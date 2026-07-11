import AppKit

/// Borderless, non-activating floating panel that hosts the SwiftUI quick-access UI
/// (PRD §F2). Non-activating so the previously frontmost app keeps focus context,
/// yet still able to become key so the search field can receive typing.
final class FloatingPanel: NSPanel {
    init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        isFloatingPanel = true
        level = .floating
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        isMovableByWindowBackground = true
        backgroundColor = .clear
        hasShadow = true
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        animationBehavior = .utilityWindow
    }

    // Borderless panels don't become key by default; allow it so text input works.
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    // Esc closes the panel (PRD §F2). Backstop for the SwiftUI `.onKeyPress` handler.
    override func cancelOperation(_ sender: Any?) {
        close()
    }
}
