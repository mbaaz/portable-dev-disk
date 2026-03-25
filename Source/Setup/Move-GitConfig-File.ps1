# FILE: Move-GitConfig-File.ps1
# This will remove the old .gitconfig file from User Home directory
# and replace it with the one stored in GitConfigs directory of this drive


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
Write-Header "MOVE GIT CONFIG FILE"
Write-Config "      GitConfigFilePath: ${GitConfigFilePath}"
Write-Config "RealPathOfGitConfigFile: ${RealPathOfGitConfigFile}"


# ---------------------------------------------------------------
# Make sure the real Git config file exists before proceeding
# ---------------------------------------------------------------
if(-not (Test-Path $RealPathOfGitConfigFile)) {
    Write-Error "Path to Git config file on this drive does not exist! Please check the path and try again."
    Write-PostError
}


# ---------------------------------------------------------------
# Check if git config file already exists in user home directory.
# If it does, we will delete it if it's a symlink, or rename it 
# if it's a real file. 
# ---------------------------------------------------------------
if (Test-Path $GitConfigFilePath) {
    if(Test-FileIsSymlink $GitConfigFilePath) {
        Write-Host "Config file (symlink) already exists - deleting it" -ForegroundColor White
        Remove-Item -Path $GitConfigFilePath | Out-null
    } else {
        Write-Host "Config file already exists - renaming it" -ForegroundColor White
        $DateNow = (Get-Date).ToString("yyMMdd-HHmmss")
        $GitConfigFilePathForCopyOfRealFile = "${GitConfigFilePath}-copy-${DateNow}"
        Move-Item -Path $GitConfigFilePath -Destination $GitConfigFilePathForCopyOfRealFile | Out-null
    }
}


# ---------------------------------------------------------------
# Create a new symlink to the real Git config file on this drive.
# ---------------------------------------------------------------
if (-not (Test-Path $GitConfigFilePath)) {
    New-Item -Path $GitConfigFilePath -ItemType SymbolicLink -Value $RealPathOfGitConfigFile | Out-null
    Write-Host "Config file symlink created!" -ForegroundColor Green
}


# ---------------------------------------------------------------
# ... and Done!
# ---------------------------------------------------------------
Write-EndOfScript