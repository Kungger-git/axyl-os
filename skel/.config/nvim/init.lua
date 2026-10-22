-- ~/.config/nvim/init.lua
require("lazy-bootstrap")

vim.cmd.colorscheme("opencode")

require("nvim-tree").setup({})
vim.keymap.set("n", "<C-n>", ":NvimTreeToggle<CR>")

local has_lspconfig, lspconfig = pcall(require, "lspconfig")
if has_lspconfig then
  if vim.fn.executable("pyright") == 1 then
    lspconfig.pyright.setup({})
  end
  if vim.fn.executable("pylsp") == 1 then
    lspconfig.pylsp.setup({})
  end
  if vim.fn.executable("vue-language-server") == 1 then
    lspconfig.volar.setup({
      filetypes = { 'typescript', 'javascript', 'javascriptreact', 'typescriptreact', 'vue', 'json' }
    })
  end
end

require("nvim-treesitter.configs").setup {
  -- Parsers are vendored in the ISO; do not try to download them at startup.
  ensure_installed = {},
  highlight = { enable = true }
}

vim.opt.number = true        -- Show absolute line numbers
vim.opt.relativenumber = true -- Optional: show relative line numbers

local cmp = require("cmp")
local luasnip = require("luasnip")

cmp.setup({
  snippet = {
    expand = function(args)
      luasnip.lsp_expand(args.body)
    end,
  },
  mapping = cmp.mapping.preset.insert({
    ["<Tab>"] = cmp.mapping.confirm({ select = true }),
    ["<C-Space>"] = cmp.mapping.complete(),
  }),
  sources = cmp.config.sources({
    { name = "nvim_lsp" },
    { name = "luasnip" },
  }, {
    { name = "buffer" },
  }),
})
