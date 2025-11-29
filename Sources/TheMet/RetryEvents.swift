import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Describes why a request retry was triggered.
public enum RetryReason: Sendable, Equatable {
    /// The server responded with an HTTP status code that supports retry.
    case httpStatus(Int)
    /// A transport-level error occurred, such as a temporary connectivity failure.
    case transportError(URLError.Code)
}

/// Metadata surfaced when the client retries a request, suitable for UI messaging or metrics.
public struct RetryEvent: Sendable, Equatable {
    /// The retry attempt number starting at 1 for the first retry.
    public let attempt: Int
    /// The backoff delay applied before the next attempt.
    public let delay: TimeInterval
    /// The status or error that triggered the retry.
    public let reason: RetryReason

    public init(attempt: Int, delay: TimeInterval, reason: RetryReason) {
        self.attempt = attempt
        self.delay = delay
        self.reason = reason
    }
}

/// Closure invoked whenever the client schedules a retry.
public typealias RetryEventHandler = @Sendable (RetryEvent) -> Void
