import Foundation

public enum MuseumSource: Equatable {
    case met
    case nationalGallery
}

public enum CrossMuseumClientError: Error, LocalizedError, Equatable {
    case missingMetSearchQuery

    public var errorDescription: String? {
        switch self {
        case .missingMetSearchQuery:
            return "A Met search term is required when searching in Met mode."
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
}

public struct MuseumObjectQuery: Equatable {
    public var met: ObjectQuery?
    public var nationalGallery: NationalGalleryObjectQuery?

    public init(met: ObjectQuery? = nil, nationalGallery: NationalGalleryObjectQuery? = nil) {
        self.met = met
        self.nationalGallery = nationalGallery
    }

    public static func met(_ query: ObjectQuery) -> MuseumObjectQuery {
        MuseumObjectQuery(met: query)
    }

    public static func nationalGallery(_ query: NationalGalleryObjectQuery) -> MuseumObjectQuery {
        MuseumObjectQuery(nationalGallery: query)
    }
}

public struct MuseumSearchQuery: Equatable {
    public var met: SearchQuery?
    public var nationalGallery: NationalGalleryObjectQuery

    public init(met: SearchQuery? = nil, nationalGallery: NationalGalleryObjectQuery = NationalGalleryObjectQuery()) {
        self.met = met
        self.nationalGallery = nationalGallery
    }

    public static func met(_ query: SearchQuery) -> MuseumSearchQuery {
        MuseumSearchQuery(met: query)
    }

    public static func nationalGallery(_ query: NationalGalleryObjectQuery) -> MuseumSearchQuery {
        MuseumSearchQuery(nationalGallery: query)
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

extension MetClient: MetAPI {}
extension NationalGalleryClient: NationalGalleryAPI {}

public final class CrossMuseumClient {
    public var source: MuseumSource

    private let metClient: any MetAPI
    private let nationalGalleryClient: any NationalGalleryAPI

    public convenience init(source: MuseumSource = .met) {
        self.init(source: source, metClient: MetClient.shared, nationalGalleryClient: NationalGalleryClient.shared)
    }

    init(source: MuseumSource, metClient: any MetAPI, nationalGalleryClient: any NationalGalleryAPI) {
        self.source = source
        self.metClient = metClient
        self.nationalGalleryClient = nationalGalleryClient
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
        }
    }

    public func search(_ query: MuseumSearchQuery) async throws -> MuseumObjectIDsResponse {
        switch source {
        case .met:
            guard let metQuery = query.met else {
                throw CrossMuseumClientError.missingMetSearchQuery
            }
            let response = try await metClient.search(metQuery)
            return MuseumObjectIDsResponse(museum: .met, total: response.total, objectIDs: response.objectIDs)
        case .nationalGallery:
            let response = try await nationalGalleryClient.objectIDs(for: query.nationalGallery)
            return MuseumObjectIDsResponse(museum: .nationalGallery, total: response.totalRecords, objectIDs: response.objectIDs)
        }
    }

    public func object(id: Int) async throws -> MuseumObject {
        switch source {
        case .met:
            return .met(try await metClient.object(id: id))
        case .nationalGallery:
            return .nationalGallery(try await nationalGalleryClient.object(id: id))
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
