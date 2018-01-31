
# updatereporting_win

Puppet module to report on missing and installed updates on a Windows machine.

## Parameters

 * ```pswindowsupdate_url``` - Location of a zipped release of the PSWindowsUpdate PowerShell module.
 * ```wsusscn_url``` - Location of a copy of the wsusscn2.cab.
 * ```download_directory``` - [Optional] Location on the local system to place downloaded files (e.g. PSWindowsUpdate PowerShell module and wsusscn2.cab). Defaults to 'C:\Windows\Temp'.
 * ```pswindowsupdate_force_download``` - [Optional] Overwrite any existing copy of the PSWindowsUpdate module that may already exist in the specified `download_directory`. Defaults to `false`.
 * ```wsusscn_force_download``` - [Optional] Overwrite any existing copy of the wsusscn2.cab file that may already exist in the specified `download_directory`. Setting this value to `true` will override the internal logic that only downloads the wsusscn2.cab file if the last modified date has changed from the current version in the specified `download_directory`. Defaults to `false`.
 * ```task_day_of_week``` - [Optional] Which day of the week the task should run. The day must either  be `mon`, `tues`, `wed`, `thurs`, `fri`, `sat`, `sun`, or `all`. This option is only applicable when `task_schedule` is set to `weekly`. Defaults to `sun`.
 * ```task_every``` - [Optional] How often the task should run, as a number of days or weeks. Defaults to `1`.
 * ```task_schedule``` - [Optional] What kind of trigger this is. Valid values are `daily` and `weekly`. Defaults to `weekly`.
 * ```task_enabled``` - [Optional] Whether the trigger for this task should be enabled. Defaults to `true`.
 * ```task_ensure``` - [Optional] Determines whether the Windows Scheduled task is present. This param allows users to back out of using the updatereporting_win module by first setting this param to `absent`, allowing Puppet to run, and then removing the updatereporting_win class.

## Usage

At a minimum supply the download locations for the PSWindowsUpdate zip and the wsusscn2.cab file. It is recommended not to schedule the task too often because the missing update scan requires quite a bit of compute (not to mention the possibility of re-downloading the ~200MB wsusscn2.cab file). As noted in the first example below the default configuration will create a scheduled task to run a scan once a week on Sunday between the hours of 12:00AM and 5:59AM.

## Examples

Download both external dependencies to `c:\Windows\Temp` and create a scheduled task to run a scan once a week on Sunday between the hours of 12:00AM and 5:59AM.
```ruby
class { 'updatereporting_win':
  pswindowsupdate_url => 'http://internal.corp:8081/PSWindowsUpdate.zip',
  wsusscn_url         => 'http://internal.corp:8081/wsusscn2.cab',
}
```

Download both external dependencies to `c:\Windows\Temp` and create a scheduled task to run a scan every other week on Friday between the hours of 12:00AM and 5:59AM.
```ruby
class { 'updatereporting_win':
  pswindowsupdate_url => 'http://internal.corp:8081/PSWindowsUpdate.zip',
  wsusscn_url         => 'http://internal.corp:8081/wsusscn2.cab',
  task_every          => 2
  task_day_of_week    => 'fri'
}
```

Download both external dependencies to `c:\Windows\Temp\Puppet-Staging` and create a scheduled task to run a scan every day between the hours of 12:00AM and 5:59AM.
```ruby
class { 'updatereporting_win':
  pswindowsupdate_url => 'http://internal.corp:8081/PSWindowsUpdate.zip',
  wsusscn_url         => 'http://internal.corp:8081/wsusscn2.cab',
  download_directory  => 'c:/windows/temp/Puppet-Staging',
  task_schedule       => 'daily',
}
```

Download both external dependencies to `c:\Windows\Temp\Puppet-Staging` and create a scheduled task to run a scan every five days between the hours of 12:00AM and 5:59AM.
```ruby
class { 'updatereporting_win':
  pswindowsupdate_url => 'http://internal.corp:8081/PSWindowsUpdate.zip',
  wsusscn_url         => 'http://internal.corp:8081/wsusscn2.cab',
  download_directory  => 'c:/windows/temp/Puppet-Staging',
  task_schedule       => 'daily',
  task_every          => 5
}
```

## The Report

The update report is consumed as an external fact named `updatereporting_win`. An example of this fact is below. The report includes the last scan time as well as the last modified time of the local wsusscn2.cab.

```json
{
  "updatereporting_win": {
    "scan_meta": {
      "last_run_time": "01-19-2018 02:19:17 AM",
      "pswindowsupdate_version" : "2.0.0.3",
      "wsusscn2_file_lastwritetime": "01-10-2018 03:26:54 PM"
    },
    "update_meta": {
      "missing_update_count": 2,
      "installed_update_count" : 4,
      "missing_update": [
        {
          "KB": "KB3000483",
          "Title": "Security Update for Windows Server 2012 R2 (KB3000483)",
          "Size": "6MB",
          "MsrcSeverity": "Critical",
          "LastDeploymentChangeTime": "02-10-2015 12:00:00 AM"
        },
        {
          "KB": "KB4048961",
          "Title": "2017-11 Security Only Quality Update for Windows Server 2012 R2 for x64-based Systems (KB4048961)",
          "Size": "23MB",
          "MsrcSeverity": "Critical",
          "LastDeploymentChangeTime": "11-14-2017 12:00:00 AM"
        }
      ],
      "missing_update_kbs": [
        "KB3000483",
        "KB4048961"
      ],
      "installed_update_kbs" : [
        "KB3134758",
        "KB2843630",
        "KB3042058",
        "KB3081320",
      ]
    }
  }
}
```

## External Dependencies

### wsusscn2.cab

This module leverages a current copy of the Windows Update offline scan file. This file can be downloaded via http://go.microsoft.com/fwlink/?LinkID=74689. It is suggested to download this ~200MB file and host it internally vs. devising a way to pull it form the Internet for each puppet node.

### PSWindowsUpdate

This module leverages an external copy of the PSWindowsUpdate module (written by Michal Gajda). Currently tested with version `2.0.0.3` The PSWindowsUpdate module must be zip'd up and placed on a web server so that it can be downloaded. Even if the system that the puppet-agent is running on already has a copy of the PSWindowsUpdate module retrieved \ installed via some other method (e.g. Nuget \ PackageManagement) and is placed in a valid `$env:PSModulePath` it will not be used. This nature of this decoupling between the system and it's own inventory of PowerShell modules is discussed under Design Considerations. A current copy of the Michal Gajda's PSWindowsUpdate module can be downloaded via `Save-Module -Name PSWindowsUpdate -Path <path>`. For more information see the PowerShell Gallery https://www.powershellgallery.com/packages/PSWindowsUpdate/.

## How it works

This module works by first using Puppet to stage a PowerShell script to the local system in `C:\Windows\Temp`. Next, Puppet registers scheduled task to run the previously staged PowerShell script. When the schedule task is triggered the PowerShell script attempts to download a copy of the PSWindowsUpdate zip file if it does not already exist (relative to the default or specified `download_directory`). The PowerShell script also attempts to download a copy of the specified wsusscn2.cab file if 1) it does not already exist or 2) the existing local wsusscn2.cab has a different last modified date than the one specified via the `wsusscn_url`. Once the download requirements have been met, the PowerShell script attempts to load the module, import the wsusscn2.cab file and proceed with generating a report of mising updates. This is accomplished by placing a .json file in `C:\ProgramData\PuppetLabs\facter\facts.d\` named `updatereporting.json`.

## Limitations

1. If you're using this module on a system that is running PowerShell Version 3.0 then you will need to modify the PSWindowsUpdate module manifest file's `PowerShellVersion` from `PowerShellVersion = '3.0.0.0'` to `PowerShellVersion = '3.0'`. If you do not do this then you'll get the following error on the PSWindowsUpdate module import.

```plaintext
Import-Module : The version of the loaded Windows PowerShell is '3.0'. The module 'C:\Windows\Temp\PSWindowsUpdate\2.0.0.3\PSWindowsUpdate.psd1' requires a minimum Windows PowerShell version of '3.0.0.0' to run. Please verify the installation of the Windows PowerShell and try again.
```

2. Time of day scheduling is currently limited to a random time between 12:00AM and 5:59AM.
3. The PowerShell script used to determine the remote wsusscn2.cab file's last modified date has been tested on IIS and Artifactory. Not all web servers will provide a last modified date when queried.

## Download Behavior

Downloads only occur during the Windows Schedule task execution (i.e. trigger time). Downloads also leverage the Background Intelligent Transfer Service (BITS).

## Design Considerations

Q: Why not leverage a system's local copy of the PSWindowsUpdate module located in a `$env:PSModulePath`?  
A: The module was designed to be backwards compatible with older version of PowerShell. It was too difficult to 1) detect if PackageManagement had been installed along with Nuget, 2) what version of PSWindowsUpdate was already installed, if any and 3) installing PSWindowsUpdate via the Internet which may not be accessible or other internal Nuget Feed. Supplying a supplemental copy of the PSWindowsUpdate module via a URL is the easiest and cleanest approach to ensure updatereporting_win has what it needs.

Q: Why not bundle the PSWindowsUpdate module in the updatereporting_win module.  
A: Although the PSWindowsUpdate module is publicly available, Michal Gajda holds the CopyRight.

Q: Why use the wsusscn2.cab file?  
A: PSWindowsUpdate performs a much faster scan when using an offline scan file. Also, having hundreds and potentially thousands of machines query Microsoft doesn't scale (nor does it work in an air gapped environment).

## Known Issues

1. Because this module is setting up a windows scheduled task, if you ever wish to stop using this module you will first need to define the updatereporting_win class' `$task_ensure` param to `absent`.s