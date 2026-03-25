# FILE: toggle.ps1
# Toggles the Docker Compose services, stopping them if they are running,
# or starting them if they are stopped
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
#Write-Host "Config:: checkStatusScriptName = $checkStatusScriptName" -ForegroundColor Yellow
#Write-Host "Config::        stopScriptName = $stopScriptName" -ForegroundColor Yellow
#Write-Host "Config::       startScriptName = $startScriptName" -ForegroundColor Yellow


# ---------------------------------------------------------------
# Get status JSON from check-status.ps1
# ---------------------------------------------------------------
$status = & ".\${checkStatusScriptName}" | ConvertFrom-Json


# ---------------------------------------------------------------
# Perform toggle action based on status
# ---------------------------------------------------------------
if ($status.isRunning -eq $true) {
    & ".\${stopScriptName}" -silent:$silent
} else {
    & ".\${startScriptName}" -silent:$silent
}
