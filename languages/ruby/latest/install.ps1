#!/usr/bin/env pwsh

# Re-source the rbenv profile to ensure it's loaded
. $profile

Write-Host "🔎 Finding the latest available Ruby version..."

# Get the list of all stable installable versions and select the last one
# The list is sorted, so the last entry is the newest version.
$latestVersion = rbenv install -l | Select-Object -Last 1

if (-not $latestVersion) {
    Write-Host "❌ Could not determine the latest Ruby version. Please check your rbenv installation."
    return
}

Write-Host "Latest available version is: $latestVersion"

# Check if the latest version is already installed
$installedVersions = rbenv versions --bare
if ($installedVersions -contains $latestVersion) {
    Write-Host "✅ Ruby $latestVersion is already installed."
} else {
    Write-Host "Installing Ruby $latestVersion... (This may take a few minutes) ⏳"
    rbenv install $latestVersion
}

# Set the latest version as the global default
Write-Host "Setting Ruby $latestVersion as the global default..."
rbenv global $latestVersion

# Verify the installation and show current versions
Write-Host "✨ Success! Your global Ruby version is now set."
Write-Host "Current Ruby version:"
ruby -v
Write-Host "All installed rbenv versions (* indicates current):"
rbenv versions
