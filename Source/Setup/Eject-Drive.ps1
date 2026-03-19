# FILE: Eject-Drive.ps1
# This script is responsible for safely ejecting the drive from windows.


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
# Script specific configuration
# ---------------------------------------------------------------
$HandlePath = "$env:TEMP\handle.exe"


# ---------------------------------------------------------------
# Write welcome message and relevant configuration
# ---------------------------------------------------------------
Write-Header "EJECT DRIVE"
Write-Config "Current Drive Letter: ${CurrentLetter}"
Write-Config "     Handle.exe Path: ${HandlePath}"


# ---------------------------------------------------------------
# This script should be run as administrator, so we will check
# for that before proceeding
# ---------------------------------------------------------------
Assert-RunningAsAdministrator


# ---------------------------------------------------------------
# Kill COM Surrogate processes (dllhost.exe) to prevent
# "The device is in use" errors when ejecting the drive.
# ---------------------------------------------------------------
$dllhosts = Get-Process -Name dllhost -ErrorAction SilentlyContinue
if ($dllhosts) {
    $dllhosts | Stop-Process -Force
    Write-Success "Killed $($dllhosts.Count) dllhost.exe instance(s)"
    Start-Sleep -Milliseconds 1500
} else {
    Write-Message "No dllhost.exe processes found"
}


# ---------------------------------------------------------------
# Temporarily stop the Windows Search indexer to prevent it from
# accessing the drive while we are trying to eject it.
# ---------------------------------------------------------------
$SearchServiceRunning = ((Get-Service -Name WSearch).Status | Out-String).Trim() -eq "Running";
if ($SearchServiceRunning) {
    Stop-Service -Name WSearch -Force -ErrorAction SilentlyContinue
    Write-Message "Windows Search indexer stopped"
}


# ---------------------------------------------------------------
# Temporarily disable Windows Defender real-time monitoring to 
# prevent it from accessing the drive while we are trying to
# eject it.
# ---------------------------------------------------------------
$RealTimeMonitoringDisabled = ((Get-MpPreference).DisableRealTimeMonitoring | Out-String).Trim() -eq "True";
if (-not $RealTimeMonitoringDisabled) {
    Set-MpPreference -DisableRealTimeMonitoring $true -ErrorAction SilentlyContinue
    Write-Message "Windows Defender real-time monitoring disabled"
}


# ---------------------------------------------------------------
# Wait a moment to ensure all above processes have fully stopped
# and released any locks
# ---------------------------------------------------------------
Start-Sleep -Milliseconds 1500


# ---------------------------------------------------------------
# Cycle the drive offline and online to help release any remain-
# ing locks. After this, the drive should be safe to remove.
# ---------------------------------------------------------------
$DriveDiskNumber = ((("select volume ${CurrentLetter}:", "detail volume" | diskpart) | Out-String) -Split "`r`n" | Select-String -Pattern "(?<=Disk )\d+").matches[0].Value

# Offline the entire disk to ensure all volumes on the disk are released
"select disk ${DriveDiskNumber}", "offline disk" | diskpart | Out-Null
Start-Sleep -Milliseconds 1500

# Online the disk again so it shows up as "Safe to Remove" in Windows Explorer
"select disk ${DriveDiskNumber}", "online disk" | diskpart | Out-Null
Start-Sleep -Milliseconds 1500


Read-Host "Drive should now be safe to remove. Press Enter to continue.."

# ---------------------------------------------------------------
# Re-enable Windows Defender real-time monitoring if it was
# disabled before
# ---------------------------------------------------------------
if (-not $RealTimeMonitoringDisabled) {
    Set-MpPreference -DisableRealTimeMonitoring $false -ErrorAction SilentlyContinue
    Write-Message "Windows Defender real-time monitoring re-enabled"
}


# ---------------------------------------------------------------
# Re-start Search Indexer service if it was running before
# ---------------------------------------------------------------
if( $SearchServiceRunning ) {
    Start-Service -Name WSearch -ErrorAction SilentlyContinue
    Write-Message "Windows Search indexer re-started"
}


# ---------------------------------------------------------------
# ... and Done!
# ---------------------------------------------------------------
Write-Message "Drive is now safe to remove. You can eject it from Windows Explorer or physically unplug it from your computer."
Write-EndOfScript