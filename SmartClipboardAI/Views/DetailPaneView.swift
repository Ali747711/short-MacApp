import SwiftUI

/// The right pane: full text of the selected item, its AI result / running /
/// error state, and the action bar (PRD §F3, §F4, §F5). No business logic —
/// everything routes through closures and the passed-in `ActionState`.
struct DetailPaneView: View {
    let item: ClipboardItem?
    let actionState: PanelViewModel.ActionState
    let onRun: (AIAction) -> Void
    let onCopyResult: () -> Void
    let onOpenSettings: () -> Void
    let onToggleFavorite: () -> Void

    @State private var justCopied = false

    private var isRunning: Bool {
        if case .running = actionState { return true }
        return false
    }

    var body: some View {
        if let item {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Spacer()
                    Button(action: onToggleFavorite) {
                        Image(systemName: item.isFavorite ? "star.fill" : "star")
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(item.isFavorite ? .yellow : .secondary)
                    .keyboardShortcut("p", modifiers: .command)
                    .help(item.isFavorite ? "Unpin" : "Pin")
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)

                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        if item.isTruncated {
                            Label("Truncated to 10,000 characters", systemImage: "scissors")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Text(item.text)
                            .font(.body)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        statusSection(for: item)
                    }
                    .padding(16)
                }

                Divider()
                actionBar(for: item)
            }
        } else {
            ContentUnavailableView("No Selection", systemImage: "text.cursor")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    @ViewBuilder
    private func statusSection(for item: ClipboardItem) -> some View {
        switch actionState {
        case .running(let action):
            Divider()
            HStack(spacing: 8) {
                ProgressView().controlSize(.small)
                Text("\(action.rawValue.capitalized)…")
                    .foregroundStyle(.secondary)
            }
        case .failed(let error):
            Divider()
            VStack(alignment: .leading, spacing: 8) {
                Label(error.message, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.red)
                if error.isMissingKey {
                    Button("Open Settings…", action: onOpenSettings)
                }
            }
        case .idle:
            if let result = item.aiResult {
                Divider()
                resultSection(result)
            }
        }
    }

    private func resultSection(_ result: AIResult) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(result.action.rawValue.capitalized)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(result.outputText)
                .font(.body)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func actionBar(for item: ClipboardItem) -> some View {
        HStack(spacing: 8) {
            Group {
                Button("Translate") { onRun(.translate) }
                    .keyboardShortcut("1", modifiers: .command)
                Button("Summarize") { onRun(.summarize) }
                    .keyboardShortcut("2", modifiers: .command)
                Button("Clean") { onRun(.clean) }
                    .keyboardShortcut("3", modifiers: .command)
            }
            .disabled(isRunning)

            Spacer()

            if justCopied {
                Label("Copied", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.callout)
            }

            Button("Copy Result", action: copyResult)
                .keyboardShortcut("c", modifiers: .command)
                .disabled(item.aiResult == nil)
        }
        .padding(12)
    }

    private func copyResult() {
        onCopyResult()
        withAnimation { justCopied = true }
        Task {
            try? await Task.sleep(for: .seconds(1.5))
            justCopied = false
        }
    }
}
