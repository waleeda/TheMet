import Foundation
import SwiftUI
import TheMet

@MainActor
final class SearchViewModel: ObservableObject {
    @Published var query = ""
    @Published var results: [CombinedSearchResult] = []
    @Published var suggestions: [String] = []
    @Published var relatedPicks: [CombinedSearchResult] = []
    @Published var filters: SearchFilters = .default
    @Published var departments: [Department] = []
    @Published var isLoading = false
    @Published var error: String?
    @Published var downloadProgress: StreamProgress?
    @Published var downloadStatus: String? = "Download The Met collection in the background."
    @Published var downloadError: String?
    @Published var isDownloadingCollection = false
    @Published var downloadedObjects = 0

    private let service: ArtDataService
    private var suggestionTask: Task<Void, Never>?
    private var relatedTask: Task<Void, Never>?
    private var downloadTask: Task<Void, Never>?
    private var isDownloadCancelled = false

    init(service: ArtDataService = ArtDataService()) {
        self.service = service
    }

    deinit {
        suggestionTask?.cancel()
        relatedTask?.cancel()
        downloadTask?.cancel()
    }

    func search() {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else {
            results = []
            relatedPicks = []
            return
        }

        suggestionTask?.cancel()
        suggestions = []

        Task {
            await performSearch(term: trimmed)
        }
    }

    func loadDepartments() {
        Task { [service] in
            do {
                let departments = try await service.metDepartments()
                await MainActor.run {
                    self.departments = departments
                }
            } catch {
                // Non-fatal: keep search usable even if departments cannot load.
            }
        }
    }

    func resetFilters() {
        filters = .default
    }

    func startCollectionDownload() {
        guard isDownloadingCollection == false else { return }

        downloadTask?.cancel()
        downloadError = nil
        downloadStatus = "Requesting object identifiers…"
        downloadProgress = nil
        downloadedObjects = 0
        isDownloadingCollection = true
        isDownloadCancelled = false

        let cancellation = CooperativeCancellation { [weak self] in
            self?.isDownloadCancelled ?? false
        }

        downloadTask = Task { [service] in
            await streamCollection(using: service, cancellation: cancellation)
        }
    }

    func cancelCollectionDownload() {
        guard isDownloadingCollection else { return }
        isDownloadCancelled = true
        downloadTask?.cancel()
        downloadStatus = "Cancelling download…"
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

    func applySuggestion(_ suggestion: String) {
        suggestionTask?.cancel()
        suggestions = []
        query = suggestion
        search()
    }

    var shouldShowSuggestions: Bool {
        suggestions.isEmpty == false && query.trimmingCharacters(in: .whitespacesAndNewlines).count >= 3
    }

    private func performSearch(term: String) async {
        isLoading = true
        error = nil
        relatedPicks = []

        do {
            results = try await service.search(term, filters: filters)
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

    private func streamCollection(using service: ArtDataService, cancellation: CooperativeCancellation) async {
        do {
            for try await object in service.streamFullMetCollection(
                progress: { progress in
                    Task { @MainActor in
                        self.downloadProgress = progress
                        self.downloadStatus = "Downloaded \(progress.completed.formatted()) of \(progress.total.formatted()) objects"
                    }
                },
                cancellation: cancellation
            ) {
                if cancellation.isCancelled { throw CancellationError() }
                try Task.checkCancellation()
                await MainActor.run {
                    self.downloadedObjects += 1
                }
                _ = object
            }

            await MainActor.run {
                self.isDownloadingCollection = false
                self.downloadTask = nil
                self.downloadStatus = "Finished downloading \(downloadedObjects.formatted()) objects."
            }
        } catch is CancellationError {
            await MainActor.run {
                self.isDownloadingCollection = false
                self.downloadTask = nil
                self.downloadStatus = "Download cancelled after \(downloadedObjects.formatted()) objects."
            }
        } catch {
            await MainActor.run {
                self.isDownloadingCollection = false
                self.downloadTask = nil
                self.downloadError = error.localizedDescription
                self.downloadStatus = "Download failed."
            }
        }
    }
}
