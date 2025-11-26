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
    private let decoder: JSONDecoder

    public init(
        baseURL: URL = URL(string: "https://collectionapi.metmuseum.org/public/collection/v1")!,
        session: URLSession = .shared,
        decoder: JSONDecoder = JSONDecoder()
    ) {
        self.baseURL = baseURL
        self.session = session
        self.decoder = decoder
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
            Task {
                do {
                    let idsResponse = try await objectIDs()
                    let ids = idsResponse.objectIDs
                    try await streamObjects(ids: ids, concurrentRequests: concurrentRequests, continuation: continuation)
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    public func objects(ids: [Int], concurrentRequests: Int = 6) -> AsyncThrowingStream<MetObject, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    try await streamObjects(ids: ids, concurrentRequests: concurrentRequests, continuation: continuation)
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    private func streamObjects(
        ids: [Int],
        concurrentRequests: Int,
        continuation: AsyncThrowingStream<MetObject, Error>.Continuation
    ) async throws {
        let clampedConcurrency = max(1, concurrentRequests)
        var index = 0
        while index < ids.count {
            let upperBound = min(ids.count, index + clampedConcurrency)
            let slice = ids[index..<upperBound]
            try await withThrowingTaskGroup(of: MetObject?.self) { group in
                for id in slice {
                    group.addTask { [weak self] in
                        guard let self else { return nil }
                        return try await self.object(id: id)
                    }
                }
                for try await object in group {
                    if let object {
                        continuation.yield(object)
                    }
                }
            }
            index = upperBound
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
