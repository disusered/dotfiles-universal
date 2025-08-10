# PowerShell Profile Script for uv-Managed Python

Write-Host "Loading uv Python environment..." -ForegroundColor DarkCyan

try {
    # Get the path to the uv-managed python.exe using the correct 'find' subcommand.
    # The .Trim() removes any leading/trailing whitespace from the command output.
    $uvPythonPath = (uv python find | Out-String).Trim()

    # Check if the path is valid and the file actually exists
    if ($uvPythonPath -and (Test-Path $uvPythonPath -PathType Leaf)) {
        # Set aliases for the current session.
        # -Force will overwrite any existing aliases with the same name.
        # -Option AllScope makes the alias available in the global scope and any child scopes.
        Set-Alias -Name python -Value $uvPythonPath -Option AllScope -Force
        Set-Alias -Name python3 -Value $uvPythonPath -Option AllScope -Force
        Set-Alias -Name python.exe -Value $uvPythonPath -Option AllScope -Force

        Write-Host "Aliases 'python' and 'python3' now point to:" -ForegroundColor Green
        Write-Host "-> $uvPythonPath" -ForegroundColor Green
    }
    else {
        # This can happen if `uv` is installed but no Python version has been installed via `uv python install`.
        Write-Warning "uv-managed Python not found. Aliases were not set."
    }
}
catch {
    # Fail gracefully if the 'uv python find' command fails for any reason.
    # This prevents errors from breaking your PowerShell profile loading.
    Write-Warning "An error occurred while trying to find the uv-managed Python. Aliases were not set."
    # You can uncomment the line below for debugging your profile if needed.
    # Write-Error $_.Exception.Message
}
