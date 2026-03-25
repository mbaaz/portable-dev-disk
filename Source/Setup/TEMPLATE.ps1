# FILE: *****FILENAME*****.ps1
# *****DESCRIPTION*****
Push-Location


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
# Write welcome message and relevant configuration
# ---------------------------------------------------------------
Write-Header "*****WELCOME*****"
Write-Config "***** RELEVANT CONFIG: ${ScriptRoot}*****"


# ---------------------------------------------------------------
# This script should be run as administrator, so we will check
# for that before proceeding
# ---------------------------------------------------------------
Assert-RunningAsAdministrator


# ---------------------------------------------------------------
# DO YOUR THING HERE
# ---------------------------------------------------------------



# ---------------------------------------------------------------
# ... and Done!
# ---------------------------------------------------------------
Pop-Location
Write-EndOfScript