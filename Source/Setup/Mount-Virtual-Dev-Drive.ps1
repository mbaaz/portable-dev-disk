# FILE: Mount-Virtual-Dev-Drive.ps1
# This script is responsible for mounting the virtual drive that will be used for development.


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
Write-Header "MOUNT VIRTUAL DEV DRIVE"
Write-Config " DevDrive VHD File Path: ${DevDriveVhdPath}"
Write-Config "VHD Drive Target Letter: [${VhdDriveTargetLetter}]"


# ---------------------------------------------------------------
# This script should be run as administrator, so we will check
# for that before proceeding
# ---------------------------------------------------------------
Assert-RunningAsAdministrator


# ---------------------------------------------------------------
# Ensure VHD file exists before proceeding
# ---------------------------------------------------------------
if (-not (Test-Path $DevDriveVhdPath)) {
    Write-Error "VHD file not found. Make sure the path is configured correctly."
    Write-PostError
}


# ---------------------------------------------------------------
# Mount the VHD at Target Letter
# ---------------------------------------------------------------
Write-Message "Mounting DevDrive VHD..."

$DiskImage = Get-DiskImage -ImagePath $DevDriveVhdPath 2>$null
if ($DiskImage -and $DiskImage.Attached) {
    Write-Success "VHD is already mounted"
} else {
    # Try to mount the VHD without assigning a drive letter
    try {
        Mount-DiskImage -ImagePath $DevDriveVhdPath -NoDriveLetter -ErrorAction Stop | Out-Null
        Write-Success "VHD mounted successfully"
    } catch {
        Write-Error "Failed to mount VHD: $_"
        Write-PostError
    }

    # Allow some time for the system to recognize the new disk and partition before we try to find it
    Start-Sleep -Milliseconds 1000
    
    # Update the disk information for the mounted VHD
    $DiskImage = Get-DiskImage -ImagePath $DevDriveVhdPath
    if (-not $DiskImage -or -not $DiskImage.Attached) {
        Write-Error "VHD was mounted but could not be found in disk list."
        Write-PostError
    }    
}


# ---------------------------------------------------------------
# Find Parition of Disk Image
# ---------------------------------------------------------------
$Partition = Get-Partition -DiskNumber $DiskImage.Number | Where-Object { $_.Type -ne "Reserved" } | Select-Object -First 1
if (-not $partition) {
    Write-Error "Could not find Partition inside mounted VHD"
    Write-PostError
}


# ---------------------------------------------------------------
# Perform Drive Letter Assertions
# ---------------------------------------------------------------
Assert-DriveLetter -Partition $Partition -TargetLetter $VhdDriveTargetLetter | Out-Null


# # ---------------------------------------------------------------
# # Remove any stray mount points Windows assigned to the VHD
# # ---------------------------------------------------------------
# $DevDriveIsCorrectlyMounted = $false

# # Remove any auto-assigned access paths (drive letters or folders)
# $ExistingPaths = $Partition.AccessPaths | Where-Object { $_ -notlike "\\?\Volume*" }
# foreach ($ExistingPath in $ExistingPaths) {
#     # Check if the existing path is the correct DevDrivePath
#     if($ExistingPath.TrimEnd("\") -eq $DevDriveMountFolderPath.TrimEnd("\")) {
#         Write-Success "DevDrive is already mounted in correct location"
#         $DevDriveIsCorrectlyMounted = $true
#         continue
#     }
    
#     Write-Message "Removing auto-assigned mount path: ${ExistingPath}"
#     try {
#         Remove-PartitionAccessPath -DiskNumber $DiskImage.Number -PartitionNumber $Partition.PartitionNumber -AccessPath $ExistingPath -ErrorAction Stop
#     } catch {
#         Write-Warning "Could not remove auto-assigned path ${ExistingPath}: $_"
#     }
# }

# if(-not $DevDriveIsCorrectlyMounted) {
#     # Assign the correct folder mount point
#     try {
#         Add-PartitionAccessPath -DiskNumber $DiskImage.Number -PartitionNumber $Partition.PartitionNumber -AccessPath $DevDriveMountFolderPath -ErrorAction Stop
#         Write-Success "DevDrive was mounted in correct location"
#     } catch {
#         Write-Error "Failed to mount DevDrive in correct location`n> $_"
#         Write-PostError
#     }
# }


# ---------------------------------------------------------------
# ... and Done!
# ---------------------------------------------------------------
Write-EndOfScript