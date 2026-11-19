' Handles wezterm-focus:<pane-id> links from Claude toasts. Windows runs this
' when a toast is clicked. wscript opens no window, and it starts PowerShell
' hidden from the first moment, so nothing flashes. A plain powershell.exe
' handler would flash its console before -WindowStyle Hidden took effect.
Option Explicit
Dim re, matches, shell, fso, script

If WScript.Arguments.Count = 0 Then WScript.Quit 1
Set re = New RegExp
re.Pattern = "^wezterm-focus:/*(\d+)"
Set matches = re.Execute(WScript.Arguments(0))
If matches.Count = 0 Then WScript.Quit 1

Set shell = CreateObject("WScript.Shell")
' wezterm-focus.ps1 sits in the same folder as this file.
Set fso = CreateObject("Scripting.FileSystemObject")
script = fso.BuildPath(fso.GetParentFolderName(WScript.ScriptFullName), "wezterm-focus.ps1")
shell.Run "powershell.exe -NoProfile -NonInteractive -File """ & script & """ " & matches(0).SubMatches(0), 0, False
