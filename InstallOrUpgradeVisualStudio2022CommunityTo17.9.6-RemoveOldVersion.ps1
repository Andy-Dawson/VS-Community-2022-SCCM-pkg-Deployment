###############
#
# InstallOrUpgrade-VisualStudio2022CommunityToXX.X.X.ps1
# This script installs (or upgrades, if a previous version is present
# Visual Studio 2022 Community to a newer version working from a network
# Layout folder. 
#
# Version: 1.0.0: Initial version for 17.7.5
# Version: 1.0.1: Version for 17.8.1, changed to using vs_community.exe ... --in appropriateresponsefile.json for installation
# Version: 1.0.2: Version for 17.9.6
#
# Note: MUST use Start-Process to allow waiting for completion of previous task before starting the next '& $CommandToRun ...' DOESN'T WORK
#
###############

# Location of the installer in the new layout location
$LayoutPath = "\\FileServer\VSCommunity2022-17.9.6"
$VSInstallerPath = $LayoutPath + "\vs_Community.exe"
$VSResponsePath = $LayoutPath + "\BaseResponse.json"
# Version to be installed - This is pulled from the catalog file in the layout folder
$LayoutCatalogPath = $LayoutPath + "\Catalog.json"
$LayoutCatalog = Get-Content $LayoutCatalogPath | out-String | ConvertFrom-Json
$LayoutVersion = [System.Version]$LayoutCatalog.info.productDisplayVersion

# The variables below control whether messages will be displayed or logged, and the location of the log file
$global:LogOutput = $True
$global:WriteStdOutput = $True
$global:LogFileLoc = "C:\Support\VisualStudioCommunity2022.txt"

# Function to notify the user what's going on
function NotifyUser {
	[CmdletBinding()]
	param(
		[Parameter(Mandatory)]
		[string]$Message
	)

    # If we're writing std output...
    if ($global:WriteStdOutput) {
        Write-Host $Message
    }

    # If we're writing log file output...
    if ($global:LogOutput) {
        # Find current date and time to prepend the message
        $date = (Get-Date -Format "dd/MM/yyyy HH:mm:ss").ToString()
        $Message = "[" + $date + "]: " + $Message 
        $Message | Out-File -FilePath $global:LogFileLoc -Append
    }
}

if (Test-Path -Path "C:\Program Files\Microsoft Visual Studio\2022\Community\Common7\IDE\devenv.exe" -ErrorAction SilentlyContinue) {
    # We have an instance of devenv.exe in the right place, so Visual Studio should be installed - check the version
    NotifyUser -Message "Instance of devenv.exe located in the correct place"
    # Now get the version and instance ID
    if (Test-Path -Path "C:\Program Files (x86)\Microsoft Visual Studio\Installer\vswhere.exe" -ErrorAction SilentlyContinue) {
        # The line below gets an array of output items from the command line process, but should identify the instance of VS Community
        $VSInstance = & "C:\Program Files (x86)\Microsoft Visual Studio\Installer\vswhere.exe" -products Microsoft.VisualStudio.Product.Community
        if ($VSInstance.Count -gt 3) {
            NotifyUser -Message "Located an installed instance of VS 2022 Community"
            $VSInstanceID = ($VSInstance | where-object {$_ -match 'instanceID: '} | foreach-object {$_ -replace 'instanceID: ',''})
            NotifyUser -Message "  o Instancd ID is $($VSInstanceID)"
            # Check that the state.json file exists for the above instance
            if (Test-Path -Path "C:\ProgramData\Microsoft\VisualStudio\Packages\_Instances\$VSInstanceID\state.json" -ErrorAction SilentlyContinue) {
                # the state.json file exists, so pull the version from it
                NotifyUser -Message "State.json file loctaed for the installed instance"
                $state = Get-Content "C:\ProgramData\Microsoft\VisualStudio\Packages\_Instances\$VSInstanceID\state.json" | out-String | ConvertFrom-Json
                $InstalledVersion = [System.Version]$state.catalogInfo.productDisplayVersion
                if ($InstalledVersion -ge $LayoutVersion) {
                    # We have same or newer version installed, so nothing to do
                    NotifyUser -Message "Same or newer version of VS 2022 Community already installed; nothing to do..."
                } else {
                    # We have an older version, perform the upgrade
                    NotifyUser -Message "Located older version of VS 2022 Community."
                    NotifyUser -Message "  o Installed version: $($InstalledVersion.ToString())"
                    NotifyUser -Message "  o Will be updated to: $($LayoutVersion.ToString())"
                    # Uninstall the existing version
                    NotifyUser -Message "  o Installed version will be uninstalled..."
                    Start-Process -FilePath $VSInstallerPath -ArgumentList "uninstall --installPath `"C:\Program Files\Microsoft Visual Studio\2022\Community`" --quiet --wait" -NoNewWindow -Wait
                    # Now update the installer on the local disk
                    NotifyUser -Message "  o Updating the Visual Studio installer..."
                    Start-Process -FilePath $VSInstallerPath -ArgumentList "--update --quiet --wait" -NoNewWindow -Wait
                    # Now install the new version of VS from the new layout location
                    NotifyUser -Message "  o installing the new Vistual Studio 2022 Community instance..."
                    Start-Process -FilePath $VSInstallerPath -ArgumentList "--in $($VSResponsePath) --wait" -NoNewWindow -Wait
                }
            } else {
                # Could not locate the state.json file, so there's something wrong with the installation
                NotifyUser -Message "Could not locate state.json file for the installed instance of VS 2022 Community"
            }
        } else {
            # No instances of VS detected by Get-CinInstance method
            NotifyUser -Message "No instances of VS 2022 Community detected by VSWhere.exe"
        }
    } else {
        # VSWhere.exe not available
        NotifyUser -Message "No instance of VSWhere.exe located"
    }
} else {
    # Visual Studio 2022 Community is NOT installed and we can go ahead and install it
    NotifyUser -Message "It appears that VS 2022 Community is NOT installed..."
	NotifyUser -Message "  o Visual Studio 2022 Community version $($LayoutVersion.ToString()) will be installed from $($LayoutPath)."
    # New command to use the response.json file format. Should install our required baseworkloads
    Start-Process -FilePath $VSInstallerPath -ArgumentList "--in $($VSResponsePath) --wait" -NoNewWindow -Wait
}

NotifyUser -Message "Script complete"
