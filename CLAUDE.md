# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

vim-sidebar-manager is a Neovim plugin (requires Neovim 0.11+) written in Lua that manages "sidebar" windows (like file explorers, tag lists, undo trees) to create an IDE-like UI. The plugin allows sidebars at the same position to switch seamlessly rather than opening simultaneously, giving users a tabbed sidebar experience.

## Code Architecture

### Core Components

**lua/sidebar/init.lua** - The complete plugin implementation as a Lua module:
- `sidebars`: Table storing all registered sidebar configurations
- `position_name_map`: Maps positions ('left', 'right', 'top', 'bottom') to sidebar names
- `M.config`: Plugin configuration with defaults for widths, heights, options, etc.
- Registration system via `M.register()` called from `M.setup()` with sidebar configs

**plugin/sidebar.lua** - Plugin loader:
- Minimal file that marks the plugin as loaded via `vim.g.sidebar_loaded`
- Does not auto-initialize; users must explicitly call `require('sidebar').setup()`

### Modern Neovim APIs Used

The plugin leverages Neovim 0.11+ APIs instead of legacy `vim.fn.*` functions:

**Window Management**:
- `vim.api.nvim_get_current_win()` - Get current window ID (not `vim.fn.winnr()`)
- `vim.api.nvim_tabpage_list_wins(0)` - List all windows in tabpage (not counting with `winnr('$')`)
- `vim.api.nvim_set_current_win(winid)` - Switch to window (not `wincmd w`)
- `vim.api.nvim_win_close(winid, false)` - Close window (not `wincmd q`)
- `vim.api.nvim_win_set_width(winid, width)` - Set window width directly
- `vim.api.nvim_win_set_height(winid, height)` - Set window height directly
- `vim.api.nvim_win_get_buf(winid)` - Get buffer in window (not `vim.fn.winbufnr()`)
- `vim.api.nvim_win_is_valid(winid)` - Check if window is still valid

**Buffer Management**:
- `vim.api.nvim_list_bufs()` - List all buffers
- `vim.api.nvim_buf_get_name(bufnr)` - Get buffer name (not `vim.fn.bufname()`)
- `vim.api.nvim_buf_get_keymap(bufnr, mode)` - Get buffer keymaps
- `vim.api.nvim_buf_set_keymap(bufnr, mode, lhs, rhs, opts)` - Set buffer keymap

**Options**:
- `vim.api.nvim_set_option_value(opt, val, {win=winid})` - Set window options
- `vim.api.nvim_set_option_value(opt, val, {buf=bufnr})` - Set buffer options
- `vim.bo[bufnr].option` - Buffer options accessor
- `vim.o.option` - Global options accessor

**Plugin Infrastructure**:
- `vim.api.nvim_create_augroup(name, opts)` - Create autocommand group
- `vim.api.nvim_create_autocmd(events, opts)` - Create autocommand with callback
- `vim.api.nvim_create_user_command(name, func, opts)` - Create user command
- `vim.uv.sleep(ms)` - Async sleep (libuv, not `vim.fn.sleep()`)
- `vim.schedule(func)` - Schedule callback on event loop

### Key Functions

**Core Operations** (lua/sidebar/init.lua):
- `M.toggle(name)`: Toggle a specific sidebar, closing others at same position
- `M.switch(name)`: Switch to a sidebar (opens if closed, focuses if open)
- `M.open(name)` / `M.close(name)`: Explicit open/close operations
- `M.close_side(position)`: Close all sidebars at a given position
- `M.close_all()`: Close all registered sidebars

**Window Detection**:
- `get_win(name)`: Find window ID for a sidebar using its filter function
- `find_windows_at_position(position)`: Get all sidebar windows at a position (returns table mapping winid -> name)
- `M.is_sidebar(winid)`: Check if a window ID is a sidebar

**Window Setup**:
- `setup_win(name, winid)`: Position sidebar with wincmd (H/L/K/J), resize, apply options
- `resize_win(name, winid)`: Apply width/height using `nvim_win_set_width/height`
- `M.setup_current_sidebar_window()`: Auto-setup via BufWinEnter/FileType events

**View Management**:
- `save_view()` / `restore_view()`: Preserve cursor position across all windows during sidebar operations
- On Neovim with `splitkeep` option: No-op (Neovim handles it automatically)
- On older Neovim: Uses `vim.fn.winsaveview()`/`vim.fn.winrestview()` across all windows

**User Commands** (created in `M.setup()`):
- `:Sidebar <name>`: Primary command to open/switch to a sidebar with autocomplete
- `:SidebarOpen <name>`: Open/switch to a sidebar (alias for `:Sidebar`)
- `:SidebarSwitch <name>`: Switch to a sidebar
- `:SidebarToggle <name>`: Toggle a sidebar
- `:SidebarClose <name>`: Close a specific sidebar
- `:SidebarCloseSide <position>`: Close all sidebars at a position
- `:SidebarCloseAll`: Close all sidebars
- All commands that take a name/position include autocomplete via completion functions

### Setup Function

The `M.setup(opts)` function initializes the plugin and accepts:

**Global Configuration**:
- `sidebars`: Table of sidebar configs (dictionary or array format)
- `left_width`: Default width for left sidebars (default: 40)
- `right_width`: Default width for right sidebars (default: 40)
- `top_height`: Default height for top sidebars (default: 0.4)
- `bottom_height`: Default height for bottom sidebars (default: 0.4)
- `move`: Whether to move sidebars to position (default: true)
- `opts`: Default window options for all sidebars
- `close_tab_on_closing_last_buffer`: Auto-close tab when only sidebars remain (default: false)

### Sidebar Registration

Sidebars are registered via the `setup()` function's `sidebars` parameter. This can be either:
- **Dictionary format** (recommended): Keys are sidebar names, values are config tables
- **Array format**: Array of config tables, each with a `name` field

Each sidebar configuration requires:

**Required properties**:
- `position`: 'left', 'right', 'top', or 'bottom'
- `filter`: Lua function taking window ID, returns boolean
- `open`: Command string or Lua function to open the sidebar

**Optional properties**:
- `close`: Command string or Lua function (default: `nvim_win_close`)
- `width`/`height`: Override default dimensions (number or float <1 for percentage)
- `move`: Override `config.move` to control window repositioning (boolean)
- `opts`: Table of window-local options to apply (extends `config.opts`)
- `dont_close`: String pattern or list of patterns - don't close matching sidebars when opening this one
- `get_win`: Custom function to find window ID (alternative to filter)

### Special Features

**wait_for_close behavior**: `close()` includes `wait_for_close()` which polls for 30ms intervals (using `vim.uv.sleep()`) until windows at that position are actually closed. This handles async close operations in some plugins.

**dont_close property**: Allows certain sidebars to coexist. When opening sidebar B, if B's `dont_close` matches sidebar A's name (via Lua pattern matching), A won't be closed.

**Intrusive mode**: The plugin can work in "intrusive" mode where it automatically sets up sidebar windows via autocmds on BufWinEnter and FileType events, ensuring proper sizing/positioning even when opened by other means. Uses `vim.schedule()` to avoid issues during event handling.

## Development Workflow

This is a pure Lua plugin with no build system, tests, or package manager configuration. Development workflow:

1. Edit `lua/sidebar/init.lua` directly
2. Test changes by reloading in a running Neovim instance:
   ```lua
   :lua package.loaded['sidebar'] = nil
   :lua require('sidebar').setup()
   ```
3. Or restart Neovim after making changes

## Configuration Pattern

Users configure sidebars by calling `setup()` in their `init.lua`:

### Dictionary Format (Recommended)

```lua
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
  },
  -- Optional global settings
  left_width = 50,
  right_width = 60,
  move = true,
  opts = {
    number = false,
    signcolumn = 'no',
  },
})

vim.keymap.set('n', '<M-1>', function()
  require('sidebar').toggle('nerdtree')
end, { silent = true })
```

### Array Format (Alternative)

```lua
require('sidebar').setup({
  sidebars = {
    {
      name = 'nerdtree',
      position = 'left',
      filter = function(winid)
        return vim.api.nvim_get_option_value('filetype', { win = winid }) == 'nerdtree'
      end,
      open = 'NERDTree',
      close = 'NERDTreeClose',
      width = 40,
    },
    {
      name = 'tagbar',
      position = 'left',
      filter = function(winid)
        local bufnr = vim.api.nvim_win_get_buf(winid)
        local bufname = vim.api.nvim_buf_get_name(bufnr)
        return bufname:match('__Tagbar__') ~= nil
      end,
      open = 'TagbarOpen',
      close = 'TagbarClose',
    },
  },
})
```

## Important Implementation Details

- The plugin requires Neovim 0.11+ and uses modern Lua APIs throughout
- **Modern setup pattern**: Users must explicitly call `require('sidebar').setup()` - no auto-initialization from global variables
- The `setup()` function accepts both dictionary and array formats for sidebars configuration
- Window positioning still uses `vim.cmd('wincmd H/L/K/J')` as there's no direct API for repositioning windows to edges
- The `call_or_exec()` and `call_or_eval()` helpers allow sidebar properties to be either command strings or Lua functions
- Default sidebar options are in `M.config.opts` (winfixwidth, number, foldcolumn, signcolumn, etc.) and are applied using `nvim_set_option_value()`
- The plugin sets up a `q` mapping for closing sidebars if not already mapped, using `nvim_buf_set_keymap()`
- Window IDs (integers) are used throughout instead of window numbers (which can change)
- Uses `vim.uv.sleep()` (libuv) for async waiting instead of blocking sleep
- Uses `vim.schedule()` in autocmd callbacks to avoid event loop issues
- All user commands created with `nvim_create_user_command()` with completion functions
- Autocmds created with `nvim_create_autocmd()` using callbacks instead of command strings
- The `plugin/sidebar.lua` file is minimal and only marks the plugin as loaded; it does not perform any initialization

## Git Workflow

Standard git workflow. Recent commits show feature additions and breaking changes marked with conventional commits (feat!, fix!).
