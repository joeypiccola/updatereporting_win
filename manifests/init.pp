# == Class: puppet_win
#
#
#    
# exec { 'puppet_win_run_file':
#   command   => "& C:\\windows\\temp\\Invoke-WindowsUpdateReport.ps1 -pswindowsupdateurl ${pswindowsupdateurl} -wsusscnurl ${wsusscnurl} -pswindowsupdateforcedownload:${pswindowsupdateforcedownload_set} -wsusscnforcedownload:${wsusscnforcedownload_set} -downloaddirectory ${downloaddirectory}",
#   provider  => 'powershell',
#   logoutput => true,
# }
#
# === Parameters
#
# [*value*]
#   The timezone to use. For a full list of available timezone run tzutil /l.
#   Use the listed time zone ID (e.g. 'Eastern Standard Time')
#
# === Examples
#
#  class { ::puppet_win:
#    timezone = 'Mountain Standard Time',
#  }
#
# === Authors
#
# Joey Piccola <joey@joeypiccola.com>
#
# === Copyright
#
# Copyright (C) 2016 Joey Piccola.
#
class puppet_win (

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

  file { 'puppet_win_stage_file':
    ensure => 'present',
    source => 'puppet:///modules/puppet_win/Invoke-WindowsUpdateReport.ps1',
    path   => 'c:/windows/temp/Invoke-WindowsUpdateReport.ps1',
    before => Scheduled_task['updatereporting_win'],
  }

  $min = fqdn_rand(59)
  $hour = fqdn_rand(3)+1

  scheduled_task { 'updatereporting_win':
    ensure    => $task_ensure,
    name      => 'Windows Update Reporting (Puppet Managed Scheduled Task)',
    enabled   => $task_enabled,
    command   => 'C:\\Windows\\System32\\WindowsPowerShell\\v1.0\\powershell.exe',
    arguments => "-WindowStyle Hidden -ExecutionPolicy Bypass \"C:\\windows\\temp\\Invoke-WindowsUpdateReport.ps1 -pswindowsupdateurl ${pswindowsupdate_url} -wsusscnurl ${wsusscn_url} -pswindowsupdateforcedownload:${pswindowsupdate_force_download_set} -wsusscnforcedownload:${wsusscn_force_download_set} -downloaddirectory ${download_directory}\"",
    provider  => 'taskscheduler_api2',
    trigger   => {
      schedule    => $task_schedule,
      every       => $task_every,
      day_of_week => $task_day_of_week,
      start_time  => "${hour}:${min}",
    }
  }
}
