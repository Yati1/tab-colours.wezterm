-- Colours each WezTerm tab by the folder its shell is in, and gives the
-- cursor the active tab's colour. See README.md for the shell hook it needs.
local wezterm = require 'wezterm'

local M = {}

local defaults = {
  -- The first entry whose match appears in the path wins. Lower case, with /
  -- between folders. A * matches any run of characters within one folder name.
  folders = {},
  -- The tab colour when no folder matches. The cursor keeps its normal colour.
  default_colour = '#333333',
  -- Inactive tabs keep this share of their colour's brightness (0 to 1).
  inactive_brightness = 0.5,
  -- Black text goes on colours whose WCAG relative luminance is above this.
  brightness_threshold = 0.179,
  -- How often, in milliseconds, to check the active pane's folder.
  update_interval = 500,
}

local function path_of(url)
  if not url then return '' end
  return (url.file_path or tostring(url)):lower()
end

-- Turns a match with * wildcards into a Lua pattern. Every other character
-- matches only itself.
local function glob_to_pattern(glob)
  local escaped = glob:lower():gsub('[%^%$%(%)%%%.%[%]%+%-%?]', '%%%0')
  return (escaped:gsub('%*', '[^/]*'))
end

-- Scales each channel of a '#RRGGBB' colour by keep (0 to 1), towards black.
local function darken(hex, keep)
  local function channel(i)
    return math.floor(tonumber(hex:sub(i, i + 1), 16) * keep + 0.5)
  end
  return string.format('#%02X%02X%02X', channel(2), channel(4), channel(6))
end

-- The WCAG relative luminance of a '#RRGGBB' colour, from 0 to 1.
local function luminance(hex)
  local function channel(i)
    local c = tonumber(hex:sub(i, i + 1), 16) / 255
    return c <= 0.04045 and c / 12.92 or ((c + 0.055) / 1.055) ^ 2.4
  end
  return 0.2126 * channel(2) + 0.7152 * channel(4) + 0.0722 * channel(6)
end

function M.apply_to_config(config, opts)
  opts = opts or {}
  for key, value in pairs(defaults) do
    if opts[key] == nil then opts[key] = value end
  end

  local rules = {}
  for _, rule in ipairs(opts.folders) do
    table.insert(rules, { pattern = glob_to_pattern(rule.match), colour = rule.colour })
  end

  -- Returns the folder's colour, or nil when no rule matches.
  local function colour_for(path)
    for _, rule in ipairs(rules) do
      if path:find(rule.pattern) then return rule.colour end
    end
    return nil
  end

  local function is_bright(hex)
    return luminance(hex) > opts.brightness_threshold
  end

  -- The retro tab bar draws the colours that format-tab-title returns.
  config.use_fancy_tab_bar = false

  wezterm.on('format-tab-title', function(tab)
    local path = path_of(tab.active_pane.current_working_dir)
    local colour = colour_for(path) or opts.default_colour
    local folder = path:match('([^/]+)/*$') or tab.active_pane.title
    -- Darken inactive tabs so the active one stands out.
    if not tab.is_active then
      colour = darken(colour, opts.inactive_brightness)
    end
    local fg
    if is_bright(colour) then
      fg = tab.is_active and '#000000' or '#333333'
    else
      fg = tab.is_active and '#FFFFFF' or '#BBBBBB'
    end
    return {
      { Background = { Color = colour } },
      { Foreground = { Color = fg } },
      { Text = ' ' .. folder .. ' ' },
    }
  end)

  -- WezTerm does not redraw the tab bar when the folder changes. A change to
  -- the right status does redraw it, so show the active pane's folder there.
  config.status_update_interval = opts.update_interval
  wezterm.on('update-status', function(window, pane)
    local url = pane:get_current_working_dir()
    window:set_right_status(' ' .. (url and (url.file_path or tostring(url)) or '') .. ' ')

    -- Give the cursor the active tab's colour. The default colour would often
    -- hide the cursor, so with no match keep the normal one. Setting overrides
    -- reloads the window's config, so only set them when the colour changes.
    local colour = colour_for(path_of(url))
    local overrides = window:get_config_overrides() or {}
    local current = overrides.colors and overrides.colors.cursor_bg
    if current == colour then return end
    if colour then
      overrides.colors = {
        cursor_bg = colour,
        cursor_border = colour,
        cursor_fg = is_bright(colour) and '#000000' or '#FFFFFF',
      }
    else
      overrides.colors = nil
    end
    window:set_config_overrides(overrides)
  end)
end

return M
