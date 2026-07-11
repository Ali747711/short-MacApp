# Favorites / Pins — Design Spec

**Date:** 2026-07-11
**Status:** Approved
**Scope:** V1.1 feature for Smart Clipboard AI — pin clipboard items so they are never evicted and surface in a dedicated section.

## Goal

Let the user pin (favorite) clipboard items. Pinned items are exempt from the
100-item FIFO cap, appear in a dedicated "Pinned" section at the top of the
list, and survive "Clear History".

## Decisions

1. **Eviction:** The 100-item cap applies only to **un-pinned** items. Favorites
   are never evicted, regardless of how many exist.
2. **Display:** The history list is split into two sections — **Pinned** (top)
   and **Recent** (below). An empty section hides its header. Selection binds
   across both sections.
3. **Clear History:** Removes only un-pinned items; pinned favorites survive.

## Data Model

`ClipboardItem` gains `var isFavorite: Bool` (default `false`).

- Codable persistence: existing `history.json` entries predate the field, so
  `ClipboardItem` implements a custom `init(from:)` that reads
  `decodeIfPresent(Bool.self, forKey: .isFavorite) ?? false`. No migration step,
  no data loss. Encoding uses the synthesized behavior.
- `Equatable`/`Identifiable` conformances are unchanged.

## HistoryStore

- **Eviction** (`add`): insert the new item at the front, then while the count of
  **non-favorite** items exceeds `maxItems` (100), remove the oldest non-favorite
  (the last non-favorite in the array). Favorites are skipped by eviction.
- **`toggleFavorite(for id: ClipboardItem.ID)`**: flips `isFavorite` on the
  matching item and schedules a debounced save. No-op if the id is absent.
- **`clear()`**: now removes only non-favorite items (`items.removeAll { !$0.isFavorite }`)
  and schedules a save. Favorites are retained.
- Store order remains insertion order (newest first). The Pinned/Recent split is
  a view concern, not a storage concern.

## Views

- **HistoryListView**: partitions the passed-in (already filtered) items into
  `pinned` (`isFavorite == true`) and `recent`. Renders a single `List` with a
  `Section("Pinned")` and a `Section("Recent")`; each section is omitted when
  empty. Rows in the Pinned section (or any favorited row) show a filled star
  (`star.fill`). Selection binding is unchanged.
- **DetailPaneView**: adds a star toggle in the header that pins/unpins the
  selected item, bound to **⌘P**. Shows `star` when un-pinned, `star.fill` when
  pinned. Disabled when no item is selected.

## PanelViewModel

- Add `func toggleFavorite(_ item: ClipboardItem)` → `history.toggleFavorite(for: item.id)`.
- `PanelRootView` passes a closure into `DetailPaneView` and the pinned-star
  handler.

## Interactions

- Pin/unpin: select an item, then click the detail-pane star or press **⌘P**.
- Search: filtering happens first; the filtered result is then split into
  Pinned/Recent, so search spans both.

## Settings

- The Clear History confirmation message updates to reflect the new behavior,
  e.g. "This removes all un-pinned items. Pinned favorites are kept."

## Tests (HistoryStoreTests)

1. **Favorite exempt from eviction:** add 100 non-favorites + 1 favorite (or
   favorite an item, then add 100+ more) → the favorite remains; non-favorite
   count stays capped at 100.
2. **toggleFavorite flips + persists:** toggle on, save, reload → item is
   favorited; toggle again → un-favorited.
3. **clear keeps favorites:** favorite one item, add others, `clear()` → only the
   favorite remains.
4. **Backward-compat decode:** decode a history JSON payload lacking `isFavorite`
   → item decodes with `isFavorite == false`.

UI behavior (section split, star toggle, ⌘P) is verified manually.

## Out of Scope (YAGNI)

Drag-to-reorder pins, a maximum pin count, a separate favorites file, and any
sync. Favorites live in the same `history.json` as everything else.
