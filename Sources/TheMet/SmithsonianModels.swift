import Foundation

public struct SmithsonianSearchResponse: Decodable, Equatable {
    public let total: Int
    public let start: Int
    public let rows: [SmithsonianObjectSummary]

    public init(total: Int, start: Int, rows: [SmithsonianObjectSummary]) {
        self.total = total
        self.start = start
        self.rows = rows
    }

    enum CodingKeys: String, CodingKey {
        case response
    }

    struct ResponseContainer: Codable {
        let rowCount: Int?
        let numFound: Int?
        let total: Int?
        let start: Int?
        let rows: [SmithsonianRecord]?
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let response = try container.decode(ResponseContainer.self, forKey: .response)

        let count = response.rowCount ?? response.numFound ?? response.total ?? 0
        let start = response.start ?? 0
        let records = response.rows ?? []

        self.total = count
        self.start = start
        self.rows = records.map(SmithsonianObjectSummary.init(record:))
    }
}

public struct SmithsonianObjectResponse: Decodable, Equatable {
    public let object: SmithsonianObject

    enum CodingKeys: String, CodingKey {
        case response
    }

    public init(object: SmithsonianObject) {
        self.object = object
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let record = try container.decode(SmithsonianRecord.self, forKey: .response)
        self.object = SmithsonianObject(record: record)
    }
}

struct SmithsonianRecord: Codable, Equatable {
    let id: String
    let title: String?
    let content: SmithsonianContent?
    let summary: String?

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case content
        case summary = "summary_label"
    }
}

struct SmithsonianContent: Codable, Equatable {
    let descriptiveNonRepeating: SmithsonianDescriptiveNonRepeating?
    let freetext: SmithsonianFreeText?
    let indexedStructured: SmithsonianIndexedStructured?

    enum CodingKeys: String, CodingKey {
        case descriptiveNonRepeating
        case freetext
        case indexedStructured
    }
}

struct SmithsonianDescriptiveNonRepeating: Codable, Equatable {
    let recordID: String?
    let title: SmithsonianTitle?
    let unitCode: String?
    let dataSource: String?
    let recordLink: URL?
    let onlineMedia: SmithsonianOnlineMedia?

    enum CodingKeys: String, CodingKey {
        case recordID = "record_ID"
        case title
        case unitCode = "unit_code"
        case dataSource = "data_source"
        case recordLink = "record_link"
        case onlineMedia = "online_media"
    }
}

struct SmithsonianTitle: Codable, Equatable {
    let content: String?
}

struct SmithsonianOnlineMedia: Codable, Equatable {
    let mediaCount: Int?
    let media: [SmithsonianMedia]?
}

public struct SmithsonianMedia: Codable, Equatable {
    public let id: String?
    public let guid: String?
    public let type: String?
    public let caption: String?
    public let thumbnail: URL?
    public let content: URL?
    public let resources: [SmithsonianMediaResource]?

    enum CodingKeys: String, CodingKey {
        case id = "idsId"
        case guid
        case type
        case caption
        case thumbnail
        case content
        case resources
    }

    public var bestURL: URL? {
        if let resourceURL = resources?.compactMap({ $0.url }).first {
            return resourceURL
        }
        if let content {
            return content
        }
        if let id, let url = URL(string: "https://ids.si.edu/ids/deliveryService?id=\(id)") {
            return url
        }
        return nil
    }
}

public struct SmithsonianMediaResource: Codable, Equatable {
    public let label: String?
    public let url: URL?

    enum CodingKeys: String, CodingKey {
        case label
        case url = "idsUrl"
    }
}

struct SmithsonianIndexedStructured: Codable, Equatable {
    let topic: [String]?
    let date: [String]?
    let place: [String]?
}

struct SmithsonianFreeText: Codable, Equatable {
    let topic: [SmithsonianFreeTextEntry]?
    let place: [SmithsonianFreeTextEntry]?
    let date: [SmithsonianFreeTextEntry]?
    let notes: [SmithsonianFreeTextEntry]?
}

struct SmithsonianFreeTextEntry: Codable, Equatable {
    let content: String?
}

public struct SmithsonianObjectSummary: Equatable {
    public let id: String
    public let title: String?
    public let summary: String?
    public let unitCode: String?
    public let topics: [String]
    public let places: [String]
    public let dates: [String]
    public let media: [SmithsonianMedia]

    init(record: SmithsonianRecord) {
        id = record.id
        title = record.title
            ?? record.content?.descriptiveNonRepeating?.title?.content
        summary = record.summary
        unitCode = record.content?.descriptiveNonRepeating?.unitCode
        topics = record.content?.indexedStructured?.topic
            ?? record.content?.freetext?.topic?.compactMap { $0.content } ?? []
        places = record.content?.indexedStructured?.place
            ?? record.content?.freetext?.place?.compactMap { $0.content } ?? []
        dates = record.content?.indexedStructured?.date
            ?? record.content?.freetext?.date?.compactMap { $0.content } ?? []
        media = record.content?.descriptiveNonRepeating?.onlineMedia?.media ?? []
    }
}

public struct SmithsonianObject: Equatable {
    public let id: String
    public let title: String?
    public let summary: String?
    public let unitCode: String?
    public let topics: [String]
    public let places: [String]
    public let dates: [String]
    public let media: [SmithsonianMedia]
    public let resourceURL: URL?

    init(record: SmithsonianRecord) {
        id = record.id
        title = record.title
            ?? record.content?.descriptiveNonRepeating?.title?.content
        summary = record.summary
            ?? record.content?.freetext?.notes?.first?.content
        unitCode = record.content?.descriptiveNonRepeating?.unitCode
        topics = record.content?.indexedStructured?.topic
            ?? record.content?.freetext?.topic?.compactMap { $0.content } ?? []
        places = record.content?.indexedStructured?.place
            ?? record.content?.freetext?.place?.compactMap { $0.content } ?? []
        dates = record.content?.indexedStructured?.date
            ?? record.content?.freetext?.date?.compactMap { $0.content } ?? []
        media = record.content?.descriptiveNonRepeating?.onlineMedia?.media ?? []
        resourceURL = record.content?.descriptiveNonRepeating?.recordLink
    }
}

public struct SmithsonianSearchQuery: Equatable {
    public var searchTerm: String
    public var topic: String?
    public var place: String?
    public var date: String?
    public var rows: Int?
    public var start: Int?
    public var mediaUsage: SmithsonianMediaUsage

    public init(
        searchTerm: String = "*",
        topic: String? = nil,
        place: String? = nil,
        date: String? = nil,
        rows: Int? = nil,
        start: Int? = nil,
        mediaUsage: SmithsonianMediaUsage = .cc0
    ) {
        self.searchTerm = searchTerm
        self.topic = topic
        self.place = place
        self.date = date
        self.rows = rows
        self.start = start
        self.mediaUsage = mediaUsage
    }

    func queryItems(apiKey: String) -> [URLQueryItem] {
        var clauses: [String] = []
        if let topic, !topic.isEmpty {
            clauses.append("topic:\"\(topic)\"")
        }
        if let place, !place.isEmpty {
            clauses.append("place:\"\(place)\"")
        }
        if let date, !date.isEmpty {
            clauses.append("date:\"\(date)\"")
        }

        var query = searchTerm.isEmpty ? "*" : searchTerm
        if !clauses.isEmpty {
            query += " AND " + clauses.joined(separator: " AND ")
        }

        var items: [URLQueryItem] = [
            URLQueryItem(name: "api_key", value: apiKey),
            URLQueryItem(name: "q", value: query)
        ]

        if mediaUsage != .any {
            items.append(URLQueryItem(name: "media_usage", value: mediaUsage.rawValue))
        }
        if let rows, rows > 0 { items.append(URLQueryItem(name: "rows", value: String(rows))) }
        if let start, start >= 0 { items.append(URLQueryItem(name: "start", value: String(start))) }

        return items
    }
}

public enum SmithsonianMediaUsage: String, Equatable {
    case any
    case cc0 = "CC0"
    case shareAllowCommercial = "CC-BY"
}
