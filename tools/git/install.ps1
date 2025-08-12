# Centralize the package ID and source for easy changes
$packageId = "Git.Git"
$sourceName = "winget"

# Check if the package is already installed
Write-Host "Checking for existing installation of $packageId..."
winget list --id $packageId --source $sourceName | Out-Null

# Check the exit code of the last command. 0 means success (package found).
if ($LASTEXITCODE -eq 0) {
    Write-Host "$packageId is already installed. Checking for upgrades..."
    winget upgrade --id $packageId --source $sourceName --accept-package-agreements --accept-source-agreements
}
else {
    Write-Host "$packageId not found. Installing now..."
    winget install --id $packageId --source $sourceName --accept-package-agreements --accept-source-agreements
}

Write-Host "Git installation script finished."
