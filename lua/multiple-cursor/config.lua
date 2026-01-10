---@class MultipleCursor.Keymaps
---@field start_next string|false Keymap to start or add next match
---@field skip string|false Keymap to skip current match
---@field prev string|false Keymap to remove last cursor
---@field select_all string|false Keymap to select all matches
---@field exit string|false Keymap to exit multi-cursor mode

---@class MultipleCursor.Highlights
---@field cursor string Highlight group for selected cursors
---@field match string Highlight group for unselected matches
---@field current string Highlight group for current match

---@class MultipleCursor.Config
---@field keymaps MultipleCursor.Keymaps
---@field highlights MultipleCursor.Highlights
---@field match_whole_word boolean Only match whole words
---@field case_sensitive boolean Case sensitive matching

local M = {}

---@type MultipleCursor.Config
M.defaults = {
	keymaps = {
		start_next = "<C-n>",
		skip = "<C-s>",
		prev = "<C-p>",
		select_all = "<C-x>",
		exit = "<Esc>",
	},
	highlights = {
		cursor = "MultipleCursor",
		match = "MultipleCursorMatch",
		current = "MultipleCursorCurrent",
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
