# Tell the terminal the current folder (OSC 7), so WezTerm can colour tabs by folder.
# Load it from your PowerShell profile:  . "C:\path\to\prompt.ps1"
function prompt {
    $p = $executionContext.SessionState.Path.CurrentLocation
    $osc7 = ""
    if ($p.Provider.Name -eq "FileSystem") {
        $esc = [char]27
        $path = $p.ProviderPath -replace "\\", "/"
        $osc7 = "$esc]7;file://${env:COMPUTERNAME}/${path}$esc\"
    }
    "${osc7}PS $p$('>' * ($nestedPromptLevel + 1)) "
}
