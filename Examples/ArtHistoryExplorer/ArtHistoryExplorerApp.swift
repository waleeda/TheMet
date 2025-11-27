import SwiftUI

@main
struct ArtHistoryExplorerApp: App {
    @StateObject private var timelineViewModel = ArtTimelineViewModel()
    @StateObject private var searchViewModel = SearchViewModel()
    @StateObject private var departmentViewModel = DepartmentExplorerViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(timelineViewModel)
                .environmentObject(searchViewModel)
                .environmentObject(departmentViewModel)
                .task {
                    timelineViewModel.load()
                }
        }
    }
}
