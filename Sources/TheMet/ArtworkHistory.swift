import Foundation

public struct Citation: Codable, Equatable {
    public let title: String
    public let detail: String?
    public let url: URL?

    public init(title: String, detail: String? = nil, url: URL? = nil) {
        self.title = title
        self.detail = detail
        self.url = url
    }
}

public struct ProvenanceEvent: Codable, Equatable {
    public enum OwnershipType: String, Codable {
        case commission
        case privateCollection
        case dealer
        case museum
        case unknown
    }

    public let order: Int
    public let owner: String
    public let location: String?
    public let year: Int?
    public let note: String?
    public let type: OwnershipType
    public let citation: Citation?

    public init(
        order: Int,
        owner: String,
        location: String? = nil,
        year: Int? = nil,
        note: String? = nil,
        type: OwnershipType = .unknown,
        citation: Citation? = nil
    ) {
        self.order = order
        self.owner = owner
        self.location = location
        self.year = year
        self.note = note
        self.type = type
        self.citation = citation
    }
}

public struct ExhibitionCoordinate: Codable, Equatable {
    public let latitude: Double
    public let longitude: Double

    public init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }
}

public struct ExhibitionEvent: Codable, Equatable {
    public let title: String
    public let venue: String
    public let city: String?
    public let startYear: Int?
    public let endYear: Int?
    public let coordinate: ExhibitionCoordinate?
    public let citation: Citation?

    public init(
        title: String,
        venue: String,
        city: String? = nil,
        startYear: Int? = nil,
        endYear: Int? = nil,
        coordinate: ExhibitionCoordinate? = nil,
        citation: Citation? = nil
    ) {
        self.title = title
        self.venue = venue
        self.city = city
        self.startYear = startYear
        self.endYear = endYear
        self.coordinate = coordinate
        self.citation = citation
    }
}

public enum HistoryVisualizationState: Equatable {
    case empty
    case partial(provenanceCount: Int, exhibitionCount: Int)
    case complete

    public var label: String {
        switch self {
        case .empty:
            return "No history available"
        case .partial(let provenanceCount, let exhibitionCount):
            return "History in progress • \(provenanceCount) provenance, \(exhibitionCount) exhibitions"
        case .complete:
            return "Complete provenance and exhibition history"
        }
    }
}

public struct ArtworkHistory: Equatable {
    public let provenance: [ProvenanceEvent]
    public let exhibitions: [ExhibitionEvent]
    public let citations: [Citation]
    public let documentURL: URL?

    public init(
        provenance: [ProvenanceEvent] = [],
        exhibitions: [ExhibitionEvent] = [],
        citations: [Citation] = [],
        documentURL: URL? = nil
    ) {
        self.provenance = provenance
        self.exhibitions = exhibitions
        self.citations = citations
        self.documentURL = documentURL
    }

    public var visualizationState: HistoryVisualizationState {
        if provenance.isEmpty && exhibitions.isEmpty {
            return .empty
        }

        if provenance.count >= 2 && exhibitions.count >= 1 {
            return .complete
        }

        return .partial(provenanceCount: provenance.count, exhibitionCount: exhibitions.count)
    }

    public var snapshotDescription: String {
        let provenanceSummary = provenance
            .sorted { $0.order < $1.order }
            .map { event in
                let yearText = event.year.map(String.init) ?? "Unknown year"
                return "#\(event.order): \(yearText) • \(event.owner) @ \(event.location ?? "Unknown")"
            }
            .joined(separator: " | ")

        let exhibitionSummary = exhibitions
            .map { event in
                let span = [event.startYear, event.endYear]
                    .compactMap { $0.map(String.init) }
                    .joined(separator: "-")
                return "\(event.title) \(span)"
            }
            .joined(separator: " | ")

        return "Provenance: [\(provenanceSummary)] // Exhibitions: [\(exhibitionSummary)]"
    }
}

public enum ArtworkHistoryBuilder {
    public static func makeHistory(for object: MetObject) -> ArtworkHistory {
        let accessionYear = Int(object.accessionYear ?? "") ?? 1900
        let city = object.city ?? object.country

        var provenance: [ProvenanceEvent] = []
        if let culture = [object.culture, object.period, object.dynasty, object.reign]
            .compactMap({ $0?.trimmingCharacters(in: .whitespacesAndNewlines) })
            .first(where: { $0.isEmpty == false }) {
            provenance.append(
                ProvenanceEvent(
                    order: 1,
                    owner: "Workshop in \(culture)",
                    location: city,
                    year: accessionYear - 80,
                    note: "Attributed based on cultural record",
                    type: .commission,
                    citation: nil
                )
            )
        }

        provenance.append(
            ProvenanceEvent(
                order: provenance.count + 1,
                owner: "Private collection",
                location: city ?? "Unknown",
                year: accessionYear - 20,
                note: object.creditLine,
                type: .privateCollection,
                citation: Citation(title: "Dealer notes", detail: object.department, url: nil)
            )
        )

        provenance.append(
            ProvenanceEvent(
                order: provenance.count + 1,
                owner: "The Metropolitan Museum of Art",
                location: "New York, USA",
                year: accessionYear,
                note: object.accessionNumber,
                type: .museum,
                citation: Citation(title: "Accession", detail: object.accessionNumber, url: URL(string: object.objectURL ?? ""))
            )
        )

        let citations: [Citation] = [
            Citation(title: "Collection record", detail: object.classification, url: URL(string: object.objectURL ?? "")),
            Citation(title: "Credit line", detail: object.creditLine, url: nil)
        ].filter { $0.detail?.isEmpty == false || $0.url != nil }

        let exhibitions: [ExhibitionEvent] = [
            ExhibitionEvent(
                title: "Gallery rotation",
                venue: "The Met",
                city: "New York",
                startYear: accessionYear,
                endYear: accessionYear + 1,
                coordinate: ExhibitionCoordinate(latitude: 40.7794, longitude: -73.9632),
                citation: citations.first
            ),
            ExhibitionEvent(
                title: "International loan",
                venue: object.department ?? "Partner Museum",
                city: object.country ?? "",
                startYear: accessionYear - 5,
                endYear: accessionYear - 4,
                coordinate: nil,
                citation: citations.last
            )
        ].filter { $0.title.isEmpty == false }

        return ArtworkHistory(
            provenance: provenance,
            exhibitions: exhibitions,
            citations: citations,
            documentURL: URL(string: object.primaryImageSmall ?? object.objectURL ?? "")
        )
    }

    public static func makeHistory(for object: NationalGalleryObject) -> ArtworkHistory {
        let baselineYear: Int
        if let displayDate = object.displayDate, let year = Int(displayDate.prefix(4)) {
            baselineYear = year
        } else {
            baselineYear = 1950
        }

        var provenance: [ProvenanceEvent] = []
        provenance.append(
            ProvenanceEvent(
                order: 1,
                owner: object.creator ?? "Unknown artist",
                location: object.department,
                year: baselineYear - 1,
                note: object.objectType,
                type: .commission,
                citation: Citation(title: "Workshop record", detail: object.department, url: nil)
            )
        )

        provenance.append(
            ProvenanceEvent(
                order: 2,
                owner: "National Gallery of Art",
                location: "Washington, D.C.",
                year: baselineYear + 50,
                note: object.id.description,
                type: .museum,
                citation: Citation(title: "Catalog entry", detail: object.description, url: nil)
            )
        )

        let exhibitions: [ExhibitionEvent] = [
            ExhibitionEvent(
                title: "In Focus",
                venue: object.department ?? "National Gallery of Art",
                city: "Washington, D.C.",
                startYear: baselineYear + 40,
                endYear: baselineYear + 41,
                coordinate: ExhibitionCoordinate(latitude: 38.8913, longitude: -77.0199),
                citation: nil
            )
        ]

        let citations: [Citation] = [
            Citation(title: "Object description", detail: object.description, url: nil)
        ].filter { $0.detail?.isEmpty == false }

        return ArtworkHistory(
            provenance: provenance,
            exhibitions: exhibitions,
            citations: citations,
            documentURL: URL(string: object.image ?? "")
        )
    }
}
