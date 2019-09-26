[CmdletBinding()]
Param (
    [Parameter(Mandatory)]
    [System.Uri]$WSUSscnURL
    ,
    [Parameter()]
    [boolean]$WSUSscnForceDownload = $false
    ,
    [Parameter()]
    [ValidateScript({Test-Path -Path $_ -IsValid})]
    [String]$DownloadDirectory = 'C:\Windows\Temp'
    ,
    [Parameter()]
    [boolean]$UploadFactsWhenDone = $false
    ,
    # not used for tasks
    [Parameter()]
    [Switch]$DoNotGeneratePuppetFact
)

$invokeParams = @{
    WSUSscnURL = $WSUSscnURL
    WSUSscnForceDownload = $WSUSscnForceDownload
    DownloadDirectory = $DownloadDirectory
}

$invokeReport = Join-Path -Path $env:ProgramData -ChildPath '/PuppetLabs/puppet/cache/lib/updatereporting_win/Invoke-WindowsUpdateReport.ps1'
. $invokeReport @invokeParams

if ($UploadFactsWhenDone) { & "$Env:ProgramFiles\Puppet Labs\Puppet\Bin\puppet.bat" facts upload }
