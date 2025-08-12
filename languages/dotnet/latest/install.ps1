# https://learn.microsoft.com/en-us/dotnet/core/install/windows#install-with-windows-package-manager-winget
#
# Centralize package IDs and source for easy changes
$packageIds = @(
    "Microsoft.DotNet.AspNetCore.9",
    "Microsoft.DotNet.SDK.9",
    "Microsoft.DotNet.AspNetCore.8",
    "Microsoft.DotNet.SDK.8"
)
$sourceName = "winget"

# Loop through each package ID
foreach ($packageId in $packageIds) {
    Write-Host "Processing package: $packageId"

    # Check if the package is already installed
    Write-Host "Checking for existing installation..."
    winget list --id $packageId --source $sourceName --accept-source-agreements | Out-Null

    # Check the exit code of the last command. 0 means the package was found.
    if ($LASTEXITCODE -eq 0) {
        Write-Host "$packageId is already installed. Checking for an upgrade..."
        winget upgrade --id $packageId --source $sourceName --accept-package-agreements --accept-source-agreements
    }
    else {
        Write-Host "$packageId not found. Installing now..."
        winget install --id $packageId --source $sourceName --accept-package-agreements --accept-source-agreements
    }
    Write-Host "`n" # Add a newline for better readability
}

Write-Host "Finished processing all .NET packages."
