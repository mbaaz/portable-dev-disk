@echo off

echo Requesting Administrator privileges...
pwsh -Command "Start-Process pwsh -ArgumentList '-NoProfile -ExecutionPolicy Bypass -File \"%~dp0.\Perform-Backup.ps1\"' -Verb RunAs"
