import Foundation
import TheMet

/// Bridges The Met and National Gallery clients to provide timeline-friendly data for the SwiftUI app.
public struct ArtDataService {
    private let metClient: MetClient
    private let galleryClient: NationalGalleryClient

    public init(metClient: MetClient = MetClient(), galleryClient: NationalGalleryClient = NationalGalleryClient()) {
        self.metClient = metClient
        self.galleryClient = galleryClient
    }

    public func loadTimelineHighlights() async throws -> [ArtTimelineEntry] {
        async let metHighlights = fetchMetHighlights()
        async let galleryHighlights = fetchNationalGalleryHighlights()
        return try await (metHighlights + galleryHighlights)
            .sorted { $0.dateText < $1.dateText }
    }

    public func search(_ term: String) async throws -> [CombinedSearchResult] {
        async let metResults = searchMet(term: term)
        async let galleryResults = searchGallery(term: term)
        return try await (metResults + galleryResults)
            .sorted { $0.title < $1.title }
    }

    public func loadLessons(from entries: [ArtTimelineEntry]) -> [ArtLesson] {
        guard entries.isEmpty == false else { return [] }

        let renaissance = entries.first { $0.dateText.contains("15") || $0.dateText.contains("16") }
        let modern = entries.first { $0.dateText.contains("19") || $0.dateText.contains("20") }

        var lessons: [ArtLesson] = []

        if let renaissance {
            lessons.append(
                ArtLesson(
                    headline: "Renaissance Humanism",
                    overview: "Explore how artists rediscovered classical ideals and experimented with linear perspective during the Renaissance.",
                    takeaway: "Artists moved from symbolic storytelling to human-centered narratives grounded in science and observation.",
                    relatedEntries: [renaissance]
                )
            )
        }

        if let modern {
            lessons.append(
                ArtLesson(
                    headline: "The Rise of Modernism",
                    overview: "Industrialization and global exchange inspired bold experiments in color, abstraction, and new media.",
                    takeaway: "Modern artists challenged tradition, using art to question politics, identity, and rapid technological change.",
                    relatedEntries: [modern]
                )
            )
        }

        return lessons
    }
}

private extension ArtDataService {
    func fetchMetHighlights() async throws -> [ArtTimelineEntry] {
        let searchResults = try await metClient.search(SearchQuery(searchTerm: "highlight", isHighlight: true, hasImages: true, dateBegin: 1200))
        let ids = searchResults.objectIDs.prefix(12)
        return try await withThrowingTaskGroup(of: ArtTimelineEntry?.self) { group in
            for id in ids {
                group.addTask {
                    let object = try await metClient.object(id: id)
                    return ArtTimelineEntry(
                        title: object.title ?? "Untitled",
                        artist: object.artistDisplayName?.isEmpty == false ? object.artistDisplayName! : "Unknown artist",
                        dateText: object.objectDate ?? "",
                        medium: object.medium ?? "",
                        imageURL: URL(string: object.primaryImageSmall ?? object.primaryImage ?? ""),
                        summary: object.classification ?? object.department ?? "",
                        source: .met(id: object.objectID),
                        periodContext: object.period ?? object.dynasty ?? object.culture ?? ""
                    )
                }
            }

            var entries: [ArtTimelineEntry] = []
            for try await entry in group {
                if let entry { entries.append(entry) }
            }
            return entries
        }
    }

    func fetchNationalGalleryHighlights() async throws -> [ArtTimelineEntry] {
        let idsResponse = try await galleryClient.objectIDs(for: NationalGalleryObjectQuery(keyword: "painting", hasImages: true, page: 1, pageSize: 10))
        let ids = idsResponse.objectIDs.prefix(10)

        return try await withThrowingTaskGroup(of: ArtTimelineEntry?.self) { group in
            for id in ids {
                group.addTask {
                    let object = try await galleryClient.object(id: id)
                    return ArtTimelineEntry(
                        title: object.title ?? "Untitled",
                        artist: object.creator ?? "Unknown artist",
                        dateText: object.displayDate ?? "",
                        medium: object.medium ?? "",
                        imageURL: URL(string: object.image ?? ""),
                        summary: object.description ?? object.objectType ?? "",
                        source: .nationalGallery(id: object.id),
                        periodContext: object.department ?? ""
                    )
                }
            }

            var entries: [ArtTimelineEntry] = []
            for try await entry in group {
                if let entry { entries.append(entry) }
            }
            return entries
        }
    }

    func searchMet(term: String) async throws -> [CombinedSearchResult] {
        let response = try await metClient.search(SearchQuery(searchTerm: term, hasImages: true, dateBegin: 1000))
        let ids = response.objectIDs.prefix(6)
        return try await withThrowingTaskGroup(of: CombinedSearchResult?.self) { group in
            for id in ids {
                group.addTask {
                    let object = try await metClient.object(id: id)
                    return CombinedSearchResult(
                        title: object.title ?? "Untitled",
                        subtitle: object.artistDisplayName ?? "Unknown artist",
                        museum: "The Met",
                        imageURL: URL(string: object.primaryImageSmall ?? ""),
                        source: .met(id: object.objectID)
                    )
                }
            }
            var results: [CombinedSearchResult] = []
            for try await result in group {
                if let result { results.append(result) }
            }
            return results
        }
    }

    func searchGallery(term: String) async throws -> [CombinedSearchResult] {
        let idsResponse = try await galleryClient.objectIDs(for: NationalGalleryObjectQuery(keyword: term, hasImages: true, page: 1, pageSize: 6))
        return try await withThrowingTaskGroup(of: CombinedSearchResult?.self) { group in
            for id in idsResponse.objectIDs {
                group.addTask {
                    let object = try await galleryClient.object(id: id)
                    return CombinedSearchResult(
                        title: object.title ?? "Untitled",
                        subtitle: object.creator ?? "Unknown artist",
                        museum: "National Gallery of Art",
                        imageURL: URL(string: object.image ?? ""),
                        source: .nationalGallery(id: object.id)
                    )
                }
            }
            var results: [CombinedSearchResult] = []
            for try await result in group {
                if let result { results.append(result) }
            }
            return results
        }
    }
}
