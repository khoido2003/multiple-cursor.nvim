---@class MultipleCursor.Keymaps
---@field start_next string|false Keymap to start or add next match
---@field skip string|false Keymap to skip current match
---@field select_all string|false Keymap to select all matches
---@field exit string|false Keymap to exit multi-cursor mode

---@class MultipleCursor.Highlights
---@field cursor string Highlight group for selected cursors
---@field match string Highlight group for unselected matches
---@field skipped? string Highlight group for skipped matches

---@alias MultipleCursor.HighlightDefinition vim.api.keyset.highlight

---@class MultipleCursor.HighlightDefinitions
---@field cursor? MultipleCursor.HighlightDefinition
---@field match? MultipleCursor.HighlightDefinition
---@field skipped? MultipleCursor.HighlightDefinition
---@field overlay? MultipleCursor.HighlightDefinition

---@class MultipleCursor.OverlayPadding
---@field top? number Padding from top edge (default: 1)
---@field right? number Padding from right edge (default: 1)
---@field bottom? number Padding from bottom edge (default: 1)
---@field left? number Padding from left edge (default: 1)

---@alias MultipleCursor.OverlayPosition "top-left"|"top-right"|"bottom-left"|"bottom-right"

---@class MultipleCursor.OverlayConfig
---@field enabled boolean Enable/disable the overlay window
---@field position MultipleCursor.OverlayPosition Position on screen
---@field padding MultipleCursor.OverlayPadding Padding from screen edges

---@class MultipleCursor.Config
---@field keymaps MultipleCursor.Keymaps
---@field highlights MultipleCursor.Highlights
---@field highlight_definitions? MultipleCursor.HighlightDefinitions
---@field overlay MultipleCursor.OverlayConfig Overlay window configuration
---@field match_whole_word boolean Only match whole words
---@field case_sensitive boolean Case sensitive matching

local M = {}

---@type MultipleCursor.Config
M.defaults = {
  keymaps = {
    start_next = "<C-n>",
    skip = "<C-x>",
    next_match = "<C-j>", -- Navigate to next match
    prev_match = "<C-k>", -- Navigate to previous match
    select_all = "<C-a>",
    exit = "<Esc>",
  },
  highlights = {
    cursor = "MultipleCursor",
    match = "MultipleCursorMatch",
    skipped = "MultipleCursorSkipped",
  },
  highlight_definitions = {
    cursor = { bg = "#00FA9A", fg = "#000000", bold = true }, -- Medium Spring Green (softer on eyes)
    match = { bg = "#FFD700", fg = "#000000", bold = true }, -- Gold (warmer than Monokai yellow)
    skipped = { bg = "#FF6347", fg = "#000000", bold = true }, -- Tomato (redder than Monokai orange)
    overlay = { bg = "#E84A72", fg = "#ffffff", bold = true }, -- Rose Pink (Monokai-inspired, slightly shifted)
  },
  overlay = {
    enabled = true,
    position = "top-right",
    padding = { top = 1, right = 1, bottom = 1, left = 1 },
  },
  match_whole_word = true,
  case_sensitive = true,
}

---@type MultipleCursor.Config
M.options = {}

---Setup configuration with user options
---@param opts? MultipleCursor.Config
function M.setup(opts)
  M.options = vim.tbl_deep_extend("force", {}, M.defaults, opts or {})
end

---Get current configuration
---@return MultipleCursor.Config
function M.get()
  return M.options
end

return M
