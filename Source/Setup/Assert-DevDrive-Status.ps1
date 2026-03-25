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


# ---------------------------------------------------------------
# This script should be run as administrator, so we will check
# for that before proceeding
# ---------------------------------------------------------------
Assert-RunningAsAdministrator


# ---------------------------------------------------------------
# Trusting Dev Drive(s)
# ---------------------------------------------------------------
Write-Message "Trusting Dev Drive..."

function Test-IsDevDriveTrusted($VolumeGUID) {
    $IsTrustedQuery = (fsutil devdrv query $VolumeGUID 2>&1) | Out-String
    return $IsTrustedQuery -notmatch "not trusted"
}
function Assert-DevDriveIsTrusted($VolumeGUID) {
    if (-not (Test-IsDevDriveTrusted $VolumeGUID)) {
        fsutil devdrv trust $VolumeGUID | Out-Null
        return [bool]($LASTEXITCODE -eq 0)
    }
    return $true
}

$Drives | Where-Object { $_.IsDevDrive } | ForEach-Object {
    if (Test-IsDevDriveTrusted $_.VolumeGUID) {
        Write-Success "DevDrive is already Trusted on this machine"
    } else {
        if (Assert-DevDriveIsTrusted $_.VolumeGUID) {
            Write-Success "DevDrive is now Trusted on this machine"
        } else {
            Write-Error "Unsuccessful in trusting the Dev Drive"
            Write-PostError
        }
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