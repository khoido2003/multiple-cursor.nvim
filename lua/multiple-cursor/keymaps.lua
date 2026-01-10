local config = require("multiple-cursor.config")

local M = {}

-- Store buffer-local keymap state
local active_keymaps = {}

---Set a buffer-local keymap
---@param bufnr number
---@param mode string
---@param lhs string
---@param rhs function|string
---@param desc string
local function set_keymap(bufnr, mode, lhs, rhs, desc)
  if not lhs or lhs == false then
    return
  end

  vim.keymap.set(mode, lhs, rhs, {
    buffer = bufnr,
    noremap = true,
    silent = true,
    desc = desc,
  })

  table.insert(active_keymaps, { bufnr = bufnr, mode = mode, lhs = lhs })
end

---Setup keymaps for multi-cursor mode
---@param bufnr number
---@param callbacks table Table of callback functions
function M.setup_active_keymaps(bufnr, callbacks)
  local opts = config.get()
  local keys = opts.keymaps

  -- Clear any existing keymaps first
  M.clear_keymaps()

  -- Add next match
  set_keymap(bufnr, "n", keys.start_next, callbacks.add_next, "MC: Add next match")

  -- Skip current match
  set_keymap(bufnr, "n", keys.skip, callbacks.skip, "MC: Skip current match")

  -- Navigate to next match
  set_keymap(bufnr, "n", keys.next_match, callbacks.next_match, "MC: Go to next match")

  -- Navigate to previous match
  set_keymap(bufnr, "n", keys.prev_match, callbacks.prev_match, "MC: Go to previous match")

  -- Select all remaining
  set_keymap(bufnr, "n", keys.select_all, callbacks.select_all, "MC: Select all matches")

  -- Exit multi-cursor mode
  set_keymap(bufnr, "n", keys.exit, callbacks.exit, "MC: Exit multi-cursor mode")

  -- Change word (c) - change all selected words
  set_keymap(bufnr, "n", "c", callbacks.change, "MC: Change selected words")

  -- Delete word (d) - delete all selected words
  set_keymap(bufnr, "n", "d", callbacks.delete, "MC: Delete selected words")

  -- Insert mode (i) - edit at all positions
  set_keymap(bufnr, "n", "i", callbacks.insert, "MC: Insert at all positions")
end

---Clear all active keymaps
function M.clear_keymaps()
  for _, keymap in ipairs(active_keymaps) do
    pcall(vim.keymap.del, keymap.mode, keymap.lhs, { buffer = keymap.bufnr })
  end
  active_keymaps = {}
end

---Setup global keymaps (for starting multi-cursor mode)
---@param start_callback function
function M.setup_global_keymaps(start_callback)
  local opts = config.get()
  local keys = opts.keymaps

  if keys.start_next and keys.start_next ~= false then
    vim.keymap.set("n", keys.start_next, start_callback, {
      noremap = true,
      silent = true,
      desc = "MC: Start multi-cursor on word under cursor",
    })
  end
end

return M
