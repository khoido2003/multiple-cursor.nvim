local config = require("multiple-cursor.config")
local state = require("multiple-cursor.state")

local M = {}

-- Overlay window state
local overlay_state = {
  win = nil,
  buf = nil,
}

---Setup highlight groups
function M.setup_highlights()
  local opts = config.get()

  local defs = opts.highlight_definitions or {}

  -- Selected cursors
  if defs.cursor then
    vim.api.nvim_set_hl(0, opts.highlights.cursor, defs.cursor)
  end

  -- Unselected matches
  if defs.match then
    vim.api.nvim_set_hl(0, opts.highlights.match, defs.match)
  end

  -- Current match being reviewed
  if defs.current then
    vim.api.nvim_set_hl(0, opts.highlights.current, defs.current)
  end

  -- Skipped matches
  if defs.skipped then
    vim.api.nvim_set_hl(0, opts.highlights.skipped or "MultipleCursorSkipped", defs.skipped)
  end

  -- Overlay highlight
  if defs.overlay then
    vim.api.nvim_set_hl(0, "MultipleCursorOverlay", defs.overlay)
  end
end

---Calculate overlay window position based on config
---@param width number Width of the overlay content
---@return number row, number col
local function calculate_overlay_position(width)
  local opts = config.get()
  local position = opts.overlay.position or "top-right"
  local padding = opts.overlay.padding or {}
  local pad_top = padding.top or 1
  local pad_right = padding.right or 1
  local pad_bottom = padding.bottom or 1
  local pad_left = padding.left or 1

  local editor_width = vim.o.columns
  local editor_height = vim.o.lines - vim.o.cmdheight - 1 -- Account for cmdline

  local row, col

  if position == "top-left" then
    row = pad_top
    col = pad_left
  elseif position == "top-right" then
    row = pad_top
    col = editor_width - width - pad_right
  elseif position == "bottom-left" then
    row = editor_height - 1 - pad_bottom
    col = pad_left
  elseif position == "bottom-right" then
    row = editor_height - 1 - pad_bottom
    col = editor_width - width - pad_right
  else
    -- Default to top-right
    row = pad_top
    col = editor_width - width - pad_right
  end

  -- Clamp values to prevent negative positions
  row = math.max(0, row)
  col = math.max(0, col)

  return row, col
end

---Create the overlay window
function M.create_overlay()
  local opts = config.get()

  -- Check if overlay is enabled
  if not opts.overlay or not opts.overlay.enabled then
    return
  end

  -- Close existing overlay if any
  M.close_overlay()

  -- Create buffer for overlay
  overlay_state.buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = overlay_state.buf })

  -- Initial content
  local content = " [0/0] selected "
  local width = #content

  local row, col = calculate_overlay_position(width)

  -- Create floating window
  overlay_state.win = vim.api.nvim_open_win(overlay_state.buf, false, {
    relative = "editor",
    row = row,
    col = col,
    width = width,
    height = 1,
    style = "minimal",
    border = "rounded",
    focusable = false,
    zindex = 50,
  })

  -- Apply highlight to the window
  vim.api.nvim_set_option_value(
    "winhl",
    "Normal:MultipleCursorOverlay,FloatBorder:MultipleCursorOverlay",
    { win = overlay_state.win }
  )
end

---Update the overlay content
---@param selected number Number of selected cursors
---@param total number Total number of matches
function M.update_overlay(selected, total)
  local opts = config.get()

  -- Check if overlay is enabled
  if not opts.overlay or not opts.overlay.enabled then
    return
  end

  -- Check if overlay window exists and is valid
  if not overlay_state.win or not vim.api.nvim_win_is_valid(overlay_state.win) then
    M.create_overlay()
  end

  if not overlay_state.buf or not vim.api.nvim_buf_is_valid(overlay_state.buf) then
    return
  end

  -- Update content
  local content = string.format(" [%d/%d] selected ", selected, total)
  vim.api.nvim_buf_set_lines(overlay_state.buf, 0, -1, false, { content })

  -- Update window size and position
  local width = #content
  local row, col = calculate_overlay_position(width)

  if overlay_state.win and vim.api.nvim_win_is_valid(overlay_state.win) then
    vim.api.nvim_win_set_config(overlay_state.win, {
      relative = "editor",
      row = row,
      col = col,
      width = width,
      height = 1,
    })
  end
end

---Close the overlay window
function M.close_overlay()
  if overlay_state.win and vim.api.nvim_win_is_valid(overlay_state.win) then
    vim.api.nvim_win_close(overlay_state.win, true)
  end
  overlay_state.win = nil
  overlay_state.buf = nil
end

-- Force highlights re-application on colorscheme change
vim.api.nvim_create_autocmd("ColorScheme", {
  group = vim.api.nvim_create_augroup("MultipleCursorHighlights", { clear = true }),
  pattern = "*",
  callback = function()
    M.setup_highlights()
  end,
})

-- Update overlay position when window is resized
vim.api.nvim_create_autocmd("VimResized", {
  group = vim.api.nvim_create_augroup("MultipleCursorResize", { clear = true }),
  pattern = "*",
  callback = function()
    -- Only update if overlay is active
    if overlay_state.win and vim.api.nvim_win_is_valid(overlay_state.win) then
      local total, selected, _ = state.get_counts()
      M.update_overlay(selected, total)
    end
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
      vim.api.nvim_buf_set_extmark(bufnr, ns, pos.line - 1, pos.col_start, {
        end_col = pos.col_end,
        hl_group = opts.highlights.cursor,
      })
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

  -- Close overlay window
  M.close_overlay()
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
      hl_group = opts.highlights.skipped or "MultipleCursorSkipped"
    else
      -- This is an unselected match
      hl_group = opts.highlights.match
    end

    vim.api.nvim_buf_set_extmark(bufnr, ns, match.line - 1, match.col_start, {
      end_col = match.col_end,
      hl_group = hl_group,
    })
  end

  -- Add virtual text showing count
  local total, selected, skipped_count = state.get_counts()
  local status_text = string.format(" [%d/%d] selected", selected, total)

  -- Show status in virtual text at the end of current line
  local cursor_pos = vim.api.nvim_win_get_cursor(0)
  vim.api.nvim_buf_set_extmark(bufnr, ns, cursor_pos[1] - 1, 0, {
    virt_text = { { status_text, "Comment" } },
    virt_text_pos = "eol",
  })

  -- Update overlay window
  M.update_overlay(selected, total)
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
