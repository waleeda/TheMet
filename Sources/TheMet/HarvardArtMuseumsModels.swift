import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public struct HarvardObjectIDsResponse: Codable, Equatable {
    public let totalRecords: Int
    public let totalPages: Int
    public let page: Int
    public let objectIDs: [Int]

    private struct Info: Codable, Equatable {
        let totalRecords: Int
        let pages: Int
        let page: Int

        enum CodingKeys: String, CodingKey {
            case totalRecords = "totalrecords"
            case pages
            case page
        }
    }

    private struct Record: Codable, Equatable {
        let objectID: Int

        enum CodingKeys: String, CodingKey {
            case objectID = "objectid"
        }
    }

    public init(totalRecords: Int, totalPages: Int, page: Int, objectIDs: [Int]) {
        self.totalRecords = totalRecords
        self.totalPages = totalPages
        self.page = page
        self.objectIDs = objectIDs
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let info = try container.decode(Info.self, forKey: .info)
        let records = try container.decode([Record].self, forKey: .records)

        self.totalRecords = info.totalRecords
        self.totalPages = info.pages
        self.page = info.page
        self.objectIDs = records.map { $0.objectID }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(Info(totalRecords: totalRecords, pages: totalPages, page: page), forKey: .info)
        try container.encode(objectIDs.map { Record(objectID: $0) }, forKey: .records)
    }

    private enum CodingKeys: String, CodingKey {
        case info
        case records
    }
}

public struct HarvardDepartment: Codable, Equatable {
    public let id: Int
    public let name: String
}

public struct HarvardDepartmentsResponse: Codable, Equatable {
    public let departments: [HarvardDepartment]

    public init(departments: [HarvardDepartment]) {
        self.departments = departments
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let records = try container.decode([HarvardDepartment].self, forKey: .records)
        self.departments = records
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(departments, forKey: .records)
    }

    private enum CodingKeys: String, CodingKey {
        case records
    }
}

public struct HarvardObject: Codable, Equatable {
    public let id: Int
    public let title: String?
    public let culture: String?
    public let period: String?
    public let classification: String?
    public let dated: String?
    public let century: String?
    public let division: String?
    public let department: String?
    public let medium: String?
    public let primaryImageURL: String?
    public let url: String?

    enum CodingKeys: String, CodingKey {
        case id = "objectid"
        case title
        case culture
        case period
        case classification
        case dated
        case century
        case division
        case department
        case medium
        case primaryImageURL = "primaryimageurl"
        case url
    }
}

public struct HarvardObjectQuery: Equatable {
    public var keyword: String?
    public var culture: String?
    public var period: String?
    public var classification: String?
    public var hasImage: Bool?
    public var page: Int?
    public var pageSize: Int?

    public init(
        keyword: String? = nil,
        culture: String? = nil,
        period: String? = nil,
        classification: String? = nil,
        hasImage: Bool? = nil,
        page: Int? = nil,
        pageSize: Int? = nil
    ) {
        self.keyword = keyword
        self.culture = culture
        self.period = period
        self.classification = classification
        self.hasImage = hasImage
        self.page = page
        self.pageSize = pageSize
    }

    var queryItems: [URLQueryItem] {
        var items: [URLQueryItem] = []
        if let keyword, !keyword.isEmpty {
            items.append(URLQueryItem(name: "q", value: keyword))
        }
        if let culture, !culture.isEmpty {
            items.append(URLQueryItem(name: "culture", value: culture))
        }
        if let period, !period.isEmpty {
            items.append(URLQueryItem(name: "period", value: period))
        }
        if let classification, !classification.isEmpty {
            items.append(URLQueryItem(name: "classification", value: classification))
        }
        if let hasImage {
            items.append(URLQueryItem(name: "hasimage", value: hasImage ? "1" : "0"))
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
