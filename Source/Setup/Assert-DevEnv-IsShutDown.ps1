# FILE: Assert-DevEnv-IsShutDown.ps1
# This script checks the status of the Docker DevEnvironments
# defined in the configuration and attempts to stop any that are
# currently running.
Push-Location


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
Write-Header "ASSERT DOCKER DEV ENVIRONMENTS ARE SHUT DOWN"


# ---------------------------------------------------------------
# Check status of each Dev Environment and stop if running
# ---------------------------------------------------------------
$vhd = Get-DiskImage -ImagePath $DevDriveVhdPath
if($vhd.Attached -eq $false) {
    Write-Message "Virtual Dev Drive is not mounted - scripts unavailable."
    exit 0
    return
}


# ---------------------------------------------------------------
# Check status of each Dev Environment and stop if running
# ---------------------------------------------------------------
$DockerDevEnvironments | ForEach-Object {
    $path = $_.Path
    $name = $_.Name
    $checkScriptPath = $_.CheckScriptPath
    $stopScriptPath = $_.StopScriptPath
    Write-Message "Checking Dev Environment: ${name}"

    $checkScriptFullPath = Join-Path $path $checkScriptPath
    if(-not (Test-Path $checkScriptFullPath)) {
        Write-Error "  > Check script not found! Expected at path: ${checkScriptFullPath}"
        continue
    }

    $status = (& $checkScriptFullPath 2>&1 | ConvertFrom-Json).isStopped
    if($status -eq $false) {
        Write-Message "  > Containers are currently running."

        $stopScriptFullPath = Join-Path $path $stopScriptPath
        if(-not (Test-Path $stopScriptFullPath)) {
            Write-Error "  > Stop script not found! Expected at path: ${stopScriptFullPath}"
            continue
        }
        (& $stopScriptFullPath -silent $true 1>$null 2>&1) | Out-Null
        Write-Message "  > Stopped containers."
    } else {
        Write-Message "  > Containers are not running."
    }
}


# ---------------------------------------------------------------
# ... and Done!
# ---------------------------------------------------------------
Pop-Location
Write-EndOfScript