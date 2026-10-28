# tab-colours.wezterm

A WezTerm plugin that colours each tab by the folder its shell is in.

- You list folders and colours. `*` matches any run of characters within one folder name.
- Tab text turns black on bright colours and white on dark ones.
- Inactive tabs are darker, so the active one stands out.
- The cursor takes the active tab's colour.
- The right end of the tab bar shows the active pane's folder.

## Install

In `wezterm.lua`:

```lua
local wezterm = require 'wezterm'
local config = wezterm.config_builder()

local tab_colours = wezterm.plugin.require('https://github.com/Yati1/tab-colours.wezterm')
tab_colours.apply_to_config(config, {
  folders = {
    { match = 'c:/dev/project-a', colour = '#f11ece' },
    { match = 'c:/dev/proj*',     colour = '#56c499' },
    { match = 'c:/dev',           colour = '#1565C0' },
  },
})

return config
```

The first rule whose match appears anywhere in the folder's path wins, so put specific rules
above broad ones. Write paths in lower case with `/`.

### Tell WezTerm the folder

WezTerm only sees the folder a shell started in, unless the shell reports each change with an
OSC 7 escape code. For PowerShell, load `prompt.ps1` from your profile (`notepad $PROFILE`):

```powershell
. "C:\path\to\prompt.ps1"
```

It replaces your `prompt` function. If you already have one, copy the OSC 7 part into it.
Other shells: see WezTerm's docs on shell integration.

## Options

| Option | Default | What it does |
|---|---|---|
| `folders` | `{}` | List of `{ match = '...', colour = '#RRGGBB' }`. |
| `default_colour` | `'#333333'` | Tab colour when no folder matches. The cursor keeps its normal colour. |
| `inactive_brightness` | `0.5` | Share of brightness inactive tabs keep, from 0 to 1. |
| `brightness_threshold` | `0.179` | Colours brighter than this (WCAG luminance) get black text. |
| `update_interval` | `500` | How often, in ms, to check the folder and redraw. |

The plugin sets `use_fancy_tab_bar = false` and `status_update_interval`, and uses the
`format-tab-title` and `update-status` events and the right status. Another plugin that uses
those will clash with it.

## Update

WezTerm does not update plugins by itself. Open the debug overlay (Ctrl+Shift+L) and run
`wezterm.plugin.update_all()`.
