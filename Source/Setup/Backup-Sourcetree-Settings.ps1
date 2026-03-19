# FILE: Backup-Sourcetree-Settings.ps1
# This script will backup the Sourcetree settings to a specified
# location. It should be run as administrator to ensure it has
# the necessary permissions to access the files.


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
Write-Header "BACKUP SOURCETREE SETTINGS"


# ---------------------------------------------------------------
# This script should be run as administrator, so we will check
# for that before proceeding
# ---------------------------------------------------------------
Assert-RunningAsAdministrator


# ---------------------------------------------------------------
# Check if Sourcetree is running - and try to close it if it is
# ---------------------------------------------------------------
$sourcetreeProcess = Get-Process -Name "Sourcetree" -ErrorAction SilentlyContinue
if ($sourcetreeProcess) {
    Write-Warning "Sourcetree is currently running. Attempting to close it to ensure settings are saved..."
    try {
        $sourcetreeProcess.CloseMainWindow() | Out-Null
        Start-Sleep -Seconds 5
        if (!$sourcetreeProcess.HasExited) {
            Write-Warning "Sourcetree did not close gracefully. Forcing it to close..."
            $sourcetreeProcess.Kill()
            Start-Sleep -Seconds 2
        }
        Write-Message "Sourcetree closed successfully."
    } catch {
        Write-Error "Failed to close Sourcetree: $_"
        Write-PostError
    }
} else {
    Write-Message "Sourcetree is not running."
}

# ---------------------------------------------------------------
# Perform backup of Sourcetree settings
# ---------------------------------------------------------------
function Copy-FileWithCheck($source, $destination) {
    if (Test-Path $source) {
        Copy-Item -Path $source -Destination $destination -Force
        Write-Message "Backed up $(Split-Path $source -Leaf)"
    } else {
        Write-Warning "Source file not found: $source. Skipping."
    }
}
$SourcetreeSettingsFiles | ForEach-Object {
    Copy-FileWithCheck -source (Join-Path $SourcetreeSettingsLocalPath $_) -destination $SourcetreeSettingsBackupPath
}


# ---------------------------------------------------------------
# ... and Done!
# ---------------------------------------------------------------
Write-EndOfScript