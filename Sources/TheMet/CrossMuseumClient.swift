import Foundation

public enum MuseumSource: Equatable {
    case met
    case nationalGallery
    case europeana
}

public enum CrossMuseumClientError: Error, LocalizedError, Equatable {
    case missingMetSearchQuery
    case missingEuropeanaSearchQuery
    case unsupportedOperation

    public var errorDescription: String? {
        switch self {
        case .missingMetSearchQuery:
            return "A Met search term is required when searching in Met mode."
        case .missingEuropeanaSearchQuery:
            return "A Europeana search query is required when searching in Europeana mode."
        case .unsupportedOperation:
            return "This operation is not supported for the selected museum."
        }
    }
}

public struct MuseumObjectIDsResponse: Equatable {
    public let museum: MuseumSource
    public let total: Int
    public let objectIDs: [Int]

    public init(museum: MuseumSource, total: Int, objectIDs: [Int]) {
        self.museum = museum
        self.total = total
        self.objectIDs = objectIDs
    }
}

public enum MuseumObject: Equatable {
    case met(MetObject)
    case nationalGallery(NationalGalleryObject)
    case europeana(EuropeanaItem)
}

public struct MuseumObjectQuery: Equatable {
    public var met: ObjectQuery?
    public var nationalGallery: NationalGalleryObjectQuery?
    public var europeana: EuropeanaSearchQuery?

    public init(met: ObjectQuery? = nil, nationalGallery: NationalGalleryObjectQuery? = nil, europeana: EuropeanaSearchQuery? = nil) {
        self.met = met
        self.nationalGallery = nationalGallery
        self.europeana = europeana
    }

    public static func met(_ query: ObjectQuery) -> MuseumObjectQuery {
        MuseumObjectQuery(met: query)
    }

    public static func nationalGallery(_ query: NationalGalleryObjectQuery) -> MuseumObjectQuery {
        MuseumObjectQuery(nationalGallery: query)
    }

    public static func europeana(_ query: EuropeanaSearchQuery) -> MuseumObjectQuery {
        MuseumObjectQuery(europeana: query)
    }
}

public struct MuseumSearchQuery: Equatable {
    public var met: SearchQuery?
    public var nationalGallery: NationalGalleryObjectQuery
    public var europeana: EuropeanaSearchQuery?

    public init(
        met: SearchQuery? = nil,
        nationalGallery: NationalGalleryObjectQuery = NationalGalleryObjectQuery(),
        europeana: EuropeanaSearchQuery? = nil
    ) {
        self.met = met
        self.nationalGallery = nationalGallery
        self.europeana = europeana
    }

    public static func met(_ query: SearchQuery) -> MuseumSearchQuery {
        MuseumSearchQuery(met: query)
    }

    public static func nationalGallery(_ query: NationalGalleryObjectQuery) -> MuseumSearchQuery {
        MuseumSearchQuery(nationalGallery: query)
    }

    public static func europeana(_ query: EuropeanaSearchQuery) -> MuseumSearchQuery {
        MuseumSearchQuery(europeana: query)
    }
}

public struct MuseumSearchResponse: Equatable {
    public let museum: MuseumSource
    public let total: Int
    public let objectIDs: [Int]?
    public let europeanaItems: [EuropeanaItem]?

    public init(museum: MuseumSource, total: Int, objectIDs: [Int]? = nil, europeanaItems: [EuropeanaItem]? = nil) {
        self.museum = museum
        self.total = total
        self.objectIDs = objectIDs
        self.europeanaItems = europeanaItems
    }
}

protocol MetAPI {
    func objectIDs(for query: ObjectQuery) async throws -> ObjectIDsResponse
    func search(_ query: SearchQuery) async throws -> ObjectIDsResponse
    func object(id: Int) async throws -> MetObject
    func allObjects(
        concurrentRequests: Int,
        progress: (@Sendable (StreamProgress) -> Void)?,
        cancellation: CooperativeCancellation?
    ) -> AsyncThrowingStream<MetObject, Error>
}

protocol NationalGalleryAPI {
    func objectIDs(for query: NationalGalleryObjectQuery) async throws -> NationalGalleryObjectIDsResponse
    func object(id: Int) async throws -> NationalGalleryObject
    func allObjects(
        query: NationalGalleryObjectQuery,
        pageSize: Int,
        concurrentRequests: Int,
        progress: (@Sendable (StreamProgress) -> Void)?,
        cancellation: CooperativeCancellation?
    ) -> AsyncThrowingStream<NationalGalleryObject, Error>
}

protocol EuropeanaAPI {
    func search(_ query: EuropeanaSearchQuery) async throws -> EuropeanaSearchResponse
}

extension MetClient: MetAPI {}
extension NationalGalleryClient: NationalGalleryAPI {}
extension EuropeanaClient: EuropeanaAPI {}

public final class CrossMuseumClient {
    public var source: MuseumSource

    private let metClient: any MetAPI
    private let nationalGalleryClient: any NationalGalleryAPI
    private let europeanaClient: any EuropeanaAPI

    public convenience init(source: MuseumSource = .met) {
        self.init(
            source: source,
            metClient: MetClient.shared,
            nationalGalleryClient: NationalGalleryClient.shared,
            europeanaClient: EuropeanaClient.shared
        )
    }

    init(source: MuseumSource, metClient: any MetAPI, nationalGalleryClient: any NationalGalleryAPI, europeanaClient: any EuropeanaAPI) {
        self.source = source
        self.metClient = metClient
        self.nationalGalleryClient = nationalGalleryClient
        self.europeanaClient = europeanaClient
    }

    public func objectIDs(for query: MuseumObjectQuery = MuseumObjectQuery()) async throws -> MuseumObjectIDsResponse {
        switch source {
        case .met:
            let metQuery = query.met ?? ObjectQuery()
            let response = try await metClient.objectIDs(for: metQuery)
            return MuseumObjectIDsResponse(museum: .met, total: response.total, objectIDs: response.objectIDs)
        case .nationalGallery:
            let galleryQuery = query.nationalGallery ?? NationalGalleryObjectQuery()
            let response = try await nationalGalleryClient.objectIDs(for: galleryQuery)
            return MuseumObjectIDsResponse(museum: .nationalGallery, total: response.totalRecords, objectIDs: response.objectIDs)
        case .europeana:
            throw CrossMuseumClientError.unsupportedOperation
        }
    }

    public func search(_ query: MuseumSearchQuery) async throws -> MuseumSearchResponse {
        switch source {
        case .met:
            guard let metQuery = query.met else {
                throw CrossMuseumClientError.missingMetSearchQuery
            }
            let response = try await metClient.search(metQuery)
            return MuseumSearchResponse(museum: .met, total: response.total, objectIDs: response.objectIDs)
        case .nationalGallery:
            let response = try await nationalGalleryClient.objectIDs(for: query.nationalGallery)
            return MuseumSearchResponse(museum: .nationalGallery, total: response.totalRecords, objectIDs: response.objectIDs)
        case .europeana:
            guard let europeanaQuery = query.europeana else {
                throw CrossMuseumClientError.missingEuropeanaSearchQuery
            }
            let response = try await europeanaClient.search(europeanaQuery)
            return MuseumSearchResponse(museum: .europeana, total: response.totalResults, europeanaItems: response.items)
        }
    }

    public func object(id: Int) async throws -> MuseumObject {
        switch source {
        case .met:
            return .met(try await metClient.object(id: id))
        case .nationalGallery:
            return .nationalGallery(try await nationalGalleryClient.object(id: id))
        case .europeana:
            throw CrossMuseumClientError.unsupportedOperation
        }
    }

    public func allObjects(
        query: MuseumObjectQuery = MuseumObjectQuery(),
        pageSize: Int = 100,
        concurrentRequests: Int = 6,
        progress: (@Sendable (StreamProgress) -> Void)? = nil,
        cancellation: CooperativeCancellation? = nil
    ) -> AsyncThrowingStream<MuseumObject, Error> {
        switch source {
        case .met:
            return mapMetObjects(
                stream: metClient.allObjects(
                    concurrentRequests: concurrentRequests,
                    progress: progress,
                    cancellation: cancellation
                )
            )
        case .nationalGallery:
            let galleryQuery = query.nationalGallery ?? NationalGalleryObjectQuery()
            return mapNationalGalleryObjects(
                stream: nationalGalleryClient.allObjects(
                    query: galleryQuery,
                    pageSize: pageSize,
                    concurrentRequests: concurrentRequests,
                    progress: progress,
                    cancellation: cancellation
                )
            )
        case .europeana:
            return AsyncThrowingStream { continuation in
                continuation.finish(throwing: CrossMuseumClientError.unsupportedOperation)
            }
        }
    }

    private func mapMetObjects(
        stream: AsyncThrowingStream<MetObject, Error>
    ) -> AsyncThrowingStream<MuseumObject, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    for try await object in stream {
                        continuation.yield(.met(object))
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }

            continuation.onTermination = { @Sendable _ in
                task.cancel()
            }
        }
    }

    private func mapNationalGalleryObjects(
        stream: AsyncThrowingStream<NationalGalleryObject, Error>
    ) -> AsyncThrowingStream<MuseumObject, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    for try await object in stream {
                        continuation.yield(.nationalGallery(object))
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }

            continuation.onTermination = { @Sendable _ in
                task.cancel()
            }
        }
    }
}
