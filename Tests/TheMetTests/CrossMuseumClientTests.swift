import XCTest
@testable import TheMet

private struct StubMetAPI: MetAPI {
    var idsResponse: ObjectIDsResponse
    var searchResponse: ObjectIDsResponse
    var object: MetObject

    func objectIDs(for query: ObjectQuery) async throws -> ObjectIDsResponse { idsResponse }
    func search(_ query: SearchQuery) async throws -> ObjectIDsResponse { searchResponse }
    func object(id: Int) async throws -> MetObject { object }
    func allObjects(
        concurrentRequests: Int,
        progress: (@Sendable (StreamProgress) -> Void)?,
        cancellation: CooperativeCancellation?
    ) -> AsyncThrowingStream<MetObject, Error> {
        AsyncThrowingStream { continuation in
            progress?(StreamProgress(completed: 1, total: 1))
            continuation.yield(object)
            continuation.finish()
        }
    }
}

private struct StubNationalGalleryAPI: NationalGalleryAPI {
    var idsResponse: NationalGalleryObjectIDsResponse
    var object: NationalGalleryObject

    func objectIDs(for query: NationalGalleryObjectQuery) async throws -> NationalGalleryObjectIDsResponse { idsResponse }
    func object(id: Int) async throws -> NationalGalleryObject { object }
    func allObjects(
        query: NationalGalleryObjectQuery,
        pageSize: Int,
        concurrentRequests: Int,
        progress: (@Sendable (StreamProgress) -> Void)?,
        cancellation: CooperativeCancellation?
    ) -> AsyncThrowingStream<NationalGalleryObject, Error> {
        AsyncThrowingStream { continuation in
            progress?(StreamProgress(completed: 1, total: 1))
            continuation.yield(object)
            continuation.finish()
        }
    }
}

private struct StubEuropeanaAPI: EuropeanaAPI {
    var response: EuropeanaSearchResponse

    func search(_ query: EuropeanaSearchQuery) async throws -> EuropeanaSearchResponse { response }
}

final class CrossMuseumClientTests: XCTestCase {
    func testObjectIDsSwitchesMuseums() async throws {
        let met = StubMetAPI(
            idsResponse: ObjectIDsResponse(total: 2, objectIDs: [1, 2]),
            searchResponse: ObjectIDsResponse(total: 0, objectIDs: []),
            object: MetObject(objectID: 1, isHighlight: nil, accessionNumber: nil, accessionYear: nil, primaryImage: nil, primaryImageSmall: nil, department: nil, objectName: nil, title: nil, culture: nil, period: nil, dynasty: nil, reign: nil, portfolio: nil, artistDisplayName: nil, artistDisplayBio: nil, objectDate: nil, medium: nil, dimensions: nil, creditLine: nil, geographyType: nil, city: nil, state: nil, county: nil, country: nil, classification: nil, objectURL: nil, tags: nil)
        )

        let nga = StubNationalGalleryAPI(
            idsResponse: NationalGalleryObjectIDsResponse(totalRecords: 1, objectIDs: [99]),
            object: NationalGalleryObject(
                id: 99,
                title: "Test",
                creator: nil,
                displayDate: nil,
                medium: nil,
                dimensions: nil,
                department: nil,
                objectType: nil,
                image: nil,
                description: nil
            )
        )

        let europeana = StubEuropeanaAPI(response: EuropeanaSearchResponse(totalResults: 0, items: []))

        let client = CrossMuseumClient(source: .met, metClient: met, nationalGalleryClient: nga, europeanaClient: europeana)

        let metIDs = try await client.objectIDs()
        XCTAssertEqual(metIDs.museum, .met)
        XCTAssertEqual(metIDs.total, 2)
        XCTAssertEqual(metIDs.objectIDs, [1, 2])

        client.source = .nationalGallery
        let ngaIDs = try await client.objectIDs()
        XCTAssertEqual(ngaIDs.museum, .nationalGallery)
        XCTAssertEqual(ngaIDs.total, 1)
        XCTAssertEqual(ngaIDs.objectIDs, [99])
    }

    func testSearchRequiresMetQueryWhenInMetMode() async throws {
        let met = StubMetAPI(
            idsResponse: ObjectIDsResponse(total: 0, objectIDs: []),
            searchResponse: ObjectIDsResponse(total: 1, objectIDs: [10]),
            object: MetObject(objectID: 10, isHighlight: nil, accessionNumber: nil, accessionYear: nil, primaryImage: nil, primaryImageSmall: nil, department: nil, objectName: nil, title: nil, culture: nil, period: nil, dynasty: nil, reign: nil, portfolio: nil, artistDisplayName: nil, artistDisplayBio: nil, objectDate: nil, medium: nil, dimensions: nil, creditLine: nil, geographyType: nil, city: nil, state: nil, county: nil, country: nil, classification: nil, objectURL: nil, tags: nil)
        )
        let nga = StubNationalGalleryAPI(
            idsResponse: NationalGalleryObjectIDsResponse(totalRecords: 0, objectIDs: []),
            object: NationalGalleryObject(id: 0, title: nil, creator: nil, displayDate: nil, medium: nil, dimensions: nil, department: nil, objectType: nil, image: nil, description: nil)
        )

        let europeana = StubEuropeanaAPI(response: EuropeanaSearchResponse(totalResults: 0, items: []))

        let client = CrossMuseumClient(source: .met, metClient: met, nationalGalleryClient: nga, europeanaClient: europeana)

        do {
            _ = try await client.search(.nationalGallery(NationalGalleryObjectQuery()))
            XCTFail("Expected Met search query to be required")
        } catch {
            XCTAssertEqual(error as? CrossMuseumClientError, .missingMetSearchQuery)
        }

        let metResults = try await client.search(.met(SearchQuery(searchTerm: "vase")))
        XCTAssertEqual(metResults.objectIDs, [10])
    }

    func testEuropeanaSearchSupportsFacets() async throws {
        let met = StubMetAPI(
            idsResponse: ObjectIDsResponse(total: 0, objectIDs: []),
            searchResponse: ObjectIDsResponse(total: 0, objectIDs: []),
            object: MetObject(
                objectID: 0,
                isHighlight: nil,
                accessionNumber: nil,
                accessionYear: nil,
                primaryImage: nil,
                primaryImageSmall: nil,
                department: nil,
                objectName: nil,
                title: nil,
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
        )
        let nga = StubNationalGalleryAPI(
            idsResponse: NationalGalleryObjectIDsResponse(totalRecords: 0, objectIDs: []),
            object: NationalGalleryObject(id: 0, title: nil, creator: nil, displayDate: nil, medium: nil, dimensions: nil, department: nil, objectType: nil, image: nil, description: nil)
        )

        let expectedItems = [
            EuropeanaItem(id: "/foo/1", title: ["First"], guid: nil, dataProvider: ["Test"], provider: nil, type: "IMAGE", year: [1920], edmIsShownBy: nil, edmPreview: nil, edmIiif: nil),
            EuropeanaItem(id: "/foo/2", title: ["Second"], guid: nil, dataProvider: nil, provider: ["Provider"], type: "SOUND", year: [1889], edmIsShownBy: nil, edmPreview: nil, edmIiif: nil)
        ]

        let europeana = StubEuropeanaAPI(
            response: EuropeanaSearchResponse(
                totalResults: 2,
                items: expectedItems
            )
        )

        let client = CrossMuseumClient(source: .europeana, metClient: met, nationalGalleryClient: nga, europeanaClient: europeana)

        do {
            _ = try await client.search(.met(SearchQuery(searchTerm: "ignored")))
            XCTFail("Expected Europeana query to be required")
        } catch {
            XCTAssertEqual(error as? CrossMuseumClientError, .missingEuropeanaSearchQuery)
        }

        let response = try await client.search(
            .europeana(
                EuropeanaSearchQuery(
                    searchTerm: "posters",
                    providers: ["Smithsonian"],
                    mediaTypes: ["IMAGE"],
                    years: [1920]
                )
            )
        )

        XCTAssertEqual(response.museum, .europeana)
        XCTAssertEqual(response.total, 2)
        XCTAssertEqual(response.europeanaItems, expectedItems)
        XCTAssertNil(response.objectIDs)
    }

    func testStreamsWrapUnderlyingObjects() async throws {
        let met = StubMetAPI(
            idsResponse: ObjectIDsResponse(total: 0, objectIDs: []),
            searchResponse: ObjectIDsResponse(total: 0, objectIDs: []),
            object: MetObject(objectID: 5, isHighlight: nil, accessionNumber: nil, accessionYear: nil, primaryImage: nil, primaryImageSmall: nil, department: nil, objectName: nil, title: "Met", culture: nil, period: nil, dynasty: nil, reign: nil, portfolio: nil, artistDisplayName: nil, artistDisplayBio: nil, objectDate: nil, medium: nil, dimensions: nil, creditLine: nil, geographyType: nil, city: nil, state: nil, county: nil, country: nil, classification: nil, objectURL: nil, tags: nil)
        )
        let nga = StubNationalGalleryAPI(
            idsResponse: NationalGalleryObjectIDsResponse(totalRecords: 0, objectIDs: []),
            object: NationalGalleryObject(id: 6, title: "NGA", creator: nil, displayDate: nil, medium: nil, dimensions: nil, department: nil, objectType: nil, image: nil, description: nil)
        )

        let europeana = StubEuropeanaAPI(response: EuropeanaSearchResponse(totalResults: 0, items: []))

        let client = CrossMuseumClient(source: .met, metClient: met, nationalGalleryClient: nga, europeanaClient: europeana)

        let metProgress = expectation(description: "Met progress")
        metProgress.expectedFulfillmentCount = 1

        var metObjects: [MuseumObject] = []
        for try await object in client.allObjects(progress: { _ in metProgress.fulfill() }) {
            metObjects.append(object)
        }

        XCTAssertEqual(metObjects, [.met(met.object)])
        await fulfillment(of: [metProgress], timeout: 1.0)

        client.source = .nationalGallery
        var ngaObjects: [MuseumObject] = []
        for try await object in client.allObjects(progress: { _ in }) {
            ngaObjects.append(object)
        }

        XCTAssertEqual(ngaObjects, [.nationalGallery(nga.object)])
    }
}
