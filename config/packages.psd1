# =========================================================================
#  Configuration: Package Definitions
#  - Contains only static data (strings, arrays, hashtables).
# =========================================================================
@{
    # NOTE: The main Scoop Installer object was moved to setup.ps1 due to its dynamic logic.

    # Group 2: Scoop buckets
    ScoopBuckets = @(
        "main",
        "extras",
        "nerd-fonts",
        "versions"
    )

    # Group 3: All Scoop packages (apps & fonts)
    ScoopPackages = @(
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
    OtherPrograms = @(
        @{
            Name              = "Rotz"
            # Use a simple string for the path, to be combined later
            RelativeExePath   = ".rotz\bin\rotz.exe"
            # Store the installation command as a string, not a script block
            InstallScriptString = "irm volllly.github.io/rotz/install.ps1 | iex"
        }
    )

    # Group 5: Winget packages to INSTALL
    WingetPackagesToInstall = @(
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
    WingetPackagesToUninstall = @(
        "Microsoft.OneDrive"
    )
}