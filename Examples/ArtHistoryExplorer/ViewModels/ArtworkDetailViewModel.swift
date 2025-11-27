import Foundation
import TheMet

@MainActor
final class ArtworkDetailViewModel: ObservableObject {
    @Published var detail: ArtworkDetail?
    @Published var related: [CombinedSearchResult] = []
    @Published var isLoading = false
    @Published var relatedIsLoading = false
    @Published var error: String?

    let source: ArtworkSource

    private let service: ArtDataService
    private var detailTask: Task<Void, Never>?
    private var relatedTask: Task<Void, Never>?

    init(source: ArtworkSource, service: ArtDataService = ArtDataService()) {
        self.source = source
        self.service = service
    }

    deinit {
        detailTask?.cancel()
        relatedTask?.cancel()
    }

    func load() {
        detailTask?.cancel()
        error = nil
        isLoading = true

        detailTask = Task { [service, source] in
            do {
                let detail = try await service.artworkDetail(for: source)
                await MainActor.run {
                    self.detail = detail
                    self.isLoading = false
                }

                if let metID = detail.source.metID {
                    await loadRelated(for: metID)
                }
            } catch {
                await MainActor.run {
                    self.error = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }

    func loadRelated(for metID: Int) async {
        relatedTask?.cancel()
        relatedIsLoading = true

        relatedTask = Task { [service] in
            do {
                let results = try await service.relatedMetObjects(for: metID, limit: 8)
                await MainActor.run {
                    self.related = results
                    self.relatedIsLoading = false
                }
            } catch {
                await MainActor.run {
                    self.related = []
                    self.relatedIsLoading = false
                }
            }
        }
    }
}
