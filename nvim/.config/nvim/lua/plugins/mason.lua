return {
    "mason-org/mason.nvim",
    event = "VeryLazy",
    dependencies = {
        "neovim/nvim-lspconfig",
        "mason-org/mason-lspconfig.nvim",
    },
    opts = {},
    config = function (_, opts)
        require("mason").setup(opts)
        local registry = require "mason-registry"

        local servers = {
            "lua-language-server",
            "typescript-language-server",
            "pyright",
            "jdtls",
        }

        for _, server in ipairs(servers) do
            local ok, pkg = pcall(registry.get_package, server)
            if ok and not pkg:is_installed() then
                pkg:install()
            end
        end

        vim.lsp.config("lua_ls", {
            settings = {
                Lua = {
                    runtime = { version = "LuaJIT" },
                    workspace = {
                        checkThirdParty = false,
                        library = { vim.env.VIMRUNTIME },
                    },
                },
            },
        })

        vim.lsp.enable({
            "lua_ls",
            "ts_ls",
            "pyright",
            "jdtls",
            "rust_analyzer",
            "clangd",
        })
    end,
}

