# Multiple Cursor for Neovim

A lightweight, independent Neovim plugin that provides multiple cursor functionality with intelligent word matching and easy selection/skip workflow.

## ✨ Features

- **🔍 Word Matching**: Hover on a word and trigger the plugin to find all matching occurrences
- **✅ Select/Skip Workflow**: Easy navigation to include or exclude matches
- **✏️ Synchronized Editing**: Edit all selected locations simultaneously
- **⌨️ User-Configurable Keymaps**: Full customization of all keybindings
- **📦 Zero Dependencies**: Standalone plugin using only Neovim's built-in APIs

## 📦 Installation

### Using [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  "khoido2003/multiple-cursor.nvim",
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

## 🚀 Quick Start

1. Place your cursor on any word
2. Press `<C-n>` to start multi-cursor mode
3. Press `<C-n>` again to add next match, or `<C-s>` to skip
4. Press `c` to change all selected words, or `d` to delete them
5. Press `<Esc>` to exit

## ⌨️ Default Keymaps

| Key | Action | Description |
|-----|--------|-------------|
| `<C-n>` | Start/Add Next | Start multi-cursor on word under cursor, or add next match |
| `<C-s>` | Skip Match | Skip current match and jump to next |
| `<C-p>` | Remove Last | Remove last added cursor |
| `<C-x>` | Select All | Select all remaining matches at once |
| `<Esc>` | Exit | Exit multi-cursor mode |
| `c` | Change | Delete selected words and enter insert mode |
| `d` | Delete | Delete all selected words |
| `i` | Insert | Start editing at all selected positions |

## ⚙️ Configuration

```lua
require("multiple-cursor").setup({
  -- Keymaps (set to false to disable)
  keymaps = {
    start_next = "<C-n>",      -- Start or add next match
    skip = "<C-s>",            -- Skip current match
    prev = "<C-p>",            -- Remove last cursor
    select_all = "<C-x>",      -- Select all matches
    exit = "<Esc>",            -- Exit multi-cursor mode
  },

  -- Highlight groups
  highlights = {
    cursor = "MultipleCursor",           -- Selected cursors
    match = "MultipleCursorMatch",       -- Unselected matches
    current = "MultipleCursorCurrent",   -- Current match being reviewed
  },

  -- Behavior
  match_whole_word = true,    -- Only match whole words
  case_sensitive = true,      -- Case sensitive matching
})
```

### Custom Keymaps Example

```lua
require("multiple-cursor").setup({
  keymaps = {
    start_next = "<leader>n",
    skip = "<leader>s",
    prev = "<leader>p",
    select_all = "<leader>a",
    exit = "<leader>q",
  },
})
```

### Disable Specific Keymaps

```lua
require("multiple-cursor").setup({
  keymaps = {
    start_next = "<C-n>",
    skip = false,  -- Disable skip keymap
    prev = false,  -- Disable prev keymap
    select_all = "<C-x>",
    exit = "<Esc>",
  },
})
```

## 🎨 Custom Highlights

You can customize the highlight colors:

```lua
-- After setup, override highlights
vim.api.nvim_set_hl(0, "MultipleCursor", { bg = "#2d4f2d", fg = "#98c379", bold = true })
vim.api.nvim_set_hl(0, "MultipleCursorMatch", { bg = "#3e3d32", fg = "#e6db74" })
vim.api.nvim_set_hl(0, "MultipleCursorCurrent", { bg = "#66d9ef", fg = "#272822", bold = true })
```

## 📋 Commands

| Command | Description |
|---------|-------------|
| `:MultipleCursorStart` | Start multi-cursor mode on word under cursor |
| `:MultipleCursorClear` | Clear all cursors and exit multi-cursor mode |
| `:MultipleCursorSelectAll` | Select all remaining matches |

## 🔧 API

You can also use the plugin programmatically:

```lua
local mc = require("multiple-cursor")

-- Start multi-cursor mode
mc.start()

-- Check if active
if mc.is_active() then
  print("Multi-cursor mode is active")
end

-- Exit mode
mc.exit()
```

## 📝 Workflow Example

```
1. You have a file with multiple occurrences of "foo":
   
   local foo = 1
   print(foo)
   return foo + foo

2. Place cursor on "foo" and press <C-n>
   → First "foo" is selected (green highlight)
   → Other "foo"s are shown as matches (yellow highlight)
   → Status shows: [1/4] 1 selected

3. Press <C-n> to add next match
   → Status shows: [2/4] 2 selected

4. Press <C-s> to skip third match
   → Status shows: [4/4] 2 selected

5. Press <C-n> to add fourth match
   → Status shows: [done] 3 selected

6. Press 'c' to change all selected words
   → Type "bar" to replace all selected "foo"s with "bar"

7. Press <Esc> to finish
```

## 🤝 Contributing

Contributions are welcome! Please feel free to submit issues and pull requests.

## 📄 License

MIT License - see [LICENSE](LICENSE) for details.
