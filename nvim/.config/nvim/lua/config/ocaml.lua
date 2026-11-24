local opam_root = vim.fn.expand("~/.opam/cs3110-2026sp")
vim.opt.rtp:prepend(opam_root .. "/share/ocp-indent/vim")

local opam_bin = opam_root .. "/bin"
if vim.fn.isdirectory(opam_bin) == 1 and not vim.env.PATH:find(opam_bin, 1, true) then
  vim.env.PATH = opam_bin .. ":" .. vim.env.PATH
end

if vim.env.OCP_INDENT_CONFIG == nil then
  vim.env.OCP_INDENT_CONFIG = "base=4,type=4,in=0,with=0,match_clause=4,ppx_stritem_ext=4,max_indent=8"
end

vim.api.nvim_create_autocmd("FileType", {
  pattern = { "ocaml", "ocamlinterface" },
  callback = function ()
    vim.opt_local.expandtab = true
    vim.opt_local.tabstop = 4
    vim.opt_local.shiftwidth = 4
    vim.opt_local.softtabstop = 4
  end,
})
