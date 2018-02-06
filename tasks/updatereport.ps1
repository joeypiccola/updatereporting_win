[CmdletBinding()]
Param (
    [Parameter(Mandatory)]
    [System.Uri]$PSWindowsUpdateURL
    ,
    [Parameter()]
    [string]$PSWindowsUpdateForceDownload = 'falase'
    ,
    [Parameter(Mandatory)]
    [System.Uri]$WSUSscnURL
    ,
    [Parameter()]
    [string]$WSUSscnForceDownload = 'falase'
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
    PSWindowsUpdateForceDownload = if ($PSWindowsUpdateForceDownload -eq 'true') {$true} else {$false}
    WSUSscnURL = $WSUSscnURL
    WSUSscnForceDownload = if ($WSUSscnForceDownload -eq 'true') {$true} else {$false}
    DownloadDirectory = $DownloadDirectory
}

$invokeReport = Join-Path -Path $env:ProgramData -ChildPath '/PuppetLabs/puppet/cache/lib/updatereporting_win/Invoke-WindowsUpdateReport.ps1'
. $invokeReport @invokeParams