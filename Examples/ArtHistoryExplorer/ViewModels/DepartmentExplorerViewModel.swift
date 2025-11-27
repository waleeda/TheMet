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

    func loadDepartmentsIfNeeded() {
        guard departments.isEmpty else { return }
        loadDepartments()
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
                }
            } catch {
                await MainActor.run {
                    self.error = error.localizedDescription
                }
            }

            await MainActor.run {
                self.isLoading = false
            }
        }
    }
}

@MainActor
final class DepartmentObjectsViewModel: ObservableObject {
    @Published var objects: [DepartmentObject] = []
    @Published var isLoading = false
    @Published var error: String?

    let department: Department
    private let service: ArtDataService

    init(department: Department, service: ArtDataService = ArtDataService()) {
        self.department = department
        self.service = service
    }

    func loadObjects() {
        guard isLoading == false else { return }
        isLoading = true
        error = nil

        Task { [service, department] in
            do {
                let objects = try await service.objects(in: department)
                await MainActor.run {
                    self.objects = objects
                }
            } catch {
                await MainActor.run {
                    self.error = error.localizedDescription
                    self.objects = []
                }
            }

            await MainActor.run {
                self.isLoading = false
            }
        }
    }
}
