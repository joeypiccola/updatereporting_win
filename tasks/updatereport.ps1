[CmdletBinding()]
Param (
    [Parameter(Mandatory)]
    [System.Uri]$WSUSscnURL
    ,
    [Parameter()]
    [string]$WSUSscnForceDownload = 'false'
    ,
    [Parameter()]
    [ValidateScript({Test-Path -Path $_ -IsValid})]
    [String]$DownloadDirectory = 'C:\Windows\Temp'
    ,
    # not used for tasks
    [Parameter()]
    [Switch]$DoNotGeneratePuppetFact
)

$invokeParams = @{
    WSUSscnURL = $WSUSscnURL
    WSUSscnForceDownload = if ($WSUSscnForceDownload -eq 'true') {$true} else {$false}
    DownloadDirectory = $DownloadDirectory
}

$invokeReport = Join-Path -Path $env:ProgramData -ChildPath '/PuppetLabs/puppet/cache/lib/updatereporting_win/Invoke-WindowsUpdateReport.ps1'
. $invokeReport @invokeParams
