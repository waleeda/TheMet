import SwiftUI
import TheMet

struct ArtworkDetailView: View {
    let source: ArtworkSource
    @StateObject private var viewModel: ArtworkDetailViewModel

    init(source: ArtworkSource) {
        self.source = source
        _viewModel = StateObject(wrappedValue: ArtworkDetailViewModel(source: source))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let detail = viewModel.detail {
                    header(for: detail)
                    detailGrid(for: detail)
                    descriptionSection(for: detail)
                    relatedSection
                } else if viewModel.isLoading {
                    ProgressView("Loading artwork…")
                        .frame(maxWidth: .infinity, alignment: .center)
                } else if let error = viewModel.error {
                    ContentUnavailableView("Couldn’t load object", systemImage: "exclamationmark.triangle", description: Text(error))
                }
            }
            .padding()
        }
        .navigationTitle("Artwork")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            viewModel.load()
        }
    }

    @ViewBuilder
    private func header(for detail: ArtworkDetail) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            if let imageURL = detail.imageURL {
                AsyncImage(url: imageURL) { image in
                    image
                        .resizable()
                        .scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                } placeholder: {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12).fill(.thinMaterial)
                        ProgressView()
                    }
                    .frame(maxWidth: .infinity)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(detail.title)
                    .font(.title2.bold())
                Text(detail.artist)
                    .font(.headline)
                Text("\(detail.museum) • \(detail.dateText)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private func detailGrid(for detail: ArtworkDetail) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Details")
                .font(.headline)
            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 8) {
                GridRow {
                    Text("Medium").font(.subheadline.bold())
                    Text(detail.medium.isEmpty ? "Unknown" : detail.medium)
                }
                GridRow {
                    Text("Culture/Period").font(.subheadline.bold())
                    Text(detail.culture.isEmpty ? "—" : detail.culture)
                }
                GridRow {
                    Text("Classification").font(.subheadline.bold())
                    Text(detail.classification.isEmpty ? "—" : detail.classification)
                }
                GridRow {
                    Text("Object type").font(.subheadline.bold())
                    Text(detail.objectName.isEmpty ? "—" : detail.objectName)
                }
                GridRow {
                    Text("Dimensions").font(.subheadline.bold())
                    Text(detail.dimensions.isEmpty ? "—" : detail.dimensions)
                }
                GridRow {
                    Text("Accession").font(.subheadline.bold())
                    Text(detail.accessionNumber.isEmpty ? "—" : detail.accessionNumber)
                }
                if detail.location.isEmpty == false {
                    GridRow {
                        Text("Location").font(.subheadline.bold())
                        Text(detail.location)
                    }
                }
                if detail.creditLine.isEmpty == false {
                    GridRow {
                        Text("Credit line").font(.subheadline.bold())
                        Text(detail.creditLine)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func descriptionSection(for detail: ArtworkDetail) -> some View {
        if detail.description.isEmpty == false {
            VStack(alignment: .leading, spacing: 8) {
                Text("About this work")
                    .font(.headline)
                Text(detail.description)
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
        }

        if detail.tags.isEmpty == false {
            VStack(alignment: .leading, spacing: 8) {
                Text("Tags")
                    .font(.headline)
                Wrap(tags: detail.tags)
            }
        }

        if let url = detail.objectURL {
            Link(destination: url) {
                Label("View on museum site", systemImage: "arrow.up.right.square")
                    .font(.body.bold())
            }
        }
    }

    private var relatedSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("You might also like")
                    .font(.headline)
                if viewModel.relatedIsLoading {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .scaleEffect(0.8)
                }
            }

            if viewModel.related.isEmpty {
                Text(source.metID == nil ? "Related picks are available for The Met objects." : "Explore related works once this object loads.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(viewModel.related) { result in
                            NavigationLink(destination: ArtworkDetailView(source: result.source)) {
                                RelatedCard(result: result)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }
}

private struct RelatedCard: View {
    let result: CombinedSearchResult

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            AsyncImage(url: result.imageURL) { image in
                image
                    .resizable()
                    .scaledToFill()
            } placeholder: {
                ZStack {
                    RoundedRectangle(cornerRadius: 8).fill(.thinMaterial)
                    Image(systemName: "photo")
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 140, height: 140)
            .clipShape(RoundedRectangle(cornerRadius: 10))

            Text(result.title)
                .font(.headline)
                .lineLimit(2)
            Text(result.subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(width: 160, alignment: .leading)
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.secondarySystemBackground)))
    }
}

private struct Wrap: View {
    let tags: [String]

    private var columns: [GridItem] {
        [GridItem(.adaptive(minimum: 80), spacing: 8)]
    }

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
            ForEach(tags, id: \.self) { tag in
                Text(tag)
                    .font(.footnote.bold())
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Color(.secondarySystemBackground)))
            }
        }
    }
}
