# =========================================================================
#  Unified PowerShell Setup Script
#  - Installs packages from Scoop and Winget in a specific order.
# =========================================================================

#region Helper Functions

# --- Scoop Helpers ---

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

function Ensure-ScoopPackage {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$Name
    )
    Write-Host "› Checking for Scoop package: " -NoNewline
    Write-Host $Name -ForegroundColor DarkCyan

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

# --- Winget Helpers ---

function Ensure-WingetPackageInstalled {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Id
    )

    Write-Host "› Checking for Winget package: " -NoNewline
    Write-Host $Id -ForegroundColor Magenta

    if (winget list --id $Id --accept-source-agreements | Select-String -Quiet -Pattern $Id) {
        Write-Host "  ✅ Already installed." -ForegroundColor Green
        return
    }

    Write-Host "  ⏳ Not found. Starting installation..." -ForegroundColor Yellow
    try {
        winget install --id $Id --silent --accept-package-agreements --accept-source-agreements | Out-Null
        Write-Host "  ✔️ Successfully installed '$Id'." -ForegroundColor Green
    }
    catch {
        Write-Host "  ❌ ERROR: Failed to install '$Id'." -ForegroundColor Red
        Write-Host "      $($_.Exception.Message)" -ForegroundColor DarkGray
    }
}

function Ensure-WingetPackageUninstalled {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Id
    )

    Write-Host "› Checking to uninstall Winget package: " -NoNewline
    Write-Host $Id -ForegroundColor Cyan

    if (-not (winget list --id $Id --accept-source-agreements | Select-String -Quiet -Pattern $Id)) {
        Write-Host "  ✅ Already uninstalled or not present." -ForegroundColor Green
        return
    }

    Write-Host "  ⏳ Package found. Starting uninstallation..." -ForegroundColor Yellow
    try {
        winget uninstall --id $Id --silent --accept-source-agreements | Out-Null
        Write-Host "  ✔️ Successfully uninstalled '$Id'." -ForegroundColor Green
    }
    catch {
        Write-Host "  ❌ ERROR: Failed to uninstall '$Id'." -ForegroundColor Red
        Write-Host "      $($_.Exception.Message)" -ForegroundColor DarkGray
    }
}

#endregion

# --- Configuration ---

# Group 1: The core package manager
$scoopInstaller = [pscustomobject]@{
    Name          = "Scoop"
    ExePath       = if (Get-Command scoop -ErrorAction SilentlyContinue) { (Get-Command scoop).Source } else { Join-Path $env:USERPROFILE 'scoop\shims\scoop.exe' }
    InstallScript = { Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Force; irm get.scoop.sh | iex }
}

# Group 2: Scoop buckets
$scoopBuckets = @(
    "main",
    "extras",
    "nerd-fonts",
    "versions"
)

# Group 3: All Scoop packages (apps & fonts)
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

# Group 5: Winget packages to INSTALL
$wingetPackagesToInstall = @(
    "7zip.7zip",
    "AgileBits.1Password",
    "AgileBits.1Password.CLI",
    "Docker.DockerDesktop",
    "Google.Chrome",
    "Google.GoogleDrive",
    "Logitech.GHub",
    "Meld.Meld",
    "RevoUninstaller.RevoUninstaller",
    "SourceFoundry.HackFonts",
    "wez.wezterm",
    "Zoom.Zoom"
)

# Group 6: Winget packages to UNINSTALL
$wingetPackagesToUninstall = @(
    "Microsoft.OneDrive",
    "Microsoft.Edge"
)

# --- Main Execution ---

# Process Scoop installations first
Write-Host "--- 1. Installing Core Package Manager ---" -ForegroundColor Yellow
Ensure-ProgramInstalled -Name $scoopInstaller.Name -ExePath $scoopInstaller.ExePath -InstallScript $scoopInstaller.InstallScript
Write-Host ""

if (Get-Command scoop -ErrorAction SilentlyContinue) {
    Write-Host "--- 2. Configuring Scoop Buckets ---" -ForegroundColor Yellow
    foreach ($bucket in $scoopBuckets) {
        Ensure-ScoopBucket -Name $bucket
        Write-Host ""
    }

    Write-Host "--- 3. Installing Scoop Packages (Apps & Fonts) ---" -ForegroundColor Yellow
    foreach ($package in $scoopPackages) {
        Ensure-ScoopPackage -Name $package
        Write-Host ""
    }
} else {
    Write-Host "--- Skipping Scoop-dependent installations because Scoop is not available. ---" -ForegroundColor Yellow
    Write-Host ""
}

# Process other standalone programs
Write-Host "--- 4. Installing Other Programs ---" -ForegroundColor Yellow
foreach ($program in $otherPrograms) {
    Ensure-ProgramInstalled -Name $program.Name -ExePath $program.ExePath -InstallScript $program.InstallScript
    Write-Host ""
}

# Process Winget installations and un-installations
Write-Host "--- 5. Managing Winget Packages ---" -ForegroundColor Yellow
if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    Write-Host "  ❌ Winget command not found. Skipping this section." -ForegroundColor Red
} else {
    Write-Host ""
    Write-Host "--- 5a. Installing Required Winget Packages ---" -ForegroundColor DarkYellow
    foreach ($packageId in $wingetPackagesToInstall) {
        Ensure-WingetPackageInstalled -Id $packageId
        Write-Host ""
    }

    Write-Host "--- 5b. Uninstalling Unwanted Winget Packages ---" -ForegroundColor DarkYellow
    foreach ($packageId in $wingetPackagesToUninstall) {
        Ensure-WingetPackageUninstalled -Id $packageId
        Write-Host ""
    }
}

Write-Host "✅ All setup tasks are complete." -ForegroundColor Green
