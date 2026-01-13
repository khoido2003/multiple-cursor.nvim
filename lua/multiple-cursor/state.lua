---@class MultipleCursor.CursorPosition
---@field line number 1-indexed line number
---@field col_start number 0-indexed start column
---@field col_end number 0-indexed end column (exclusive)
---@field extmark_id? number Extmark ID for this position

---@class MultipleCursor.State
---@field active boolean Whether multi-cursor mode is active
---@field word string The word being matched
---@field bufnr number Buffer number
---@field cursors MultipleCursor.CursorPosition[] Selected cursor positions
---@field matches MultipleCursor.CursorPosition[] All found matches
---@field skipped MultipleCursor.CursorPosition[] Skipped matches (for re-selection)
---@field current_idx number Current match index (1-indexed)
---@field namespace number Namespace for extmarks
---@field original_pos number[] Original cursor position [line, col]

local M = {}

---@type MultipleCursor.State
M.state = {
  active = false,
  word = "",
  bufnr = 0,
  cursors = {},
  matches = {},
  skipped = {},
  current_idx = 0,
  namespace = 0,
  original_pos = {},
}

---Initialize the state namespace
function M.init()
  if M.state.namespace == 0 then
    M.state.namespace = vim.api.nvim_create_namespace("multiple-cursor")
  end
end

---Reset state to initial values
function M.reset()
  M.state.active = false
  M.state.word = ""
  M.state.bufnr = 0
  M.state.cursors = {}
  M.state.matches = {}
  M.state.skipped = {}
  M.state.current_idx = 0
  M.state.original_pos = {}
end

---Check if multi-cursor mode is active
---@return boolean
function M.is_active()
  return M.state.active
end

---Get the namespace
---@return number
function M.get_namespace()
  return M.state.namespace
end

---Start multi-cursor mode
---@param word string
---@param bufnr number
---@param matches MultipleCursor.CursorPosition[]
function M.start(word, bufnr, matches)
  M.state.active = true
  M.state.word = word
  M.state.bufnr = bufnr
  M.state.matches = matches
  M.state.cursors = {}
  M.state.skipped = {}
  M.state.current_idx = 1
  M.state.original_pos = vim.api.nvim_win_get_cursor(0)
end

---Add a cursor at the current match
---@return boolean success
function M.add_cursor()
  if M.state.current_idx > #M.state.matches then
    return false
  end

  local match = M.state.matches[M.state.current_idx]
  table.insert(M.state.cursors, vim.deepcopy(match))
  M.state.current_idx = M.state.current_idx + 1
  return true
end

---Skip the current match
---@return boolean success
function M.skip_current()
  if M.state.current_idx > #M.state.matches then
    return false
  end

  -- Store the skipped match for potential re-selection
  local skipped_match = M.state.matches[M.state.current_idx]
  table.insert(M.state.skipped, vim.deepcopy(skipped_match))

  M.state.current_idx = M.state.current_idx + 1
  return true
end

---Re-select the last skipped match
---@return boolean success
function M.reselect_last()
  if #M.state.skipped == 0 then
    return false
  end

  -- Get the last skipped match
  local last_skipped = table.remove(M.state.skipped)

  -- Add it to cursors
  table.insert(M.state.cursors, last_skipped)

  return true
end

---Get all skipped matches
---@return MultipleCursor.CursorPosition[]
function M.get_skipped()
  return M.state.skipped
end

---Remove the last added cursor (does NOT add to skipped - just removes)
---@return boolean success
function M.remove_last()
  if #M.state.cursors == 0 then
    return false
  end

  table.remove(M.state.cursors)
  return true
end

---Remove the last added cursor AND add it to skipped list
---@return boolean success
function M.remove_last_to_skipped()
  if #M.state.cursors == 0 then
    return false
  end

  local removed = table.remove(M.state.cursors)
  table.insert(M.state.skipped, removed)
  return true
end

---Find match at given cursor position
---@param line number 1-indexed line
---@param col number 0-indexed column
---@return MultipleCursor.CursorPosition?, number? match and its index
function M.get_match_at_position(line, col)
  for i, match in ipairs(M.state.matches) do
    if match.line == line and col >= match.col_start and col < match.col_end then
      return match, i
    end
  end
  return nil, nil
end

---Check if position is already in cursors (selected)
---@param line number
---@param col_start number
---@return boolean, number? is_selected and index in cursors
function M.is_position_selected(line, col_start)
  for i, cursor in ipairs(M.state.cursors) do
    if cursor.line == line and cursor.col_start == col_start then
      return true, i
    end
  end
  return false, nil
end

---Check if position is in skipped list
---@param line number
---@param col_start number
---@return boolean, number? is_skipped and index in skipped
function M.is_position_skipped(line, col_start)
  for i, skip in ipairs(M.state.skipped) do
    if skip.line == line and skip.col_start == col_start then
      return true, i
    end
  end
  return false, nil
end

---Add cursor at specific position (if it's a valid match and not already selected)
---@param line number
---@param col number
---@return boolean success
function M.add_cursor_at_position(line, col)
  local match, _ = M.get_match_at_position(line, col)
  if not match then
    return false
  end

  if M.is_position_selected(match.line, match.col_start) then
    return false
  end

  local is_skipped, skip_idx = M.is_position_skipped(match.line, match.col_start)
  if is_skipped and skip_idx then
    table.remove(M.state.skipped, skip_idx)
  end

  table.insert(M.state.cursors, vim.deepcopy(match))
  return true
end

---Skip/remove cursor at specific position
---@param line number
---@param col number
---@return boolean success, string action ("skipped" or "removed" or nil)
function M.skip_at_position(line, col)
  local match, _ = M.get_match_at_position(line, col)
  if not match then
    return false, nil
  end

  local is_selected, cursor_idx = M.is_position_selected(match.line, match.col_start)
  if is_selected and cursor_idx then
    local removed = table.remove(M.state.cursors, cursor_idx)
    table.insert(M.state.skipped, removed)
    return true, "removed"
  end

  if not M.is_position_skipped(match.line, match.col_start) then
    table.insert(M.state.skipped, vim.deepcopy(match))
    return true, "skipped"
  end

  return false, nil
end

---Select all remaining matches
function M.select_all()
  for _, match in ipairs(M.state.matches) do
    if
      not M.is_position_selected(match.line, match.col_start)
      and not M.is_position_skipped(match.line, match.col_start)
    then
      table.insert(M.state.cursors, vim.deepcopy(match))
    end
  end
end

---Get current match
---@return MultipleCursor.CursorPosition?
function M.get_current_match()
  if M.state.current_idx <= #M.state.matches then
    return M.state.matches[M.state.current_idx]
  end
  return nil
end

---Get all selected cursors
---@return MultipleCursor.CursorPosition[]
function M.get_cursors()
  return M.state.cursors
end

---Get all matches
---@return MultipleCursor.CursorPosition[]
function M.get_matches()
  return M.state.matches
end

---Get the word being matched
---@return string
function M.get_word()
  return M.state.word
end

---Get buffer number
---@return number
function M.get_bufnr()
  return M.state.bufnr
end

---Check if all matches have been processed
---@return boolean
function M.all_processed()
  return M.state.current_idx > #M.state.matches
end

---Get match and cursor counts
---@return number total_matches
---@return number selected_cursors
---@return number skipped_count
function M.get_counts()
  return #M.state.matches, #M.state.cursors, #M.state.skipped
end

---Get match at specific index
---@param idx number
---@return MultipleCursor.CursorPosition?
function M.get_match_at(idx)
  if idx >= 1 and idx <= #M.state.matches then
    return M.state.matches[idx]
  end
  return nil
end

---Get total number of matches
---@return number
function M.get_match_count()
  return #M.state.matches
end

---Find the next unselected and unskipped match after the given position
---@param line number current line (1-indexed)
---@param col number current column (0-indexed)
---@return MultipleCursor.CursorPosition? next unselected match
function M.get_next_unselected_match(line, col)
  local matches = M.state.matches
  if #matches == 0 then
    return nil
  end

  -- Find matches after current position, then wrap around
  local candidates = {}
  local before_current = {}

  for _, match in ipairs(matches) do
    -- Skip if already selected or skipped
    if
      not M.is_position_selected(match.line, match.col_start)
      and not M.is_position_skipped(match.line, match.col_start)
    then
      if match.line > line or (match.line == line and match.col_start > col) then
        table.insert(candidates, match)
      else
        table.insert(before_current, match)
      end
    end
  end

  -- Helper to sort matches by position
  local function sort_matches(a, b)
    if a.line ~= b.line then
      return a.line < b.line
    end
    return a.col_start < b.col_start
  end

  -- Return first candidate after current, or first from before (wrap around)
  if #candidates > 0 then
    table.sort(candidates, sort_matches)
    return candidates[1]
  elseif #before_current > 0 then
    table.sort(before_current, sort_matches)
    return before_current[1]
  end

  return nil
end

return M
