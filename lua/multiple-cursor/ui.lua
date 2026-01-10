local config = require("multiple-cursor.config")
local state = require("multiple-cursor.state")

local M = {}

---Setup highlight groups
function M.setup_highlights()
  local opts = config.get()

  -- Selected cursors - green background
  vim.api.nvim_set_hl(0, opts.highlights.cursor, {
    bg = "#2d4f2d",
    fg = "#98c379",
    bold = true,
  })

  -- Unselected matches - distinct yellow background with underline
  vim.api.nvim_set_hl(0, opts.highlights.match, {
    bg = "#5e5d42",  -- Brighter dim yellow
    fg = "#e6db74",
    underline = true,
  })

  -- Current match being reviewed (deprecated usage but kept for safety)
  vim.api.nvim_set_hl(0, opts.highlights.current, {
    bg = "#66d9ef",
    fg = "#272822",
    bold = true,
  })

  -- Skipped matches - dim red/strikethrough style
  vim.api.nvim_set_hl(0, "MultipleCursorSkipped", {
    bg = "#5a3030",  -- Brighter red background
    fg = "#f92672",
    italic = true,
  })
end

-- Force highlights re-application on colorscheme change
vim.api.nvim_create_autocmd("ColorScheme", {
  pattern = "*",
  callback = function()
    M.setup_highlights()
  end,
})

---Update highlights for editing mode with specific positions
---@param positions table[] Array of {line, col_start, col_end}
function M.update_edit_highlights(positions)
  local ns = state.get_namespace()
  local bufnr = state.get_bufnr()
  local opts = config.get()

  if not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end

  -- Clear existing highlights
  vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)

  -- Highlight all edit positions with the same cursor color (green)
  for _, pos in ipairs(positions) do
    pcall(function()
      vim.api.nvim_buf_add_highlight(bufnr, ns, opts.highlights.cursor, pos.line - 1, pos.col_start, pos.col_end)
    end)
  end
end

---Clear all highlights
function M.clear_highlights()
  local ns = state.get_namespace()
  local bufnr = state.get_bufnr()

  if bufnr > 0 and vim.api.nvim_buf_is_valid(bufnr) then
    vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)
  end
end

---Update all highlights based on current state
function M.update_highlights()
  local ns = state.get_namespace()
  local bufnr = state.get_bufnr()
  local opts = config.get()

  if not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end

  -- Clear existing highlights
  vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)

  local matches = state.get_matches()
  local cursors = state.get_cursors()
  local skipped = state.get_skipped()
  local current_match = state.get_current_match()

  -- Create a set of cursor positions for quick lookup
  local cursor_set = {}
  for _, cursor in ipairs(cursors) do
    local key = cursor.line .. ":" .. cursor.col_start
    cursor_set[key] = true
  end

  -- Create a set of skipped positions for quick lookup
  local skipped_set = {}
  for _, skip in ipairs(skipped) do
    local key = skip.line .. ":" .. skip.col_start
    skipped_set[key] = true
  end

  -- Highlight all matches
  for _, match in ipairs(matches) do
    local key = match.line .. ":" .. match.col_start
    local hl_group

    if cursor_set[key] then
      -- This is a selected cursor
      hl_group = opts.highlights.cursor
    elseif skipped_set[key] then
      -- This is a skipped match
      hl_group = "MultipleCursorSkipped"
    else
      -- This is an unselected match
      hl_group = opts.highlights.match
    end

    vim.api.nvim_buf_add_highlight(bufnr, ns, hl_group, match.line - 1, match.col_start, match.col_end)
  end

  -- Add virtual text showing count
  local total, selected, skipped = state.get_counts()
  local status_text = string.format(" [%d/%d] selected", selected, total)

  -- Show status in virtual text at the end of current line
  local cursor_pos = vim.api.nvim_win_get_cursor(0)
  vim.api.nvim_buf_set_extmark(bufnr, ns, cursor_pos[1] - 1, 0, {
    virt_text = { { status_text, "Comment" } },
    virt_text_pos = "eol",
  })
end

---Move cursor to the current match (at end of word)
function M.jump_to_current()
  local current = state.get_current_match()
  if current then
    -- Jump to end of word (col_end - 1 because col_end is exclusive)
    local end_col = current.col_end > 0 and current.col_end - 1 or current.col_start
    vim.api.nvim_win_set_cursor(0, { current.line, end_col })
  end
end

---Show a notification message
---@param msg string
---@param level? number vim.log.levels
function M.notify(msg, level)
  vim.notify(msg, level or vim.log.levels.INFO, { title = "Multiple Cursor" })
end

return M
