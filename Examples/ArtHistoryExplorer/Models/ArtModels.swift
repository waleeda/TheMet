import Foundation
import TheMet

public enum ArtworkSource: Equatable, Hashable {
    case met(id: Int)
    case nationalGallery(id: Int)

    public var displayName: String {
        switch self {
        case .met:
            return "The Met"
        case .nationalGallery:
            return "National Gallery of Art"
        }
    }

    public var metID: Int? {
        if case let .met(id) = self { return id }
        return nil
    }
}

public struct ArtTimelineEntry: Identifiable, Equatable {
    public let id = UUID()
    public let title: String
    public let artist: String
    public let dateText: String
    public let medium: String
    public let imageURL: URL?
    public let summary: String
    public let source: ArtworkSource
    public let periodContext: String
}

public struct ArtLesson: Identifiable, Equatable {
    public let id = UUID()
    public let headline: String
    public let overview: String
    public let takeaway: String
    public let relatedEntries: [ArtTimelineEntry]
}

public struct CombinedSearchResult: Identifiable, Equatable {
    public let id = UUID()
    public let title: String
    public let subtitle: String
    public let museum: String
    public let imageURL: URL?
    public let source: ArtworkSource
}

public struct ArtworkDetail: Identifiable, Equatable {
    public let id = UUID()
    public let title: String
    public let artist: String
    public let museum: String
    public let dateText: String
    public let medium: String
    public let culture: String
    public let dimensions: String
    public let creditLine: String
    public let description: String
    public let classification: String
    public let objectName: String
    public let location: String
    public let accessionNumber: String
    public let tags: [String]
    public let objectURL: URL?
    public let imageURL: URL?
    public let source: ArtworkSource
    public let history: ArtworkHistory
}
