import AppKit
import SwiftUI
import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    /// Global hotkey that toggles the quick-access panel. Default ⌘⇧V (PRD §F2).
    static let togglePanel = Self("togglePanel", default: .init(.v, modifiers: [.command, .shift]))
}

/// Owns the floating panel: registers the global hotkey, toggles show/hide, and
/// closes on Esc / click-outside (PRD §F2). Holds no business logic — it wires the
/// history store into `PanelRootView` and forwards copy-back to `AppState`.
@MainActor
final class PanelController: NSObject, NSWindowDelegate {
    private let model: PanelViewModel
    private var panel: FloatingPanel?

    private static let panelSize = NSSize(width: 640, height: 480)

    init(model: PanelViewModel) {
        self.model = model
        super.init()

        KeyboardShortcuts.onKeyDown(for: .togglePanel) { [weak self] in
            self?.toggle()
        }
    }

    func toggle() {
        if let panel, panel.isVisible {
            panel.close()
        } else {
            show()
        }
    }

    private func show() {
        let panel = panel ?? makePanel()
        self.panel = panel

        // Rebuild the content each open so search resets and the field re-focuses.
        let root = PanelRootView(
            model: model,
            onClose: { [weak self] in self?.panel?.close() }
        )
        panel.contentViewController = NSHostingController(rootView: root)

        position(panel)
        panel.makeKeyAndOrderFront(nil)
    }

    private func makePanel() -> FloatingPanel {
        let panel = FloatingPanel(
            contentRect: NSRect(origin: .zero, size: Self.panelSize)
        )
        panel.delegate = self
        return panel
    }

    /// Center the panel on whichever screen currently holds the mouse (PRD §F2).
    private func position(_ panel: NSPanel) {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { $0.frame.contains(mouse) } ?? NSScreen.main
        guard let visible = screen?.visibleFrame else { return }

        let origin = NSPoint(
            x: visible.midX - Self.panelSize.width / 2,
            y: visible.midY - Self.panelSize.height / 2
        )
        panel.setFrame(NSRect(origin: origin, size: Self.panelSize), display: true)
    }

    // Clicking outside the panel (losing key status) closes it (PRD §F2).
    func windowDidResignKey(_ notification: Notification) {
        panel?.close()
    }
}
