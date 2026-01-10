# Changelog

## [0.1.0] - 2026-01-10

### Added
- **Position-Based Selection**: `Ctrl+N` and `Ctrl+X` now act on the match specifically under the cursor, allowing for non-sequential selection.
- **Auto-Jump Navigation**: Cursor automatically jumps to the next unselected match after selecting or skipping a word.
- **New Navigation Keys**: Added `Ctrl+J` (Next Match) and `Ctrl+K` (Previous Match) to navigate between matches without modifying selection.
- **Combined Add/Reselect**: `Ctrl+N` now handles both adding a new cursor and re-selecting a previously skipped one.

### Changed
- **Skipping Behavior**: Changed Skip keybinding to `Ctrl+X`. Skipping a match now moves it to a "skipped" state that can be re-selected later.
- **Editing Experience**: Entering edit mode (cw/c/i) no longer deletes the word first. Text remains visible and edits are synchronized in real-time.
- **Cursor Positioning**: Cursor relative position (start/middle/end of word) is preserved when entering edit mode.
- **Status Highlighting**: Improved UI highlighting to clearly distinguish between Selected (Green), Skipped (Dim Red), and Unselected (Dim Yellow) matches.
- **Status Text**: Simplified status notification to show `[Selected/Total]` count (e.g., `[2/5] selected`).

### Removed
- **Sequential Selection**: Removed rigid "next match" only logic.
- **Ctrl+P**: Removed `Ctrl+P` (Previous) in favor of `Ctrl+X` for skip/remove and `Ctrl+J/K` for navigation.
- **Implicit Word Deletion**: Words are no longer auto-deleted on change; standard Vim editing applies.

### Fixed
- Fixed issue where edits were not synchronizing across all cursors.
- Fixed cursor jumping to start of word when entering edit mode.
- Fixed "stuck" status text counters.
- Fixed highlight visibility issues for unselected matches.
