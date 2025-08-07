# =========================================================================
#  PowerShell Setup Script
#  - Enforces a strict installation order:
#    1. Scoop -> 2. Buckets -> 3. Scoop Packages -> 4. Other Apps
# =========================================================================

#region Helper Functions

# This function remains for non-Scoop programs that need a path check.
function Ensure-ProgramInstalled {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$Name,
        [Parameter(Mandatory = $true)]
        [string]$ExePath,
        [Parameter(Mandatory = $true)]
        [scriptblock]$InstallScript
    )

    Write-Host "› Checking for program: " -NoNewline
    Write-Host $Name -ForegroundColor Magenta

    if (Test-Path -Path $ExePath) {
        Write-Host "  ✅ Already installed." -ForegroundColor Green
        return
    }

    Write-Host "  ⏳ Not found. Starting installation..." -ForegroundColor Yellow
    try {
        & $InstallScript
        if (Test-Path -Path $ExePath) {
            Write-Host "  ✔️ Successfully installed to: $ExePath" -ForegroundColor Green
        }
        else {
            $command = Get-Command $Name -ErrorAction SilentlyContinue
            if ($command) {
                 Write-Host "  ✔️ Successfully installed. Found at: $($command.Source)" -ForegroundColor Green
            } else {
                 Write-Host "  ❌ ERROR: Installer ran, but the program is still not at the expected path." -ForegroundColor Red
            }
        }
    }
    catch {
        Write-Host "  ❌ ERROR: An exception occurred during installation." -ForegroundColor Red
        Write-Host "      $($_.Exception.Message)" -ForegroundColor DarkGray
    }
}

function Ensure-ScoopBucket {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$Name
    )
    Write-Host "› Checking for Scoop bucket: " -NoNewline
    Write-Host $Name -ForegroundColor Cyan
    if (scoop bucket list | Select-String -Quiet -Pattern "\b$Name\b") {
        Write-Host "  ✅ Already added." -ForegroundColor Green
        return
    }
    Write-Host "  ⏳ Bucket not found. Adding..." -ForegroundColor Yellow
    try {
        scoop bucket add $Name | Out-Null
        Write-Host "  ✔️ Successfully added bucket '$Name'." -ForegroundColor Green
    }
    catch {
        Write-Host "  ❌ ERROR: Failed to add bucket '$Name'." -ForegroundColor Red
        Write-Host "      $($_.Exception.Message)" -ForegroundColor DarkGray
    }
}

# NEW: Unified function for all Scoop packages (apps and fonts).
function Ensure-ScoopPackage {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$Name
    )
    Write-Host "› Checking for Scoop package: " -NoNewline
    Write-Host $Name -ForegroundColor DarkCyan

    # Use 'scoop list' as the single source of truth for installation status.
    if (scoop list | Select-String -Quiet -Pattern "\b$Name\b") {
        Write-Host "  ✅ Already installed." -ForegroundColor Green
        return
    }

    Write-Host "  ⏳ Not found. Starting installation..." -ForegroundColor Yellow
    try {
        scoop install $Name | Out-Null
        Write-Host "  ✔️ Successfully installed package '$Name'." -ForegroundColor Green
    }
    catch {
        Write-Host "  ❌ ERROR: Failed to install package '$Name'." -ForegroundColor Red
        Write-Host "      $($_.Exception.Message)" -ForegroundColor DarkGray
    }
}

#endregion

# --- Configuration ---
# Define programs in logical groups based on dependencies.

# Group 1: The core package manager
$scoopInstaller = [pscustomobject]@{
    Name          = "Scoop"
    ExePath       = if (Get-Command scoop -ErrorAction SilentlyContinue) { (Get-Command scoop).Source } else { Join-Path $env:USERPROFILE 'scoop\shims\scoop.exe' }
    InstallScript = { Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Force; irm get.scoop.sh | iex }
}

# Group 2: Scoop buckets (dependent on Scoop)
$scoopBuckets = @(
    "main",
    "extras",
    "nerd-fonts",
    "versions"
)

# NEW: Group 3 is now a single, unified list of all Scoop packages.
$scoopPackages = @(
    "CascadiaCode-NF-Mono",
    "fd",
    "FiraCode",
    "git",
    "hack-font",
    "Hasklig",
    "neovim",
    "nuget",
    "win32yank"
)

# Group 4: All other standalone programs
$otherPrograms = @(
    [pscustomobject]@{
        Name          = "Rotz"
        ExePath       = Join-Path $env:USERPROFILE ".rotz\bin\rotz.exe"
        InstallScript = { irm volllly.github.io/rotz/install.ps1 | iex }
    }
)


# --- Main Execution ---
# Process each group in the correct order.

Write-Host "--- 1. Installing Core Package Manager ---" -ForegroundColor Yellow
Ensure-ProgramInstalled -Name $scoopInstaller.Name -ExePath $scoopInstaller.ExePath -InstallScript $scoopInstaller.InstallScript
Write-Host ""

# Only proceed if Scoop is actually installed and available.
if (Get-Command scoop -ErrorAction SilentlyContinue) {
    Write-Host "--- 2. Configuring Scoop Buckets ---" -ForegroundColor Yellow
    foreach ($bucket in $scoopBuckets) {
        Ensure-ScoopBucket -Name $bucket
        Write-Host ""
    }

    # NEW: Step 3 is now a single loop for all Scoop packages.
    Write-Host "--- 3. Installing Scoop Packages (Apps & Fonts) ---" -ForegroundColor Yellow
    foreach ($package in $scoopPackages) {
        Ensure-ScoopPackage -Name $package
        Write-Host ""
    }

} else {
    Write-Host "--- Skipping Scoop-dependent installations because Scoop is not available. ---" -ForegroundColor Yellow
    Write-Host ""
}

Write-Host "--- 4. Installing Other Programs ---" -ForegroundColor Yellow
foreach ($program in $otherPrograms) {
    Ensure-ProgramInstalled -Name $program.Name -ExePath $program.ExePath -InstallScript $program.InstallScript
    Write-Host ""
}

Write-Host "✅ All setup tasks are complete." -ForegroundColor Green
