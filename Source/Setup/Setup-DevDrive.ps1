# Setup-DevDrive.ps1
# Place this file in the Setup folder on your portable drive.
# Must be run as Administrator (1. Setup-DevDrive.cmd handles this).
#
# What this script does:
#   1. Detects its own volume GUID from the script location
#   2. Finds the current drive letter of the NTFS partition
#   3. If not on configured drive letter, reassigns the letter atomically
#   4. Ensures DevDrive mount folder exists
#   5. Mounts the DevDrive VHD at DevDrive mount folder (if not already mounted)
#   6. Trusts the DevDrive (skips if already trusted)

# ---------------------------------------------------------------
# CONFIG
# ---------------------------------------------------------------
$TotalSteps = 6
$ConfigFile = Join-Path $PSScriptRoot "config.ps1"
if (-not (Test-Path $ConfigFile)) {
    Write-Error "Configuration file not found: $ConfigFile"
    Read-Host "Press Enter to close"
    exit 1
}
. $ConfigFile # Load configuration variables from separate file

# ---------------------------------------------------------------
# HELPER FUNCTIONS
# ---------------------------------------------------------------

function Get-VolumeGUIDFromDriveLetter($driveLetter) {
    $volume = Get-Volume -DriveLetter $driveLetter -ErrorAction SilentlyContinue
    if ($volume) {
        return $volume.UniqueId.Trim()
    } else {
        return $null
    }
}

function Get-VolumeDriveLetterFromGUID($volumeGUID) {
    $volume = Get-Volume -UniqueId $volumeGUID -ErrorAction SilentlyContinue
    if ($volume) {
        return $volume.DriveLetter.ToString().ToUpper()
    } else {
        return $null
    }
}

# ---------------------------------------------------------------
# Require Administrator
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Error "This script must be run as Administrator."
    Read-Host "Press Enter to close"
    exit 1
}

# ---------------------------------------------------------------
# STEP 0: Welcome message and configuration display
# ---------------------------------------------------------------
Write-Host "`n=== Portable Dev Drive Setup ===" -ForegroundColor Cyan

Write-Host "`n[0/$TotalSteps] Configuration:" -ForegroundColor Yellow
Write-Host "  Target Letter: ${TargetLetter}:" -ForegroundColor White
Write-Host "DevDrive Folder: ${DevDriveFolderName}" -ForegroundColor White
Write-Host "       VHD File: ${VhdFileName}" -ForegroundColor White

# ---------------------------------------------------------------
# STEP 1: Detect our own volume GUID from the script's location
# ---------------------------------------------------------------
Write-Host "`n[1/$TotalSteps] Determining volume GUID..." -ForegroundColor Yellow

if($UseCurrentDrive) {
    Write-Host "Using current drive detection method" -ForegroundColor Green
    $ScriptDriveLetter = (Split-Path -Qualifier $PSScriptRoot).TrimEnd(":").ToUpper()
    $VolumeGUID = Get-VolumeGUIDFromDriveLetter $ScriptDriveLetter
} else {
    Write-Host "Using hardcoded volume GUID from config" -ForegroundColor Green
    $VolumeGUID = $UseVolumeGUID
}

if (-not $VolumeGUID) {
    Write-Error "`nVolume GUID '${VolumeGUID}' is not available"
    Read-Host "`nPress Enter to close"
    exit 1
}
Write-Host "Volume GUID: ${VolumeGUID}" -ForegroundColor Green

$CurrentLetter = Get-VolumeDriveLetterFromGUID $VolumeGUID
if(-not $CurrentLetter) {
    Write-Error "Could not find a drive letter for volume GUID '${VolumeGUID}'. Make sure the drive is connected and the GUID is correct."
    Read-Host "Press Enter to close"
    exit 1
}
Write-Host "Portable drive is currently on ${CurrentLetter}:" -ForegroundColor Green

# ---------------------------------------------------------------
# STEP 2: Reassign to X: if not already there
# ---------------------------------------------------------------
Write-Host "`n[2/$TotalSteps] Checking drive letter assignment..." -ForegroundColor Yellow


if ($CurrentLetter -eq $TargetLetter) {
    Write-Host "Drive is already on ${TargetLetter}:, nothing to do." -ForegroundColor Green
} else {
    $TargetLetterCheck = Get-VolumeGUIDFromDriveLetter $TargetLetter
    $TargetLetterIsFree = [string]::IsNullOrEmpty($TargetLetterCheck)

    if (-not $TargetLetterIsFree) {
        Write-Error "${TargetLetter}: is in use by another volume (${TargetLetterCheck}). Please free ${TargetLetter}: manually and try again."
        Read-Host "Press Enter to close"
        exit 1
    }

    Write-Host "Reassigning [${CurrentLetter}:] to [${TargetLetter}:]..." -ForegroundColor Green
    Get-Partition -DriveLetter $CurrentLetter | Set-Partition -NewDriveLetter $TargetLetter

    $TargetLetterCheck = Get-VolumeGUIDFromDriveLetter $TargetLetter
    if($TargetLetterCheck -ne $VolumeGUID) {
        Write-Error "Drive letter reassignment failed. Expected volume GUID '${VolumeGUID}', but ${TargetLetter}: has '${TargetLetterCheck}'."
        Read-Host "Press Enter to close"
        exit 1
    }

    Write-Host "Drive successfully reassigned to ${TargetLetter}:" -ForegroundColor Green
    $CurrentLetter = $TargetLetter
}

# ---------------------------------------------------------------
# STEP 3: Ensure DevDrive mount folder exists
# ---------------------------------------------------------------
$DevDriveMountPath = "${CurrentLetter}:\${DevDriveFolderName}"
Write-Host "`n[3/$TotalSteps] Checking DevDrive mount folder..." -ForegroundColor Yellow

if (-not (Test-Path $DevDriveMountPath)) {
    Write-Host "Mount folder does not exist, creating it..." -ForegroundColor Green
    New-Item -ItemType Directory -Path $DevDriveMountPath | Out-Null
    Write-Host "Created ${DevDriveMountPath}" -ForegroundColor Green
} else {
    Write-Host "Mount folder exists" -ForegroundColor Green
}

# ---------------------------------------------------------------
# STEP 4: Mount the VHD at X:\DevDrive (if not already mounted)
# ---------------------------------------------------------------
$VhdPath = "${CurrentLetter}:\${VhdFileName}"
Write-Host "`n[4/$TotalSteps] Mounting DevDrive VHD..." -ForegroundColor Yellow

if (-not (Test-Path $VhdPath)) {
    Write-Error "VHD file not found at '${VhdPath}'. Make sure the path is configured correctly."
    Read-Host "Press Enter to close"
    exit 1
}

$diskImage = Get-DiskImage -ImagePath $VhdPath 2>$null

if ($diskImage -and $diskImage.Attached) {
    Write-Host "VHD is already mounted." -ForegroundColor Green
} else {
    # Try to mount the VHD without assigning a drive letter (we'll assign the folder mount point later)
    try {
        Mount-DiskImage -ImagePath $VhdPath -NoDriveLetter -ErrorAction Stop | Out-Null
        Write-Host "VHD mounted successfully" -ForegroundColor Green
    } catch {
        Write-Error "Failed to mount VHD: $_"
        Read-Host "Press Enter to close"
        exit 1
    }

    # Allow some time for the system to recognize the new disk and partition before we try to find it
    Start-Sleep -Milliseconds 1000
    
    # Update the disk information for the mounted VHD
    $diskImage = Get-DiskImage -ImagePath $VhdPath
    if (-not $diskImage -or -not $diskImage.Attached) {
        Write-Error "VHD was mounted but could not be found in disk list."
        Read-Host "Press Enter to close"
        exit 1
    }    
}

# ---------------------------------------------------------------
# STEP 5: Remove any stray drive letter Windows assigned to the VHD
# ---------------------------------------------------------------
Write-Host "`n[5/$TotalSteps] Checking access points to VHD volume..." -ForegroundColor Yellow

# Find partition on the mounted VHD (assuming there's only one partition and it's not a Reserved partition)
$partition = Get-Partition -DiskNumber $diskImage.Number | Where-Object { $_.Type -ne "Reserved" } | Select-Object -First 1
if (-not $partition) {
    Write-Error "Could not find partition inside mounted VHD."
    Read-Host "Press Enter to close"
    exit 1
}

$devDriveVolumeID = ($partition.AccessPaths | Where-Object { $_ -like "\\?\Volume*" } | Select-Object -First 1)
if (-not $devDriveVolumeID) {
    Write-Error "Could not determine volume GUID of mounted VHD."
    Read-Host "Press Enter to close"
    exit 1
}

# Determine the expected DevDrive path (e.g. X:\DevDrive)
$DevDrivePath = "${CurrentLetter}:\${DevDriveFolderName}"
$DevDriveIsMounted = $false

# Remove any auto-assigned access paths (drive letters or folders)
$existingPaths = $partition.AccessPaths | Where-Object { $_ -notlike "\\?\Volume*" }
foreach ($existingPath in $existingPaths) {
    # Check if the existing path is the correct DevDrivePath
    if($existingPath.TrimEnd("\") -eq $DevDrivePath.TrimEnd("\")) {
        Write-Host "DevDrive is already mounted at ${DevDrivePath}" -ForegroundColor Green
        $DevDriveIsMounted = $true
        continue
    }
    
    Write-Host "Removing auto-assigned mount path: ${existingPath}" -ForegroundColor Green
    try {
        Remove-PartitionAccessPath -DiskNumber $diskImage.Number -PartitionNumber $partition.PartitionNumber -AccessPath $existingPath -ErrorAction Stop
    } catch {
        Write-Warning "Could not remove auto-assigned path ${existingPath}: $_"
    }
}

if(-not $DevDriveIsMounted) {
    # Assign the correct folder mount point
    try {
        Add-PartitionAccessPath -DiskNumber $diskImage.Number -PartitionNumber $partition.PartitionNumber -AccessPath $DevDrivePath -ErrorAction Stop
        Write-Host "VHD mounted at ${DevDrivePath}" -ForegroundColor Green
    } catch {
        Write-Error "Failed to mount VHD at ${DevDrivePath}: $_"
        Read-Host "Press Enter to close"
        exit 1
    }
}

# ---------------------------------------------------------------
# STEP 6: Trust the Dev Drive
# ---------------------------------------------------------------
Write-Host "`n[6/$TotalSteps] Trusting Dev Drive..." -ForegroundColor Yellow

$trustQuery = (fsutil devdrv query $devDriveVolumeID 2>&1) | Out-String
if ($trustQuery -match "Trusted") {
    Write-Host "Status: Trusted (already trusted on this machine)" -ForegroundColor Green
} else {
    fsutil devdrv trust $DevDrivePath | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Write-Error "fsutil devdrv trust failed. Try running manually: fsutil devdrv trust ${DevDrivePath}"
    } else {
        Write-Host "Status: Trusted" -ForegroundColor Green
    }
}

Write-Host "`n=== Setup Complete! ===" -ForegroundColor Cyan
Write-Host "   Drive letter: ${CurrentLetter}:" -ForegroundColor White
Write-Host "  DevDrive path: ${DevDrivePath}" -ForegroundColor White
Write-Host ""



if($DEBUG -eq $true) {
    Read-Host "Press Enter to close"
}
