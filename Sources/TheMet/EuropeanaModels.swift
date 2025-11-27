import Foundation
import FoundationNetworking

public struct EuropeanaSearchResponse: Codable, Equatable {
    public let totalResults: Int
    public let items: [EuropeanaItem]
}

public struct EuropeanaItem: Codable, Equatable {
    public let id: String
    public let title: [String]?
    public let guid: String?
    public let dataProvider: [String]?
    public let provider: [String]?
    public let type: String?
    public let year: [Int]?
    public let edmIsShownBy: [String]?
    public let edmPreview: [String]?
    public let edmIiif: [String]?

    public init(
        id: String,
        title: [String]? = nil,
        guid: String? = nil,
        dataProvider: [String]? = nil,
        provider: [String]? = nil,
        type: String? = nil,
        year: [Int]? = nil,
        edmIsShownBy: [String]? = nil,
        edmPreview: [String]? = nil,
        edmIiif: [String]? = nil
    ) {
        self.id = id
        self.title = title
        self.guid = guid
        self.dataProvider = dataProvider
        self.provider = provider
        self.type = type
        self.year = year
        self.edmIsShownBy = edmIsShownBy
        self.edmPreview = edmPreview
        self.edmIiif = edmIiif
    }

    public var displayTitle: String? { title?.first }

    public var iiifImageURL: URL? {
        let candidates = (edmIiif ?? []) + (edmPreview ?? []) + (edmIsShownBy ?? [])
        for candidate in candidates {
            if let url = Self.normalizeIIIFURL(from: candidate) {
                return url
            }
        }
        return nil
    }

    private static func normalizeIIIFURL(from rawValue: String) -> URL? {
        guard !rawValue.isEmpty, var components = URLComponents(string: rawValue) else { return nil }
        let lowercasedPath = components.path.lowercased()
        if lowercasedPath.hasSuffix(".jpg") || lowercasedPath.hasSuffix(".png") || lowercasedPath.hasSuffix("/full/full/0/default.jpg") {
            return components.url
        }

        if lowercasedPath.hasSuffix("/info.json") {
            components.path = String(components.path.dropLast("/info.json".count))
        } else if lowercasedPath.hasSuffix("/manifest") {
            components.path = String(components.path.dropLast("/manifest".count))
        }

        if !components.path.hasSuffix("/") {
            components.path.append("/")
        }
        components.path.append("full/full/0/default.jpg")
        return components.url
    }
}

public struct EuropeanaSearchQuery: Equatable {
    public var searchTerm: String
    public var providers: [String]?
    public var mediaTypes: [String]?
    public var years: [Int]?
    public var page: Int?
    public var pageSize: Int?
    public var profile: String

    public init(
        searchTerm: String,
        providers: [String]? = nil,
        mediaTypes: [String]? = nil,
        years: [Int]? = nil,
        page: Int? = nil,
        pageSize: Int? = nil,
        profile: String = "rich"
    ) {
        self.searchTerm = searchTerm
        self.providers = providers
        self.mediaTypes = mediaTypes
        self.years = years
        self.page = page
        self.pageSize = pageSize
        self.profile = profile
    }

    var queryItems: [URLQueryItem] {
        var items: [URLQueryItem] = [
            URLQueryItem(name: "query", value: searchTerm),
            URLQueryItem(name: "profile", value: profile)
        ]

        if let providers, !providers.isEmpty {
            items.append(contentsOf: providers.map { URLQueryItem(name: "qf", value: "PROVIDER:\"\($0)\"") })
        }
        if let mediaTypes, !mediaTypes.isEmpty {
            items.append(contentsOf: mediaTypes.map { URLQueryItem(name: "qf", value: "TYPE:\($0)") })
        }
        if let years, !years.isEmpty {
            items.append(contentsOf: years.map { URLQueryItem(name: "qf", value: "YEAR:\($0)") })
        }

        if let pageSize, pageSize > 0 {
            items.append(URLQueryItem(name: "rows", value: String(pageSize)))
            if let page, page > 1 {
                let start = (page - 1) * pageSize
                items.append(URLQueryItem(name: "start", value: String(start)))
            }
        } else if let page, page > 1 {
            let start = (page - 1) * 12
            items.append(URLQueryItem(name: "start", value: String(start)))
        }

        return items
    }
}
