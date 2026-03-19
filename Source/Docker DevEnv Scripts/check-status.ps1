# FILE: check-status.ps1
# DESCRIPTION: Checks the status of Docker Compose services


# ---------------------------------------------------------------
# Configure script
# ---------------------------------------------------------------
$ErrorActionPreference = "SilentlyContinue"
Set-Location $PSScriptRoot


# ---------------------------------------------------------------
# Query Docker Compose for expected and running services
# ---------------------------------------------------------------
$all      = docker compose --profile "*" config --services 2>$null | ForEach-Object { $_.Trim() } | Where-Object { $_ }
$expected = docker compose config --services 2>$null | ForEach-Object { $_.Trim() } | Where-Object { $_ }
$running  = docker compose ps --status running --services 2>$null | ForEach-Object { $_.Trim() } | Where-Object { $_ }


# ---------------------------------------------------------------
# Determine if any expected services are not running
# ---------------------------------------------------------------
$missing = @()
if ($expected) {
    $missing = $expected | Where-Object { $running -notcontains $_ }
}


# ---------------------------------------------------------------
# Compose a result object
# ---------------------------------------------------------------
$result = [PSCustomObject]@{
    isRunning  = ($expected.Count -gt 0 -and $missing.Count -eq 0)
    isRunningStr = ("" + ($expected.Count -gt 0 -and $missing.Count -eq 0) + "").ToLower()
    isStopped = ($expected.Count -gt 0 -and $running.Count -eq 0)
    expectedServices = $expected
    runningServices = $running
    missingServices  = $missing
    allServices = $all
}


# ---------------------------------------------------------------
# Return the result as JSON
# ---------------------------------------------------------------
$result | ConvertTo-Json -Compress
