---@class MultipleCursor.Keymaps
---@field start_next string|false Keymap to start or add next match
---@field skip string|false Keymap to skip current match
---@field select_all string|false Keymap to select all matches
---@field exit string|false Keymap to exit multi-cursor mode

---@class MultipleCursor.Highlights
---@field cursor string Highlight group for selected cursors
---@field match string Highlight group for unselected matches
---@field current string Highlight group for current match
---@field skipped? string Highlight group for skipped matches

---@alias MultipleCursor.HighlightDefinition vim.api.keyset.highlight

---@class MultipleCursor.HighlightDefinitions
---@field cursor? MultipleCursor.HighlightDefinition
---@field match? MultipleCursor.HighlightDefinition
---@field current? MultipleCursor.HighlightDefinition
---@field skipped? MultipleCursor.HighlightDefinition

---@class MultipleCursor.Config
---@field keymaps MultipleCursor.Keymaps
---@field highlights MultipleCursor.Highlights
---@field highlight_definitions? MultipleCursor.HighlightDefinitions
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
    current = "MultipleCursorCurrent",
    skipped = "MultipleCursorSkipped",
  },
  highlight_definitions = {
    cursor = { bg = "#50fa7b", fg = "#000000", bold = true }, -- Vivid Green with Black text
    match = { bg = "#f1fa8c", fg = "#000000", bold = true }, -- Bright Yellow with Black text
    current = { bg = "#8be9fd", fg = "#000000", bold = true }, -- Cyan with Black text
    skipped = { bg = "#ff5555", fg = "#000000", strikethrough = true }, -- Red with Black text
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
