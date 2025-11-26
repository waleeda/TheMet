import XCTest
import FoundationNetworking
@testable import TheMet

final class MetClientTests: XCTestCase {
    func testDecodesObjectIDsResponse() throws {
        let json = """
        {"total":3,"objectIDs":[1,2,3]}
        """.data(using: .utf8)!
        let response = try JSONDecoder().decode(ObjectIDsResponse.self, from: json)
        XCTAssertEqual(response.total, 3)
        XCTAssertEqual(response.objectIDs, [1, 2, 3])
    }

    func testDecodesMetObject() throws {
        let json = """
        {
          "objectID": 1,
          "isHighlight": false,
          "accessionNumber": "67.265",
          "accessionYear": "1967",
          "primaryImage": "https://images.metmuseum.org/1.jpg",
          "primaryImageSmall": "https://images.metmuseum.org/1-small.jpg",
          "department": "Asian Art",
          "objectName": "Jar",
          "title": "Blue and White Jar",
          "culture": "China",
          "period": "Ming dynasty",
          "dynasty": "Ming",
          "reign": "Xuande",
          "portfolio": "",
          "artistDisplayName": "Unknown",
          "artistDisplayBio": "",
          "objectDate": "15th century",
          "medium": "Porcelain",
          "dimensions": "H. 10 in.",
          "creditLine": "Gift",
          "geographyType": "",
          "city": "Jingdezhen",
          "state": "",
          "county": "",
          "country": "China",
          "classification": "Ceramics",
          "objectURL": "https://www.metmuseum.org/art/collection/search/1",
          "tags": [{"term": "Ceramics"}]
        }
        """.data(using: .utf8)!
        let object = try JSONDecoder().decode(MetObject.self, from: json)
        XCTAssertEqual(object.objectID, 1)
        XCTAssertEqual(object.title, "Blue and White Jar")
        XCTAssertEqual(object.tags?.first?.term, "Ceramics")
    }

    func testDecodesDepartmentsResponse() throws {
        let json = """
        {
          "departments": [
            {"departmentId": 1, "displayName": "First"},
            {"departmentId": 2, "displayName": "Second"}
          ]
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(DepartmentsResponse.self, from: json)
        XCTAssertEqual(response.departments.count, 2)
        XCTAssertEqual(response.departments.first?.displayName, "First")
        XCTAssertEqual(response.departments.last?.departmentId, 2)
    }

    func testDecodesAutocompleteResponse() throws {
        let json = """
        {"terms":["sun","sunflower","sunset"]}
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(AutocompleteResponse.self, from: json)
        XCTAssertEqual(response.terms, ["sun", "sunflower", "sunset"])
    }

    func testStreamsObjectsForAllIDs() async throws {
        let ids = [4, 5, 6]
        let session = URLSession.mock(respondingWith: { request in
            guard let url = request.url else { throw URLError(.badURL) }
            if (url.absoluteString.contains("/objects") && url.absoluteString.contains("?")) || url.absoluteString.hasSuffix("/objects") {
                let response = ObjectIDsResponse(total: ids.count, objectIDs: ids)
                return try JSONEncoder().encode(response)
            }
            if let id = Int(url.lastPathComponent) {
                let object = MetObject(
                    objectID: id,
                    isHighlight: false,
                    accessionNumber: nil,
                    accessionYear: nil,
                    primaryImage: nil,
                    primaryImageSmall: nil,
                    department: nil,
                    objectName: nil,
                    title: "Object #\(id)",
                    culture: nil,
                    period: nil,
                    dynasty: nil,
                    reign: nil,
                    portfolio: nil,
                    artistDisplayName: nil,
                    artistDisplayBio: nil,
                    objectDate: nil,
                    medium: nil,
                    dimensions: nil,
                    creditLine: nil,
                    geographyType: nil,
                    city: nil,
                    state: nil,
                    county: nil,
                    country: nil,
                    classification: nil,
                    objectURL: nil,
                    tags: nil
                )
                return try JSONEncoder().encode(object)
            }
            throw URLError(.unsupportedURL)
        })

        let client = MetClient(session: session)
        var streamedIDs: Set<Int> = []

        for try await object in client.allObjects(concurrentRequests: 2) {
            streamedIDs.insert(object.objectID)
        }

        XCTAssertEqual(streamedIDs, Set(ids))
    }

    func testFetchesDepartments() async throws {
        let session = URLSession.mock { request in
            guard let url = request.url else { throw URLError(.badURL) }
            XCTAssertEqual(url.absoluteString, "https://collectionapi.metmuseum.org/public/collection/v1/departments")
            let response = DepartmentsResponse(departments: [Department(departmentId: 1, displayName: "European Paintings")])
            return try JSONEncoder().encode(response)
        }

        let client = MetClient(session: session)
        let departments = try await client.departments()

        XCTAssertEqual(departments, [Department(departmentId: 1, displayName: "European Paintings")])
    }

    func testSearchBuildsQueryParameters() async throws {
        let session = URLSession.mock { request in
            guard let url = request.url else { throw URLError(.badURL) }
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            XCTAssertEqual(components?.path, "/public/collection/v1/search")

            let queryItems = components?.queryItems ?? []
            let parameters = Dictionary(uniqueKeysWithValues: queryItems.map { ($0.name, $0.value) })
            XCTAssertEqual(parameters["q"], "flowers")
            XCTAssertEqual(parameters["departmentId"], "5")
            XCTAssertEqual(parameters["hasImages"], "true")

            let response = ObjectIDsResponse(total: 1, objectIDs: [42])
            return try JSONEncoder().encode(response)
        }

        let client = MetClient(session: session)
        let response = try await client.search(SearchQuery(searchTerm: "flowers", hasImages: true, departmentId: 5))

        XCTAssertEqual(response.objectIDs, [42])
        XCTAssertEqual(response.total, 1)
    }

    func testAutocompleteBuildsQueryParameters() async throws {
        let session = URLSession.mock { request in
            guard let url = request.url else { throw URLError(.badURL) }
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            XCTAssertEqual(components?.path, "/public/collection/v1/search/autocomplete")
            let parameters = Dictionary(uniqueKeysWithValues: (components?.queryItems ?? []).map { ($0.name, $0.value) })
            XCTAssertEqual(parameters["q"], "sun")

            let response = AutocompleteResponse(terms: ["sun", "sunflower"])
            return try JSONEncoder().encode(response)
        }

        let client = MetClient(session: session)
        let terms = try await client.autocomplete("sun")

        XCTAssertEqual(terms, ["sun", "sunflower"])
    }

    func testFetchesRelatedObjectIDs() async throws {
        let session = URLSession.mock { request in
            guard let url = request.url else { throw URLError(.badURL) }
            XCTAssertEqual(url.absoluteString, "https://collectionapi.metmuseum.org/public/collection/v1/objects/123/related")
            let response = ObjectIDsResponse(total: 2, objectIDs: [4, 5])
            return try JSONEncoder().encode(response)
        }

        let client = MetClient(session: session)
        let response = try await client.relatedObjectIDs(for: 123)

        XCTAssertEqual(response.objectIDs, [4, 5])
        XCTAssertEqual(response.total, 2)
    }
}

private final class URLProtocolMock: URLProtocol {
    static var responder: ((URLRequest) throws -> Data)?

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let responder = URLProtocolMock.responder else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }

        do {
            let data = try responder(request)
            guard let url = request.url else {
                throw URLError(.badURL)
            }
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

private extension URLSession {
    static func mock(respondingWith responder: @escaping (URLRequest) throws -> Data) -> URLSession {
        URLProtocolMock.responder = responder
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [URLProtocolMock.self]
        return URLSession(configuration: configuration)
    }
}
