# Changelog

## [0.1.2] - 2026-01-13

### Added
- **Floating Overlay Window**: Configurable floating overlay for selection count display.
  - Positions: `top-left`, `top-right`, `bottom-left`, `bottom-right`
  - Configurable padding and colors via `highlight_definitions.overlay`
- **Visual Selection Support**: `Ctrl+N` now works on visual selection (not just word under cursor)
- **Insert Keys**: Added `I` (insert at start) and `A` (append at end) edit modes
- **Undo Cursor**: Added `Ctrl+U` to remove the last added cursor
- **Vim-style Operators**: Apply operations to all selected words at once:
  - `gy` - Yank all selected words
  - `g~` - Toggle case
  - `gu` - Lowercase all
  - `gU` - Uppercase all

### Fixed
- **Overlay Resize**: Overlay now repositions when terminal window is resized
- **Overlay Position Clamping**: Prevents negative positions on narrow windows
- **Multi-line Editing**: Improved sync for cursors across different lines
- **Duplicate Annotations**: Removed duplicate `@return` comments in `state.lua`

## [0.1.1] - 2026-01-10

### Added
- **Configurable Highlights**: Added `highlight_definitions` option to `setup()` allowing full customization of cursor, match, and skipped colors.

### Changed
- **Refined Defaults**: Updated default highlight colors to be more vivid and high-contrast (Black text on Bright Backgrounds) for better visibility across all colorschemes.

### Fixed
- **Critical Edit Bug**: Fixed issue where entering insert mode at the start of a word (`i`) would delete the rest of the word. Implemented robust delta-based synchronization.
- **Navigation Logic**: Fixed `Ctrl+N` jumping to incorrect match when selecting out of order. Now consistently jumps to the nearest unselected match relative to cursor.
- **EOL Cursor Fix**: Fixed cursor positioning when editing a word at the end of the line. Now correctly appends instead of landing on the last character.

### Improved
- **Unpacked Startup**: Refactored internal `init.lua` to lazy-load modules, significantly improving startup time.
- **Edit Cursor Position**: When entering edit mode from an unselected position, cursor now defaults to the **end** of the word instead of the start.

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
