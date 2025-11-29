import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public struct NationalGalleryObjectIDsResponse: Codable, Equatable {
    public let totalRecords: Int
    public let objectIDs: [Int]
}

public struct NationalGalleryObject: Codable, Equatable {
    public let id: Int
    public let title: String?
    public let creator: String?
    public let displayDate: String?
    public let medium: String?
    public let dimensions: String?
    public let department: String?
    public let objectType: String?
    public let image: String?
    public let description: String?

    enum CodingKeys: String, CodingKey {
        case id = "objectId"
        case title
        case creator
        case displayDate
        case medium
        case dimensions
        case department
        case objectType
        case image
        case description
    }
}

public struct NationalGalleryObjectQuery: Equatable {
    public var keyword: String?
    public var classification: String?
    public var hasImages: Bool?
    public var page: Int?
    public var pageSize: Int?

    public init(
        keyword: String? = nil,
        classification: String? = nil,
        hasImages: Bool? = nil,
        page: Int? = nil,
        pageSize: Int? = nil
    ) {
        self.keyword = keyword
        self.classification = classification
        self.hasImages = hasImages
        self.page = page
        self.pageSize = pageSize
    }

    var queryItems: [URLQueryItem] {
        var items: [URLQueryItem] = []
        if let keyword, !keyword.isEmpty {
            items.append(URLQueryItem(name: "q", value: keyword))
        }
        if let classification, !classification.isEmpty {
            items.append(URLQueryItem(name: "classification", value: classification))
        }
        if let hasImages {
            items.append(URLQueryItem(name: "images", value: hasImages ? "true" : "false"))
        }
        if let page, page > 0 {
            items.append(URLQueryItem(name: "page", value: String(page)))
        }
        if let pageSize, pageSize > 0 {
            items.append(URLQueryItem(name: "size", value: String(pageSize)))
        }
        return items
    }
}
