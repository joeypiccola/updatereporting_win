# updatereporting_win

## Description

Puppet module to report on missing and installed updates on a Windows machine.

## Parameters

 * ```wsusscn_url``` - Location of a copy of the wsusscn2.cab.
 * ```wsusscn_force_download``` - [Optional] Overwrite any existing copy of the wsusscn2.cab file that may already exist in the specified `download_directory`. Setting this value to `true` will override the internal logic that only downloads the wsusscn2.cab file if the last modified date has changed from the current version in the specified `download_directory`. Defaults to `false`.
 * ```download_directory``` - [Optional] Location on the local system to place downloaded files (e.g. wsusscn2.cab). Defaults to 'C:\Windows\Temp'.
 * ```task_day_of_week``` - [Optional] Which day of the week the task should run. The day must either  be `mon`, `tues`, `wed`, `thurs`, `fri`, `sat`, `sun`, or `all`. This option is only applicable when `task_schedule` is set to `weekly`. Defaults to `sun`.
 * ```task_every``` - [Optional] How often the task should run, as a number of days or weeks. Defaults to `1`.
 * ```task_schedule``` - [Optional] What kind of trigger this is. Valid values are `daily` and `weekly`. Defaults to `weekly`.
 * ```task_enabled``` - [Optional] Whether the trigger for this task should be enabled. Defaults to `true`.
 * ```task_ensure``` - [Optional] Determines whether the Windows Scheduled task is present. This param allows users to back out of using the updatereporting_win module by first setting this param to `absent`, allowing Puppet to run, and then removing the updatereporting_win class.

## Usage

At a minimum supply the download location the wsusscn2.cab file. It is recommended not to schedule the task too often because the missing update scan requires quite a bit of compute (not to mention the possibility of re-downloading the ~200MB wsusscn2.cab file). As noted in the first example below the default configuration will create a scheduled task to run a scan once a week on Sunday between the hours of 12:00AM and 5:59AM.

### Examples

Download the wsusscn2.cab to `c:\Windows\Temp` and create a scheduled task to run a scan once a week on Sunday between the hours of 12:00AM and 5:59AM.
```ruby
class { 'updatereporting_win':
  wsusscn_url         => 'http://internal.corp:8081/wsusscn2.cab',
}
```

Download the wsusscn2.cab to `c:\Windows\Temp` and create a scheduled task to run a scan every other week on Friday between the hours of 12:00AM and 5:59AM.
```ruby
class { 'updatereporting_win':
  wsusscn_url         => 'http://internal.corp:8081/wsusscn2.cab',
  task_every          => 2
  task_day_of_week    => 'fri'
}
```

Download the wsusscn2.cab to `c:\Windows\Temp\Puppet-Staging` and create a scheduled task to run a scan every day between the hours of 12:00AM and 5:59AM.
```ruby
class { 'updatereporting_win':
  wsusscn_url         => 'http://internal.corp:8081/wsusscn2.cab',
  download_directory  => 'c:/windows/temp/Puppet-Staging',
  task_schedule       => 'daily',
}
```

Download the wsusscn2.cab to `c:\Windows\Temp\Puppet-Staging` and create a scheduled task to run a scan every five days between the hours of 12:00AM and 5:59AM.
```ruby
class { 'updatereporting_win':
  wsusscn_url         => 'http://internal.corp:8081/wsusscn2.cab',
  download_directory  => 'c:/windows/temp/Puppet-Staging',
  task_schedule       => 'daily',
  task_every          => 5
}
```

### The Report

The update report is consumed as an external fact named `updatereporting_win`. An abbreviated example of this fact is below. The report includes the last scan time as well as the last modified time of the local wsusscn2.cab. The `wsusscn2_file_lastwritetime` can be used to determine whether or not the system is using a recent copy of the wsusscn2.cab file (released monthly).

```json
{
  "updatereporting_win": {
    "scan_meta": {
      "last_run_time": "01-19-2018 02:19:17 AM",
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
        "KB3081320"
      ]
    }
  }
}
```

## External Dependencies

### wsusscn2.cab

This module leverages a current copy of the Windows Update offline scan file. This file can be downloaded via http://go.microsoft.com/fwlink/?LinkID=74689. It is suggested to download this ~400MB file and host it internally vs. devising a way to pull it form the Internet for each puppet node.


**Note**: The parameter `wsusscn_url` is not intended to be used with the http://go.microsoft.com/fwlink/?LinkID=74689 URL. The underlying script expects a URL with a `.cab` file.

## How it works

The module's class and task work by executing a PowerShell script located in the module's lib directory. This PowerShell script is dropped in the node's vardir (e.g. `%PROGRAMDATA%\PuppetLabs\puppet\cache`). Next, Puppet registers a scheduled task to run the previously staged PowerShell script. When the schedule task is triggered the PowerShell script attempts to download a copy of the specified wsusscn2.cab file if 1) it does not already exist or 2) the existing local wsusscn2.cab has a different last modified date than the one specified via the `wsusscn_url`**. Once the wsusscn2.cab file has been downloaded the PowerShell script attempts to import the wsusscn2.cab file and proceed with generating a report of missing and installed updates. This is accomplished by placing a .json file in `C:\ProgramData\PuppetLabs\facter\facts.d\` named `updatereporting.json`.

** see limitation #2

### Download Behavior

wsusscn2.cab file downloads only occur during the Windows Schedule task execution (i.e. trigger time). Downloads also leverage the Background Intelligent Transfer Service (BITS).

## Tasks

### updatereport

The task `updatereport` lets you run the underlying update report PowerShell script on-demand. Simply supply a `wsusscn_url` and the task will regenerate a current fact with missing and installed updates. That said, once you run the task puppet will need to run to pickup the created \ regenerated fact.

## Compatibility

updatereporting_win has been tested on the following versions of Windows and PowerShell.

1. Server 2008 R2 (PowerShell v3.0, 4.0, 5.0)
2. Server 2012 R2 (PowerShell v4.0, v5.0)

### Limitations

1. Time of day scheduling is currently limited to a random time between 12:00AM and 5:59AM.
2. The PowerShell script used to determine the remote wsusscn2.cab file's last modified date has been tested on IIS. Not all web servers will provide a last modified date when queried. If the last modified date is unable to be detected then the script will proceed to download the file again.

### Known Issues

1. Because this module is setting up a windows scheduled task, if you ever wish to stop using this module you will first need to define the updatereporting_win class' `$task_ensure` param to `absent`, allow puppet to run, then remove the class.

## Design Considerations

Q: Why use the wsusscn2.cab file?
A: The IUpdateSearcher search method performs a much faster scan when using an offline scan file. Also, having hundreds and potentially thousands of machines query Microsoft doesn't scale (nor does it work in an air gapped environment).