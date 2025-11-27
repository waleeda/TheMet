import Foundation

public enum TourMode: Equatable {
    case onSite(location: String?)
    case virtual
}

public struct TourRequest: Equatable {
    public var interests: Set<String>
    public var durationMinutes: Int
    public var mode: TourMode
    public var adaPreferred: Bool

    public init(interests: [String], durationMinutes: Int, mode: TourMode, adaPreferred: Bool = false) {
        self.interests = Set(interests.map { $0.lowercased() })
        self.durationMinutes = durationMinutes
        self.mode = mode
        self.adaPreferred = adaPreferred
    }
}

public struct TourArtwork: Equatable {
    public let objectID: Int
    public let title: String
    public let tags: Set<String>
    public let period: String?
    public let medium: String?
    public let estimatedVisitMinutes: Int
    public let adaAccessible: Bool
    public let locationHint: String?

    public init(
        objectID: Int,
        title: String,
        tags: [String],
        period: String? = nil,
        medium: String? = nil,
        estimatedVisitMinutes: Int = 5,
        adaAccessible: Bool = true,
        locationHint: String? = nil
    ) {
        self.objectID = objectID
        self.title = title
        self.tags = Set(tags.map { $0.lowercased() })
        self.period = period
        self.medium = medium
        self.estimatedVisitMinutes = estimatedVisitMinutes
        self.adaAccessible = adaAccessible
        self.locationHint = locationHint
    }
}

public struct TourStop: Equatable {
    public let artwork: TourArtwork
    public let order: Int
}

public struct TourPlan: Equatable {
    public let mode: TourMode
    public let stops: [TourStop]
    public let totalDurationMinutes: Int
    public let adaFriendly: Bool

    public init(mode: TourMode, stops: [TourStop], totalDurationMinutes: Int, adaFriendly: Bool) {
        self.mode = mode
        self.stops = stops
        self.totalDurationMinutes = totalDurationMinutes
        self.adaFriendly = adaFriendly
    }
}

public final class TourGenerator {
    public init() {}

    public func generateTour(from artworks: [TourArtwork], request: TourRequest) -> TourPlan {
        var pool = artworks

        if request.adaPreferred {
            let accessible = pool.filter { $0.adaAccessible }
            if !accessible.isEmpty {
                pool = accessible
            }
        }

        let scoredArtworks: [(artwork: TourArtwork, score: Int)] = pool.compactMap { artwork in
            let score = score(for: artwork, request: request)
            return score > 0 ? (artwork, score) : nil
        }

        let sorted = scoredArtworks.sorted { lhs, rhs in
            if lhs.score == rhs.score {
                return lhs.artwork.objectID < rhs.artwork.objectID
            }
            return lhs.score > rhs.score
        }

        var selectedStops: [TourStop] = []
        var accumulatedMinutes = 0

        for entry in sorted {
            let projected = accumulatedMinutes + entry.artwork.estimatedVisitMinutes
            if projected > request.durationMinutes {
                break
            }
            let stop = TourStop(artwork: entry.artwork, order: selectedStops.count + 1)
            selectedStops.append(stop)
            accumulatedMinutes = projected
        }

        return TourPlan(
            mode: request.mode,
            stops: selectedStops,
            totalDurationMinutes: accumulatedMinutes,
            adaFriendly: request.adaPreferred && selectedStops.allSatisfy { $0.artwork.adaAccessible }
        )
    }

    private func score(for artwork: TourArtwork, request: TourRequest) -> Int {
        var score = 0
        let interestMatches = artwork.tags.intersection(request.interests).count
        score += interestMatches * 3

        if let period = artwork.period?.lowercased(), request.interests.contains(period) {
            score += 2
        }

        if let medium = artwork.medium?.lowercased(), request.interests.contains(medium) {
            score += 1
        }

        if case let .onSite(location) = request.mode, let hint = artwork.locationHint?.lowercased(), let location = location?.lowercased() {
            if hint.contains(location) {
                score += 2
            }
        }

        guard score > 0 else { return 0 }

        if request.adaPreferred && artwork.adaAccessible {
            score += 1
        }

        return score
    }
}

public struct OfflineDownloadBundle: Equatable {
    public let totalSizeBytes: Int
    public let artworks: [TourArtwork]

    public init(totalSizeBytes: Int, artworks: [TourArtwork]) {
        self.totalSizeBytes = totalSizeBytes
        self.artworks = artworks
    }

    public static func estimate(for artworks: [TourArtwork], averageAssetSizeBytes: Int = 1_500_000) -> OfflineDownloadBundle {
        let total = artworks.reduce(0) { partialResult, artwork in
            partialResult + averageAssetSizeBytes + (artwork.tags.count * 2500)
        }
        return OfflineDownloadBundle(totalSizeBytes: total, artworks: artworks)
    }
}
