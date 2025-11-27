import Foundation

public struct EuropeanaSearchResponse: Decodable, Equatable {
    public let totalResults: Int
    public let itemsCount: Int
    public let items: [EuropeanaItem]

    enum CodingKeys: String, CodingKey {
        case totalResults
        case itemsCount
        case items
    }

    public init(totalResults: Int, itemsCount: Int, items: [EuropeanaItem]) {
        self.totalResults = totalResults
        self.itemsCount = itemsCount
        self.items = items
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        totalResults = try container.decodeIfPresent(Int.self, forKey: .totalResults) ?? 0
        itemsCount = try container.decodeIfPresent(Int.self, forKey: .itemsCount) ?? 0
        items = try container.decodeIfPresent([EuropeanaItem].self, forKey: .items) ?? []
    }
}

public struct EuropeanaItem: Decodable, Equatable {
    public let id: String
    public let guid: URL?
    public let title: String?
    public let provider: String?
    public let dataProvider: String?
    public let mediaType: EuropeanaMediaType?
    public let year: String?
    public let previewURL: URL?
    public let imageURL: URL?
    public let aggregations: [EuropeanaAggregation]

    enum CodingKeys: String, CodingKey {
        case id
        case guid
        case title
        case provider
        case dataProvider
        case type
        case year
        case edmIsShownBy
        case edmPreview
        case aggregations
    }

    public init(
        id: String,
        guid: URL?,
        title: String?,
        provider: String?,
        dataProvider: String?,
        mediaType: EuropeanaMediaType?,
        year: String?,
        previewURL: URL?,
        imageURL: URL?,
        aggregations: [EuropeanaAggregation]
    ) {
        self.id = id
        self.guid = guid
        self.title = title
        self.provider = provider
        self.dataProvider = dataProvider
        self.mediaType = mediaType
        self.year = year
        self.previewURL = previewURL
        self.imageURL = imageURL
        self.aggregations = aggregations
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        guid = try container.decodeIfPresent(URL.self, forKey: .guid)

        let titles = try container.decodeIfPresent([String].self, forKey: .title)
        title = titles?.first

        let providers = try container.decodeIfPresent([String].self, forKey: .provider)
        provider = providers?.first

        let dataProviders = try container.decodeIfPresent([String].self, forKey: .dataProvider)
        dataProvider = dataProviders?.first

        mediaType = try container.decodeIfPresent(EuropeanaMediaType.self, forKey: .type)

        let years = try container.decodeIfPresent([String].self, forKey: .year)
        year = years?.first

        let shownBy = try container.decodeIfPresent([URL].self, forKey: .edmIsShownBy)?.first
        let preview = try container.decodeIfPresent([URL].self, forKey: .edmPreview)?.first

        aggregations = try container.decodeIfPresent([EuropeanaAggregation].self, forKey: .aggregations) ?? []

        previewURL = preview ?? aggregations.compactMap { $0.edmPreview }.first
        imageURL = shownBy ?? aggregations.compactMap { $0.edmIsShownBy }.first
    }

    public var iiifImageURL: URL? {
        if let iiifBaseURL = aggregations.compactMap({ $0.iiifBaseUrl }).first {
            return iiifBaseURL.appendingPathComponent("full/full/0/default.jpg")
        }
        return nil
    }

    public var bestImageURL: URL? {
        if let iiifImageURL { return iiifImageURL }
        if let imageURL { return imageURL }
        return previewURL
    }
}

public struct EuropeanaAggregation: Codable, Equatable {
    public let edmIsShownBy: URL?
    public let edmPreview: URL?
    public let iiifBaseUrl: URL?

    enum CodingKeys: String, CodingKey {
        case edmIsShownBy
        case edmPreview
        case iiifBaseUrl
    }
}

public enum EuropeanaMediaType: String, Codable, Equatable {
    case image = "IMAGE"
    case video = "VIDEO"
    case sound = "SOUND"
    case text = "TEXT"
    case threeD = "3D"
}

public struct EuropeanaSearchQuery: Equatable {
    public var searchTerm: String?
    public var provider: String?
    public var mediaType: EuropeanaMediaType?
    public var year: String?
    public var page: Int
    public var pageSize: Int
    public var mediaRequired: Bool

    public init(
        searchTerm: String? = nil,
        provider: String? = nil,
        mediaType: EuropeanaMediaType? = nil,
        year: String? = nil,
        page: Int = 1,
        pageSize: Int = 24,
        mediaRequired: Bool = true
    ) {
        self.searchTerm = searchTerm
        self.provider = provider
        self.mediaType = mediaType
        self.year = year
        self.page = max(1, page)
        self.pageSize = max(1, pageSize)
        self.mediaRequired = mediaRequired
    }

    func queryItems(apiKey: String) -> [URLQueryItem] {
        var items: [URLQueryItem] = [
            URLQueryItem(name: "wskey", value: apiKey),
            URLQueryItem(name: "profile", value: "rich"),
            URLQueryItem(name: "query", value: searchTerm?.isEmpty == false ? searchTerm : "*"),
            URLQueryItem(name: "start", value: String(((page - 1) * pageSize) + 1)),
            URLQueryItem(name: "rows", value: String(pageSize)),
            URLQueryItem(name: "facet", value: "PROVIDER"),
            URLQueryItem(name: "facet", value: "TYPE"),
            URLQueryItem(name: "facet", value: "YEAR")
        ]

        if mediaRequired {
            items.append(URLQueryItem(name: "media", value: "true"))
        }

        var facetFilters: [String] = []

        if let provider, !provider.isEmpty {
            facetFilters.append("PROVIDER:\"\(provider)\"")
        }

        if let mediaType {
            facetFilters.append("TYPE:\(mediaType.rawValue)")
        }

        if let year, !year.isEmpty {
            facetFilters.append("YEAR:\(year)")
        }

        for filter in facetFilters {
            items.append(URLQueryItem(name: "qf", value: filter))
        }

        return items
    }
}
