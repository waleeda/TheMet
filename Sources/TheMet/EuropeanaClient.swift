import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public enum EuropeanaClientError: Error, LocalizedError {
    case invalidResponse
    case statusCode(Int)
    case requestBuilderFailed(Error)

    public var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Unexpected response from the Europeana API."
        case .statusCode(let code):
            return "Received HTTP status code \(code) from the Europeana API."
        case .requestBuilderFailed:
            return "Failed to build a request for the Europeana API."
        }
    }
}

public final class EuropeanaClient {
    public static let shared = EuropeanaClient()

    public let baseURL: URL
    public let apiKey: String
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
        baseURL: URL = URL(string: "https://api.europeana.eu/record/v2")!,
        apiKey: String = "DEMO_KEY",
        session: URLSession = .shared,
        decoder: JSONDecoder? = nil,
        decodingStrategies: DecodingStrategies = DecodingStrategies(),
        requestTimeout: TimeInterval = 30,
        retryConfiguration: RetryConfiguration = RetryConfiguration(),
        requestBuilder: RequestBuilder? = nil,
        onRetry: RetryEventHandler? = nil
    ) {
        self.baseURL = baseURL
        self.apiKey = apiKey
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

    public func search(_ query: EuropeanaSearchQuery = EuropeanaSearchQuery()) async throws -> EuropeanaSearchResponse {
        let url = try buildURL(path: "search.json", queryItems: query.queryItems(apiKey: apiKey))
        return try await fetch(url: url, as: EuropeanaSearchResponse.self)
    }

    private func buildURL(path: String, queryItems: [URLQueryItem] = []) throws -> URL {
        guard var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
            throw EuropeanaClientError.invalidResponse
        }
        components.path.append("/\(path)")
        if !queryItems.isEmpty {
            components.queryItems = queryItems
        }
        guard let url = components.url else {
            throw EuropeanaClientError.invalidResponse
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
                throw EuropeanaClientError.requestBuilderFailed(error)
            }

            do {
                let (data, response) = try await session.data(for: request)
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw EuropeanaClientError.invalidResponse
                }
                guard 200..<300 ~= httpResponse.statusCode else {
                    if shouldRetry(statusCode: httpResponse.statusCode, attempt: attempt) {
                        notifyRetry(attempt: attempt, delay: backoff, reason: .httpStatus(httpResponse.statusCode))
                        attempt += 1
                        try await applyBackoff(delay: backoff)
                        backoff *= retryConfiguration.backoffMultiplier
                        continue
                    }
                    throw EuropeanaClientError.statusCode(httpResponse.statusCode)
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
