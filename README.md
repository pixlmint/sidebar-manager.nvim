# vim-sidebar-manager

A sidebar manager for Neovim to mimic an IDE-like UI layout.

**Note:** This plugin requires Neovim 0.11+ and is written in Lua using modern Neovim APIs.

## TL;DR

![Screencast](https://github.com/brglng/images/raw/master/vim-sidebar-manager/screencast.webp)

## Motivation

We have a lot of plugins who open windows at your editor's side. I would call
them "sidebars". Unfortunately, those plugins do no cooperate with each other.
For example, if you have NERDTree and Tagbar installed, and configured to open
at the same side, they can open simultaneously, and you have to control each
of them individually. I think a better approach would be to "switch" them.
That is, when you switch to NERDTree, Tagbar is closed automatically, and when
you switch to Tagbar, NERDTree is closed automatically. As a result, it gives
you a feeling that there is always a bar at a side, where there are several
pages that can be switched back and forth. That's pretty much like a typical
UI layout of an IDE.  What's more, I want to use the same key for switching
and toggling. I wrote a lot of code to implement this behavior in the past
years, and finally noticed that an abstraction layer can be made, and that's
this plugin.

## Example

Here's an example of configuration for NERDTree, Tagbar and Undotree at the
left side.

```lua
-- Configure the underlying plugins
vim.g.NERDTreeWinPos = 'left'
vim.g.NERDTreeWinSize = 40
vim.g.NERDTreeQuitOnOpen = 0

vim.g.tagbar_left = 1
vim.g.tagbar_width = 40
vim.g.tagbar_autoclose = 0
vim.g.tagbar_autofocus = 1

vim.g.undotree_SetFocusWhenToggle = 1
vim.g.undotree_SplitWidth = 40

-- Setup vim-sidebar-manager
require('sidebar').setup({
  sidebars = {
    nerdtree = {
      position = 'left',
      filter = function(winid)
        return vim.api.nvim_get_option_value('filetype', { win = winid }) == 'nerdtree'
      end,
      open = 'NERDTree',
      close = 'NERDTreeClose',
      width = 40,
    },
    tagbar = {
      position = 'left',
      filter = function(winid)
        local bufnr = vim.api.nvim_win_get_buf(winid)
        local bufname = vim.api.nvim_buf_get_name(bufnr)
        return bufname:match('__Tagbar__') ~= nil
      end,
      open = 'TagbarOpen',
      close = 'TagbarClose',
    },
    undotree = {
      position = 'left',
      filter = function(winid)
        return vim.api.nvim_get_option_value('filetype', { win = winid }) == 'undotree'
      end,
      open = 'UndotreeShow',
      close = 'UndotreeHide',
    },
  },
})

-- Key mappings
vim.keymap.set('n', '<M-1>', function()
  require('sidebar').toggle('nerdtree')
end, { silent = true })
vim.keymap.set('n', '<M-2>', function()
  require('sidebar').toggle('tagbar')
end, { silent = true })
vim.keymap.set('n', '<M-3>', function()
  require('sidebar').toggle('undotree')
end, { silent = true })
```

### Configuration Options

The `setup()` function accepts the following options:

- `sidebars`: Dictionary of sidebar configurations (key = sidebar name, value = config table)
  - Alternatively, can be an array where each item has a `name` field
- `left_width`: Default width for left sidebars (default: 40)
- `right_width`: Default width for right sidebars (default: 40)
- `top_height`: Default height for top sidebars (default: 0.4)
- `bottom_height`: Default height for bottom sidebars (default: 0.4)
- `move`: Whether to move sidebars to their position (default: true)
- `opts`: Default window options for all sidebars
- `close_tab_on_closing_last_buffer`: Auto-close tab when only sidebars remain (default: false)

### Sidebar Configuration

Each sidebar configuration requires:

- `position`: 'left', 'right', 'top', or 'bottom'
- `filter`: Lua function taking window ID, returns boolean
- `open`: Command string or Lua function to open the sidebar

Optional fields:

- `close`: Command string or Lua function (default: `nvim_win_close`)
- `width`/`height`: Override default dimensions (number or float <1 for percentage)
- `move`: Override global `move` setting
- `opts`: Window-local options (extends global `opts`)
- `dont_close`: String pattern or list of patterns - don't close matching sidebars when opening this one
- `get_win`: Custom function to find window ID (alternative to `filter`)

### Notes

- `vim-sidebar-manager` moves the configured windows to the specified side
  and adjusts their sizes correspondingly. However sometimes it may not work
  properly. In that case, you may need to adjust the settings of the underlying plugins.

For more examples, please refer to the [Wiki page](https://github.com/brglng/vim-sidebar-manager/wiki/Examples)

<!-- vim: ts=8 sts=4 sw=4 et cc=79
-->
