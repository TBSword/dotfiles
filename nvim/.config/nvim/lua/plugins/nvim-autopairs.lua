return {
    "windwp/nvim-autopairs",
    event = "InsertEnter",
    opts = {},
    config = function (_, opts)
        local npairs = require("nvim-autopairs")
        npairs.setup(opts)
        for _, key in ipairs({ "'", "`" }) do
            for _, rule in ipairs(npairs.get_rules(key)) do
                if rule.filetypes == nil then
                    rule.not_filetypes = vim.list_extend(rule.not_filetypes or {}, { "ocaml" })
                end
            end
        end
        npairs.force_attach()
    end,
}
