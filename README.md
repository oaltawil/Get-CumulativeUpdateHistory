# Get-CumulativeUpdateHistory
This is a Discovery script for a custom Intune Compliance policy that monitors the age of the installed cumulative update relative to the latest available cumulative update.

The script compares the release dates of the installed cumulative update and the latest available cumulative update and returns the number of days between them.

1. Downloads the Update History webpage for the running operating system, e.g. 'https://support.microsoft.com/en-us/help/5018680' for Windows 11 22H2.
2. Determines the release dates of the installed cumulative update and latest available cumulative update.
3. Returns the number of days that have passed from the release date of the installed update to the release date of the latest available update. The return type is a JSON object with a single (integer) property called NumberOfDaysSinceLCU.

Notes:
- If the OS Build of the running operating system cannot be found in the Windows Update History webpage, then no cumulative updates have been installed. Non-cumulative updates, typically necessary servicing stack updates or updates to the Windows Update client, were most probably included in the image, or were installed by Windows Setup Dynamic Update or by Windows Update client from Microsoft Update/WSUS/MECM. In this case, the script uses the release date of the initial build of the Windows 10/11 feature update or version, e.g. October 04, 2021 for Windows 11 21H2.
- If the latest cumulative update cannot be found in the Windows Update History webpage, then the script returns zero for the 'NumberOfDaysSinceLCU' property. This can happen for a freshly released Windows 11 feature update or version, e.g. 23H2, that doesn't have any non-Preview cumulative updates published yet (as of November 10, 2023).

**Tip**: Use the -Verbose common parameter to display details about the installed and latest cumulative updates.
