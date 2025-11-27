import Foundation
import FoundationNetworking

public enum HarvardArtMuseumsClientError: Error, LocalizedError {
    case invalidResponse
    case statusCode(Int)
    case requestBuilderFailed(Error)

    public var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Unexpected response from the Harvard Art Museums API."
        case .statusCode(let code):
            return "Received HTTP status code \(code) from the Harvard Art Museums API."
        case .requestBuilderFailed:
            return "Failed to build a request for the Harvard Art Museums API."
        }
    }
}

public final class HarvardArtMuseumsClient {
    public let apiKey: String
    public let baseURL: URL
    private let session: URLSession
    private let requestBuilder: RequestBuilder
    private let retryConfiguration: RetryConfiguration
    private let onRetry: RetryEventHandler?
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
        apiKey: String,
        baseURL: URL = URL(string: "https://api.harvardartmuseums.org")!,
        session: URLSession = .shared,
        decoder: JSONDecoder? = nil,
        decodingStrategies: DecodingStrategies = DecodingStrategies(),
        requestTimeout: TimeInterval = 30,
        retryConfiguration: RetryConfiguration = RetryConfiguration(),
        requestBuilder: RequestBuilder? = nil,
        onRetry: RetryEventHandler? = nil
    ) {
        self.apiKey = apiKey
        self.baseURL = baseURL
        self.session = session
        self.retryConfiguration = retryConfiguration
        self.onRetry = onRetry
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

    public func departments() async throws -> [HarvardDepartment] {
        let url = try buildURL(path: "department")
        let response = try await fetch(url: url, as: HarvardDepartmentsResponse.self)
        return response.departments
    }

    public func objectIDs(for query: HarvardObjectQuery = HarvardObjectQuery()) async throws -> HarvardObjectIDsResponse {
        let url = try buildURL(path: "object", queryItems: query.queryItems)
        return try await fetch(url: url, as: HarvardObjectIDsResponse.self)
    }

    public func object(id: Int) async throws -> HarvardObject {
        let url = try buildURL(path: "object/\(id)")
        return try await fetch(url: url, as: HarvardObject.self)
    }

    public func allObjects(
        query: HarvardObjectQuery = HarvardObjectQuery(),
        pageSize: Int = 100,
        concurrentRequests: Int = 6,
        progress: (@Sendable (StreamProgress) -> Void)? = nil,
        cancellation: CooperativeCancellation? = nil
    ) -> AsyncThrowingStream<HarvardObject, Error> {
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
    ) -> AsyncThrowingStream<HarvardObject, Error> {
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
        query: HarvardObjectQuery,
        pageSize: Int,
        cancellation: CooperativeCancellation?
    ) async throws -> [Int] {
        try checkCancellation(cancellation)

        var allIDs: [Int] = []
        var currentPage = max(1, query.page ?? 1)
        let effectivePageSize = query.pageSize ?? pageSize
        var totalPages: Int?

        while true {
            var pagedQuery = query
            pagedQuery.page = currentPage
            pagedQuery.pageSize = effectivePageSize

            let response = try await objectIDs(for: pagedQuery)
            try checkCancellation(cancellation)

            allIDs.append(contentsOf: response.objectIDs)
            totalPages = totalPages ?? response.totalPages

            if currentPage >= (totalPages ?? currentPage) || response.objectIDs.isEmpty {
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
        continuation: AsyncThrowingStream<HarvardObject, Error>.Continuation
    ) async throws {
        let clampedConcurrency = max(1, concurrentRequests)
        var index = 0
        var completed = 0

        while index < ids.count {
            try checkCancellation(cancellation)
            let upperBound = min(ids.count, index + clampedConcurrency)
            let slice = ids[index..<upperBound]
            try await withThrowingTaskGroup(of: HarvardObject?.self) { group in
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
            throw HarvardArtMuseumsClientError.invalidResponse
        }
        components.path.append("/\(path)")
        var items = queryItems
        items.append(URLQueryItem(name: "apikey", value: apiKey))
        if !items.isEmpty {
            components.queryItems = items
        }
        guard let url = components.url else {
            throw HarvardArtMuseumsClientError.invalidResponse
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
                throw HarvardArtMuseumsClientError.requestBuilderFailed(error)
            }

            do {
                let (data, response) = try await session.data(for: request)
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw HarvardArtMuseumsClientError.invalidResponse
                }
                guard 200..<300 ~= httpResponse.statusCode else {
                    if shouldRetry(statusCode: httpResponse.statusCode, attempt: attempt) {
                        notifyRetry(attempt: attempt, delay: backoff, reason: .httpStatus(httpResponse.statusCode))
                        attempt += 1
                        try await applyBackoff(delay: backoff)
                        backoff *= retryConfiguration.backoffMultiplier
                        continue
                    }
                    throw HarvardArtMuseumsClientError.statusCode(httpResponse.statusCode)
                }
                return try decoder.decode(type, from: data)
            } catch {
                if shouldRetry(error: error, attempt: attempt) {
                    notifyRetry(attempt: attempt, delay: backoff, reason: .transportError((error as? URLError)?.code ?? .unknown))
                    attempt += 1
                    try await applyBackoff(delay: backoff)
                    backoff *= retryConfiguration.backoffMultiplier
                    continue
                }
                throw error
            }
        }
    }

    private func notifyRetry(attempt: Int, delay: TimeInterval, reason: RetryReason) {
        guard let onRetry else { return }
        onRetry(RetryEvent(attempt: attempt + 1, delay: delay, reason: reason))
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
