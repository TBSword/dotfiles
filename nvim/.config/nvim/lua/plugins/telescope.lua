return {
    "nvim-telescope/telescope.nvim",
    dependencies = {
        "nvim-lua/plenary.nvim",
        {
            "nvim-telescope/telescope-fzf-native.nvim",
            build = "cmake -S. -Bbuild -DCMAKE_BUILD_TYPE=Release && "
                .. "cmake --build build --config Release && "
                .. "cmake --install build --prefix build",
        },
    },
    cmd = "Telescope",
    keys = {
        { "<leader>f", "<Cmd>Telescope buffers<CR>", desc = "Find Buffer", silent = true },
        { "<leader><C-f>", "<Cmd>Telescope find_files<CR>", desc = "Find Files", silent = true },
        { "<leader><C-s>", "<Cmd>Telescope live_grep<CR>", desc = "Live Grep", silent = true },
        { "<leader>r", "<Cmd>Telescope oldfiles<CR>", desc = "Recent Files", silent = true },
    },
    opts = {
        extensions = {
            fzf = {
                fuzzy = true,
                override_generic_sorter = true,
                override_file_sorter = true,
                case_mode = "smart_case",
            },
        },
    },
    config = function(_, opts)
        local telescope = require "telescope"
        telescope.setup(opts)
        telescope.load_extension("fzf")
    end,
}

