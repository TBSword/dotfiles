return {
    "rmagatti/auto-session",
    cmd = { "SessionSave", "SessionRestore", "SessionDelete", "SessionSearch" },
    keys = {
        { "<leader>ws", "<Cmd>SessionSave<CR>", desc = "Save Session" },
        { "<leader>wr", "<Cmd>SessionRestore<CR>", desc = "Restore Session" },
    },
    opts = {
        suppressed_dirs = { "~/", "~/Downloads", "/", "/tmp" },
        auto_save = true,
        auto_restore = true,
        auto_create = true,
    },
    config = function(_, opts)
        require("auto-session").setup(opts)
    end,
}
