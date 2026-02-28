-- Display line number
vim.opt.relativenumber = true

-- Highlight current line
vim.opt.cursorline = true

-- Recommended maximum char count for a line
-- vim.opt.colorcolumn = "80"

-- Turn tabs into spaces
vim.opt.expandtab = true

-- How long a tab looks
vim.opt.tabstop = 4
-- Last line requires a workaround
vim.opt.shiftwidth = 0

-- Refresh when the file is modified
vim.opt.autoread = true

-- Custom hotkey setting
vim.g.mapleader = " "

-- Disable native mode display since lualine is installed now
vim.opt.showmode = false

