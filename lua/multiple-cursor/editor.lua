local state = require("multiple-cursor.state")
local ui = require("multiple-cursor.ui")

local M = {}

-- Store the original text at each cursor position
local original_texts = {}
-- Track if we're currently applying changes (to prevent recursion)
local applying_changes = false
-- Store autocmd IDs for cleanup
local autocmd_ids = {}
-- Track the primary cursor position and changes
local primary_cursor = nil
local last_text = nil

---Get text at a cursor position
---@param bufnr number
---@param cursor MultipleCursor.CursorPosition
---@return string
local function get_text_at_cursor(bufnr, cursor)
	local line = vim.api.nvim_buf_get_lines(bufnr, cursor.line - 1, cursor.line, false)[1]
	if line then
		return line:sub(cursor.col_start + 1, cursor.col_end)
	end
	return ""
end

---Replace text at a cursor position
---@param bufnr number
---@param cursor MultipleCursor.CursorPosition
---@param new_text string
local function replace_at_cursor(bufnr, cursor, new_text)
	vim.api.nvim_buf_set_text(bufnr, cursor.line - 1, cursor.col_start, cursor.line - 1, cursor.col_end, { new_text })
end

---Start editing mode - setup autocmds for synchronized editing
function M.start_editing()
	local bufnr = state.get_bufnr()
	local cursors = state.get_cursors()

	if #cursors == 0 then
		ui.notify("No cursors selected!", vim.log.levels.WARN)
		return
	end

	-- Store original text at each position
	original_texts = {}
	for i, cursor in ipairs(cursors) do
		original_texts[i] = get_text_at_cursor(bufnr, cursor)
	end

	-- Set primary cursor to first selected cursor
	primary_cursor = cursors[1]
	last_text = original_texts[1]

	-- Move to primary cursor position
	vim.api.nvim_win_set_cursor(0, { primary_cursor.line, primary_cursor.col_start })

	-- Setup autocmd for text changes
	local group = vim.api.nvim_create_augroup("MultipleCursorEdit", { clear = true })

	-- Track changes in insert mode
	table.insert(
		autocmd_ids,
		vim.api.nvim_create_autocmd({ "TextChangedI", "TextChangedP" }, {
			group = group,
			buffer = bufnr,
			callback = function()
				if applying_changes then
					return
				end
				M.sync_changes()
			end,
		})
	)

	-- Also handle normal mode changes (for operators like cw)
	table.insert(
		autocmd_ids,
		vim.api.nvim_create_autocmd("TextChanged", {
			group = group,
			buffer = bufnr,
			callback = function()
				if applying_changes then
					return
				end
				M.sync_changes()
			end,
		})
	)

	ui.notify(string.format("Editing %d locations. Type to edit, <Esc> to finish.", #cursors), vim.log.levels.INFO)
end

---Synchronize changes from primary cursor to all other cursors
function M.sync_changes()
	if applying_changes then
		return
	end

	local bufnr = state.get_bufnr()
	local cursors = state.get_cursors()

	if #cursors == 0 or not primary_cursor then
		return
	end

	-- Get current cursor position
	local cur_pos = vim.api.nvim_win_get_cursor(0)
	local cur_line = cur_pos[1]
	local cur_col = cur_pos[2]

	-- Find what changed at primary position
	-- We need to figure out the new text at the primary cursor region
	local line_content = vim.api.nvim_buf_get_lines(bufnr, primary_cursor.line - 1, primary_cursor.line, false)[1]
	if not line_content then
		return
	end

	-- Calculate offset from original position
	local original_len = #(original_texts[1] or "")
	local col_offset = cur_col - primary_cursor.col_start

	-- Estimate new text length based on cursor position
	-- This is a simplified approach - we'll track the region more carefully
	local new_end = primary_cursor.col_start + math.max(0, col_offset + 1)
	local new_text = line_content:sub(primary_cursor.col_start + 1, new_end)

	if new_text == last_text then
		return -- No change
	end

	last_text = new_text

	-- Apply changes to other cursors
	applying_changes = true

	-- Sort cursors in reverse order (bottom to top, right to left) to avoid position shifts
	local sorted_cursors = {}
	for i = 2, #cursors do
		table.insert(sorted_cursors, { idx = i, cursor = cursors[i] })
	end
	table.sort(sorted_cursors, function(a, b)
		if a.cursor.line ~= b.cursor.line then
			return a.cursor.line > b.cursor.line
		end
		return a.cursor.col_start > b.cursor.col_start
	end)

	for _, item in ipairs(sorted_cursors) do
		local cursor = item.cursor
		local orig_text = original_texts[item.idx]
		if orig_text then
			replace_at_cursor(bufnr, cursor, new_text)
			-- Update cursor end position
			cursor.col_end = cursor.col_start + #new_text
		end
	end

	-- Update primary cursor end position
	primary_cursor.col_end = primary_cursor.col_start + #new_text

	applying_changes = false

	-- Update highlights
	ui.update_highlights()
end

---Stop editing mode and cleanup
function M.stop_editing()
	-- Clear autocmds
	vim.api.nvim_del_augroup_by_name("MultipleCursorEdit")
	autocmd_ids = {}

	-- Reset tracking variables
	original_texts = {}
	primary_cursor = nil
	last_text = nil
	applying_changes = false
end

---Perform a delete operation at all cursor positions
function M.delete_word()
	local bufnr = state.get_bufnr()
	local cursors = state.get_cursors()

	if #cursors == 0 then
		ui.notify("No cursors selected!", vim.log.levels.WARN)
		return
	end

	-- Sort cursors in reverse order to avoid position shifts
	local sorted_cursors = vim.deepcopy(cursors)
	table.sort(sorted_cursors, function(a, b)
		if a.line ~= b.line then
			return a.line > b.line
		end
		return a.col_start > b.col_start
	end)

	-- Delete at each position
	for _, cursor in ipairs(sorted_cursors) do
		vim.api.nvim_buf_set_text(bufnr, cursor.line - 1, cursor.col_start, cursor.line - 1, cursor.col_end, { "" })
	end

	ui.notify(string.format("Deleted %d occurrences", #cursors), vim.log.levels.INFO)
end

---Perform a change operation (delete and enter insert mode)
function M.change_word()
	M.delete_word()
	-- The delete already happened, now enter insert mode at first cursor position
	local cursors = state.get_cursors()
	if #cursors > 0 then
		local first = cursors[1]
		vim.api.nvim_win_set_cursor(0, { first.line, first.col_start })
		vim.cmd("startinsert")
		M.start_editing()
	end
end

return M
