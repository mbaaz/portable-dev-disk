# FILE: start.ps1
# Starts the Docker Compose services, and runs database restore
# if the database container was not already running
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
#Write-Host "Config:: mssqlRestoreServiceNamePattern = $mssqlRestoreServiceNamePattern" -ForegroundColor Yellow


# ---------------------------------------------------------------
# Get status JSON from check-status.ps1
# ---------------------------------------------------------------
$status = & ".\${checkStatusScriptName}" | ConvertFrom-Json
$mssqlRestoreServiceName = $status.allServices | Where-Object { $_ -like $mssqlRestoreServiceNamePattern }
#Write-Host "Config::        mssqlRestoreServiceName = $mssqlRestoreServiceName" -ForegroundColor Yellow


# ---------------------------------------------------------------
# Check if services are already running, we're done here!
# ---------------------------------------------------------------
if ($status.isRunning -eq $true) {
    if(-not $silent) {
        Write-Host "Containers are already running!" -ForegroundColor Green
    }
    exit 0
    return
} 


# ---------------------------------------------------------------
# Start all default services
# ---------------------------------------------------------------
if(-not $silent) {
    Write-Host "Starting containers..."
    docker compose up -d
} else {
    (docker compose up -d) | Out-Null
}


# ---------------------------------------------------------------
# Determine the name of the MSSQL service
# ---------------------------------------------------------------
$mssqlServiceName = $status.expectedServices | Where-Object { $_ -like $mssqlServiceNamePattern }
if (-not $mssqlServiceName) {
    if(-not $silent) {
        Write-Warning "Could not determine database container name from expected services. Database restore will be skipped!"
    }
    exit 1
    return
} 


# ---------------------------------------------------------------
# If MSSQL service was not already running, we will run the
# restore job to initialize the database
# ---------------------------------------------------------------
if (-not ($status.runningServices -contains $mssqlServiceName)) {
    if(-not $silent) {
        Write-Host "Running database restore service: ${mssqlRestoreServiceName}"
        docker compose --profile "*" run --rm $mssqlRestoreServiceName
    } else {
        (docker compose --profile "*" run --rm $mssqlRestoreServiceName) | Out-Null
    }
} elseif(-not $silent) {
    Write-Host "Database container is already running, skipping restore." -ForegroundColor Green
}


# ---------------------------------------------------------------
# ... and Done!
# ---------------------------------------------------------------
if(-not $silent) {
    Write-Host "Done!`n" -ForegroundColor Green
}
