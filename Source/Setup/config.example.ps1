# This file is used to set up the environment for the PowerShell scripts in this project.
# It is sourced by the other scripts to ensure that the necessary environment variables and configurations are in place.

# Only while debugging
$DEBUG = $false

# Setup which drive to use for the scripts. This should be the drive where the script is located, but can be overridden for testing purposes.
$UseCurrentDrive = $true
$UseVolumeGUID = ""

# Desired drive letter for the NTFS partition
$TargetLetter = "X"

# Mount point folder name on the NTFS partition
$DevDriveFolderName = "DevDrive"

# Name of the VHD file inside Setup
$VhdFileName = "Setup\DevDrive.vhdx"
