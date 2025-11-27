import XCTest
@testable import TheMet

final class ArtworkHistoryTests: XCTestCase {
    func testVisualizationStateEmpty() {
        let history = ArtworkHistory()
        XCTAssertEqual(history.visualizationState, .empty)
        XCTAssertTrue(history.snapshotDescription.contains("Provenance: []"))
    }

    func testVisualizationStatePartial() {
        let history = ArtworkHistory(
            provenance: [ProvenanceEvent(order: 1, owner: "Collector")],
            exhibitions: []
        )
        let state = history.visualizationState
        XCTAssertEqual(state, .partial(provenanceCount: 1, exhibitionCount: 0))
        XCTAssertEqual(state.label, "History in progress • 1 provenance, 0 exhibitions")
    }

    func testBuilderCreatesMetHistory() {
        let object = MetObject(
            objectID: 1,
            isHighlight: true,
            accessionNumber: "1970.1",
            accessionYear: "1970",
            primaryImage: nil,
            primaryImageSmall: "https://example.org/image.jpg",
            department: "European Paintings",
            objectName: "Oil on canvas",
            title: "Test Object",
            culture: "Dutch",
            period: "Baroque",
            dynasty: nil,
            reign: nil,
            portfolio: nil,
            artistDisplayName: "Artist Name",
            artistDisplayBio: nil,
            objectDate: "1650",
            medium: "Oil",
            dimensions: "10 x 10",
            creditLine: "Gift of Patron",
            geographyType: nil,
            city: "Amsterdam",
            state: nil,
            county: nil,
            country: "Netherlands",
            classification: "Painting",
            objectURL: "https://metmuseum.org/1",
            tags: nil
        )

        let history = ArtworkHistoryBuilder.makeHistory(for: object)
        XCTAssertEqual(history.provenance.count, 3)
        XCTAssertEqual(history.provenance.last?.owner, "The Metropolitan Museum of Art")
        XCTAssertEqual(history.exhibitions.count, 2)
        XCTAssertEqual(history.visualizationState, .complete)
        XCTAssertTrue(history.snapshotDescription.contains("Amsterdam"))
    }

    func testBuilderCreatesNationalGalleryHistory() {
        let object = NationalGalleryObject(
            id: 10,
            title: "Landscape",
            creator: "Painter",
            displayDate: "1901",
            medium: "Oil",
            dimensions: nil,
            department: "American Art",
            objectType: "Painting",
            image: "https://example.org/nga.jpg",
            description: "A test object"
        )

        let history = ArtworkHistoryBuilder.makeHistory(for: object)
        XCTAssertEqual(history.provenance.first?.owner, "Painter")
        XCTAssertEqual(history.exhibitions.count, 1)
        XCTAssertEqual(history.visualizationState, .complete)
        XCTAssertTrue(history.snapshotDescription.contains("In Focus"))
    }
}
