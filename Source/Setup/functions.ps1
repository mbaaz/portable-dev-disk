# ---------------------------------------------------------------
# MESSAGE HANDLING
# ---------------------------------------------------------------
function Write-Header($text) {
    Write-Host "`n=== $text ===" -ForegroundColor Cyan
}

function Write-Message($text) {
    Write-Host $text -ForegroundColor White
}

function Write-Config($text) {
    Write-Host $text -ForegroundColor DarkYellow
}

function Write-Success($text) {
    Write-Host $text -ForegroundColor Green
}

function Write-EndOfScript {
    Write-Host "`n"
}

function Write-PostError {
    Read-Host "`nPress Enter to close"
    exit 1
}

# ---------------------------------------------------------------
# IS RUNNING AS ADMINISTRATOR
# ---------------------------------------------------------------
function Test-IsRunningAsAdministrator {
    return [bool]([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Assert-RunningAsAdministrator {
    if (-not (Test-IsRunningAsAdministrator)) {
        Write-Error "This script must be run as Administrator."
        Write-PostError
    }
}

# ---------------------------------------------------------------
# FILE HANDLING
# ---------------------------------------------------------------
function Test-FileIsSymlink([string]$path) {
    $file = Get-Item $path -Force -ea SilentlyContinue
    return [bool]($file.Attributes -band [IO.FileAttributes]::ReparsePoint)
}

function Assert-FileExists($filePath) {
    $filePathWithoutDot = $filePath.Replace(".\", "")
    if ([string]::IsNullOrEmpty($ScriptRoot)) { $ScriptRoot = $PSScriptRoot }
    $fullFilePath = Join-Path $ScriptRoot $filePathWithoutDot
    #Write-Host "Asserting file exists: ${fullFilePath}" -ForegroundColor Magenta
    if (-not (Test-Path $fullFilePath)) {
        Write-Error "File not found! Please check file path and try again.`n> ${fullFilePath}"
        Read-Host "`nPress Enter to close"
        exit 1
    }
    return $fullFilePath
}

# ---------------------------------------------------------------
# VOLUME HANDLING
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
        return $volume.DriveLetter?.ToString()?.ToUpper()
    } else {
        return $null
    }
}

function Assert-DriveLetter {
    [cmdletbinding()]
    param(
        [parameter(Mandatory)]
        [ciminstance] $Partition,

        [parameter(Mandatory)]
        [string] $TargetLetter
    )

    Write-Message "Asserting Drive Letter"


    # ---------------------------------------------------------------
    # Get the current drive letter for this volume
    # ---------------------------------------------------------------
    Write-Config "  > Target Letter: [${TargetLetter}]"


    # ---------------------------------------------------------------
    # Make sure we have a Partition
    # ---------------------------------------------------------------
    if (-not $Partition) {
        Write-Error "  > Partition is invalid"
        Write-PostError
        return $false
    }


    # ---------------------------------------------------------------
    # Check if the current drive letter matches
    # the target drive letter.
    # ---------------------------------------------------------------
    $driveLetter = $Partition.DriveLetter?.ToString().ToUpper()
    if ($driveLetter -eq $TargetLetter) {
        Write-Success "  > Drive is already on [${TargetLetter}] - No reassignment needed."
        return $true
    } 
    
    
    # ---------------------------------------------------------------
    # Reassign the drive letter to the target drive letter if it
    # doesn't match.
    # ---------------------------------------------------------------    
    $TargetLetterCheck = Get-VolumeGUIDFromDriveLetter $TargetLetter
    $TargetLetterIsFree = [string]::IsNullOrEmpty($TargetLetterCheck)

    if (-not $TargetLetterIsFree) {
        Write-Error "  > ${TargetLetter}:\ is in use by another volume (${TargetLetterCheck}). Please free ${TargetLetter}:\ manually and try again."
        Write-PostError
        return $false
    }

    Write-Message "  > Reassigning [${driveLetter}] to [${TargetLetter}]..."
    $Partition | Set-Partition -NewDriveLetter $TargetLetter

    # $TargetLetterCheck = Get-VolumeGUIDFromDriveLetter $TargetLetter
    # if($TargetLetterCheck -ne $VolumeID) {
    #     Write-Error "  > Drive letter reassignment failed. Expected volume GUID '${VolumeID}', but ${TargetLetter}: has '${TargetLetterCheck}'."
    #     Write-PostError
    #     return $false
    # }

    # ---------------------------------------------------------------
    # Check if the current drive letter matches
    # the target drive letter.
    # ---------------------------------------------------------------
    $Partition = Get-Partition -UniqueId $Partition.UniqueId
    $driveLetter = $Partition.DriveLetter?.ToString().ToUpper()
    if ($driveLetter -ne $TargetLetter) {
            Write-Error "  > Drive letter reassignment failed. Expected drive letter [${TargetLetter}], but [${driveLetter}] was found."
            Write-PostError
            return $false
    } 

    Write-Success "  > Drive successfully reassigned to ${TargetLetter}:\"
    return $true
}