import Foundation
import SwiftUI

@MainActor
final class ArtTimelineViewModel: ObservableObject {
    @Published var timeline: [ArtTimelineEntry] = []
    @Published var lessons: [ArtLesson] = []
    @Published var isLoading = false
    @Published var error: String?

    private let service: ArtDataService

    init(service: ArtDataService = ArtDataService()) {
        self.service = service
    }

    func load() {
        Task {
            await fetchTimeline()
        }
    }

    private func fetchTimeline() async {
        isLoading = true
        error = nil
        do {
            let entries = try await service.loadTimelineHighlights()
            timeline = entries
            lessons = service.loadLessons(from: entries)
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }
}
