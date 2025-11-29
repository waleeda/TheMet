import Foundation

public struct NormalizedMetObject: Equatable {
    public let objectID: Int
    public let title: String?
    public let objectDate: String?
    public let primaryImage: String?
    public let primaryImageSmall: String?
    public let constituents: [NormalizedConstituent]
    public let tags: [String]
}

public struct NormalizedConstituent: Equatable {
    public let constituentID: Int?
    public let name: String?
    public let role: String?
}

public enum MetObjectSerializer {
    public static func normalize(_ object: MetObject) -> NormalizedMetObject {
        NormalizedMetObject(
            objectID: object.objectID,
            title: object.title,
            objectDate: object.objectDate,
            primaryImage: object.primaryImage,
            primaryImageSmall: object.primaryImageSmall,
            constituents: (object.constituents ?? []).map { constituent in
                NormalizedConstituent(
                    constituentID: constituent.constituentID,
                    name: constituent.name,
                    role: constituent.role
                )
            },
            tags: (object.tags ?? []).map(\.term)
        )
    }
}
