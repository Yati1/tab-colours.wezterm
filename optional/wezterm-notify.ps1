# Raises a Windows toast when Claude Code needs the user. Clicking it opens
# wezterm-focus:<pane-id>, which wezterm-focus.vbs and wezterm-focus.ps1 handle
# so your wezterm.lua can bring that pane's window and tab forward. WezTerm sets
# WEZTERM_PANE in every pane, and Claude and this hook inherit it.
# Run it with Windows PowerShell 5.1 (powershell.exe). PowerShell 7 cannot load
# the Windows toast API.
[Console]::InputEncoding = [Text.Encoding]::UTF8

$data = [Console]::In.ReadToEnd() | ConvertFrom-Json

$body = switch ($data.hook_event_name) {
  'PreToolUse' {
    $question = @($data.tool_input.questions)[0].question
    if ($question) { "Question: $question" } else { 'Claude has a question' }
  }
  default { if ($data.message) { $data.message } else { 'Claude needs your attention' } }
}

$folder = if ($data.cwd) { Split-Path $data.cwd -Leaf } else { '' }
$title = "Claude - $folder"

function Clean([string]$text) { ($text -replace '[\x00-\x1f\x7f]', ' ').Trim() }
$title = Clean $title
$body = Clean $body
if ($body.Length -gt 200) { $body = $body.Substring(0, 197) + '...' }

$pane = $env:WEZTERM_PANE
$launch = ''
if ($pane -match '^\d+$') {
  $launch = " activationType=`"protocol`" launch=`"wezterm-focus:$pane`""
  # wezterm.lua puts a bell on the tab while this file exists. The
  # clear-waiting hooks in ~/.claude/settings.json delete it.
  $dir = New-Item -ItemType Directory -Force "$env:USERPROFILE\.claude-waiting"
  Set-Content -Path "$dir\$pane" -Value '' -NoNewline
}
$esc = [Security.SecurityElement]
$xml = @"
<toast$launch>
  <visual><binding template="ToastGeneric">
    <text>$($esc::Escape($title))</text>
    <text>$($esc::Escape($body))</text>
  </binding></visual>
  <audio src="ms-winsoundevent:Notification.Default"/>
</toast>
"@

# Each run appends one line to this log, so a toast that never shows leaves
# a trace. 'start' with no 'shown' after it means the process died mid-Show.
$log = "$env:TEMP\claude-notify.log"
function Log([string]$what) {
  $line = "$(Get-Date -Format o) event=$($data.hook_event_name) pane=$pane $what"
  Add-Content -Path $log -Value $line -ErrorAction SilentlyContinue
}

Log 'start'
try {
  [void][Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime]
  [void][Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom, ContentType = WindowsRuntime]
  $doc = New-Object Windows.Data.Xml.Dom.XmlDocument
  $doc.LoadXml($xml)
  $toast = New-Object Windows.UI.Notifications.ToastNotification $doc
  # WezTerm's installer registers this app id, so the toast shows as WezTerm.
  [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier('org.wezfurlong.wezterm').Show($toast)
  # Give Windows a moment to take the toast before this process exits.
  Start-Sleep -Milliseconds 300
  Log 'shown'
} catch {
  Log "error: $($_.Exception.GetType().FullName): $($_.Exception.Message)"
}
