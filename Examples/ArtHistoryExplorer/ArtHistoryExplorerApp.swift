import SwiftUI

@main
struct ArtHistoryExplorerApp: App {
    @StateObject private var timelineViewModel = ArtTimelineViewModel()
    @StateObject private var searchViewModel = SearchViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(timelineViewModel)
                .environmentObject(searchViewModel)
                .task {
                    timelineViewModel.load()
                }
        }
    }
}
