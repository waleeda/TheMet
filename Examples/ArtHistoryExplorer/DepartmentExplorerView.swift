import SwiftUI
import TheMet

struct DepartmentExplorerScreen: View {
    @StateObject private var viewModel = DepartmentExplorerViewModel()

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading && viewModel.departments.isEmpty {
                    ProgressView("Loading departments…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                } else if let error = viewModel.error {
                    ContentUnavailableView("Couldn’t load departments", systemImage: "exclamationmark.triangle", description: Text(error))
                } else {
                    List(viewModel.departments, id: \.departmentId) { department in
                        NavigationLink(destination: DepartmentObjectsView(department: department)) {
                            Label(department.displayName, systemImage: "folder")
                        }
                    }
                }
            }
            .navigationTitle("Departments")
            .task { viewModel.loadDepartments() }
            .refreshable { viewModel.loadDepartments() }
        }
    }
}

struct DepartmentObjectsView: View {
    let department: Department
    @StateObject private var viewModel: DepartmentObjectsViewModel

    init(department: Department) {
        self.department = department
        _viewModel = StateObject(wrappedValue: DepartmentObjectsViewModel(department: department))
    }

    var body: some View {
        List {
            if viewModel.isLoading && viewModel.objects.isEmpty {
                Section {
                    ProgressView()
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            } else if let error = viewModel.error {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Couldn’t load objects")
                            .font(.headline)
                        Text(error)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Button("Retry") {
                            viewModel.load()
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 8)
                }
            } else {
                Section(header: Text("Objects (\(viewModel.totalCount))")) {
                    ForEach(viewModel.objects) { result in
                        NavigationLink(destination: ArtworkDetailView(source: result.source)) {
                            SearchResultRow(result: result)
                        }
                    }

                    if viewModel.canLoadMore {
                        loadMoreRow
                    }
                }
            }
        }
        .navigationTitle(department.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .task { viewModel.load() }
        .refreshable { viewModel.load() }
    }

    private var loadMoreRow: some View {
        HStack {
            if viewModel.isLoadingMore {
                ProgressView()
                    .frame(maxWidth: .infinity, alignment: .center)
            } else {
                Button(action: { Task { await viewModel.loadMore() } }) {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.down.circle")
                        Text("Load more objects")
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

#Preview {
    DepartmentExplorerScreen()
}
