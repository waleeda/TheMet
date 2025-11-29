import Foundation

public enum CachePolicy {
    case useCache
    case reload
}

actor ValueCache<Value> {
    private var value: Value?

    func cached() -> Value? {
        value
    }

    func store(_ newValue: Value) {
        value = newValue
    }

    func clear() {
        value = nil
    }
}

actor LRUCache<Key: Hashable, Value> {
    private var storage: [Key: Value] = [:]
    private var order: [Key] = []
    private let capacity: Int

    init(capacity: Int) {
        self.capacity = max(1, capacity)
    }

    func value(for key: Key) -> Value? {
        guard let value = storage[key] else { return nil }
        touch(key)
        return value
    }

    func insert(_ value: Value, for key: Key) {
        storage[key] = value
        touch(key)
        enforceCapacity()
    }

    func clear() {
        storage.removeAll()
        order.removeAll()
    }

    private func touch(_ key: Key) {
        order.removeAll { $0 == key }
        order.insert(key, at: 0)
    }

    private func enforceCapacity() {
        while storage.count > capacity, let last = order.popLast() {
            storage.removeValue(forKey: last)
        }
    }
}
