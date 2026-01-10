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
    default = true,
  })

  -- Unselected matches - dim yellow background
  vim.api.nvim_set_hl(0, opts.highlights.match, {
    bg = "#3e3d32",
    fg = "#e6db74",
    default = true,
  })

  -- Current match being reviewed - bright highlight
  vim.api.nvim_set_hl(0, opts.highlights.current, {
    bg = "#66d9ef",
    fg = "#272822",
    bold = true,
    default = true,
  })
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
  local current_match = state.get_current_match()

  -- Create a set of cursor positions for quick lookup
  local cursor_set = {}
  for _, cursor in ipairs(cursors) do
    local key = cursor.line .. ":" .. cursor.col_start
    cursor_set[key] = true
  end

  -- Highlight all matches
  for _, match in ipairs(matches) do
    local key = match.line .. ":" .. match.col_start
    local hl_group

    if cursor_set[key] then
      -- This is a selected cursor
      hl_group = opts.highlights.cursor
    elseif current_match and match.line == current_match.line and match.col_start == current_match.col_start then
      -- This is the current match being reviewed
      hl_group = opts.highlights.current
    else
      -- This is an unselected match
      hl_group = opts.highlights.match
    end

    vim.api.nvim_buf_add_highlight(bufnr, ns, hl_group, match.line - 1, match.col_start, match.col_end)
  end

  -- Add virtual text showing count
  local total, selected, current_idx = state.get_counts()
  local status_text
  if current_idx <= total then
    status_text = string.format(" [%d/%d] %d selected", current_idx, total, selected)
  else
    status_text = string.format(" [done] %d selected", selected)
  end

  -- Show status in virtual text at the end of current line
  local cursor_pos = vim.api.nvim_win_get_cursor(0)
  vim.api.nvim_buf_set_extmark(bufnr, ns, cursor_pos[1] - 1, 0, {
    virt_text = { { status_text, "Comment" } },
    virt_text_pos = "eol",
  })
end

---Move cursor to the current match
function M.jump_to_current()
  local current = state.get_current_match()
  if current then
    vim.api.nvim_win_set_cursor(0, { current.line, current.col_start })
  end
end

---Show a notification message
---@param msg string
---@param level? number vim.log.levels
function M.notify(msg, level)
  vim.notify(msg, level or vim.log.levels.INFO, { title = "Multiple Cursor" })
end

return M
