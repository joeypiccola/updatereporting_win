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
)

$DownloadDirectory = $DownloadDirectory.Replace('/','\')
$PSWindowsUpdateDir = Join-Path -Path $DownloadDirectory -ChildPath 'PSWindowsUpdate'
$PSWindowsUpdateZipFile = $PSWindowsUpdateURL.ToString().Split('/')[$PSWindowsUpdateURL.ToString().split('/').count-1]
$PSWindowsUpdateZipFilePath = Join-Path -Path $DownloadDirectory -ChildPath $PSWindowsUpdateZipFile
$WSUSscnCabFile =  $WSUSscnURL.ToString().Split('/')[$WSUSscnURL.ToString().split('/').count-1]
$WSUSscnCabFilePath = Join-Path -Path $DownloadDirectory -ChildPath $WSUSscnCabFile

Write-Verbose -Message $PSWindowsUpdateURL
Write-Verbose -Message $PSWindowsUpdateForceDownload
Write-Verbose -Message $WSUSscnURL
Write-Verbose -Message $WSUSscnForceDownload
Write-Verbose -Message $DownloadDirectory
Write-Verbose -Message $PSWindowsUpdateDir
Write-Verbose -Message $PSWindowsUpdateZipFile
Write-Verbose -Message $PSWindowsUpdateZipFilePath
Write-Verbose -Message $WSUSscnCabFile
Write-Verbose -Message $WSUSscnCabFilePath

#region helperFunctions

function Expand-ZIPFile($File, $Destination) {
    if (!(Test-Path -Path $Destination)) {
        New-Item -ItemType Directory -Force -Path $Destination
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
        New-Item -ItemType Directory -Path $DownloadDirectory -Force -ErrorAction Stop
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

    # add the previously downloaded wsusscn2.cab file as an Offline Sync Service Manager
    Add-WUServiceManager -ScanFileLocation $WSUSscnCabFilePath -Confirm:$false -ErrorAction Stop
    # get the service ID of the previously added Offline Service Manager
    $offlineServiceManager = Get-WUServiceManager -ErrorAction Stop | ?{$_.name -eq 'Offline Sync Service'}
    # get the missing updates using the previously added Offline Service Manager
    $missingUpdates = Get-WindowsUpdate -ServiceID $offlineServiceManager.ServiceID -ErrorAction Stop
    # get the previously added Offline Sync Service Manager and remove it
    $offlineServiceManager = Get-WUServiceManager | ?{$_.name -eq 'Offline Sync Service'}
    $objServiceManager = New-Object -ComObject "Microsoft.Update.ServiceManager"
    $objService = $objServiceManager.RemoveService($offlineServiceManager.ServiceID)

    # parse the results and stage an external fact
    $updates = $missingUpdates | select kb, title, size, msrcseverity, @{Name="LastDeploymentChangeTime";Expression={$_.lastdeploymentchangetime.tostring("MM-dd-yyyy hh:mm:ss tt")}}
    $kbarray = @()
    $updates | %{$kbarray += $_.kb} | ConvertTo-Csv
    $windowsupdatereporting_col = @()

    $update_meta = [pscustomobject]@{
        missing_update_count = $updates.Count
        missing_update = $updates
        missing_update_kbs = $kbarray
    }

    $scan_meta = [pscustomobject]@{
        last_run_time = (Get-Date -Format "MM-dd-yyyy hh:mm:ss tt")
        wsusscn2_file_time = (Get-Item -Path $WSUSscnCabFilePath).lastwritetime.ToString("MM-dd-yyyy hh:mm:ss tt")
        pswindowsupdate_version = 'tbd'
    }

    $meta = [pscustomobject]@{
        scan_meta = $scan_meta
        update_meta = $update_meta
    }

    $fact_name = [pscustomobject]@{
        updatereporting_win = $meta
    }

    $windowsupdatereporting_col += $fact_name
    $factContent = $windowsupdatereporting_col | ConvertTo-Json -Depth 4
    $factPath = 'C:\ProgramData\PuppetLabs\facter\facts.d\updatereporting.json'
    # force UTF8 with no BOM to make facter happy (Out-File -Encoding UTF8 does not work, Add-Content does not work, >> does not work)
    $Utf8NoBomEncoding = New-Object System.Text.UTF8Encoding $False
    [System.IO.File]::WriteAllLines($factPath, $factContent, $Utf8NoBomEncoding)

} catch {
    Write-Error $_.Exception.Message
    exit 1
}