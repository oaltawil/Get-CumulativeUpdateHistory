<#
.NOTES
This sample script is not supported under any Microsoft standard support program or service. The sample script is provided AS IS without warranty of any kind. Microsoft disclaims all implied warranties including, without limitation, any implied warranties of merchantability or of fitness for a particular purpose. The entire risk arising out of the use or performance of the sample script remains with you. 
In no event shall Microsoft, its authors, or anyone else involved in the creation, production, or delivery of the script be liable for any damages whatsoever (including, without limitation, damages for loss of business profits, business interruption, loss of business information, or other pecuniary loss) arising out of the use of or inability to use the sample script, even if Microsoft has been advised of the possibility of such damages.

.SYNOPSIS
This is the Discovery script for a custom Intune Compliance policy that monitors the age of the installed cumulative update relative to the latest available cumulative update.

.DESCRIPTION
This script compares the release dates of the installed cumulative update and the latest available cumulative update and returns the number of days between them.
- Downloads the Update History webpage for the running operating system, e.g. 'https://support.microsoft.com/en-us/help/5018680' for Windows 11 22H2.
- Determines the release dates of the installed cumulative update and latest available cumulative update
- Returns the number of days that have passed from the release date of the installed update to the release date of the latest available update.

Tip: Use the -Verbose common parameter to display the following output:
VERBOSE: The installed cumulative update 'October 10, 2023 - KB5031354 (OS Build 22621.2428)' is 35 days behind the
latest cumulative update 'November 14, 2023 - KB5032190 (OS Builds 22621.2715 and 22631.2715)'
#>

[CmdletBinding()]
Param ()

<#
# A list of the Update History web pages for supported versions of Windows 11 and Windows 10
# The list also includes the initial OS build number and initial release date of each supported feature update or version of Windows 11/10
# Reference: https://learn.microsoft.com/en-us/windows/release-health/windows11-release-information
#
#>
$WindowsUpdateHistoryInformation = 
@"
ProductName,Version,InitialOSBuild,InitialReleaseDate,Uri
Windows 11,23H2,22631.2428,2023-10-31,https://support.microsoft.com/en-us/help/5031682
Windows 11,22H2,22621.521,2022-09-20,https://support.microsoft.com/en-us/help/5018680
Windows 11,21H2,22000.194,2021-10-04,https://support.microsoft.com/en-us/help/5006099
Windows 10,22H2,19045.2130,2022-10-18,https://support.microsoft.com/en-us/help/5018682
Windows 10,21H2,19044.1288,2021-11-16,https://support.microsoft.com/en-us/help/5008339
"@


<#
############################################
    1. Function: Get-WindowsVersion
############################################
#>

Function Get-WindowsVersion {
<#
This function returns a custom object with 3 properties that describe the running operating system:
- ProductName, e.g. Microsoft Windows 11 Enterprise
- Version, e.g. 22H2
- OSBuild, e.g. 22621.2506
#>

    [CmdletBinding()]
    param()

    $CurrentBuild = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -Name CurrentBuild -ErrorAction Stop).CurrentBuild
    
    $UBR = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -Name UBR -ErrorAction Stop).UBR
    
    $OSBuild = $CurrentBuild + "." + $UBR

    # Return a custom object that describes the operating system
    return [PSCustomObject]@{

        ProductName = (Get-CimInstance -ClassName Win32_OperatingSystem -Property Caption -ErrorAction Stop).Caption

        Version = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -Name DisplayVersion -ErrorAction Stop).DisplayVersion

        OSBuild = $OSBuild

    }
}

<#
############################################
    2. Function: Format-UpdateLink
############################################
#>

Function Format-UpdateLink {
<#
This function accepts the hypertext link for a Cumulative Update and returns a custom object with 5 properties that describe that update:
- Name, e.g. July 11, 2023 - KB5028185 (OS Build 22621.1992)
- KB, e.g. KB5028185
- InfoUrl, e.g. https://support.microsoft.com/en-us/help/5028185
- OSBuild, e.g. 22621.1992
- ReleaseDate, e.g. July 11, 2023 (as a [DateTime] object)
#>

    # The input should be a hypertext link - <a> or anchor element - with a class of "supLeftNavLink" and the string "OS Build" in its label.
    # Example: <a class="supLeftNavLink" data-bi-slot="11" href="/en-us/help/5028185">July 11, 2023&#x2014;KB5028185 (OS Build 22621.1992)</a>
    [CmdletBinding()]
    Param ($UpdateLink)

    if (($UpdateLink.class -ne "supLeftNavLink") -or ($UpdateLink.outerHTML -notmatch "OS Build"))
    {
        Write-Error "Format-UpdateLink: The hypertext link is not in the expected format."

        return
    }

    # Extract the label of the hypertext link - the text between the start '<a>' and end '</a>' tags
    # Replace the Unicode hexadecimal character code for the "Em Dash" (&#x2014;) with a standard dash surrounded by spaces
    # Example: July 11, 2023 - KB5028185 (OS Build 22621.1992)
    $Label = $UpdateLink.outerHTML.Split('>')[1].Split('<')[0].Replace('&#x2014;',' - ')

    # Extract the Release Date from the link's label
    # Example: July 11, 2023
    $ReleaseDate = $Label.Split('-')[0].Trim()

    # Create a custom object that describes the update using 5 properties: Name, KB, InfoUrl, OSBuild, and ReleaseDate
    return [PSCustomObject]@{

        # The name of the update is the label of the link, the text between the start '<a>' and end '</a>' tags.
        # Example: July 11, 2023 - KB5028185 (OS Build 22621.1992)
        Name = $Label

        # The HREF attribute designates the destination of the link, e.g. "/en-us/help/5028185"
        # Extract the KB number from the HREF attribute and append it to the string "KB"
        # Example: KB5028185
        KB = "KB" + $UpdateLink.href.Split('/')[-1]

        # Support Article Url
        # Example: https://support.microsoft.com/en-us/help/5028185
        InfoURL = "https://support.microsoft.com" + $UpdateLink.href

        # The OSBuild is enclosed in round brackets or parentheses '( )' and starts with the string "OS Build"
        # Example: OS Build 22621.1992
        OSBuild = $UpdateLink.outerHTML.Split('(')[1].Split(')')[0]

        # Cast the release date to a [DateTime] object for more efficient processing
        ReleaseDate = [datetime]$ReleaseDate

    }
}
    
<#
################################
        3. Main Script          
################################
#>

# Retrieve version details of the running operating system
$WindowsVersion = Get-WindowsVersion

# Locate the Update History web page that corresponds to the running operating system's name and version, e.g. Windows 11 22H2
$WindowsUpdateHistory = $WindowsUpdateHistoryInformation | ConvertFrom-Csv | Where-Object {$WindowsVersion.ProductName -match $_.ProductName -and $WindowsVersion.Version -eq $_.Version}

if (-not $WindowsUpdateHistory) 
{
    throw "Unable to find the Windows Update History information for the running operating system."
}

# Disable the (default) progress indicator shown by 'Invoke-WebRequest'; it significantly affects download speed
$ProgressPreference = 'SilentlyContinue'

<#
Save the HTML web response, which contains the following information:
    - Content: The text body content of the web response
    - Images: The <img> HTML element embeds an image into the document
    - InputFields: The <input> HTML element is used to create interactive controls for web-based forms in order to accept data from the user
    - Links: The <a> (anchor) HTML element, with its href attribute, creates a hyperlink to web pages, files, email addresses, locations in the same page, or anything else a URL can address
    - Relation Links: The <link> HTML element specifies relationships between the current document and an external resource. This element is most commonly used to link to stylesheets and is also used to establish site icons.
#>
$HtmlWebResponse = Invoke-WebRequest -Uri $WindowsUpdateHistory.Uri -UseBasicParsing -ErrorAction Stop

# Verify that the web page contains hypertext links - <a> or anchor Html elements. This is the only property of the web response object that we're interested in.
If (-not $HtmlWebResponse.Links)
{ 
    throw "The Html Web Response is not in the expected format."
}

# Retrieve all the hypertext links - <a> or anchor Html elements - that have "supLeftNavLink" as the class name and the string "OS Build" in the label
# Example: <a class="supLeftNavLink" data-bi-slot="11" href="/en-us/help/5028185">July 11, 2023&#x2014;KB5028185 (OS Build 22621.1992)</a> 
$UpdateLinks = $HtmlWebResponse.Links | Where-Object {$_.class -eq "supLeftNavLink" -and $_.outerHTML -match "OS Build"}

if (-not $UpdateLinks) 
{
    throw "The Update History support article $($WindowsUpdateHistory.Uri) for $($WindowsUpdateHistory.ProductName) $($WindowsUpdateHistory.Version) does not contain the expected hypertext links."
}

<#
######################
Installed CU Discovery
######################
#>

# Find the installed cumulative update in the Update History webpage. Match the full OS Build of the running operating system, e.g. 22621.2506.
$InstalledUpdateLink = $UpdateLinks | Where-Object {$_.outerHTML -match $WindowsVersion.OSBuild} | Select-Object -First 1

# If the installed cumulative update was found in the Update History webpage
if ($InstalledUpdateLink) {

    # Create a structured object that describes the installed cumulative update
    $InstalledUpdateInfo = Format-UpdateLink $InstalledUpdateLink

}
# Unable to find the installed update in the Windows Update History webpage
# Determine if the running operating system does not have any updates installed. In other words, if it's the initial build of a Feature Update or Verion of Windows 11/10.
elseif ($WindowsVersion.OSBuild -eq $WindowsUpdateHistory.InitialOSBuild) 
{
    # Create an object with a single property Release Date, which is the initial release date of the Windows 11/10 Feature Update or Version.
    $InstalledUpdateInfo = [PSCustomObject]@{ReleaseDate = [datetime]$WindowsUpdateHistory.InitialReleaseDate}
}
else 
{
    throw "Unable to find the installed Cumulative Update for OS Build $($WindowsVersion.OSBuild) in the $($WindowsUpdateHistory.ProductName) $($WindowsUpdateHistory.Version) Update History support article $($WindowsUpdateHistory.Uri)"
}


<#
#############
LCU Discovery
#############
#>

# Find the latest update for the same current build, e.g. 22621 (for Windows 11 22H2), and exclude Preview and Out-of-Band updates
$LatestUpdateLink = $UpdateLinks | Where-Object {($_.outerHTML -match $WindowsVersion.OSBuild.Split('.')[0]) -and ($_.outerHTML -notmatch "Preview") -and ($_.outerHTML -notmatch "Out-of-band")} | Select-Object -First 1

# If the latest cumulative update was found in the Update History webpage
if ($LatestUpdateLink)
{
    # Create a structured object that describes the latest non-Preview update
    $LatestUpdateInfo = Format-UpdateLink $LatestUpdateLink
}
else
{
    Write-Verbose "There are no cumulative updates (excluding Preview and Out-of-Band updates) for Build Number $($WindowsVersion.OSBuild.Split('.')[0]) in the $($WindowsUpdateHistory.ProductName) $($WindowsUpdateHistory.Version) Update History support article $($WindowsUpdateHistory.Uri)."

    return @{NumberOfDaysBehindLCU = 0} | ConvertTo-Json -Compress

}

<#
###############
Time Difference
###############
#>

# Calculate the time difference between the release dates of the installed update and latest update
# The time difference can be negative; i.e. the installed update is more recent than the latest update. This can happen if the user installed the latest cumulative preview update since we're excluding preview and out-of-band updates. 
$TimeDifference = New-TimeSpan -Start $InstalledUpdateInfo.ReleaseDate -End $LatestUpdateInfo.ReleaseDate

$NumberOfDaysBehindLCU = $TimeDifference.Days

<#
#########################################
Verbose Messages: Use -Verbose to display
#########################################
#>

# If the installed cumulative update was found in the Update History webpage 
if ($InstalledUpdateInfo.Name) 
{
    Write-Verbose "The installed cumulative update '$($InstalledUpdateInfo.Name)' is $NumberOfDaysBehindLCU days behind the latest cumulative update '$($LatestUpdateInfo.Name)'"
}
# If the running O/S is the initial build of a feature update or version of Windows; i.e. it has no updates installed
elseif ($InstalledUpdateInfo.ReleaseDate)
{
    Write-Verbose "There are no cumulative updates installed. The OS Build '$($WindowsVersion.OSBuild)' is $NumberOfDaysBehindLCU days behind the latest cumulative update '$($LatestUpdateInfo.Name)'"
}

# Return the number of days that the installed update is behind the latest update
# The output should be a hashtable converted to a JSON string
return @{NumberOfDaysBehindLCU = $NumberOfDaysBehindLCU} | ConvertTo-Json -Compress
