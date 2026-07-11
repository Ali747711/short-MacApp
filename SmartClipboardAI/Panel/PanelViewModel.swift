import Foundation
import Observation

/// Drives the panel's AI actions and copy-back (PRD §F4, §F5). Owns the transient
/// action state so views can react; delegates persistence to `HistoryStore` and
/// pasteboard writes to the injected `copyBack` closure (which suppresses the
/// resulting self-copy in `ClipboardMonitor`).
@MainActor
@Observable
final class PanelViewModel {
    let history: HistoryStore

    enum ActionState: Equatable {
        case idle
        case running(AIAction)
        case failed(AppError)
    }

    private(set) var actionState: ActionState = .idle

    private let claude: ClaudeService
    private let copyBack: (String) -> Void
    let openSettings: () -> Void

    init(
        history: HistoryStore,
        claude: ClaudeService,
        copyBack: @escaping (String) -> Void,
        openSettings: @escaping () -> Void
    ) {
        self.history = history
        self.claude = claude
        self.copyBack = copyBack
        self.openSettings = openSettings
    }

    var isRunning: Bool {
        if case .running = actionState { return true }
        return false
    }

    func resetState() {
        actionState = .idle
    }

    func run(_ action: AIAction, on item: ClipboardItem) async {
        actionState = .running(action)
        do {
            let output = try await claude.run(action, on: item.text)
            history.setResult(AIResult(action: action, outputText: output), for: item.id)
            actionState = .idle
        } catch let error as AppError {
            actionState = .failed(error)
        } catch {
            actionState = .failed(.networkError)
        }
    }

    /// Copy the original selected text back (Enter / row selection).
    func copyOriginal(_ text: String) {
        copyBack(text)
    }

    /// Copy the AI result back (Copy Result / ⌘C).
    func copyResult(_ text: String) {
        copyBack(text)
    }
}
