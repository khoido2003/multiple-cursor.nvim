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

-- Helper to create a unique numeric key from line and col_start
-- Using multiplication to create a unique key (supports up to 1M columns per line)
local function make_key(line, col_start)
  return line * 1000000 + col_start
end

---@type MultipleCursor.State
M.state = {
  active = false,
  word = "",
  bufnr = 0,
  cursors = {},
  matches = {},
  skipped = {},
  -- Hash sets for O(1) lookups
  cursor_set = {},
  skipped_set = {},
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
  M.state.cursor_set = {}
  M.state.skipped_set = {}
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
  M.state.cursor_set = {}
  M.state.skipped_set = {}
  M.state.current_idx = 1
  M.state.original_pos = vim.api.nvim_win_get_cursor(0)
end

---Update matches and current word (e.g. after editing)
---@param word string
---@param matches MultipleCursor.CursorPosition[]
function M.update_matches(word, matches)
  M.state.word = word
  M.state.matches = matches
  -- Current cursors remain selected; we don't reset them
end

function M.add_cursor()
  if M.state.current_idx > #M.state.matches then
    return false
  end

  local match = M.state.matches[M.state.current_idx]
  -- Shallow copy is sufficient since CursorPosition only contains primitives
  table.insert(M.state.cursors, { line = match.line, col_start = match.col_start, col_end = match.col_end })
  -- Update hash set
  M.state.cursor_set[make_key(match.line, match.col_start)] = true
  M.state.current_idx = M.state.current_idx + 1
  return true
end

function M.skip_current()
  if M.state.current_idx > #M.state.matches then
    return false
  end

  -- Store the skipped match for potential re-selection
  local skipped_match = M.state.matches[M.state.current_idx]
  table.insert(
    M.state.skipped,
    { line = skipped_match.line, col_start = skipped_match.col_start, col_end = skipped_match.col_end }
  )
  -- Update hash set
  M.state.skipped_set[make_key(skipped_match.line, skipped_match.col_start)] = true

  M.state.current_idx = M.state.current_idx + 1
  return true
end

function M.reselect_last()
  if #M.state.skipped == 0 then
    return false
  end

  -- Get the last skipped match
  local last_skipped = table.remove(M.state.skipped)
  -- Update hash sets
  M.state.skipped_set[make_key(last_skipped.line, last_skipped.col_start)] = nil
  M.state.cursor_set[make_key(last_skipped.line, last_skipped.col_start)] = true

  -- Add it to cursors
  table.insert(M.state.cursors, last_skipped)

  return true
end

---Get all skipped matches
---@return MultipleCursor.CursorPosition[]
function M.get_skipped()
  return M.state.skipped
end

function M.remove_last()
  if #M.state.cursors == 0 then
    return false
  end

  local removed = table.remove(M.state.cursors)
  -- Update hash set
  M.state.cursor_set[make_key(removed.line, removed.col_start)] = nil
  return true
end

function M.remove_last_to_skipped()
  if #M.state.cursors == 0 then
    return false
  end

  local removed = table.remove(M.state.cursors)
  -- Update hash sets
  M.state.cursor_set[make_key(removed.line, removed.col_start)] = nil
  M.state.skipped_set[make_key(removed.line, removed.col_start)] = true
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

---Check if position is already in cursors (selected) - O(1) lookup
---@param line number
---@param col_start number
---@return boolean, number? is_selected and index in cursors (index only if needed)
function M.is_position_selected(line, col_start)
  local key = make_key(line, col_start)
  if M.state.cursor_set[key] then
    -- Only compute index if needed (for removal operations)
    for i, cursor in ipairs(M.state.cursors) do
      if cursor.line == line and cursor.col_start == col_start then
        return true, i
      end
    end
    return true, nil
  end
  return false, nil
end

---Check if position is in skipped list - O(1) lookup
---@param line number
---@param col_start number
---@return boolean, number? is_skipped and index in skipped (index only if needed)
function M.is_position_skipped(line, col_start)
  local key = make_key(line, col_start)
  if M.state.skipped_set[key] then
    -- Only compute index if needed (for removal operations)
    for i, skip in ipairs(M.state.skipped) do
      if skip.line == line and skip.col_start == col_start then
        return true, i
      end
    end
    return true, nil
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

  local key = make_key(match.line, match.col_start)
  if M.state.cursor_set[key] then
    return false
  end

  -- Remove from skipped if present
  if M.state.skipped_set[key] then
    M.state.skipped_set[key] = nil
    for i, skip in ipairs(M.state.skipped) do
      if skip.line == match.line and skip.col_start == match.col_start then
        table.remove(M.state.skipped, i)
        break
      end
    end
  end

  table.insert(M.state.cursors, { line = match.line, col_start = match.col_start, col_end = match.col_end })
  M.state.cursor_set[key] = true
  return true
end

function M.skip_at_position(line, col)
  local match, _ = M.get_match_at_position(line, col)
  if not match then
    return false, nil
  end

  local key = make_key(match.line, match.col_start)

  -- If selected, move to skipped
  if M.state.cursor_set[key] then
    M.state.cursor_set[key] = nil
    for i, cursor in ipairs(M.state.cursors) do
      if cursor.line == match.line and cursor.col_start == match.col_start then
        local removed = table.remove(M.state.cursors, i)
        table.insert(M.state.skipped, removed)
        M.state.skipped_set[key] = true
        return true, "removed"
      end
    end
  end

  -- If not skipped, add to skipped
  if not M.state.skipped_set[key] then
    table.insert(M.state.skipped, { line = match.line, col_start = match.col_start, col_end = match.col_end })
    M.state.skipped_set[key] = true
    return true, "skipped"
  end

  return false, nil
end

function M.select_all()
  for _, match in ipairs(M.state.matches) do
    local key = make_key(match.line, match.col_start)
    if not M.state.cursor_set[key] and not M.state.skipped_set[key] then
      table.insert(M.state.cursors, { line = match.line, col_start = match.col_start, col_end = match.col_end })
      M.state.cursor_set[key] = true
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
