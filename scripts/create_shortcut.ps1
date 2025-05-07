<#
.SYNOPSIS
    Creates or removes an autostart shortcut for sync_all.ps1 that runs in the background.

.DESCRIPTION
    This script creates a shortcut in the autostart folder (user or global) to run sync_all.ps1 without a visible console window. Features:
    - Validates paths and autostart folder
    - Checks admin privileges for global autostart
    - Supports removing existing shortcuts
    - Verifies PowerShell ExecutionPolicy (requires RemoteSigned)
    - Provides detailed error handling and user guidance
    - Compatible with Windows; skips on non-Windows systems with a warning

.PARAMETER ScriptPath
    Path to the sync_all.ps1 script. Defaults to scripts/sync_all.ps1 in the repository.

.PARAMETER StartupFolder
    Path to the autostart folder. Defaults to the current user's Startup folder.

.PARAMETER Remove
    Removes the existing shortcut if specified.

.PARAMETER Global
    Creates the shortcut in the global autostart folder (requires admin privileges).

.EXAMPLE
    PS> .\create_shortcut.ps1
    Creates a shortcut in the current user's autostart folder.

.EXAMPLE
    PS> .\create_shortcut.ps1 -Global
    Creates a shortcut in the global autostart folder (requires admin privileges).

.EXAMPLE
    PS> .\create_shortcut.ps1 -Remove
    Removes the existing shortcut.

.NOTES
    Version: 1.0.0
    File: scripts/create_shortcut.ps1
    ExecutionPolicy: Requires RemoteSigned
    Repository: https://github.com/<your-username>/rclone-sync
    Run as Administrator for global autostart.
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory = $false)]
    [ValidateScript({ Test-Path $_ -PathType Leaf })]
    [string]$ScriptPath = (Join-Path $PSScriptRoot "sync_all.ps1"),

    [Parameter(Mandatory = $false)]
    [string]$StartupFolder = [Environment]::GetFolderPath("Startup"),

    [Parameter(Mandatory = $false)]
    [switch]$Remove,

    [Parameter(Mandatory = $false)]
    [switch]$Global
)

# Script version
$ScriptVersion = "1.0.0"

# region Functions

function Test-PathSafety {
    <#
    .SYNOPSIS
        Validates a file or directory path for safety and existence.
    .PARAMETER Path
        The path to validate.
    .OUTPUTS
        Boolean indicating if the path is safe and exists.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$Path
    )
    if ($Path -match '[<>|&]') {
        Throw "Invalid characters in path: ${Path}"
    }
    return Test-Path $Path -ErrorAction Stop
}

function Test-ExecutionPolicy {
    <#
    .SYNOPSIS
        Verifies that the PowerShell ExecutionPolicy allows script execution.
    .OUTPUTS
        Boolean indicating if the policy is sufficient.
    #>
    [CmdletBinding()]
    param ()
    $policy = Get-ExecutionPolicy -Scope CurrentUser -ErrorAction SilentlyContinue
    if ($policy -eq "Restricted" -or $policy -eq "AllSigned") {
        Write-Warning "Current ExecutionPolicy ($policy) does not allow script execution. Run 'Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned -Force' to fix."
        return $false
    }
    return $true
}

# endregion

# region Initialization

# Check for non-Windows systems
if ($PSVersionTable.PSVersion.Platform -ne "Win32NT") {
    Write-Warning "This script is designed for Windows. Autostart shortcuts are not supported on $($PSVersionTable.PSVersion.Platform)."
    exit 0
}

# Verify ExecutionPolicy
if (-not (Test-ExecutionPolicy)) {
    Write-Error "Cannot proceed due to restrictive ExecutionPolicy."
    exit 1
}

# Adjust startup folder for global autostart
if ($Global) {
    $StartupFolder = "C:\ProgramData\Microsoft\Windows\Start Menu\Programs\StartUp"
    $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if (-not $isAdmin) {
        Write-Error "Administrative privileges required for global autostart: ${StartupFolder}. Run as Administrator."
        exit 1
    }
}

# Validate paths
if (-not (Test-PathSafety $ScriptPath)) {
    Write-Error "Script path not found: ${ScriptPath}. Ensure sync_all.ps1 exists."
    exit 1
}
if (-not (Test-PathSafety $StartupFolder)) {
    Write-Error "Startup folder not found: ${StartupFolder}. Check system configuration."
    exit 1
}

# Shortcut details
$shortcutName = "RcloneSync.lnk"
$shortcutPath = Join-Path $StartupFolder $shortcutName

# endregion

# region Shortcut Management

if ($Remove) {
    if (Test-Path $shortcutPath) {
        Remove-Item $shortcutPath -Force -ErrorAction Stop
        Write-Host "Shortcut removed: ${shortcutPath}"
    } else {
        Write-Warning "Shortcut not found: ${shortcutPath}"
    }
    exit 0
}

# Check for existing shortcut
if (Test-Path $shortcutPath) {
    Write-Warning "Shortcut already exists: ${shortcutPath}. Overwriting."
}

# Create shortcut
try {
    $shell = New-Object -ComObject WScript.Shell -ErrorAction Stop
    $shortcut = $shell.CreateShortcut($shortcutPath)
    $shortcut.TargetPath = "powershell.exe"
    $shortcut.Arguments = "-WindowStyle Hidden -File `"$ScriptPath`""
    $shortcut.WorkingDirectory = Split-Path $ScriptPath -Parent
    $shortcut.Description = "Runs Rclone sync in the background"
    $shortcut.Save()
    Write-Host "Shortcut created: ${shortcutPath}"
    Write-Host "Command: powershell.exe -WindowStyle Hidden -File `"${ScriptPath}`""
} catch {
    Write-Error "Failed to create shortcut: $_. Check permissions and try again."
    exit 1
}

# endregion