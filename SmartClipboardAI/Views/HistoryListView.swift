import SwiftUI

/// The left pane: a two-section (Pinned / Recent) selectable list, or an empty state.
struct HistoryListView: View {
    let items: [ClipboardItem]
    let isSearching: Bool
    @Binding var selectedID: ClipboardItem.ID?

    private var pinned: [ClipboardItem] { items.filter(\.isFavorite) }
    private var recent: [ClipboardItem] { items.filter { !$0.isFavorite } }

    var body: some View {
        if items.isEmpty {
            emptyState
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            List(selection: $selectedID) {
                if !pinned.isEmpty {
                    Section("Pinned") {
                        ForEach(pinned) { item in
                            HistoryRowView(item: item).tag(item.id)
                        }
                    }
                }
                if !recent.isEmpty {
                    Section("Recent") {
                        ForEach(recent) { item in
                            HistoryRowView(item: item).tag(item.id)
                        }
                    }
                }
            }
            .listStyle(.sidebar)
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        if isSearching {
            ContentUnavailableView.search
        } else {
            ContentUnavailableView(
                "No clipboard history yet",
                systemImage: "doc.on.clipboard",
                description: Text("Copy some text and it will show up here.")
            )
        }
    }
}

/// A single history row: the first two lines of text, a relative timestamp, and a
/// star when pinned.
private struct HistoryRowView: View {
    let item: ClipboardItem

    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            VStack(alignment: .leading, spacing: 3) {
                Text(previewText)
                    .font(.callout)
                    .lineLimit(2)
                Text(Self.relativeFormatter.localizedString(for: item.copiedAt, relativeTo: .now))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            if item.isFavorite {
                Image(systemName: "star.fill")
                    .font(.caption)
                    .foregroundStyle(.yellow)
            }
        }
        .padding(.vertical, 2)
    }

    private var previewText: String {
        item.text
            .split(separator: "\n", maxSplits: 1, omittingEmptySubsequences: false)
            .prefix(2)
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter
    }()
}
