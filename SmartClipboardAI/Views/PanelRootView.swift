import SwiftUI

/// Quick-access panel layout: search field over a history list + detail pane
/// (PRD §F3). Owns transient UI state (search text, selection, focus); all data
/// and side effects go through the injected `PanelViewModel`.
struct PanelRootView: View {
    let model: PanelViewModel
    let onClose: () -> Void

    @State private var searchText = ""
    @State private var selectedID: ClipboardItem.ID?
    @FocusState private var searchFocused: Bool

    private var filteredItems: [ClipboardItem] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return model.history.items }
        return model.history.items.filter { $0.text.lowercased().contains(query) }
    }

    private var selectedItem: ClipboardItem? {
        filteredItems.first { $0.id == selectedID }
    }

    /// Visual order: pinned first, then recent — matches HistoryListView so
    /// arrow-key navigation lines up with what's on screen.
    private var orderedItems: [ClipboardItem] {
        let filtered = filteredItems
        return filtered.filter(\.isFavorite) + filtered.filter { !$0.isFavorite }
    }

    var body: some View {
        VStack(spacing: 0) {
            searchField
            Divider()
            HStack(spacing: 0) {
                HistoryListView(
                    items: filteredItems,
                    isSearching: !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                    selectedID: $selectedID
                )
                .frame(width: 260)
                Divider()
                DetailPaneView(
                    item: selectedItem,
                    actionState: model.actionState,
                    onRun: runAction,
                    onCopyResult: copyResult,
                    onOpenSettings: model.openSettings,
                    onToggleFavorite: toggleFavorite
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(width: 640, height: 480)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .onAppear {
            searchFocused = true
            model.resetState()
            if selectedID == nil { selectedID = orderedItems.first?.id }
        }
        .onChange(of: searchText) {
            if !filteredItems.contains(where: { $0.id == selectedID }) {
                selectedID = orderedItems.first?.id
            }
        }
        .onChange(of: selectedID) {
            model.resetState()
        }
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Search clipboard history", text: $searchText)
                .textFieldStyle(.plain)
                .font(.title3)
                .focused($searchFocused)
                .onSubmit(copySelectedAndClose)
                .onKeyPress(.downArrow) { moveSelection(by: 1); return .handled }
                .onKeyPress(.upArrow) { moveSelection(by: -1); return .handled }
                .onKeyPress(.escape) { onClose(); return .handled }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    private func moveSelection(by delta: Int) {
        let items = orderedItems
        guard !items.isEmpty else { return }
        let current = items.firstIndex { $0.id == selectedID } ?? -1
        let next = min(max(current + delta, 0), items.count - 1)
        selectedID = items[next].id
    }

    private func copySelectedAndClose() {
        if let selectedItem {
            model.copyOriginal(selectedItem.text)
        }
        onClose()
    }

    private func runAction(_ action: AIAction) {
        guard let item = selectedItem else { return }
        Task { await model.run(action, on: item) }
    }

    private func copyResult() {
        guard let output = selectedItem?.aiResult?.outputText else { return }
        model.copyResult(output)
    }

    private func toggleFavorite() {
        guard let item = selectedItem else { return }
        model.toggleFavorite(item)
    }
}
