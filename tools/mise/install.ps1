#
# Description:
# This script checks for the existence of the mise activation script for PowerShell.
# If the script does not exist, it runs 'mise activate pwsh' and saves the
# output to the correct location (~/.config/powershell/profile.d/mise.ps1).
# This ensures that mise is correctly loaded into your PowerShell sessions
# without duplicating the setup on subsequent runs.
#

# Define the full path for the mise profile script.
# Using Join-Path is a robust way to construct file paths.
$profileDir = Join-Path -Path $HOME -ChildPath ".config\powershell\profile.d"
$miseProfilePath = Join-Path -Path $profileDir -ChildPath "mise.ps1"

# Check if the mise profile script already exists.
if (-not (Test-Path -Path $miseProfilePath)) {
    Write-Host "Mise profile script not found. Proceeding with setup..." -ForegroundColor Yellow

    # Ensure the destination directory exists.
    # The -Force parameter prevents an error if the directory already exists.
    if (-not (Test-Path -Path $profileDir)) {
        Write-Host "Creating directory: $profileDir"
        New-Item -ItemType Directory -Path $profileDir -Force | Out-Null
    }

    # Run 'mise activate pwsh' and save its output to the profile script file.
    # A try/catch block is used to handle potential errors, for example, if 'mise'
    # is not installed or not available in the system's PATH.
    try {
        Write-Host "Running 'mise activate pwsh' and saving to $miseProfilePath"
        # The command 'mise activate pwsh' generates the necessary script content.
        # We pipe that output directly into the Out-File cmdlet.
        mise activate pwsh | Out-File -FilePath $miseProfilePath -Encoding utf8
        Write-Host "Setup complete! Mise activation script created successfully." -ForegroundColor Green
        Write-Host "Please restart your PowerShell session for the changes to take effect."
    } catch {
        Write-Error "An error occurred while running 'mise activate pwsh'."
        Write-Error "Please ensure that 'mise' is installed and accessible in your PATH."
        # The $_ variable contains the specific error record.
        Write-Error $_
    }
} else {
    # If the file already exists, inform the user and do nothing.
    Write-Host "Mise activation script already exists at '$miseProfilePath'." -ForegroundColor Cyan
    Write-Host "No action is needed." -ForegroundColor Cyan
}
