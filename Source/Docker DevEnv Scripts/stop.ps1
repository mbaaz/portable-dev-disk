# FILE: stop.ps1
# Stops the Docker Compose services, and runs database backup
# if the database container is running
param (
    [bool]$silent = $false
)


# ---------------------------------------------------------------
# Configure script
# ---------------------------------------------------------------
Set-Location $PSScriptRoot
. .\config.ps1


# ---------------------------------------------------------------
# While debugging, it's useful to see the configuration values that will be used
# ---------------------------------------------------------------
#Write-Host "Config::          checkStatusScriptName = $checkStatusScriptName" -ForegroundColor Yellow
#Write-Host "Config::        mssqlServiceNamePattern = $mssqlServiceNamePattern" -ForegroundColor Yellow
#Write-Host "Config::  mssqlBackupServiceNamePattern = $mssqlBackupServiceNamePattern" -ForegroundColor Yellow


# ---------------------------------------------------------------
# Get status JSON from check-status.ps1
# ---------------------------------------------------------------
$status = & ".\${checkStatusScriptName}" | ConvertFrom-Json
$mssqlBackupServiceName = $status.allServices | Where-Object { $_ -like $mssqlBackupServiceNamePattern }
#Write-Host "Config::         mssqlBackupServiceName = $mssqlBackupServiceName" -ForegroundColor Yellow


# ---------------------------------------------------------------
# Check if services are already stopped, we're done here!
# ---------------------------------------------------------------
if ($status.isStopped -eq $true) {
    if(-not $silent) {
        Write-Host "Containers are already stopped!" -ForegroundColor Green
    }
    exit 0
    return
}


# ---------------------------------------------------------------
# Determine the name of the MSSQL service
# ---------------------------------------------------------------
$mssqlServiceName = $status.expectedServices | Where-Object { $_ -like $mssqlServiceNamePattern }
if (-not $mssqlServiceName) {
    if(-not $silent) {
        Write-Warning "Could not determine database container name from expected services. Database backup will be skipped!"
    }
    exit 1
    return
}


# ---------------------------------------------------------------
# Only run database backup when database is actually running
# ---------------------------------------------------------------
if ($status.runningServices -contains $mssqlServiceName) {
    if (-not $silent) { 
        Write-Host "Running database backup service: ${mssqlBackupServiceName}" 
        docker compose --profile "*" run --rm $mssqlBackupServiceName
    } else {
        (docker compose --profile "*" run --rm $mssqlBackupServiceName) | Out-Null
    }
} elseif (-not $silent) {
    Write-Host "Database container is not running, skipping backup." -ForegroundColor Green
}


# ---------------------------------------------------------------
# Stop all running containers
# ---------------------------------------------------------------
if (-not $silent) { 
    Write-Host "Stopping containers..." 
    docker compose stop
} else {
    (docker compose stop) | Out-Null
}


# ---------------------------------------------------------------
# ... and Done!
# ---------------------------------------------------------------
if(-not $silent) {
    Write-Host "Done!`n" -ForegroundColor Green
}
