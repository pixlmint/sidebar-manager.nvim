-- vim-sidebar-manager: Neovim sidebar manager plugin
-- This file marks the plugin as loaded
-- Users must call require('sidebar').setup() in their init.lua

if vim.g.sidebar_loaded then
  return
end
vim.g.sidebar_loaded = true
