return {
    "akinsho/bufferline.nvim",
    dependencies = {
        "nvim-tree/nvim-web-devicons",
    },
    opts = {},

    -- Search content vim.g.mapleader for <leader> key config
    keys = {
        { "<leader>j", ":BufferLineCyclePrev<CR>", silent = true },
        { "<leader>k", ":BufferLineCycleNext<CR>", silent = true },
        { "<leader>bd", ":bdelete<CR>", silent = true },
        { "<leader>bo", ":BufferLineCloseOthers<CR>", silent = true },
        { "<leader>p", ":BufferLinePick<CR>", silent = true },
        { "<leader>bc", ":BufferLinePickClose<CR>", silent = true },
    },
    lazy = false,
}

