# FILE: config.ps1
# Configuration file for Devenv scripts

# Define the check status script name, so it can be used in multiple places without hardcoding the name
$checkStatusScriptName = "check-status.ps1"
$stopScriptName = "stop.ps1"
$startScriptName = "start.ps1"

# Define wildcard pattern for identifying the MSSQL service among the expected services
$mssqlServiceNamePattern = "*-mssql"

# Define wilcard patterns for identifying backup and restore services related to MSSQL service
$mssqlBackupServiceNamePattern = "${mssqlServiceNamePattern}-backup"
$mssqlRestoreServiceNamePattern = "${mssqlServiceNamePattern}-restore"