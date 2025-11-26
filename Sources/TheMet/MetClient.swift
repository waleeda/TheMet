import Foundation
import FoundationNetworking

public enum MetClientError: Error, LocalizedError {
    case invalidResponse
    case statusCode(Int)

    public var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Unexpected response from The Met Collection API."
        case .statusCode(let code):
            return "Received HTTP status code \(code) from The Met Collection API."
        }
    }
}

public final class MetClient {
    public static let shared = MetClient()

    public let baseURL: URL
    private let session: URLSession

    public struct DecodingStrategies {
        public var dateDecodingStrategy: JSONDecoder.DateDecodingStrategy
        public var dataDecodingStrategy: JSONDecoder.DataDecodingStrategy
        public var nonConformingFloatDecodingStrategy: JSONDecoder.NonConformingFloatDecodingStrategy
        public var keyDecodingStrategy: JSONDecoder.KeyDecodingStrategy

        public init(
            dateDecodingStrategy: JSONDecoder.DateDecodingStrategy = .deferredToDate,
            dataDecodingStrategy: JSONDecoder.DataDecodingStrategy = .base64,
            nonConformingFloatDecodingStrategy: JSONDecoder.NonConformingFloatDecodingStrategy = .throw,
            keyDecodingStrategy: JSONDecoder.KeyDecodingStrategy = .useDefaultKeys
        ) {
            self.dateDecodingStrategy = dateDecodingStrategy
            self.dataDecodingStrategy = dataDecodingStrategy
            self.nonConformingFloatDecodingStrategy = nonConformingFloatDecodingStrategy
            self.keyDecodingStrategy = keyDecodingStrategy
        }
    }

    public let decoder: JSONDecoder

    public init(
        baseURL: URL = URL(string: "https://collectionapi.metmuseum.org/public/collection/v1")!,
        session: URLSession = .shared,
        decoder: JSONDecoder? = nil,
        decodingStrategies: DecodingStrategies = DecodingStrategies()
    ) {
        self.baseURL = baseURL
        self.session = session
        if let decoder {
            self.decoder = decoder
        } else {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = decodingStrategies.dateDecodingStrategy
            decoder.dataDecodingStrategy = decodingStrategies.dataDecodingStrategy
            decoder.nonConformingFloatDecodingStrategy = decodingStrategies.nonConformingFloatDecodingStrategy
            decoder.keyDecodingStrategy = decodingStrategies.keyDecodingStrategy
            self.decoder = decoder
        }
    }

    public func objectIDs(for query: ObjectQuery = ObjectQuery()) async throws -> ObjectIDsResponse {
        let url = try buildURL(path: "objects", queryItems: query.queryItems)
        return try await fetch(url: url, as: ObjectIDsResponse.self)
    }

    public func departments() async throws -> [Department] {
        let url = try buildURL(path: "departments")
        let response = try await fetch(url: url, as: DepartmentsResponse.self)
        return response.departments
    }

    public func search(_ query: SearchQuery) async throws -> ObjectIDsResponse {
        let url = try buildURL(path: "search", queryItems: query.queryItems)
        return try await fetch(url: url, as: ObjectIDsResponse.self)
    }

    public func autocomplete(_ searchTerm: String) async throws -> [String] {
        let url = try buildURL(path: "search/autocomplete", queryItems: [URLQueryItem(name: "q", value: searchTerm)])
        let response = try await fetch(url: url, as: AutocompleteResponse.self)
        return response.terms
    }

    public func object(id: Int) async throws -> MetObject {
        let url = try buildURL(path: "objects/\(id)")
        return try await fetch(url: url, as: MetObject.self)
    }

    public func relatedObjectIDs(for objectID: Int) async throws -> ObjectIDsResponse {
        let url = try buildURL(path: "objects/\(objectID)/related")
        return try await fetch(url: url, as: ObjectIDsResponse.self)
    }

    public func allObjects(concurrentRequests: Int = 6) -> AsyncThrowingStream<MetObject, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    try checkCancellation(cancellation)
                    let idsResponse = try await objectIDs()
                    try checkCancellation(cancellation)
                    let ids = idsResponse.objectIDs
                    try await streamObjects(
                        ids: ids,
                        concurrentRequests: concurrentRequests,
                        totalCount: ids.count,
                        progress: progress,
                        cancellation: cancellation,
                        continuation: continuation
                    )
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }

            continuation.onTermination = { @Sendable _ in
                task.cancel()
            }
        }
    }

    public func objects(
        ids: [Int],
        concurrentRequests: Int = 6,
        progress: (@Sendable (StreamProgress) -> Void)? = nil,
        cancellation: CooperativeCancellation? = nil
    ) -> AsyncThrowingStream<MetObject, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    try checkCancellation(cancellation)
                    try await streamObjects(
                        ids: ids,
                        concurrentRequests: concurrentRequests,
                        totalCount: ids.count,
                        progress: progress,
                        cancellation: cancellation,
                        continuation: continuation
                    )
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }

            continuation.onTermination = { @Sendable _ in
                task.cancel()
            }
        }
    }

    private func streamObjects(
        ids: [Int],
        concurrentRequests: Int,
        totalCount: Int,
        progress: (@Sendable (StreamProgress) -> Void)?,
        cancellation: CooperativeCancellation?,
        continuation: AsyncThrowingStream<MetObject, Error>.Continuation
    ) async throws {
        let clampedConcurrency = max(1, concurrentRequests)
        var index = 0
        var completed = 0

        while index < ids.count {
            try checkCancellation(cancellation)
            let upperBound = min(ids.count, index + clampedConcurrency)
            let slice = ids[index..<upperBound]
            try await withThrowingTaskGroup(of: MetObject?.self) { group in
                for id in slice {
                    group.addTask { [weak self] in
                        guard let self else { return nil }
                        try Task.checkCancellation()
                        return try await self.object(id: id)
                    }
                }

                do {
                    for try await object in group {
                        if cancellation?.isCancelled == true || Task.isCancelled {
                            group.cancelAll()
                            throw CancellationError()
                        }

                        if let object {
                            continuation.yield(object)
                            completed += 1
                            progress?(StreamProgress(completed: completed, total: totalCount))
                        }
                    }
                } catch {
                    group.cancelAll()
                    throw error
                }
            }
            index = upperBound
        }

        try checkCancellation(cancellation)
    }

    private func checkCancellation(_ cancellation: CooperativeCancellation?) throws {
        if Task.isCancelled || cancellation?.isCancelled == true {
            throw CancellationError()
        }
    }

    private func buildURL(path: String, queryItems: [URLQueryItem] = []) throws -> URL {
        guard var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
            throw MetClientError.invalidResponse
        }
        components.path.append("/\(path)")
        if !queryItems.isEmpty {
            components.queryItems = queryItems
        }
        guard let url = components.url else {
            throw MetClientError.invalidResponse
        }
        return url
    }

    private func fetch<T: Decodable>(url: URL, as type: T.Type) async throws -> T {
        let request = URLRequest(url: url)
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw MetClientError.invalidResponse
        }
        guard 200..<300 ~= httpResponse.statusCode else {
            throw MetClientError.statusCode(httpResponse.statusCode)
        }
        return try decoder.decode(type, from: data)
    }
}
