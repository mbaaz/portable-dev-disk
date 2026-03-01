# Setup-DevDrive.ps1
# Place this file in the Setup folder on your portable drive.
# Must be run as Administrator (1. Setup-DevDrive.cmd handles this).
#
# What this script does:
#   1. Detects its own volume GUID from the script location
#   2. Finds the current drive letter of the NTFS partition
#   3. If not on X:, uses diskpart to reassign the letter atomically
#   4. Ensures X:\DevDrive mount folder exists
#   5. Mounts the DevDrive VHD at X:\DevDrive (if not already mounted)
#   6. Trusts the Dev Drive (skips if already trusted)

# ---------------------------------------------------------------
# CONFIG
# ---------------------------------------------------------------
$TargetLetter = "X" # Desired drive letter for the NTFS partition
$DevDriveFolderName = "DevDrive" # Mount point folder name on the NTFS partition
$VhdFileName = "Setup`\DevDrive.vhdx" # Name of the VHD file inside Setup
# ---------------------------------------------------------------

# Require Administrator
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Error "This script must be run as Administrator."
    Read-Host "Press Enter to close"
    exit 1
}

Write-Host "`n=== Portable Dev Drive Setup ===" -ForegroundColor Cyan

Write-Host "`n[0/6] Configuration:" -ForegroundColor Yellow
Write-Host "  Target Letter: ${TargetLetter}:" -ForegroundColor White
Write-Host "DevDrive Folder: ${DevDriveFolderName}" -ForegroundColor White
Write-Host "       VHD File: ${VhdFileName}" -ForegroundColor White

# ---------------------------------------------------------------
# [1/6] Detect our own volume GUID from the script's location
# ---------------------------------------------------------------
Write-Host "`n[1/6] Detecting volume GUID from script location..." -ForegroundColor Yellow

$ScriptDriveLetter = (Split-Path -Qualifier $PSScriptRoot).TrimEnd(":")
$VolumeGUID = (Get-Volume -DriveLetter $ScriptDriveLetter 2>$null).UniqueId | Out-String

if (-not $VolumeGUID) {
    Write-Error "`nCould not determine volume GUID from script location '${ScriptDriveLetter}:'."
    Read-Host "`nPress Enter to close"
    exit 1
}

$VolumeGUID = $VolumeGUID.Trim()
Write-Host "Volume GUID: ${VolumeGUID}" -ForegroundColor Green

$CurrentLetter = $ScriptDriveLetter
Write-Host "Portable drive is currently on ${CurrentLetter}:" -ForegroundColor Green

# ---------------------------------------------------------------
# [2/6] Reassign to X: if not already there, using diskpart
# ---------------------------------------------------------------
Write-Host "`n[2/6] Checking drive letter assignment..." -ForegroundColor Yellow


exit 1


if ($CurrentLetter -eq $TargetLetter) {
    Write-Host "Drive is already on ${TargetLetter}:, nothing to do." -ForegroundColor Green
} else {
    #$xCheck = (mountvol "${TargetLetter}:" /L 2>$null).Trim()
    $xCheck = (Get-Volume -DriveLetter X 2>$null).UniqueId | Out-String
    if($xCheck) { $xCheck.Trim() }
    $xIsFree = [string]::IsNullOrEmpty($xCheck)

    if (-not $xIsFree) {
        Write-Error "${TargetLetter}: is in use by another volume (${xCheck}). Please free ${TargetLetter}: manually and try again."
        Read-Host "Press Enter to close"
        exit 1
    }

    Write-Host "Reassigning [${CurrentLetter}:] to [${TargetLetter}:]..." -ForegroundColor Yellow

    #$diskpartScript = @"
#select volume $CurrentLetter
#assign letter=$TargetLetter
#"@
    #$tempScript = "$env:TEMP\dp_assign.txt"
    #$diskpartScript | Set-Content -Path $tempScript -Encoding ASCII
    #diskpart /s $tempScript | Out-Null
    #Remove-Item $tempScript -Force

    Get-Partition -DriveLetter $CurrentLetter | Set-Partition -NewDriveLetter $TargetLetter

    # Retry loop — diskpart returns before Windows fully registers the new letter
    $maxAttempts = 10
    $attempt = 0
    $letterConfirmed = $false
    do {
        Start-Sleep -Milliseconds 500
        $attempt++
        
        $match = Get-Volume -UniqueId $VolumeGUID | Where-Object { $_.DriveLetter -eq $TargetLetter }
        Write-Host "  [attempt ${attempt}] result: '${match}'" -ForegroundColor DarkGray
        if ($match) {
            #Write-Host "Remap successful."
            $letterConfirmed = $true
        }
        else {
            #Write-Host "Remap NOT complete."
        }
        
        #$verifyRaw = mountvol "${TargetLetter}:" /L 2>$null
        #$verifyRaw = mountvol "${TargetLetter}:" /L 2>$null
        #$verify = if ($verifyRaw) { $verifyRaw.Trim() } else { "" }
        #Write-Host "  [attempt ${attempt}] mountvol result: '${verify}' [$verifyRaw]" -ForegroundColor DarkGray
        #if ($verify -eq $VolumeGUID) {
        #    $letterConfirmed = $true
        #}
    } until ($letterConfirmed -or $attempt -ge $maxAttempts)

    if (-not $letterConfirmed) {
        Write-Error "Letter reassignment failed after ${maxAttempts} attempts. Last mountvol output: '${verify}'. Try running diskpart manually: select volume ${CurrentLetter} then assign letter=${TargetLetter}"
        Read-Host "Press Enter to close"
        exit 1
    }

    Write-Host "Drive successfully reassigned to ${TargetLetter}:" -ForegroundColor Green
    $CurrentLetter = $TargetLetter
}

# ---------------------------------------------------------------
# [3/6] Ensure X:\DevDrive mount folder exists
# ---------------------------------------------------------------
$DevDrivePath = "${CurrentLetter}:\${DevDriveFolderName}"
Write-Host "`n[3/6] Checking DevDrive mount folder at ${DevDrivePath}..." -ForegroundColor Yellow

if (-not (Test-Path $DevDrivePath)) {
    Write-Host "Mount folder does not exist, creating it..." -ForegroundColor Yellow
    New-Item -ItemType Directory -Path $DevDrivePath | Out-Null
    Write-Host "Created ${DevDrivePath}" -ForegroundColor Green
} else {
    Write-Host "Mount folder exists." -ForegroundColor Green
}

# ---------------------------------------------------------------
# [4/6] Mount the VHD at X:\DevDrive (if not already mounted)
# ---------------------------------------------------------------
$VhdPath = "${CurrentLetter}:\_Setup\${VhdFileName}"
Write-Host "`n[4/6] Mounting VHD from ${VhdPath}..." -ForegroundColor Yellow

if (-not (Test-Path $VhdPath)) {
    Write-Error "VHD file not found at '${VhdPath}'. Make sure '${VhdFileName}' is in the _Setup folder."
    Read-Host "Press Enter to close"
    exit 1
}

$diskImage = Get-DiskImage -ImagePath $VhdPath 2>$null
if ($diskImage -and $diskImage.Attached) {
    Write-Host "VHD is already mounted." -ForegroundColor Green
    $disk = $diskImage
    $partition = Get-Partition -DiskNumber $disk.Number | Where-Object { $_.Type -ne "Reserved" } | Select-Object -First 1
    $devVolName = ($partition.AccessPaths | Where-Object { $_ -like "\\?\Volume*" } | Select-Object -First 1)
    $folderMounted = mountvol $DevDrivePath /L 2>$null
    if($folderMounted) { $folderMounted.Trim() }
    if ($folderMounted -and $folderMounted -notmatch "cannot find") {
        Write-Host "VHD is mounted at ${DevDrivePath}." -ForegroundColor Green
    } else {
        Write-Host "VHD is mounted but not at ${DevDrivePath}, fixing..." -ForegroundColor Yellow
        Add-PartitionAccessPath -DiskNumber $disk.Number -PartitionNumber $partition.PartitionNumber -AccessPath $DevDrivePath
    }
} else {
    try {
        Mount-DiskImage -ImagePath $VhdPath -NoDriveLetter -ErrorAction Stop | Out-Null
        Write-Host "VHD mounted successfully." -ForegroundColor Green
    } catch {
        Write-Error "Failed to mount VHD: $_"
        Read-Host "Press Enter to close"
        exit 1
    }

    Start-Sleep -Milliseconds 1000
    $disk = Get-DiskImage -ImagePath $VhdPath
    $partition = Get-Partition -DiskNumber $disk.Number | Where-Object { $_.Type -ne "Reserved" } | Select-Object -First 1

    if (-not $partition) {
        Write-Error "Could not find partition inside mounted VHD."
        Read-Host "Press Enter to close"
        exit 1
    }

    $devVolName = ($partition.AccessPaths | Where-Object { $_ -like "\\?\Volume*" } | Select-Object -First 1)

    if (-not $devVolName) {
        Write-Error "Could not determine volume GUID of mounted VHD."
        Read-Host "Press Enter to close"
        exit 1
    }

    # Remove any auto-assigned access paths (drive letters or folders)
    $existingPaths = $partition.AccessPaths | Where-Object { $_ -notlike "\\?\Volume*" }
    foreach ($existingPath in $existingPaths) {
        Write-Host "Removing auto-assigned mount path: ${existingPath}" -ForegroundColor Yellow
        try {
            Remove-PartitionAccessPath -DiskNumber $disk.Number -PartitionNumber $partition.PartitionNumber -AccessPath $existingPath -ErrorAction Stop
        } catch {
            Write-Warning "Could not remove auto-assigned path ${existingPath}: $_"
        }
    }

    # Assign the correct folder mount point
    try {
        Add-PartitionAccessPath -DiskNumber $disk.Number -PartitionNumber $partition.PartitionNumber -AccessPath $DevDrivePath -ErrorAction Stop
        Write-Host "VHD mounted at ${DevDrivePath}" -ForegroundColor Green
    } catch {
        Write-Error "Failed to mount VHD at ${DevDrivePath}: $_"
        Read-Host "Press Enter to close"
        exit 1
    }
}

# ---------------------------------------------------------------
# [5/6] Remove any stray drive letter Windows assigned to the VHD
# ---------------------------------------------------------------
Write-Host "`n[5/6] Checking VHD volume for stray drive letters..." -ForegroundColor Yellow

$rawMountvol = mountvol
$devRawLines = $rawMountvol -split "`n"
$devCurrentLetters = @()
$inOurVolume = $false

foreach ($line in $devRawLines) {
    $trimmed = $line.Trim()
    if ($trimmed -eq $devVolName) {
        $inOurVolume = $true
        continue
    }
    if ($inOurVolume) {
        if ($trimmed -like "\\?\Volume*") { break }
        if ($trimmed -match "^([A-Z]):\\$") {
            $devCurrentLetters += $matches[1]
        }
    }
}

if ($devCurrentLetters.Count -gt 0) {
    foreach ($devCurrentLetter in $devCurrentLetters) {
        Write-Host "Removing stray drive letter ${devCurrentLetter}:..." -ForegroundColor Yellow
        mountvol "${devCurrentLetter}:" /D
        if ($LASTEXITCODE -ne 0) {
            Write-Warning "Could not remove drive letter ${devCurrentLetter}: from VHD volume."
        } else {
            Write-Host "Drive letter ${devCurrentLetter}: removed." -ForegroundColor Green
        }
    }
    Write-Host "VHD volume is now accessible via ${DevDrivePath} only." -ForegroundColor Green
} else {
    Write-Host "No stray drive letters found." -ForegroundColor Green
}

# ---------------------------------------------------------------
# [6/6] Trust the Dev Drive
# ---------------------------------------------------------------
Write-Host "`n[6/6] Trusting Dev Drive..." -ForegroundColor Yellow

$trustQuery = (fsutil devdrv query $devVolName 2>&1) | Out-String
if ($trustQuery -match "Trusted") {
    Write-Host "Status: Trusted (already trusted on this machine)" -ForegroundColor Green
} else {
    fsutil devdrv trust $DevDrivePath
    if ($LASTEXITCODE -ne 0) {
        Write-Error "fsutil devdrv trust failed. Try running manually: fsutil devdrv trust ${DevDrivePath}"
    } else {
        Write-Host "Status: Trusted" -ForegroundColor Green
    }
}

Write-Host "`n=== Setup Complete! ===" -ForegroundColor Cyan
Write-Host "  Drive letter : ${CurrentLetter}:" -ForegroundColor White
Write-Host "  DevDrive path: ${DevDrivePath}" -ForegroundColor White
Write-Host ""

Read-Host "Press Enter to close"
