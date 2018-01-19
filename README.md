
# updatereporting_win

Report on missing updates on a Windows machine.

## Parameters

 * ```pswindowsupdate_url``` - Location of a zipped release of the PSWindowsUpdate PowerShell module.
 * ```wsusscn_url``` - Location of a copy of the wsusscn2.cab.
 * ```download_directory``` - [Optional] Location on the local system to place downloaded files (e.g. PSWindowsUpdate PowerShell module and wsusscn2.cab). Defaults to 'C:\Windows\Temp'.
 * ```pswindowsupdate_force_download``` - [Optional] Overwrite any existing copy of the PSWindowsUpdate module that may already exist in the specified `download_directory`. Defaults to 'false'.
 * ```wsusscn_force_download``` - [Optional] Overwrite any existing copy of the wsusscn2.cab file that may already exist in the specified `download_directory`. Setting this value to `true` will override the internal logic to only download the wsusscn2.cab file if the last modified date has changed from the current version in the specified `download_directory`. Defaults to `false`.
 * ```task_day_of_week``` - [Optional] 
 * ```task_every``` - [Optional] 
 * ```task_schedule``` - [Optional] 
 * ```task_enabled``` - [Optional] 
 * ```task_ensure``` - [Optional] 