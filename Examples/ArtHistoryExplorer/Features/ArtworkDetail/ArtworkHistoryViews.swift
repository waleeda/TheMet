import SwiftUI
import TheMet

struct ArtworkHistorySection: View {
    let history: ArtworkHistory

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Provenance & Exhibitions")
                    .font(.headline)
                Spacer()
                HistoryStateBadge(state: history.visualizationState)
            }

            if history.visualizationState == .empty {
                ContentUnavailableView("No history available", systemImage: "clock.badge.questionmark", description: Text("This object does not yet include a provenance chain or exhibition record."))
            } else {
                ProvenanceTimeline(events: history.provenance)
                ExhibitionMapTimeline(exhibitions: history.exhibitions)
                CitationList(citations: history.citations, documentURL: history.documentURL)
            }
        }
    }
}

private struct HistoryStateBadge: View {
    let state: HistoryVisualizationState

    var color: Color {
        switch state {
        case .empty:
            return .orange
        case .partial:
            return .yellow
        case .complete:
            return .green
        }
    }

    var body: some View {
        Label(state.label, systemImage: "sparkles")
            .font(.footnote.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Capsule().fill(color.opacity(0.15)))
            .foregroundStyle(color)
    }
}

private struct ProvenanceTimeline: View {
    let events: [ProvenanceEvent]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Provenance timeline")
                .font(.subheadline.bold())

            ForEach(events.sorted { $0.order < $1.order }, id: \.order) { event in
                HStack(alignment: .top, spacing: 12) {
                    VStack {
                        Circle()
                            .fill(Color.accentColor)
                            .frame(width: 10, height: 10)
                        Rectangle()
                            .fill(Color.accentColor.opacity(0.2))
                            .frame(width: 2)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text(event.owner)
                            .font(.body.bold())
                        Text(event.location ?? "Unknown location")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        HStack(spacing: 8) {
                            if let year = event.year {
                                Label(String(year), systemImage: "calendar")
                            }
                            Label(event.type.rawValue.capitalized, systemImage: "person.text.rectangle")
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        if let note = event.note, note.isEmpty == false {
                            Text(note)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        if let citation = event.citation {
                            Text(citation.title)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }
}

private struct ExhibitionMapTimeline: View {
    let exhibitions: [ExhibitionEvent]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Exhibition trail")
                .font(.subheadline.bold())

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(Array(exhibitions.enumerated()), id: \.offset) { _, exhibition in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 6) {
                                Image(systemName: "mappin.and.ellipse")
                                    .foregroundStyle(.secondary)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(exhibition.venue)
                                        .font(.headline)
                                    Text(exhibition.city ?? "Unknown city")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            HStack(spacing: 8) {
                                if let start = exhibition.startYear {
                                    Label(String(start), systemImage: "calendar")
                                        .font(.caption)
                                }
                                if let end = exhibition.endYear {
                                    Label("to \(end)", systemImage: "arrow.right")
                                        .font(.caption)
                                }
                            }
                            Text(exhibition.title)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                            MapBadge(coordinate: exhibition.coordinate)
                        }
                        .padding()
                        .frame(width: 200, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.secondarySystemBackground)))
                    }
                }
            }
        }
    }
}

private struct MapBadge: View {
    let coordinate: ExhibitionCoordinate?

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "globe.americas.fill")
                .foregroundStyle(.blue)
            Text(coordinateText)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var coordinateText: String {
        guard let coordinate else { return "Coordinates pending" }
        return String(format: "%.2f, %.2f", coordinate.latitude, coordinate.longitude)
    }
}

private struct CitationList: View {
    let citations: [Citation]
    let documentURL: URL?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Sources")
                .font(.subheadline.bold())

            if citations.isEmpty == false {
                ForEach(Array(citations.enumerated()), id: \.offset) { _, citation in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(citation.title)
                            .font(.footnote.bold())
                        if let detail = citation.detail {
                            Text(detail)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        if let url = citation.url {
                            Link(destination: url) {
                                Label("View source", systemImage: "arrow.up.right.square")
                                    .font(.caption.bold())
                            }
                        }
                    }
                }
            }

            if let url = documentURL {
                Link(destination: url) {
                    Label("Download provenance PDF", systemImage: "doc.richtext")
                        .font(.footnote.bold())
                }
            }
        }
    }
}
