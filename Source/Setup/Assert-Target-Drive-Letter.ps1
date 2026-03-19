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
# Get the volume GUID for the drive
# ---------------------------------------------------------------
if($UseCurrentDrive) {
    Write-Message "Using current drive detection method"
    $ScriptDriveLetter = (Split-Path -Qualifier $PSScriptRoot).TrimEnd(":").ToUpper()
    $VolumeGUID = Get-VolumeGUIDFromDriveLetter $ScriptDriveLetter
} else {
    Write-Message "Using hardcoded volume GUID from config"
    $VolumeGUID = $UseVolumeGUID
}
if (-not $VolumeGUID) {
    Write-Error "`nVolume GUID '${VolumeGUID}' is not available"
    Write-PostError
}
Write-Config "         Volume GUID: ${VolumeGUID}"


# ---------------------------------------------------------------
# Find current Volume
# ---------------------------------------------------------------
$Volume = Get-Volume -UniqueId $VolumeGUID
if (-not $Volume) {
    Write-Error "Could not find Volume"
    Write-PostError
}


# ---------------------------------------------------------------
# Find current Partition
# ---------------------------------------------------------------
$Partition = Get-Partition -Volume $Volume | Where-Object { $_.Type -ne "Reserved" } | Select-Object -First 1
if (-not $Partition) {
    Write-Error "Could not find Partition"
    Write-PostError
}


# ---------------------------------------------------------------
# Perform Drive Letter Assertions
# ---------------------------------------------------------------
if (Assert-DriveLetter -Partition $Partition -TargetLetter $DevDataDriveTargetLetter) {   
    $ScriptRoot = $ScriptRoot.Replace($CurrentLetter + ":", $DevDataDriveTargetLetter + ":")
    Write-Success "Updated ScriptRoot to match new drive letter"
    Write-Config "  > ScriptRoot: ${ScriptRoot}"
}


# ---------------------------------------------------------------
# ... and Done!
# ---------------------------------------------------------------
Write-EndOfScript