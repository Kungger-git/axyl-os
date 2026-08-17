-- Core options
vim.opt.number         = true
vim.opt.relativenumber = true
vim.opt.tabstop        = 2
vim.opt.shiftwidth     = 2
vim.opt.expandtab      = true
vim.opt.smartindent    = true
vim.opt.wrap           = false
vim.opt.termguicolors  = true
vim.opt.cursorline     = true
vim.opt.scrolloff      = 8
vim.opt.signcolumn     = "yes"
vim.opt.clipboard      = "unnamedplus"
vim.opt.updatetime     = 100
vim.opt.splitright     = true
vim.opt.splitbelow     = true
vim.opt.ignorecase     = true
vim.opt.smartcase      = true
vim.opt.hlsearch       = true
vim.opt.incsearch      = true
vim.opt.undofile       = true

vim.g.mapleader      = " "
vim.g.maplocalleader = " "

local map = vim.keymap.set
map("n", "<leader>w", "<cmd>write<cr>",    { desc = "Save" })
map("n", "<leader>q", "<cmd>quit<cr>",     { desc = "Quit" })
map("n", "<Esc>",     "<cmd>nohlsearch<cr>")
map("n", "<leader>e", "<cmd>Explore<cr>",  { desc = "File explorer" })
map("n", "<C-h>",     "<C-w>h")
map("n", "<C-j>",     "<C-w>j")
map("n", "<C-k>",     "<C-w>k")
map("n", "<C-l>",     "<C-w>l")
map("n", "<leader>/", "gcc", { remap = true, desc = "Toggle comment" })
map("v", "<leader>/", "gc",  { remap = true, desc = "Toggle comment" })

-- Axyl / Claude color scheme
local c = {
    bg     = "#1a1a2e",
    bg_alt = "#16213e",
    fg     = "#e6e1d8",
    muted  = "#6e7290",
    accent = "#d97757",
    red    = "#ff5555",
    green  = "#50fa7b",
    yellow = "#f1fa8c",
    blue   = "#8be9fd",
    purple = "#bd93f9",
    cyan   = "#8be9fd",
}

local function hl(group, opts) vim.api.nvim_set_hl(0, group, opts) end

hl("Normal",           { fg = c.fg,     bg = c.bg })
hl("NormalFloat",      { fg = c.fg,     bg = c.bg_alt })
hl("NormalNC",         { fg = c.fg,     bg = c.bg })
hl("CursorLine",       {                bg = c.bg_alt })
hl("CursorLineNr",     { fg = c.accent, bold = true })
hl("LineNr",           { fg = c.muted })
hl("Comment",          { fg = c.muted,  italic = true })
hl("Keyword",          { fg = c.accent, bold = true })
hl("Statement",        { fg = c.accent })
hl("Conditional",      { fg = c.accent })
hl("Repeat",           { fg = c.accent })
hl("Function",         { fg = c.blue })
hl("String",           { fg = c.green })
hl("Number",           { fg = c.purple })
hl("Float",            { fg = c.purple })
hl("Boolean",          { fg = c.purple })
hl("Type",             { fg = c.yellow })
hl("Typedef",          { fg = c.yellow })
hl("StorageClass",     { fg = c.yellow })
hl("Identifier",       { fg = c.fg })
hl("Operator",         { fg = c.fg })
hl("Delimiter",        { fg = c.muted })
hl("Special",          { fg = c.cyan })
hl("PreProc",          { fg = c.purple })
hl("Error",            { fg = c.red })
hl("ErrorMsg",         { fg = c.red })
hl("WarningMsg",       { fg = c.yellow })
hl("Visual",           {                bg = c.bg_alt })
hl("Search",           { fg = c.bg,     bg = c.accent })
hl("IncSearch",        { fg = c.bg,     bg = c.accent })
hl("MatchParen",       { fg = c.accent, bold = true })
hl("Pmenu",            { fg = c.fg,     bg = c.bg_alt })
hl("PmenuSel",         { fg = c.bg,     bg = c.accent })
hl("PmenuSbar",        {                bg = c.bg_alt })
hl("PmenuThumb",       {                bg = c.accent })
hl("StatusLine",       { fg = c.fg,     bg = c.bg_alt })
hl("StatusLineNC",     { fg = c.muted,  bg = c.bg })
hl("WinSeparator",     { fg = c.muted })
hl("TabLine",          { fg = c.muted,  bg = c.bg_alt })
hl("TabLineSel",       { fg = c.bg,     bg = c.accent })
hl("TabLineFill",      {                bg = c.bg })
hl("SignColumn",       {                bg = c.bg })
hl("FoldColumn",       { fg = c.muted,  bg = c.bg })
hl("Folded",           { fg = c.muted,  bg = c.bg_alt })
hl("Directory",        { fg = c.blue })
hl("Title",            { fg = c.accent, bold = true })
hl("DiagnosticError",  { fg = c.red })
hl("DiagnosticWarn",   { fg = c.yellow })
hl("DiagnosticInfo",   { fg = c.blue })
hl("DiagnosticHint",   { fg = c.cyan })
