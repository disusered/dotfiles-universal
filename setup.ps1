# =========================================================================
#  Unified PowerShell Setup Script (Orchestrator)
# =========================================================================

# --- Initialization ---
$scriptRoot = $PSScriptRoot
$configFile = "$scriptRoot\config\packages.psd1"
$functionsFile = "$scriptRoot\modules\functions.ps1"

# 1. Check if the functions file exists
if (-not (Test-Path $functionsFile)) {
    Write-Host "❌ ERROR: Functions file not found at '$functionsFile'." -ForegroundColor Red
    return # Stop execution
}

# Load helper functions using dot-sourcing
. $functionsFile

# 2. VERIFY that a key function was actually loaded
if (-not (Get-Command "Ensure-ScoopBucket" -ErrorAction SilentlyContinue)) {
    Write-Host "❌ ERROR: Failed to load functions from '$functionsFile'." -ForegroundColor Red
    Write-Host "Please check that the file is not empty and has the correct function definitions." -ForegroundColor Yellow
    return # Stop execution
}

# 3. Check if the configuration file exists
if (-not (Test-Path $configFile)) {
    Write-Host "❌ ERROR: Configuration file not found at '$configFile'." -ForegroundColor Red
    return # Stop execution
}

# Load all package lists from the configuration file
$config = Import-PowerShellDataFile -Path $configFile

# 4. VERIFY that the configuration was loaded successfully
if (-not $config) {
    Write-Host "❌ ERROR: Failed to load configuration from '$configFile'." -ForegroundColor Red
    Write-Host "Please check the file for syntax errors or ensure it is not empty." -ForegroundColor Yellow
    return # Stop execution
}

# --- Main Execution ---
Write-Host "✅ Configuration and functions loaded successfully. Starting setup..." -ForegroundColor Green
Write-Host ""

# Process Scoop installations first
Write-Host "--- 1. Installing Core Package Manager ---" -ForegroundColor Yellow
# Define the Scoop installer object here because its path logic is dynamic.
$scoopInstaller = [pscustomobject]@{
    Name          = "Scoop"
    ExePath       = if (Get-Command scoop -ErrorAction SilentlyContinue) { (Get-Command scoop).Source } else { Join-Path $env:USERPROFILE 'scoop\shims\scoop.exe' }
    InstallScript = { Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Force; irm get.scoop.sh | iex }
}
Ensure-ProgramInstalled -Name $scoopInstaller.Name -ExePath $scoopInstaller.ExePath -InstallScript $scoopInstaller.InstallScript
Write-Host ""

if (Get-Command scoop -ErrorAction SilentlyContinue) {
    Write-Host "--- 2. Configuring Scoop Buckets ---" -ForegroundColor Yellow
    foreach ($bucket in $config.ScoopBuckets) {
        Ensure-ScoopBucket -Name $bucket
        Write-Host ""
    }

    Write-Host "--- 3. Installing Scoop Packages (Apps & Fonts) ---" -ForegroundColor Yellow
    foreach ($package in $config.ScoopPackages) {
        Ensure-ScoopPackage -Name $package
        Write-Host ""
    }
} else {
    Write-Host "--- Skipping Scoop-dependent installations because Scoop is not available. ---" -ForegroundColor Yellow
    Write-Host ""
}

# Process other standalone programs
Write-Host "--- 4. Installing Other Programs ---" -ForegroundColor Yellow
foreach ($program in $config.OtherPrograms) {
    # Rebuild the dynamic parts from the static data in the config file
    $fullExePath = Join-Path $env:USERPROFILE $program.RelativeExePath
    $installBlock = [ScriptBlock]::Create($program.InstallScriptString)

    Ensure-ProgramInstalled -Name $program.Name -ExePath $fullExePath -InstallScript $installBlock
    Write-Host ""
}

# Process Winget installations and un-installations
Write-Host "--- 5. Managing Winget Packages ---" -ForegroundColor Yellow
if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    Write-Host "  ❌ Winget command not found. Skipping this section." -ForegroundColor Red
} else {
    Write-Host ""
    Write-Host "--- 5a. Installing Required Winget Packages ---" -ForegroundColor DarkYellow
    foreach ($packageId in $config.WingetPackagesToInstall) {
        Ensure-WingetPackageInstalled -Id $packageId
        Write-Host ""
    }

    Write-Host "--- 5b. Uninstalling Unwanted Winget Packages ---" -ForegroundColor DarkYellow
    foreach ($packageId in $config.WingetPackagesToUninstall) {
        Ensure-WingetPackageUninstalled -Id $packageId
        Write-Host ""
    }
}

Write-Host "✅ All setup tasks are complete." -ForegroundColor Green
Write-Host "🎯  Next Steps: Remember to run Rotz to install configs and any other manual commands." -ForegroundColor Cyan
