import Foundation
import FoundationNetworking

public struct ObjectIDsResponse: Codable, Equatable {
    public let total: Int
    public let objectIDs: [Int]
}

public enum MetFilter: Equatable {
    case searchTerm(String)
    case departmentIds([Int])
    case departmentId(Int)
    case hasImages(Bool)
    case metadataDate(Date)
    case isHighlight(Bool)
    case isOnView(Bool)
    case artistOrCulture(Bool)
    case medium(String)
    case geoLocation(String)
    case dateBegin(Int)
    case dateEnd(Int)
}

public struct DepartmentsResponse: Codable, Equatable {
    public let departments: [Department]
}

public struct AutocompleteResponse: Codable, Equatable {
    public let terms: [String]
}

public struct Department: Codable, Equatable {
    public let departmentId: Int
    public let displayName: String
}

public struct ObjectQuery: Equatable {
    public var departmentIds: [Int]?
    public var hasImages: Bool?
    public var searchQuery: String?
    public var metadataDate: Date?
    public var isHighlight: Bool?
    public var isOnView: Bool?
    public var artistOrCulture: Bool?
    public var medium: String?
    public var geoLocation: String?
    public var dateBegin: Int?
    public var dateEnd: Int?

    public init(
        departmentIds: [Int]? = nil,
        hasImages: Bool? = nil,
        searchQuery: String? = nil,
        metadataDate: Date? = nil,
        isHighlight: Bool? = nil,
        isOnView: Bool? = nil,
        artistOrCulture: Bool? = nil,
        medium: String? = nil,
        geoLocation: String? = nil,
        dateBegin: Int? = nil,
        dateEnd: Int? = nil
    ) {
        self.departmentIds = departmentIds
        self.hasImages = hasImages
        self.searchQuery = searchQuery
        self.metadataDate = metadataDate
        self.isHighlight = isHighlight
        self.isOnView = isOnView
        self.artistOrCulture = artistOrCulture
        self.medium = medium
        self.geoLocation = geoLocation
        self.dateBegin = dateBegin
        self.dateEnd = dateEnd
    }

    public init(filters: [MetFilter]) {
        self.init()
        apply(filters: filters)
    }

    var queryItems: [URLQueryItem] {
        var items: [URLQueryItem] = []
        if let departmentIds, !departmentIds.isEmpty {
            let value = departmentIds.map(String.init).joined(separator: "|")
            items.append(URLQueryItem(name: "departmentIds", value: value))
        }
        if let hasImages {
            items.append(URLQueryItem(name: "hasImages", value: hasImages ? "true" : "false"))
        }
        if let searchQuery, !searchQuery.isEmpty {
            items.append(URLQueryItem(name: "q", value: searchQuery))
        }
        if let metadataDate {
            let dateString = Self.metadataDateFormatter.string(from: metadataDate)
            items.append(URLQueryItem(name: "metadataDate", value: dateString))
        }
        if let isHighlight {
            items.append(URLQueryItem(name: "isHighlight", value: isHighlight ? "true" : "false"))
        }
        if let isOnView {
            items.append(URLQueryItem(name: "isOnView", value: isOnView ? "true" : "false"))
        }
        if let artistOrCulture {
            items.append(URLQueryItem(name: "artistOrCulture", value: artistOrCulture ? "true" : "false"))
        }
        if let medium, !medium.isEmpty {
            items.append(URLQueryItem(name: "medium", value: medium))
        }
        if let geoLocation, !geoLocation.isEmpty {
            items.append(URLQueryItem(name: "geoLocation", value: geoLocation))
        }
        if let dateBegin {
            items.append(URLQueryItem(name: "dateBegin", value: String(dateBegin)))
        }
        if let dateEnd {
            items.append(URLQueryItem(name: "dateEnd", value: String(dateEnd)))
        }
        return items
    }

    private static let metadataDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()

    public mutating func apply(filters: [MetFilter]) {
        for filter in filters {
            switch filter {
            case .departmentIds(let ids):
                departmentIds = ids
            case .departmentId(let id):
                departmentIds = [id]
            case .hasImages(let value):
                hasImages = value
            case .searchTerm(let term):
                searchQuery = term
            case .metadataDate(let date):
                metadataDate = date
            case .isHighlight(let value):
                isHighlight = value
            case .isOnView(let value):
                isOnView = value
            case .artistOrCulture(let value):
                artistOrCulture = value
            case .medium(let value):
                medium = value
            case .geoLocation(let value):
                geoLocation = value
            case .dateBegin(let value):
                dateBegin = value
            case .dateEnd(let value):
                dateEnd = value
            }
        }
    }
}

public struct SearchQuery: Equatable {
    public var searchTerm: String
    public var isHighlight: Bool?
    public var hasImages: Bool?
    public var departmentId: Int?
    public var isOnView: Bool?
    public var artistOrCulture: Bool?
    public var medium: String?
    public var geoLocation: String?
    public var dateBegin: Int?
    public var dateEnd: Int?

    public init(
        searchTerm: String,
        isHighlight: Bool? = nil,
        hasImages: Bool? = nil,
        departmentId: Int? = nil,
        isOnView: Bool? = nil,
        artistOrCulture: Bool? = nil,
        medium: String? = nil,
        geoLocation: String? = nil,
        dateBegin: Int? = nil,
        dateEnd: Int? = nil
    ) {
        self.searchTerm = searchTerm
        self.isHighlight = isHighlight
        self.hasImages = hasImages
        self.departmentId = departmentId
        self.isOnView = isOnView
        self.artistOrCulture = artistOrCulture
        self.medium = medium
        self.geoLocation = geoLocation
        self.dateBegin = dateBegin
        self.dateEnd = dateEnd
    }

    public init(filters: [MetFilter]) throws {
        var searchTerm: String?
        self.init(searchTerm: "")
        apply(filters: filters, capturedSearchTerm: &searchTerm)

        guard let searchTerm else {
            throw SearchQueryError.missingSearchTerm
        }

        self.searchTerm = searchTerm
    }

    public mutating func apply(filters: [MetFilter]) {
        var capturedSearchTerm: String? = searchTerm
        apply(filters: filters, capturedSearchTerm: &capturedSearchTerm)
        if let capturedSearchTerm {
            searchTerm = capturedSearchTerm
        }
    }

    var queryItems: [URLQueryItem] {
        var items: [URLQueryItem] = [URLQueryItem(name: "q", value: searchTerm)]
        if let isHighlight {
            items.append(URLQueryItem(name: "isHighlight", value: isHighlight ? "true" : "false"))
        }
        if let hasImages {
            items.append(URLQueryItem(name: "hasImages", value: hasImages ? "true" : "false"))
        }
        if let departmentId {
            items.append(URLQueryItem(name: "departmentId", value: String(departmentId)))
        }
        if let isOnView {
            items.append(URLQueryItem(name: "isOnView", value: isOnView ? "true" : "false"))
        }
        if let artistOrCulture {
            items.append(URLQueryItem(name: "artistOrCulture", value: artistOrCulture ? "true" : "false"))
        }
        if let medium, !medium.isEmpty {
            items.append(URLQueryItem(name: "medium", value: medium))
        }
        if let geoLocation, !geoLocation.isEmpty {
            items.append(URLQueryItem(name: "geoLocation", value: geoLocation))
        }
        if let dateBegin {
            items.append(URLQueryItem(name: "dateBegin", value: String(dateBegin)))
        }
        if let dateEnd {
            items.append(URLQueryItem(name: "dateEnd", value: String(dateEnd)))
        }
        return items
    }

    public mutating func apply(filters: [MetFilter], capturedSearchTerm: inout String?) {
        for filter in filters {
            switch filter {
            case .searchTerm(let term):
                capturedSearchTerm = term
            case .departmentId(let id):
                departmentId = id
            case .departmentIds(let ids):
                departmentId = ids.first
            case .hasImages(let value):
                hasImages = value
            case .isHighlight(let value):
                isHighlight = value
            case .isOnView(let value):
                isOnView = value
            case .artistOrCulture(let value):
                artistOrCulture = value
            case .medium(let value):
                medium = value
            case .geoLocation(let value):
                geoLocation = value
            case .dateBegin(let value):
                dateBegin = value
            case .dateEnd(let value):
                dateEnd = value
            case .metadataDate:
                break
            }
        }
    }
}

public enum SearchQueryError: Error, LocalizedError, Equatable {
    case missingSearchTerm

    public var errorDescription: String? {
        switch self {
        case .missingSearchTerm:
            return "A search term is required to perform a search request."
        }
    }
}

public struct MetObject: Codable, Equatable {
    public let objectID: Int
    public let isHighlight: Bool?
    public let accessionNumber: String?
    public let accessionYear: String?
    public let primaryImage: String?
    public let primaryImageSmall: String?
    public let department: String?
    public let objectName: String?
    public let title: String?
    public let culture: String?
    public let period: String?
    public let dynasty: String?
    public let reign: String?
    public let portfolio: String?
    public let artistDisplayName: String?
    public let artistDisplayBio: String?
    public let objectDate: String?
    public let medium: String?
    public let dimensions: String?
    public let creditLine: String?
    public let geographyType: String?
    public let city: String?
    public let state: String?
    public let county: String?
    public let country: String?
    public let classification: String?
    public let objectURL: String?
    public let tags: [MetTag]?
}

public struct MetTag: Codable, Equatable {
    public let term: String
}
