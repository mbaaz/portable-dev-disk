# FILE: Assert-Target-Drive-Letter.ps1
# This script checks if the target drive letter is assigned to the correct volume,
# and if not, it reassigns the drive letter to the target drive letter.


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
Write-Header "ASSERT TARGET DRIVE LETTER"


# ---------------------------------------------------------------
# This script should be run as administrator, so we will check
# for that before proceeding
# ---------------------------------------------------------------
Assert-RunningAsAdministrator


# ---------------------------------------------------------------
# Perform Drive Letter Assertions
# ---------------------------------------------------------------
$Drives | ForEach-Object {
    if(Assert-DriveLetter -VolumeID $_.VolumeGUID -TargetLetter $_.TargetLetter) {
        if($_.IsScriptRootDrive) {
            $ScriptRoot = $ScriptRoot.Replace($CurrentLetter + ":", $_.TargetLetter + ":")
    
            Write-Success "`nUpdated ScriptRoot to match new drive letter"
            Write-Config "  > ScriptRoot: ${ScriptRoot}"
        }
    }
    Write-Host ""
}


# ---------------------------------------------------------------
# ... and Done!
# ---------------------------------------------------------------
Write-EndOfScript