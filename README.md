# Get-CumulativeUpdateHistory
Returns the age of the installed Cumulative Update, relative to the latest available Cumulative Update.

This is the Discovery script for a custom Intune Compliance policy that monitors the age of the installed cumulative update relative to the latest available cumulative update.

This script compares the release dates of the installed cumulative update and the latest available cumulative update and returns the number of days between them.
- Downloads the Update History webpage for the running operating system, e.g. 'https://support.microsoft.com/en-us/help/5018680' for Windows 11 22H2.
- Determines the release dates of the installed cumulative update and latest available cumulative update.
- Returns the number of days that have passed from the release date of the installed update to the release date of the latest available update.
