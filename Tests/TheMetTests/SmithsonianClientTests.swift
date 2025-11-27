import XCTest
@testable import TheMet

final class SmithsonianClientTests: XCTestCase {
    func testBuildsSearchQueryWithFacetsAndCC0() {
        let query = SmithsonianSearchQuery(
            searchTerm: "lincoln",
            topic: "Photography",
            place: "Washington",
            date: "1865",
            rows: 20,
            start: 40,
            mediaUsage: .cc0
        )

        let items = query.queryItems(apiKey: "KEY")
        let dictionary = Dictionary(uniqueKeysWithValues: items.map { ($0.name, $0.value ?? "") })

        XCTAssertEqual(dictionary["api_key"], "KEY")
        XCTAssertEqual(dictionary["media_usage"], SmithsonianMediaUsage.cc0.rawValue)
        XCTAssertEqual(dictionary["rows"], "20")
        XCTAssertEqual(dictionary["start"], "40")
        XCTAssertEqual(
            dictionary["q"],
            "lincoln AND topic:\"Photography\" AND place:\"Washington\" AND date:\"1865\""
        )
    }

    func testDecodesSearchResponseWithMedia() throws {
        let json = """
        {
          "response": {
            "rowCount": 1,
            "start": 0,
            "rows": [
              {
                "id": "edanmdm-siris_sil_123456",
                "title": "Sample Object",
                "summary_label": "Short summary",
                "content": {
                  "descriptiveNonRepeating": {
                    "unit_code": "SIA",
                    "record_link": "https://example.org/record",
                    "title": { "content": "Sample Object" },
                    "online_media": {
                      "mediaCount": 1,
                      "media": [
                        {
                          "idsId": "12345",
                          "guid": "abc",
                          "type": "Images",
                          "caption": "Full view",
                          "thumbnail": "https://ids.si.edu/ids/deliveryService?id=12345&max=150",
                          "content": "https://ids.si.edu/ids/deliveryService?id=12345&max=800",
                          "resources": [
                            { "label": "Original", "idsUrl": "https://ids.si.edu/ids/deliveryService?id=12345" }
                          ]
                        }
                      ]
                    }
                  },
                  "indexedStructured": {
                    "topic": ["Photography"],
                    "place": ["Washington, D.C."],
                    "date": ["1865"]
                  }
                }
              }
            ]
          }
        }
        """

        let data = Data(json.utf8)
        let response = try JSONDecoder().decode(SmithsonianSearchResponse.self, from: data)

        XCTAssertEqual(response.total, 1)
        XCTAssertEqual(response.start, 0)
        XCTAssertEqual(response.rows.first?.unitCode, "SIA")
        XCTAssertEqual(response.rows.first?.topics, ["Photography"])
        XCTAssertEqual(response.rows.first?.places, ["Washington, D.C."])
        XCTAssertEqual(response.rows.first?.dates, ["1865"])
        XCTAssertEqual(response.rows.first?.media.first?.caption, "Full view")
        XCTAssertEqual(
            response.rows.first?.media.first?.bestURL?.absoluteString,
            "https://ids.si.edu/ids/deliveryService?id=12345"
        )
    }

    func testDecodesObjectResponseUsingFreetextNotes() throws {
        let json = """
        {
          "response": {
            "id": "edanmdm-siris_sil_9999",
            "content": {
              "descriptiveNonRepeating": {
                "title": { "content": "Detailed Object" },
                "online_media": { "media": [] }
              },
              "freetext": {
                "topic": [ { "content": "Paintings" } ],
                "place": [ { "content": "Paris" } ],
                "date": [ { "content": "1901" } ],
                "notes": [ { "content": "From the open access set." } ]
              }
            }
          }
        }
        """

        let data = Data(json.utf8)
        let response = try JSONDecoder().decode(SmithsonianObjectResponse.self, from: data)

        XCTAssertEqual(response.object.id, "edanmdm-siris_sil_9999")
        XCTAssertEqual(response.object.title, "Detailed Object")
        XCTAssertEqual(response.object.summary, "From the open access set.")
        XCTAssertEqual(response.object.topics, ["Paintings"])
        XCTAssertEqual(response.object.places, ["Paris"])
        XCTAssertEqual(response.object.dates, ["1901"])
    }
}
