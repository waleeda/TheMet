import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var timelineViewModel: ArtTimelineViewModel
    @EnvironmentObject private var searchViewModel: SearchViewModel

    var body: some View {
        TabView {
            TimelineScreen(viewModel: timelineViewModel)
                .tabItem { Label("Timeline", systemImage: "hourglass") }

            SearchScreen(viewModel: searchViewModel)
                .tabItem { Label("Discover", systemImage: "magnifyingglass") }

            LessonsScreen(lessons: timelineViewModel.lessons)
                .tabItem { Label("Lessons", systemImage: "book") }
        }
    }
}

struct TimelineScreen: View {
    @ObservedObject var viewModel: ArtTimelineViewModel

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading {
                    ProgressView("Building your art timeline…")
                } else if let error = viewModel.error {
                    ContentUnavailableView("Couldn’t load art", systemImage: "exclamationmark.triangle", description: Text(error))
                } else {
                    List(viewModel.timeline) { entry in
                        TimelineRow(entry: entry)
                    }
                }
            }
            .navigationTitle("Art Through Time")
        }
    }
}

struct TimelineRow: View {
    let entry: ArtTimelineEntry

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            AsyncImage(url: entry.imageURL) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                ZStack {
                    RoundedRectangle(cornerRadius: 8).fill(.thinMaterial)
                    Image(systemName: "photo")
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 72, height: 72)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 4) {
                Text(entry.title)
                    .font(.headline)
                Text(entry.artist)
                    .font(.subheadline)
                Text("\(entry.dateText) • \(entry.source.displayName)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(entry.summary)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct SearchScreen: View {
    @ObservedObject var viewModel: SearchViewModel

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                TextField("Search by artist, style, or period", text: $viewModel.query)
                    .textFieldStyle(.roundedBorder)
                    .submitLabel(.search)
                    .onChange(of: viewModel.query) { newValue in
                        viewModel.updateSuggestions(for: newValue)
                    }
                    .onSubmit { viewModel.search() }

                if viewModel.isLoading {
                    ProgressView()
                }

                if let error = viewModel.error {
                    ContentUnavailableView("Search failed", systemImage: "questionmark.circle", description: Text(error))
                }

                List {
                    if viewModel.suggestions.isEmpty == false {
                        Section("Suggested searches") {
                            ForEach(viewModel.suggestions, id: \.self) { suggestion in
                                Button {
                                    viewModel.query = suggestion
                                    viewModel.search()
                                } label: {
                                    HStack {
                                        Image(systemName: "lightbulb")
                                        Text(suggestion)
                                    }
                                }
                            }
                        }
                    }

                    Section(viewModel.results.isEmpty ? "" : "Results") {
                        ForEach(viewModel.results) { result in
                            SearchResultRow(result: result)
                        }
                    }

                    if viewModel.relatedPicks.isEmpty == false {
                        Section("Related picks from The Met") {
                            ForEach(viewModel.relatedPicks) { result in
                                SearchResultRow(result: result)
                            }
                        }
                    }
                }
            }
            .padding()
            .navigationTitle("Discover Museums")
        }
    }
}

struct SearchResultRow: View {
    let result: CombinedSearchResult

    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: result.imageURL) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                ZStack {
                    RoundedRectangle(cornerRadius: 8).fill(.thinMaterial)
                    Image(systemName: "photo")
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 64, height: 64)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading) {
                Text(result.title).font(.headline)
                Text(result.subtitle).font(.subheadline)
                Text(result.museum).font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}

struct LessonsScreen: View {
    let lessons: [ArtLesson]

    var body: some View {
        NavigationStack {
            if lessons.isEmpty {
                ContentUnavailableView("Lessons are coming", systemImage: "book.closed", description: Text("Load the timeline to generate personalized lessons."))
            } else {
                List(lessons) { lesson in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(lesson.headline)
                            .font(.headline)
                        Text(lesson.overview)
                            .font(.subheadline)
                        Text("What to remember")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(lesson.takeaway)
                            .font(.footnote)
                        if let highlight = lesson.relatedEntries.first {
                            Text("Featured: \(highlight.title) — \(highlight.source.displayName)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("Lessons")
        }
    }
}
