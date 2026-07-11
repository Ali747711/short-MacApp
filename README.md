# Smart Clipboard AI

A native macOS menu bar app that tracks your clipboard history and applies AI
actions — **Translate (KO ↔ EN)**, **Summarize**, and **Clean/Format** — to any
copied text, then copies the result back. All from a keyboard-summoned floating
panel.

- **Platform:** macOS 14.0+ (Sonoma), Apple Silicon + Intel
- **UI:** SwiftUI menu bar app (no Dock icon) with a floating `NSPanel`
- **AI:** Claude API (`claude-haiku-4-5-20251001`) via direct `URLSession` — no SDK

## Features

- **Clipboard history** — captures plain text automatically (0.5 s polling),
  keeps the last 100 entries, and persists them across launches. Passwords and
  other concealed/transient pasteboard entries are never stored.
- **Quick-access panel** — `⌘⇧V` from any app opens a floating panel with live
  search, a history list, and a detail pane. Closes on `Esc`, click-outside, or
  the hotkey again.
- **AI actions** — Translate / Summarize / Clean on the selected item
  (`⌘1` / `⌘2` / `⌘3`), with the result copied back via **Copy Result** (`⌘C`).
- **Keyboard-first** — `↑`/`↓` to select, `Enter` to copy the original text back
  and close.

## Build & Run

Prerequisites: **Xcode 15+** and **XcodeGen** (`brew install xcodegen`).

The Xcode project is generated from `project.yml` — never hand-edit
`SmartClipboardAI.xcodeproj`; edit `project.yml` and regenerate.

```bash
# Generate the Xcode project (required after adding/removing/renaming files)
xcodegen generate

# Build
xcodebuild -project SmartClipboardAI.xcodeproj -scheme SmartClipboardAI -configuration Debug build

# Run unit tests
xcodebuild -project SmartClipboardAI.xcodeproj -scheme SmartClipboardAI test

# Launch the built app
open ~/Library/Developer/Xcode/DerivedData/SmartClipboardAI-*/Build/Products/Debug/SmartClipboardAI.app
```

## API Key Setup

The AI actions require your own Claude API key from
[the Anthropic Console](https://console.anthropic.com/).

1. Launch the app — a clipboard icon appears in the menu bar.
2. Menu bar icon → **Settings…**
3. Paste your key into **Claude API Key** and click **Save**.
4. Click **Test key** to verify (✓ = valid).

The key is stored **only** in the macOS Keychain — never in UserDefaults, never
in source, never in logs.

## Privacy

- Clipboard text is sent to the Claude API **only** on an explicit action
  (Translate / Summarize / Clean) — never automatically.
- Concealed/transient pasteboard entries (e.g. from password managers) are never
  stored or displayed.
- Clipboard contents and API payloads are never logged.
- History is stored as plain JSON at
  `~/Library/Application Support/SmartClipboardAI/history.json`.
- The app runs sandboxed; its only entitlement is outbound network access
  (`com.apple.security.network.client`).

## Architecture

MVVM, one type per file. See [short-PRD.md](short-PRD.md) §6 for the full map.

| Layer | Location | Responsibility |
|---|---|---|
| App | `SmartClipboardAI/App/` | `@main`, `MenuBarExtra`, `Settings`, root `AppState` |
| Models | `SmartClipboardAI/Models/` | `Codable` value types |
| Services | `SmartClipboardAI/Services/` | Clipboard monitor, history store, Claude/Keychain — no UI |
| Panel | `SmartClipboardAI/Panel/` | `NSPanel` + controller + view model |
| Views | `SmartClipboardAI/Views/` | Dumb SwiftUI views |
| Tests | `SmartClipboardAITests/` | Ignore rules, FIFO/persistence, `ClaudeService` (mocked `URLProtocol`) |
