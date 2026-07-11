# CLAUDE.md — Smart Clipboard AI

Guidance for Claude Code when building and maintaining this project.

## What This Project Is

A native macOS menu bar app (SwiftUI, macOS 14.0+) that tracks clipboard history and applies AI actions (Translate KO↔EN, Summarize, Clean/Format) via the Claude API.

**The single source of truth is [short-PRD.md](short-PRD.md).** All technical decisions are already made there (§3 Fixed Technical Decisions). Do not substitute alternatives (e.g., Core Data instead of JSON, a different hotkey library, an Anthropic SDK instead of URLSession) without the user explicitly approving the change.

## Current Status

- [x] Phase 1 — Skeleton & clipboard capture
- [x] Phase 2 — Panel UI
- [x] Phase 3 — AI integration
- [x] Phase 4 — Polish

> Update this checklist as phases complete. Work strictly in phase order; each phase must build and pass its acceptance criteria (PRD §4, §8) before starting the next.

## Build & Test Commands

The Xcode project is generated from `project.yml` — **never hand-edit `SmartClipboardAI.xcodeproj`**; edit `project.yml` and regenerate.

```bash
# Regenerate the Xcode project (required after adding/removing/renaming files)
xcodegen generate

# Build
xcodebuild -project SmartClipboardAI.xcodeproj -scheme SmartClipboardAI -configuration Debug build

# Run unit tests
xcodebuild -project SmartClipboardAI.xcodeproj -scheme SmartClipboardAI test

# Launch the built app for manual verification
open ~/Library/Developer/Xcode/DerivedData/SmartClipboardAI-*/Build/Products/Debug/SmartClipboardAI.app
```

Prerequisites: Xcode 15+, `brew install xcodegen`.

**Always run a full build after every file change** — there is no incremental type-checker hook for Swift here. Treat compiler warnings as errors to fix.

## Architecture (summary — full map in PRD §6)

MVVM. One type per file, files < 300 lines.

| Layer | Location | Rule |
|---|---|---|
| App entry | `SmartClipboardAI/App/` | `@main`, `MenuBarExtra`, `Settings` scene, root `AppState` |
| Models | `SmartClipboardAI/Models/` | `Codable` value types only, no logic |
| Services | `SmartClipboardAI/Services/` | All business logic. **No UI imports** (no SwiftUI) |
| Panel | `SmartClipboardAI/Panel/` | `NSPanel` subclass + controller (the one AppKit island) |
| Views | `SmartClipboardAI/Views/` | Dumb SwiftUI views. **No business logic, no URLSession, no NSPasteboard** |
| Tests | `SmartClipboardAITests/` | Unit tests for Services |

Key services and their single responsibility:
- `ClipboardMonitor` — 0.5 s `changeCount` polling, ignore rules, self-copy suppression
- `HistoryStore` — in-memory array + debounced JSON persistence (max 100 items, FIFO)
- `ClaudeService` — `async func run(_ action: AIAction, on text: String) throws -> String`
- `KeychainService` — API key save/load/delete (key lives ONLY in Keychain)
- `Prompts` — the three system-prompt constants (exact strings in PRD §F4)

## Swift Conventions

- Swift 5.9+, `async/await` only — no completion handlers, no Combine
- `@Observable` macro (macOS 14) for state, not `ObservableObject`
- All UI-facing state mutation on `@MainActor`
- Value types (`struct`/`enum`) by default; classes only where AppKit/reference semantics require (e.g., `NSPanel`, monitor with a `Timer`)
- Errors: one `AppError` enum; every user-visible failure maps to the human-readable strings in PRD §F4 — never surface raw response bodies
- No force unwraps (`!`) outside tests; no `try?` that swallows errors silently
- Naming: Apple API Design Guidelines (camelCase, argument labels that read as prose)
- Comments explain *why*, not *what*; keep them rare

## Testing

- Unit-test Services, not Views: ignore rules, FIFO eviction, persistence round-trip, `ClaudeService` via mocked `URLProtocol` (success, 401, 429, timeout)
- Tests must not touch the real network, real Keychain, or the real pasteboard — inject protocols/fakes
- UI behavior (panel, hotkey, keyboard nav) is verified manually against the acceptance checklists in PRD §4 — state which criteria you verified when finishing a phase

## Privacy & Security Rules (hard constraints)

- Clipboard text goes to the Claude API **only** on an explicit user action — never automatically
- Never store or display concealed/transient pasteboard entries (`org.nspasteboard.ConcealedType` / `TransientType`)
- **Never log clipboard contents or API payloads** — no `print`/`os_log` of user text, even in debug
- API key: Keychain only. Never UserDefaults, never in source, never in logs
- App Sandbox stays ON (`com.apple.security.network.client` is the only network entitlement)

## Common Pitfalls (read before touching related code)

- **Self-copy loop:** when the app writes to the pasteboard (Copy Result / Enter), `ClipboardMonitor` must skip that change (record the post-write `changeCount` and ignore it) or history fills with the app's own output.
- **Panel focus:** the panel is a `.nonactivatingPanel`; don't convert it to a regular window or the frontmost app loses focus context. Search field still needs first-responder status on open — handle via the panel's `canBecomeKey` override.
- **XcodeGen drift:** a new `.swift` file that doesn't show up in the build almost always means `xcodegen generate` wasn't re-run.
- **Timer retain cycle:** `ClipboardMonitor`'s `Timer` must be invalidated on deinit; use `[weak self]` in its closure.
- **Truncation order:** store up to 10,000 chars (F1), but send at most 4,000 to the API (F4) — these are different limits on purpose.

## Git

- Conventional commits: `feat|fix|refactor|docs|test|chore: description`
- Commit at the end of each phase at minimum (working, tested state)
- Never commit: API keys, `history.json` test artifacts, `DerivedData/`, `.xcodeproj` is generated — decide once whether to commit it (default: commit it so the repo builds without xcodegen) and stay consistent
