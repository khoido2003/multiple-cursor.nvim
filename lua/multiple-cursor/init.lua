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
      add_next = function()
        local pos = vim.api.nvim_win_get_cursor(0)
        local line, col = pos[1], pos[2]
        
        if state.add_cursor_at_position(line, col) then
          ui.update_highlights()
          local next_match = state.get_next_unselected_match(line, col)
          if next_match then
            local end_col = next_match.col_end > 0 and next_match.col_end - 1 or next_match.col_start
            vim.api.nvim_win_set_cursor(0, { next_match.line, end_col })
          end
        end
      end,
      skip = function()
        local pos = vim.api.nvim_win_get_cursor(0)
        local line, col = pos[1], pos[2]
        
        local success, action = state.skip_at_position(line, col)
        if success then
          ui.update_highlights()
          local next_match = state.get_next_unselected_match(line, col)
          if next_match then
            local end_col = next_match.col_end > 0 and next_match.col_end - 1 or next_match.col_start
            vim.api.nvim_win_set_cursor(0, { next_match.line, end_col })
          end
        end
      end,
      next_match = function()
        -- Navigate to next match (wrap around)
        local matches = state.get_matches()
        if #matches == 0 then return end
        
        local current_pos = vim.api.nvim_win_get_cursor(0)
        local current_line, current_col = current_pos[1], current_pos[2]
        
        -- Find next match after current position
        local next_match = nil
        local first_match = nil
        for _, match in ipairs(matches) do
          if not first_match then first_match = match end
          if match.line > current_line or (match.line == current_line and match.col_start > current_col) then
            next_match = match
            break
          end
        end
        
        -- Wrap around to first match if no next found
        local target = next_match or first_match
        if target then
          local end_col = target.col_end > 0 and target.col_end - 1 or target.col_start
          vim.api.nvim_win_set_cursor(0, { target.line, end_col })
        end
      end,
      prev_match = function()
        -- Navigate to previous match (wrap around)
        local matches = state.get_matches()
        if #matches == 0 then return end
        
        local current_pos = vim.api.nvim_win_get_cursor(0)
        local current_line, current_col = current_pos[1], current_pos[2]
        
        -- Find previous match before current position
        local prev_match = nil
        local last_match = nil
        for i = #matches, 1, -1 do
          local match = matches[i]
          if not last_match then last_match = match end
          if match.line < current_line or (match.line == current_line and match.col_end <= current_col) then
            prev_match = match
            break
          end
        end
        
        -- Wrap around to last match if no prev found
        local target = prev_match or last_match
        if target then
          local end_col = target.col_end > 0 and target.col_end - 1 or target.col_start
          vim.api.nvim_win_set_cursor(0, { target.line, end_col })
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

    local total, _, _ = state.get_counts()
    ui.notify(string.format("Found %d matches for '%s'", total, word), vim.log.levels.INFO)

    -- Select the word under cursor using position-based selection
    local pos = vim.api.nvim_win_get_cursor(0)
    local line, col = pos[1], pos[2]
    state.add_cursor_at_position(line, col)
    ui.update_highlights()
    
    local next_match = state.get_next_unselected_match(line, col)
    if next_match then
      local end_col = next_match.col_end > 0 and next_match.col_end - 1 or next_match.col_start
      vim.api.nvim_win_set_cursor(0, { next_match.line, end_col })
    end
  else
    local pos = vim.api.nvim_win_get_cursor(0)
    local line, col = pos[1], pos[2]
    
    if state.add_cursor_at_position(line, col) then
      ui.update_highlights()
      local next_match = state.get_next_unselected_match(line, col)
      if next_match then
        local end_col = next_match.col_end > 0 and next_match.col_end - 1 or next_match.col_start
        vim.api.nvim_win_set_cursor(0, { next_match.line, end_col })
      end
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
