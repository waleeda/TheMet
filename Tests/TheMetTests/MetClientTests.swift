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

    func testBuildsObjectQueryWithExtendedFilters() throws {
        var dateComponents = DateComponents()
        dateComponents.calendar = Calendar(identifier: .gregorian)
        dateComponents.year = 2024
        dateComponents.month = 1
        dateComponents.day = 2
        let metadataDate = try XCTUnwrap(dateComponents.date)

        let query = ObjectQuery(
            departmentIds: [1, 2],
            hasImages: true,
            searchQuery: "flowers",
            metadataDate: metadataDate,
            isHighlight: true,
            isOnView: false,
            artistOrCulture: true,
            medium: "Oil",
            geoLocation: "Europe",
            dateBegin: 1800,
            dateEnd: 1900
        )

        let items = Dictionary<String, String>(uniqueKeysWithValues: query.queryItems.compactMap { item in
            guard let value = item.value else { return nil }
            return (item.name, value)
        })

        XCTAssertEqual(items["departmentIds"], "1|2")
        XCTAssertEqual(items["hasImages"], "true")
        XCTAssertEqual(items["q"], "flowers")
        XCTAssertEqual(items["metadataDate"], "2024-01-02")
        XCTAssertEqual(items["isHighlight"], "true")
        XCTAssertEqual(items["isOnView"], "false")
        XCTAssertEqual(items["artistOrCulture"], "true")
        XCTAssertEqual(items["medium"], "Oil")
        XCTAssertEqual(items["geoLocation"], "Europe")
        XCTAssertEqual(items["dateBegin"], "1800")
        XCTAssertEqual(items["dateEnd"], "1900")
    }

    func testConfiguresDecoderStrategiesWhenNoCustomDecoderProvided() throws {
        let client = MetClient(
            decodingStrategies: .init(
                dateDecodingStrategy: .iso8601,
                dataDecodingStrategy: .deferredToData,
                nonConformingFloatDecodingStrategy: .convertFromString(
                    positiveInfinity: "INF",
                    negativeInfinity: "-INF",
                    nan: "NaN"
                ),
                keyDecodingStrategy: .convertFromSnakeCase
            )
        )

        switch client.decoder.dateDecodingStrategy {
        case .iso8601:
            break
        default:
            XCTFail("Expected ISO8601 date decoding strategy")
        }

        switch client.decoder.dataDecodingStrategy {
        case .deferredToData:
            break
        default:
            XCTFail("Expected deferredToData decoding strategy")
        }

        switch client.decoder.nonConformingFloatDecodingStrategy {
        case .convertFromString(positiveInfinity: "INF", negativeInfinity: "-INF", nan: "NaN"):
            break
        default:
            XCTFail("Expected custom non-conforming float decoding strategy")
        }

        switch client.decoder.keyDecodingStrategy {
        case .convertFromSnakeCase:
            break
        default:
            XCTFail("Expected convertFromSnakeCase decoding strategy")
        }
    }

    func testUsesInjectedDecoderDirectlyWhenProvided() throws {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        let client = MetClient(decoder: decoder, decodingStrategies: .init(dateDecodingStrategy: .iso8601))

        switch client.decoder.dateDecodingStrategy {
        case .secondsSince1970:
            break
        default:
            XCTFail("Injected decoder should not be overridden")
        }

        switch client.decoder.keyDecodingStrategy {
        case .convertFromSnakeCase:
            break
        default:
            XCTFail("Injected decoder should retain its key decoding strategy")
        }
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

    func testReportsProgressWhileStreamingObjects() async throws {
        let ids = [1, 2, 3]
        let session = URLSession.mock(respondingWith: { request in
            guard let url = request.url else { throw URLError(.badURL) }
            guard let id = Int(url.lastPathComponent) else { throw URLError(.unsupportedURL) }
            let object = MetObject(
                objectID: id,
                isHighlight: nil,
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
        })

        let client = MetClient(session: session)
        let progressCollector = ProgressCollector()
        var streamedIDs: [Int] = []

        for try await object in client.objects(ids: ids, concurrentRequests: 2, progress: { progress in
            progressCollector.append(progress)
        }) {
            streamedIDs.append(object.objectID)
        }

        let progressUpdates = progressCollector.snapshot()

        XCTAssertEqual(streamedIDs.sorted(), ids)
        XCTAssertEqual(progressUpdates.map(\.completed), [1, 2, 3])
        XCTAssertEqual(progressUpdates.map(\.total), Array(repeating: ids.count, count: ids.count))
    }

    func testStopsStreamingWhenCancelled() async throws {
        let ids = [10, 11, 12]
        let session = URLSession.mock(respondingWith: { request in
            guard let url = request.url else { throw URLError(.badURL) }
            guard let id = Int(url.lastPathComponent) else { throw URLError(.unsupportedURL) }
            let object = MetObject(
                objectID: id,
                isHighlight: nil,
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
        })

        let client = MetClient(session: session)
        var streamedIDs: [Int] = []
        let cancellationFlag = CancellationFlag()

        do {
            for try await object in client.objects(
                ids: ids,
                concurrentRequests: 1,
                cancellation: CooperativeCancellation { cancellationFlag.value }
            ) {
                streamedIDs.append(object.objectID)
                cancellationFlag.cancel()
            }
            XCTFail("Expected stream to cancel after the first object")
        } catch is CancellationError {
            // Expected cancellation
        }

        XCTAssertEqual(streamedIDs, [10])
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

    func testObjectIDsIncludesMetadataDateParameter() async throws {
        var dateComponents = DateComponents()
        dateComponents.year = 2024
        dateComponents.month = 4
        dateComponents.day = 10
        dateComponents.calendar = Calendar(identifier: .gregorian)
        let metadataDate = dateComponents.date!

        let session = URLSession.mock { request in
            guard let url = request.url else { throw URLError(.badURL) }
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            XCTAssertEqual(components?.path, "/public/collection/v1/objects")

            let queryItems = components?.queryItems ?? []
            let parameters = Dictionary(uniqueKeysWithValues: queryItems.map { ($0.name, $0.value) })
            XCTAssertEqual(parameters["metadataDate"], "2024-04-10")

            let response = ObjectIDsResponse(total: 0, objectIDs: [])
            return try JSONEncoder().encode(response)
        }

        let client = MetClient(session: session)
        let response = try await client.objectIDs(for: ObjectQuery(metadataDate: metadataDate))

        XCTAssertEqual(response.objectIDs, [])
        XCTAssertEqual(response.total, 0)
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

private final class ProgressCollector: @unchecked Sendable {
    private let lock = NSLock()
    private var updates: [StreamProgress] = []

    func append(_ progress: StreamProgress) {
        lock.lock()
        updates.append(progress)
        lock.unlock()
    }

    func snapshot() -> [StreamProgress] {
        lock.lock()
        let result = updates
        lock.unlock()
        return result
    }
}

private final class CancellationFlag: @unchecked Sendable {
    private let lock = NSLock()
    private var cancelled = false

    var value: Bool {
        lock.lock()
        let result = cancelled
        lock.unlock()
        return result
    }

    func cancel() {
        lock.lock()
        cancelled = true
        lock.unlock()
    }
}
