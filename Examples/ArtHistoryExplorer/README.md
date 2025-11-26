# Art History Explorer (Example iOS App)

A SwiftUI sample app that combines The Met Collection API and the National Gallery of Art Collection API to teach art history through a cross-museum timeline, discovery search, and short lessons.

## How it works
- Uses the `ArtDataService` to fetch highlighted works and search results from both museums.
- Builds a chronological timeline of artworks, then derives short lessons (e.g., Renaissance or Modernism) from the loaded items.
- Provides a single search surface that returns combined results from The Met and the National Gallery.

## Running the app
1. In Xcode, create a new iOS App project named **ArtHistoryExplorer** targeting iOS 16 or later.
2. Add this repository as a Swift Package dependency (File > Add Packages… and select the local path or Git URL).
3. Remove the placeholder `ContentView.swift` and replace the generated files with the sources in `Examples/ArtHistoryExplorer/`.
4. Build and run on an iOS 16+ simulator or device. The app will load highlights on launch; use the search tab to explore additional works.

## File overview
- `ArtHistoryExplorerApp.swift`: App entry point wiring up shared view models.
- `ContentView.swift`: Tab-based UI for the timeline, discovery search, and lessons.
- `ViewModels/`: Observable object view models for timeline loading and cross-museum search.
- `Services/ArtDataService.swift`: Bridges `MetClient` and `NationalGalleryClient` into timeline entries, search results, and lightweight lessons.
- `Models/ArtModels.swift`: View-facing data types shared by the UI.
