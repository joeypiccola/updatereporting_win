# == Class: updatereporting_win
#
# Puppet module to report on missing and installed updates on a Windows machine.
#
# === Parameters
#
# [*pswindowsupdate_url*]
#   Location of a zipped release of the PSWindowsUpdate PowerShell module.
# *[wsusscn_url*]
#   Location of a copy of the wsusscn2.cab.
# [*download_directory*]
#   [Optional] Location on the local system to place downloaded files (e.g. PSWindowsUpdate PowerShell module and wsusscn2.cab). Defaults to 'C:\Windows\Temp'.
# [*pswindowsupdate_force_download*]
#   [Optional] Overwrite any existing copy of the PSWindowsUpdate module that may already exist in the specified download_directory. Defaults to false.
# [*wsusscn_force_download*]
#   [Optional] Overwrite any existing copy of the wsusscn2.cab file that may already exist in the specified download_directory. Setting this value to true will override the internal logic that only downloads the wsusscn2.cab file if the last modified date has changed from the current version in the specified download_directory. Defaults to false.
# [*task_day_of_week*]
#   [Optional] Which day of the week the task should run. The day must either be mon, tues, wed, thurs, fri, sat, sun, or all. This option is only applicable when task_schedule is set to weekly. Defaults to sun.
# [*task_every*]
#   [Optional] How often the task should run, as a number of days or weeks. Defaults to 1.
# [*task_schedule*]
#   [Optional] What kind of trigger this is. Valid values are daily and weekly. Defaults to weekly.
# [*task_enabled*]
#   [Optional] Whether the trigger for this task should be enabled. Defaults to true.
# [*task_ensure*]
#   [Optional] Determines whether the Windows Scheduled task is present. This param allows users to back out of using the updatereporting_win module by first setting this param to absent, allowing Puppet to run, and then removing the updatereporting_win class.
#
# === Examples
#
# class { 'updatereporting_win':
#   pswindowsupdate_url => 'http://internal.corp:8081/PSWindowsUpdate.zip',
#   wsusscn_url         => 'http://internal.corp:8081/wsusscn2.cab',
# }
#
# === Authors
#
# Joey Piccola <joey@joeypiccola.com>
#
# === Copyright
#
# Copyright (C) 2018 Joey Piccola.
#
class updatereporting_win (

  String $pswindowsupdate_url,
  String $wsusscn_url,
  String $download_directory = 'c:/Windows/Temp',
  Boolean $pswindowsupdate_force_download = false,
  Boolean $wsusscn_force_download = false,
  String $task_day_of_week = 'sun',
  Integer $task_every = 1,
  String $task_schedule = 'weekly',
  Boolean $task_enabled = true,
  String $task_ensure = 'present',

){

  case $pswindowsupdate_force_download {
    true: {
      $pswindowsupdate_force_download_set = '$true'
  }
    default: {
      $pswindowsupdate_force_download_set = '$false'
    }
  }

  case $wsusscn_force_download {
    true: {
      $wsusscn_force_download_set = '$true'
  }
    default: {
      $wsusscn_force_download_set = '$false'
    }
  }

  $min = fqdn_rand(59)
  $hour = fqdn_rand(3)+1
  $cachedir = $facts['puppet_vardir']

  scheduled_task { 'updatereporting_win':
    ensure    => $task_ensure,
    name      => 'Windows Update Reporting (Puppet Managed Scheduled Task)',
    enabled   => $task_enabled,
    command   => 'C:\\Windows\\System32\\WindowsPowerShell\\v1.0\\powershell.exe',
    arguments => "-WindowStyle Hidden -ExecutionPolicy Bypass \"${cachedir}/lib/updatereporting_win/Invoke-WindowsUpdateReport.ps1 -pswindowsupdateurl ${pswindowsupdate_url} -wsusscnurl ${wsusscn_url} -pswindowsupdateforcedownload:${pswindowsupdate_force_download_set} -wsusscnforcedownload:${wsusscn_force_download_set} -downloaddirectory ${download_directory}\"",
    provider  => 'taskscheduler_api2',
    trigger   => {
      schedule    => $task_schedule,
      every       => $task_every,
      day_of_week => $task_day_of_week,
      start_time  => "${hour}:${min}",
    }
  }
}
