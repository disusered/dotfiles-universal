# --- Git Path Detection and Configuration ---
# Find git.exe on your system. This works for Winget, Scoop, or standard installs.
$gitCommand = Get-Command git.exe -ErrorAction SilentlyContinue

if ($gitCommand) {
    # Git log options for the 'gli' function and other git commands
    $env:GIT_LOG_STYLE = "%C(bold #cba6f7)%h%C(reset) %C(bold #89b4fa)%aN%C(reset) %C(auto)%d%C(reset)%C(#cdd6f4)%s %C(#a6adc8)(%cr)%C(reset)"

    # --- Git Aliases (as PowerShell Functions) ---
    Remove-Alias -Name gp -Force
    Remove-Alias -Name gl -Force
    function g { git $args }
    function gcp { git cherry-pick $args }
    function gs { git s $args }
    function gb { git b $args }
    function gbc { git bc $args }
    function gc { git c $args }
    function gca { git ca $args }
    function gcm { git cm $args }
    function ga { git a $args }
    function gp { git p $args }
    function gpf { git pf $args }
    function gd { git d $args }
    function gdt { git dt $args }
    function gm { git m $args }
    function gmt { git mt $args }
    function gf { git f $args }
    function gfm { git fm $args }
    function gr { git r $args }
    function gco { git co $args }
    function gl {
        <#
    .SYNOPSIS
        An interactive 'git log' viewer using fzf.
    .DESCRIPTION
        Displays the git log, allowing you to select commits with fzf for various actions.
        - Enter: Show details for selected commit(s).
        - Ctrl+D: Show a combined diff for selected commit(s).
        - Ctrl+I: Start an interactive rebase from the selected commit's parent.
        - Ctrl+R: Hard reset to the selected commit.
        - Ctrl+C: Copy the selected commit SHA(s) to the clipboard.
    .NOTES
        Requires 'fzf' and 'git' to be installed and in your PATH.
        Ported from: https://gist.github.com/junegunn/f4fca918e937e6bf5bad
    #>

        # 1. Check for dependencies
        if (-not (Get-Command fzf -ErrorAction SilentlyContinue)) {
            Write-Error "fzf is not installed or not in your PATH. Please install it to use this function."
            return
        }

        # 2. Main interactive loop
        while ($true) {
            # The core command: pipe git log to fzf and capture the multi-line output
            $fzfOutput = git l @args | fzf --ansi --no-sort --reverse --multi --query=$query --print-query --expect='ctrl-d,ctrl-c,ctrl-i,ctrl-r' --toggle-sort='`'

            # Exit if fzf was cancelled (e.g., with Esc)
            if (-not $fzfOutput) {
                break
            }

            # 3. Parse fzf's output
            $query = $fzfOutput[0]
            $keyPressed = $fzfOutput[1]

            # Extract commit SHAs from the remaining lines
            # This regex is designed to find the first alphanumeric hash on each line
            $shas = $fzfOutput | Select-Object -Skip 2 | ForEach-Object {
                if ($_ -match '^[^\da-f]*([a-f0-9]{7,40})') {
                    $matches[1]
                }
            } | Where-Object { $_ }

            # If no commits were selected, restart the loop
            if (-not $shas) {
                continue
            }

            # For actions that only accept a single commit, use the first one selected
            $firstSha = $shas[0]

            # 5. Handle the user's action
            switch ($keyPressed) {
                'ctrl-d' {
                    git show $shas
                    break # Exit the loop after showing the diff
                }
                'ctrl-i' {
                    # Interactive rebase from the parent of the first selected commit
                    git rebase --interactive "$($firstSha)~"
                    break # Rebase opens an editor, so exit the loop
                }
                'ctrl-c' {
                    # Join all SHAs with a space and copy to clipboard
                    $shas -join ' ' | Set-Clipboard
                    Write-Host "Copied $($shas.Count) commit SHA(s) to clipboard."
                    break # Exit the loop after copying
                }
                'ctrl-r' {
                    git reset --hard $firstSha
                    break # Reset alters history, so exit the loop
                }
                default {
                    # The default action (Enter key) is to show each selected commit
                    foreach ($sha in $shas) {
                        git show $sha
                    }
                    # Loop continues after showing
                }
            }
        }
    }

    # Get the main installation directory (e.g., 'C:\Program Files\Git')
    $gitRootPath = Split-Path -Path (Split-Path -Path $gitCommand.Source -Parent) -Parent

    # Add the Git cmd and usr/bin directories to the PATH for the current session
    # The 'usr\bin' directory includes useful GNU utilities like ls, grep, and ssh.
    $env:Path += ";$($gitRootPath)\usr\bin"
}
else {
    # Display a warning if Git is not found
    Write-Warning "Git could not be found. Please ensure it's installed and in your PATH."
}
