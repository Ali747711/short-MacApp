import AppKit

/// User-selectable app appearance (V1.1). Persisted as its raw value in
/// UserDefaults under `defaultsKey`, and applied app-wide via
/// `NSApplication.shared.appearance` so it covers both the AppKit panel and the
/// SwiftUI Settings window in one place.
enum AppearanceMode: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    static let defaultsKey = "appearanceMode"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .system: "System"
        case .light: "Light"
        case .dark: "Dark"
        }
    }

    private var appearance: NSAppearance? {
        switch self {
        case .system: nil
        case .light: NSAppearance(named: .aqua)
        case .dark: NSAppearance(named: .darkAqua)
        }
    }

    @MainActor
    func apply() {
        NSApplication.shared.appearance = appearance
    }

    /// The mode currently stored in UserDefaults (defaults to `.system`).
    static func stored(in defaults: UserDefaults = .standard) -> AppearanceMode {
        AppearanceMode(rawValue: defaults.string(forKey: defaultsKey) ?? "") ?? .system
    }
}
