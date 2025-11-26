import Foundation
import FoundationNetworking

public struct ObjectIDsResponse: Codable, Equatable {
    public let total: Int
    public let objectIDs: [Int]
}

public struct ObjectQuery: Equatable {
    public var departmentIds: [Int]?
    public var hasImages: Bool?
    public var searchQuery: String?

    public init(departmentIds: [Int]? = nil, hasImages: Bool? = nil, searchQuery: String? = nil) {
        self.departmentIds = departmentIds
        self.hasImages = hasImages
        self.searchQuery = searchQuery
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
        return items
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
