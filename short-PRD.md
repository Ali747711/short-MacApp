# Smart Clipboard AI — Product Requirements Document (PRD)

> **How to use this document:** This PRD is written to be executed by Claude Code phase-by-phase. Every decision is already made — do not re-open "option A vs option B" questions. Build Phase 1 → verify → Phase 2 → verify → etc. Each phase ends with concrete acceptance criteria that must pass before moving on.

---

## 1. Overview

| | |
|---|---|
| **Product** | Smart Clipboard AI |
| **Platform** | macOS 14.0+ (Sonoma), Apple Silicon + Intel |
| **Type** | Menu bar utility (no Dock icon) with a floating panel |
| **Language / UI** | Swift 5.9+, SwiftUI |
| **Distribution (MVP)** | Local build via Xcode, unsigned / dev-signed. No App Store, no notarization for MVP. |

### Description

A macOS menu bar app that tracks clipboard history and applies AI actions (translate, summarize, clean/format) to any copied text, then copies the result back — all from a keyboard-summoned floating panel.

### Core Value

- Reduce context switching (no pasting into ChatGPT/Google Translate tabs)
- Instant Korean ↔ English translation for multilingual developers
- One-shot cleanup of copied code, logs, and prose

### Non-Goals (MVP — do NOT build these)

- No image/file clipboard support — **text only** (`NSPasteboard` string types)
- No iCloud/device sync
- No login/accounts
- No auto-processing of clipboard content (AI runs only on explicit user action)
- No App Store packaging, sparkle updates, or analytics

---

## 2. Target Users & Use Cases

**Primary:** developers and Korean ↔ English bilingual users.

| Use case | Flow |
|---|---|
| Translate | Copy Korean text → `⌘⇧V` → select item → Translate → result auto-copied |
| Summarize | Copy long article text → Summarize → 3–5 bullets |
| Clean code | Copy badly-indented snippet → Clean → formatted code |
| Fix prose | Copy rough English draft → Clean → grammar-corrected text |

---

## 3. Fixed Technical Decisions

These are decided. Do not substitute alternatives.

| Concern | Decision | Notes |
|---|---|---|
| App style | Menu bar app: `MenuBarExtra` + `LSUIElement = YES` in Info.plist | No Dock icon, no main window |
| Floating panel | Borderless `NSPanel` (`.nonactivatingPanel`) wrapped for SwiftUI, `level = .floating` | Opens centered on the active screen; closes on `Esc` or focus loss |
| Global hotkey | [`sindresorhus/KeyboardShortcuts`](https://github.com/sindresorhus/KeyboardShortcuts) SPM package | Default `⌘⇧V`, user-recordable in Settings |
| Clipboard monitoring | Poll `NSPasteboard.general.changeCount` every **0.5 s** via `Timer` | No Accessibility permission needed for reading the pasteboard |
| Storage | **JSON file** at `~/Library/Application Support/SmartClipboardAI/history.json` | Max **100** entries, FIFO eviction. No Core Data / SwiftData — keep MVP simple |
| AI provider | **Claude API only** (no OpenAI fallback in MVP) | Model: `claude-haiku-4-5-20251001` (fast + cheap; meets < 2 s target). Direct `URLSession` calls to `https://api.anthropic.com/v1/messages` — no SDK dependency |
| API key | User pastes their own key in Settings; stored in **macOS Keychain** | Never in UserDefaults, never hardcoded, never logged |
| Sandbox | App Sandbox **ON** with `com.apple.security.network.client` entitlement | Pasteboard read/write works inside the sandbox |
| Architecture | MVVM. Views are dumb; all logic in ViewModels/Services | See module map in §6 |
| Project generation | Create the Xcode project with **XcodeGen** (`project.yml` checked into repo) so the whole project is file-driven and reproducible | Build/run with `xcodebuild` from CLI |
| Min deployment | macOS 14.0 | Allows `MenuBarExtra`, `@Observable` macro |

---

## 4. Functional Requirements (MVP)

### F1 — Clipboard History

- Detect every clipboard change while the app runs (0.5 s polling of `changeCount`).
- Capture **plain text only**. Ignore non-text pasteboard content.
- **Ignore rules** (do not store):
  - Empty / whitespace-only strings
  - Duplicates of the most recent entry
  - Entries whose pasteboard declares `org.nspasteboard.ConcealedType` or `org.nspasteboard.TransientType` (password managers mark secrets this way)
  - Text longer than 10,000 characters (truncate to 10,000 and mark `isTruncated`)
- Store up to **100** entries; oldest evicted first.
- Persist to disk on every change (debounced 1 s); reload on launch.

**Data model:**

```swift
struct ClipboardItem: Codable, Identifiable, Equatable {
  let id: UUID
  let text: String
  let copiedAt: Date
  let isTruncated: Bool
  var aiResult: AIResult?   // last AI output for this item, nil until an action runs
}

struct AIResult: Codable, Equatable {
  let action: AIAction      // .translate | .summarize | .clean
  let outputText: String
  let createdAt: Date
}

enum AIAction: String, Codable { case translate, summarize, clean }
```

**Acceptance criteria:**
- [ ] Copy text in any app → item appears at top of list within 1 s
- [ ] Copying the same text twice creates one entry
- [ ] Copying a password from a password manager (concealed type) creates no entry
- [ ] Quit and relaunch → history intact
- [ ] 101st copy evicts the oldest entry

### F2 — Floating Panel (Quick Access)

- `⌘⇧V` from any app toggles the panel (open if closed, close if open).
- Panel: fixed size **640 × 480**, appears centered on the screen with the mouse cursor, floats above other windows, does **not** steal full app activation (non-activating panel so the previous app keeps focus context).
- Closes on: `Esc`, clicking outside, or pressing the hotkey again.
- Menu bar icon (clipboard SF Symbol) with menu: *Open Panel*, *Settings…*, *Quit*.

**Acceptance criteria:**
- [ ] Hotkey works while any other app is frontmost
- [ ] `Esc` closes the panel
- [ ] Panel opens in < 200 ms with history already rendered

### F3 — Panel UI & Keyboard Navigation

Layout (single window, two panes):

```
┌──────────────────────────────────────────────┐
│ 🔍 Search field (focused on open)            │
├──────────────────┬───────────────────────────┤
│ History list     │ Detail pane               │
│ ▸ item preview   │  full text (scrollable)   │
│   item preview   │  ── AI result (if any) ── │
│   item preview   │                           │
│                  │ [Translate] [Summarize]   │
│                  │ [Clean]     [Copy Result] │
└──────────────────┴───────────────────────────┘
```

- List row: first 2 lines of text + relative timestamp ("2m ago").
- Search field filters list live (case-insensitive substring match). *(This pulls the V1.1 "search" item into MVP because the field is structural to the layout.)*
- Keyboard: `↑/↓` moves selection, `Enter` copies the **original** selected text back to the clipboard and closes the panel, `⌘1/⌘2/⌘3` trigger Translate/Summarize/Clean on the selection, `⌘C` in detail pane copies the AI result.
- Follows system Dark/Light mode automatically (no manual toggle in MVP).

**Acceptance criteria:**
- [ ] Full flow with keyboard only: hotkey → type to filter → `↓` → `⌘1` → result appears → `Copy Result`
- [ ] `Enter` on an item puts its original text on the clipboard and closes the panel

### F4 — AI Actions

- Buttons + shortcuts run one action on the selected item.
- While running: buttons disabled, spinner shown in detail pane. Requests time out at **30 s**.
- On success: result shown in detail pane below original, stored in `item.aiResult` (overwrites previous result for that item).
- **Input cap:** send at most the first **4,000 characters**; if trimmed, note "(input truncated)" in the UI.
- On failure show an inline, human-readable error (not a raw response body):
  - No API key → "Add your Claude API key in Settings" + button that opens Settings
  - 401 → "Invalid API key"
  - 429 → "Rate limited — try again in a moment"
  - Network/timeout → "Network error — check your connection"
- `max_tokens: 1024` per request.

**Prompts** (system prompt per action; user message is the raw text — keep these exact strings in a `Prompts.swift` constants file):

| Action | System prompt |
|---|---|
| Translate | `You are a translator. If the text is mostly Korean, translate it to English. Otherwise translate it to Korean. Output ONLY the translation — no preamble, no explanations, no quotes.` |
| Summarize | `Summarize the text in 3–5 concise bullet points in the same language as the input. Output ONLY the bullet points, one per line starting with "- ".` |
| Clean | `If the text is code: fix indentation and spacing, do not change logic, output ONLY the code. If it is prose: fix grammar, spelling, and clarity while preserving meaning and tone, output ONLY the corrected text. Never add explanations.` |

**Acceptance criteria:**
- [ ] Each action returns clean output with no "Here is the translation:" preamble
- [ ] Removing the API key and running an action shows the Settings-prompt error, app does not crash
- [ ] Requests never fire without an explicit user action

### F5 — Copy Back

- **Copy Result** button (and `⌘C` in detail pane) writes `aiResult.outputText` to `NSPasteboard.general`.
- The app's own write must **not** create a new history entry (compare against last-written text, or record own `changeCount` after writing and skip it in the monitor).
- Brief "Copied ✓" confirmation, panel stays open.

**Acceptance criteria:**
- [ ] After Copy Result, pasting in another app pastes the AI output
- [ ] The copied-back result does not appear as a new history item

### F6 — Settings Window

Standard `Settings` scene (opens as a regular window):
- **API Key:** secure field, Save → Keychain, "Test key" button that fires a minimal API call and shows ✓/✗
- **Hotkey:** `KeyboardShortcuts.Recorder`
- **Launch at login:** toggle using `SMAppService.mainApp` (macOS 13+ API)
- **Clear history:** button with confirmation alert

---

## 5. Deferred to V1.1 (do not build now)

Favorites/pins, manual dark-light toggle, local-only mode toggle, multi-language pairs beyond KO↔EN, OpenAI fallback, rich text/image history.

---

## 6. Architecture & File Map

Create exactly this structure (one type per file, files < 300 lines):

```
SmartClipboardAI/
├── project.yml                        # XcodeGen spec (targets, entitlements, SPM deps)
├── SmartClipboardAI/
│   ├── App/
│   │   ├── SmartClipboardAIApp.swift  # @main, MenuBarExtra, Settings scene
│   │   └── AppState.swift             # @Observable root state, owns services
│   ├── Models/
│   │   ├── ClipboardItem.swift
│   │   └── AIResult.swift             # AIResult + AIAction
│   ├── Services/
│   │   ├── ClipboardMonitor.swift     # Timer polling, ignore rules, self-copy suppression
│   │   ├── HistoryStore.swift         # in-memory array + debounced JSON persistence
│   │   ├── ClaudeService.swift        # URLSession → /v1/messages, error mapping
│   │   ├── KeychainService.swift      # save/load/delete API key
│   │   └── Prompts.swift              # the 3 system-prompt constants
│   ├── Panel/
│   │   ├── FloatingPanel.swift        # NSPanel subclass + SwiftUI hosting
│   │   └── PanelController.swift      # show/hide/toggle, hotkey wiring
│   ├── Views/
│   │   ├── PanelRootView.swift        # search + list + detail layout
│   │   ├── HistoryListView.swift
│   │   ├── DetailPaneView.swift       # text, AI result, action buttons, errors
│   │   └── SettingsView.swift
│   └── Resources/
│       └── Info.plist                 # LSUIElement = YES
└── SmartClipboardAITests/
    ├── HistoryStoreTests.swift
    ├── ClipboardIgnoreRulesTests.swift
    └── ClaudeServiceTests.swift       # mocked URLProtocol
```

**Rules:**
- Services own no UI; Views own no business logic.
- `ClaudeService` takes the API key via `KeychainService`, exposes `func run(_ action: AIAction, on text: String) async throws -> String`.
- All async work with structured concurrency (`async/await`, `@MainActor` for state mutation).
- Errors are a single `AppError` enum mapped to the user-facing strings in §F4.

---

## 7. Privacy & Security Requirements

- Clipboard text is sent to the Claude API **only** on explicit user action — never automatically.
- Respect concealed/transient pasteboard types (never store or display them).
- API key lives only in Keychain.
- No logging of clipboard contents or API payloads (including in debug builds — no `print` of user text).
- History file is plain JSON in Application Support (acceptable for MVP; document this in README).

---

## 8. Build Plan (phased, each phase must compile + pass its checks)

### Phase 1 — Skeleton & clipboard capture
1. `project.yml` (XcodeGen) with app target, test target, sandbox + network entitlements, KeyboardShortcuts SPM dep, `LSUIElement`.
2. Menu bar app boots with icon + Quit.
3. `ClipboardMonitor` + `HistoryStore` with all F1 ignore rules and JSON persistence.
4. Unit tests: ignore rules, FIFO eviction, persistence round-trip.
- **Verify:** `xcodebuild build test` green; manual check of F1 acceptance criteria.

### Phase 2 — Panel UI
1. `FloatingPanel` + `PanelController`, hotkey toggle, `Esc`/click-outside close.
2. `PanelRootView`: search, list, detail, keyboard navigation, `Enter` copy-back of original.
- **Verify:** F2 + F3 acceptance criteria manually.

### Phase 3 — AI integration
1. `KeychainService`, `SettingsView` (key entry + test button).
2. `ClaudeService` with error mapping; `Prompts.swift`.
3. Wire Translate/Summarize/Clean buttons + shortcuts, loading/error states, Copy Result with self-copy suppression.
4. Unit tests: `ClaudeService` against mocked `URLProtocol` (success, 401, 429, timeout).
- **Verify:** F4 + F5 acceptance criteria with a real API key.

### Phase 4 — Polish
1. Launch at login, Clear history, relative timestamps, "Copied ✓" feedback, empty states ("No clipboard history yet", "No results").
2. App icon (simple SF-Symbol-derived placeholder is fine).
3. README: build instructions (`xcodegen generate && xcodebuild …`), API key setup.
- **Verify:** run the full checklist in §9.

---

## 9. Release Checklist (MVP "done" definition)

- [ ] All acceptance criteria in F1–F6 pass
- [ ] All unit tests pass; no compiler warnings
- [ ] AI actions complete in < 2 s for typical (< 1,000 char) inputs
- [ ] Panel opens in < 200 ms; idle CPU < 1 % (polling must be cheap)
- [ ] No clipboard text in logs; API key only in Keychain
- [ ] App survives: no network, invalid key, 10,000-char input, rapid repeated copies

---

## 10. Success Metrics (post-MVP, qualitative)

- Daily use replaces manual paste-into-translator workflows
- Round-trip (copy → transform → paste) under 10 seconds

## 11. Future Improvements

Shared clipboard across devices · smart snippet recognition · plugin actions · per-user prompt customization · streaming responses for long summaries.
