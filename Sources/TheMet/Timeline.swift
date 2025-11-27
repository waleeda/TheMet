import Foundation

public struct TimelinePeriod: Codable, Equatable {
    public let id: String
    public let title: String
    public let startYear: Int
    public let endYear: Int
    public let region: String?
    public let movement: String?
    public let predominantMedium: String?
    public let works: [TimelineWork]

    public init(
        id: String,
        title: String,
        startYear: Int,
        endYear: Int,
        region: String? = nil,
        movement: String? = nil,
        predominantMedium: String? = nil,
        works: [TimelineWork]
    ) {
        self.id = id
        self.title = title
        self.startYear = startYear
        self.endYear = endYear
        self.region = region
        self.movement = movement
        self.predominantMedium = predominantMedium
        self.works = works
    }

    public func overlaps(with range: ClosedRange<Int>) -> Bool {
        return startYear <= range.upperBound && endYear >= range.lowerBound
    }
}

public struct TimelineWork: Codable, Equatable {
    public let objectID: Int
    public let title: String
    public let artistDisplayName: String?
    public let year: Int?
    public let movement: String?
    public let region: String?
    public let medium: String?
    public let deepLink: TimelineDeepLink

    public init(
        objectID: Int,
        title: String,
        artistDisplayName: String? = nil,
        year: Int? = nil,
        movement: String? = nil,
        region: String? = nil,
        medium: String? = nil,
        deepLink: TimelineDeepLink = .object(id: 0)
    ) {
        self.objectID = objectID
        self.title = title
        self.artistDisplayName = artistDisplayName
        self.year = year
        self.movement = movement
        self.region = region
        self.medium = medium
        self.deepLink = deepLink
    }
}

public enum TimelineDeepLink: Equatable {
    case object(id: Int)
    case artist(id: Int)
    case custom(URL)

    public var url: URL? {
        switch self {
        case .object(let id):
            return URL(string: "themet://object/\(id)")
        case .artist(let id):
            return URL(string: "themet://artist/\(id)")
        case .custom(let url):
            return url
        }
    }
}

extension TimelineDeepLink: Codable {
    private enum CodingKeys: String, CodingKey { case type, value }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        switch type {
        case "object":
            let id = try container.decode(Int.self, forKey: .value)
            self = .object(id: id)
        case "artist":
            let id = try container.decode(Int.self, forKey: .value)
            self = .artist(id: id)
        case "custom":
            let url = try container.decode(URL.self, forKey: .value)
            self = .custom(url)
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .type,
                in: container,
                debugDescription: "Unsupported deep link type \(type)"
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .object(let id):
            try container.encode("object", forKey: .type)
            try container.encode(id, forKey: .value)
        case .artist(let id):
            try container.encode("artist", forKey: .type)
            try container.encode(id, forKey: .value)
        case .custom(let url):
            try container.encode("custom", forKey: .type)
            try container.encode(url, forKey: .value)
        }
    }
}

public struct TimelineFilter: Equatable {
    public var regions: Set<String>
    public var movements: Set<String>
    public var mediums: Set<String>
    public var dateRange: ClosedRange<Int>?

    public init(
        regions: Set<String> = [],
        movements: Set<String> = [],
        mediums: Set<String> = [],
        dateRange: ClosedRange<Int>? = nil
    ) {
        self.regions = Set(regions.map { $0.lowercased() })
        self.movements = Set(movements.map { $0.lowercased() })
        self.mediums = Set(mediums.map { $0.lowercased() })
        self.dateRange = dateRange
    }

    public var isEmpty: Bool {
        return regions.isEmpty && movements.isEmpty && mediums.isEmpty && dateRange == nil
    }
}

public struct TimelineState: Equatable {
    public let periods: [TimelinePeriod]
    public let works: [TimelineWork]
    public let activeFilter: TimelineFilter

    public init(periods: [TimelinePeriod], works: [TimelineWork], activeFilter: TimelineFilter) {
        self.periods = periods
        self.works = works
        self.activeFilter = activeFilter
    }
}

public final class TimelineViewModel {
    private let allPeriods: [TimelinePeriod]
    public private(set) var state: TimelineState

    public init(periods: [TimelinePeriod], filter: TimelineFilter = .init()) {
        self.allPeriods = periods
        self.state = TimelineState(periods: periods, works: periods.flatMap { $0.works }, activeFilter: filter)
        apply(filter: filter)
    }

    public func updateFilter(_ filter: TimelineFilter) {
        apply(filter: filter)
    }

    private func apply(filter: TimelineFilter) {
        let filteredPeriods = allPeriods.filter { period in
            guard let range = filter.dateRange else { return periodMatches(period, filter: filter) }
            return period.overlaps(with: range) && periodMatches(period, filter: filter)
        }

        let filteredWorks: [TimelineWork]
        if filter.isEmpty {
            filteredWorks = filteredPeriods.flatMap { $0.works }
        } else {
            filteredWorks = filteredPeriods.flatMap { period in
                period.works.filter { work in
                    matches(work.region, in: filter.regions) &&
                    matches(work.movement, in: filter.movements) &&
                    matches(work.medium, in: filter.mediums) &&
                    matches(year: work.year, within: filter.dateRange)
                }
            }
        }

        state = TimelineState(periods: filteredPeriods, works: filteredWorks, activeFilter: filter)
    }

    private func periodMatches(_ period: TimelinePeriod, filter: TimelineFilter) -> Bool {
        return matches(period.region, in: filter.regions)
            && matches(period.movement, in: filter.movements)
            && matches(period.predominantMedium, in: filter.mediums)
    }

    private func matches(_ value: String?, in allowed: Set<String>) -> Bool {
        guard !allowed.isEmpty else { return true }
        guard let value = value?.lowercased() else { return false }
        return allowed.contains(value)
    }

    private func matches(year: Int?, within range: ClosedRange<Int>?) -> Bool {
        guard let range = range else { return true }
        guard let year = year else { return false }
        return range.contains(year)
    }
}

public struct TimelineDataSource {
    public init() {}

    public func decode(from data: Data) throws -> [TimelinePeriod] {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode([TimelinePeriod].self, from: data)
    }

    public func shareableURL(baseURL: URL, filter: TimelineFilter) -> URL? {
        guard var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else { return nil }
        var queryItems: [URLQueryItem] = []

        if !filter.regions.isEmpty {
            queryItems.append(URLQueryItem(name: "regions", value: filter.regions.sorted().joined(separator: ",")))
        }
        if !filter.movements.isEmpty {
            queryItems.append(URLQueryItem(name: "movements", value: filter.movements.sorted().joined(separator: ",")))
        }
        if !filter.mediums.isEmpty {
            queryItems.append(URLQueryItem(name: "mediums", value: filter.mediums.sorted().joined(separator: ",")))
        }
        if let range = filter.dateRange {
            queryItems.append(URLQueryItem(name: "start", value: String(range.lowerBound)))
            queryItems.append(URLQueryItem(name: "end", value: String(range.upperBound)))
        }

        queryItems.sort { $0.name < $1.name }
        components.queryItems = queryItems.isEmpty ? nil : queryItems
        return components.url
    }
}
