-- lazy-bootstrap.lua
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"

-- The ISO ships a vendored plugin tree, but keep a bootstrap fallback for
-- systems where ~/.local/share/nvim was not populated.
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system({
    "git", "clone", "--filter=blob:none", "--branch=stable",
    "https://github.com/folke/lazy.nvim.git", lazypath,
  })
end

vim.opt.rtp:prepend(lazypath)

require("lazy").setup({
  { "nvim-lua/plenary.nvim" },
  { "nvim-tree/nvim-tree.lua", dependencies = { "nvim-tree/nvim-web-devicons" } },
  { "nvim-treesitter/nvim-treesitter", build = ":TSUpdate" },
  { "neovim/nvim-lspconfig" },
  { "hrsh7th/nvim-cmp" },
  { "hrsh7th/cmp-nvim-lsp" },
  { "L3MON4D3/LuaSnip" },
  { "onsails/lspkind.nvim" },
}, {
  install = { missing = false },
  checker = { enabled = false },
  change_detection = { enabled = false },
})
