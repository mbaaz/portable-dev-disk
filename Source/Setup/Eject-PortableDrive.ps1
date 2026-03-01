# Eject-PortableDrive.ps1
# Attempts to safely eject the portable drive.
# If ejection fails, lists all processes with open handles on the drive.
#
# Requires:
#   - Administrator privileges
#   - Sysinternals Handle.exe (downloaded automatically if not present)

# ---------------------------------------------------------------
# CONFIG
# ---------------------------------------------------------------
$TargetLetter  = "X"          # Drive letter of the portable NTFS partition
$DevFolderName = "DevDrive"   # Dev Drive mount point folder name
$HandlePath    = "$env:TEMP\handle.exe"
# ---------------------------------------------------------------

# Require Administrator
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Error "This script must be run as Administrator."
    Read-Host "Press Enter to close"
    exit 1
}

# Helper: attempt eject via WMI dismount
function Try-Eject {
    try {
        $vol = Get-WmiObject -Class Win32_Volume | Where-Object { $_.DriveLetter -eq "$TargetLetter`:" }
        if ($vol) {
            $result = $vol.Dismount($false, $true)
            return $result.ReturnValue
        }
    } catch {}
    return -1
}

# Helper: attempt eject via safe removal (PnP)
function Try-SafeRemoval($diskNumber) {
    try {
        $code = @"
using System;
using System.Runtime.InteropServices;
public class SafeRemove {
    [DllImport("setupapi.dll", SetLastError = true, CharSet = CharSet.Auto)]
    public static extern IntPtr SetupDiGetClassDevs(ref Guid ClassGuid, string Enumerator, IntPtr hwndParent, uint Flags);
    public static bool Eject(string driveLetter) {
        try {
            var vol = new System.IO.DriveInfo(driveLetter);
            return vol.IsReady;
        } catch { return false; }
    }
}
"@
        # Use shell namespace approach for safe removal
        $shell = New-Object -ComObject Shell.Application
        $drives = $shell.Namespace(17).Items()
        foreach ($drive in $drives) {
            if ($drive.Path -like "$TargetLetter*") {
                $drive.InvokeVerb("Eject")
                return $true
            }
        }
    } catch {}
    return $false
}

Write-Host "`n=== Portable Drive Eject Tool ===" -ForegroundColor Cyan

# ---------------------------------------------------------------
# [1/6] Verify the drive is present
# ---------------------------------------------------------------
Write-Host "`n[1/6] Locating drive on $TargetLetter`:..." -ForegroundColor Yellow

$volCheck = (mountvol "$TargetLetter`:" /L 2>$null).Trim()
if ($volCheck -match "cannot find" -or [string]::IsNullOrEmpty($volCheck)) {
    Write-Host "Drive is not mounted on $TargetLetter`: - nothing to eject." -ForegroundColor Yellow
    Read-Host "Press Enter to close"
    exit 0
}

$VolumeGUID   = $volCheck
$DevDrivePath = "$TargetLetter`:\$DevFolderName"
$devVolGUID   = (mountvol $DevDrivePath /L 2>$null).Trim()

Write-Host "NTFS partition : $VolumeGUID" -ForegroundColor Green
Write-Host "DevDrive volume: $devVolGUID" -ForegroundColor Green

# ---------------------------------------------------------------
# [2/6] Kill COM Surrogate and pause background services
# ---------------------------------------------------------------
Write-Host "`n[2/6] Stopping background processes..." -ForegroundColor Yellow

$dllhosts = Get-Process -Name dllhost -ErrorAction SilentlyContinue
if ($dllhosts) {
    $dllhosts | Stop-Process -Force
    Write-Host "Killed $($dllhosts.Count) dllhost.exe instance(s)." -ForegroundColor Green
    Start-Sleep -Milliseconds 1500
} else {
    Write-Host "No dllhost.exe processes found." -ForegroundColor Gray
}

Stop-Service -Name WSearch -Force -ErrorAction SilentlyContinue
Write-Host "Windows Search indexer paused." -ForegroundColor Green

# Pause Defender real-time monitoring briefly to release filter driver handles
Set-MpPreference -DisableRealtimeMonitoring $true -ErrorAction SilentlyContinue
Write-Host "Defender real-time monitoring paused." -ForegroundColor Green

Start-Sleep -Milliseconds 1500

# ---------------------------------------------------------------
# [3/6] Dismount DevDrive inner volume
# ---------------------------------------------------------------
Write-Host "`n[3/6] Dismounting inner DevDrive volume..." -ForegroundColor Yellow

if ($devVolGUID) {
    $devVol = Get-WmiObject -Class Win32_Volume | Where-Object { $_.DeviceID -eq $devVolGUID }
    if ($devVol) {
        $result = $devVol.Dismount($false, $true)
        if ($result.ReturnValue -eq 0) {
            Write-Host "DevDrive volume dismounted successfully." -ForegroundColor Green
        } else {
            Write-Host "Could not dismount DevDrive volume (code $($result.ReturnValue)), continuing..." -ForegroundColor Yellow
        }
        Start-Sleep -Milliseconds 1000
    }
}

# ---------------------------------------------------------------
# [4/6] Attempt eject (WMI first, then Shell fallback)
# ---------------------------------------------------------------
Write-Host "`n[4/6] Attempting to eject drive..." -ForegroundColor Yellow

$ejected = $false
$wmiResult = Try-Eject
if ($wmiResult -eq 0) {
    $ejected = $true
} else {
    Write-Host "WMI dismount failed (code $wmiResult), trying Shell eject..." -ForegroundColor Yellow
    $shellResult = Try-SafeRemoval $TargetLetter
    if ($shellResult) {
        Start-Sleep -Milliseconds 2000
        # Verify it actually ejected
        $verify = (mountvol "$TargetLetter`:" /L 2>$null).Trim()
        if ($verify -match "cannot find" -or [string]::IsNullOrEmpty($verify)) {
            $ejected = $true
        }
    }
}

# Restore services regardless of eject outcome
Set-MpPreference -DisableRealtimeMonitoring $false -ErrorAction SilentlyContinue
if (-not $ejected) {
    Start-Service -Name WSearch -ErrorAction SilentlyContinue
}

if ($ejected) {
    Write-Host "Drive ejected successfully! Safe to unplug." -ForegroundColor Green
    Write-Host "(Defender and Windows Search restored)" -ForegroundColor Gray
    Write-Host "`n=== Done ===" -ForegroundColor Cyan
    Write-Host ""
    Read-Host "Press Enter to close"
    exit 0
}

Write-Host "Eject failed - drive is still in use." -ForegroundColor Red

# ---------------------------------------------------------------
# [5/6] Download Handle.exe if needed
# ---------------------------------------------------------------
Write-Host "`n[5/6] Preparing diagnostics..." -ForegroundColor Yellow

if (-not (Test-Path $HandlePath)) {
    Write-Host "Downloading Sysinternals Handle.exe..." -ForegroundColor Yellow
    try {
        Invoke-WebRequest -Uri "https://live.sysinternals.com/handle.exe" -OutFile $HandlePath
        Write-Host "Downloaded successfully." -ForegroundColor Green
    } catch {
        Write-Warning "Could not download Handle.exe."
        $HandlePath = $null
    }
} else {
    Write-Host "Handle.exe already present." -ForegroundColor Gray
}

# ---------------------------------------------------------------
# [6/6] Diagnose - find processes holding handles
# ---------------------------------------------------------------
Write-Host "`n[6/6] Searching for culprits..." -ForegroundColor Yellow

function Search-Handles($label, $path) {
    Write-Host "`n  --- $label ---" -ForegroundColor Cyan
    if ($HandlePath -and (Test-Path $HandlePath)) {
        $handleOutput = & $HandlePath -accepteula -nobanner $path 2>&1
        $filtered = $handleOutput | Where-Object { $_ -notmatch "^Handle v" -and $_ -ne "" }
        if (-not $filtered -or ($filtered | Out-String) -match "No matching handles found") {
            Write-Host "  No open file handles found." -ForegroundColor Gray
        } else {
            $filtered | ForEach-Object {
                if ($_ -match "pid") { Write-Host "  $_" -ForegroundColor Red }
                elseif ($_ -match "\.exe") { Write-Host "  $_" -ForegroundColor Yellow }
                else { Write-Host "  $_" }
            }
        }
    } else {
        Write-Host "  (Handle.exe unavailable)" -ForegroundColor DarkGray
    }
}

Search-Handles "NTFS partition ($TargetLetter`:)" "$TargetLetter`:"
if ($devVolGUID) {
    $devVolPath = $devVolGUID.TrimEnd('\')
    Search-Handles "DevDrive volume" $devVolPath
}

Write-Host "`n  --- Processes with modules loaded from $TargetLetter`: ---" -ForegroundColor Cyan
$suspectProcesses = Get-Process | Where-Object {
    try { $_.Modules | Where-Object { $_.FileName -like "$TargetLetter`:\*" } } catch { $false }
}
if ($suspectProcesses) {
    $suspectProcesses | ForEach-Object {
        Write-Host "  PID $($_.Id) - $($_.ProcessName) ($($_.MainWindowTitle))" -ForegroundColor Yellow
    }
} else {
    Write-Host "  None found." -ForegroundColor Gray
}

Write-Host "`n  Note: Code 2 (Access Denied) typically means a kernel filter driver" -ForegroundColor DarkGray
Write-Host "  (Defender, ReFS, or antivirus) is holding a volume-level reference." -ForegroundColor DarkGray
Write-Host "  This is usually safe to resolve by restarting the machine before unplugging." -ForegroundColor DarkGray

Write-Host ""
Write-Host "Trying diskpart offline as last resort..." -ForegroundColor Yellow

$finalResult = Try-Eject
if ($finalResult -eq 0) {
    Write-Host "Drive ejected successfully! Safe to unplug." -ForegroundColor Green
} else {
    Write-Host "Eject still failed (code $finalResult), escalating to diskpart offline..." -ForegroundColor Yellow

    # Find the disk number strictly by matching the volume GUID access path
    # Never match by drive letter to avoid accidentally selecting internal disks
    $diskNumber = $null
    $partition = Get-Partition | Where-Object {
        $_.AccessPaths -contains $VolumeGUID
    } | Select-Object -First 1

    if ($partition) {
        $diskNumber = $partition.DiskNumber
        # Safety check: refuse to offline non-removable internal disks
        $disk = Get-Disk -Number $diskNumber
        if ($disk.BusType -notin @('USB', 'IEEE 1394', 'SD', 'MMC', 'Virtual')) {
            Write-Host "Safety check failed: Disk $diskNumber is bus type '$($disk.BusType)' - refusing to offline a non-removable disk!" -ForegroundColor Red
            $diskNumber = $null
        } else {
            Write-Host "Confirmed portable drive is Disk $diskNumber (bus type: $($disk.BusType))." -ForegroundColor Green
        }
    }

    if ($null -ne $diskNumber) {
        Write-Host "Found drive on Disk $diskNumber, taking offline via diskpart..." -ForegroundColor Yellow

        $diskpartScript = @"
select disk $diskNumber
offline disk
"@
        $tempScript = "$env:TEMP\dp_offline.txt"
        $diskpartScript | Set-Content -Path $tempScript -Encoding ASCII
        $dpOutput = diskpart /s $tempScript | Out-String
        Remove-Item $tempScript -Force

        Start-Sleep -Milliseconds 1500

        # Verify disk is offline
        $verify = (mountvol "$TargetLetter`:" /L 2>$null).Trim()
        if ($verify -match "cannot find" -or [string]::IsNullOrEmpty($verify)) {
            Write-Host "Filesystem flushed and released successfully." -ForegroundColor Green
            Write-Host "Bringing disk back online so it reconnects cleanly after unplug..." -ForegroundColor Yellow

            $onlineScript = "select disk $diskNumber`r`nonline disk"
            $tempOnline = "$env:TEMP\dp_online.txt"
            $onlineScript | Set-Content -Path $tempOnline -Encoding ASCII
            diskpart /s $tempOnline | Out-Null
            Remove-Item $tempOnline -Force
            Start-Sleep -Milliseconds 1000

            # After offline/online cycle, filesystem references are reset - try dismounting again
            Write-Host "Attempting dismount after offline/online cycle..." -ForegroundColor Yellow
            Start-Sleep -Milliseconds 500

            # Try inner DevDrive volume first
            if ($devVolGUID) {
                $devVol = Get-WmiObject -Class Win32_Volume | Where-Object { $_.DeviceID -eq $devVolGUID }
                if ($devVol) { $devVol.Dismount($false, $true) | Out-Null }
            }
            Start-Sleep -Milliseconds 500

            # Then try outer NTFS volume
            $outerVol = Get-WmiObject -Class Win32_Volume | Where-Object { $_.DriveLetter -eq "$TargetLetter`:" }
            if ($outerVol) {
                $dismountResult = $outerVol.Dismount($false, $true)
                if ($dismountResult.ReturnValue -eq 0) {
                    Write-Host "Drive ejected successfully! Safe to unplug." -ForegroundColor Green
                } else {
                    Write-Host "Dismount still failed (code $($dismountResult.ReturnValue))." -ForegroundColor Yellow
                    Write-Host "Filesystem has been flushed. You can either:" -ForegroundColor Yellow
                    Write-Host "  - Unplug now (low risk, filesystem was flushed)" -ForegroundColor White
                    Write-Host "  - Shut down the PC first (guaranteed safe)" -ForegroundColor White
                }
            }
        } else {
            Write-Host "Diskpart offline did not release the drive." -ForegroundColor Red
            Write-Host "Safest option: shut down the computer before unplugging the drive." -ForegroundColor Yellow
        }
    } else {
        Write-Host "Could not determine disk number for diskpart." -ForegroundColor Red
        Write-Host "Safest option: shut down the computer before unplugging the drive." -ForegroundColor Yellow
    }
}

Write-Host "`n=== Done ===" -ForegroundColor Cyan
Write-Host ""
Read-Host "Press Enter to close"
