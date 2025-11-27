local M = {}

-- State management
local sidebars = {}
local position_name_map = {
  left = {},
  right = {},
  top = {},
  bottom = {},
}

-- Configuration defaults
M.config = {
  left_width = 40,
  right_width = 40,
  top_height = 0.4,
  bottom_height = 0.4,
  move = true,
  lualine = false,
  opts = {
    winfixwidth = false,
    winfixheight = false,
    number = false,
    foldcolumn = '0',
    signcolumn = 'no',
    colorcolumn = '0',
    bufhidden = 'hide',
    buflisted = false,
  },
  close_tab_on_closing_last_buffer = false,
}

-- Helper functions

---Call a function or execute a command
---@param func_or_cmd function|string
local function call_or_exec(func_or_cmd)
  if type(func_or_cmd) == 'function' then
    func_or_cmd()
  else
    vim.cmd(func_or_cmd)
  end
end

---Call a function or evaluate an expression
---@param func_or_expr function|string
---@return any
local function call_or_eval(func_or_expr)
  if type(func_or_expr) == 'function' then
    return func_or_expr()
  else
    return vim.fn.eval(func_or_expr)
  end
end

---Check if a window matches a sidebar filter
---@param name string
---@param winid integer
---@return boolean
local function filter_win(name, winid)
  local sidebar = sidebars[name]
  if sidebar.filter then
    return sidebar.filter(winid)
  elseif sidebar.check_win then
    return sidebar.check_win(winid)
  end
  return false
end

---Get the window ID for a sidebar
---@param name string
---@return integer|nil Window ID or nil if not found
local function get_win(name)
  local sidebar = sidebars[name]
  if sidebar.get_win then
    return call_or_eval(sidebar.get_win)
  else
    local wins = vim.api.nvim_tabpage_list_wins(0)
    for _, winid in ipairs(wins) do
      if filter_win(name, winid) then
        return winid
      end
    end
  end
  return nil
end

---Get width for a sidebar
---@param name string
---@return integer
local function get_width(name)
  local sidebar = sidebars[name]
  local w = 0

  if sidebar.width then
    w = sidebar.width
  elseif sidebar.position == 'left' then
    w = M.config.left_width
  elseif sidebar.position == 'right' then
    w = M.config.right_width
  end

  if w < 1 then
    w = math.floor(w * vim.o.columns)
  end

  return w
end

---Get height for a sidebar
---@param name string
---@return integer
local function get_height(name)
  local sidebar = sidebars[name]
  local h = 0

  if sidebar.height then
    h = sidebar.height
  elseif sidebar.position == 'top' then
    h = M.config.top_height
  elseif sidebar.position == 'bottom' then
    h = M.config.bottom_height
  end

  if h < 1 then
    h = math.floor(h * vim.o.lines)
  end

  return h
end

---Check if a sidebar should be moved
---@param name string
---@return boolean
local function should_move(name)
  local sidebar = sidebars[name]
  if sidebar.move ~= nil then
    return sidebar.move
  end
  return M.config.move
end

---Get options for a sidebar
---@param name string
---@return table
local function get_opts(name)
  local sidebar = sidebars[name]
  local opts = vim.tbl_extend('force', {}, M.config.opts)
  if sidebar.opts then
    opts = vim.tbl_extend('force', opts, sidebar.opts)
  end
  return opts
end

---Resize a window
---@param name string
---@param winid integer
local function resize_win(name, winid)
  local sidebar = sidebars[name]
  if sidebar.position == 'left' or sidebar.position == 'right' then
    vim.api.nvim_win_set_width(winid, get_width(name))
  else
    vim.api.nvim_win_set_height(winid, get_height(name))
  end
end

---Setup window options and mappings
---@param name string
---@param winid integer
local function setup_win(name, winid)
  local sidebar = sidebars[name]

  -- Move window to position if needed
  if should_move(name) then
    local cur_win = vim.api.nvim_get_current_win()
    vim.api.nvim_set_current_win(winid)

    if sidebar.position == 'left' then
      vim.cmd('wincmd H')
    elseif sidebar.position == 'right' then
      vim.cmd('wincmd L')
    elseif sidebar.position == 'top' then
      vim.cmd('wincmd K')
    elseif sidebar.position == 'bottom' then
      vim.cmd('wincmd J')
    end

    -- Restore original window
    if vim.api.nvim_win_is_valid(cur_win) then
      vim.api.nvim_set_current_win(cur_win)
    end
  end

  -- Resize
  resize_win(name, winid)

  -- Apply options
  local bufnr = vim.api.nvim_win_get_buf(winid)
  for opt, val in pairs(get_opts(name)) do
    -- Try to set as window option first, then buffer option
    pcall(vim.api.nvim_set_option_value, opt, val, { win = winid })
    pcall(vim.api.nvim_set_option_value, opt, val, { buf = bufnr })
  end

  -- Set up 'q' mapping if not already mapped
  local maps = vim.api.nvim_buf_get_keymap(bufnr, 'n')
  local has_q = false
  for _, map in ipairs(maps) do
    if map.lhs == 'q' then
      has_q = true
      break
    end
  end

  if not has_q then
    vim.api.nvim_buf_set_keymap(bufnr, 'n', 'q', '<C-w>q', {
      silent = true,
      noremap = true,
    })
  end
end

---Find all windows at a given position
---@param position string
---@return table<integer, string> Map of window IDs to sidebar names
local function find_windows_at_position(position)
  local found = {}
  for _, name in ipairs(position_name_map[position]) do
    local winid = get_win(name)
    if winid then
      found[winid] = name
    end
  end
  return found
end

---Wait for windows at a position to close
---@param position string
local function wait_for_close(position)
  while true do
    local found_wins = find_windows_at_position(position)
    if vim.tbl_isempty(found_wins) then
      break
    end
    vim.uv.sleep(30)
  end
end

---Open a sidebar
---@param name string
local function open(name)
  local sidebar = sidebars[name]
  call_or_exec(sidebar.open)

  local winid = get_win(name)
  if winid and vim.api.nvim_get_current_win() ~= winid then
    vim.api.nvim_set_current_win(winid)
  end
end

---Close a sidebar
---@param name string
local function close(name)
  local sidebar = sidebars[name]

  if M.config.lualine ~= nil and M.config.lualine ~= false then
    require("lualine.components.sidebar").set_current({})
  end

  if sidebar.close then
    call_or_exec(sidebar.close)
  else
    local winid = get_win(name)
    if winid then
      vim.api.nvim_win_close(winid, false)
    end
  end
  wait_for_close(sidebar.position)
end

---Check if a sidebar should not be closed when switching to another
---@param prev_name string
---@param next_name string
---@return boolean
local function dont_close(prev_name, next_name)
  local next_sidebar = sidebars[next_name]
  if next_sidebar.dont_close then
    if type(next_sidebar.dont_close) == 'string' then
      return prev_name:match(next_sidebar.dont_close) ~= nil
    elseif type(next_sidebar.dont_close) == 'table' then
      for _, pattern in ipairs(next_sidebar.dont_close) do
        if prev_name:match(pattern) then
          return true
        end
      end
    end
  end
  return false
end

-- View management

local saved_views = {}

---Save views for all windows (only needed for older Neovim without splitkeep)
local function save_view()
  if vim.o.splitkeep ~= nil then
    return -- Neovim handles this automatically with splitkeep
  end

  saved_views = {}
  local cur_win = vim.api.nvim_get_current_win()
  local wins = vim.api.nvim_tabpage_list_wins(0)

  for _, winid in ipairs(wins) do
    vim.api.nvim_set_current_win(winid)
    saved_views[winid] = vim.fn.winsaveview()
  end

  if vim.api.nvim_win_is_valid(cur_win) then
    vim.api.nvim_set_current_win(cur_win)
  end
end

---Restore views for all windows
local function restore_view()
  if vim.o.splitkeep ~= nil then
    return -- Neovim handles this automatically with splitkeep
  end

  local cur_win = vim.api.nvim_get_current_win()

  for winid, view in pairs(saved_views) do
    if vim.api.nvim_win_is_valid(winid) then
      vim.api.nvim_set_current_win(winid)
      vim.fn.winrestview(view)
    end
  end

  if vim.api.nvim_win_is_valid(cur_win) then
    vim.api.nvim_set_current_win(cur_win)
  end

  saved_views = {}
end

-- Public API

---Register a sidebar
---@param desc table Sidebar description with name, position, filter, open, close, etc.
function M.register(desc)
  if not desc.name then
    error('Sidebar description must include a name')
  end

  sidebars[desc.name] = desc
  table.insert(position_name_map[desc.position], desc.name)
end

---Check if a window is a sidebar
---@param winid integer|nil Window ID (nil for current window)
---@return boolean
function M.is_sidebar(winid)
  winid = winid or vim.api.nvim_get_current_win()

  for name, sidebar in pairs(sidebars) do
    if sidebar.get_win then
      if call_or_eval(sidebar.get_win) == winid then
        return true
      end
    else
      if filter_win(name, winid) then
        return true
      end
    end
  end

  return false
end

---Get current sidebar info
---@return integer|nil, table|nil Window ID and sidebar description
function M.get_current_sidebar()
  local cur_win = vim.api.nvim_get_current_win()

  for name, sidebar in pairs(sidebars) do
    local winid = get_win(name)
    if winid == cur_win then
      return winid, sidebar
    end
  end

  return nil, nil
end

---Setup the current sidebar window
function M.setup_current_sidebar_window()
  local saved_lazyredraw = vim.o.lazyredraw
  vim.o.lazyredraw = true

  local winid, sidebar = M.get_current_sidebar()
  if winid and sidebar then
    if M.config.lualine ~= nil and M.config.lualine ~= false then
      require("lualine.components.sidebar").set_current(sidebar)
    end
    setup_win(sidebar.name, winid)
  end

  vim.o.lazyredraw = saved_lazyredraw
end

---Switch to a sidebar (opens if closed, focuses if open, closes others at same position)
---@param name string
function M.switch(name)
  if not sidebars[name] then
    error(string.format('Unknown sidebar: %s', name))
  end

  local sidebar = sidebars[name]
  local position = sidebar.position

  if position == 'top' or position == 'bottom' then
    save_view()
  end

  local found_desired_win = nil
  local found_wins = find_windows_at_position(position)

  for winid, found_name in pairs(found_wins) do
    if found_name == name then
      found_desired_win = winid
    else
      if not dont_close(found_name, name) then
        close(found_name)
      end
    end
  end

  -- Move focus away from closing sidebar
  local cur_win = vim.api.nvim_get_current_win()
  for winid, _ in pairs(found_wins) do
    if winid == cur_win then
      vim.cmd('wincmd p')
      break
    end
  end

  if found_desired_win then
    if vim.api.nvim_get_current_win() ~= found_desired_win then
      vim.api.nvim_set_current_win(found_desired_win)
    end
  else
    open(name)
  end

  if position == 'top' or position == 'bottom' then
    restore_view()
  end

  if M.config.lualine ~= nil and M.config.lualine ~= false then
    require("lualine.components.sidebar").set_current(sidebar)
  end
end

---Open a sidebar
---@param name string
function M.open(name)
  return M.switch(name)
end

---Close a sidebar
---@param name string
function M.close(name)
  if not sidebars[name] then
    error(string.format('Unknown sidebar: %s', name))
  end

  local sidebar = sidebars[name]
  local position = sidebar.position

  if position == 'top' or position == 'bottom' then
    save_view()
  end

  local winid = get_win(name)
  if winid then
    close(name)
  end

  if position == 'top' or position == 'bottom' then
    restore_view()
  end
end

---Toggle a sidebar (closes if open, opens if closed, closes others at same position)
---@param name string
function M.toggle(name)
  if not sidebars[name] then
    error(string.format('Unknown sidebar: %s', name))
  end

  local sidebar = sidebars[name]
  local position = sidebar.position

  if position == 'top' or position == 'bottom' then
    save_view()
  end

  local found_desired_win = nil
  local found_wins = find_windows_at_position(position)

  for winid, found_name in pairs(found_wins) do
    if found_name == name then
      found_desired_win = winid
    else
      if not dont_close(found_name, name) then
        close(found_name)
      end
    end
  end

  -- Move focus away from closing sidebar
  local cur_win = vim.api.nvim_get_current_win()
  for winid, _ in pairs(found_wins) do
    if winid == cur_win then
      vim.cmd('wincmd p')
      break
    end
  end

  if found_desired_win then
    close(name)
  else
    open(name)
  end

  if position == 'top' or position == 'bottom' then
    restore_view()
  end
end

---Close all sidebars at a given position
---@param position string 'left', 'right', 'top', or 'bottom'
function M.close_side(position)
  save_view()

  for _, name in ipairs(position_name_map[position]) do
    local winid = get_win(name)
    if winid then
      close(name)
    end
  end

  restore_view()
end

---Close all sidebars at a position except one
---@param position string
---@param except_name string
function M.close_side_except(position, except_name)
  save_view()

  for _, name in ipairs(position_name_map[position]) do
    if name ~= except_name then
      local winid = get_win(name)
      if winid then
        close(name)
      end
    end
  end

  restore_view()
end

---Close all sidebars
function M.close_all()
  save_view()

  for name, _ in pairs(sidebars) do
    local winid = get_win(name)
    if winid then
      close(name)
    end
  end

  restore_view()
end

---Close tab if only sidebars remain
function M.close_tab_on_closing_last_buffer()
  local wins = vim.api.nvim_tabpage_list_wins(0)
  local num_non_sidebar_wins = 0

  for _, winid in ipairs(wins) do
    if not M.is_sidebar(winid) then
      num_non_sidebar_wins = num_non_sidebar_wins + 1
    end
  end

  if num_non_sidebar_wins == 0 then
    local tabpages = vim.api.nvim_list_tabpages()
    if #tabpages > 1 then
      vim.cmd('confirm tabclose')
    else
      vim.cmd('confirm qall')
    end
  end
end

---Get registered sidebars
---@param name string|nil Optional sidebar name
---@return table|table[] Sidebar(s)
function M.get(name)
  if name then
    return sidebars[name]
  else
    return vim.tbl_values(sidebars)
  end
end

---Open the last used help window
---@param cmd string Command to use (e.g., 'vertical split')
function M.open_last_help(cmd)
  local bufnr = 0
  local lastused = 0

  local bufs = vim.api.nvim_list_bufs()
  for _, nr in ipairs(bufs) do
    if vim.bo[nr].buftype == 'help' then
      local bufinfo = vim.fn.getbufinfo(nr)[1]
      if nr > bufnr or bufinfo.lastused > lastused then
        bufnr = nr
        lastused = bufinfo.lastused
      end
    end
  end

  vim.cmd(cmd .. ' help')
  if bufnr > 0 then
    vim.cmd('buffer ' .. bufnr)
  end
end

---Get lualine component for sidebars
---@param opts? table Options for the lualine component
function M.lualine_component(opts)
  opts = opts or {}

  require("lualine.components.sidebar").setup(opts)
end

---Setup plugin
---@param opts table|nil Configuration options
---  - sidebars: table Dictionary of sidebar configurations (key = name, value = config)
---              or array of sidebar configs (each must have 'name' field)
---  - left_width: number|nil Default width for left sidebars
---  - right_width: number|nil Default width for right sidebars
---  - top_height: number|nil Default height for top sidebars
---  - bottom_height: number|nil Default height for bottom sidebars
---  - move: boolean|nil Whether to move sidebars to their position
---  - opts: table|nil Default window options for all sidebars
---  - close_tab_on_closing_last_buffer: boolean|nil Auto-close tab when only sidebars remain
function M.setup(opts)
  opts = opts or {}

  -- Extract sidebars config before merging
  local sidebars_config = opts.sidebars
  opts.sidebars = nil -- Remove from opts to avoid merging into M.config

  -- Merge user config (excluding sidebars)
  M.config = vim.tbl_deep_extend('force', M.config, opts)

  -- Register sidebars
  if sidebars_config then
    -- Support both dictionary format and array format
    if vim.islist(sidebars_config) then
      -- Array format: each item must have a 'name' field
      for _, sidebar_config in ipairs(sidebars_config) do
        if not sidebar_config.name then
          error('Sidebar config in array format must include a "name" field')
        end
        M.register(sidebar_config)
      end
    else
      -- Dictionary format: key is the name
      for name, attrs in pairs(sidebars_config) do
        local desc = vim.tbl_extend('force', {}, attrs)
        desc.name = name
        M.register(desc)
      end
    end
  end

  if M.config.lualine ~= nil then
    if type(M.config.lualine) == "table" then
      require("lualine.components.sidebar").setup({
        sidebars = sidebars_config,
        config = M.config.lualine,
      })
    elseif M.config.lualine then
      require("lualine.components.sidebar").setup({ sidebars = sidebars_config })
    end
  end

  -- Create autocommands
  local group = vim.api.nvim_create_augroup('Sidebar', { clear = true })

  if M.config.close_tab_on_closing_last_buffer then
    vim.api.nvim_create_autocmd('WinEnter', {
      group = group,
      callback = M.close_tab_on_closing_last_buffer,
    })
  end

  vim.api.nvim_create_autocmd({ 'BufWinEnter', 'FileType' }, {
    group = group,
    callback = function()
      -- Schedule to avoid issues with window setup during events
      vim.schedule(function()
        if M.is_sidebar() then
          M.setup_current_sidebar_window()
        end
      end)
    end,
  })

  vim.api.nvim_create_autocmd({ 'BufWinLeave' }, {
    group = group,
    callback = function()
      -- Schedule to avoid issues with window setup during events
      vim.schedule(function()
        if M.is_sidebar() then
          M.setup_current_sidebar_window()
        end
      end)
    end,
  })

  -- Create user commands
  vim.api.nvim_create_user_command('Sidebar', function(args)
    M.open(args.args)
  end, {
    nargs = 1,
    complete = function(arg_lead)
      local names = {}
      for name, _ in pairs(sidebars) do
        if vim.startswith(name, arg_lead) then
          table.insert(names, name)
        end
      end
      return names
    end,
  })

  vim.api.nvim_create_user_command('SidebarOpen', function(args)
    M.open(args.args)
  end, {
    nargs = 1,
    complete = function(arg_lead)
      local names = {}
      for name, _ in pairs(sidebars) do
        if vim.startswith(name, arg_lead) then
          table.insert(names, name)
        end
      end
      return names
    end,
  })

  vim.api.nvim_create_user_command('SidebarSwitch', function(args)
    M.switch(args.args)
  end, {
    nargs = 1,
    complete = function(arg_lead)
      local names = {}
      for name, _ in pairs(sidebars) do
        if vim.startswith(name, arg_lead) then
          table.insert(names, name)
        end
      end
      return names
    end,
  })

  vim.api.nvim_create_user_command('SidebarToggle', function(args)
    M.toggle(args.args)
  end, {
    nargs = 1,
    complete = function(arg_lead)
      local names = {}
      for name, _ in pairs(sidebars) do
        if vim.startswith(name, arg_lead) then
          table.insert(names, name)
        end
      end
      return names
    end,
  })

  vim.api.nvim_create_user_command('SidebarClose', function(args)
    M.close(args.args)
  end, {
    nargs = 1,
    complete = function(arg_lead)
      local names = {}
      for name, _ in pairs(sidebars) do
        if vim.startswith(name, arg_lead) then
          table.insert(names, name)
        end
      end
      return names
    end,
  })

  vim.api.nvim_create_user_command('SidebarCloseSide', function(args)
    M.close_side(args.args)
  end, {
    nargs = 1,
    complete = function(arg_lead)
      local positions = { 'left', 'right', 'top', 'bottom' }
      local matches = {}
      for _, pos in ipairs(positions) do
        if vim.startswith(pos, arg_lead) then
          table.insert(matches, pos)
        end
      end
      return matches
    end,
  })

  vim.api.nvim_create_user_command('SidebarCloseAll', function()
    M.close_all()
  end, { nargs = 0 })
end

return M
