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
                header(for: item)

                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        originalLabel(for: item)

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

    // MARK: - Header

    private func header(for item: ClipboardItem) -> some View {
        HStack {
            Text(item.copiedAt, format: .relative(presentation: .named))
                .font(.caption)
                .foregroundStyle(.tertiary)
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
        .padding(.bottom, 4)
    }

    private func originalLabel(for item: ClipboardItem) -> some View {
        HStack(spacing: 6) {
            Text("Original")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)
            if item.isTruncated {
                Label("truncated to 10,000 characters", systemImage: "scissors")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    // MARK: - Status (running / error / result)

    @ViewBuilder
    private func statusSection(for item: ClipboardItem) -> some View {
        switch actionState {
        case .running(let action):
            HStack(spacing: 8) {
                ProgressView().controlSize(.small)
                Text("\(action.rawValue.capitalized)…")
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 4)
        case .failed(let error):
            VStack(alignment: .leading, spacing: 8) {
                Label(error.message, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.red)
                if error.isMissingKey {
                    Button("Open Settings…", action: onOpenSettings)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        case .idle:
            if let result = item.aiResult {
                resultCard(result)
            }
        }
    }

    private func resultCard(_ result: AIResult) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(result.action.rawValue.capitalized, systemImage: Self.icon(for: result.action))
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)
            Text(result.outputText)
                .font(.body)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    // MARK: - Action bar

    private func actionBar(for item: ClipboardItem) -> some View {
        HStack(spacing: 8) {
            Group {
                Button { onRun(.translate) } label: {
                    Label("Translate", systemImage: Self.icon(for: .translate))
                }
                .keyboardShortcut("1", modifiers: .command)
                Button { onRun(.summarize) } label: {
                    Label("Summarize", systemImage: Self.icon(for: .summarize))
                }
                .keyboardShortcut("2", modifiers: .command)
                Button { onRun(.clean) } label: {
                    Label("Clean", systemImage: Self.icon(for: .clean))
                }
                .keyboardShortcut("3", modifiers: .command)
            }
            .buttonStyle(.bordered)
            .disabled(isRunning)

            Spacer()

            if justCopied {
                Label("Copied", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.callout)
                    .transition(.opacity)
            }

            Button(action: copyResult) {
                Label("Copy Result", systemImage: "doc.on.doc")
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut("c", modifiers: .command)
            .disabled(item.aiResult == nil)
        }
        .controlSize(.large)
        .padding(12)
    }

    private func copyResult() {
        onCopyResult()
        withAnimation { justCopied = true }
        Task {
            try? await Task.sleep(for: .seconds(1.5))
            withAnimation { justCopied = false }
        }
    }

    private static func icon(for action: AIAction) -> String {
        switch action {
        case .translate: "character.book.closed"
        case .summarize: "list.bullet.rectangle"
        case .clean: "wand.and.sparkles"
        }
    }
}
