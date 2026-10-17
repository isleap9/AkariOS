# Setup category. GENERATED from the AkariOS-Ultimate '3 Setup' scripts.

Add-Tweak -Id 'bitlocker' -Category 'Setup' -Name 'BitLocker' -Risk Caution `
    -Description 'Turn BitLocker off (Default turns it on)' `
    -Apply {
Write-Host "BitLocker: Off..."

# disable bitlocker
try {
Get-BitLockerVolume |
Where-Object {
$_.ProtectionStatus -eq "On" -or $_.VolumeStatus -ne "FullyDecrypted"
} |
ForEach-Object {
Disable-BitLocker -MountPoint $_.MountPoint -ErrorAction SilentlyContinue | Out-Null
}
} catch { }

# open settings
Start-Process control.exe -ArgumentList "/name microsoft.bitlockerdriveencryption"

manage-bde -status

Pause
    } `
    -Revert {
Write-Host "BitLocker: On..."

# open settings
Start-Process control.exe -ArgumentList "/name microsoft.bitlockerdriveencryption"

manage-bde -status

Pause
    }

Add-Tweak -Id 'memory-compression' -Category 'Setup' -Name 'Memory compression' -Risk Caution `
    -Description 'Turn memory compression off' `
    -Apply {
Write-Host "Memory Compression: Off"

Pause

# disable memory compression
Disable-MMAgent -MemoryCompression -ErrorAction SilentlyContinue | Out-Null
    } `
    -Revert {
Write-Host "Memory Compression: Enable"

Pause

# enable memory compression
Enable-MMAgent -MemoryCompression -ErrorAction SilentlyContinue | Out-Null
    } `
    -Check {
Write-Host "SETTINGS MAY TAKE A WHILE TO INITIALIZE AFTER REBOOT"
Write-Host "WAIT A SHORT PERIOD BEFORE CHECKING`n"
Write-Host "Check"

# show mmagent
get-mmagent

Pause
    }

Add-Tweak -Id 'home-to-pro' -Category 'Setup' -Kind Action -Button 'Run' -Name 'Convert Home to Pro' -Risk Caution `
    -Description 'Copy the generic Pro key and open activation (disable internet first)' `
    -Apply {
Write-Host "Disable Internet First`n"

# copy key to clipboard
Set-Clipboard -Value "VK7JG-NPHTM-C97JM-9MPGT-3V66T"

Write-Host "Enter: VK7JG-NPHTM-C97JM-9MPGT-3V66T (Or Paste From Clipboard)`n"

# open activation screen
Start-Process ms-settings:activation
& "$env:windir\System32\SystemSettingsAdminFlows.exe" 'EnterProductKey'

Pause
    }

Add-Tweak -Id 'keys' -Category 'Setup' -Kind Action -Button 'Open' -Name 'Keys' -Risk Safe `
    -Description 'Open the Microsoft Activation Scripts page' `
    -Apply {
Start-Process "https://github.com/massgravel/Microsoft-Activation-Scripts"
    }

Add-Tweak -Id 'activation' -Category 'Setup' -Kind Action -Button 'Open' -Name 'Activation' -Risk Safe `
    -Description 'Open the activation settings' `
    -Apply {
Start-Process "ms-settings:activation"
    }

Add-Tweak -Id 'date-time' -Category 'Setup' -Kind Action -Button 'Open' -Name 'Date, language, region and time' -Risk Safe `
    -Description 'Open the date and time settings' `
    -Apply {
Start-Process "ms-settings:dateandtime"
    }

Add-Tweak -Id 'startup-apps-settings' -Category 'Setup' -Kind Action -Button 'Open' -Name 'Startup apps (Settings)' -Risk Safe `
    -Description 'Open the startup apps settings page' `
    -Apply {
Start-Process "ms-settings:startupapps"
    }

Add-Tweak -Id 'startup-apps-taskmgr' -Category 'Setup' -Kind Action -Button 'Open' -Name 'Startup apps (Task Manager)' -Risk Safe `
    -Description 'Open the Task Manager startup tab' `
    -Apply {
Start-Process "taskmgr" -ArgumentList " /0 /startup"
    }

Add-Tweak -Id 'background-apps' -Category 'Setup' -Name 'Background apps' -Risk Safe `
    -Description 'Stop apps from running in the background' `
    -Apply {
# disable background apps regedit
cmd /c "reg add `"HKLM\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy`" /v `"LetAppsRunInBackground`" /t REG_DWORD /d `"2`" /f >nul 2>&1"

# disable background apps global regedit
cmd /c "reg add `"HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Search`" /v `"BackgroundAppGlobalToggle`" /t REG_DWORD /d `"0`" /f >nul 2>&1"
cmd /c "reg add `"HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications`" /v `"GlobalUserDisabled`" /t REG_DWORD /d `"1`" /f >nul 2>&1"

# open settings
Start-Process ms-settings:privacy-backgroundapps
    } `
    -Revert {
# background apps regedit
cmd /c "reg delete `"HKLM\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy`" /v `"LetAppsRunInBackground`" /f >nul 2>&1"

# background apps global regedit
cmd /c "reg delete `"HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Search`" /v `"BackgroundAppGlobalToggle`" /f >nul 2>&1"
cmd /c "reg delete `"HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications`" /v `"GlobalUserDisabled`" /f >nul 2>&1"

# open settings
Start-Process ms-settings:privacy-backgroundapps
    }

Add-Tweak -Id 'edge-settings' -Category 'Setup' -Name 'Edge settings' -Risk Safe `
    -Description 'Optimized Microsoft Edge settings' `
    -Apply {
if (-not (Test-Connection -ComputerName '8.8.8.8' -Count 1 -Quiet -ErrorAction SilentlyContinue)) { Write-Log 'Internet connection required'; return }
Write-Host "Edge Settings: Optimize..."

# install ublock origin
cmd /c "reg add `"HKLM\SOFTWARE\Policies\Microsoft\Edge\ExtensionInstallForcelist`" /v `"1`" /t REG_SZ /d `"odfafepnkmbhccpbejgmiehpchacaeak;https://edge.microsoft.com/extensionwebstorebase/v1/crx`" /f >nul 2>&1"

# add edge policies
cmd /c "reg add `"HKLM\SOFTWARE\Policies\Microsoft\Edge`" /v `"HardwareAccelerationModeEnabled`" /t REG_DWORD /d `"0`" /f >nul 2>&1"
cmd /c "reg add `"HKLM\SOFTWARE\Policies\Microsoft\Edge`" /v `"BackgroundModeEnabled`" /t REG_DWORD /d `"0`" /f >nul 2>&1"
cmd /c "reg add `"HKLM\SOFTWARE\Policies\Microsoft\Edge`" /v `"StartupBoostEnabled`" /t REG_DWORD /d `"0`" /f >nul 2>&1"

# remove logon edge
$basePath = "HKLM:\Software\Microsoft\Active Setup\Installed Components"
Get-ChildItem $basePath | ForEach-Object {
$val = (Get-ItemProperty $_.PsPath)."(default)"
if ($val -like "*Edge*") {
Remove-Item $_.PsPath -Force -ErrorAction SilentlyContinue
}
}

# remove runonce edge
$runOncePath = "HKLM:\Software\Microsoft\Windows\CurrentVersion\RunOnce"
Get-Item $runOncePath -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Property | Where-Object { $_ -like "*msedge*" } | ForEach-Object {
Remove-ItemProperty -Path $runOncePath -Name $_ -Force -ErrorAction SilentlyContinue
}

# remove edge services
$services = Get-Service | Where-Object { $_.Name -match 'Edge' }
foreach ($service in $services) {
cmd /c "sc stop `"$($service.Name)`" >nul 2>&1"
cmd /c "sc delete `"$($service.Name)`" >nul 2>&1"
}

# remove edge scheduled tasks
Get-ScheduledTask | Where-Object { $_.TaskName -like '*Edge*' } | Unregister-ScheduledTask -Confirm:$false -ErrorAction SilentlyContinue

# remove ietoedge bho
cmd /c "reg delete `"HKLM\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Explorer\Browser Helper Objects\{1FD49718-1D00-4B19-AF5F-070AF6D5D54C}`" /f >nul 2>&1"
cmd /c "reg delete `"HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Browser Helper Objects\{1FD49718-1D00-4B19-AF5F-070AF6D5D54C}`" /f >nul 2>&1"
    } `
    -Revert {
if (-not (Test-Connection -ComputerName '8.8.8.8' -Count 1 -Quiet -ErrorAction SilentlyContinue)) { Write-Log 'Internet connection required'; return }
Write-Host "Edge Settings: Default..."

# remove ublock origin
# remove edge policies
cmd /c "reg delete `"HKLM\SOFTWARE\Policies\Microsoft\Edge`" /f >nul 2>&1"

# stop edge running
Stop-Process -Name "msedge" -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 2

# reset edge settings
Start-Process "msedge.exe" -ArgumentList "--restore-last-session --disable-extensions"
Start-Sleep -Seconds 2

# stop edge running
Stop-Process -Name "msedge" -Force -ErrorAction SilentlyContinue

# download edge installer
IWR "https://github.com/isleap9/AkariOS-Files/releases/download/Files/edge.exe" -OutFile "$env:SystemRoot\Temp\edge.exe"

# start edge installer
Start-Process "$env:SystemRoot\Temp\edge.exe"
    }

Add-Tweak -Id 'store-settings' -Category 'Setup' -Name 'Store settings' -Risk Safe `
    -Description 'Optimized Microsoft Store settings' `
    -Apply {
Write-Host "Store Settings: Optimize..."

# open store settings page so disable personalized experiences on ms account sticks
try {
Start-Process "ms-windows-store:settings"
} catch { }
Start-Sleep -Seconds 5

# stop store running
$stop = "WinStore.App", "backgroundTaskHost", "StoreDesktopExtension"
$stop | ForEach-Object { Stop-Process -Name $_ -Force -ErrorAction SilentlyContinue }
Start-Sleep -Seconds 2

# disable apps updates
cmd /c "reg add `"HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsStore\WindowsUpdate`" /v `"AutoDownload`" /t REG_DWORD /d `"2`" /f >nul 2>&1"

# create reg file
$storesettings = @'
Windows Registry Editor Version 5.00

[HKEY_LOCAL_MACHINE\Settings\LocalState]
; disable video autoplay
"VideoAutoplay"=hex(5f5e10b):00,96,9d,69,8d,cd,93,dc,01
; disable notifications for app installations
"EnableAppInstallNotifications"=hex(5f5e10b):00,36,d0,88,8e,cd,93,dc,01

[HKEY_LOCAL_MACHINE\Settings\LocalState\PersistentSettings]
; disable personalized experiences
"PersonalizationEnabled"=hex(5f5e10b):00,0d,56,a1,8a,cd,93,dc,01
'@
Set-Content -Path "$env:SystemRoot\Temp\windowsstore.reg" -Value $storesettings -Force
$settingsdat = "$env:LocalAppData\Packages\Microsoft.WindowsStore_8wekyb3d8bbwe\Settings\settings.dat"
$regfilewindowsstore = "$env:SystemRoot\Temp\windowsstore.reg"

# load hive
reg load "HKLM\Settings" $settingsdat >$null 2>&1

# import reg file
if ($LASTEXITCODE -eq 0) {
reg import $regfilewindowsstore >$null 2>&1

# unload hive
[gc]::Collect()
Start-Sleep -Seconds 2
reg unload "HKLM\Settings" >$null 2>&1
}
Start-Sleep -Seconds 2

# open store settings
Start-Process "ms-windows-store:settings"
    } `
    -Revert {
Write-Host "Store Settings: Default..."

# enable apps updates
cmd /c "reg delete HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsStore /f >nul 2>&1"

# stop store running
$stop = "WinStore.App", "backgroundTaskHost", "StoreDesktopExtension"
$stop | ForEach-Object { Stop-Process -Name $_ -Force -ErrorAction SilentlyContinue }
Start-Sleep -Seconds 2

# reset microsoft store
Start-Process "wsreset.exe" -WindowStyle Hidden

# stop store running
$stop = "WinStore.App", "backgroundTaskHost", "StoreDesktopExtension"
$stop | ForEach-Object { Stop-Process -Name $_ -Force -ErrorAction SilentlyContinue }
Start-Sleep -Seconds 2

# open store settings
Start-Process "ms-windows-store:settings"
    }

Add-Tweak -Id 'updates-pause' -Category 'Setup' -Kind Action -Button 'Run' -Name 'Pause updates' -Risk Caution `
    -Description 'Pause Windows updates for one year' `
    -Apply {
# pause updates
$pause = (Get-Date).AddDays(365)
$today = Get-Date
$today = $today.ToUniversalTime().ToString( "yyyy-MM-ddTHH:mm:ssZ" )
$pause = $pause.ToUniversalTime().ToString( "yyyy-MM-ddTHH:mm:ssZ" )
Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings" -Name "PauseUpdatesExpiryTime" -Value $pause -Force >$null
Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings" -Name "PauseFeatureUpdatesEndTime" -Value $pause -Force >$null
Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings" -Name "PauseFeatureUpdatesStartTime" -Value $today -Force >$null
Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings" -Name "PauseQualityUpdatesEndTime" -Value $pause -Force >$null
Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings" -Name "PauseQualityUpdatesStartTime" -Value $today -Force >$null
Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings" -Name "PauseUpdatesStartTime" -Value $today -Force >$null

# open settings
Start-Process ms-settings:windowsupdate
    }
