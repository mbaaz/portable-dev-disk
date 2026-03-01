@echo off

echo Requesting Administrator privileges...
powershell -Command "Start-Process powershell -ArgumentList '-NoProfile -ExecutionPolicy Bypass -File \"%~dp0.\Setup-DevDrive.ps1\"' -Verb RunAs"
