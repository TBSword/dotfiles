-- ocp-indent (OCaml) indentation plugin
vim.opt.rtp:append('/home/explosivitea/.opam/cs3110-2026sp/share/ocp-indent/vim')

-- Sync with system clipboard
vim.opt.clipboard = 'unnamedplus'

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

-- Persistent undo history
vim.opt.undofile = true

-- Custom hotkey setting
vim.g.mapleader = " "

-- Disable native mode display since lualine is installed now
vim.opt.showmode = false

-- 初始化全局变量（可选，autocmd 会覆盖它）
vim.g.fcitx5state = 1

-- Ctrl+S 保存
vim.keymap.set({ 'i', 'n', 'v' }, '<C-s>', '<Cmd>w<CR>')

-- 离开插入模式时：记录当前输入法状态，然后关闭输入法
vim.api.nvim_create_autocmd('InsertLeave', {
    pattern = '*',
    callback = function()
        -- 获取 fcitx5 状态（输出类似 "2\n" 或 "0\n"）
        local output = vim.fn.system('fcitx5-remote')
        local state = tonumber(output:sub(1, 1)) or 0
        vim.g.fcitx5state = state
        -- 关闭输入法（静默执行，忽略输出）
        vim.fn.system('fcitx5-remote -c')
    end,
})

vim.api.nvim_create_autocmd('LspAttach', {
    group = vim.api.nvim_create_augroup('my.lsp', {}),
    callback = function(ev)
        local map = function(mode, lhs, rhs, desc)
            vim.keymap.set(mode, lhs, rhs, { buffer = ev.buf, desc = desc })
        end
        map('n', 'gd',        vim.lsp.buf.definition,    '[G]oto [D]efinition')
        map('n', 'gr',        vim.lsp.buf.references,     '[G]oto [R]eferences')
        map('n', 'K',         vim.lsp.buf.hover,          'Hover Documentation')
        map('n', '<F2>',      vim.lsp.buf.rename,         '[R]e[n]ame')
        map('n', '<leader>ca', vim.lsp.buf.code_action,   '[C]ode [A]ction')
    end,
})
