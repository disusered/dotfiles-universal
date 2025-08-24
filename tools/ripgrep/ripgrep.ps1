# Configuration path for ripgrep
$Env:RIPGREP_CONFIG_PATH = Join-Path $HOME "AppData/Local/ripgrep/ripgreprc"

# Search with ripgrep and pipe to delta for a side-by-side view
# Usage: rgi [rg_flags] <search_term>
# Example: rgi -C 2 my_search_term
function rgi {
    # Check if any arguments were provided
    if ($args.Count -eq 0) {
        Write-Error "Usage: rg [rg_flags] <search_term>"
        return
    }

    try {
        # Get the full path to the rg executable to avoid the alias loop
        $rgPath = (Get-Command rg.exe -ErrorAction Stop).Source

        # Execute rg using its full path and pipe the JSON output to delta
        # The '&' is the call operator, used to execute the command at the specified path.
        & $rgPath --json -C 2 $args | delta
    }
    catch {
        Write-Error "Error executing ripgrep. Make sure 'rg.exe' and 'delta.exe' are in your PATH."
        Write-Error $_.Exception.Message
    }
}

# Aliases for text search
Set-Alias -Name rg -Value rgi
Set-Alias -Name ag -Value rgi
