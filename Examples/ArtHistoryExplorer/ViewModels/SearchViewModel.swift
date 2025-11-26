import Foundation
import SwiftUI

@MainActor
final class SearchViewModel: ObservableObject {
    @Published var query = ""
    @Published var results: [CombinedSearchResult] = []
    @Published var isLoading = false
    @Published var error: String?

    private let service: ArtDataService

    init(service: ArtDataService = ArtDataService()) {
        self.service = service
    }

    func search() {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else {
            results = []
            return
        }

        Task {
            await performSearch(term: trimmed)
        }
    }

    private func performSearch(term: String) async {
        isLoading = true
        error = nil

        do {
            results = try await service.search(term)
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }
}
