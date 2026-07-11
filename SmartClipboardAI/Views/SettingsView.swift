import ServiceManagement
import SwiftUI
import KeyboardShortcuts

/// Settings window: API key entry + test, hotkey recorder, launch-at-login, and
/// clear history (PRD §F6).
struct SettingsView: View {
    let keychain: KeychainService
    let claude: ClaudeService
    let history: HistoryStore

    @State private var apiKey = ""
    @State private var testState: TestState = .idle
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var showClearConfirmation = false

    enum TestState: Equatable {
        case idle
        case testing
        case success
        case failure(String)
    }

    var body: some View {
        Form {
            Section("Claude API Key") {
                SecureField("sk-ant-…", text: $apiKey)
                HStack(spacing: 12) {
                    Button("Save") { keychain.save(apiKey) }
                        .disabled(apiKey.isEmpty)
                    Button("Test key") { Task { await testKey() } }
                        .disabled(apiKey.isEmpty || testState == .testing)
                    testStatus
                }
            }

            Section("Hotkey") {
                KeyboardShortcuts.Recorder("Toggle panel:", name: .togglePanel)
            }

            Section("General") {
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, enabled in
                        setLaunchAtLogin(enabled)
                    }
            }

            Section("History") {
                Button("Clear History…", role: .destructive) {
                    showClearConfirmation = true
                }
                .confirmationDialog(
                    "Clear all clipboard history?",
                    isPresented: $showClearConfirmation
                ) {
                    Button("Clear History", role: .destructive) { history.clear() }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("This permanently removes all stored items.")
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 440)
        .onAppear { apiKey = keychain.load() ?? "" }
    }

    @ViewBuilder
    private var testStatus: some View {
        switch testState {
        case .idle:
            EmptyView()
        case .testing:
            ProgressView().controlSize(.small)
        case .success:
            Label("Valid", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case .failure(let message):
            Label(message, systemImage: "xmark.circle.fill")
                .foregroundStyle(.red)
        }
    }

    private func testKey() async {
        keychain.save(apiKey)
        testState = .testing
        do {
            _ = try await claude.run(.translate, on: "hello")
            testState = .success
        } catch let error as AppError {
            testState = .failure(error.message)
        } catch {
            testState = .failure(AppError.networkError.message)
        }
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            // Registration can fail for an unsigned/dev build — reflect real status.
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }
}
