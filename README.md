# multiple-cursor.nvim

A lightweight, powerful multi-cursor plugin for Neovim that feels like VS Code's multi-cursor implementation.

<p align="center">
  <img src="./gallery/1.png" width="700" alt="multiple-cursor.nvim showcase">
</p>

## Features

- **Position-Based Selection**: Select or skip specific matches based on your cursor position.
- **Real-time Sync**: Edits (insert, delete, change) are synchronized across all cursors instantly.
- **Smart Navigation**: `Ctrl+J` / `Ctrl+K` to jump between matches quickly.
- **Auto-Jump**: Automatically moves to the next unselected match after you select or skip one.
- **Preserved State**: Keeps track of skipped matches so you can come back to them.

## 📦 Installation

### Using [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  "khoido2003/multiple-cursor.nvim",
  keys = {
    { "<C-n>", "<cmd>MultipleCursorStart<cr>", desc = "Start Multiple Cursor" },
  },
  cmd = { "MultipleCursorStart", "MultipleCursorSelectAll" },
  config = function()
    require("multiple-cursor").setup()
  end,
}
```

### Using [packer.nvim](https://github.com/wbthomason/packer.nvim)

```lua
use {
  "khoido2003/multiple-cursor.nvim",
  config = function()
    require("multiple-cursor").setup()
  end,
}
```

### Manual Installation

Clone to your Neovim packages directory:

```bash
git clone https://github.com/khoido2003/multiple-cursor.nvim ~/.local/share/nvim/site/pack/plugins/start/multiple-cursor
```


## Keybindings

| Key | Action | Description |
|-----|--------|-------------|
| `<C-n>` | **Add Cursor** | Adds a cursor to the match under cursor. Works in normal and visual mode. |
| `<C-x>` | **Skip / Remove** | Skips or removes the cursor from the match under your current position. |
| `<C-j>` | **Next Match** | Jump to the next match occurrence. |
| `<C-k>` | **Prev Match** | Jump to the previous match occurrence. |
| `<C-a>` | **Select All** | Selects all remaining matches in the buffer. |
| `<C-u>` | **Undo Cursor** | Remove the last added cursor. |
| `c` / `i` / `I` / `A` | **Edit** | Enter edit mode. Changes are synced to all selected cursors. |
| `d` | **Delete** | Delete all selected words. |
| `<Esc>` | **Exit** | Exit multi-cursor mode. |

### Operators (Vim-style)

| Key | Action | Description |
|-----|--------|-------------|
| `gy` | **Yank All** | Yank all selected words to register. |
| `g~` | **Toggle Case** | Toggle case of all selected words. |
| `gu` | **Lowercase** | Convert all selected words to lowercase. |
| `gU` | **Uppercase** | Convert all selected words to UPPERCASE. |

## Usage Workflow

1. Place your cursor on a word you want to edit.
2. Press `<C-n>` to start. The current word is selected and the cursor jumps to the next match.
3. Use `<C-j>` / `<C-k>` to move between matches if needed.
4. Press `<C-n>` to add more cursors, or `<C-x>` to skip a match.
5. Press `c` (change), `d` (delete), or `i` (insert) to start editing. All selected instances will be updated simultaneously.
6. Press `<Esc>` to finish.

## Configuration

Default configuration:

```lua
require("multiple-cursor").setup({
  keymaps = {
    start_next = "<C-n>",
    skip = "<C-x>",
    next_match = "<C-j>",
    prev_match = "<C-k>",
    select_all = "<C-a>",
    exit = "<Esc>",
  },
  highlights = {
    cursor = "MultipleCursor",
    match = "MultipleCursorMatch",
    skipped = "MultipleCursorSkipped",
  },
  highlight_definitions = {
    cursor = { bg = "#00FA9A", fg = "#000000", bold = true }, -- Medium Spring Green (selected cursors)
    match = { bg = "#FFD700", fg = "#000000", bold = true }, -- Gold (unselected matches)
    skipped = { bg = "#FF6347", fg = "#000000", bold = true }, -- Tomato (skipped)
    overlay = { bg = "#E84A72", fg = "#ffffff", bold = true }, -- Rose Pink (Monokai-inspired)
  },
  -- Floating overlay window for selection count (easier to see)
  overlay = {
    enabled = true,                              -- Enable/disable the overlay
    position = "top-right",                      -- "top-left", "top-right", "bottom-left", "bottom-right"
    padding = { top = 1, right = 1, bottom = 1, left = 1 }, -- Padding from screen edges
  },
  match_whole_word = true,
  case_sensitive = true,
})
```

