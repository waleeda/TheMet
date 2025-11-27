import Foundation

public struct SavedFilterSet: Equatable {
    public let name: String
    public let filters: [MetFilter]

    public init(name: String, filters: [MetFilter]) {
        self.name = name
        self.filters = filters
    }
}

public enum SavedFilterError: Error, LocalizedError, Equatable {
    case missingFilterSet(String)

    public var errorDescription: String? {
        switch self {
        case .missingFilterSet(let name):
            return "No saved filters were found for the name \(name)."
        }
    }
}

public final class SavedFilterLibrary {
    private var storage: [String: [MetFilter]]

    public init(savedFilterSets: [SavedFilterSet] = []) {
        self.storage = Dictionary(uniqueKeysWithValues: savedFilterSets.map { ($0.name, $0.filters) })
    }

    @discardableResult
    public func save(_ filters: [MetFilter], named name: String) -> SavedFilterSet {
        storage[name] = filters
        return SavedFilterSet(name: name, filters: filters)
    }

    public func remove(named name: String) {
        storage[name] = nil
    }

    public func filters(named name: String) -> [MetFilter]? {
        storage[name]
    }

    public func filterSet(named name: String) -> SavedFilterSet? {
        guard let filters = storage[name] else { return nil }
        return SavedFilterSet(name: name, filters: filters)
    }

    public var allFilterSets: [SavedFilterSet] {
        storage.map { SavedFilterSet(name: $0.key, filters: $0.value) }.sorted { $0.name < $1.name }
    }
}
