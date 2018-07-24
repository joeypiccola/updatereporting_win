<#
.SYNOPSIS
Script for gathering installed and missing updates. This script relies on an external copy of the
latest Microsoft Windows Update (WU) offline scan file (WSUSscn2.cab).

.DESCRIPTION
Use this script to generate a report of both missing and installed updates on a windows machine.
This script was originally intendd to be used with puppet but has been adapted to be used as a
standalone.

.PARAMETER WSUSscnURL
A http url of the WSUSscnURL.cab file.
Example: 'http://internal.corp:8081/wsusscnurl.cab'

.PARAMETER WSUSscnForceDownload
Specify this parameter if you want to force the redownload of the WSUSscnURL.cab. This will
overwrite the existing copy (if any).

.PARAMETER DownloadDirectory
Location of where to download WSUSscnURL.cab files. Defaults to C:\Windows\Temp.

.PARAMETER DoNotGeneratePuppetFact
Specify this parameter if you want to use this script independent of puppet. In which case it will
simply output an object of missing and installed updates.

.EXAMPLE
.\Invoke-WindowsUpdateReport.ps1 -wsusscnurl http://internal.corp:8081/wsusscn2.cab -downloaddirectory c:/windows/temp/puppet/updatereporting_win

Generate a Windows update report. Download the prerequisites to
c:/windows/temp/puppet/updatereporting_win. Stage a puppet fact.

.EXAMPLE
.\Invoke-WindowsUpdateReport.ps1 -wsusscnurl http://internal.corp:8081/wsusscn2.cab -downloaddirectory c:/windows/temp/puppet/updatereporting_win -DoNotGeneratePuppetFact

Generate a Windows update report. Download the prerequisites to
c:/windows/temp/puppet/updatereporting_win. Output update report object only and DO NOT stage a
puppet fact. Work with the report results via '-OutVariable report'.
($report | Select-Object -ExpandProperty updatereporting_win).update_meta.missing_update

.INPUTS
None. You cannot pipe objects to .\Invoke-WindowsUpdateReport.ps1

.OUTPUTS
System.Management.Automation.PSCustomObject Only if ran with the DoNotGeneratePuppetFacts parameter.

.NOTES
Version:        2.2
Author:         Joey Piccola
Creation Date:  01.31.18
Last Modified:  07.24.18
Purpose/Change: Used by the puppet module updatereporting_win
#>

[CmdletBinding()]
Param (
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
$WSUSscnCabFile =  $WSUSscnURL.ToString().Split('/')[$WSUSscnURL.ToString().split('/').count-1]
$WSUSscnCabFilePath = Join-Path -Path $DownloadDirectory -ChildPath $WSUSscnCabFile

#region helperFunctions
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
        try {
            $remoteWSUSscnFile = Get-WebFileLastModified -url $WSUSscnURL
        } catch {
            $remoteWSUSscnFile = $null
            Write-Warning "Last modified detection of $WSUSscnCabFile failed."
            Write-Warning "Downloading $WSUSscnCabFile."
        }
        # if the wsusscn2.cab file in the webrepo does not match the local version then redownload it
        if ($localwsusscnFile -ne $remoteWSUSscnFile) {
            Remove-Item -Path $WSUSscnCabFilePath -Force -Confirm:$false -ErrorAction Stop
            Start-BitsTransfer -Source $WSUSscnURL -Destination $DownloadDirectory -ErrorAction Stop
        }
    }

    # Windows Update API Agent, https://msdn.microsoft.com/en-us/library/windows/desktop/aa387099(v=vs.85).aspx
    # Adds or removes the registration of the update service with Windows Update Agent or Automatic Updates.
    $updateServiceManager = New-Object -ComObject 'Microsoft.Update.ServiceManager'
    # Registers a scan package as a service with Windows Update Agent (WUA) and then returns an IUpdateService interface.
    $updateService = $updateServiceManager.AddScanPackageService("Offline Sync Service", $WSUSscnCabFilePath)
    # Searches for updates on a server.
    $updateSearcher = New-Object -ComObject Microsoft.Update.Searcher
    # Gets and sets a ServerSelection value that indicates the server to search for updates.
    $updateSearcher.ServerSelection = 3
    # Gets and sets a site to search when the site to search is not a Windows Update site.
    $updateSearcher.ServiceID = $updateService.ServiceID
    # Performs a synchronous search for updates. The search uses the search options that are currently configured.
    # "IsInstalled=1" finds updates that are installed on the destination computer.
    # "IsHidden=0" finds updates that are not marked as hidden.
    $searchResult = $updateSearcher.Search("IsInstalled=0 and IsHidden=0")
    # A collection of updates that match the search criteria.
    $missingUpdates = $searchResult.Updates
    # Removes a service registration from WUA.
    $objService = $updateServiceManager.RemoveService($updateService.ServiceID)

    $updateCollection = @()
    $missingUpdates | %{
        $updateObject = $null
        $updateObject = [pscustomobject]@{
            KB = "KB" + $_.KBArticleIDs
            LastDeploymentChangeTime = $_.LastDeploymentChangeTime.tostring("MM-dd-yyyy hh:mm:ss tt")
            Size = "$([math]::round($_.maxdownloadsize / 1MB,0))MB"
            MsrcSeverity = $_.MsrcSeverity
            Title = $_.Title
        }
        $updateCollection += $updateObject
    }

    $kbarray = @()
    $updateCollection | %{$kbarray += $_.kb}
    # get installed updates
    $installedkbarray = @()
    $getinstalledUpdates = Get-HotFix
    $getinstalledUpdates | %{$installedkbarray += $_.hotfixid}

    # build an object with all the update info
    $windowsupdatereporting_col = @()
    $update_meta = [pscustomobject]@{
        missing_update_count = $updateCollection.Count
        missing_update = $updateCollection
        missing_update_kbs = $kbarray
        installed_update_count = $getinstalledUpdates.count
        installed_update_kbs = $installedkbarray
    }
    $scan_meta = [pscustomobject]@{
        last_run_time = (Get-Date -Format "MM-dd-yyyy hh:mm:ss tt")
        wsusscn2_file_lastwritetime = (Get-Item -Path $WSUSscnCabFilePath).lastwritetime.ToString("MM-dd-yyyy hh:mm:ss tt")
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