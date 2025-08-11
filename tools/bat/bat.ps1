$Env:BAT_CONFIG_DIR = '~/AppData/Local/bat/'
$Env:BAT_THEME = 'Catppuccin Mocha'

# Use Select-String with -Quiet for efficiency.
# It returns $true if a match is found, $false otherwise.
$catppuccinInstalled = bat --list-themes 2>&1 | Select-String -Pattern 'Catppuccin' -Quiet
if (-not $catppuccinInstalled) {
    try {
        # Execute the command to rebuild the cache.
        bat cache --build
    } catch {
        Write-Error $_
    }
}

