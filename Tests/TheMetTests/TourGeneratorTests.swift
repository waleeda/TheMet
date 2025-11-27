import XCTest
@testable import TheMet

final class TourGeneratorTests: XCTestCase {
    func testRanksByInterestsAndRespectsDuration() {
        let artworks = [
            TourArtwork(objectID: 1, title: "Sculpture", tags: ["modern"], period: "modern", medium: "bronze", estimatedVisitMinutes: 12, adaAccessible: true, locationHint: "gallery a"),
            TourArtwork(objectID: 2, title: "Painting", tags: ["impressionism", "color"], period: "impressionism", medium: "oil", estimatedVisitMinutes: 10, adaAccessible: true, locationHint: "gallery b"),
            TourArtwork(objectID: 3, title: "Long Tour", tags: ["renaissance"], period: "renaissance", medium: "fresco", estimatedVisitMinutes: 45, adaAccessible: true, locationHint: "gallery c")
        ]

        let request = TourRequest(interests: ["impressionism", "oil", "modern"], durationMinutes: 25, mode: .virtual)
        let plan = TourGenerator().generateTour(from: artworks, request: request)

        XCTAssertEqual(plan.totalDurationMinutes, 22)
        XCTAssertEqual(plan.stops.map { $0.artwork.objectID }, [2, 1])
        XCTAssertFalse(plan.adaFriendly)
    }

    func testFiltersForADAAndLocation() {
        let artworks = [
            TourArtwork(objectID: 4, title: "Accessible", tags: ["sculpture"], period: "ancient", medium: "stone", estimatedVisitMinutes: 15, adaAccessible: true, locationHint: "wing east"),
            TourArtwork(objectID: 5, title: "Non ADA", tags: ["sculpture"], period: "ancient", medium: "stone", estimatedVisitMinutes: 10, adaAccessible: false, locationHint: "wing east"),
            TourArtwork(objectID: 6, title: "Painting", tags: ["baroque"], period: "baroque", medium: "oil", estimatedVisitMinutes: 8, adaAccessible: true, locationHint: "wing west")
        ]

        let request = TourRequest(interests: ["sculpture"], durationMinutes: 25, mode: .onSite(location: "east"), adaPreferred: true)
        let plan = TourGenerator().generateTour(from: artworks, request: request)

        XCTAssertEqual(plan.stops.map { $0.artwork.objectID }, [4])
        XCTAssertTrue(plan.adaFriendly)
        XCTAssertEqual(plan.totalDurationMinutes, 15)
    }

    func testOfflineDownloadBundleEstimation() {
        let artworks = [
            TourArtwork(objectID: 7, title: "Work", tags: ["color", "light"], estimatedVisitMinutes: 5),
            TourArtwork(objectID: 8, title: "Work 2", tags: ["light"], estimatedVisitMinutes: 5)
        ]

        let bundle = OfflineDownloadBundle.estimate(for: artworks, averageAssetSizeBytes: 1_000_000)
        XCTAssertGreaterThan(bundle.totalSizeBytes, 2_000_000)
        XCTAssertEqual(bundle.artworks.count, 2)
    }
}
