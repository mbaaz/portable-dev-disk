. .\Backup.ps1

$BackupPath = "D:\DevBackups\PortableDisk"
$BackupFilePath = "${BackupPath}\PortableDisk_Backup_$(Get-Date -Format "yyyyMMdd_HHmmss").vhdx"
$BackupsToKeep = 5

$Drives = @(
    @{
        Path = "X:\"
        Name = "DevX"
    },
    @{
        Path = "Y:\"
        Name = "DevY"
    }
)


# ---------------------------------------------------------------
# Write welcome message and relevant configuration
# ---------------------------------------------------------------
Write-Host "`n=== PORTABLE DISK BACKUP ===" -ForegroundColor Cyan


# ---------------------------------------------------------------
# Check paths
# ---------------------------------------------------------------
Write-Host "`nChecking paths" -ForegroundColor White

# Backup directory
if (-not (Test-Path $BackupPath)) {
    Write-Host "  > Creating backup destination: $BackupPath" -ForegroundColor Yellow
    New-Item -ItemType Directory -Path $BackupPath | Out-Null
} else {
    Write-Host "  > Backup destination exists: $BackupPath" -ForegroundColor Green
}
# Drives to backup
$foundError = $false
$Drives | ForEach-Object {
    $drive = $_
    if (-not (Test-Path $drive.Path)) {
        Write-Warning "  >           Drive not found: $($drive.Path) ($($drive.Name))"
        $foundError = $true
    } else {
        Write-Host "  >     Drive to backup found: $($drive.Path) ($($drive.Name))" -ForegroundColor Green
    }
}

if ($foundError) {
    exit 1
}

# ---------------------------------------------------------------
# Calculate disk space needed
# ---------------------------------------------------------------
Write-Host "`nCalculating disk space requirements..." -ForegroundColor White

$totalSizeGB = 7 # Start with a base size for overhead
$Drives | ForEach-Object {
    $drive = $_
    $sizeBytes = (Get-ChildItem -Path $drive.Path -Recurse -File | Measure-Object -Property Length -Sum).Sum
    $sizeGB = [math]::Ceiling($sizeBytes / 1GB)
    $totalSizeGB += $sizeGB
    Write-Host "      $($drive.Name): ${sizeGB} GB"
    $drive.SizeGB = $sizeGB + 3 # Store size (with overhead) for later use
}
Write-Host "Total size: ${totalSizeGB} GB (incl. overhead)" -ForegroundColor White


# ---------------------------------------------------------------
# Create the VHDX
# ---------------------------------------------------------------
Write-Host "`nCreating VHDX file..." -ForegroundColor White

New-VHD -Path $BackupFilePath -SizeBytes "${totalSizeGB}GB" -Dynamic | Out-Null
if (-not (Test-Path $BackupFilePath)) {
    Write-Error "Failed to create VHDX file"
    exit 1
}

$disk = Mount-VHD -Path $BackupFilePath -Passthru
Initialize-Disk -Number $disk.DiskNumber -PartitionStyle GPT -ErrorAction SilentlyContinue


# ---------------------------------------------------------------
# Copy data into the VHDX
# ---------------------------------------------------------------
$Drives | ForEach-Object {
    if ($foundError) {
        return
    }

    $drive = $_
    #$source = Join-Path $drive.Path "*"
    $source = $drive.Path

    Write-Host "`nCreating a partition in vhdx for [$($drive.Name)]" -ForegroundColor White
    try {
        $partition = New-Partition -DiskNumber $disk.DiskNumber -Size "$($drive.SizeGB)GB" -AssignDriveLetter
        Format-Volume -Partition $partition -FileSystem NTFS -NewFileSystemLabel $drive.Name -Confirm:$false | Out-Null

        $destination = ($partition | Get-Volume).DriveLetter + ":"

        Write-Host "  > Copying files..." -ForegroundColor White

        robocopy $source $destination /mir /xa:sh /r:0 /xjd /nfl /ndl /njh /xd "`$RECYCLE.BIN" "node_modules" "bin" "obj"
    }
    catch {
        Write-Error "  > Error processing drive"
        $foundError = $true
    }
}


# ---------------------------------------------------------------
# Cleanup
# ---------------------------------------------------------------
Dismount-VHD -Path $BackupFilePath
if ($foundError) {
    Write-Host "`nBackup encountered errors. Please review the messages above." -ForegroundColor Red
} else {
    Write-Host "`nDone! VHDX created and populated!" -ForegroundColor Green
}



# After backup → enforce retention
Write-Host "`nPruning old backups..." -ForegroundColor White

# Get all matching VHDX files ordered newest → oldest
$backups = Get-ChildItem -Path $BackupPath -Filter "PortableDisk_Backup_*.vhdx" | Sort-Object LastWriteTime -Descending
$backupsToDelete = $backups | Select-Object -Skip $BackupsToKeep

foreach ($file in $backupsToDelete) {
    Write-Host "  > Deleting old backup: $($file.Name)" -ForegroundColor Yellow
    Remove-Item $file.FullName -Force
}

Write-Host "Completed. Kept $BackupsToKeep latest backups." -ForegroundColor Green
