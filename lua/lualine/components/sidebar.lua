local M = require("lualine.component"):extend()
local highlight = require("lualine.highlight")

M.sidebars = {}
M.current_status = ''
M.config = {
  separator = ' ',
  -- Color for active sidebar
  active_color = { fg = '#89b4fa' },
  -- Color for inactive sidebar
  inactive_color = { fg = '#585b70' },
  -- Show sidebar names (not just icons)
  show_names = false,
  -- Custom icon if sidebar doesn't have one
  default_icon = '󰍉',
  -- Padding
  padding = { left = 1, right = 1 },
  -- Filter sidebars to show (by position)
  filter_position = nil, -- e.g., 'bottom', 'left', etc.
}
M.init_done = false
M.setup_done = false

-- Initializer
function M:init(options)
  M.super.init(self, options)

  local active_color = options.active_color
  local inactive_color = options.inactive_color

  M.highlights = {
    sidebar_active = highlight.create_component_highlight_group(
      active_color, 'sidebar_active', options
    ),
    sidebar_inactive = highlight.create_component_highlight_group(
      inactive_color, 'sidebar_inactive', options
    )
  }

  if M.setup_done then
    M.set_current({})
  end
  M.init_done = true
end

function M.setup(opts)
  if opts.sidebars ~= nil then
    M.sidebars = opts.sidebars
  end

  if M.init_done then
    M.set_current({})
  end
  M.setup_done = true
end

function M.set_current(current)
  local parts = {}
  for name, config in pairs(M.sidebars) do
    -- Filter by position if specified
    if M.config.filter_position and config.position ~= M.config.filter_position then
    else
      local icon = config.icon or M.config.default_icon
      local is_active = current.name ~= nil and name == current.name

      -- Build the display text
      local text = icon
      if M.config.show_names then
        text = text .. ' ' .. name
      end

      -- Apply color based on active state
      if is_active then
        -- text = '%#SidebarActive#' .. text .. '%*'
        text = highlight.component_format_highlight(M.highlights.sidebar_active) .. text
      else
        text = highlight.component_format_highlight(M.highlights.sidebar_inactive) .. text
        -- text = '%#SidebarInactive#' .. text .. '%*'
      end

      table.insert(parts, text)
    end
  end

  M.current_status = table.concat(parts, M.config.separator)
end

-- Function that runs every time statusline is updated
function M:update_status()
  return M.current_status
end

return M
