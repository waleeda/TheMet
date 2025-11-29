import XCTest
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
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

    func testDepartmentsCacheRespectsReloadPolicy() async throws {
        let json = """
        {"departments":[{"departmentId":1,"displayName":"First"}]}
        """.data(using: .utf8)!

        var callCount = 0
        let session = URLSession.mock { _ in
            callCount += 1
            return json
        }

        let client = MetClient(session: session)
        let first = try await client.departments()
        let second = try await client.departments()
        _ = try await client.departments(cachePolicy: .reload)

        XCTAssertEqual(first, second)
        XCTAssertEqual(callCount, 2)
    }

    func testObjectCaching() async throws {
        let object = MetObject(
            objectID: 1,
            isHighlight: nil,
            accessionNumber: nil,
            accessionYear: nil,
            primaryImage: nil,
            primaryImageSmall: nil,
            department: nil,
            objectName: nil,
            title: "Cached",
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
            constituents: nil,
            tags: nil
        )

        let encoded = try JSONEncoder().encode(object)
        var callCount = 0
        let session = URLSession.mock { _ in
            callCount += 1
            return encoded
        }

        let client = MetClient(session: session)
        let first = try await client.object(id: 1)
        let second = try await client.object(id: 1)
        let refreshed = try await client.object(id: 1, cachePolicy: .reload)

        XCTAssertEqual(first.title, "Cached")
        XCTAssertEqual(first, second)
        XCTAssertEqual(refreshed.title, "Cached")
        XCTAssertEqual(callCount, 2)
    }

    func testPaginatedSearchSlicesResults() async throws {
        let payload = ObjectIDsResponse(total: 5, objectIDs: [1, 2, 3, 4, 5])
        let json = try JSONEncoder().encode(payload)
        let session = URLSession.mock { _ in json }
        let client = MetClient(session: session)

        let page1 = try await client.search(SearchQuery(searchTerm: "art"), page: 1, pageSize: 2)
        let page2 = try await client.search(SearchQuery(searchTerm: "art"), page: 2, pageSize: 2)

        XCTAssertEqual(page1.objectIDs, [1, 2])
        XCTAssertEqual(page1.page, 1)
        XCTAssertTrue(page1.hasNextPage)

        XCTAssertEqual(page2.objectIDs, [3, 4])
        XCTAssertEqual(page2.page, 2)
    }

    func testSearchValidationRejectsBadDateRange() throws {
        let query = SearchQuery(searchTerm: "art", dateBegin: 2025, dateEnd: 1900)
        XCTAssertThrowsError(try query.validate()) { error in
            XCTAssertEqual(error as? SearchQueryValidationError, .invalidDateRange)
        }
    }

    func testSerializerExposesExpectedFields() {
        let object = MetObject(
            objectID: 99,
            isHighlight: nil,
            accessionNumber: nil,
            accessionYear: nil,
            primaryImage: "large",
            primaryImageSmall: "small",
            department: nil,
            objectName: nil,
            title: "Title",
            culture: nil,
            period: nil,
            dynasty: nil,
            reign: nil,
            portfolio: nil,
            artistDisplayName: nil,
            artistDisplayBio: nil,
            objectDate: "2020",
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
            constituents: [MetConstituent(constituentID: 1, role: "Artist", name: "Name")],
            tags: [MetTag(term: "tag")]
        )

        let normalized = MetObjectSerializer.normalize(object)

        XCTAssertEqual(normalized.objectID, 99)
        XCTAssertEqual(normalized.title, "Title")
        XCTAssertEqual(normalized.objectDate, "2020")
        XCTAssertEqual(normalized.primaryImageSmall, "small")
        XCTAssertEqual(normalized.tags, ["tag"])
        XCTAssertEqual(normalized.constituents.first?.role, "Artist")
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

    func testBuildsObjectQueryFromFiltersEnum() throws {
        var dateComponents = DateComponents()
        dateComponents.calendar = Calendar(identifier: .gregorian)
        dateComponents.year = 2023
        dateComponents.month = 12
        dateComponents.day = 31
        let metadataDate = try XCTUnwrap(dateComponents.date)

        let filters: [MetFilter] = [
            .departmentIds([3, 4]),
            .hasImages(true),
            .searchTerm("portraits"),
            .metadataDate(metadataDate),
            .isHighlight(false),
            .isOnView(true),
            .artistOrCulture(false),
            .medium("Oil"),
            .geoLocation("United States"),
            .dateBegin(1700),
            .dateEnd(1900)
        ]

        let query = ObjectQuery(filters: filters)
        let items = Dictionary<String, String>(uniqueKeysWithValues: query.queryItems.compactMap { item in
            guard let value = item.value else { return nil }
            return (item.name, value)
        })

        XCTAssertEqual(items["departmentIds"], "3|4")
        XCTAssertEqual(items["hasImages"], "true")
        XCTAssertEqual(items["q"], "portraits")
        XCTAssertEqual(items["metadataDate"], "2023-12-31")
        XCTAssertEqual(items["isHighlight"], "false")
        XCTAssertEqual(items["isOnView"], "true")
        XCTAssertEqual(items["artistOrCulture"], "false")
        XCTAssertEqual(items["medium"], "Oil")
        XCTAssertEqual(items["geoLocation"], "United States")
        XCTAssertEqual(items["dateBegin"], "1700")
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

    func testSearchUsingFilters() async throws {
        let session = URLSession.mock { request in
            guard let url = request.url else { throw URLError(.badURL) }
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            XCTAssertEqual(components?.path, "/public/collection/v1/search")

            let queryItems = components?.queryItems ?? []
            let parameters = Dictionary(uniqueKeysWithValues: queryItems.map { ($0.name, $0.value) })

            XCTAssertEqual(parameters["q"], "landscape")
            XCTAssertEqual(parameters["departmentId"], "7")
            XCTAssertEqual(parameters["hasImages"], "true")
            XCTAssertEqual(parameters["dateBegin"], "1850")
            XCTAssertEqual(parameters["dateEnd"], "1900")

            let response = ObjectIDsResponse(total: 2, objectIDs: [101, 102])
            return try JSONEncoder().encode(response)
        }

        let filters: [MetFilter] = [
            .searchTerm("landscape"),
            .departmentId(7),
            .hasImages(true),
            .dateBegin(1850),
            .dateEnd(1900)
        ]

        let client = MetClient(session: session)
        let response = try await client.search(using: filters)

        XCTAssertEqual(response.objectIDs, [101, 102])
        XCTAssertEqual(response.total, 2)
    }

    func testRunsObjectIDsUsingSavedFilters() async throws {
        let library = SavedFilterLibrary()
        library.save([.departmentIds([8, 9]), .hasImages(true)], named: "European Paintings")

        let session = URLSession.mock { request in
            guard let url = request.url else { throw URLError(.badURL) }
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            XCTAssertEqual(components?.path, "/public/collection/v1/objects")

            let parameters = Dictionary(uniqueKeysWithValues: (components?.queryItems ?? []).map { ($0.name, $0.value) })
            XCTAssertEqual(parameters["departmentIds"], "8|9")
            XCTAssertEqual(parameters["hasImages"], "true")

            let response = ObjectIDsResponse(total: 1, objectIDs: [88])
            return try JSONEncoder().encode(response)
        }

        let client = MetClient(session: session)
        let response = try await client.objectIDs(usingSavedFilters: "European Paintings", from: library)

        XCTAssertEqual(response.total, 1)
        XCTAssertEqual(response.objectIDs, [88])
    }

    func testRunsSearchUsingSavedFilters() async throws {
        let filters: [MetFilter] = [.searchTerm("sunrise"), .departmentId(12), .hasImages(false), .dateBegin(1800), .dateEnd(1850)]
        let library = SavedFilterLibrary(savedFilterSets: [SavedFilterSet(name: "Romanticism", filters: filters)])

        let session = URLSession.mock { request in
            guard let url = request.url else { throw URLError(.badURL) }
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            XCTAssertEqual(components?.path, "/public/collection/v1/search")

            let parameters = Dictionary(uniqueKeysWithValues: (components?.queryItems ?? []).map { ($0.name, $0.value) })
            XCTAssertEqual(parameters["q"], "sunrise")
            XCTAssertEqual(parameters["departmentId"], "12")
            XCTAssertEqual(parameters["hasImages"], "false")
            XCTAssertEqual(parameters["dateBegin"], "1800")
            XCTAssertEqual(parameters["dateEnd"], "1850")

            let response = ObjectIDsResponse(total: 3, objectIDs: [11, 12, 13])
            return try JSONEncoder().encode(response)
        }

        let client = MetClient(session: session)
        let response = try await client.search(usingSavedFilters: "Romanticism", from: library)

        XCTAssertEqual(response.total, 3)
        XCTAssertEqual(response.objectIDs, [11, 12, 13])
    }

    func testSavedFiltersSurfaceHelpfulError() async throws {
        let client = MetClient()
        let library = SavedFilterLibrary()

        do {
            _ = try await client.search(usingSavedFilters: "Missing", from: library)
            XCTFail("Expected missing saved filters to throw")
        } catch {
            XCTAssertEqual(error as? SavedFilterError, .missingFilterSet("Missing"))
        }
    }

    func testSavedFilterLibraryStoresAndRemovesFilters() {
        let filters: [MetFilter] = [.searchTerm("portraits"), .hasImages(true), .isOnView(true)]
        let library = SavedFilterLibrary()

        let saved = library.save(filters, named: "Highlights")
        XCTAssertEqual(saved.name, "Highlights")
        XCTAssertEqual(saved.filters, filters)
        XCTAssertEqual(library.filterSet(named: "Highlights"), saved)

        library.save([.searchTerm("landscape")], named: "Landscapes")

        let allSets = library.allFilterSets
        XCTAssertEqual(allSets.count, 2)
        XCTAssertTrue(allSets.contains(saved))

        library.remove(named: "Highlights")
        XCTAssertNil(library.filters(named: "Highlights"))
    }

    func testSearchRequiresSearchTermWhenBuildingFromFilters() throws {
        XCTAssertThrowsError(try SearchQuery(filters: [.hasImages(true)])) { error in
            XCTAssertEqual(error as? SearchQueryError, .missingSearchTerm)
        }
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

    func testDecodesNationalGalleryObjectIDsResponse() throws {
        let json = """
        {"totalRecords":2,"objectIDs":[101,102]}
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(NationalGalleryObjectIDsResponse.self, from: json)

        XCTAssertEqual(response.totalRecords, 2)
        XCTAssertEqual(response.objectIDs, [101, 102])
    }

    func testBuildsNationalGalleryQueryParameters() async throws {
        let session = URLSession.mock { request in
            guard let url = request.url else { throw URLError(.badURL) }
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            XCTAssertEqual(components?.path, "/collection/art/objects")

            let parameters = Dictionary(uniqueKeysWithValues: (components?.queryItems ?? []).map { ($0.name, $0.value) })
            XCTAssertEqual(parameters["q"], "landscape")
            XCTAssertEqual(parameters["classification"], "Painting")
            XCTAssertEqual(parameters["images"], "true")
            XCTAssertEqual(parameters["page"], "2")
            XCTAssertEqual(parameters["size"], "50")

            let response = NationalGalleryObjectIDsResponse(totalRecords: 0, objectIDs: [])
            return try JSONEncoder().encode(response)
        }

        let client = NationalGalleryClient(session: session)
        let response = try await client.objectIDs(for: NationalGalleryObjectQuery(keyword: "landscape", classification: "Painting", hasImages: true, page: 2, pageSize: 50))

        XCTAssertEqual(response.totalRecords, 0)
        XCTAssertEqual(response.objectIDs, [])
    }

    func testFetchesNationalGalleryObject() async throws {
        let session = URLSession.mock { request in
            guard let url = request.url else { throw URLError(.badURL) }
            XCTAssertEqual(url.absoluteString, "https://api.nga.gov/collection/art/objects/501")

            let object = NationalGalleryObject(
                id: 501,
                title: "Sample Painting",
                creator: "Jane Doe",
                displayDate: "1899",
                medium: "Oil on canvas",
                dimensions: "10 x 12 in",
                department: "Paintings",
                objectType: "Painting",
                image: "https://images.nga.gov/501.jpg",
                description: "A sample painting"
            )
            return try JSONEncoder().encode(object)
        }

        let client = NationalGalleryClient(session: session)
        let object = try await client.object(id: 501)

        XCTAssertEqual(object.id, 501)
        XCTAssertEqual(object.title, "Sample Painting")
        XCTAssertEqual(object.creator, "Jane Doe")
        XCTAssertEqual(object.objectType, "Painting")
    }

    func testStreamsNationalGalleryObjectsAcrossPages() async throws {
        let session = URLSession.mock { request in
            guard let url = request.url else { throw URLError(.badURL) }
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false)

            if components?.path == "/collection/art/objects" {
                let queryItems = components?.queryItems ?? []
                let parameters = Dictionary(uniqueKeysWithValues: queryItems.map { ($0.name, $0.value ?? "") })
                let page = Int(parameters["page"] ?? "1") ?? 1

                switch page {
                case 1:
                    return try JSONEncoder().encode(NationalGalleryObjectIDsResponse(totalRecords: 3, objectIDs: [101, 102]))
                case 2:
                    return try JSONEncoder().encode(NationalGalleryObjectIDsResponse(totalRecords: 3, objectIDs: [103]))
                default:
                    return try JSONEncoder().encode(NationalGalleryObjectIDsResponse(totalRecords: 3, objectIDs: []))
                }
            }

            if components?.path.starts(with: "/collection/art/objects/") == true,
               let id = Int(components?.path.split(separator: "/").last ?? "") {
                let object = NationalGalleryObject(
                    id: id,
                    title: "Object #\(id)",
                    creator: nil,
                    displayDate: nil,
                    medium: nil,
                    dimensions: nil,
                    department: nil,
                    objectType: nil,
                    image: nil,
                    description: nil
                )
                return try JSONEncoder().encode(object)
            }

            throw URLError(.unsupportedURL)
        }

        let client = NationalGalleryClient(session: session)
        var streamedIDs: [Int] = []

        for try await object in client.allObjects(pageSize: 2, concurrentRequests: 1) {
            streamedIDs.append(object.id)
        }

        XCTAssertEqual(streamedIDs.sorted(), [101, 102, 103])
    }

    func testNationalGalleryObjectsReportProgress() async throws {
        let ids = [201, 202, 203]
        let session = URLSession.mock { request in
            guard let url = request.url else { throw URLError(.badURL) }
            guard let id = Int(url.lastPathComponent) else { throw URLError(.unsupportedURL) }
            let object = NationalGalleryObject(
                id: id,
                title: "Item #\(id)",
                creator: nil,
                displayDate: nil,
                medium: nil,
                dimensions: nil,
                department: nil,
                objectType: nil,
                image: nil,
                description: nil
            )
            return try JSONEncoder().encode(object)
        }

        let client = NationalGalleryClient(session: session)
        let progressCollector = ProgressCollector()
        var streamedIDs: [Int] = []

        for try await object in client.objects(ids: ids, concurrentRequests: 2, progress: { progress in
            progressCollector.append(progress)
        }) {
            streamedIDs.append(object.id)
        }

        let progressUpdates = progressCollector.snapshot()

        XCTAssertEqual(streamedIDs.sorted(), ids)
        XCTAssertEqual(progressUpdates.map(\.completed), [1, 2, 3])
        XCTAssertEqual(progressUpdates.map(\.total), Array(repeating: ids.count, count: ids.count))
    }

    func testEmitsRetryEventsForHttpStatusCodes() async throws {
        let expectedResponse = ObjectIDsResponse(total: 1, objectIDs: [1])
        var callCount = 0
        let session = URLSession.mock { _ in
            callCount += 1
            if callCount == 1 {
                return (Data(), 429)
            }
            return (try JSONEncoder().encode(expectedResponse), 200)
        }

        let retryEvents = ProgressCollector()
        let client = MetClient(
            session: session,
            retryConfiguration: .init(maxRetries: 1, initialBackoff: 0, backoffMultiplier: 1),
            onRetry: { retryEvents.append($0) }
        )

        let ids = try await client.objectIDs().objectIDs
        let events = retryEvents.retryEventsSnapshot()

        XCTAssertEqual(ids, expectedResponse.objectIDs)
        XCTAssertEqual(events, [RetryEvent(attempt: 1, delay: 0, reason: .httpStatus(429))])
    }

    func testEmitsRetryEventsForTransportErrors() async throws {
        let expectedResponse = ObjectIDsResponse(total: 1, objectIDs: [1])
        var callCount = 0
        let session = URLSession.mock { _ in
            callCount += 1
            if callCount == 1 {
                throw URLError(.timedOut)
            }
            return (try JSONEncoder().encode(expectedResponse), 200)
        }

        let retryEvents = ProgressCollector()
        let client = MetClient(
            session: session,
            retryConfiguration: .init(maxRetries: 1, initialBackoff: 0.01, backoffMultiplier: 1),
            onRetry: { retryEvents.append($0) }
        )

        let ids = try await client.objectIDs().objectIDs
        let events = retryEvents.retryEventsSnapshot()

        XCTAssertEqual(ids, expectedResponse.objectIDs)
        XCTAssertEqual(events, [RetryEvent(attempt: 1, delay: 0.01, reason: .transportError(.timedOut))])
    }
}

private final class URLProtocolMock: URLProtocol {
    static var responder: ((URLRequest) throws -> (Data, Int))?

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
            let (data, statusCode) = try responder(request)
            guard let url = request.url else {
                throw URLError(.badURL)
            }
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
        URLProtocolMock.responder = { request in
            (try responder(request), 200)
        }
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [URLProtocolMock.self]
        return URLSession(configuration: configuration)
    }

    static func mock(respondingWith responder: @escaping (URLRequest) throws -> (Data, Int)) -> URLSession {
        URLProtocolMock.responder = responder
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [URLProtocolMock.self]
        return URLSession(configuration: configuration)
    }
}

private final class ProgressCollector: @unchecked Sendable {
    private let lock = NSLock()
    private var updates: [StreamProgress] = []
    private var retryEvents: [RetryEvent] = []

    func append(_ progress: StreamProgress) {
        lock.lock()
        updates.append(progress)
        lock.unlock()
    }

    func append(_ retryEvent: RetryEvent) {
        lock.lock()
        retryEvents.append(retryEvent)
        lock.unlock()
    }

    func snapshot() -> [StreamProgress] {
        lock.lock()
        let result = updates
        lock.unlock()
        return result
    }

    func retryEventsSnapshot() -> [RetryEvent] {
        lock.lock()
        let result = retryEvents
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
