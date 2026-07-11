import SwiftUI

/// The left pane: a selectable list of clipboard items, or an empty state.
struct HistoryListView: View {
    let items: [ClipboardItem]
    let isSearching: Bool
    @Binding var selectedID: ClipboardItem.ID?

    var body: some View {
        if items.isEmpty {
            emptyState
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            List(items, selection: $selectedID) { item in
                HistoryRowView(item: item)
                    .tag(item.id)
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

/// A single history row: the first two lines of text plus a relative timestamp.
private struct HistoryRowView: View {
    let item: ClipboardItem

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(previewText)
                .font(.callout)
                .lineLimit(2)
            Text(Self.relativeFormatter.localizedString(for: item.copiedAt, relativeTo: .now))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }

    /// First two lines of the entry, whitespace-trimmed for a tidy preview.
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
