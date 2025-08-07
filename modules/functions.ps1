# =========================================================================
#  Module: Helper Functions
#  - Contains all reusable functions for the setup script.
# =========================================================================

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
        Write-Host "    $($_.Exception.Message)" -ForegroundColor DarkGray
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
        Write-Host "    $($_.Exception.Message)" -ForegroundColor DarkGray
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
        Write-Host "    $($_.Exception.Message)" -ForegroundColor DarkGray
    }
}

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
        Write-Host "    $($_.Exception.Message)" -ForegroundColor DarkGray
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
        Write-Host "    $($_.Exception.Message)" -ForegroundColor DarkGray
    }}
