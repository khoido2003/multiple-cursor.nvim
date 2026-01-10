-- Prevent loading twice
if vim.g.loaded_multiple_cursor then
	return
end
vim.g.loaded_multiple_cursor = true

-- Plugin will be initialized when user calls require("multiple-cursor").setup()
