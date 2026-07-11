import AppKit
import SwiftUI

@main
struct SmartClipboardAIApp: App {
    @State private var appState = AppState()

    var body: some Scene {
        MenuBarExtra("Smart Clipboard AI", systemImage: "clipboard") {
            // The global ⌘⇧V hotkey is handled by PanelController; this menu item
            // toggles the same panel. Settings UI arrives in Phase 3.
            Button("Open Panel") {
                appState.togglePanel()
            }

            Divider()

            SettingsLink {
                Text("Settings…")
            }
            .keyboardShortcut(",", modifiers: .command)

            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q", modifiers: .command)
        }

        Settings {
            SettingsView(
                keychain: appState.keychain,
                claude: appState.claude,
                history: appState.history
            )
        }
    }
}
