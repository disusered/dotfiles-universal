Import-Module PSReadLine
Import-Module Sudo

# Include local binaries
$env:Path += ';' + $HOME + '\.local\bin'

# Exit with ctrl+d
Set-PSReadlineKeyHandler -Key ctrl+d -Function ViExit

# Vim mode
Set-PSReadlineOption -EditMode vi
Set-PSReadLineOption -ViModeIndicator Cursor 

# Accept suggestion with tab
Set-PSReadLineKeyHandler -Key Tab `
                         -BriefDescription ForwardCharAndAcceptNextSuggestionWord `
                         -LongDescription "Move cursor one character to the right in the current editing line and accept the next word in suggestion when it's at the end of current editing line" `
                         -ScriptBlock {
    param($key, $arg)

    $line = $null
    $cursor = $null
    [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$line, [ref]$cursor)

    if ($cursor -lt $line.Length) {
        [Microsoft.PowerShell.PSConsoleReadLine]::ForwardChar($key, $arg)
    } else {
        [Microsoft.PowerShell.PSConsoleReadLine]::AcceptSuggestion($key, $arg)
    }
}

# Inlcude all scripts in the config profile.d folder
$scriptFolder = Join-Path $HOME '.config/powershell/profile.d'
$scripts = Get-ChildItem -Path $scriptFolder -Filter '*.ps1'
foreach ($script in $scripts) {
  . $script.FullName
}
