import XCTest
@testable import TheMet

final class TimelineTests: XCTestCase {
    func testDecodesTimeline() throws {
        let json = """
        [
            {
                "id": "baroque",
                "title": "Baroque",
                "startYear": 1600,
                "endYear": 1750,
                "region": "Europe",
                "movement": "baroque",
                "predominantMedium": "oil",
                "works": [
                    {
                        "objectID": 1,
                        "title": "Self Portrait",
                        "artistDisplayName": "Rembrandt",
                        "year": 1640,
                        "movement": "baroque",
                        "region": "europe",
                        "medium": "oil",
                        "deepLink": { "type": "object", "value": 1 }
                    }
                ]
            }
        ]
        """.data(using: .utf8)!

        let periods = try TimelineDataSource().decode(from: json)
        XCTAssertEqual(periods.count, 1)
        XCTAssertEqual(periods.first?.works.count, 1)
        XCTAssertEqual(periods.first?.works.first?.deepLink.url?.absoluteString, "themet://object/1")
    }

    func testFiltersTimelineStateAndShareableURL() {
        let renaissance = TimelinePeriod(
            id: "renaissance",
            title: "Renaissance",
            startYear: 1400,
            endYear: 1550,
            region: "Europe",
            movement: "renaissance",
            predominantMedium: "oil",
            works: [
                TimelineWork(
                    objectID: 2,
                    title: "Madonna and Child",
                    artistDisplayName: "Unknown",
                    year: 1500,
                    movement: "renaissance",
                    region: "europe",
                    medium: "oil",
                    deepLink: .object(id: 2)
                )
            ]
        )

        let global = TimelinePeriod(
            id: "global",
            title: "Global Contemporary",
            startYear: 1970,
            endYear: 2024,
            region: "Global",
            movement: "contemporary",
            predominantMedium: "mixed media",
            works: [
                TimelineWork(
                    objectID: 3,
                    title: "Installation",
                    artistDisplayName: "Artist",
                    year: 2010,
                    movement: "contemporary",
                    region: "global",
                    medium: "mixed media",
                    deepLink: .custom(URL(string: "https://metmuseum.org/art/collection/search/3")!)
                )
            ]
        )

        let viewModel = TimelineViewModel(periods: [renaissance, global])
        XCTAssertEqual(viewModel.state.works.count, 2)

        let filter = TimelineFilter(
            regions: ["Europe"],
            movements: ["renaissance"],
            mediums: ["oil"],
            dateRange: 1400...1600
        )
        viewModel.updateFilter(filter)

        XCTAssertEqual(viewModel.state.periods.map { $0.id }, ["renaissance"])
        XCTAssertEqual(viewModel.state.works.map { $0.objectID }, [2])

        let baseURL = URL(string: "https://app.example.com/timeline")!
        let url = TimelineDataSource().shareableURL(baseURL: baseURL, filter: filter)
        XCTAssertEqual(url?.absoluteString, "https://app.example.com/timeline?end=1600&mediums=oil&movements=renaissance&regions=europe&start=1400")
    }
}
