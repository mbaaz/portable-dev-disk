# FILE: Assert-DevDrive-Status.ps1
# This script will make sure the DevDrive is trusted by windows and that anti-virus performance mode is enabled.
# It should be run after mounting the DevDrive with Mount-Virtual-Dev-Drive.ps1.


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
Write-Header "ASSERT DEV DRIVE STATUS"
Write-Config "   DevDrive VHD Path: ${DevDriveVhdPath}"


# ---------------------------------------------------------------
# This script should be run as administrator, so we will check
# for that before proceeding
# ---------------------------------------------------------------
Assert-RunningAsAdministrator


# ---------------------------------------------------------------
# Find the DevDrive Volume GUID
# ---------------------------------------------------------------
$DiskImage = Get-DiskImage -ImagePath $DevDriveVhdPath 2>$null
$Partition = Get-Partition -DiskNumber $DiskImage.Number | Where-Object { $_.Type -ne "Reserved" } | Select-Object -First 1
if (-not $partition) {
    Write-Error "Could not find partition inside mounted DevDrive VHD"
    Write-PostError
}

$DevDriveVolumeID = ($Partition.AccessPaths | Where-Object { $_ -like "\\?\Volume*" } | Select-Object -First 1)
if (-not $DevDriveVolumeID) {
    Write-Error "Could not determine volume GUID of mounted DevDrive VHD"
    Write-PostError
}
Write-Config "DevDrive Volume GUID: ${DevDriveVolumeID}"


# ---------------------------------------------------------------
# Trust the Dev Drive
# ---------------------------------------------------------------
Write-Message "Trusting Dev Drive..."

function Test-IsDevDriveTrusted($VolumeID) {
    $IsTrustedQuery = (fsutil devdrv query $VolumeID 2>&1) | Out-String
    return $IsTrustedQuery -notmatch "not trusted"
}
function Assert-DevDriveIsTrusted($VolumeID) {
    if (-not (Test-IsDevDriveTrusted $VolumeID)) {
        fsutil devdrv trust $VolumeID | Out-Null
        return [bool]($LASTEXITCODE -eq 0)
    }
    return $true
}

if (Test-IsDevDriveTrusted $DevDriveVolumeID) {
    Write-Success "DevDrive is already Trusted on this machine"
} else {
    if (Assert-DevDriveIsTrusted $DevDriveVolumeID) {
        Write-Success "DevDrive is now Trusted on this machine"
    } else {
        Write-Error "Unsuccessful in trusting the Dev Drive"
        Write-PostError
    }
}


# ---------------------------------------------------------------
# Ensure Anti-virus Performance Mode is ON
# ---------------------------------------------------------------
Write-Message "Enabling Windows Defender Performance Mode..."

function Test-IsDefenderPerformanceModeEnabled {
    return ((Get-MpPreference).PerformanceModeStatus | Out-String).Trim() -eq "1"
}
function Enable-DefenderPerformanceMode {
    Set-MpPreference -PerformanceModeStatus Enabled
}

if (Test-IsDefenderPerformanceModeEnabled) {
    Write-Success "Windows Defender Performance Mode is already active"
} else {
    Enable-DefenderPerformanceMode

    if (Test-IsDefenderPerformanceModeEnabled) {
        Write-Success "Windows Defender Performance Mode is now enabled"
    } else {
        Write-Error "Windows Defender Performance Mode could not be enabled"
        Write-PostError
    }
}


# ---------------------------------------------------------------
# ... and Done!
# ---------------------------------------------------------------
Write-EndOfScript