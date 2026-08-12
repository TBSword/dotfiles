return {
    "epwalsh/obsidian.nvim",
    version = "*",
    event = "VeryLazy",
    dependencies = {
        "nvim-lua/plenary.nvim",
    },
    keys = {
        { "<leader>on",  "<cmd>ObsidianNew<cr>",         desc = "New Obsidian note" },
        { "<leader>od",  "<cmd>ObsidianDailies<cr>",      desc = "Daily note" },
        { "<leader>oo",  "<cmd>ObsidianSearch<cr>",       desc = "Search notes" },
        { "<leader>of",  "<cmd>ObsidianQuickSwitch<cr>",  desc = "Quick switch" },
        { "<leader>ob",  "<cmd>ObsidianBacklinks<cr>",    desc = "Backlinks" },
        { "<leader>ol",  "<cmd>ObsidianFollowLink<cr>",   desc = "Follow link" },
        { "<leader>ot",  "<cmd>ObsidianTags<cr>",         desc = "Search tags" },
        { "<leader>otn", "<cmd>ObsidianToday<cr>",        desc = "Today's daily note" },
        { "<leader>gp", function()
            local filename = vim.fn.expand("%:p")
            local w = math.floor(vim.o.columns * 0.8)
            local h = math.floor(vim.o.lines * 0.8)
            local buf = vim.api.nvim_create_buf(false, true)
            local win = vim.api.nvim_open_win(buf, true, {
                relative = "editor",
                width = w,
                height = h,
                col = math.floor((vim.o.columns - w) / 2),
                row = math.floor((vim.o.lines - h) / 2),
                style = "minimal",
                border = "rounded",
            })
            vim.api.nvim_buf_set_keymap(buf, "n", "q", "<cmd>close<cr>", { noremap = true, silent = true })
            vim.fn.termopen("glow -p \"" .. filename .. "\"")
            vim.cmd.startinsert()
        end, desc = "Glow preview" },
    },
    cmd = {
        "ObsidianNew",
        "ObsidianSearch",
        "ObsidianQuickSwitch",
        "ObsidianFollowLink",
        "ObsidianBacklinks",
        "ObsidianTags",
        "ObsidianToday",
        "ObsidianDailies",
    },
    opts = {
        workspaces = {
            { name = "main", path = "~/Documents" },
        },
        daily_notes = {
            folder = "daily",
            date_format = "%Y-%m-%d",
        },
        completion = {
            nvim_cmp = false,
            min_chars = 2,
        },
        picker = {
            name = "telescope.nvim",
        },
    },
}
