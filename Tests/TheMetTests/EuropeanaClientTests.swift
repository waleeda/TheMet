import Foundation
import FoundationNetworking
import XCTest
@testable import TheMet

final class EuropeanaClientTests: XCTestCase {
    func testSearchBuildsFacetQueries() async throws {
        let expectedResponse = EuropeanaSearchResponse(totalResults: 1, items: [EuropeanaItem(id: "/foo/1")])
        var requestedURL: URL?

        let session = URLSession.mock { request in
            requestedURL = request.url
            return try JSONEncoder().encode(expectedResponse)
        }

        let client = EuropeanaClient(
            apiKey: "test-key",
            session: session,
            retryConfiguration: .init(maxRetries: 0)
        )

        let query = EuropeanaSearchQuery(
            searchTerm: "canal",
            providers: ["Rijksmuseum"],
            mediaTypes: ["IMAGE"],
            years: [1889],
            page: 2,
            pageSize: 5
        )

        let response = try await client.search(query)
        XCTAssertEqual(response, expectedResponse)

        let components = requestedURL.flatMap { URLComponents(url: $0, resolvingAgainstBaseURL: false) }
        let queryItems = components?.queryItems ?? []

        XCTAssertEqual(queryItems.first(where: { $0.name == "wskey" })?.value, "test-key")
        XCTAssertEqual(queryItems.first(where: { $0.name == "query" })?.value, "canal")
        XCTAssertEqual(queryItems.first(where: { $0.name == "profile" })?.value, "rich")
        XCTAssertEqual(queryItems.first(where: { $0.name == "rows" })?.value, "5")
        XCTAssertEqual(queryItems.first(where: { $0.name == "start" })?.value, "5")

        let qfValues = queryItems.filter { $0.name == "qf" }.compactMap { $0.value }
        XCTAssertTrue(qfValues.contains("PROVIDER:\"Rijksmuseum\""))
        XCTAssertTrue(qfValues.contains("TYPE:IMAGE"))
        XCTAssertTrue(qfValues.contains("YEAR:1889"))
    }

    func testNormalizesIIIFImageURLs() {
        let previewItem = EuropeanaItem(id: "/foo/2", edmPreview: ["https://example.org/iiif/resource/info.json"])
        XCTAssertEqual(previewItem.iiifImageURL?.absoluteString, "https://example.org/iiif/resource/full/full/0/default.jpg")

        let manifestItem = EuropeanaItem(id: "/foo/3", edmIiif: ["https://images.org/iiif/asset/manifest"])
        XCTAssertEqual(manifestItem.iiifImageURL?.absoluteString, "https://images.org/iiif/asset/full/full/0/default.jpg")

        let fallbackItem = EuropeanaItem(id: "/foo/4", edmIsShownBy: ["https://images.org/final.jpg"])
        XCTAssertEqual(fallbackItem.iiifImageURL?.absoluteString, "https://images.org/final.jpg")
    }
}

private final class EuropeanaURLProtocolMock: URLProtocol {
    static var responder: ((URLRequest) throws -> (Data, Int))?

    override class func canInit(with request: URLRequest) -> Bool { true }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let responder = EuropeanaURLProtocolMock.responder else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }

        do {
            let (data, statusCode) = try responder(request)
            guard let url = request.url else { throw URLError(.badURL) }
            let response = HTTPURLResponse(url: url, statusCode: statusCode, httpVersion: nil, headerFields: nil)!
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
        EuropeanaURLProtocolMock.responder = { request in
            (try responder(request), 200)
        }
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [EuropeanaURLProtocolMock.self]
        return URLSession(configuration: configuration)
    }
}
