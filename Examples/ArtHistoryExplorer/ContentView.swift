import SwiftUI
import TheMet

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
                VStack(alignment: .leading, spacing: 8) {
                    TextField("Search by artist, style, or period", text: $viewModel.query)
                        .textFieldStyle(.roundedBorder)
                        .submitLabel(.search)
                        .onChange(of: viewModel.query) { newValue in
                            viewModel.updateSuggestions(for: newValue)
                        }
                        .onSubmit { viewModel.search() }

                    if viewModel.shouldShowSuggestions {
                        AutocompleteSuggestionList(suggestions: viewModel.suggestions) { suggestion in
                            viewModel.applySuggestion(suggestion)
                        }
                        .transition(.opacity)
                    }
                }

                FilterControls(filters: $viewModel.filters, departments: viewModel.departments, onReset: viewModel.resetFilters)

                CollectionDownloadCard(viewModel: viewModel)

                if viewModel.isLoading {
                    ProgressView()
                }

                if let error = viewModel.error {
                    ContentUnavailableView("Search failed", systemImage: "questionmark.circle", description: Text(error))
                }

                List {
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
            .task { viewModel.loadDepartments() }
        }
    }
}

struct AutocompleteSuggestionList: View {
    let suggestions: [String]
    var onSelect: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(suggestions.enumerated()), id: \.offset) { index, suggestion in
                Button(action: { onSelect(suggestion) }) {
                    HStack(spacing: 8) {
                        Image(systemName: "sparkle.magnifyingglass")
                            .foregroundStyle(.secondary)
                        Text(suggestion)
                            .foregroundStyle(.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                }
                .buttonStyle(.plain)

                if index < suggestions.count - 1 {
                    Divider()
                }
            }
        }
        .background(RoundedRectangle(cornerRadius: 10).fill(.thickMaterial))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.gray.opacity(0.2))
        )
        .shadow(color: Color.black.opacity(0.08), radius: 6, x: 0, y: 4)
    }
}

struct CollectionDownloadCard: View {
    @ObservedObject var viewModel: SearchViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "arrow.down.circle")
                    .font(.title2)
                    .foregroundStyle(.blue)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Download the collection")
                        .font(.headline)
                    Text("Stream every object from The Met in the background with progress updates and cancellation.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            if let status = viewModel.downloadStatus {
                Text(status)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if let progress = viewModel.downloadProgress {
                ProgressView(value: Double(progress.completed), total: Double(progress.total))
            } else if viewModel.isDownloadingCollection {
                ProgressView()
            }

            if let error = viewModel.downloadError {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }

            HStack {
                Button(action: viewModel.startCollectionDownload) {
                    Label("Download the collection", systemImage: "arrow.down.circle.fill")
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)
                .disabled(viewModel.isDownloadingCollection)

                if viewModel.isDownloadingCollection {
                    Button(role: .cancel, action: viewModel.cancelCollectionDownload) {
                        Label("Cancel", systemImage: "xmark")
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12).fill(.thinMaterial))
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

struct FilterControls: View {
    @Binding var filters: SearchFilters
    let departments: [Department]
    var onReset: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Filters")
                    .font(.headline)
                Spacer()
                Button("Reset") {
                    onReset()
                }
                .buttonStyle(.borderless)
            }

            Picker("Department", selection: $filters.departmentId) {
                Text("Any department").tag(Optional<Int>.none)
                ForEach(departments, id: \.departmentId) { department in
                    Text(department.displayName).tag(Optional(department.departmentId))
                }
            }
            .pickerStyle(.menu)

            Toggle("Images only", isOn: $filters.requiresImages)
            Toggle("Highlights only", isOn: $filters.highlightsOnly)
            Toggle("On view only", isOn: $filters.onViewOnly)
            Toggle("Artist or culture emphasis", isOn: $filters.artistOrCultureOnly)

            VStack(alignment: .leading) {
                Text("Medium")
                    .font(.subheadline)
                TextField("e.g., Oil on canvas", text: $filters.medium)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading) {
                Text("Geography")
                    .font(.subheadline)
                TextField("e.g., France|Italy", text: $filters.geoLocation)
                    .textFieldStyle(.roundedBorder)
            }

            HStack {
                VStack(alignment: .leading) {
                    Text("Start year")
                        .font(.subheadline)
                    TextField("1200", text: $filters.dateBegin)
                        .keyboardType(.numberPad)
                        .textFieldStyle(.roundedBorder)
                }

                VStack(alignment: .leading) {
                    Text("End year")
                        .font(.subheadline)
                    TextField("1900", text: $filters.dateEnd)
                        .keyboardType(.numberPad)
                        .textFieldStyle(.roundedBorder)
                }
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.secondarySystemBackground)))
    }
}
