#!/usr/bin/env pwsh
#
# PowerShell Profile Setup Script
#
# This script configures the PowerShell environment by setting repository policies,
# installing common modules, and creating a profile directory structure.
# It includes checks to prevent re-installing existing modules or re-creating
# existing directories.
#

# --- Initial Setup ---
Write-Host "INFO: Starting PowerShell environment setup..."

# Trust the official PowerShell Gallery to allow module installation
try {
    Set-PSRepository -Name 'PSGallery' -InstallationPolicy 'Trusted'
    Write-Host "SUCCESS: PSGallery repository is set to 'Trusted'."
}
catch {
    Write-Warning "ALERT: Failed to set PSGallery installation policy. This might cause issues with module installation."
    # Exit if we can't trust the gallery, as installations will likely fail.
    exit 1
}


# --- OS-Specific Configuration ---
if ($IsLinux) {
    Write-Host "INFO: Performing Linux-specific PowerShell setup."
    # Add any Linux-specific commands here in the future
}
elseif ($IsMacOS) {
    Write-Host "INFO: Performing macOS-specific PowerShell setup."
    # Add any macOS-specific commands here in the future
}
elseif ($IsWindows) {
    Write-Host "INFO: Performing Windows-specific PowerShell setup."
    try {
        # Set execution policy to allow local scripts and signed remote scripts to run.
        Set-ExecutionPolicy -Name 'RemoteSigned' -Scope 'CurrentUser' -Force
        Write-Host "SUCCESS: Execution policy set to 'RemoteSigned' for the current user."
    }
    catch {
        Write-Warning "ALERT: Failed to set execution policy."
    }
}


# --- Module Installation ---
# Define a list of essential modules to ensure are installed.
$modulesToInstall = @(
    'PSReadline',
    'Sudo'
)

Write-Host "INFO: Checking and installing required modules..."

foreach ($moduleName in $modulesToInstall) {
    # Check if the module is already available on the system
    if (Get-Module -ListAvailable -Name $moduleName) {
        Write-Host "INFO: Module '$moduleName' is already installed. Skipping."
    }
    else {
        Write-Host "INFO: Module '$moduleName' not found. Attempting to install..."
        try {
            # Install the module for the current user only
            Install-Module -Name $moduleName -Scope 'CurrentUser' -Force -ErrorAction 'Stop'
            Write-Host "SUCCESS: Module '$moduleName' installed successfully."
        }
        catch {
            Write-Warning "ALERT: Failed to install module '$moduleName'. Please try installing it manually."
        }
    }
}


# --- Profile Directory Creation ---
# Define the path for custom profile scripts.
$profileDir = Join-Path -Path $HOME -ChildPath '.config/powershell/profile.d'

Write-Host "INFO: Checking for profile directory at '$profileDir'..."

# Check if the directory already exists
if (-not (Test-Path -Path $profileDir)) {
    Write-Host "INFO: Directory not found. Creating it now..."
    try {
        # Create the directory recursively if needed.
        New-Item -ItemType 'Directory' -Path $profileDir -Force -ErrorAction 'Stop' | Out-Null
        Write-Host "SUCCESS: Profile directory created."
    }
    catch {
        Write-Warning "ALERT: Failed to create profile directory at '$profileDir'."
    }
}
else {
    Write-Host "INFO: Profile directory already exists. Skipping."
}

Write-Host "INFO: PowerShell setup script finished."
