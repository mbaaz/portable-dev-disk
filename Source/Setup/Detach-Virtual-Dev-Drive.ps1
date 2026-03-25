# FILE: Detach-Virtual-Dev-Drive.ps1
# This script is responsible for detaching the virtual DevDrive.


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
Write-Header "DETACH VIRTUAL DEV DRIVE"
Write-Config "DevDrive VHD File Path: ${DevDriveVhdPath}"


# ---------------------------------------------------------------
# This script should be run as administrator, so we will check
# for that before proceeding
# ---------------------------------------------------------------
Assert-RunningAsAdministrator


# ---------------------------------------------------------------
# Ensure VHD file exists before proceeding
# ---------------------------------------------------------------
if (-not (Test-Path $DevDriveVhdPath)) {
    Write-Error "DevDrive VHD file not found. Make sure the path is configured correctly."
    Write-PostError
}


# ---------------------------------------------------------------
# Detach the VHD if it's currently mounted
# ---------------------------------------------------------------
function Test-IsDevDriveMounted($VhdPath) {
    $DiskImage = Get-DiskImage -ImagePath $VhdPath 2>$null
    return $DiskImage -and $DiskImage.Attached
}

if (-not (Test-IsDevDriveMounted $DevDriveVhdPath)) {
    Write-Success "DevDrive VHD is already detached"
} else {
    try {
        Dismount-DiskImage -ImagePath $DevDriveVhdPath -ErrorAction Stop | Out-Null
        Write-Success "DevDrive VHD detached successfully"
    } catch {
        Write-Error "Failed to detach DevDrive VHD: $_"
        Write-PostError
    }
}


# ---------------------------------------------------------------
# ... and Done!
# ---------------------------------------------------------------
Write-EndOfScript