local config = require("multiple-cursor.config")
local state = require("multiple-cursor.state")
local finder = require("multiple-cursor.finder")
local ui = require("multiple-cursor.ui")
local editor = require("multiple-cursor.editor")
local keymaps = require("multiple-cursor.keymaps")

local M = {}

---Exit multi-cursor mode and cleanup
local function exit_mode()
	if not state.is_active() then
		return
	end

	-- Stop any editing
	editor.stop_editing()

	-- Clear highlights
	ui.clear_highlights()

	-- Clear keymaps
	keymaps.clear_keymaps()

	-- Reset state
	state.reset()

	ui.notify("Exited multi-cursor mode", vim.log.levels.INFO)
end

---Start multi-cursor mode on word under cursor
local function start_or_add_next()
	if not state.is_active() then
		-- Start new multi-cursor session
		local word = finder.get_word_under_cursor()
		if word == "" then
			ui.notify("No word under cursor", vim.log.levels.WARN)
			return
		end

		local bufnr = vim.api.nvim_get_current_buf()
		local matches = finder.find_matches_from_cursor(word, bufnr)

		if #matches == 0 then
			ui.notify("No matches found for: " .. word, vim.log.levels.WARN)
			return
		end

		-- Initialize state
		state.init()
		state.start(word, bufnr, matches)

		-- Setup keymaps for active mode
		keymaps.setup_active_keymaps(bufnr, {
			add_next = start_or_add_next,
			skip = function()
				if state.skip_current() then
					ui.update_highlights()
					ui.jump_to_current()
				else
					ui.notify("No more matches", vim.log.levels.INFO)
				end
			end,
			prev = function()
				if state.remove_last() then
					ui.update_highlights()
				else
					ui.notify("No cursors to remove", vim.log.levels.WARN)
				end
			end,
			select_all = function()
				state.select_all()
				ui.update_highlights()
				ui.notify("Selected all matches", vim.log.levels.INFO)
			end,
			exit = exit_mode,
			change = function()
				if #state.get_cursors() > 0 then
					editor.change_word()
				else
					ui.notify("Select at least one match first", vim.log.levels.WARN)
				end
			end,
			delete = function()
				if #state.get_cursors() > 0 then
					editor.delete_word()
					exit_mode()
				else
					ui.notify("Select at least one match first", vim.log.levels.WARN)
				end
			end,
			insert = function()
				if #state.get_cursors() > 0 then
					editor.start_editing()
				else
					ui.notify("Select at least one match first", vim.log.levels.WARN)
				end
			end,
		})

		-- Add first match as cursor
		state.add_cursor()

		-- Update UI
		ui.update_highlights()
		ui.jump_to_current()

		local total, selected, _ = state.get_counts()
		ui.notify(string.format("Found %d matches for '%s'", total, word), vim.log.levels.INFO)
	else
		-- Add next match
		if state.add_cursor() then
			ui.update_highlights()
			ui.jump_to_current()
		else
			ui.notify("No more matches", vim.log.levels.INFO)
		end
	end
end

---Setup the plugin
---@param opts? MultipleCursor.Config
function M.setup(opts)
	-- Setup configuration
	config.setup(opts)

	-- Initialize state
	state.init()

	-- Setup highlights
	ui.setup_highlights()

	-- Setup global keymaps
	keymaps.setup_global_keymaps(start_or_add_next)

	-- Create user commands
	vim.api.nvim_create_user_command("MultipleCursorStart", function()
		start_or_add_next()
	end, { desc = "Start multi-cursor mode on word under cursor" })

	vim.api.nvim_create_user_command("MultipleCursorClear", function()
		exit_mode()
	end, { desc = "Clear all cursors and exit multi-cursor mode" })

	vim.api.nvim_create_user_command("MultipleCursorSelectAll", function()
		if state.is_active() then
			state.select_all()
			ui.update_highlights()
			ui.notify("Selected all matches", vim.log.levels.INFO)
		else
			ui.notify("Start multi-cursor mode first", vim.log.levels.WARN)
		end
	end, { desc = "Select all remaining matches" })
end

-- Export functions for external use
M.start = start_or_add_next
M.exit = exit_mode
M.is_active = state.is_active

return M
