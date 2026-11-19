# Brings a WezTerm pane forward. wezterm-focus.vbs runs this, hidden, when a
# Claude toast is clicked. wezterm.lua reads the request file on its next
# status update and switches to that pane's tab; this script raises the window.
param([int]$pane)

$request = "$env:USERPROFILE\.wezterm-focus-request"
Set-Content -Path $request -Value $pane -NoNewline

Add-Type -Namespace Win32 -Name User32 -MemberDefinition @'
[DllImport("user32.dll")] public static extern bool AllowSetForegroundWindow(int processId);
[DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);
[DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
[DllImport("user32.dll")] public static extern bool IsIconic(IntPtr hWnd);
[DllImport("user32.dll")] public static extern void keybd_event(byte vk, byte scan, int flags, IntPtr extra);
'@

# Windows only lets the process that got the user's last input take the
# foreground. This one runs a step removed from the click, so it holds Alt
# down to become that process, raises WezTerm, then lets Alt go. WezTerm gets
# the Alt release and ignores a lone Alt.
$VK_MENU = 0x12; $EXTENDED = 1; $KEYUP = 2
[Win32.User32]::keybd_event($VK_MENU, 0, $EXTENDED, [IntPtr]::Zero)
try {
  $windows = @(Get-Process wezterm-gui -ErrorAction SilentlyContinue |
    Where-Object { $_.MainWindowHandle -ne [IntPtr]::Zero })
  if ($windows.Count -eq 1) {
    $hwnd = $windows[0].MainWindowHandle
    if ([Win32.User32]::IsIconic($hwnd)) { [void][Win32.User32]::ShowWindow($hwnd, 9) }
    [void][Win32.User32]::SetForegroundWindow($hwnd)
  } else {
    # With several windows only WezTerm knows which holds the pane. Pass the
    # right on and hold it until WezTerm has taken the request.
    [void][Win32.User32]::AllowSetForegroundWindow(-1)
    for ($i = 0; $i -lt 20 -and (Test-Path $request); $i++) { Start-Sleep -Milliseconds 100 }
  }
} finally {
  [Win32.User32]::keybd_event($VK_MENU, 0, $EXTENDED -bor $KEYUP, [IntPtr]::Zero)
}
