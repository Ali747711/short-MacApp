import AppKit
import Observation

/// Root application state. Owns the services and wires the clipboard monitor into
/// the history store and the panel (PRD §6). UI-facing state lives here; views
/// stay dumb.
@MainActor
@Observable
final class AppState {
    let history: HistoryStore
    let keychain: KeychainService
    let claude: ClaudeService

    private let monitor: ClipboardMonitor
    private var panelController: PanelController?

    init(
        history: HistoryStore = HistoryStore(),
        monitor: ClipboardMonitor = ClipboardMonitor(),
        keychain: KeychainService = KeychainService()
    ) {
        self.history = history
        self.monitor = monitor
        self.keychain = keychain
        self.claude = ClaudeService(keyProvider: keychain)

        history.load()
        monitor.onNewItem = { [weak history] item in
            history?.add(item)
        }
        monitor.start()

        let viewModel = PanelViewModel(
            history: history,
            claude: claude,
            copyBack: { [weak self] text in self?.copyBack(text) },
            openSettings: { [weak self] in self?.openSettings() }
        )
        panelController = PanelController(model: viewModel)
    }

    func togglePanel() {
        panelController?.toggle()
    }

    /// Write text back to the pasteboard and suppress the resulting change so the
    /// app's own output never becomes a new history entry (PRD §F5).
    private func copyBack(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        monitor.ignoreChange(upTo: pasteboard.changeCount)
    }

    private func openSettings() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
    }
}
