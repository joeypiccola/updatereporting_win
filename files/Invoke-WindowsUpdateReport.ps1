<#
.SYNOPSIS
Script for gathering installed and missing updates via an external copy of the PSWindowsUpdate
module. This script relies on an external copy of the latest Microsoft Windows Update (WU) 
offline scan file (WSUSscn2.cab).

.DESCRIPTION
Use this script to generate a report of both missing and installed updates on a windows machine.
The script is a wrapper for PSWindowsUpdate so that it handles all prerequisites to be used offline.
This script was originally intendd to be used with puppet but has been adapted to be used as a 
standalone. 

.PARAMETER PSWindowsUpdateURL
A http url of the PSWindowsUpdate module zip file.
Example: 'http://internal.corp:8081/PSWindowsUpdate.zip'

.PARAMETER PSWindowsUpdateForceDownload
Specify this parameter if you want to force the redownload of the PSWindowsUpdate module zip. This
will overwrite the existing copy (if any).

.PARAMETER WSUSscnURL
A http url of the WSUSscnURL.cab file.
Example: 'http://internal.corp:8081/wsusscnurl.cab'

.PARAMETER WSUSscnForceDownload
Specify this parameter if you want to force the redownload of the WSUSscnURL.cab. This will
overwrite the existing copy (if any).

.PARAMETER DownloadDirectory
Location of where to download the PSWindowsUpdate.zip and WSUSscnURL.cab files. Defaults to 
C:\Windows\Temp.

.PARAMETER DoNotGeneratePuppetFact
Specify this parameter if you want to use this script independent of puppet. In which case it will
simply output an object of missing and installed updates.

.EXAMPLE
.\Invoke-WindowsUpdateReport.ps1 -pswindowsupdateurl http://internal.corp:8081/pswindowsupdate.zip -wsusscnurl http://internal.corp:8081/wsusscn2.cab -downloaddirectory c:/windows/temp/puppet/updatereporting_win

Generate a Windows update report. Download the prerequisites to 
c:/windows/temp/puppet/updatereporting_win. Stage a puppet fact.

.EXAMPLE
.\Invoke-WindowsUpdateReport.ps1 -pswindowsupdateurl http://internal.corp:8081/pswindowsupdate.zip -wsusscnurl http://internal.corp:8081/wsusscn2.cab -downloaddirectory c:/windows/temp/puppet/updatereporting_win -DoNotGeneratePuppetFact

Generate a Windows update report. Download the prerequisites to 
c:/windows/temp/puppet/updatereporting_win. Output update report object only and DO NOT stage a 
puppet fact. Work with the report results via '-OutVariable report'. 
($report | Select-Object -ExpandProperty updatereporting_win).update_meta.missing_update

.INPUTS
None. You cannot pipe objects to .\Invoke-WindowsUpdateReport.ps1

.OUTPUTS
PSWindowsUpdate.WindowsUpdate Only if ran with the DoNotGeneratePuppetFacts parameter. 

.NOTES
Version:        1.0
Author:         Joey Piccola
Creation Date:  01.31.18
Purpose/Change: Used by the puppet module updatereporting_win
#>

[CmdletBinding()]
Param (
    [Parameter(Mandatory)]
    [System.Uri]$PSWindowsUpdateURL
    ,
    [Parameter()]
    [Switch]$PSWindowsUpdateForceDownload
    ,
    [Parameter(Mandatory)]
    [System.Uri]$WSUSscnURL
    ,
    [Parameter()]
    [Switch]$WSUSscnForceDownload
    ,
    [Parameter()]
    [ValidateScript({Test-Path -Path $_ -IsValid})]
    [String]$DownloadDirectory = 'C:\Windows\Temp'
    ,
    [Parameter()]
    [Switch]$DoNotGeneratePuppetFact
)

$DownloadDirectory = $DownloadDirectory.Replace('/','\')
$PSWindowsUpdateDir = Join-Path -Path $DownloadDirectory -ChildPath 'PSWindowsUpdate'
$PSWindowsUpdateZipFile = $PSWindowsUpdateURL.ToString().Split('/')[$PSWindowsUpdateURL.ToString().split('/').count-1]
$PSWindowsUpdateZipFilePath = Join-Path -Path $DownloadDirectory -ChildPath $PSWindowsUpdateZipFile
$WSUSscnCabFile =  $WSUSscnURL.ToString().Split('/')[$WSUSscnURL.ToString().split('/').count-1]
$WSUSscnCabFilePath = Join-Path -Path $DownloadDirectory -ChildPath $WSUSscnCabFile

#region helperFunctions
function Expand-ZIPFile($File, $Destination) {
    if (!(Test-Path -Path $Destination)) {
        New-Item -ItemType Directory -Force -Path $Destination | Out-Null
    }
    $shell = new-object -com shell.application
    $zip = $shell.NameSpace($file)
    foreach($item in $zip.items()) {
        $shell.Namespace($Destination).copyhere($item)
    }
}

function Get-WebFileLastModified($url) {
    $webRequest = [System.Net.HttpWebRequest]::Create($url);
    $webRequest.Method = "HEAD";
    $webResponse = $webRequest.GetResponse()
    $remoteLastModified = ($webResponse.LastModified) -as [DateTime] 
    $webResponse.Close()
    Write-Output $remoteLastModified
}
#endregion

try {
    # if the specified working directory does not exist try and make it
    if (!(Test-Path -Path $DownloadDirectory)) {
        New-Item -ItemType Directory -Path $DownloadDirectory -Force -ErrorAction Stop | Out-Null
    }

    # import the BitsTransfer module
    Import-Module -Name BitsTransfer -ErrorAction Stop

    # download the pswindowsupdate module
    if (!(Test-Path -Path $PSWindowsUpdateDir) -or ($PSWindowsUpdateForceDownload -eq $true)) {
        # remove pswindowsupdate dir if it exists
        if (Test-Path -Path $PSWindowsUpdateDir) {
            Remove-Item -Path $PSWindowsUpdateDir -Recurse -Force -ErrorAction Stop
        }
        # download the pswindowsupdate module, automatically overwrite the zip if already present
        Start-BitsTransfer -Source $PSWindowsUpdateURL -Destination $DownloadDirectory -ErrorAction Stop
        # unzip the module
        Expand-ZIPFile -File $PSWindowsUpdateZipFilePath -Destination $PSWindowsUpdateDir
        # remove the module zip file
        Remove-Item -Path $PSWindowsUpdateZipFilePath -Force -ErrorAction Stop
    }

    # download the wsusscn2.cab file
    if (!(Test-Path -Path $WSUSscnCabFilePath) -or (($WSUSscnForceDownload -eq $true) -and (Test-Path -Path $WSUSscnCabFilePath))) {
        # remove the wsusscn2.cab if it exists
        if (Test-Path -Path $WSUSscnCabFilePath) {
            Remove-Item -Path $WSUSscnCabFilePath -Force -Confirm:$false -ErrorAction Stop
        }
        # download the wsusscn2.cab
        Start-BitsTransfer -Source $WSUSscnURL -Destination $DownloadDirectory -ErrorAction Stop
    } else {
        $localwsusscnFile = (Get-Item -Path $WSUSscnCabFilePath).LastWriteTime
        $remoteWSUSscnFile = Get-WebFileLastModified -url $WSUSscnURL
        # if the wsusscn2.cab file in the webrepo does not match the local version then redownload it
        if ($localwsusscnFile -ne $remoteWSUSscnFile) {
            Remove-Item -Path$WSUSscnCabFilePath -Force -Confirm:$false -ErrorAction Stop
            Start-BitsTransfer -Source $WSUSscnURL -Destination $DownloadDirectory -ErrorAction Stop
        }
    }

    # import the pswindowesupdate module
    Import-Module (Get-ChildItem -Filter "*.psd1" -Path $PSWindowsUpdateDir -Recurse).FullName -ErrorAction Stop
    # get any previous Offline Service Managers and remove them manually
    $offlineServiceManagers = Get-WUServiceManager | ?{$_.name -eq 'Offline Sync Service'}
    if ($offlineServiceManagers) {
        foreach ($offlineServiceManager in $offlineServiceManagers) {
            $objServiceManager = $null
            $objServiceManager = New-Object -ComObject "Microsoft.Update.ServiceManager"
            $objService = $objServiceManager.RemoveService($offlineServiceManager.ServiceID)
        }
    }

    # add the previously downloaded wsusscn2.cab file as an Offline Sync Service Manager, this outputs an object. 
    $offlineServiceManager = Add-WUServiceManager -ScanFileLocation $WSUSscnCabFilePath -Confirm:$false -ErrorAction Stop
    # get the missing updates using the previously added Offline Service Manager
    $missingUpdates = Get-WindowsUpdate -ServiceID $offlineServiceManager.ServiceID -ErrorAction Stop
    # remove the previously added Offline Sync Service Manager. Remove-WUServiceManager does not work as of v2.0.0.0
    $objServiceManager = New-Object -ComObject "Microsoft.Update.ServiceManager"
    $objService = $objServiceManager.RemoveService($offlineServiceManager.ServiceID)

    # parse the results
    $updates = $missingUpdates | select kb, title, size, msrcseverity, @{Name="LastDeploymentChangeTime";Expression={$_.lastdeploymentchangetime.tostring("MM-dd-yyyy hh:mm:ss tt")}}        
    $kbarray = @()
    $updates | %{$kbarray += $_.kb}        
    # get installed updates
    $installedkbarray = @()
    $getinstalledUpdates = Get-HotFix
    $installedUpdates = $getinstalledUpdates | %{$installedkbarray += $_.hotfixid}

    # build an object with all the update info
    $windowsupdatereporting_col = @()   
    $update_meta = [pscustomobject]@{
        missing_update_count = $updates.Count
        missing_update = $updates
        missing_update_kbs = $kbarray
        installed_update_count = $getinstalledUpdates.count
        installed_update_kbs = $installedkbarray
    }   
    $scan_meta = [pscustomobject]@{
        last_run_time = (Get-Date -Format "MM-dd-yyyy hh:mm:ss tt")
        wsusscn2_file_lastwritetime = (Get-Item -Path $WSUSscnCabFilePath).lastwritetime.ToString("MM-dd-yyyy hh:mm:ss tt")
        # getting the version this way might conflict with a version loaded in a $env:PSModulePath
        pswindowsupdate_version = (Get-Module pswindowsupdate).Version.ToString()
    }   
    $meta = [pscustomobject]@{
        scan_meta = $scan_meta
        update_meta = $update_meta
    }   
    $fact_name = [pscustomobject]@{
        updatereporting_win = $meta
    }   
    $windowsupdatereporting_col += $fact_name

    if (!($DoNotGeneratePuppetFact)) {
        $factContent = $windowsupdatereporting_col | ConvertTo-Json -Depth 4
        $factPath = 'C:\ProgramData\PuppetLabs\facter\facts.d\updatereporting.json'    
        # force UTF8 with no BOM to make facter happy (Out-File -Encoding UTF8 does not work, Add-Content does not work, >> does not work)
        $Utf8NoBomEncoding = New-Object System.Text.UTF8Encoding $False
        [System.IO.File]::WriteAllLines($factPath, $factContent, $Utf8NoBomEncoding)
    } else {
        Write-Output $windowsupdatereporting_col
    }

} catch {
    Write-Error $_.Exception.Message
    exit 1
}