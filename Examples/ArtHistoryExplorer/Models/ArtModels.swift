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

public struct DepartmentObject: Identifiable, Equatable {
    public let id: Int
    public let title: String
    public let artist: String
    public let dateText: String
    public let medium: String
    public let classification: String
    public let imageURL: URL?
    public let creditLine: String?
    public let objectURL: URL?
    public let metObject: MetObject

    public init(metObject: MetObject) {
        self.id = metObject.objectID
        self.title = metObject.title ?? "Untitled"
        self.artist = metObject.artistDisplayName?.isEmpty == false ? metObject.artistDisplayName! : "Unknown artist"
        self.dateText = metObject.objectDate ?? ""
        self.medium = metObject.medium ?? ""
        self.classification = metObject.classification ?? metObject.objectName ?? ""
        self.imageURL = URL(string: metObject.primaryImageSmall ?? metObject.primaryImage ?? "")
        self.creditLine = metObject.creditLine
        if let urlString = metObject.objectURL, let url = URL(string: urlString) {
            self.objectURL = url
        } else {
            self.objectURL = nil
        }
        self.metObject = metObject
    }
}
