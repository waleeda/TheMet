import Foundation
import FoundationNetworking

public enum NationalGalleryClientError: Error, LocalizedError {
    case invalidResponse
    case statusCode(Int)
    case requestBuilderFailed(Error)

    public var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Unexpected response from the National Gallery of Art Collection API."
        case .statusCode(let code):
            return "Received HTTP status code \(code) from the National Gallery of Art Collection API."
        case .requestBuilderFailed:
            return "Failed to build a request for the National Gallery of Art Collection API."
        }
    }
}

public final class NationalGalleryClient {
    public static let shared = NationalGalleryClient()

    public let baseURL: URL
    private let session: URLSession
    private let requestBuilder: RequestBuilder
    private let retryConfiguration: RetryConfiguration
    public let decoder: JSONDecoder

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

    public struct RetryConfiguration {
        public var maxRetries: Int
        public var initialBackoff: TimeInterval
        public var backoffMultiplier: Double

        public init(maxRetries: Int = 2, initialBackoff: TimeInterval = 0.5, backoffMultiplier: Double = 2.0) {
            self.maxRetries = max(0, maxRetries)
            self.initialBackoff = max(0, initialBackoff)
            self.backoffMultiplier = max(1, backoffMultiplier)
        }
    }

    public typealias RequestBuilder = @Sendable (URL) throws -> URLRequest

    public init(
        baseURL: URL = URL(string: "https://api.nga.gov/collection")!,
        session: URLSession = .shared,
        decoder: JSONDecoder? = nil,
        decodingStrategies: DecodingStrategies = DecodingStrategies(),
        requestTimeout: TimeInterval = 30,
        retryConfiguration: RetryConfiguration = RetryConfiguration(),
        requestBuilder: RequestBuilder? = nil
    ) {
        self.baseURL = baseURL
        self.session = session
        self.retryConfiguration = retryConfiguration
        let timeout = requestTimeout
        self.requestBuilder = requestBuilder ?? { url in
            var request = URLRequest(url: url)
            request.timeoutInterval = timeout
            return request
        }
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

    public func objectIDs(for query: NationalGalleryObjectQuery = NationalGalleryObjectQuery()) async throws -> NationalGalleryObjectIDsResponse {
        let url = try buildURL(path: "art/objects", queryItems: query.queryItems)
        return try await fetch(url: url, as: NationalGalleryObjectIDsResponse.self)
    }

    public func object(id: Int) async throws -> NationalGalleryObject {
        let url = try buildURL(path: "art/objects/\(id)")
        return try await fetch(url: url, as: NationalGalleryObject.self)
    }

    public func allObjects(
        query: NationalGalleryObjectQuery = NationalGalleryObjectQuery(),
        pageSize: Int = 100,
        concurrentRequests: Int = 6,
        progress: (@Sendable (StreamProgress) -> Void)? = nil,
        cancellation: CooperativeCancellation? = nil
    ) -> AsyncThrowingStream<NationalGalleryObject, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let ids = try await fetchAllObjectIDs(
                        query: query,
                        pageSize: pageSize,
                        cancellation: cancellation
                    )
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
    ) -> AsyncThrowingStream<NationalGalleryObject, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
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

    private func fetchAllObjectIDs(
        query: NationalGalleryObjectQuery,
        pageSize: Int,
        cancellation: CooperativeCancellation?
    ) async throws -> [Int] {
        try checkCancellation(cancellation)

        var allIDs: [Int] = []
        var currentPage = max(1, query.page ?? 1)
        let effectivePageSize = query.pageSize ?? pageSize
        var totalRecords: Int?

        while true {
            var pagedQuery = query
            pagedQuery.page = currentPage
            pagedQuery.pageSize = effectivePageSize

            let response = try await objectIDs(for: pagedQuery)
            try checkCancellation(cancellation)

            totalRecords = totalRecords ?? response.totalRecords
            allIDs.append(contentsOf: response.objectIDs)

            let expectedTotal = totalRecords ?? allIDs.count
            if allIDs.count >= expectedTotal || response.objectIDs.isEmpty {
                break
            }

            currentPage += 1
        }

        return allIDs
    }

    private func streamObjects(
        ids: [Int],
        concurrentRequests: Int,
        totalCount: Int,
        progress: (@Sendable (StreamProgress) -> Void)?,
        cancellation: CooperativeCancellation?,
        continuation: AsyncThrowingStream<NationalGalleryObject, Error>.Continuation
    ) async throws {
        let clampedConcurrency = max(1, concurrentRequests)
        var index = 0
        var completed = 0

        while index < ids.count {
            try checkCancellation(cancellation)
            let upperBound = min(ids.count, index + clampedConcurrency)
            let slice = ids[index..<upperBound]

            try await withThrowingTaskGroup(of: NationalGalleryObject?.self) { group in
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
            throw NationalGalleryClientError.invalidResponse
        }
        components.path.append("/\(path)")
        if !queryItems.isEmpty {
            components.queryItems = queryItems
        }
        guard let url = components.url else {
            throw NationalGalleryClientError.invalidResponse
        }
        return url
    }

    private func fetch<T: Decodable>(url: URL, as type: T.Type) async throws -> T {
        var attempt = 0
        var backoff = retryConfiguration.initialBackoff

        while true {
            let request: URLRequest

            do {
                request = try requestBuilder(url)
            } catch {
                throw NationalGalleryClientError.requestBuilderFailed(error)
            }

            do {
                let (data, response) = try await session.data(for: request)
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw NationalGalleryClientError.invalidResponse
                }
                guard 200..<300 ~= httpResponse.statusCode else {
                    if shouldRetry(statusCode: httpResponse.statusCode, attempt: attempt) {
                        attempt += 1
                        try await applyBackoff(delay: backoff)
                        backoff *= retryConfiguration.backoffMultiplier
                        continue
                    }
                    throw NationalGalleryClientError.statusCode(httpResponse.statusCode)
                }
                return try decoder.decode(type, from: data)
            } catch {
                if shouldRetry(error: error, attempt: attempt) {
                    attempt += 1
                    try await applyBackoff(delay: backoff)
                    backoff *= retryConfiguration.backoffMultiplier
                    continue
                }
                throw error
            }
        }
    }

    private func shouldRetry(statusCode: Int, attempt: Int) -> Bool {
        guard attempt < retryConfiguration.maxRetries else { return false }
        return statusCode == 429 || (500..<600).contains(statusCode)
    }

    private func shouldRetry(error: Error, attempt: Int) -> Bool {
        guard attempt < retryConfiguration.maxRetries else { return false }
        if let urlError = error as? URLError {
            return urlError.code != .cancelled && urlError.code != .badURL
        }
        return false
    }

    private func applyBackoff(delay: TimeInterval) async throws {
        guard delay > 0 else { return }
        let nanoseconds = UInt64(delay * 1_000_000_000)
        try await Task.sleep(nanoseconds: nanoseconds)
    }
}
