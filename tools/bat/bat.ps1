# Only rn if bat is installed
$batCommand = Get-Command bat.exe -ErrorAction SilentlyContinue
if ($batCommand) {
    # Set environment variables for bat configuration
    $Env:BAT_CONFIG_DIR = Join-Path $HOME "AppData/Local/bat/"
    $Env:BAT_THEME = 'Catppuccin Mocha'

    # Remove existing cat alias
    Remove-Alias -Name cat -Force

    # See if theme is installed, if not, rebuild cache
    $catppuccinInstalled = bat --list-themes 2>&1 | Select-String -Pattern 'Catppuccin' -Quiet
    if (-not $catppuccinInstalled) {
        try {
            # Execute the command to rebuild the cache.
            bat cache --build
        }
        catch {
            Write-Error $_
        }
    }

    function cat { bat $args }
}
