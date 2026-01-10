local state = require("multiple-cursor.state")
local ui = require("multiple-cursor.ui")

local M = {}

-- Store cursor positions at the time editing started
local edit_positions = {}
-- Track if we're currently applying changes
local applying_changes = false
-- Store autocmd group name
local augroup_name = "MultipleCursorEdit"
-- Track the last known text length at primary cursor region
local last_primary_length = 0

---Debug helper (set to true to enable debug messages)
local DEBUG_ENABLED = false

local function debug(msg)
  if DEBUG_ENABLED then
    vim.notify("[MC Debug] " .. msg, vim.log.levels.INFO)
  end
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
  local cursor_offset = 0  -- Offset within the word (0 = start, word_len = end)
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
      cursor_offset = 0  -- Default to start if not within word
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
    debug(string.format("Cursor %d: line=%d, col_start=%d, col_end=%d", 
      i, cursor.line, cursor.col_start, cursor.col_end))
  end

  -- Track initial word length at primary cursor
  last_primary_length = edit_positions[1].col_end - edit_positions[1].col_start

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

  ui.notify(string.format("Editing %d locations. Edit normally, <Esc> to finish.", #edit_positions), vim.log.levels.INFO)

  -- Enter insert mode at the start of the word
  vim.cmd("startinsert")
end

---Sync changes from primary cursor to all secondary cursors
function M.sync_from_primary()
  if applying_changes or #edit_positions < 2 then
    return
  end

  local bufnr = state.get_bufnr()
  local primary = edit_positions[1]

  -- Get current cursor position
  local cur_pos = vim.api.nvim_win_get_cursor(0)
  local cur_col = cur_pos[2]

  -- Get line content at primary cursor
  local lines = vim.api.nvim_buf_get_lines(bufnr, primary.line - 1, primary.line, false)
  if not lines or #lines == 0 then
    return
  end
  local line_content = lines[1]

  -- Calculate the new length of the region at primary
  -- The region starts at col_start and extends to wherever cursor is now
  -- We need to figure out how much text is now in the "word" region
  
  -- The cursor position tells us where the user is typing
  -- new_col_end = cursor position (user is typing here)
  -- But we need to account for text that might be after the cursor too
  
  -- For simplicity: track the text from col_start to the cursor position
  -- This represents what the user has typed/modified so far
  local new_text = line_content:sub(primary.col_start + 1, cur_col)
  local new_length = cur_col - primary.col_start

  debug(string.format("sync: new_text='%s', new_length=%d, last_length=%d", 
    new_text, new_length, last_primary_length))

  -- Check if length changed
  if new_length == last_primary_length then
    return
  end

  last_primary_length = new_length

  applying_changes = true

  -- Apply the same text to all secondary cursors
  -- Sort in reverse order
  local indices = {}
  for i = 2, #edit_positions do
    table.insert(indices, i)
  end
  
  table.sort(indices, function(a, b)
    local pa, pb = edit_positions[a], edit_positions[b]
    if pa.line ~= pb.line then
      return pa.line > pb.line
    end
    return pa.col_start > pb.col_start
  end)

  for _, i in ipairs(indices) do
    local pos = edit_positions[i]
    
    debug(string.format("Syncing to pos %d: replacing [%d,%d] with '%s'",
      i, pos.col_start, pos.col_end, new_text))
    
    local ok = pcall(function()
      vim.api.nvim_buf_set_text(
        bufnr,
        pos.line - 1,
        pos.col_start,
        pos.line - 1,
        pos.col_end,
        { new_text }
      )
    end)
    
    if ok then
      pos.col_end = pos.col_start + #new_text
      debug("Sync succeeded, new col_end=" .. pos.col_end)
    end
  end

  -- Update primary col_end
  primary.col_end = primary.col_start + #new_text

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

  -- Delete at each position
  for _, cursor in ipairs(sorted_cursors) do
    vim.api.nvim_buf_set_text(bufnr, cursor.line - 1, cursor.col_start, cursor.line - 1, cursor.col_end, { "" })
  end

  ui.notify(string.format("Deleted %d occurrences", #cursors), vim.log.levels.INFO)
end

---Perform a change operation - same as start_editing (keeps words visible)
function M.change_word()
  M.start_editing_mode()
end

return M
