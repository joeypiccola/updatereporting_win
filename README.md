
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

## Know Issues

b

## Design Considerations

c