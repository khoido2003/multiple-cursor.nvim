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

  M.state.current_idx = M.state.current_idx + 1
  return true
end

---Remove the last added cursor
---@return boolean success
function M.remove_last()
  if #M.state.cursors == 0 then
    return false
  end

  table.remove(M.state.cursors)
  return true
end

---Select all remaining matches
function M.select_all()
  while M.state.current_idx <= #M.state.matches do
    M.add_cursor()
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
---@return number current_idx
function M.get_counts()
  return #M.state.matches, #M.state.cursors, M.state.current_idx
end

return M
