local config = require("multiple-cursor.config")

local M = {}

---Get the word under cursor
---@return string
function M.get_word_under_cursor()
  return vim.fn.expand("<cword>")
end

---Find all matches of a word in the current buffer
---@param word string The word to search for
---@param bufnr number Buffer number
---@return MultipleCursor.CursorPosition[] matches
function M.find_matches(word, bufnr)
  local opts = config.get()
  local matches = {}

  if word == "" then
    return matches
  end

  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

  -- Build search pattern
  local pattern
  if opts.match_whole_word then
    -- Escape special pattern characters
    local escaped = vim.pesc(word)
    pattern = "%f[%w_]" .. escaped .. "%f[^%w_]"
  else
    pattern = vim.pesc(word)
  end

  for line_idx, line in ipairs(lines) do
    local search_line = opts.case_sensitive and line or line:lower()
    local search_word = opts.case_sensitive and word or word:lower()
    local search_pattern = opts.match_whole_word and ("%f[%w_]" .. vim.pesc(search_word) .. "%f[^%w_]")
      or vim.pesc(search_word)

    local start_pos = 1
    while true do
      local match_start, match_end = search_line:find(search_pattern, start_pos)
      if not match_start then
        break
      end

      table.insert(matches, {
        line = line_idx,
        col_start = match_start - 1, -- Convert to 0-indexed
        col_end = match_end, -- Already correct for exclusive end
      })

      start_pos = match_start + 1
    end
  end

  return matches
end

---Find and sort matches, putting cursor position first
---@param word string
---@param bufnr number
---@return MultipleCursor.CursorPosition[]
function M.find_matches_from_cursor(word, bufnr)
  local matches = M.find_matches(word, bufnr)

  if #matches == 0 then
    return matches
  end

  -- Get current cursor position
  local cursor = vim.api.nvim_win_get_cursor(0)
  local cur_line = cursor[1]
  local cur_col = cursor[2]

  -- Find the match at or after cursor position
  local cursor_match_idx = nil
  for i, match in ipairs(matches) do
    if match.line > cur_line or (match.line == cur_line and match.col_start >= cur_col) then
      cursor_match_idx = i
      break
    end
  end

  -- If no match found after cursor, start from beginning
  if not cursor_match_idx then
    cursor_match_idx = 1
  end

  -- Find exact match under cursor (if cursor is inside a match)
  for i, match in ipairs(matches) do
    if match.line == cur_line and cur_col >= match.col_start and cur_col < match.col_end then
      cursor_match_idx = i
      break
    end
  end

  -- Reorder matches: start from cursor_match_idx, wrap around
  local reordered = {}
  for i = cursor_match_idx, #matches do
    table.insert(reordered, matches[i])
  end
  for i = 1, cursor_match_idx - 1 do
    table.insert(reordered, matches[i])
  end

  return reordered
end

return M
