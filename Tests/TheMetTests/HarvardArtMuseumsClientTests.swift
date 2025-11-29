import XCTest
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
@testable import TheMet

final class HarvardArtMuseumsClientTests: XCTestCase {
    func testDecodesObjectIDsResponse() throws {
        let json = """
        {
          "info": {
            "totalrecords": 3,
            "page": 1,
            "pages": 2
          },
          "records": [
            {"objectid": 10},
            {"objectid": 20},
            {"objectid": 30}
          ]
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(HarvardObjectIDsResponse.self, from: json)
        XCTAssertEqual(response.totalRecords, 3)
        XCTAssertEqual(response.totalPages, 2)
        XCTAssertEqual(response.page, 1)
        XCTAssertEqual(response.objectIDs, [10, 20, 30])
    }

    func testDecodesDepartmentResponse() throws {
        let json = """
        {
          "info": {"totalrecords": 1},
          "records": [
            {"id": 1, "name": "Paintings"}
          ]
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(HarvardDepartmentsResponse.self, from: json)
        XCTAssertEqual(response.departments.count, 1)
        XCTAssertEqual(response.departments.first?.name, "Paintings")
    }

    func testDecodesHarvardObject() throws {
        let json = """
        {
          "objectid": 55,
          "title": "Test Object",
          "culture": "American",
          "period": "Modern",
          "classification": "Paintings",
          "dated": "1910",
          "century": "20th century",
          "division": "Modern Art",
          "department": "Paintings",
          "medium": "Oil on canvas",
          "primaryimageurl": "https://example.com/image.jpg",
          "url": "https://example.com/object/55"
        }
        """.data(using: .utf8)!

        let object = try JSONDecoder().decode(HarvardObject.self, from: json)
        XCTAssertEqual(object.id, 55)
        XCTAssertEqual(object.title, "Test Object")
        XCTAssertEqual(object.culture, "American")
        XCTAssertEqual(object.period, "Modern")
        XCTAssertEqual(object.classification, "Paintings")
        XCTAssertEqual(object.primaryImageURL, "https://example.com/image.jpg")
    }

    func testBuildsRichFilterQueryItems() {
        let query = HarvardObjectQuery(
            keyword: "landscape",
            culture: "French",
            period: "Renaissance",
            classification: "Paintings",
            hasImage: true,
            page: 2,
            pageSize: 50
        )

        let items: [String: String] = Dictionary(uniqueKeysWithValues: query.queryItems.compactMap { item in
            guard let value = item.value else { return nil }
            return (item.name, value)
        })

        XCTAssertEqual(items["q"], "landscape")
        XCTAssertEqual(items["culture"], "French")
        XCTAssertEqual(items["period"], "Renaissance")
        XCTAssertEqual(items["classification"], "Paintings")
        XCTAssertEqual(items["hasimage"], "1")
        XCTAssertEqual(items["page"], "2")
        XCTAssertEqual(items["size"], "50")
    }
}
