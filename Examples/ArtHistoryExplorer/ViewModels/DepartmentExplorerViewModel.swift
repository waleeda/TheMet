import Foundation
import TheMet

@MainActor
final class DepartmentExplorerViewModel: ObservableObject {
    @Published var departments: [Department] = []
    @Published var isLoading = false
    @Published var error: String?

    private let service: ArtDataService

    init(service: ArtDataService = ArtDataService()) {
        self.service = service
    }

    func loadDepartments() {
        guard isLoading == false else { return }

        isLoading = true
        error = nil

        Task { [service] in
            do {
                let departments = try await service.metDepartments()
                await MainActor.run {
                    self.departments = departments.sorted { $0.displayName < $1.displayName }
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.error = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }
}

@MainActor
final class DepartmentObjectsViewModel: ObservableObject {
    @Published var objects: [CombinedSearchResult] = []
    @Published var isLoading = false
    @Published var isLoadingMore = false
    @Published var error: String?
    @Published var totalCount = 0

    let department: Department

    private let service: ArtDataService
    private let pageSize = 10
    private var objectIDs: [Int] = []
    private var nextIndex = 0

    init(department: Department, service: ArtDataService = ArtDataService()) {
        self.department = department
        self.service = service
    }

    var canLoadMore: Bool {
        nextIndex < objectIDs.count
    }

    func load() {
        isLoading = true
        error = nil
        objects = []
        objectIDs = []
        nextIndex = 0

        Task { [service, department] in
            do {
                let response = try await service.metObjectIDs(for: department)
                await MainActor.run {
                    self.objectIDs = response.objectIDs
                    self.totalCount = response.total
                }

                await loadMore()
            } catch {
                await MainActor.run {
                    self.error = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }

    func loadMore() async {
        guard canLoadMore else {
            isLoading = false
            isLoadingMore = false
            return
        }

        if isLoading == false { isLoadingMore = true }

        let slice = Array(objectIDs[nextIndex..<min(objectIDs.count, nextIndex + pageSize)])

        do {
            let results = try await service.metObjects(for: slice)
            objects.append(contentsOf: results)
            nextIndex += slice.count
            isLoading = false
            isLoadingMore = false
        } catch {
            error = error.localizedDescription
            isLoading = false
            isLoadingMore = false
        }
    }
}
