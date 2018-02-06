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

$invokeParams = @{
    PSWindowsUpdateURL = $PSWindowsUpdateURL
    PSWindowsUpdateForceDownload = $PSWindowsUpdateForceDownload
    WSUSscnURL = $WSUSscnURL
    WSUSscnForceDownload = $WSUSscnForceDownload
    DownloadDirectory = $DownloadDirectory
}

$invokeReport = Join-Path -Path $env:ProgramData -ChildPath '/PuppetLabs/puppet/cache/lib/updatereporting_win/Invoke-WindowsUpdateReport.ps1'
. $invokeReport @invokeParams