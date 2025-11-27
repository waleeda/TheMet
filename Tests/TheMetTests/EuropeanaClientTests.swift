import XCTest
@testable import TheMet

final class EuropeanaClientTests: XCTestCase {
    func testBuildsQueryWithFacets() {
        let query = EuropeanaSearchQuery(
            searchTerm: "impressionism",
            provider: "National Gallery of Denmark",
            mediaType: .image,
            year: "1890",
            page: 2,
            pageSize: 12
        )

        let items = query.queryItems(apiKey: "KEY")
        let dictionary = Dictionary(grouping: items, by: { $0.name }).mapValues { $0.map { $0.value ?? "" } }

        XCTAssertEqual(dictionary["wskey"]?.first, "KEY")
        XCTAssertEqual(dictionary["query"]?.first, "impressionism")
        XCTAssertEqual(dictionary["start"]?.first, "13")
        XCTAssertEqual(dictionary["rows"]?.first, "12")
        XCTAssertEqual(dictionary["facet"] ?? [], ["PROVIDER", "TYPE", "YEAR"])
        XCTAssertTrue(dictionary["qf"]?.contains("PROVIDER:\"National Gallery of Denmark\"") ?? false)
        XCTAssertTrue(dictionary["qf"]?.contains("TYPE:IMAGE") ?? false)
        XCTAssertTrue(dictionary["qf"]?.contains("YEAR:1890") ?? false)
    }

    func testDecodesResponseAndBuildsIiifImage() throws {
        let json = """
        {
          "totalResults": 1,
          "itemsCount": 1,
          "items": [
            {
              "id": "/123/abc",
              "guid": "https://example.org/item/123",
              "title": ["Sample Painting"],
              "provider": ["Europeana"],
              "dataProvider": ["Sample Museum"],
              "type": "IMAGE",
              "year": ["1890"],
              "edmIsShownBy": ["https://example.org/full.jpg"],
              "edmPreview": ["https://example.org/preview.jpg"],
              "aggregations": [
                {
                  "edmIsShownBy": "https://example.org/full-agg.jpg",
                  "edmPreview": "https://example.org/preview-agg.jpg",
                  "iiifBaseUrl": "https://iiif.example.org/iiif/123"
                }
              ]
            }
          ]
        }
        """

        let data = Data(json.utf8)
        let response = try JSONDecoder().decode(EuropeanaSearchResponse.self, from: data)

        XCTAssertEqual(response.totalResults, 1)
        XCTAssertEqual(response.itemsCount, 1)
        let item = try XCTUnwrap(response.items.first)
        XCTAssertEqual(item.title, "Sample Painting")
        XCTAssertEqual(item.provider, "Europeana")
        XCTAssertEqual(item.dataProvider, "Sample Museum")
        XCTAssertEqual(item.mediaType, .image)
        XCTAssertEqual(item.year, "1890")
        XCTAssertEqual(item.previewURL?.absoluteString, "https://example.org/preview.jpg")
        XCTAssertEqual(item.imageURL?.absoluteString, "https://example.org/full.jpg")
        XCTAssertEqual(item.iiifImageURL?.absoluteString, "https://iiif.example.org/iiif/123/full/full/0/default.jpg")
        XCTAssertEqual(item.bestImageURL?.absoluteString, item.iiifImageURL?.absoluteString)
    }
}
