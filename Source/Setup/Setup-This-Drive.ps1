# FILE: Setup-This-Drive.ps1
# This is the main script to setup this drive on your computer - new or otherwise.


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
Write-Header "SETUP THIS DRIVE"
Write-Message "This will `"install`" this drive on your computer - new or otherwise.`nA lot of conventions and configurations will be set up to make this drive work as intended."
Write-Config "     ScriptRoot: ${ScriptRoot}"
Write-Host "`n"


# ---------------------------------------------------------------
# Run through the main setup steps
# ---------------------------------------------------------------
. (Assert-FileExists ".\Assert-Target-Drive-Letter.ps1")
. (Assert-FileExists ".\Assert-DevDrive-Status.ps1")
. (Assert-FileExists ".\Shutdown-Wsl.ps1")
. (Assert-FileExists ".\Move-GitConfig-File.ps1")
. (Assert-FileExists ".\Restore-Sourcetree-Settings.ps1")


# ---------------------------------------------------------------
# ... and Done!
# ---------------------------------------------------------------
if($DEBUG -eq $true) {
    Read-Host "Press Enter to close"
}