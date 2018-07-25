# Changelog

All notable changes to this project will be documented in this file.

## Release 0.1.0
Initial release.

## Release 0.1.1
Doc updates.

## Release 0.1.2
Convert CR LF to LF, see PCP-825 for details, updatereport.ps1.

## Release 0.1.3
Removed old params and doc update.

## Release 0.1.3
Removed old params cont...

## Release 0.1.5
Doc update.

## Release 0.1.6

**Features**

**Bugfixes**

Fixed issue for when remote wsusscn2.cab file is newer than local file and PowerShell script attempts to remove it, but fails with the following.

> A parameter cannot be found that matches parameter name 'Path$WSUSscnCabFilePath'.".

**Known Issues**

## Release 0.1.7

**Features**

Add logic to clean up Offline Sync Service if in the event we add the service and error before removing it as part of the standard API logic.

**Bugfixes**

Add exception handling for when Invoke-WindowsUpdateReport.ps1 is unable to pull the LastModified date from the wsusscn2.cab file. Previously the script `Invoke-WindowsUpdateReport.ps1` would exit 1 with the following error.

> Exception calling "GetResponse" with "0" argument(s): "The underlying connection was closed: An unexpected error occurred on a receive."

**Known Issues**