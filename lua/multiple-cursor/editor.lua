local state = require("multiple-cursor.state")
local ui = require("multiple-cursor.ui")
local finder = require("multiple-cursor.finder")

local M = {}

-- Store cursor positions at the time editing started
local edit_positions = {}
-- Track if we're currently applying changes
local applying_changes = false
-- Store autocmd group name
local augroup_name = "MultipleCursorEdit"
-- Track the last known text length at primary cursor region
local last_primary_length = 0
-- Track the last known primary line length
local last_line_len = 0

---Debug helper (set to true to enable debug messages)
local DEBUG_ENABLED = false

local function debug(msg)
  if DEBUG_ENABLED then
    vim.notify("[MC Debug] " .. msg, vim.log.levels.INFO)
  end
end

---Cleanup function to reset module state (prevents memory leaks)
function M.cleanup()
  edit_positions = {}
  applying_changes = false
  last_primary_length = 0
  last_line_len = 0
  pcall(vim.api.nvim_del_augroup_by_name, augroup_name)
end

---Start editing mode - positions cursor at current word, does NOT delete
function M.start_editing_mode()
  local bufnr = state.get_bufnr()
  local cursors = state.get_cursors()

  debug("start_editing_mode called, cursors count: " .. #cursors)

  if #cursors == 0 then
    ui.notify("No cursors selected!", vim.log.levels.WARN)
    return
  end

  -- Get current cursor position to find which selected word we're at
  local current_pos = vim.api.nvim_win_get_cursor(0)
  local current_line = current_pos[1]
  local current_col = current_pos[2]

  -- Find which cursor contains or is closest to current position
  local primary_idx = 1
  local cursor_offset = 0 -- Offset within the word (0 = start, word_len = end)
  local min_distance = math.huge

  for i, cursor in ipairs(cursors) do
    -- Check if cursor is within this word
    if cursor.line == current_line and current_col >= cursor.col_start and current_col <= cursor.col_end then
      primary_idx = i
      cursor_offset = current_col - cursor.col_start
      min_distance = 0
      break
    end

    -- Calculate distance (prioritize same line, then column distance)
    local line_dist = math.abs(cursor.line - current_line)
    local col_dist = math.min(math.abs(cursor.col_start - current_col), math.abs(cursor.col_end - current_col))
    local distance = line_dist * 10000 + col_dist

    if distance < min_distance then
      min_distance = distance
      primary_idx = i
      cursor_offset = cursor.col_end - cursor.col_start -- Default to end if not within word
    end
  end

  -- Reorder cursors so the current one is first (becomes primary)
  local reordered = {}
  reordered[1] = cursors[primary_idx]
  local idx = 2
  for i, cursor in ipairs(cursors) do
    if i ~= primary_idx then
      reordered[idx] = cursor
      idx = idx + 1
    end
  end

  -- Deep copy all cursor positions with primary first
  edit_positions = {}
  for i, cursor in ipairs(reordered) do
    edit_positions[i] = {
      line = cursor.line,
      col_start = cursor.col_start,
      col_end = cursor.col_end,
    }
    debug(
      string.format("Cursor %d: line=%d, col_start=%d, col_end=%d", i, cursor.line, cursor.col_start, cursor.col_end)
    )
  end

  -- Track initial word length at primary cursor
  last_primary_length = edit_positions[1].col_end - edit_positions[1].col_start

  -- Track initial line length
  local current_line_content =
    vim.api.nvim_buf_get_lines(bufnr, edit_positions[1].line - 1, edit_positions[1].line, false)[1]
  last_line_len = #current_line_content

  -- Position cursor at the same offset within the primary word as before
  local primary = edit_positions[1]
  local target_col = primary.col_start + cursor_offset
  -- Clamp to word boundaries
  if target_col > primary.col_end then
    target_col = primary.col_end
  end
  vim.api.nvim_win_set_cursor(0, { primary.line, target_col })

  -- Show highlights on all edit positions
  ui.update_edit_highlights(edit_positions)

  -- Setup autocmds
  local group = vim.api.nvim_create_augroup(augroup_name, { clear = true })

  vim.api.nvim_create_autocmd({ "TextChangedI", "TextChangedP" }, {
    group = group,
    buffer = bufnr,
    callback = function()
      if applying_changes then
        return
      end
      M.sync_from_primary()
    end,
  })

  vim.api.nvim_create_autocmd("InsertLeave", {
    group = group,
    buffer = bufnr,
    once = true,
    callback = function()
      M.stop_editing()
      ui.notify("Editing complete", vim.log.levels.INFO)
    end,
  })

  ui.notify(
    string.format("Editing %d locations. Edit normally, <Esc> to finish.", #edit_positions),
    vim.log.levels.INFO
  )

  -- Enter insert mode
  -- If targeting the end of the line, use append ('A' behavior)
  -- because nvim_win_set_cursor will clamp to the last character
  if target_col >= last_line_len then
    vim.cmd("startinsert!")
  else
    vim.cmd("startinsert")
  end
end

---Sync changes from primary cursor to all secondary cursors
function M.sync_from_primary()
  if applying_changes then
    return
  end
  applying_changes = true

  local bufnr = state.get_bufnr()
  local primary = edit_positions[1]
  local line_content_list = vim.api.nvim_buf_get_lines(bufnr, primary.line - 1, primary.line, false)
  if not line_content_list or #line_content_list == 0 then
    applying_changes = false
    return
  end
  local line_content = line_content_list[1]

  -- Get cursor position to determine new text boundaries
  local cursor_pos = vim.api.nvim_win_get_cursor(0)
  local cursor_col = cursor_pos[2]

  -- Calculate new word boundaries based on cursor movement from col_start
  -- The new text extends from col_start to the current cursor position
  -- But we need to account for the offset within the word
  local current_line_len = #line_content
  local delta = current_line_len - last_line_len

  -- New primary length = original length + delta
  local new_primary_length = last_primary_length + delta
  if new_primary_length < 0 then
    new_primary_length = 0
  end

  -- Extract the new text at primary position
  local new_text = line_content:sub(primary.col_start + 1, primary.col_start + new_primary_length)

  debug(
    string.format(
      "sync: delta=%d, new_text='%s', new_length=%d, last_length=%d",
      delta,
      new_text,
      new_primary_length,
      last_primary_length
    )
  )

  -- Check if text actually changed
  local old_text = line_content:sub(primary.col_start + 1, primary.col_start + last_primary_length)
  if new_text == old_text and delta == 0 then
    applying_changes = false
    return
  end

  -- Group cursors by line for proper offset adjustment
  -- When editing multiple cursors on the same line, we need to adjust
  -- positions right-to-left to avoid offset corruption

  -- Sort indices by line (descending) then by col_start (descending)
  -- This ensures we edit from bottom-to-top and right-to-left
  local indices = {}
  for i = 2, #edit_positions do
    table.insert(indices, i)
  end

  table.sort(indices, function(a, b)
    local pa, pb = edit_positions[a], edit_positions[b]
    if pa.line ~= pb.line then
      return pa.line > pb.line
    end
    return pa.col_start > pb.col_start -- Right-to-left on same line
  end)

  -- Track column offset adjustments per line
  local line_offsets = {}

  for _, i in ipairs(indices) do
    local pos = edit_positions[i]
    local offset = line_offsets[pos.line] or 0

    -- Adjust position by any previous edits on the same line
    local adjusted_col_start = pos.col_start + offset
    local adjusted_col_end = pos.col_end + offset

    debug(
      string.format(
        "Syncing to pos %d (line %d): replacing [%d,%d] (adjusted from [%d,%d]) with '%s'",
        i,
        pos.line,
        adjusted_col_start,
        adjusted_col_end,
        pos.col_start,
        pos.col_end,
        new_text
      )
    )

    local ok = pcall(function()
      vim.api.nvim_buf_set_text(bufnr, pos.line - 1, adjusted_col_start, pos.line - 1, adjusted_col_end, { new_text })
    end)

    if ok then
      -- Calculate the length change for this edit
      local old_len = pos.col_end - pos.col_start
      local new_len = #new_text
      local len_change = new_len - old_len

      -- Update the stored position
      pos.col_start = adjusted_col_start
      pos.col_end = adjusted_col_start + new_len

      -- We're going right-to-left, so no need to accumulate offset for positions
      -- to our right (they're already processed). But for consistency, track it.
      -- Actually, since we process right-to-left, earlier (left) positions on same
      -- line don't need adjustment from this edit.

      debug("Sync succeeded, new col_end=" .. pos.col_end)
    end
  end

  -- Update primary col_end and state
  primary.col_end = primary.col_start + #new_text
  last_primary_length = new_primary_length
  last_line_len = current_line_len

  applying_changes = false

  -- Update highlights to show all edit positions
  ui.update_edit_highlights(edit_positions)
end

---Start editing (called by 'i' key) - keeps words visible
function M.start_editing()
  M.start_editing_mode()
end

---Stop editing mode and cleanup
function M.stop_editing()
  pcall(vim.api.nvim_del_augroup_by_name, augroup_name)

  -- Re-scan for matches of the new word to keep UI consistent
  -- This ensures that after editing 'foo' to 'bar', we start matching all 'bar's
  local bufnr = state.get_bufnr()
  local cursors = state.get_cursors()

  if #cursors > 0 then
    -- Get the new word from the first cursor position
    local first = cursors[1]
    local lines = vim.api.nvim_buf_get_lines(bufnr, first.line - 1, first.line, false)
    if lines and #lines > 0 then
      local new_word = lines[1]:sub(first.col_start + 1, first.col_end)
      if new_word and new_word ~= "" then
        -- Find all matches for this new word
        -- Use the configured matching logic (e.g. case sensitivity)
        local new_matches = finder.find_matches(new_word, bufnr)

        -- Update state with new word and matches
        state.update_matches(new_word, new_matches)

        -- Update highlights to show potential candidates
        ui.update_highlights()
      end
    end
  end

  edit_positions = {}
  last_primary_length = 0
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

  -- Sort in reverse order
  local sorted_cursors = vim.deepcopy(cursors)
  table.sort(sorted_cursors, function(a, b)
    if a.line ~= b.line then
      return a.line > b.line
    end
    return a.col_start > b.col_start
  end)

  -- Track offset adjustments per line for cursors on the same line
  local line_offsets = {}

  -- Delete at each position (reverse order)
  for _, cursor in ipairs(sorted_cursors) do
    local offset = line_offsets[cursor.line] or 0
    local adjusted_start = cursor.col_start + offset
    local adjusted_end = cursor.col_end + offset
    local deleted_len = cursor.col_end - cursor.col_start

    vim.api.nvim_buf_set_text(bufnr, cursor.line - 1, adjusted_start, cursor.line - 1, adjusted_end, { "" })

    -- Track offset for other cursors on same line
    line_offsets[cursor.line] = offset - deleted_len
  end

  -- Update the actual cursor positions in state to reflect deleted text
  -- Reset offsets for forward pass
  line_offsets = {}
  for _, cursor in ipairs(cursors) do
    local offset = line_offsets[cursor.line] or 0
    local deleted_len = cursor.col_end - cursor.col_start

    -- Apply offset to this cursor
    cursor.col_start = cursor.col_start + offset
    cursor.col_end = cursor.col_start -- Now empty (col_end = col_start)

    -- Track offset for subsequent cursors on same line
    line_offsets[cursor.line] = offset - deleted_len
  end

  ui.notify(string.format("Deleted %d occurrences", #cursors), vim.log.levels.INFO)
  ui.update_highlights()
end

---Perform a change operation - same as start_editing (keeps words visible)
function M.change_word()
  M.start_editing_mode()
end

---Start editing at the start of all words (for 'I' key)
function M.start_editing_at_start()
  local cursors = state.get_cursors()

  if #cursors == 0 then
    ui.notify("No cursors selected!", vim.log.levels.WARN)
    return
  end

  -- Force cursor to start of first word
  local first_cursor = cursors[1]
  vim.api.nvim_win_set_cursor(0, { first_cursor.line, first_cursor.col_start })

  -- Then start normal editing (which will pick up cursor position)
  M.start_editing_mode()
end

---Start editing at the end of all words (for 'A' key)
function M.start_editing_at_end()
  local cursors = state.get_cursors()

  if #cursors == 0 then
    ui.notify("No cursors selected!", vim.log.levels.WARN)
    return
  end

  -- Force cursor to end of first word
  local first_cursor = cursors[1]
  local end_col = first_cursor.col_end > 0 and first_cursor.col_end or first_cursor.col_start
  vim.api.nvim_win_set_cursor(0, { first_cursor.line, end_col })

  -- Then start normal editing (which will pick up cursor position)
  M.start_editing_mode()
end

---Yank all selected words to register
function M.yank_all()
  local bufnr = state.get_bufnr()
  local cursors = state.get_cursors()

  if #cursors == 0 then
    ui.notify("No cursors selected!", vim.log.levels.WARN)
    return
  end

  -- Collect all words
  local words = {}
  for _, cursor in ipairs(cursors) do
    local lines = vim.api.nvim_buf_get_lines(bufnr, cursor.line - 1, cursor.line, false)
    if lines and #lines > 0 then
      local word = lines[1]:sub(cursor.col_start + 1, cursor.col_end)
      table.insert(words, word)
    end
  end

  -- Join and yank to default register
  local text = table.concat(words, "\n")
  vim.fn.setreg('"', text)
  vim.fn.setreg("0", text)

  ui.notify(string.format("Yanked %d words", #words), vim.log.levels.INFO)
end

---Toggle case of all selected words
function M.toggle_case()
  local bufnr = state.get_bufnr()
  local cursors = state.get_cursors()

  if #cursors == 0 then
    ui.notify("No cursors selected!", vim.log.levels.WARN)
    return
  end

  -- Sort in reverse order for safe editing
  local sorted_cursors = vim.deepcopy(cursors)
  table.sort(sorted_cursors, function(a, b)
    if a.line ~= b.line then
      return a.line > b.line
    end
    return a.col_start > b.col_start
  end)

  for _, cursor in ipairs(sorted_cursors) do
    local lines = vim.api.nvim_buf_get_lines(bufnr, cursor.line - 1, cursor.line, false)
    if lines and #lines > 0 then
      local word = lines[1]:sub(cursor.col_start + 1, cursor.col_end)
      -- Toggle: if mostly upper, make lower; if mostly lower, make upper
      local upper_count = 0
      for i = 1, #word do
        local c = word:sub(i, i)
        if c:match("%u") then
          upper_count = upper_count + 1
        end
      end
      local new_word
      if upper_count > #word / 2 then
        new_word = word:lower()
      else
        new_word = word:upper()
      end
      vim.api.nvim_buf_set_text(bufnr, cursor.line - 1, cursor.col_start, cursor.line - 1, cursor.col_end, { new_word })
    end
  end

  ui.notify(string.format("Toggled case of %d words", #cursors), vim.log.levels.INFO)
  ui.update_highlights()
end

---Lowercase all selected words
function M.lowercase()
  local bufnr = state.get_bufnr()
  local cursors = state.get_cursors()

  if #cursors == 0 then
    ui.notify("No cursors selected!", vim.log.levels.WARN)
    return
  end

  -- Sort in reverse order
  local sorted_cursors = vim.deepcopy(cursors)
  table.sort(sorted_cursors, function(a, b)
    if a.line ~= b.line then
      return a.line > b.line
    end
    return a.col_start > b.col_start
  end)

  for _, cursor in ipairs(sorted_cursors) do
    local lines = vim.api.nvim_buf_get_lines(bufnr, cursor.line - 1, cursor.line, false)
    if lines and #lines > 0 then
      local word = lines[1]:sub(cursor.col_start + 1, cursor.col_end)
      vim.api.nvim_buf_set_text(
        bufnr,
        cursor.line - 1,
        cursor.col_start,
        cursor.line - 1,
        cursor.col_end,
        { word:lower() }
      )
    end
  end

  ui.notify(string.format("Lowercased %d words", #cursors), vim.log.levels.INFO)
  ui.update_highlights()
end

---Uppercase all selected words
function M.uppercase()
  local bufnr = state.get_bufnr()
  local cursors = state.get_cursors()

  if #cursors == 0 then
    ui.notify("No cursors selected!", vim.log.levels.WARN)
    return
  end

  -- Sort in reverse order
  local sorted_cursors = vim.deepcopy(cursors)
  table.sort(sorted_cursors, function(a, b)
    if a.line ~= b.line then
      return a.line > b.line
    end
    return a.col_start > b.col_start
  end)

  for _, cursor in ipairs(sorted_cursors) do
    local lines = vim.api.nvim_buf_get_lines(bufnr, cursor.line - 1, cursor.line, false)
    if lines and #lines > 0 then
      local word = lines[1]:sub(cursor.col_start + 1, cursor.col_end)
      vim.api.nvim_buf_set_text(
        bufnr,
        cursor.line - 1,
        cursor.col_start,
        cursor.line - 1,
        cursor.col_end,
        { word:upper() }
      )
    end
  end

  ui.notify(string.format("Uppercased %d words", #cursors), vim.log.levels.INFO)
  ui.update_highlights()
end

return M
