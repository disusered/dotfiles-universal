# --- Git Path Detection and Configuration ---
# Find git.exe on your system. This works for Winget, Scoop, or standard installs.
$gitCommand = Get-Command git.exe -ErrorAction SilentlyContinue

if ($gitCommand) {
    # Get the main installation directory (e.g., 'C:\Program Files\Git')
    $gitRootPath = Split-Path -Path (Split-Path -Path $gitCommand.Source -Parent) -Parent

    # Add the Git cmd and usr/bin directories to the PATH for the current session
    # The 'usr\bin' directory includes useful GNU utilities like ls, grep, and ssh.
    $env:Path += ";$($gitRootPath)\usr\bin"

    # --- Git Aliases (as PowerShell Functions) ---
    # The $args variable passes along any additional arguments you type.
    function g   { git $args }
    function gcp { git cherry-pick $args }
    function gs  { git s $args }
    function gb  { git b $args }
    function gbc { git bc $args }
    function gc  { git c $args }
    function gca { git ca $args }
    function gcm { git cm $args }
    function ga  { git a $args }
    function gp  { git p $args }
    function gpf { git pf $args }
    function gd  { git d $args }
    function gdt { git dt $args }
    function gm  { git m $args }
    function gmt { git mt $args }
    function gf  { git f $args }
    function gfm { git fm $args }
    function gr  { git r $args }
    function gco { git co $args }

} else {
    # Display a warning if Git is not found
    Write-Warning "Git could not be found. Please ensure it's installed and in your PATH."
}
