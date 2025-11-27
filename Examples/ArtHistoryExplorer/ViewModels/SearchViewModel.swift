import Foundation
import SwiftUI

@MainActor
final class SearchViewModel: ObservableObject {
    @Published var query = ""
    @Published var results: [CombinedSearchResult] = []
    @Published var suggestions: [String] = []
    @Published var relatedPicks: [CombinedSearchResult] = []
    @Published var isLoading = false
    @Published var error: String?

    private let service: ArtDataService
    private var suggestionTask: Task<Void, Never>?
    private var relatedTask: Task<Void, Never>?

    init(service: ArtDataService = ArtDataService()) {
        self.service = service
    }

    deinit {
        suggestionTask?.cancel()
        relatedTask?.cancel()
    }

    func search() {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else {
            results = []
            relatedPicks = []
            return
        }

        Task {
            await performSearch(term: trimmed)
        }
    }

    func updateSuggestions(for term: String) {
        suggestionTask?.cancel()
        let trimmed = term.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 3 else {
            suggestions = []
            return
        }

        suggestionTask = Task { [service] in
            do {
                let suggestions = try await service.suggestions(for: trimmed)
                await MainActor.run {
                    self.suggestions = suggestions
                }
            } catch {
                // Suggestions are a nicety; ignore failures without surfacing an error state.
                await MainActor.run {
                    self.suggestions = []
                }
            }
        }
    }

    private func performSearch(term: String) async {
        isLoading = true
        error = nil
        relatedPicks = []

        do {
            results = try await service.search(term)
            await loadRelatedPicks(from: results)
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    private func loadRelatedPicks(from results: [CombinedSearchResult]) async {
        guard let metID = results.compactMap({ $0.source.metID }).first else { return }

        relatedTask?.cancel()
        relatedTask = Task { [service] in
            do {
                let picks = try await service.relatedMetHighlights(for: metID, limit: 4)
                await MainActor.run {
                    self.relatedPicks = picks
                }
            } catch {
                // Non-fatal: keep the primary results and omit related suggestions on failure.
                await MainActor.run {
                    self.relatedPicks = []
                }
            }
        }
    }
}
