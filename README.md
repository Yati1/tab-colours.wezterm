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
| `title_suffix` | `nil` | A function that takes the tab (as `format-tab-title` gets it) and returns text to add after the folder name, or `nil`. |

The plugin sets `use_fancy_tab_bar = false` and `status_update_interval`, and uses the
`format-tab-title` and `update-status` events and the right status. Another plugin that uses
those will clash with it.

## Optional: a bell when Claude Code waits

`optional/` holds hook scripts for [Claude Code](https://claude.com/claude-code). When Claude asks
a question or wants permission, `wezterm-notify.ps1`:

- writes an empty file named for the pane, `~/.claude-waiting/<WEZTERM_PANE>`, so your
  `wezterm.lua` can put a 🔔 on that tab;
- shows a Windows toast with the default notification sound.

Click the toast to jump to the pane. `wezterm-focus.vbs` and `wezterm-focus.ps1` handle the click.

This only works on Windows, and the hook must run in Windows PowerShell 5.1 (`powershell.exe`).
PowerShell 7 (`pwsh`) cannot load the toast API.

### 1. Copy the scripts

Copy the three files in `optional/` to `~/.claude/hooks/`. Keep them in one folder: the `.vbs`
looks for `wezterm-focus.ps1` next to itself.

### 2. Add the hooks

Merge these into `~/.claude/settings.json`. The first two run the script when Claude waits. The
last three delete the pane's file when you reply, when Claude stops, or when the session ends.

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "AskUserQuestion",
        "hooks": [
          {
            "type": "command",
            "command": "& \"$env:USERPROFILE\\.claude\\hooks\\wezterm-notify.ps1\"",
            "shell": "powershell"
          }
        ]
      }
    ],
    "Notification": [
      {
        "matcher": "permission_prompt|elicitation_dialog",
        "hooks": [
          {
            "type": "command",
            "command": "& \"$env:USERPROFILE\\.claude\\hooks\\wezterm-notify.ps1\"",
            "shell": "powershell"
          }
        ]
      }
    ],
    "UserPromptSubmit": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "if ($env:WEZTERM_PANE) { Remove-Item \"$env:USERPROFILE\\.claude-waiting\\$env:WEZTERM_PANE\" -ErrorAction SilentlyContinue }; exit 0",
            "shell": "powershell"
          }
        ]
      }
    ],
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "if ($env:WEZTERM_PANE) { Remove-Item \"$env:USERPROFILE\\.claude-waiting\\$env:WEZTERM_PANE\" -ErrorAction SilentlyContinue }; exit 0",
            "shell": "powershell"
          }
        ]
      }
    ],
    "SessionEnd": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "if ($env:WEZTERM_PANE) { Remove-Item \"$env:USERPROFILE\\.claude-waiting\\$env:WEZTERM_PANE\" -ErrorAction SilentlyContinue }; exit 0",
            "shell": "powershell"
          }
        ]
      }
    ]
  }
}
```

If you already have hooks for these events, add these entries to their lists.

### 3. Show the bell in WezTerm

Put `bell_for` above `apply_to_config` and pass it as `title_suffix`. The `update-status` handler
reads `~/.claude-waiting` each tick. It also deletes a pane's file once Claude moves on after you
answer, or once the pane closes. Claude starts its title with ✳ while idle, and the handler
watches for the title to change from that.

```lua
local waiting_dir = wezterm.home_dir .. '/.claude-waiting'
local waiting = {}   -- pane id -> true
local IDLE = '✳'
local idle_seen = {}

local function bell_for(tab)
  local ok, mux_tab = pcall(wezterm.mux.get_tab, tab.tab_id)
  for _, pane in ipairs(ok and mux_tab and mux_tab:panes() or {}) do
    if waiting[pane:pane_id()] then return ' 🔔' end
  end
  if waiting[tab.active_pane.pane_id] then return ' 🔔' end
end

tab_colours.apply_to_config(config, {
  folders = { --[[ your rules ]] },
  title_suffix = bell_for,
})

-- WezTerm redraws the tab bar only when something it watches changes, such as
-- the left status. So when the set of waiting panes changes, flip the left
-- status between two values that both draw nothing.
local seen, flipped = {}, {}
wezterm.on('update-status', function(window)
  local ids, key = {}, {}
  local ok, paths = pcall(wezterm.read_dir, waiting_dir)
  for _, path in ipairs(ok and paths or {}) do
    local id = tonumber(path:match('[/\\](%d+)$'))
    local found, pane = false, nil
    if id then found, pane = pcall(wezterm.mux.get_pane, id) end
    pane = found and pane or nil
    local title = pane and pane:get_title() or ''
    if title:sub(1, #IDLE) == IDLE then
      idle_seen[id] = true
    elseif id and (idle_seen[id] or not pane) then
      os.remove(path)
      idle_seen[id] = nil
      id = nil
    end
    if id then
      ids[id] = true
      table.insert(key, id)
    end
  end
  waiting = ids
  table.sort(key)
  key = table.concat(key, ',')

  local win = window:window_id()
  if seen[win] == key then return end
  seen[win] = key
  flipped[win] = not flipped[win]
  window:set_left_status(flipped[win] and wezterm.format({ 'ResetAttributes' }) or '')
end)
```

### 4. Click to focus (optional)

Skip this step if you only want the bell and the sound.

The toast opens a `wezterm-focus:<pane-id>` link. Register that link type once, from PowerShell:

```powershell
$key = 'HKCU:\Software\Classes\wezterm-focus'
New-Item -Force $key -Value 'URL:WezTerm focus pane' | Out-Null
Set-ItemProperty $key -Name 'URL Protocol' -Value ''
$vbs = "$env:USERPROFILE\.claude\hooks\wezterm-focus.vbs"
New-Item -Force "$key\shell\open\command" -Value "wscript.exe //B //Nologo `"$vbs`" `"%1`"" | Out-Null
```

`wezterm-focus.ps1` raises the WezTerm window and writes the pane id to
`~/.wezterm-focus-request`. Add this to `wezterm.lua` so WezTerm switches to that tab and pane:

```lua
local focus_request = wezterm.home_dir .. '/.wezterm-focus-request'
wezterm.on('update-status', function()
  local file = io.open(focus_request, 'r')
  if not file then return end
  local id = tonumber(file:read('*a'))
  file:close()
  os.remove(focus_request)

  local ok, pane = pcall(wezterm.mux.get_pane, id)
  if not ok or not pane then return end
  local tab = pane:tab()
  local gui = tab and tab:window():gui_window()
  if not gui then return end
  tab:activate()
  pane:activate()
  gui:focus()
end)
```

The script logs each toast to `%TEMP%\claude-notify.log`. If no toast shows, look there.

## Update

WezTerm does not update plugins by itself. Open the debug overlay (Ctrl+Shift+L) and run
`wezterm.plugin.update_all()`.
