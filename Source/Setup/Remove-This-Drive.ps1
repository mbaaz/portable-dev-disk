# FILE: Eject-This-Drive.ps1
# This is the main script to eject this drive from your computer.
# It will unmount the virtual drive and do some cleanup if necessary.


# ---------------------------------------------------------------
# Include configuration and common functions
# ---------------------------------------------------------------
function Get-FilePath($filePath) {
    if ([string]::IsNullOrEmpty($ScriptRoot)) { $ScriptRoot = $PSScriptRoot }
    $path = Join-Path $ScriptRoot $filePath.Replace(".\", "")
    if(-not (Test-Path $path)) { Write-Error "File not found"; Read-Host "`nPress Enter to close"; exit 1; }
    return $path
}
. (Get-FilePath ".\config.ps1")
. (Get-FilePath ".\functions.ps1")


# ---------------------------------------------------------------
# This script should be run as administrator, so we will check
# for that before proceeding
# ---------------------------------------------------------------
Assert-RunningAsAdministrator


# ---------------------------------------------------------------
# Write welcome message and some info about the configuration
# ---------------------------------------------------------------
Write-Header "REMOVE THIS DRIVE"
Write-Message "This will remove this drive from your computer"
Write-Config "     ScriptRoot: ${ScriptRoot}"
Write-Host "`n"


# ---------------------------------------------------------------
# Run through the main eject steps
# ---------------------------------------------------------------
. (Assert-FileExists ".\Assert-DevEnv-IsShutDown.ps1")
. (Assert-FileExists ".\Backup-Sourcetree-Settings.ps1")
. (Assert-FileExists ".\Eject-Drive.ps1")


# ---------------------------------------------------------------
# ... and Done!
# ---------------------------------------------------------------
if($DEBUG -eq $true) {
    Read-Host "Press Enter to close"
}