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

    public func search(_ term: String, filters: SearchFilters) async throws -> [CombinedSearchResult] {
        async let metResults = searchMet(term: term, filters: filters)
        async let galleryResults = searchGallery(term: term)
        return try await (metResults + galleryResults)
            .sorted { $0.title < $1.title }
    }

    public func metDepartments() async throws -> [Department] {
        try await metClient.departments()
    }

    public func objects(in department: Department, limit: Int = 24) async throws -> [DepartmentObject] {
        let queries = [
            ObjectQuery(departmentIds: [department.departmentId], hasImages: true, isHighlight: true),
            ObjectQuery(departmentIds: [department.departmentId], hasImages: true, isOnView: true),
            ObjectQuery(departmentIds: [department.departmentId], hasImages: true)
        ]

        for query in queries {
            let ids = try await metClient.objectIDs(for: query).objectIDs.prefix(limit)
            guard ids.isEmpty == false else { continue }

            let objects = try await loadObjects(for: Array(ids))
            if objects.isEmpty == false { return objects }
        }

        return []
    }

    public func suggestions(for term: String) async throws -> [String] {
        let trimmed = term.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 3 else { return [] }
        return try await metClient.autocomplete(trimmed)
    }

    public func relatedMetHighlights(for objectID: Int, limit: Int = 4) async throws -> [CombinedSearchResult] {
        let response = try await metClient.relatedObjectIDs(for: objectID)
        let ids = response.objectIDs.prefix(limit)

        return try await withThrowingTaskGroup(of: CombinedSearchResult?.self) { group in
            for id in ids {
                group.addTask {
                    let object = try await metClient.object(id: id)
                    return CombinedSearchResult(
                        title: object.title ?? "Untitled",
                        subtitle: object.artistDisplayName ?? "Unknown artist",
                        museum: "The Met",
                        imageURL: URL(string: object.primaryImageSmall ?? object.primaryImage ?? ""),
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

    public func streamFullMetCollection(
        concurrentRequests: Int = 6,
        progress: (@Sendable (StreamProgress) -> Void)? = nil,
        cancellation: CooperativeCancellation? = nil
    ) -> AsyncThrowingStream<MetObject, Error> {
        metClient.allObjects(
            concurrentRequests: concurrentRequests,
            progress: progress,
            cancellation: cancellation
        )
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
    func loadObjects(for ids: [Int]) async throws -> [DepartmentObject] {
        try await withThrowingTaskGroup(of: DepartmentObject?.self) { group in
            for id in ids {
                group.addTask {
                    let object = try await metClient.object(id: id)
                    return DepartmentObject(metObject: object)
                }
            }

            var objects: [DepartmentObject] = []
            for try await object in group {
                if let object { objects.append(object) }
            }
            return objects.sorted { $0.title < $1.title }
        }
    }

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

    func searchMet(term: String, filters: SearchFilters) async throws -> [CombinedSearchResult] {
        let query = SearchQuery(
            searchTerm: term,
            isHighlight: filters.highlightsOnly ? true : nil,
            hasImages: filters.requiresImages ? true : nil,
            departmentId: filters.departmentId,
            isOnView: filters.onViewOnly ? true : nil,
            artistOrCulture: filters.artistOrCultureOnly ? true : nil,
            medium: filters.medium.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : filters.medium,
            geoLocation: filters.geoLocation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : filters.geoLocation,
            dateBegin: filters.parsedDateBegin,
            dateEnd: filters.parsedDateEnd
        )

        let response = try await metClient.search(query)
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
