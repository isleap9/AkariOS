# Refresh category. GENERATED from the AkariOS-Ultimate '2 Refresh' scripts.

Add-Tweak -Id 'factory-reset' -Category 'Refresh' -Kind Action -Button 'Open' -Name 'Factory reset' -Risk Safe `
    -Description 'Open the Windows recovery settings' `
    -Apply {
Start-Process "ms-settings:recovery"
    }

Add-Tweak -Id 'account-local' -Category 'Refresh' -Kind Action -Button 'Open' -Name 'Local account' -Risk Safe `
    -Description 'Open the user accounts window (netplwiz)' `
    -Apply {
Start-Process "netplwiz"
    }

Add-Tweak -Id 'reinstall' -Category 'Refresh' -Kind Group -Name 'Reinstall Windows' -Risk Caution `
    -Description 'Download the Windows media creation tool' `
    -Actions @(
        @{ Name = 'Reinstall: W10'; Description = 'Download the Windows 10 media creation tool'; Button = 'Download'; Block = {
if (-not (Test-Connection -ComputerName '8.8.8.8' -Count 1 -Quiet -ErrorAction SilentlyContinue)) { Write-Log 'Internet connection required'; return }
Write-Host "Downloading: Media Creation Tool Win 10..."

# download media creation tool win 10
IWR "https://github.com/isleap9/AkariOS-Files/releases/download/Files/mediacreationtoolw10.exe" -OutFile "$env:SystemRoot\Temp\mediacreationtoolw10.exe"

# start media creation tool win 10
Start-Process "$env:SystemRoot\Temp\mediacreationtoolw10.exe"
        }},
        @{ Name = 'Reinstall: W11'; Description = 'Download the Windows 11 media creation tool'; Button = 'Download'; Block = {
if (-not (Test-Connection -ComputerName '8.8.8.8' -Count 1 -Quiet -ErrorAction SilentlyContinue)) { Write-Log 'Internet connection required'; return }
Write-Host "Downloading: Media Creation Tool Win 11..."

# download media creation tool win 11
IWR "https://github.com/isleap9/AkariOS-Files/releases/download/Files/mediacreationtoolw11.exe" -OutFile "$env:SystemRoot\Temp\mediacreationtoolw11.exe"

# start media creation tool win 11
Start-Process "$env:SystemRoot\Temp\mediacreationtoolw11.exe"
        }}
    )

Add-Tweak -Id 'autounattend' -Category 'Refresh' -Kind Group -Name 'Autounattend' -Risk Caution `
    -Description 'Create an autounattend file for a bootable USB' `
    -Actions @(
        @{ Name = 'Create'; Description = 'Generate an autounattend.xml and copy it to a USB drive'; Button = 'Create'; Block = {
Write-Host "Creating autounattend file..."

# save autounattendtemplate
$AutoUnattend = @'
<?xml version="1.0" encoding="utf-8"?>
<unattend xmlns="urn:schemas-microsoft-com:unattend">
    <settings pass="oobeSystem">
        <component name="Microsoft-Windows-International-Core" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS"
            xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State"
            xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <InputLocale>0409:00000409</InputLocale>
            <SystemLocale>en-US</SystemLocale>
            <UILanguage>en-US</UILanguage>
            <UILanguageFallback>en-US</UILanguageFallback>
            <UserLocale>en-US</UserLocale>
        </component>
        <component name="Microsoft-Windows-Shell-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS"
            xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State"
            xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <TimeZone>Central Standard Time</TimeZone>
            <OOBE>
                <HideEULAPage>true</HideEULAPage>
                <HideLocalAccountScreen>true</HideLocalAccountScreen>
                <HideOnlineAccountScreens>true</HideOnlineAccountScreens>
                <HideWirelessSetupInOOBE>true</HideWirelessSetupInOOBE>
                <NetworkLocation>Home</NetworkLocation>
                <ProtectYourPC>3</ProtectYourPC>
                <SkipMachineOOBE>true</SkipMachineOOBE>
                <SkipUserOOBE>true</SkipUserOOBE>
            </OOBE>
            <UserAccounts>
                <AdministratorPassword>
                    <PlainText>true</PlainText>
                    <Value></Value>
                </AdministratorPassword>
                <LocalAccounts>
                    <LocalAccount wcm:action="add">
                        <Group>Administrators</Group>
                        <Name>@</Name>
                        <Password>
                            <PlainText>true</PlainText>
                            <Value></Value>
                        </Password>
                    </LocalAccount>
                </LocalAccounts>
            </UserAccounts>
        </component>
    </settings>
    <settings pass="specialize">
        <component name="Microsoft-Windows-Deployment" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS"
            xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State"
            xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <RunSynchronous>
                <RunSynchronousCommand wcm:action="add">
                    <Order>1</Order>
                    <Path>net accounts /maxpwage:unlimited</Path>
                    <WillReboot>Never</WillReboot>
                </RunSynchronousCommand>
                <RunSynchronousCommand wcm:action="add">
                    <Order>2</Order>
                    <Path>net user @ /active:Yes</Path>
                    <WillReboot>Never</WillReboot>
                </RunSynchronousCommand>
                <RunSynchronousCommand wcm:action="add">
                    <Order>3</Order>
                    <Path>net user @ /passwordreq:no</Path>
                    <WillReboot>Never</WillReboot>
                </RunSynchronousCommand>
            </RunSynchronous>
        </component>
        <component name="Microsoft-Windows-Security-SPP-UX" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS"
            xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State"
            xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <SkipAutoActivation>true</SkipAutoActivation>
        </component>
        <component name="Microsoft-Windows-UnattendedJoin" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS"
            xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State"
            xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <Identification>
                <JoinWorkgroup>WORKGROUP</JoinWorkgroup>
            </Identification>
        </component>
    </settings>
    <settings pass="windowsPE">
        <component name="Microsoft-Windows-International-Core-WinPE" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS"
            xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State"
            xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <InputLocale>0409:00000409</InputLocale>
            <SystemLocale>en-US</SystemLocale>
            <UILanguage>en-US</UILanguage>
            <UILanguageFallback>en-US</UILanguageFallback>
            <UserLocale>en-US</UserLocale>
            <SetupUILanguage>
                <UILanguage>en-US</UILanguage>
            </SetupUILanguage>
        </component>
        <component name="Microsoft-Windows-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS"
            xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State"
            xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <RunSynchronous>
                <RunSynchronousCommand wcm:action="add">
                    <Order>1</Order>
                    <Path>reg add "HKLM\SYSTEM\Setup\LabConfig" /v "BypassTPMCheck" /t REG_DWORD /d 1 /f</Path>
                    <Description>Add BypassTPMCheck</Description>
                </RunSynchronousCommand>
                <RunSynchronousCommand wcm:action="add">
                    <Order>2</Order>
                    <Path>reg add "HKLM\SYSTEM\Setup\LabConfig" /v "BypassRAMCheck" /t REG_DWORD /d 1 /f</Path>
                    <Description>Add BypassRAMCheck</Description>
                </RunSynchronousCommand>
                <RunSynchronousCommand wcm:action="add">
                    <Order>3</Order>
                    <Path>reg add "HKLM\SYSTEM\Setup\LabConfig" /v "BypassSecureBootCheck" /t REG_DWORD /d 1 /f</Path>
                    <Description>Add BypassSecureBootCheck</Description>
                </RunSynchronousCommand>
                <RunSynchronousCommand wcm:action="add">
                    <Order>4</Order>
                    <Path>reg add "HKLM\SYSTEM\Setup\LabConfig" /v "BypassCPUCheck" /t REG_DWORD /d 1 /f</Path>
                    <Description>Add BypassCPUCheck</Description>
                </RunSynchronousCommand>
                <RunSynchronousCommand wcm:action="add">
                    <Order>5</Order>
                    <Path>reg add "HKLM\SYSTEM\Setup\LabConfig" /v "BypassStorageCheck" /t REG_DWORD /d 1 /f</Path>
                    <Description>Add BypassStorageCheck</Description>
                </RunSynchronousCommand>
            </RunSynchronous>
            <Diagnostics>
                <OptIn>false</OptIn>
            </Diagnostics>
            <DynamicUpdate>
                <Enable>false</Enable>
                <WillShowUI>OnError</WillShowUI>
            </DynamicUpdate>
            <UserData>
                <AcceptEula>true</AcceptEula>
                <ProductKey>
                    <Key></Key>
                </ProductKey>
            </UserData>
        </component>
    </settings>
</unattend>
'@
Set-Content -Path "$env:SystemRoot\Temp\autounattendtemplate.xml" -Value $AutoUnattend -Force

# get username
$username = Read-Host "Enter Account Name (No Spaces)"
if (-not $username) { Write-Log 'Cancelled'; return }

# replace placeholder
$path = "$env:SystemRoot\Temp\autounattendtemplate.xml"
(Get-Content $path) -replace "@",$username | Out-File $path

# convert to utf8
Get-Content "$env:SystemRoot\Temp\autounattendtemplate.xml" | Set-Content -Encoding utf8 "$env:SystemRoot\Temp\autounattend.xml" -Force
Remove-Item -Path "$env:SystemRoot\Temp\autounattendtemplate.xml" -Force | Out-Null

# select usb drive
$destination = Get-FolderPath "Select your USB drive"
if (-not $destination) { Write-Log 'Cancelled'; return }

# move to usb
$file = "$env:SystemRoot\Temp\autounattend.xml"
Move-Item -Path $file -Destination $destination -Force

# open usb directory
Start-Process $destination
Write-Host "Done - autounattend.xml copied to $destination"
        }}
    )

Add-Tweak -Id 'updates-drivers-block' -Category 'Refresh' -Kind Group -Name 'Updates and drivers block' -Risk Advanced `
    -Description 'Block or unblock Windows updates and driver updates (Pro/LTSC/IoT/Server)' `
    -Actions @(
        @{ Name = 'Block drivers'; Description = 'Block all Windows driver updates via registry'; Button = 'Block'; Block = {
Write-Host "Blocked: Driver Updates"
# block all windows driver updates
reg add "HKLM\Software\Policies\Microsoft\Windows\Device Metadata" /v "PreventDeviceMetadataFromNetwork" /t REG_DWORD /d 1 /f | Out-Null
reg add "HKLM\Software\Policies\Microsoft\Windows\DeviceInstall\Settings" /v "DisableSendGenericDriverNotFoundToWER" /t REG_DWORD /d 1 /f | Out-Null
reg add "HKLM\Software\Policies\Microsoft\Windows\DeviceInstall\Settings" /v "DisableSendRequestAdditionalSoftwareToWER" /t REG_DWORD /d 1 /f | Out-Null
reg add "HKLM\Software\Policies\Microsoft\Windows\DriverSearching" /v "SearchOrderConfig" /t REG_DWORD /d 0 /f | Out-Null
reg add "HKLM\Software\Policies\Microsoft\Windows\WindowsUpdate" /v "SetAllowOptionalContent" /t REG_DWORD /d 0 /f | Out-Null
reg add "HKLM\Software\Policies\Microsoft\Windows\WindowsUpdate" /v "AllowTemporaryEnterpriseFeatureControl" /t REG_DWORD /d 0 /f | Out-Null
reg add "HKLM\Software\Policies\Microsoft\Windows\WindowsUpdate" /v "ExcludeWUDriversInQualityUpdate" /t REG_DWORD /d 1 /f | Out-Null
reg add "HKLM\Software\Policies\Microsoft\Windows\WindowsUpdate\AU" /v "IncludeRecommendedUpdates" /t REG_DWORD /d 0 /f | Out-Null
reg add "HKLM\Software\Policies\Microsoft\Windows\WindowsUpdate\AU" /v "EnableFeaturedSoftware" /t REG_DWORD /d 0 /f | Out-Null
Write-Host "Driver updates blocked."
        }},
        @{ Name = 'Block drivers (USB)'; Description = 'Create setupcomplete.cmd for a bootable USB to block driver updates'; Button = 'USB'; Block = {
Write-Host "Creating setupcomplete.cmd for driver block..."
# create setupcomplete.cmd
$SetupCompleteCmd = @'
@echo off
reg add "HKLM\Software\Policies\Microsoft\Windows\Device Metadata" /v "PreventDeviceMetadataFromNetwork" /t REG_DWORD /d 1 /f
reg add "HKLM\Software\Policies\Microsoft\Windows\DeviceInstall\Settings" /v "DisableSendGenericDriverNotFoundToWER" /t REG_DWORD /d 1 /f
reg add "HKLM\Software\Policies\Microsoft\Windows\DeviceInstall\Settings" /v "DisableSendRequestAdditionalSoftwareToWER" /t REG_DWORD /d 1 /f
reg add "HKLM\Software\Policies\Microsoft\Windows\DriverSearching" /v "SearchOrderConfig" /t REG_DWORD /d 0 /f
reg add "HKLM\Software\Policies\Microsoft\Windows\WindowsUpdate" /v "SetAllowOptionalContent" /t REG_DWORD /d 0 /f
reg add "HKLM\Software\Policies\Microsoft\Windows\WindowsUpdate" /v "AllowTemporaryEnterpriseFeatureControl" /t REG_DWORD /d 0 /f
reg add "HKLM\Software\Policies\Microsoft\Windows\WindowsUpdate" /v "ExcludeWUDriversInQualityUpdate" /t REG_DWORD /d 1 /f
reg add "HKLM\Software\Policies\Microsoft\Windows\WindowsUpdate\AU" /v "IncludeRecommendedUpdates" /t REG_DWORD /d 0 /f
reg add "HKLM\Software\Policies\Microsoft\Windows\WindowsUpdate\AU" /v "EnableFeaturedSoftware" /t REG_DWORD /d 0 /f
shutdown /r /t 0
'@
Set-Content -Path "$env:SystemRoot\Temp\setupcomplete.cmd" -Value $SetupCompleteCmd -Force
# select usb drive
$destination = Get-FolderPath "Select your USB drive"
if (-not $destination) { Write-Log 'Cancelled'; return }
# create scripts folder
New-Item -Path "$destination\sources\`$OEM`$\`$`$\Setup\Scripts" -ItemType Directory -Force | Out-Null
# move setupcomplete.cmd to usb
Move-Item -Path "$env:SystemRoot\Temp\setupcomplete.cmd" -Destination "$destination\sources\`$OEM`$\`$`$\Setup\Scripts" -Force
# open usb directory
Start-Process "$destination\sources\`$OEM`$\`$`$\Setup\Scripts"
Write-Host "Done - setupcomplete.cmd copied to USB."
        }},
        @{ Name = 'Unblock drivers'; Description = 'Revert the driver update block'; Button = 'Unblock'; Block = {
Write-Host "Unblocked: Driver Updates"
# revert block all windows driver updates
reg delete "HKLM\Software\Policies\Microsoft\Windows\Device Metadata" /v "PreventDeviceMetadataFromNetwork" /f | Out-Null
reg delete "HKLM\Software\Policies\Microsoft\Windows\DeviceInstall\Settings" /v "DisableSendGenericDriverNotFoundToWER" /f | Out-Null
reg delete "HKLM\Software\Policies\Microsoft\Windows\DeviceInstall\Settings" /v "DisableSendRequestAdditionalSoftwareToWER" /f | Out-Null
reg delete "HKLM\Software\Policies\Microsoft\Windows\DriverSearching" /v "SearchOrderConfig" /f | Out-Null
reg delete "HKLM\Software\Policies\Microsoft\Windows\WindowsUpdate" /v "SetAllowOptionalContent" /f | Out-Null
reg delete "HKLM\Software\Policies\Microsoft\Windows\WindowsUpdate" /v "AllowTemporaryEnterpriseFeatureControl" /f | Out-Null
reg delete "HKLM\Software\Policies\Microsoft\Windows\WindowsUpdate" /v "ExcludeWUDriversInQualityUpdate" /f | Out-Null
reg delete "HKLM\Software\Policies\Microsoft\Windows\WindowsUpdate\AU" /v "IncludeRecommendedUpdates" /f | Out-Null
reg delete "HKLM\Software\Policies\Microsoft\Windows\WindowsUpdate\AU" /v "EnableFeaturedSoftware" /f | Out-Null
Write-Host "Driver updates unblocked."
        }},
        @{ Name = 'Block updates'; Description = 'Block all Windows updates via registry'; Button = 'Block'; Block = {
Write-Host "Blocked: Updates"
# block all windows updates
reg add "HKLM\Software\Policies\Microsoft\Windows\WindowsUpdate" /v "DoNotConnectToWindowsUpdateInternetLocations" /t REG_DWORD /d 1 /f | Out-Null
reg add "HKLM\Software\Policies\Microsoft\Windows\WindowsUpdate" /v "UpdateServiceUrlAlternate" /t REG_SZ /d "https://fuckyoumicrosoft.com/" /f | Out-Null
reg add "HKLM\Software\Policies\Microsoft\Windows\WindowsUpdate" /v "WUStatusServer" /t REG_SZ /d "https://fuckyoumicrosoft.com/" /f | Out-Null
reg add "HKLM\Software\Policies\Microsoft\Windows\WindowsUpdate" /v "WUServer" /t REG_SZ /d "https://fuckyoumicrosoft.com/" /f | Out-Null
reg add "HKLM\Software\Policies\Microsoft\Windows\WindowsUpdate" /v "SetDisableUXWUAccess" /t REG_DWORD /d 1 /f | Out-Null
reg add "HKLM\Software\Policies\Microsoft\Windows\WindowsUpdate" /v "ExcludeWUDriversInQualityUpdate" /t REG_DWORD /d 1 /f | Out-Null
reg add "HKLM\Software\Policies\Microsoft\Windows\WindowsUpdate\AU" /v "NoAutoUpdate" /t REG_DWORD /d 1 /f | Out-Null
reg add "HKLM\Software\Policies\Microsoft\Windows\WindowsUpdate\AU" /v "UseWUServer" /t REG_DWORD /d 1 /f | Out-Null
Write-Host "Windows updates blocked."
        }},
        @{ Name = 'Block updates (USB)'; Description = 'Create setupcomplete.cmd for a bootable USB to block updates'; Button = 'USB'; Block = {
Write-Host "Creating setupcomplete.cmd for update block..."
# create setupcomplete.cmd
$SetupCompleteCmd = @'
@echo off
reg add "HKLM\Software\Policies\Microsoft\Windows\WindowsUpdate" /v "DoNotConnectToWindowsUpdateInternetLocations" /t REG_DWORD /d 1 /f
reg add "HKLM\Software\Policies\Microsoft\Windows\WindowsUpdate" /v "UpdateServiceUrlAlternate" /t REG_SZ /d "https://fuckyoumicrosoft.com/" /f
reg add "HKLM\Software\Policies\Microsoft\Windows\WindowsUpdate" /v "WUStatusServer" /t REG_SZ /d "https://fuckyoumicrosoft.com/" /f
reg add "HKLM\Software\Policies\Microsoft\Windows\WindowsUpdate" /v "WUServer" /t REG_SZ /d "https://fuckyoumicrosoft.com/" /f
reg add "HKLM\Software\Policies\Microsoft\Windows\WindowsUpdate" /v "SetDisableUXWUAccess" /t REG_DWORD /d 1 /f
reg add "HKLM\Software\Policies\Microsoft\Windows\WindowsUpdate" /v "ExcludeWUDriversInQualityUpdate" /t REG_DWORD /d 1 /f
reg add "HKLM\Software\Policies\Microsoft\Windows\WindowsUpdate\AU" /v "NoAutoUpdate" /t REG_DWORD /d 1 /f
reg add "HKLM\Software\Policies\Microsoft\Windows\WindowsUpdate\AU" /v "UseWUServer" /t REG_DWORD /d 1 /f
shutdown /r /t 0
'@
Set-Content -Path "$env:SystemRoot\Temp\setupcomplete.cmd" -Value $SetupCompleteCmd -Force
# select usb drive
$destination = Get-FolderPath "Select your USB drive"
if (-not $destination) { Write-Log 'Cancelled'; return }
# create scripts folder
New-Item -Path "$destination\sources\`$OEM`$\`$`$\Setup\Scripts" -ItemType Directory -Force | Out-Null
# move setupcomplete.cmd to usb
Move-Item -Path "$env:SystemRoot\Temp\setupcomplete.cmd" -Destination "$destination\sources\`$OEM`$\`$`$\Setup\Scripts" -Force
# open usb directory
Start-Process "$destination\sources\`$OEM`$\`$`$\Setup\Scripts"
Write-Host "Done - setupcomplete.cmd copied to USB."
        }},
        @{ Name = 'Unblock updates'; Description = 'Revert the Windows update block'; Button = 'Unblock'; Block = {
Write-Host "Unblocked: Updates"
# revert block all windows updates
reg delete "HKLM\Software\Policies\Microsoft\Windows\WindowsUpdate" /v "DoNotConnectToWindowsUpdateInternetLocations" /f | Out-Null
reg delete "HKLM\Software\Policies\Microsoft\Windows\WindowsUpdate" /v "UpdateServiceUrlAlternate" /f | Out-Null
reg delete "HKLM\Software\Policies\Microsoft\Windows\WindowsUpdate" /v "WUStatusServer" /f | Out-Null
reg delete "HKLM\Software\Policies\Microsoft\Windows\WindowsUpdate" /v "WUServer" /f | Out-Null
reg delete "HKLM\Software\Policies\Microsoft\Windows\WindowsUpdate" /v "SetDisableUXWUAccess" /f | Out-Null
reg delete "HKLM\Software\Policies\Microsoft\Windows\WindowsUpdate" /v "ExcludeWUDriversInQualityUpdate" /f | Out-Null
reg delete "HKLM\Software\Policies\Microsoft\Windows\WindowsUpdate\AU" /v "NoAutoUpdate" /f | Out-Null
reg delete "HKLM\Software\Policies\Microsoft\Windows\WindowsUpdate\AU" /v "UseWUServer" /f | Out-Null
Write-Host "Windows updates unblocked."
        }}
    )

Add-Tweak -Id 'network-driver' -Category 'Refresh' -Kind Action -Button 'Open' -Name 'Network driver' -Risk Safe `
    -Description 'Search your motherboard model online for the network driver' `
    -Apply {
# get motherboard id
$instanceID = (Get-CimInstance Win32_BaseBoard).Product
$query = [uri]::EscapeDataString($instanceID)

# search motherboard id in web browser
Start-Process "https://www.google.com/search?q=$query"
    }

Add-Tweak -Id 'to-bios' -Category 'Refresh' -Kind Action -Button 'Restart' -Name 'Restart to BIOS' -Risk Caution -Confirm 'Restart now and boot into the BIOS / UEFI settings? Unsaved work will be lost.' `
    -Description 'Restart the PC straight into the BIOS or UEFI settings' `
    -Apply {
Write-Host "Press Enter to Restart to BIOS" -ForegroundColor Red
Pause

# restart to bios
cmd /c C:\Windows\System32\shutdown.exe /r /fw /t 0
    }
