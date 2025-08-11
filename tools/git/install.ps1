# The parameters for the winget command
$wingetParams = @{
    Id                      = "Git.Git"
    Source                  = "winget"
    Exact                   = $true
    AcceptPackageAgreements = $true
    AcceptSourceAgreements  = $true
}

# Check if the package is already installed by listing it
Write-Host "Checking for existing installation of $($wingetParams.Id)..."
$installedPackage = winget list @wingetParams

# The 'list' command's output includes the package ID if it's found.
# If not found, it prints a "No installed package found..." message.
if ($installedPackage -like "*$($wingetParams.Id)*") {
    Write-Host "$($wingetParams.Id) is already installed. Checking for upgrades..."
    winget upgrade @wingetParams
}
else {
    Write-Host "$($wingetParams.Id) not found. Installing now..."
    winget install @wingetParams
}

Write-Host "Git installation script finished."
