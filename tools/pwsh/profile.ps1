Import-Module PSReadLine
Import-Module Sudo

# Include local binaries
$env:Path += ';' + $HOME + '\.local\bin'

# Exit with ctrl+d
Set-PSReadlineKeyHandler -Key ctrl+d -Function ViExit

# Vim mode
Set-PSReadlineOption -EditMode vi
Set-PSReadLineOption -ViModeIndicator Cursor 

# Inlcude all scripts in the config profile.d folder
$scriptFolder = Join-Path $HOME '.config/powershell/profile.d'
$scripts = Get-ChildItem -Path $scriptFolder -Filter '*.ps1'
foreach ($script in $scripts) {
  . $script.FullName
}
