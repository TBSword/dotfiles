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

        vim.lsp.config("ocamllsp", {
            cmd = { "opam", "exec", "--", "ocamllsp" },
        })

        -- 让 jdtls 把 root_dir 定位到 Maven/Gradle 项目目录（pom.xml / build.gradle），
        -- 而不是 git 仓库根目录。否则在 monorepo（一个 git 仓库含多个 lab/proj 子项目）里，
        -- jdtls 会定位到 git 根、找不到项目，导致 .java 文件 "does not resolve to a
        -- ICompilationUnit"，补全和诊断全部失效。
        vim.lsp.config("jdtls", {
            root_markers = { "pom.xml", "build.gradle", "build.gradle.kts", "build.xml", ".git" },
        })

        vim.lsp.enable({
            "lua_ls",
            "ts_ls",
            "pyright",
            "jdtls",
            "rust_analyzer",
            "clangd",
            "ocamllsp",
        })
    end,
}

