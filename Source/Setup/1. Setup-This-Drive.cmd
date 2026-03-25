@echo off

echo Requesting Administrator privileges...
pwsh -Command "Start-Process pwsh -ArgumentList '-NoProfile -ExecutionPolicy Bypass -File \"%~dp0.\Setup-This-Drive.ps1\"' -Verb RunAs"
