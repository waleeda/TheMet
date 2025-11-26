import Foundation

public struct StreamProgress: Sendable, Equatable {
    public let completed: Int
    public let total: Int

    public init(completed: Int, total: Int) {
        self.completed = completed
        self.total = total
    }
}

public struct CooperativeCancellation: Sendable {
    private let isCancelledProvider: @Sendable () -> Bool

    public init(_ isCancelled: @escaping @Sendable () -> Bool) {
        self.isCancelledProvider = isCancelled
    }

    public var isCancelled: Bool { isCancelledProvider() }
}
