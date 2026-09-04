return {
    "nvim-treesitter/nvim-treesitter",
    main = "nvim-treesitter.configs",
    branch = "master", -- 详见本系列的附录
    event = "VeryLazy",
    opts = {
        ensure_installed = { "lua", "markdown", "markdown_inline", "ocaml", "ocaml_interface"},
        highlight = { enable = true }
    },
}

