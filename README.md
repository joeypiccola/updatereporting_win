
# updatereporting_win

Report on missing updates on a Windows machine.

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

At a minimum supply the download locations for the PSWindowsUpdate zip and the wsusscn2.cab file.

## How it works

This module works by first using Puppet to stage a PowerShell script to the local system in `C:\Windows\Temp`. Next, Puppet registers a user defined Scheduled Task to run the previously staged PowerShell script. When the schedule task is triggered the PowerShell script attempts to download a copy of the PSWindowsUpdate zip file if it does not already exist (relative to the default or specified `download_directory`). The PowerShell script also attempts to download a copy of the specified wsusscn2.cab file if 1) it does not already exist or 2) the existing local wsusscn2.cab has a different last modified date than the one specified via the `pswindowsupdate_url`. Once the download requirments have been met, the PowerShell script attempls to load the module, import the wsusscn2.cab file and proceed with generating a report of the missing updates.

### The Report

The missing update report is consumed as an external fact. This is accomlishd by placing a .json file in `C:\ProgramData\PuppetLabs\facter\facts.d\` named `updatereporting.json`. An example of this file is below.

```json
{
  "updatereporting_win": {
    "scan_meta": {
      "last_run_time": "01-19-2018 02:19:17 AM",
      "wsusscn2_file_time": "01-10-2018 03:26:54 PM"
    },
    "update_meta": {
      "missing_update_count": 2,
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
      ]
    }
  }
}
```

### Download Behavior

Downloads only occur during the Windows Schedule task execution (i.e. trigger time). Downloads also leverage the Background Intelligent Transfer Service (BITS).

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

## External Dependencies

### wsusscn2.cab

This module leverages a current copy of the Windows Update offline scan file. This file can be downloaded via http://go.microsoft.com/fwlink/?LinkID=74689. It is suggested to download this ~200MB file and host it internally vs. devising a way to pull it form the Internet.

### PSWindowsUpdate

This module leverages it's own copy of the PSWindowsUpdate module. The PSWindowsUpdate copy must be zip'd up and placed a web server so that it can be downloaded. Even if the system that the puppet-agent is running on already has a copy of the PSWindowsUpdate module retrieved \ installed via some other method (e.g. Nuget \ PackageManagement) and is placed in a valid `$env:PSModulePath` it will not be used. This nature of this decoupling between the system and it's own inventory of PowerShell modules is discussed under Design Considerations.

## Limitations

Time of day scheduling is currently limited to a random time between 12:00AM and 5:59AM. 

The code used to determine the remote file's last modified date has been tested on IIS and Artifactory.

## Know Issues

b

## Design Considerations

c