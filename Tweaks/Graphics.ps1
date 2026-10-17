# Graphics category. GENERATED from the AkariOS-Ultimate '5 Graphics' scripts.

Add-Tweak -Id 'driver-clean' -Category 'Graphics' -Kind Group -Name 'Driver clean (DDU)' -Risk Advanced `
    -Description 'Remove the current graphics driver with DDU' `
    -Actions @(
        @{ Name = 'DDU: Auto'; Description = 'Run DDU automatically'; Button = 'Run'; Confirm = 'DDU will remove your graphics driver and restart the PC. Continue?'; Block = {
if (-not (Test-Connection -ComputerName '8.8.8.8' -Count 1 -Quiet -ErrorAction SilentlyContinue)) { Write-Log 'Internet connection required'; return }
# download 7zip
IWR "https://github.com/isleap9/AkariOS-Files/releases/download/Files/7zip.exe" -OutFile "$env:SystemRoot\Temp\7zip.exe"

# install 7zip
Start-Process -Wait "$env:SystemRoot\Temp\7zip.exe" -ArgumentList "/S"

# set config for 7zip
cmd /c "reg add `"HKEY_CURRENT_USER\Software\7-Zip\Options`" /v `"ContextMenu`" /t REG_DWORD /d `"259`" /f >nul 2>&1"
cmd /c "reg add `"HKEY_CURRENT_USER\Software\7-Zip\Options`" /v `"CascadedMenu`" /t REG_DWORD /d `"0`" /f >nul 2>&1"

# cleaner start menu shortcut path
Move-Item -Path "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\7-Zip\7-Zip File Manager.lnk" -Destination "$env:ProgramData\Microsoft\Windows\Start Menu\Programs" -Force -ErrorAction SilentlyContinue | Out-Null
Remove-Item "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\7-Zip" -Recurse -Force -ErrorAction SilentlyContinue | Out-Null

# download ddu
IWR "https://github.com/isleap9/AkariOS-Files/releases/download/Files/ddu.exe" -OutFile "$env:SystemRoot\Temp\ddu.exe"

# extract ddu with 7zip
& "$env:SystemDrive\Program Files\7-Zip\7z.exe" x "$env:SystemRoot\Temp\ddu.exe" -o"$env:SystemRoot\Temp\ddu" -y | Out-Null

# set config for ddu
$DduConfig = @'
<?xml version="1.0" encoding="utf-8"?>
<DisplayDriverUninstaller Version="18.1.4.2">
	<Settings>
		<SelectedLanguage>en-US</SelectedLanguage>
		<RemoveMonitors>True</RemoveMonitors>
		<RemoveCrimsonCache>True</RemoveCrimsonCache>
		<RemoveAMDDirs>True</RemoveAMDDirs>
		<RemoveAudioBus>True</RemoveAudioBus>
		<RemoveAMDKMPFD>True</RemoveAMDKMPFD>
		<RemoveNvidiaDirs>True</RemoveNvidiaDirs>
		<RemovePhysX>True</RemovePhysX>
		<Remove3DTVPlay>True</Remove3DTVPlay>
		<RemoveGFE>True</RemoveGFE>
		<RemoveNVBROADCAST>True</RemoveNVBROADCAST>
		<RemoveNVCP>True</RemoveNVCP>
		<RemoveINTELCP>True</RemoveINTELCP>
		<RemoveINTELIGS>True</RemoveINTELIGS>
		<RemoveOneAPI>True</RemoveOneAPI>
		<RemoveEnduranceGaming>True</RemoveEnduranceGaming>
		<RemoveIntelNpu>True</RemoveIntelNpu>
		<RemoveAMDCP>True</RemoveAMDCP>
		<UseRoamingConfig>False</UseRoamingConfig>
		<CheckUpdates>False</CheckUpdates>
		<CreateRestorePoint>False</CreateRestorePoint>
		<SaveLogs>False</SaveLogs>
		<RemoveVulkan>True</RemoveVulkan>
		<ShowOffer>False</ShowOffer>
		<EnableSafeModeDialog>False</EnableSafeModeDialog>
		<PreventWinUpdate>True</PreventWinUpdate>
		<UsedBCD>False</UsedBCD>
		<KeepNVCPopt>False</KeepNVCPopt>
		<RememberLastChoice>False</RememberLastChoice>
		<LastSelectedGPUIndex>0</LastSelectedGPUIndex>
		<LastSelectedTypeIndex>0</LastSelectedTypeIndex>
	</Settings>
</DisplayDriverUninstaller>
'@
Set-Content -Path "$env:SystemRoot\Temp\ddu\Settings\Settings.xml" -Value $DduConfig -Force

# set ddu config to read only
Set-ItemProperty -Path "$env:SystemRoot\Temp\ddu\Settings\Settings.xml" -Name IsReadOnly -Value $true

# prevent downloads of drivers from windows update
cmd /c "reg add `"HKLM\Software\Microsoft\Windows\CurrentVersion\DriverSearching`" /v `"SearchOrderConfig`" /t REG_DWORD /d `"0`" /f >nul 2>&1"

# create ddu ps1 file
$DDU = @'

# remove safe mode boot
cmd /c "bcdedit /deletevalue {current} safeboot >nul 2>&1"

Write-Host "DDU & RESTARTING`n" -ForegroundColor Red

# uninstall soundblaster realtek intel amd nvidia drivers & restart
Start-Process "$env:SystemRoot\Temp\ddu\Display Driver Uninstaller.exe" -ArgumentList "-CleanSoundBlaster -CleanRealtek -CleanAllGpus -Restart" -Wait
'@
Set-Content -Path "$env:SystemRoot\Temp\ddu.ps1" -Value $DDU -Force

# install runonce ddu ps1 file to run in safe boot
cmd /c "reg add `"HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce`" /v `"*ddu`" /t REG_SZ /d `"powershell.exe -nop -ep bypass -WindowStyle Maximized -f $env:SystemRoot\Temp\ddu.ps1`" /f >nul 2>&1"

# turn on safe boot
cmd /c "bcdedit /set {current} safeboot minimal >nul 2>&1"

Write-Host "RESTARTING`n" -ForegroundColor Red

# restart
Start-Sleep -Seconds 5
shutdown -r -t 00
        }},
        @{ Name = 'DDU: Manual'; Description = 'Open DDU to clean manually'; Button = 'Run'; Confirm = 'DDU will remove your graphics driver. Continue?'; Block = {
if (-not (Test-Connection -ComputerName '8.8.8.8' -Count 1 -Quiet -ErrorAction SilentlyContinue)) { Write-Log 'Internet connection required'; return }
# download 7zip
IWR "https://github.com/isleap9/AkariOS-Files/releases/download/Files/7zip.exe" -OutFile "$env:SystemRoot\Temp\7zip.exe"

# install 7zip
Start-Process -Wait "$env:SystemRoot\Temp\7zip.exe" -ArgumentList "/S"

# set config for 7zip
cmd /c "reg add `"HKEY_CURRENT_USER\Software\7-Zip\Options`" /v `"ContextMenu`" /t REG_DWORD /d `"259`" /f >nul 2>&1"
cmd /c "reg add `"HKEY_CURRENT_USER\Software\7-Zip\Options`" /v `"CascadedMenu`" /t REG_DWORD /d `"0`" /f >nul 2>&1"

# cleaner start menu shortcut path
Move-Item -Path "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\7-Zip\7-Zip File Manager.lnk" -Destination "$env:ProgramData\Microsoft\Windows\Start Menu\Programs" -Force -ErrorAction SilentlyContinue | Out-Null
Remove-Item "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\7-Zip" -Recurse -Force -ErrorAction SilentlyContinue | Out-Null

# download ddu
IWR "https://github.com/isleap9/AkariOS-Files/releases/download/Files/ddu.exe" -OutFile "$env:SystemRoot\Temp\ddu.exe"

# extract ddu with 7zip
& "$env:SystemDrive\Program Files\7-Zip\7z.exe" x "$env:SystemRoot\Temp\ddu.exe" -o"$env:SystemRoot\Temp\ddu" -y | Out-Null

# set config for ddu
$DduConfig = @'
<?xml version="1.0" encoding="utf-8"?>
<DisplayDriverUninstaller Version="18.1.4.2">
	<Settings>
		<SelectedLanguage>en-US</SelectedLanguage>
		<RemoveMonitors>True</RemoveMonitors>
		<RemoveCrimsonCache>True</RemoveCrimsonCache>
		<RemoveAMDDirs>True</RemoveAMDDirs>
		<RemoveAudioBus>True</RemoveAudioBus>
		<RemoveAMDKMPFD>True</RemoveAMDKMPFD>
		<RemoveNvidiaDirs>True</RemoveNvidiaDirs>
		<RemovePhysX>True</RemovePhysX>
		<Remove3DTVPlay>True</Remove3DTVPlay>
		<RemoveGFE>True</RemoveGFE>
		<RemoveNVBROADCAST>True</RemoveNVBROADCAST>
		<RemoveNVCP>True</RemoveNVCP>
		<RemoveINTELCP>True</RemoveINTELCP>
		<RemoveINTELIGS>True</RemoveINTELIGS>
		<RemoveOneAPI>True</RemoveOneAPI>
		<RemoveEnduranceGaming>True</RemoveEnduranceGaming>
		<RemoveIntelNpu>True</RemoveIntelNpu>
		<RemoveAMDCP>True</RemoveAMDCP>
		<UseRoamingConfig>False</UseRoamingConfig>
		<CheckUpdates>False</CheckUpdates>
		<CreateRestorePoint>False</CreateRestorePoint>
		<SaveLogs>False</SaveLogs>
		<RemoveVulkan>True</RemoveVulkan>
		<ShowOffer>False</ShowOffer>
		<EnableSafeModeDialog>False</EnableSafeModeDialog>
		<PreventWinUpdate>True</PreventWinUpdate>
		<UsedBCD>False</UsedBCD>
		<KeepNVCPopt>False</KeepNVCPopt>
		<RememberLastChoice>False</RememberLastChoice>
		<LastSelectedGPUIndex>0</LastSelectedGPUIndex>
		<LastSelectedTypeIndex>0</LastSelectedTypeIndex>
	</Settings>
</DisplayDriverUninstaller>
'@
Set-Content -Path "$env:SystemRoot\Temp\ddu\Settings\Settings.xml" -Value $DduConfig -Force

# set ddu config to read only
Set-ItemProperty -Path "$env:SystemRoot\Temp\ddu\Settings\Settings.xml" -Name IsReadOnly -Value $true

# prevent downloads of drivers from windows update
cmd /c "reg add `"HKLM\Software\Microsoft\Windows\CurrentVersion\DriverSearching`" /v `"SearchOrderConfig`" /t REG_DWORD /d `"0`" /f >nul 2>&1"

# create ddumanual ps1 file
$DDU = @'

# remove safe mode boot
cmd /c "bcdedit /deletevalue {current} safeboot >nul 2>&1"

Write-Host "DDU MANUAL`n"

# open ddu
Start-Process -Wait "$env:SystemRoot\Temp\ddu\Display Driver Uninstaller.exe"
'@
Set-Content -Path "$env:SystemRoot\Temp\ddumanual.ps1" -Value $DDU -Force

# install runonce ddumanual ps1 file to run in safe boot
cmd /c "reg add `"HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce`" /v `"*ddumanual`" /t REG_SZ /d `"powershell.exe -nop -ep bypass -WindowStyle Maximized -f $env:SystemRoot\Temp\ddumanual.ps1`" /f >nul 2>&1"

# turn on safe boot
cmd /c "bcdedit /set {current} safeboot minimal >nul 2>&1"

Write-Host "RESTARTING`n" -ForegroundColor Red

# restart
Start-Sleep -Seconds 5
shutdown -r -t 00
        }}
    )

Add-Tweak -Id 'driver-install' -Category 'Graphics' -Kind Group -Name 'Driver install (updated)' -Risk Caution `
    -Description 'Install the latest graphics driver' `
    -Actions @(
        @{ Name = 'NVIDIA'; Description = 'Driver install (updated): NVIDIA'; Button = 'Install'; Block = {
if (-not (Test-Connection -ComputerName '8.8.8.8' -Count 1 -Quiet -ErrorAction SilentlyContinue)) { Write-Log 'Internet connection required'; return }
Write-Host "NVIDIA APP TURN OFF:"
Write-Host "- Statistics"
Write-Host "- Game Filters"
Write-Host "- Automatically optimize newly added games and apps`n"

# find latest nvidia driver
$uri = 'https://gfwsl.geforce.com/services_toolkit/services/com/nvidia/services/AjaxDriverService.php?func=DriverManualLookup&psid=120&pfid=929&osID=57&languageCode=1033&isWHQL=1&dch=1&sort1=0&numberOfResults=1'
$response = Invoke-WebRequest -Uri $uri -Method GET -UseBasicParsing
$payload = $response.Content | ConvertFrom-Json
$version =  $payload.IDS[0].downloadInfo.Version
$windowsVersion = if ([Environment]::OSVersion.Version -ge (new-object 'Version' 9, 1)) {"win10-win11"} else {"win8-win7"}
$windowsArchitecture = if ([Environment]::Is64BitOperatingSystem) {"64bit"} else {"32bit"}
$url = "https://international.download.nvidia.com/Windows/$version/$version-desktop-$windowsVersion-$windowsArchitecture-international-dch-whql.exe"
Write-Output "Downloading: Nvidia Driver $version ..."

# download nvidia driver
IWR $url -OutFile "$env:SystemRoot\Temp\nvidiadriver.exe"

# open nvidia driver installer
Start-Process "$env:SystemRoot\Temp\nvidiadriver.exe"
        }},
        @{ Name = 'AMD'; Description = 'Driver install (updated): AMD'; Button = 'Install'; Block = {
if (-not (Test-Connection -ComputerName '8.8.8.8' -Count 1 -Quiet -ErrorAction SilentlyContinue)) { Write-Log 'Internet connection required'; return }
# download amd driver auto detect
$DownloadAmd = Invoke-WebRequest "https://www.amd.com/en/support/download/drivers.html" -UseBasicParsing |
Select-Object -ExpandProperty Links |
Where-Object { $_.href -match "drivers\.amd\.com/drivers/installer/.*/whql/amd-software-adrenalin-edition-.*-minimalsetup-.*_web\.exe" } | Select-Object href
$spoofwebbrowser = @{
"User-Agent" = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36"
"Accept"     = "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8"
"Referer"    = "https://www.amd.com/"
}
IWR $DownloadAmd.href -UseBasicParsing -Headers $spoofwebbrowser -OutFile "$env:SystemRoot\Temp\amddriver.exe" -ErrorAction SilentlyContinue | Out-Null

# open amd web driver installer
Start-Process "$env:SystemRoot\Temp\amddriver.exe"
        }},
        @{ Name = 'INTEL'; Description = 'Driver install (updated): INTEL'; Button = 'Install'; Block = {
if (-not (Test-Connection -ComputerName '8.8.8.8' -Count 1 -Quiet -ErrorAction SilentlyContinue)) { Write-Log 'Internet connection required'; return }
# open intel driver web page
Start-Process "https://www.intel.com/content/www/us/en/search.html#sortCriteria=%40lastmodifieddt%20descending&f-operatingsystem_en=Windows%2011%20Family*&f-downloadtype=Drivers&cf-tabfilter=Downloads&cf-downloadsppth=Graphics"
        }}
    )

Add-Tweak -Id 'driver-install-settings' -Category 'Graphics' -Kind Group -Name 'Driver install and settings (updated)' -Risk Caution `
    -Description 'Install the latest graphics driver and import optimized settings' `
    -Actions @(
        @{ Name = 'NVIDIA'; Description = 'Download, install, and configure the latest NVIDIA driver'; Button = 'Install'; Block = {
Write-Host "NVIDIA: Installing latest driver and importing settings..."
# download 7zip
IWR "https://github.com/isleap9/AkariOS-Files/releases/download/Files/7zip.exe" -OutFile "$env:SystemRoot\Temp\7zip.exe"
Start-Process -Wait "$env:SystemRoot\Temp\7zip.exe" -ArgumentList "/S"
cmd /c "reg add `"HKEY_CURRENT_USER\Software\7-Zip\Options`" /v `"ContextMenu`" /t REG_DWORD /d `"259`" /f >nul 2>&1"
cmd /c "reg add `"HKEY_CURRENT_USER\Software\7-Zip\Options`" /v `"CascadedMenu`" /t REG_DWORD /d `"0`" /f >nul 2>&1"
Move-Item -Path "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\7-Zip\7-Zip File Manager.lnk" -Destination "$env:ProgramData\Microsoft\Windows\Start Menu\Programs" -Force -ErrorAction SilentlyContinue | Out-Null
Remove-Item "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\7-Zip" -Recurse -Force -ErrorAction SilentlyContinue | Out-Null
# find latest nvidia driver
$uri = 'https://gfwsl.geforce.com/services_toolkit/services/com/nvidia/services/AjaxDriverService.php?func=DriverManualLookup&psid=120&pfid=929&osID=57&languageCode=1033&isWHQL=1&dch=1&sort1=0&numberOfResults=1'
$response = Invoke-WebRequest -Uri $uri -Method GET -UseBasicParsing
$payload = $response.Content | ConvertFrom-Json
$version = $payload.IDS[0].downloadInfo.Version
$windowsVersion = if ([Environment]::OSVersion.Version -ge (new-object 'Version' 9, 1)) {"win10-win11"} else {"win8-win7"}
$windowsArchitecture = if ([Environment]::Is64BitOperatingSystem) {"64bit"} else {"32bit"}
$url = "https://international.download.nvidia.com/Windows/$version/$version-desktop-$windowsVersion-$windowsArchitecture-international-dch-whql.exe"
Write-Host "Downloading: Nvidia Driver $version ..."
IWR $url -OutFile "$env:SystemRoot\Temp\nvidiadriver.exe"
& "$env:SystemDrive\Program Files\7-Zip\7z.exe" x "$env:SystemRoot\Temp\nvidiadriver.exe" -o"$env:SystemRoot\Temp\nvidiadriver" -y | Out-Null
Write-Host "Installing driver..."
Start-Process "$env:SystemRoot\Temp\nvidiadriver\setup.exe" -ArgumentList "-s -noreboot -noeula -clean" -Wait -NoNewWindow
IWR "https://github.com/isleap9/AkariOS-Files/releases/download/Files/nvp.appx" -OutFile "$env:SystemRoot\Temp\nvp.appx"
Add-AppxPackage -Path "$env:SystemRoot\Temp\nvp.appx" -ErrorAction SilentlyContinue | Out-Null
$WshShell = New-Object -comObject WScript.Shell
$Desktop = (New-Object -ComObject Shell.Application).Namespace('shell:Desktop').Self.Path
$Shortcut = $WshShell.CreateShortcut("$Desktop\NVIDIA Control Panel.lnk")
$Shortcut.TargetPath = "shell:appsFolder\NVIDIACorp.NVIDIAControlPanel_56jybvy8sckqj!NVIDIACorp.NVIDIAControlPanel"
$Shortcut.WorkingDirectory = "shell:appsFolder"
$Shortcut.Save()
Remove-Item "$env:SystemDrive\NVIDIA" -Recurse -Force -ErrorAction SilentlyContinue | Out-Null
Write-Host "Importing NVIDIA settings..."
$subkeys = Get-ChildItem -Path "Registry::HKLM\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}" -Force -ErrorAction SilentlyContinue
foreach($key in $subkeys){ if ($key -notlike '*Configuration'){ reg add "$key" /v "DisableDynamicPstate" /t REG_DWORD /d "1" /f | Out-Null } }
$subkeys = Get-ChildItem -Path "Registry::HKLM\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}" -Force -ErrorAction SilentlyContinue
foreach($key in $subkeys){ if ($key -notlike '*Configuration'){ reg add "$key" /v "RMHdcpKeyglobZero" /t REG_DWORD /d "1" /f | Out-Null } }
$path = "C:\ProgramData\NVIDIA Corporation\Drs"
Get-ChildItem -Path $path -Recurse | Unblock-File
cmd /c "reg add `"HKLM\System\ControlSet001\Services\nvlddmkm\Parameters\Global\NVTweak`" /v `"NvCplPhysxAuto`" /t REG_DWORD /d `"0`" /f >nul 2>&1"
cmd /c "reg add `"HKLM\System\ControlSet001\Services\nvlddmkm\Parameters\Global\NVTweak`" /v `"NvDevToolsVisible`" /t REG_DWORD /d `"1`" /f >nul 2>&1"
$subkeys = Get-ChildItem -Path "Registry::HKLM\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}" -Force -ErrorAction SilentlyContinue
foreach($key in $subkeys){ if ($key -notlike '*Configuration'){ reg add "$key" /v "RmProfilingAdminOnly" /t REG_DWORD /d "0" /f | Out-Null } }
cmd /c "reg add `"HKLM\System\ControlSet001\Services\nvlddmkm\Parameters\Global\NVTweak`" /v `"RmProfilingAdminOnly`" /t REG_DWORD /d `"0`" /f >nul 2>&1"
cmd /c "reg add `"HKCU\Software\NVIDIA Corporation\NvTray`" /v `"StartOnLogin`" /t REG_DWORD /d `"0`" /f >nul 2>&1"
cmd /c "reg add `"HKLM\SYSTEM\CurrentControlSet\Services\nvlddmkm\FTS`" /v `"EnableGR535`" /t REG_DWORD /d `"0`" /f >nul 2>&1"
cmd /c "reg add `"HKLM\SYSTEM\ControlSet001\Services\nvlddmkm\Parameters\FTS`" /v `"EnableGR535`" /t REG_DWORD /d `"0`" /f >nul 2>&1"
cmd /c "reg add `"HKLM\SYSTEM\CurrentControlSet\Services\nvlddmkm\Parameters\FTS`" /v `"EnableGR535`" /t REG_DWORD /d `"0`" /f >nul 2>&1"
New-Item -Path "$env:SystemDrive\Program Files (x86)\Nvidia Profile Inspector" -ItemType Directory -Force -ErrorAction SilentlyContinue | Out-Null
IWR "https://github.com/isleap9/AkariOS-Files/releases/download/Files/inspector.exe" -OutFile "$env:SystemDrive\Program Files (x86)\Nvidia Profile Inspector\Nvidia Profile Inspector.exe"
$WshShell = New-Object -comObject WScript.Shell
$Desktop = (New-Object -ComObject Shell.Application).Namespace('shell:Desktop').Self.Path
$Shortcut = $WshShell.CreateShortcut("$Desktop\Nvidia Profile Inspector.lnk")
$Shortcut.TargetPath = "$env:SystemDrive\Program Files (x86)\Nvidia Profile Inspector\Nvidia Profile Inspector.exe"
$Shortcut.WorkingDirectory = "$env:SystemDrive\Program Files (x86)\Nvidia Profile Inspector"
$Shortcut.Save()
$WshShell = New-Object -comObject WScript.Shell
$Shortcut = $WshShell.CreateShortcut("$env:ProgramData\Microsoft\Windows\Start Menu\Programs\Nvidia Profile Inspector.lnk")
$Shortcut.TargetPath = "$env:SystemDrive\Program Files (x86)\Nvidia Profile Inspector\Nvidia Profile Inspector.exe"
$Shortcut.WorkingDirectory = "$env:SystemDrive\Program Files (x86)\Nvidia Profile Inspector"
$Shortcut.Save()
$nipfile = @'
<?xml version="1.0" encoding="utf-16"?>
<ArrayOfProfile>
  <Profile>
    <ProfileName>Base Profile</ProfileName>
    <Executables/>
    <Settings>
      <ProfileSetting><SettingNameInfo>Frame Rate Limiter V3</SettingNameInfo><SettingID>277041154</SettingID><SettingValue>0</SettingValue><ValueType>Dword</ValueType></ProfileSetting>
      <ProfileSetting><SettingNameInfo>GSYNC - Application Mode</SettingNameInfo><SettingID>294973784</SettingID><SettingValue>0</SettingValue><ValueType>Dword</ValueType></ProfileSetting>
      <ProfileSetting><SettingNameInfo>GSYNC - Application State</SettingNameInfo><SettingID>279476687</SettingID><SettingValue>4</SettingValue><ValueType>Dword</ValueType></ProfileSetting>
      <ProfileSetting><SettingNameInfo>GSYNC - Global Feature</SettingNameInfo><SettingID>278196567</SettingID><SettingValue>0</SettingValue><ValueType>Dword</ValueType></ProfileSetting>
      <ProfileSetting><SettingNameInfo>GSYNC - Global Mode</SettingNameInfo><SettingID>278196727</SettingID><SettingValue>0</SettingValue><ValueType>Dword</ValueType></ProfileSetting>
      <ProfileSetting><SettingNameInfo>GSYNC - Indicator Overlay</SettingNameInfo><SettingID>268604728</SettingID><SettingValue>0</SettingValue><ValueType>Dword</ValueType></ProfileSetting>
      <ProfileSetting><SettingNameInfo>Maximum Pre-Rendered Frames</SettingNameInfo><SettingID>8102046</SettingID><SettingValue>1</SettingValue><ValueType>Dword</ValueType></ProfileSetting>
      <ProfileSetting><SettingNameInfo>Preferred Refresh Rate</SettingNameInfo><SettingID>6600001</SettingID><SettingValue>1</SettingValue><ValueType>Dword</ValueType></ProfileSetting>
      <ProfileSetting><SettingNameInfo>Ultra Low Latency - CPL State</SettingNameInfo><SettingID>390467</SettingID><SettingValue>2</SettingValue><ValueType>Dword</ValueType></ProfileSetting>
      <ProfileSetting><SettingNameInfo>Ultra Low Latency - Enabled</SettingNameInfo><SettingID>277041152</SettingID><SettingValue>1</SettingValue><ValueType>Dword</ValueType></ProfileSetting>
      <ProfileSetting><SettingNameInfo>Vertical Sync</SettingNameInfo><SettingID>11041231</SettingID><SettingValue>138504007</SettingValue><ValueType>Dword</ValueType></ProfileSetting>
      <ProfileSetting><SettingNameInfo>Vertical Sync - Smooth AFR Behavior</SettingNameInfo><SettingID>270198627</SettingID><SettingValue>0</SettingValue><ValueType>Dword</ValueType></ProfileSetting>
      <ProfileSetting><SettingNameInfo>Vertical Sync - Tear Control</SettingNameInfo><SettingID>5912412</SettingID><SettingValue>2525368439</SettingValue><ValueType>Dword</ValueType></ProfileSetting>
      <ProfileSetting><SettingNameInfo>Vulkan/OpenGL Present Method</SettingNameInfo><SettingID>550932728</SettingID><SettingValue>0</SettingValue><ValueType>Dword</ValueType></ProfileSetting>
      <ProfileSetting><SettingNameInfo>Antialiasing - Gamma Correction</SettingNameInfo><SettingID>276652957</SettingID><SettingValue>0</SettingValue><ValueType>Dword</ValueType></ProfileSetting>
      <ProfileSetting><SettingNameInfo>Antialiasing - Mode</SettingNameInfo><SettingID>276757595</SettingID><SettingValue>1</SettingValue><ValueType>Dword</ValueType></ProfileSetting>
      <ProfileSetting><SettingNameInfo>Antialiasing - Setting</SettingNameInfo><SettingID>282555346</SettingID><SettingValue>0</SettingValue><ValueType>Dword</ValueType></ProfileSetting>
      <ProfileSetting><SettingNameInfo>Anisotropic Filter - Optimization</SettingNameInfo><SettingID>8703344</SettingID><SettingValue>1</SettingValue><ValueType>Dword</ValueType></ProfileSetting>
      <ProfileSetting><SettingNameInfo>Anisotropic Filter - Sample Optimization</SettingNameInfo><SettingID>15151633</SettingID><SettingValue>1</SettingValue><ValueType>Dword</ValueType></ProfileSetting>
      <ProfileSetting><SettingNameInfo>Anisotropic Filtering - Mode</SettingNameInfo><SettingID>282245910</SettingID><SettingValue>1</SettingValue><ValueType>Dword</ValueType></ProfileSetting>
      <ProfileSetting><SettingNameInfo>Anisotropic Filtering - Setting</SettingNameInfo><SettingID>270426537</SettingID><SettingValue>1</SettingValue><ValueType>Dword</ValueType></ProfileSetting>
      <ProfileSetting><SettingNameInfo>Texture Filtering - Negative LOD Bias</SettingNameInfo><SettingID>1686376</SettingID><SettingValue>0</SettingValue><ValueType>Dword</ValueType></ProfileSetting>
      <ProfileSetting><SettingNameInfo>Texture Filtering - Quality</SettingNameInfo><SettingID>13510289</SettingID><SettingValue>20</SettingValue><ValueType>Dword</ValueType></ProfileSetting>
      <ProfileSetting><SettingNameInfo>Texture Filtering - Trilinear Optimization</SettingNameInfo><SettingID>3066610</SettingID><SettingValue>0</SettingValue><ValueType>Dword</ValueType></ProfileSetting>
      <ProfileSetting><SettingNameInfo>CUDA - Force P2 State</SettingNameInfo><SettingID>1343646814</SettingID><SettingValue>0</SettingValue><ValueType>Dword</ValueType></ProfileSetting>
      <ProfileSetting><SettingNameInfo>CUDA - Sysmem Fallback Policy</SettingNameInfo><SettingID>283962569</SettingID><SettingValue>1</SettingValue><ValueType>Dword</ValueType></ProfileSetting>
      <ProfileSetting><SettingNameInfo>Power Management - Mode</SettingNameInfo><SettingID>274197361</SettingID><SettingValue>1</SettingValue><ValueType>Dword</ValueType></ProfileSetting>
      <ProfileSetting><SettingNameInfo>Shader Cache - Cache Size</SettingNameInfo><SettingID>11306135</SettingID><SettingValue>4294967295</SettingValue><ValueType>Dword</ValueType></ProfileSetting>
      <ProfileSetting><SettingNameInfo>Threaded Optimization</SettingNameInfo><SettingID>549528094</SettingID><SettingValue>1</SettingValue><ValueType>Dword</ValueType></ProfileSetting>
      <ProfileSetting><SettingNameInfo>OpenGL GDI Compatibility</SettingNameInfo><SettingID>544392611</SettingID><SettingValue>0</SettingValue><ValueType>Dword</ValueType></ProfileSetting>
      <ProfileSetting><SettingNameInfo>Preferred OpenGL GPU</SettingNameInfo><SettingID>550564838</SettingID><SettingValue>id,2.0:268410DE,00000100,GF - (400,2,161,24564) @ (0)</SettingValue><ValueType>String</ValueType></ProfileSetting>
    </Settings>
  </Profile>
</ArrayOfProfile>
'@
Set-Content -Path "$env:SystemRoot\Temp\inspector.nip" -Value $nipfile -Force
Start-Process -Wait "$env:SystemDrive\Program Files (x86)\Nvidia Profile Inspector\Nvidia Profile Inspector.exe" -ArgumentList "-silentImport -silent $env:SystemRoot\Temp\inspector.nip"
Write-Host "NVIDIA driver installed and settings imported."
        }},
        @{ Name = 'AMD'; Description = 'Download, install, and configure the latest AMD driver'; Button = 'Install'; Block = {
Write-Host "AMD: Installing latest driver and importing settings..."
$DownloadAmd = Invoke-WebRequest "https://www.amd.com/en/support/download/drivers.html" -UseBasicParsing |
Select-Object -ExpandProperty Links |
Where-Object { $_.href -match "drivers\.amd\.com/drivers/installer/.*/whql/amd-software-adrenalin-edition-.*-minimalsetup-.*_web\.exe" } | Select-Object href
$spoofwebbrowser = @{
"User-Agent" = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36"
"Accept"     = "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8"
"Referer"    = "https://www.amd.com/"
}
IWR $DownloadAmd.href -UseBasicParsing -Headers $spoofwebbrowser -OutFile "$env:SystemRoot\Temp\amddriver.exe" -ErrorAction SilentlyContinue | Out-Null
Write-Host "Installing driver..."
Start-Process -Wait "$env:SystemRoot\Temp\amddriver.exe"
$WshShell = New-Object -comObject WScript.Shell
$Desktop = (New-Object -ComObject Shell.Application).Namespace('shell:Desktop').Self.Path
$Shortcut = $WshShell.CreateShortcut("$Desktop\AMD Radeon Software.lnk")
$Shortcut.TargetPath = "$env:SystemDrive\Program Files\AMD\CNext\CNext\RadeonSoftware.exe"
$Shortcut.WorkingDirectory = "$env:SystemDrive\Program Files\AMD\CNext\CNext"
$Shortcut.Save()
$folderName = "AMD Software$([char]0xA789) Adrenalin Edition"
Move-Item -Path "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\$folderName\$folderName.lnk" -Destination "$env:ProgramData\Microsoft\Windows\Start Menu\Programs" -Force -ErrorAction SilentlyContinue
Remove-Item "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\$folderName" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item "$env:SystemDrive\AMD" -Recurse -Force -ErrorAction SilentlyContinue | Out-Null
Write-Host "Importing AMD settings..."
Start-Process "$env:SystemDrive\Program Files\AMD\CNext\CNext\RadeonSoftware.exe"
Start-Sleep -Seconds 15
Stop-Process -Name "RadeonSoftware" -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 2
cmd /c "reg add `"HKCU\Software\AMD\CN`" /v `"AutoUpdate`" /t REG_DWORD /d `"0`" /f >nul 2>&1"
cmd /c "reg add `"HKCU\Software\AMD\CN`" /v `"WizardProfile`" /t REG_SZ /d `"PROFILE_CUSTOM`" /f >nul 2>&1"
$basePath = "HKLM:\System\ControlSet001\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}"
$adapterKeys = Get-ChildItem -Path $basePath -ErrorAction SilentlyContinue
foreach ($key in $adapterKeys) { if ($key.PSChildName -match '^\d{4}$') { $regPath = $key.Name; cmd /c "reg add `"$regPath`" /v `"KMD_DeLagEnabled`" /t REG_DWORD /d `"1`" /f >nul 2>&1" } }
$basePath = "HKLM:\System\ControlSet001\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}"
$allKeys = Get-ChildItem -Path $basePath -Recurse -ErrorAction SilentlyContinue
$optionKeys = $allKeys | Where-Object { $_.PSChildName -eq "UMD" }
foreach ($key in $optionKeys) { $regPath = $key.Name; cmd /c "reg add `"$regPath`" /v `"VSyncControl`" /t REG_BINARY /d `"3000`" /f >nul 2>&1" }
$basePath = "HKLM:\System\ControlSet001\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}"
$allKeys = Get-ChildItem -Path $basePath -Recurse -ErrorAction SilentlyContinue
$optionKeys = $allKeys | Where-Object { $_.PSChildName -eq "UMD" }
foreach ($key in $optionKeys) { $regPath = $key.Name; cmd /c "reg add `"$regPath`" /v `"TFQ`" /t REG_BINARY /d `"3200`" /f >nul 2>&1" }
$basePath = "HKLM:\System\ControlSet001\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}"
$allKeys = Get-ChildItem -Path $basePath -Recurse -ErrorAction SilentlyContinue
$optionKeys = $allKeys | Where-Object { $_.PSChildName -eq "UMD" }
foreach ($key in $optionKeys) { $regPath = $key.Name; cmd /c "reg add `"$regPath`" /v `"Tessellation`" /t REG_BINARY /d `"3100`" /f >nul 2>&1"; cmd /c "reg add `"$regPath`" /v `"Tessellation_OPTION`" /t REG_BINARY /d `"3200`" /f >nul 2>&1" }
cmd /c "reg add `"HKCU\Software\AMD\CN\CustomResolutions`" /v `"EulaAccepted`" /t REG_SZ /d `"true`" /f >nul 2>&1"
cmd /c "reg add `"HKCU\Software\AMD\CN\DisplayOverride`" /v `"EulaAccepted`" /t REG_SZ /d `"true`" /f >nul 2>&1"
$basePath = "HKLM:\System\ControlSet001\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}"
$allKeys = Get-ChildItem -Path $basePath -Recurse -ErrorAction SilentlyContinue
$optionKeys = $allKeys | Where-Object { $_.PSChildName -eq "power_v1" }
foreach ($key in $optionKeys) { $regPath = $key.Name; cmd /c "reg add `"$regPath`" /v `"abmlevel`" /t REG_BINARY /d `"00000000`" /f >nul 2>&1" }
cmd /c "reg add `"HKCU\Software\AMD\CN`" /v `"SystemTray`" /t REG_SZ /d `"false`" /f >nul 2>&1"
cmd /c "reg add `"HKCU\Software\AMD\CN`" /v `"CN_Hide_Toast_Notification`" /t REG_SZ /d `"true`" /f >nul 2>&1"
cmd /c "reg add `"HKCU\Software\AMD\CN`" /v `"AnimationEffect`" /t REG_SZ /d `"false`" /f >nul 2>&1"
cmd /c "reg delete `"HKCU\Software\AMD\CN\Notification`" /f >nul 2>&1"
cmd /c "reg add `"HKCU\Software\AMD\CN\Notification`" /f >nul 2>&1"
cmd /c "reg add `"HKCU\Software\AMD\CN\FreeSync`" /v `"AlreadyNotified`" /t REG_DWORD /d `"1`" /f >nul 2>&1"
cmd /c "reg add `"HKCU\Software\AMD\CN\OverlayNotification`" /v `"AlreadyNotified`" /t REG_DWORD /d `"1`" /f >nul 2>&1"
cmd /c "reg add `"HKCU\Software\AMD\CN\VirtualSuperResolution`" /v `"AlreadyNotified`" /t REG_DWORD /d `"1`" /f >nul 2>&1"
Write-Host "AMD driver installed and settings imported."
        }},
        @{ Name = 'Intel'; Description = 'Open Intel driver download page, select downloaded driver, install and configure'; Button = 'Install'; Block = {
Write-Host "Intel: Opening driver download page..."
Start-Process "https://www.intel.com/content/www/us/en/search.html#sortCriteria=%40lastmodifieddt%20descending&f-operatingsystem_en=Windows%2011%20Family*&f-downloadtype=Drivers&cf-tabfilter=Downloads&cf-downloadsppth=Graphics"
Start-Sleep -Seconds 5
Write-Host "Select downloaded driver..."
$InstallFile = Get-FilePath "Intel Driver Setup (*.exe)|*.exe|All Files (*.*)|*.*"
if (-not $InstallFile) { Write-Log 'Cancelled'; return }
Write-Host "Installing driver..."
Start-Process -Wait "$InstallFile"
$WshShell = New-Object -comObject WScript.Shell
$Desktop = (New-Object -ComObject Shell.Application).Namespace('shell:Desktop').Self.Path
$Shortcut = $WshShell.CreateShortcut("$Desktop\Intel Graphics Software.lnk")
$Shortcut.TargetPath = "$env:SystemDrive\Program Files\Intel\Intel Graphics Software\IntelGraphicsSoftware.exe"
$Shortcut.WorkingDirectory = "$env:SystemDrive\Program Files\Intel\Intel Graphics Software"
$Shortcut.Save()
Remove-Item "$InstallFile" -Force -ErrorAction SilentlyContinue | Out-Null
$FileName = "Intel$([char]0xAE) Graphics Software"
Move-Item -Path "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\Intel\Intel Graphics Software\$FileName.lnk" -Destination "$env:ProgramData\Microsoft\Windows\Start Menu\Programs" -Force -ErrorAction SilentlyContinue
Remove-Item "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\Intel" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item "$env:SystemDrive\Intel" -Recurse -Force -ErrorAction SilentlyContinue | Out-Null
Remove-Item "$env:SystemDrive\inteldriver" -Recurse -Force -ErrorAction SilentlyContinue | Out-Null
Write-Host "Importing Intel settings..."
$basePath = "HKLM:\System\ControlSet001\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}"
$adapterKeys = Get-ChildItem -Path $basePath -ErrorAction SilentlyContinue
foreach ($key in $adapterKeys) { if ($key.PSChildName -match '^\d{4}$') { $regPath = $key.Name; cmd /c "reg add `"$regPath\3DKeys`" /f >nul 2>&1" } }
$basePath = "HKLM:\System\ControlSet001\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}"
$allKeys = Get-ChildItem -Path $basePath -Recurse -ErrorAction SilentlyContinue
$optionKeys = $allKeys | Where-Object { $_.PSChildName -eq "3DKeys" }
foreach ($key in $optionKeys) { $regPath = $key.Name; cmd /c "reg add `"$regPath`" /v `"Global_AsyncFlipMode`" /t REG_DWORD /d `"2`" /f >nul 2>&1" }
$basePath = "HKLM:\System\ControlSet001\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}"
$allKeys = Get-ChildItem -Path $basePath -Recurse -ErrorAction SilentlyContinue
$optionKeys = $allKeys | Where-Object { $_.PSChildName -eq "3DKeys" }
foreach ($key in $optionKeys) { $regPath = $key.Name; cmd /c "reg add `"$regPath`" /v `"Global_LowLatency`" /t REG_DWORD /d `"1`" /f >nul 2>&1" }
cmd /c "reg add `"HKEY_CURRENT_USER\Software\Microsoft\DirectX\UserGpuPreferences`" /v `"DirectXUserGlobalSettings`" /t REG_SZ /d `"SwapEffectUpgradeEnable=1;VRROptimizeEnable=0;`" /f >nul 2>&1"
Write-Host "Intel driver installed and settings imported."
        }}
    )

Add-Tweak -Id 'driver-debloat' -Category 'Graphics' -Kind Group -Name 'Driver debloat install and settings' -Risk Caution `
    -Description 'Install a debloated graphics driver and import optimized settings' `
    -Actions @(
        @{ Name = 'NVIDIA'; Description = 'Select a downloaded NVIDIA driver, debloat it, install and configure'; Button = 'Install'; Block = {
Write-Host "NVIDIA: Debloating and installing driver..."
# download 7zip
IWR "https://github.com/isleap9/AkariOS-Files/releases/download/Files/7zip.exe" -OutFile "$env:SystemRoot\Temp\7zip.exe"
Start-Process -Wait "$env:SystemRoot\Temp\7zip.exe" -ArgumentList "/S"
cmd /c "reg add `"HKEY_CURRENT_USER\Software\7-Zip\Options`" /v `"ContextMenu`" /t REG_DWORD /d `"259`" /f >nul 2>&1"
cmd /c "reg add `"HKEY_CURRENT_USER\Software\7-Zip\Options`" /v `"CascadedMenu`" /t REG_DWORD /d `"0`" /f >nul 2>&1"
Move-Item -Path "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\7-Zip\7-Zip File Manager.lnk" -Destination "$env:ProgramData\Microsoft\Windows\Start Menu\Programs" -Force -ErrorAction SilentlyContinue | Out-Null
Remove-Item "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\7-Zip" -Recurse -Force -ErrorAction SilentlyContinue | Out-Null
Write-Host "Select downloaded NVIDIA driver..."
$InstallFile = Get-FilePath "NVIDIA Driver (*.exe)|*.exe|All Files (*.*)|*.*"
if (-not $InstallFile) { Write-Log 'Cancelled'; return }
Write-Host "Debloating driver..."
& "$env:SystemDrive\Program Files\7-Zip\7z.exe" x "$InstallFile" -o"$env:SystemRoot\Temp\nvidiadriver" -y | Out-Null
Remove-Item "$env:SystemRoot\Temp\nvidiadriver\Display.Nview" -Recurse -Force -ErrorAction SilentlyContinue | Out-Null
Remove-Item "$env:SystemRoot\Temp\nvidiadriver\FrameViewSDK" -Recurse -Force -ErrorAction SilentlyContinue | Out-Null
Remove-Item "$env:SystemRoot\Temp\nvidiadriver\HDAudio" -Recurse -Force -ErrorAction SilentlyContinue | Out-Null
Remove-Item "$env:SystemRoot\Temp\nvidiadriver\MSVCRT" -Recurse -Force -ErrorAction SilentlyContinue | Out-Null
Remove-Item "$env:SystemRoot\Temp\nvidiadriver\NvApp.MessageBus" -Recurse -Force -ErrorAction SilentlyContinue | Out-Null
Remove-Item "$env:SystemRoot\Temp\nvidiadriver\NvBackend" -Recurse -Force -ErrorAction SilentlyContinue | Out-Null
Remove-Item "$env:SystemRoot\Temp\nvidiadriver\NvContainer" -Recurse -Force -ErrorAction SilentlyContinue | Out-Null
Remove-Item "$env:SystemRoot\Temp\nvidiadriver\NvCpl" -Recurse -Force -ErrorAction SilentlyContinue | Out-Null
Remove-Item "$env:SystemRoot\Temp\nvidiadriver\NvDLISR" -Recurse -Force -ErrorAction SilentlyContinue | Out-Null
Remove-Item "$env:SystemRoot\Temp\nvidiadriver\NVPCF" -Recurse -Force -ErrorAction SilentlyContinue | Out-Null
Remove-Item "$env:SystemRoot\Temp\nvidiadriver\NvTelemetry" -Recurse -Force -ErrorAction SilentlyContinue | Out-Null
Remove-Item "$env:SystemRoot\Temp\nvidiadriver\NvVAD" -Recurse -Force -ErrorAction SilentlyContinue | Out-Null
Remove-Item "$env:SystemRoot\Temp\nvidiadriver\PhysX" -Recurse -Force -ErrorAction SilentlyContinue | Out-Null
Remove-Item "$env:SystemRoot\Temp\nvidiadriver\PPC" -Recurse -Force -ErrorAction SilentlyContinue | Out-Null
Remove-Item "$env:SystemRoot\Temp\nvidiadriver\ShadowPlay" -Recurse -Force -ErrorAction SilentlyContinue | Out-Null
Remove-Item "$env:SystemRoot\Temp\nvidiadriver\NvApp\CEF" -Recurse -Force -ErrorAction SilentlyContinue | Out-Null
Remove-Item "$env:SystemRoot\Temp\nvidiadriver\NvApp\osc" -Recurse -Force -ErrorAction SilentlyContinue | Out-Null
Remove-Item "$env:SystemRoot\Temp\nvidiadriver\NvApp\Plugins" -Recurse -Force -ErrorAction SilentlyContinue | Out-Null
Remove-Item "$env:SystemRoot\Temp\nvidiadriver\NvApp\UpgradeConsent" -Recurse -Force -ErrorAction SilentlyContinue | Out-Null
Remove-Item "$env:SystemRoot\Temp\nvidiadriver\NvApp\www" -Recurse -Force -ErrorAction SilentlyContinue | Out-Null
Remove-Item "$env:SystemRoot\Temp\nvidiadriver\NvApp\7z.dll" -Force -ErrorAction SilentlyContinue | Out-Null
Remove-Item "$env:SystemRoot\Temp\nvidiadriver\NvApp\7z.exe" -Force -ErrorAction SilentlyContinue | Out-Null
Remove-Item "$env:SystemRoot\Temp\nvidiadriver\NvApp\DarkModeCheck.exe" -Force -ErrorAction SilentlyContinue | Out-Null
Remove-Item "$env:SystemRoot\Temp\nvidiadriver\NvApp\InstallerExtension.dll" -Force -ErrorAction SilentlyContinue | Out-Null
Remove-Item "$env:SystemRoot\Temp\nvidiadriver\NvApp\NvApp.nvi" -Force -ErrorAction SilentlyContinue | Out-Null
Remove-Item "$env:SystemRoot\Temp\nvidiadriver\NvApp\NvAppApi.dll" -Force -ErrorAction SilentlyContinue | Out-Null
Remove-Item "$env:SystemRoot\Temp\nvidiadriver\NvApp\NvAppExt.dll" -Force -ErrorAction SilentlyContinue | Out-Null
Remove-Item "$env:SystemRoot\Temp\nvidiadriver\NvApp\NvConfigGenerator.dll" -Force -ErrorAction SilentlyContinue | Out-Null
Write-Host "Installing driver..."
Start-Process "$env:SystemRoot\Temp\nvidiadriver\setup.exe" -ArgumentList "-s -noreboot -noeula -clean" -Wait -NoNewWindow
IWR "https://github.com/isleap9/AkariOS-Files/releases/download/Files/nvp.appx" -OutFile "$env:SystemRoot\Temp\nvp.appx"
Add-AppxPackage -Path "$env:SystemRoot\Temp\nvp.appx" -ErrorAction SilentlyContinue | Out-Null
$WshShell = New-Object -comObject WScript.Shell
$Desktop = (New-Object -ComObject Shell.Application).Namespace('shell:Desktop').Self.Path
$Shortcut = $WshShell.CreateShortcut("$Desktop\NVIDIA Control Panel.lnk")
$Shortcut.TargetPath = "shell:appsFolder\NVIDIACorp.NVIDIAControlPanel_56jybvy8sckqj!NVIDIACorp.NVIDIAControlPanel"
$Shortcut.WorkingDirectory = "shell:appsFolder"
$Shortcut.Save()
Remove-Item "$InstallFile" -Force -ErrorAction SilentlyContinue | Out-Null
Remove-Item "$env:SystemDrive\NVIDIA" -Recurse -Force -ErrorAction SilentlyContinue | Out-Null
Write-Host "Importing NVIDIA settings..."
$subkeys = Get-ChildItem -Path "Registry::HKLM\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}" -Force -ErrorAction SilentlyContinue
foreach($key in $subkeys){ if ($key -notlike '*Configuration'){ reg add "$key" /v "DisableDynamicPstate" /t REG_DWORD /d "1" /f | Out-Null } }
$subkeys = Get-ChildItem -Path "Registry::HKLM\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}" -Force -ErrorAction SilentlyContinue
foreach($key in $subkeys){ if ($key -notlike '*Configuration'){ reg add "$key" /v "RMHdcpKeyglobZero" /t REG_DWORD /d "1" /f | Out-Null } }
$path = "C:\ProgramData\NVIDIA Corporation\Drs"
Get-ChildItem -Path $path -Recurse | Unblock-File
cmd /c "reg add `"HKLM\System\ControlSet001\Services\nvlddmkm\Parameters\Global\NVTweak`" /v `"NvCplPhysxAuto`" /t REG_DWORD /d `"0`" /f >nul 2>&1"
cmd /c "reg add `"HKLM\System\ControlSet001\Services\nvlddmkm\Parameters\Global\NVTweak`" /v `"NvDevToolsVisible`" /t REG_DWORD /d `"1`" /f >nul 2>&1"
$subkeys = Get-ChildItem -Path "Registry::HKLM\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}" -Force -ErrorAction SilentlyContinue
foreach($key in $subkeys){ if ($key -notlike '*Configuration'){ reg add "$key" /v "RmProfilingAdminOnly" /t REG_DWORD /d "0" /f | Out-Null } }
cmd /c "reg add `"HKLM\System\ControlSet001\Services\nvlddmkm\Parameters\Global\NVTweak`" /v `"RmProfilingAdminOnly`" /t REG_DWORD /d `"0`" /f >nul 2>&1"
cmd /c "reg add `"HKCU\Software\NVIDIA Corporation\NvTray`" /v `"StartOnLogin`" /t REG_DWORD /d `"0`" /f >nul 2>&1"
cmd /c "reg add `"HKLM\SYSTEM\CurrentControlSet\Services\nvlddmkm\FTS`" /v `"EnableGR535`" /t REG_DWORD /d `"0`" /f >nul 2>&1"
cmd /c "reg add `"HKLM\SYSTEM\ControlSet001\Services\nvlddmkm\Parameters\FTS`" /v `"EnableGR535`" /t REG_DWORD /d `"0`" /f >nul 2>&1"
cmd /c "reg add `"HKLM\SYSTEM\CurrentControlSet\Services\nvlddmkm\Parameters\FTS`" /v `"EnableGR535`" /t REG_DWORD /d `"0`" /f >nul 2>&1"
New-Item -Path "$env:SystemDrive\Program Files (x86)\Nvidia Profile Inspector" -ItemType Directory -Force -ErrorAction SilentlyContinue | Out-Null
IWR "https://github.com/isleap9/AkariOS-Files/releases/download/Files/inspector.exe" -OutFile "$env:SystemDrive\Program Files (x86)\Nvidia Profile Inspector\Nvidia Profile Inspector.exe"
$WshShell = New-Object -comObject WScript.Shell
$Desktop = (New-Object -ComObject Shell.Application).Namespace('shell:Desktop').Self.Path
$Shortcut = $WshShell.CreateShortcut("$Desktop\Nvidia Profile Inspector.lnk")
$Shortcut.TargetPath = "$env:SystemDrive\Program Files (x86)\Nvidia Profile Inspector\Nvidia Profile Inspector.exe"
$Shortcut.WorkingDirectory = "$env:SystemDrive\Program Files (x86)\Nvidia Profile Inspector"
$Shortcut.Save()
$WshShell = New-Object -comObject WScript.Shell
$Shortcut = $WshShell.CreateShortcut("$env:ProgramData\Microsoft\Windows\Start Menu\Programs\Nvidia Profile Inspector.lnk")
$Shortcut.TargetPath = "$env:SystemDrive\Program Files (x86)\Nvidia Profile Inspector\Nvidia Profile Inspector.exe"
$Shortcut.WorkingDirectory = "$env:SystemDrive\Program Files (x86)\Nvidia Profile Inspector"
$Shortcut.Save()
$nipfile = @'
<?xml version="1.0" encoding="utf-16"?>
<ArrayOfProfile>
  <Profile>
    <ProfileName>Base Profile</ProfileName>
    <Executables/>
    <Settings>
      <ProfileSetting><SettingNameInfo>Frame Rate Limiter V3</SettingNameInfo><SettingID>277041154</SettingID><SettingValue>0</SettingValue><ValueType>Dword</ValueType></ProfileSetting>
      <ProfileSetting><SettingNameInfo>GSYNC - Application Mode</SettingNameInfo><SettingID>294973784</SettingID><SettingValue>0</SettingValue><ValueType>Dword</ValueType></ProfileSetting>
      <ProfileSetting><SettingNameInfo>GSYNC - Application State</SettingNameInfo><SettingID>279476687</SettingID><SettingValue>4</SettingValue><ValueType>Dword</ValueType></ProfileSetting>
      <ProfileSetting><SettingNameInfo>GSYNC - Global Feature</SettingNameInfo><SettingID>278196567</SettingID><SettingValue>0</SettingValue><ValueType>Dword</ValueType></ProfileSetting>
      <ProfileSetting><SettingNameInfo>GSYNC - Global Mode</SettingNameInfo><SettingID>278196727</SettingID><SettingValue>0</SettingValue><ValueType>Dword</ValueType></ProfileSetting>
      <ProfileSetting><SettingNameInfo>GSYNC - Indicator Overlay</SettingNameInfo><SettingID>268604728</SettingID><SettingValue>0</SettingValue><ValueType>Dword</ValueType></ProfileSetting>
      <ProfileSetting><SettingNameInfo>Maximum Pre-Rendered Frames</SettingNameInfo><SettingID>8102046</SettingID><SettingValue>1</SettingValue><ValueType>Dword</ValueType></ProfileSetting>
      <ProfileSetting><SettingNameInfo>Preferred Refresh Rate</SettingNameInfo><SettingID>6600001</SettingID><SettingValue>1</SettingValue><ValueType>Dword</ValueType></ProfileSetting>
      <ProfileSetting><SettingNameInfo>Ultra Low Latency - CPL State</SettingNameInfo><SettingID>390467</SettingID><SettingValue>2</SettingValue><ValueType>Dword</ValueType></ProfileSetting>
      <ProfileSetting><SettingNameInfo>Ultra Low Latency - Enabled</SettingNameInfo><SettingID>277041152</SettingID><SettingValue>1</SettingValue><ValueType>Dword</ValueType></ProfileSetting>
      <ProfileSetting><SettingNameInfo>Vertical Sync</SettingNameInfo><SettingID>11041231</SettingID><SettingValue>138504007</SettingValue><ValueType>Dword</ValueType></ProfileSetting>
      <ProfileSetting><SettingNameInfo>Vertical Sync - Smooth AFR Behavior</SettingNameInfo><SettingID>270198627</SettingID><SettingValue>0</SettingValue><ValueType>Dword</ValueType></ProfileSetting>
      <ProfileSetting><SettingNameInfo>Vertical Sync - Tear Control</SettingNameInfo><SettingID>5912412</SettingID><SettingValue>2525368439</SettingValue><ValueType>Dword</ValueType></ProfileSetting>
      <ProfileSetting><SettingNameInfo>Vulkan/OpenGL Present Method</SettingNameInfo><SettingID>550932728</SettingID><SettingValue>0</SettingValue><ValueType>Dword</ValueType></ProfileSetting>
      <ProfileSetting><SettingNameInfo>Antialiasing - Gamma Correction</SettingNameInfo><SettingID>276652957</SettingID><SettingValue>0</SettingValue><ValueType>Dword</ValueType></ProfileSetting>
      <ProfileSetting><SettingNameInfo>Antialiasing - Mode</SettingNameInfo><SettingID>276757595</SettingID><SettingValue>1</SettingValue><ValueType>Dword</ValueType></ProfileSetting>
      <ProfileSetting><SettingNameInfo>Antialiasing - Setting</SettingNameInfo><SettingID>282555346</SettingID><SettingValue>0</SettingValue><ValueType>Dword</ValueType></ProfileSetting>
      <ProfileSetting><SettingNameInfo>Anisotropic Filter - Optimization</SettingNameInfo><SettingID>8703344</SettingID><SettingValue>1</SettingValue><ValueType>Dword</ValueType></ProfileSetting>
      <ProfileSetting><SettingNameInfo>Anisotropic Filter - Sample Optimization</SettingNameInfo><SettingID>15151633</SettingID><SettingValue>1</SettingValue><ValueType>Dword</ValueType></ProfileSetting>
      <ProfileSetting><SettingNameInfo>Anisotropic Filtering - Mode</SettingNameInfo><SettingID>282245910</SettingID><SettingValue>1</SettingValue><ValueType>Dword</ValueType></ProfileSetting>
      <ProfileSetting><SettingNameInfo>Anisotropic Filtering - Setting</SettingNameInfo><SettingID>270426537</SettingID><SettingValue>1</SettingValue><ValueType>Dword</ValueType></ProfileSetting>
      <ProfileSetting><SettingNameInfo>Texture Filtering - Negative LOD Bias</SettingNameInfo><SettingID>1686376</SettingID><SettingValue>0</SettingValue><ValueType>Dword</ValueType></ProfileSetting>
      <ProfileSetting><SettingNameInfo>Texture Filtering - Quality</SettingNameInfo><SettingID>13510289</SettingID><SettingValue>20</SettingValue><ValueType>Dword</ValueType></ProfileSetting>
      <ProfileSetting><SettingNameInfo>Texture Filtering - Trilinear Optimization</SettingNameInfo><SettingID>3066610</SettingID><SettingValue>0</SettingValue><ValueType>Dword</ValueType></ProfileSetting>
      <ProfileSetting><SettingNameInfo>CUDA - Force P2 State</SettingNameInfo><SettingID>1343646814</SettingID><SettingValue>0</SettingValue><ValueType>Dword</ValueType></ProfileSetting>
      <ProfileSetting><SettingNameInfo>CUDA - Sysmem Fallback Policy</SettingNameInfo><SettingID>283962569</SettingID><SettingValue>1</SettingValue><ValueType>Dword</ValueType></ProfileSetting>
      <ProfileSetting><SettingNameInfo>Power Management - Mode</SettingNameInfo><SettingID>274197361</SettingID><SettingValue>1</SettingValue><ValueType>Dword</ValueType></ProfileSetting>
      <ProfileSetting><SettingNameInfo>Shader Cache - Cache Size</SettingNameInfo><SettingID>11306135</SettingID><SettingValue>4294967295</SettingValue><ValueType>Dword</ValueType></ProfileSetting>
      <ProfileSetting><SettingNameInfo>Threaded Optimization</SettingNameInfo><SettingID>549528094</SettingID><SettingValue>1</SettingValue><ValueType>Dword</ValueType></ProfileSetting>
      <ProfileSetting><SettingNameInfo>OpenGL GDI Compatibility</SettingNameInfo><SettingID>544392611</SettingID><SettingValue>0</SettingValue><ValueType>Dword</ValueType></ProfileSetting>
      <ProfileSetting><SettingNameInfo>Preferred OpenGL GPU</SettingNameInfo><SettingID>550564838</SettingID><SettingValue>id,2.0:268410DE,00000100,GF - (400,2,161,24564) @ (0)</SettingValue><ValueType>String</ValueType></ProfileSetting>
    </Settings>
  </Profile>
</ArrayOfProfile>
'@
Set-Content -Path "$env:SystemRoot\Temp\inspector.nip" -Value $nipfile -Force
Start-Process -Wait "$env:SystemDrive\Program Files (x86)\Nvidia Profile Inspector\Nvidia Profile Inspector.exe" -ArgumentList "-silentImport -silent $env:SystemRoot\Temp\inspector.nip"
Write-Host "NVIDIA driver debloated, installed, and settings imported."
        }},
        @{ Name = 'AMD'; Description = 'Select a downloaded AMD driver, debloat it, install and configure'; Button = 'Install'; Block = {
Write-Host "AMD: Debloating and installing driver..."
# download 7zip
IWR "https://github.com/isleap9/AkariOS-Files/releases/download/Files/7zip.exe" -OutFile "$env:SystemRoot\Temp\7zip.exe"
Start-Process -Wait "$env:SystemRoot\Temp\7zip.exe" -ArgumentList "/S"
cmd /c "reg add `"HKEY_CURRENT_USER\Software\7-Zip\Options`" /v `"ContextMenu`" /t REG_DWORD /d `"259`" /f >nul 2>&1"
cmd /c "reg add `"HKEY_CURRENT_USER\Software\7-Zip\Options`" /v `"CascadedMenu`" /t REG_DWORD /d `"0`" /f >nul 2>&1"
Move-Item -Path "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\7-Zip\7-Zip File Manager.lnk" -Destination "$env:ProgramData\Microsoft\Windows\Start Menu\Programs" -Force -ErrorAction SilentlyContinue | Out-Null
Remove-Item "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\7-Zip" -Recurse -Force -ErrorAction SilentlyContinue | Out-Null
Write-Host "Select downloaded AMD driver..."
$InstallFile = Get-FilePath "AMD Driver (*.exe)|*.exe|All Files (*.*)|*.*"
if (-not $InstallFile) { Write-Log 'Cancelled'; return }
Write-Host "Debloating driver..."
& "$env:SystemDrive\Program Files\7-Zip\7z.exe" x "$InstallFile" -o"$env:SystemRoot\Temp\amddriver" -y | Out-Null
$xmlFiles = @(
"$env:SystemRoot\Temp\amddriver\Config\AMDAUEPInstaller.xml"
"$env:SystemRoot\Temp\amddriver\Config\AMDCOMPUTE.xml"
"$env:SystemRoot\Temp\amddriver\Config\AMDLinkDriverUpdate.xml"
"$env:SystemRoot\Temp\amddriver\Config\AMDRELAUNCHER.xml"
"$env:SystemRoot\Temp\amddriver\Config\AMDScoSupportTypeUpdate.xml"
"$env:SystemRoot\Temp\amddriver\Config\AMDUpdater.xml"
"$env:SystemRoot\Temp\amddriver\Config\AMDUWPLauncher.xml"
"$env:SystemRoot\Temp\amddriver\Config\EnableWindowsDriverSearch.xml"
"$env:SystemRoot\Temp\amddriver\Config\InstallUEP.xml"
"$env:SystemRoot\Temp\amddriver\Config\ModifyLinkUpdate.xml"
)
foreach ($file in $xmlFiles) {
if (Test-Path $file) {
$content = Get-Content $file -Raw
$content = $content -replace '<Enabled>true</Enabled>', '<Enabled>false</Enabled>'
$content = $content -replace '<Hidden>true</Hidden>', '<Hidden>false</Hidden>'
Set-Content $file -Value $content -NoNewline
}
}
$jsonFiles = @(
"$env:SystemRoot\Temp\amddriver\Config\InstallManifest.json"
"$env:SystemRoot\Temp\amddriver\Bin64\cccmanifest_64.json"
)
foreach ($file in $jsonFiles) {
if (Test-Path $file) {
$content = Get-Content $file -Raw
$content = $content -replace '"InstallByDefault"\s*:\s*"Yes"', '"InstallByDefault" : "No"'
Set-Content $file -Value $content -NoNewline
}
}
Write-Host "Installing driver..."
Start-Process -Wait "$env:SystemRoot\Temp\amddriver\Bin64\ATISetup.exe" -ArgumentList "-INSTALL -VIEW:2" -WindowStyle Hidden
for ($i = 90; $i -gt 0; $i--) { Write-Host "`rWAITING FOR AMD DRIVER TIMEOUT $i ... " -NoNewline; Start-Sleep -Seconds 1 }
Write-Host "Cleaning up AMD bloat..."
cmd /c "reg delete `"HKCU\Software\Microsoft\Windows\CurrentVersion\Run`" /v `"AMDNoiseSuppression`" /f >nul 2>&1"
cmd /c "reg delete `"HKCU\Software\Microsoft\Windows\CurrentVersion\RunOnce`" /v `"StartRSX`" /f >nul 2>&1"
Unregister-ScheduledTask -TaskName "StartCN" -Confirm:$false -ErrorAction SilentlyContinue
cmd /c "sc stop `"AMD Crash Defender Service`" >nul 2>&1"
cmd /c "sc delete `"AMD Crash Defender Service`" >nul 2>&1"
cmd /c "sc stop `"amdfendr`" >nul 2>&1"
cmd /c "sc delete `"amdfendr`" >nul 2>&1"
cmd /c "sc stop `"amdfendrmgr`" >nul 2>&1"
cmd /c "sc delete `"amdfendrmgr`" >nul 2>&1"
cmd /c "sc stop `"amdacpbus`" >nul 2>&1"
cmd /c "sc delete `"amdacpbus`" >nul 2>&1"
cmd /c "sc stop `"AMDSAFD`" >nul 2>&1"
cmd /c "sc delete `"AMDSAFD`" >nul 2>&1"
cmd /c "sc stop `"AtiHDAudioService`" >nul 2>&1"
cmd /c "sc delete `"AtiHDAudioService`" >nul 2>&1"
Remove-Item "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\AMD Bug Report Tool" -Recurse -Force -ErrorAction SilentlyContinue | Out-Null
Remove-Item "$env:SystemDrive\Windows\SysWOW64\AMDBugReportTool.exe" -Force -ErrorAction SilentlyContinue | Out-Null
$findamdinstallmanager = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*"
$amdinstallmanager = Get-ItemProperty $findamdinstallmanager -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like "*AMD Install Manager*" }
if ($amdinstallmanager) { $guid = $amdinstallmanager.PSChildName; Start-Process "msiexec.exe" -ArgumentList "/x $guid /qn /norestart" -Wait -NoNewWindow }
Remove-Item "$InstallFile" -Force -ErrorAction SilentlyContinue | Out-Null
$WshShell = New-Object -comObject WScript.Shell
$Desktop = (New-Object -ComObject Shell.Application).Namespace('shell:Desktop').Self.Path
$Shortcut = $WshShell.CreateShortcut("$Desktop\AMD Radeon Software.lnk")
$Shortcut.TargetPath = "$env:SystemDrive\Program Files\AMD\CNext\CNext\RadeonSoftware.exe"
$Shortcut.WorkingDirectory = "$env:SystemDrive\Program Files\AMD\CNext\CNext"
$Shortcut.Save()
$folderName = "AMD Software$([char]0xA789) Adrenalin Edition"
Move-Item -Path "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\$folderName\$folderName.lnk" -Destination "$env:ProgramData\Microsoft\Windows\Start Menu\Programs" -Force -ErrorAction SilentlyContinue
Remove-Item "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\$folderName" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item "$env:SystemDrive\AMD" -Recurse -Force -ErrorAction SilentlyContinue | Out-Null
Write-Host "Importing AMD settings..."
Start-Process "$env:SystemDrive\Program Files\AMD\CNext\CNext\RadeonSoftware.exe"
Start-Sleep -Seconds 15
Stop-Process -Name "RadeonSoftware" -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 2
cmd /c "reg add `"HKCU\Software\AMD\CN`" /v `"AutoUpdate`" /t REG_DWORD /d `"0`" /f >nul 2>&1"
cmd /c "reg add `"HKCU\Software\AMD\CN`" /v `"WizardProfile`" /t REG_SZ /d `"PROFILE_CUSTOM`" /f >nul 2>&1"
$basePath = "HKLM:\System\ControlSet001\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}"
$adapterKeys = Get-ChildItem -Path $basePath -ErrorAction SilentlyContinue
foreach ($key in $adapterKeys) { if ($key.PSChildName -match '^\d{4}$') { $regPath = $key.Name; cmd /c "reg add `"$regPath`" /v `"KMD_DeLagEnabled`" /t REG_DWORD /d `"1`" /f >nul 2>&1" } }
$basePath = "HKLM:\System\ControlSet001\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}"
$allKeys = Get-ChildItem -Path $basePath -Recurse -ErrorAction SilentlyContinue
$optionKeys = $allKeys | Where-Object { $_.PSChildName -eq "UMD" }
foreach ($key in $optionKeys) { $regPath = $key.Name; cmd /c "reg add `"$regPath`" /v `"VSyncControl`" /t REG_BINARY /d `"3000`" /f >nul 2>&1" }
$basePath = "HKLM:\System\ControlSet001\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}"
$allKeys = Get-ChildItem -Path $basePath -Recurse -ErrorAction SilentlyContinue
$optionKeys = $allKeys | Where-Object { $_.PSChildName -eq "UMD" }
foreach ($key in $optionKeys) { $regPath = $key.Name; cmd /c "reg add `"$regPath`" /v `"TFQ`" /t REG_BINARY /d `"3200`" /f >nul 2>&1" }
$basePath = "HKLM:\System\ControlSet001\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}"
$allKeys = Get-ChildItem -Path $basePath -Recurse -ErrorAction SilentlyContinue
$optionKeys = $allKeys | Where-Object { $_.PSChildName -eq "UMD" }
foreach ($key in $optionKeys) { $regPath = $key.Name; cmd /c "reg add `"$regPath`" /v `"Tessellation`" /t REG_BINARY /d `"3100`" /f >nul 2>&1"; cmd /c "reg add `"$regPath`" /v `"Tessellation_OPTION`" /t REG_BINARY /d `"3200`" /f >nul 2>&1" }
cmd /c "reg add `"HKCU\Software\AMD\CN\CustomResolutions`" /v `"EulaAccepted`" /t REG_SZ /d `"true`" /f >nul 2>&1"
cmd /c "reg add `"HKCU\Software\AMD\CN\DisplayOverride`" /v `"EulaAccepted`" /t REG_SZ /d `"true`" /f >nul 2>&1"
$basePath = "HKLM:\System\ControlSet001\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}"
$allKeys = Get-ChildItem -Path $basePath -Recurse -ErrorAction SilentlyContinue
$optionKeys = $allKeys | Where-Object { $_.PSChildName -eq "power_v1" }
foreach ($key in $optionKeys) { $regPath = $key.Name; cmd /c "reg add `"$regPath`" /v `"abmlevel`" /t REG_BINARY /d `"00000000`" /f >nul 2>&1" }
cmd /c "reg add `"HKCU\Software\AMD\CN`" /v `"SystemTray`" /t REG_SZ /d `"false`" /f >nul 2>&1"
cmd /c "reg add `"HKCU\Software\AMD\CN`" /v `"CN_Hide_Toast_Notification`" /t REG_SZ /d `"true`" /f >nul 2>&1"
cmd /c "reg add `"HKCU\Software\AMD\CN`" /v `"AnimationEffect`" /t REG_SZ /d `"false`" /f >nul 2>&1"
cmd /c "reg delete `"HKCU\Software\AMD\CN\Notification`" /f >nul 2>&1"
cmd /c "reg add `"HKCU\Software\AMD\CN\Notification`" /f >nul 2>&1"
cmd /c "reg add `"HKCU\Software\AMD\CN\FreeSync`" /v `"AlreadyNotified`" /t REG_DWORD /d `"1`" /f >nul 2>&1"
cmd /c "reg add `"HKCU\Software\AMD\CN\OverlayNotification`" /v `"AlreadyNotified`" /t REG_DWORD /d `"1`" /f >nul 2>&1"
cmd /c "reg add `"HKCU\Software\AMD\CN\VirtualSuperResolution`" /v `"AlreadyNotified`" /t REG_DWORD /d `"1`" /f >nul 2>&1"
Write-Host "AMD driver debloated, installed, and settings imported."
        }},
        @{ Name = 'Intel'; Description = 'Select a downloaded Intel driver, debloat it, install and configure'; Button = 'Install'; Block = {
Write-Host "Intel: Debloating and installing driver..."
# download 7zip
IWR "https://github.com/isleap9/AkariOS-Files/releases/download/Files/7zip.exe" -OutFile "$env:SystemRoot\Temp\7zip.exe"
Start-Process -Wait "$env:SystemRoot\Temp\7zip.exe" -ArgumentList "/S"
cmd /c "reg add `"HKEY_CURRENT_USER\Software\7-Zip\Options`" /v `"ContextMenu`" /t REG_DWORD /d `"259`" /f >nul 2>&1"
cmd /c "reg add `"HKEY_CURRENT_USER\Software\7-Zip\Options`" /v `"CascadedMenu`" /t REG_DWORD /d `"0`" /f >nul 2>&1"
Move-Item -Path "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\7-Zip\7-Zip File Manager.lnk" -Destination "$env:ProgramData\Microsoft\Windows\Start Menu\Programs" -Force -ErrorAction SilentlyContinue | Out-Null
Remove-Item "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\7-Zip" -Recurse -Force -ErrorAction SilentlyContinue | Out-Null
Write-Host "Select downloaded Intel driver..."
$InstallFile = Get-FilePath "Intel Driver (*.exe)|*.exe|All Files (*.*)|*.*"
if (-not $InstallFile) { Write-Log 'Cancelled'; return }
Write-Host "Debloating driver..."
& "$env:SystemDrive\Program Files\7-Zip\7z.exe" x "$InstallFile" -o"$env:SystemDrive\inteldriver" -y | Out-Null
Write-Host "Installing driver..."
Start-Process "cmd.exe" -ArgumentList "/c `"$env:SystemDrive\inteldriver\Installer.exe`" -f --noExtras --terminateProcesses -s" -WindowStyle Hidden -Wait
$IntelGraphicsSoftware = Get-ChildItem "$env:SystemDrive\inteldriver\Resources\Extras\IntelGraphicsSoftware_*.exe" | Select-Object -First 1 -ExpandProperty Name
if ($IntelGraphicsSoftware) { Start-Process "$env:SystemDrive\inteldriver\Resources\Extras\$IntelGraphicsSoftware" -ArgumentList "/s" -Wait -NoNewWindow }
$WshShell = New-Object -comObject WScript.Shell
$Desktop = (New-Object -ComObject Shell.Application).Namespace('shell:Desktop').Self.Path
$Shortcut = $WshShell.CreateShortcut("$Desktop\Intel Graphics Software.lnk")
$Shortcut.TargetPath = "$env:SystemDrive\Program Files\Intel\Intel Graphics Software\IntelGraphicsSoftware.exe"
$Shortcut.WorkingDirectory = "$env:SystemDrive\Program Files\Intel\Intel Graphics Software"
$Shortcut.Save()
$FileName = "Intel$([char]0xAE) Graphics Software"
cmd /c "reg delete `"HKLM\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Run`" /v `"$FileName`" /f >nul 2>&1"
cmd /c "sc stop `"IntelGFXFWupdateTool`" >nul 2>&1"
cmd /c "sc delete `"IntelGFXFWupdateTool`" >nul 2>&1"
cmd /c "sc stop `"cplspcon`" >nul 2>&1"
cmd /c "sc delete `"cplspcon`" >nul 2>&1"
cmd /c "sc stop `"CtaChildDriver`" >nul 2>&1"
cmd /c "sc delete `"CtaChildDriver`" >nul 2>&1"
cmd /c "sc stop `"GSCAuxDriver`" >nul 2>&1"
cmd /c "sc delete `"GSCAuxDriver`" >nul 2>&1"
cmd /c "sc stop `"GSCx64`" >nul 2>&1"
cmd /c "sc delete `"GSCx64`" >nul 2>&1"
$stop = "IntelGraphicsSoftware", "PresentMonService"
$stop | ForEach-Object { Stop-Process -Name $_ -Force -ErrorAction SilentlyContinue }
Start-Sleep -Seconds 2
Remove-Item "$env:SystemDrive\Program Files\Intel\Intel Graphics Software\PresentMonService.exe" -Force -ErrorAction SilentlyContinue | Out-Null
Remove-Item "$InstallFile" -Force -ErrorAction SilentlyContinue | Out-Null
$FileName = "Intel$([char]0xAE) Graphics Software"
Move-Item -Path "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\Intel\Intel Graphics Software\$FileName.lnk" -Destination "$env:ProgramData\Microsoft\Windows\Start Menu\Programs" -Force -ErrorAction SilentlyContinue
Remove-Item "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\Intel" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item "$env:SystemDrive\Intel" -Recurse -Force -ErrorAction SilentlyContinue | Out-Null
Remove-Item "$env:SystemDrive\inteldriver" -Recurse -Force -ErrorAction SilentlyContinue | Out-Null
Write-Host "Importing Intel settings..."
$basePath = "HKLM:\System\ControlSet001\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}"
$adapterKeys = Get-ChildItem -Path $basePath -ErrorAction SilentlyContinue
foreach ($key in $adapterKeys) { if ($key.PSChildName -match '^\d{4}$') { $regPath = $key.Name; cmd /c "reg add `"$regPath\3DKeys`" /f >nul 2>&1" } }
$basePath = "HKLM:\System\ControlSet001\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}"
$allKeys = Get-ChildItem -Path $basePath -Recurse -ErrorAction SilentlyContinue
$optionKeys = $allKeys | Where-Object { $_.PSChildName -eq "3DKeys" }
foreach ($key in $optionKeys) { $regPath = $key.Name; cmd /c "reg add `"$regPath`" /v `"Global_AsyncFlipMode`" /t REG_DWORD /d `"2`" /f >nul 2>&1" }
$basePath = "HKLM:\System\ControlSet001\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}"
$allKeys = Get-ChildItem -Path $basePath -Recurse -ErrorAction SilentlyContinue
$optionKeys = $allKeys | Where-Object { $_.PSChildName -eq "3DKeys" }
foreach ($key in $optionKeys) { $regPath = $key.Name; cmd /c "reg add `"$regPath`" /v `"Global_LowLatency`" /t REG_DWORD /d `"1`" /f >nul 2>&1" }
cmd /c "reg add `"HKEY_CURRENT_USER\Software\Microsoft\DirectX\UserGpuPreferences`" /v `"DirectXUserGlobalSettings`" /t REG_SZ /d `"SwapEffectUpgradeEnable=1;VRROptimizeEnable=0;`" /f >nul 2>&1"
Write-Host "Intel driver debloated, installed, and settings imported."
        }}
    )

Add-Tweak -Id 'nvidia-settings' -Category 'Graphics' -Name 'NVIDIA settings' -Risk Caution `
    -Description 'Apply optimized NVIDIA driver settings' `
    -Apply {
if (-not (Test-Connection -ComputerName '8.8.8.8' -Count 1 -Quiet -ErrorAction SilentlyContinue)) { Write-Log 'Internet connection required'; return }
# download nvidia control panel
IWR "https://github.com/isleap9/AkariOS-Files/releases/download/Files/nvp.appx" -OutFile "$env:SystemRoot\Temp\nvp.appx"

# install nvidia control panel
Add-AppxPackage -Path "$env:SystemRoot\Temp\nvp.appx" -ErrorAction SilentlyContinue | Out-Null

# create desktop shortcut
$WshShell = New-Object -comObject WScript.Shell
$Desktop = (New-Object -ComObject Shell.Application).Namespace('shell:Desktop').Self.Path
$Shortcut = $WshShell.CreateShortcut("$Desktop\NVIDIA Control Panel.lnk")
$Shortcut.TargetPath = "shell:appsFolder\NVIDIACorp.NVIDIAControlPanel_56jybvy8sckqj!NVIDIACorp.NVIDIAControlPanel"
$Shortcut.WorkingDirectory = "shell:appsFolder"
$Shortcut.Save()
# unblock drs files
$path = "C:\ProgramData\NVIDIA Corporation\Drs"
Get-ChildItem -Path $path -Recurse | Unblock-File

# set physx to gpu
cmd /c "reg add `"HKLM\System\ControlSet001\Services\nvlddmkm\Parameters\Global\NVTweak`" /v `"NvCplPhysxAuto`" /t REG_DWORD /d `"0`" /f >nul 2>&1"

# enable developer settings
cmd /c "reg add `"HKLM\System\ControlSet001\Services\nvlddmkm\Parameters\Global\NVTweak`" /v `"NvDevToolsVisible`" /t REG_DWORD /d `"1`" /f >nul 2>&1"

# allow access to the gpu performance counters to all users
$subkeys = Get-ChildItem -Path "Registry::HKLM\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}" -Force -ErrorAction SilentlyContinue
foreach($key in $subkeys){
if ($key -notlike '*Configuration'){
reg add "$key" /v "RmProfilingAdminOnly" /t REG_DWORD /d "0" /f | Out-Null
}
}
cmd /c "reg add `"HKLM\System\ControlSet001\Services\nvlddmkm\Parameters\Global\NVTweak`" /v `"RmProfilingAdminOnly`" /t REG_DWORD /d `"0`" /f >nul 2>&1"

# disable show notification tray icon
cmd /c "reg add `"HKCU\Software\NVIDIA Corporation\NvTray`" /v `"StartOnLogin`" /t REG_DWORD /d `"0`" /f >nul 2>&1"

# enable nvidia legacy sharpen
cmd /c "reg add `"HKLM\SYSTEM\CurrentControlSet\Services\nvlddmkm\FTS`" /v `"EnableGR535`" /t REG_DWORD /d `"0`" /f >nul 2>&1"
cmd /c "reg add `"HKLM\SYSTEM\ControlSet001\Services\nvlddmkm\Parameters\FTS`" /v `"EnableGR535`" /t REG_DWORD /d `"0`" /f >nul 2>&1"
cmd /c "reg add `"HKLM\SYSTEM\CurrentControlSet\Services\nvlddmkm\Parameters\FTS`" /v `"EnableGR535`" /t REG_DWORD /d `"0`" /f >nul 2>&1"

# new folder
New-Item -Path "$env:SystemDrive\Program Files (x86)\Nvidia Profile Inspector" -ItemType Directory -Force -ErrorAction SilentlyContinue | Out-Null

# download nvidia profile inspector
IWR "https://github.com/isleap9/AkariOS-Files/releases/download/Files/inspector.exe" -OutFile "$env:SystemDrive\Program Files (x86)\Nvidia Profile Inspector\Nvidia Profile Inspector.exe"

# create desktop shortcut
$WshShell = New-Object -comObject WScript.Shell
$Desktop = (New-Object -ComObject Shell.Application).Namespace('shell:Desktop').Self.Path
$Shortcut = $WshShell.CreateShortcut("$Desktop\Nvidia Profile Inspector.lnk")
$Shortcut.TargetPath = "$env:SystemDrive\Program Files (x86)\Nvidia Profile Inspector\Nvidia Profile Inspector.exe"
$Shortcut.WorkingDirectory = "$env:SystemDrive\Program Files (x86)\Nvidia Profile Inspector"
$Shortcut.Save()

# create start menu shortcut
$WshShell = New-Object -comObject WScript.Shell
$Shortcut = $WshShell.CreateShortcut("$env:ProgramData\Microsoft\Windows\Start Menu\Programs\Nvidia Profile Inspector.lnk")
$Shortcut.TargetPath = "$env:SystemDrive\Program Files (x86)\Nvidia Profile Inspector\Nvidia Profile Inspector.exe"
$Shortcut.WorkingDirectory = "$env:SystemDrive\Program Files (x86)\Nvidia Profile Inspector"
$Shortcut.Save()

# set config for inspector
$nipfile = @'
<?xml version="1.0" encoding="utf-16"?>
<ArrayOfProfile>
  <Profile>
    <ProfileName>Base Profile</ProfileName>
    <Executables/>
    <Settings>
      <ProfileSetting>
        <SettingNameInfo>Frame Rate Limiter V3</SettingNameInfo>
        <SettingID>277041154</SettingID>
        <SettingValue>0</SettingValue>
        <ValueType>Dword</ValueType>
      </ProfileSetting>
      <ProfileSetting>
        <SettingNameInfo>GSYNC - Application Mode</SettingNameInfo>
        <SettingID>294973784</SettingID>
        <SettingValue>0</SettingValue>
        <ValueType>Dword</ValueType>
      </ProfileSetting>
      <ProfileSetting>
        <SettingNameInfo>GSYNC - Application State</SettingNameInfo>
        <SettingID>279476687</SettingID>
        <SettingValue>4</SettingValue>
        <ValueType>Dword</ValueType>
      </ProfileSetting>
      <ProfileSetting>
        <SettingNameInfo>GSYNC - Global Feature</SettingNameInfo>
        <SettingID>278196567</SettingID>
        <SettingValue>0</SettingValue>
        <ValueType>Dword</ValueType>
      </ProfileSetting>
      <ProfileSetting>
        <SettingNameInfo>GSYNC - Global Mode</SettingNameInfo>
        <SettingID>278196727</SettingID>
        <SettingValue>0</SettingValue>
        <ValueType>Dword</ValueType>
      </ProfileSetting>
      <ProfileSetting>
        <SettingNameInfo>GSYNC - Indicator Overlay</SettingNameInfo>
        <SettingID>268604728</SettingID>
        <SettingValue>0</SettingValue>
        <ValueType>Dword</ValueType>
      </ProfileSetting>
      <ProfileSetting>
        <SettingNameInfo>Maximum Pre-Rendered Frames</SettingNameInfo>
        <SettingID>8102046</SettingID>
        <SettingValue>1</SettingValue>
        <ValueType>Dword</ValueType>
      </ProfileSetting>
      <ProfileSetting>
        <SettingNameInfo>Preferred Refresh Rate</SettingNameInfo>
        <SettingID>6600001</SettingID>
        <SettingValue>1</SettingValue>
        <ValueType>Dword</ValueType>
      </ProfileSetting>
      <ProfileSetting>
        <SettingNameInfo>Ultra Low Latency - CPL State</SettingNameInfo>
        <SettingID>390467</SettingID>
        <SettingValue>2</SettingValue>
        <ValueType>Dword</ValueType>
      </ProfileSetting>
      <ProfileSetting>
        <SettingNameInfo>Ultra Low Latency - Enabled</SettingNameInfo>
        <SettingID>277041152</SettingID>
        <SettingValue>1</SettingValue>
        <ValueType>Dword</ValueType>
      </ProfileSetting>
      <ProfileSetting>
        <SettingNameInfo>Vertical Sync</SettingNameInfo>
        <SettingID>11041231</SettingID>
        <SettingValue>138504007</SettingValue>
        <ValueType>Dword</ValueType>
      </ProfileSetting>
      <ProfileSetting>
        <SettingNameInfo>Vertical Sync - Smooth AFR Behavior</SettingNameInfo>
        <SettingID>270198627</SettingID>
        <SettingValue>0</SettingValue>
        <ValueType>Dword</ValueType>
      </ProfileSetting>
      <ProfileSetting>
        <SettingNameInfo>Vertical Sync - Tear Control</SettingNameInfo>
        <SettingID>5912412</SettingID>
        <SettingValue>2525368439</SettingValue>
        <ValueType>Dword</ValueType>
      </ProfileSetting>
      <ProfileSetting>
        <SettingNameInfo>Vulkan/OpenGL Present Method</SettingNameInfo>
        <SettingID>550932728</SettingID>
        <SettingValue>0</SettingValue>
        <ValueType>Dword</ValueType>
      </ProfileSetting>
      <ProfileSetting>
        <SettingNameInfo>Antialiasing - Gamma Correction</SettingNameInfo>
        <SettingID>276652957</SettingID>
        <SettingValue>0</SettingValue>
        <ValueType>Dword</ValueType>
      </ProfileSetting>
      <ProfileSetting>
        <SettingNameInfo>Antialiasing - Mode</SettingNameInfo>
        <SettingID>276757595</SettingID>
        <SettingValue>1</SettingValue>
        <ValueType>Dword</ValueType>
      </ProfileSetting>
      <ProfileSetting>
        <SettingNameInfo>Antialiasing - Setting</SettingNameInfo>
        <SettingID>282555346</SettingID>
        <SettingValue>0</SettingValue>
        <ValueType>Dword</ValueType>
      </ProfileSetting>
      <ProfileSetting>
        <SettingNameInfo>Anisotropic Filter - Optimization</SettingNameInfo>
        <SettingID>8703344</SettingID>
        <SettingValue>1</SettingValue>
        <ValueType>Dword</ValueType>
      </ProfileSetting>
      <ProfileSetting>
        <SettingNameInfo>Anisotropic Filter - Sample Optimization</SettingNameInfo>
        <SettingID>15151633</SettingID>
        <SettingValue>1</SettingValue>
        <ValueType>Dword</ValueType>
      </ProfileSetting>
      <ProfileSetting>
        <SettingNameInfo>Anisotropic Filtering - Mode</SettingNameInfo>
        <SettingID>282245910</SettingID>
        <SettingValue>1</SettingValue>
        <ValueType>Dword</ValueType>
      </ProfileSetting>
      <ProfileSetting>
        <SettingNameInfo>Anisotropic Filtering - Setting</SettingNameInfo>
        <SettingID>270426537</SettingID>
        <SettingValue>1</SettingValue>
        <ValueType>Dword</ValueType>
      </ProfileSetting>
      <ProfileSetting>
        <SettingNameInfo>Texture Filtering - Negative LOD Bias</SettingNameInfo>
        <SettingID>1686376</SettingID>
        <SettingValue>0</SettingValue>
        <ValueType>Dword</ValueType>
      </ProfileSetting>
      <ProfileSetting>
        <SettingNameInfo>Texture Filtering - Quality</SettingNameInfo>
        <SettingID>13510289</SettingID>
        <SettingValue>20</SettingValue>
        <ValueType>Dword</ValueType>
      </ProfileSetting>
      <ProfileSetting>
        <SettingNameInfo>Texture Filtering - Trilinear Optimization</SettingNameInfo>
        <SettingID>3066610</SettingID>
        <SettingValue>0</SettingValue>
        <ValueType>Dword</ValueType>
      </ProfileSetting>
      <ProfileSetting>
        <SettingNameInfo>CUDA - Force P2 State</SettingNameInfo>
        <SettingID>1343646814</SettingID>
        <SettingValue>0</SettingValue>
        <ValueType>Dword</ValueType>
      </ProfileSetting>
	  <ProfileSetting>
        <SettingNameInfo>CUDA - Sysmem Fallback Policy</SettingNameInfo>
        <SettingID>283962569</SettingID>
        <SettingValue>1</SettingValue>
        <ValueType>Dword</ValueType>
      </ProfileSetting>
      <ProfileSetting>
        <SettingNameInfo>Power Management - Mode</SettingNameInfo>
        <SettingID>274197361</SettingID>
        <SettingValue>1</SettingValue>
        <ValueType>Dword</ValueType>
      </ProfileSetting>
      <ProfileSetting>
        <SettingNameInfo>Shader Cache - Cache Size</SettingNameInfo>
        <SettingID>11306135</SettingID>
        <SettingValue>4294967295</SettingValue>
        <ValueType>Dword</ValueType>
      </ProfileSetting>
      <ProfileSetting>
        <SettingNameInfo>Threaded Optimization</SettingNameInfo>
        <SettingID>549528094</SettingID>
        <SettingValue>1</SettingValue>
        <ValueType>Dword</ValueType>
      </ProfileSetting>
      <ProfileSetting>
        <SettingNameInfo>OpenGL GDI Compatibility</SettingNameInfo>
        <SettingID>544392611</SettingID>
        <SettingValue>0</SettingValue>
        <ValueType>Dword</ValueType>
      </ProfileSetting>
      <ProfileSetting>
        <SettingNameInfo>Preferred OpenGL GPU</SettingNameInfo>
        <SettingID>550564838</SettingID>
        <SettingValue>id,2.0:268410DE,00000100,GF - (400,2,161,24564) @ (0)</SettingValue>
        <ValueType>String</ValueType>
      </ProfileSetting>
    </Settings>
  </Profile>
</ArrayOfProfile>
'@
Set-Content -Path "$env:SystemRoot\Temp\inspector.nip" -Value $nipfile -Force

# import nip
Start-Process -Wait "$env:SystemDrive\Program Files (x86)\Nvidia Profile Inspector\Nvidia Profile Inspector.exe" -ArgumentList "-silentImport -silent $env:SystemRoot\Temp\inspector.nip"

# open nvidiacontrolpanel
Start-Process "shell:appsFolder\NVIDIACorp.NVIDIAControlPanel_56jybvy8sckqj!NVIDIACorp.NVIDIAControlPanel"
    } `
    -Revert {
if (-not (Test-Connection -ComputerName '8.8.8.8' -Count 1 -Quiet -ErrorAction SilentlyContinue)) { Write-Log 'Internet connection required'; return }
# download nvidia control panel
IWR "https://github.com/isleap9/AkariOS-Files/releases/download/Files/nvp.appx" -OutFile "$env:SystemRoot\Temp\nvp.appx"

# install nvidia control panel
Add-AppxPackage -Path "$env:SystemRoot\Temp\nvp.appx" -ErrorAction SilentlyContinue | Out-Null

# create desktop shortcut
$WshShell = New-Object -comObject WScript.Shell
$Desktop = (New-Object -ComObject Shell.Application).Namespace('shell:Desktop').Self.Path
$Shortcut = $WshShell.CreateShortcut("$Desktop\NVIDIA Control Panel.lnk")
$Shortcut.TargetPath = "shell:appsFolder\NVIDIACorp.NVIDIAControlPanel_56jybvy8sckqj!NVIDIACorp.NVIDIAControlPanel"
$Shortcut.WorkingDirectory = "shell:appsFolder"
$Shortcut.Save()
# unblock drs files
$path = "C:\ProgramData\NVIDIA Corporation\Drs"
Get-ChildItem -Path $path -Recurse | Unblock-File

# revert set physx to gpu
cmd /c "reg delete `"HKLM\System\ControlSet001\Services\nvlddmkm\Parameters\Global\NVTweak`" /v `"NvCplPhysxAuto`" /f >nul 2>&1"

# revert enable developer settings
cmd /c "reg delete `"HKLM\System\ControlSet001\Services\nvlddmkm\Parameters\Global\NVTweak`" /v `"NvDevToolsVisible`" /f >nul 2>&1"

# revert allow access to the gpu performance counters to all users
$subkeys = Get-ChildItem -Path "Registry::HKLM\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}" -Force -ErrorAction SilentlyContinue
foreach($key in $subkeys){
if ($key -notlike '*Configuration'){
cmd /c "reg delete `"$key`" /v `"RmProfilingAdminOnly`" /f >nul 2>&1"
}
}
cmd /c "reg delete `"HKLM\System\ControlSet001\Services\nvlddmkm\Parameters\Global\NVTweak`" /v `"RmProfilingAdminOnly`" /f >nul 2>&1"

# revert disable show notification tray icon
cmd /c "reg delete `"HKCU\Software\NVIDIA Corporation\NvTray`" /f >nul 2>&1"

# revert enable nvidia legacy sharpen
cmd /c "reg add `"HKLM\SYSTEM\CurrentControlSet\Services\nvlddmkm\FTS`" /v `"EnableGR535`" /t REG_DWORD /d `"1`" /f >nul 2>&1"
cmd /c "reg add `"HKLM\SYSTEM\ControlSet001\Services\nvlddmkm\Parameters\FTS`" /v `"EnableGR535`" /t REG_DWORD /d `"1`" /f >nul 2>&1"
cmd /c "reg add `"HKLM\SYSTEM\CurrentControlSet\Services\nvlddmkm\Parameters\FTS`" /v `"EnableGR535`" /t REG_DWORD /d `"1`" /f >nul 2>&1"

# new folder
New-Item -Path "$env:SystemDrive\Program Files (x86)\Nvidia Profile Inspector" -ItemType Directory -Force -ErrorAction SilentlyContinue | Out-Null

# download nvidia profile inspector
IWR "https://github.com/isleap9/AkariOS-Files/releases/download/Files/inspector.exe" -OutFile "$env:SystemDrive\Program Files (x86)\Nvidia Profile Inspector\Nvidia Profile Inspector.exe"

# create desktop shortcut
$WshShell = New-Object -comObject WScript.Shell
$Desktop = (New-Object -ComObject Shell.Application).Namespace('shell:Desktop').Self.Path
$Shortcut = $WshShell.CreateShortcut("$Desktop\Nvidia Profile Inspector.lnk")
$Shortcut.TargetPath = "$env:SystemDrive\Program Files (x86)\Nvidia Profile Inspector\Nvidia Profile Inspector.exe"
$Shortcut.WorkingDirectory = "$env:SystemDrive\Program Files (x86)\Nvidia Profile Inspector"
$Shortcut.Save()

# create start menu shortcut
$WshShell = New-Object -comObject WScript.Shell
$Shortcut = $WshShell.CreateShortcut("$env:ProgramData\Microsoft\Windows\Start Menu\Programs\Nvidia Profile Inspector.lnk")
$Shortcut.TargetPath = "$env:SystemDrive\Program Files (x86)\Nvidia Profile Inspector\Nvidia Profile Inspector.exe"
$Shortcut.WorkingDirectory = "$env:SystemDrive\Program Files (x86)\Nvidia Profile Inspector"
$Shortcut.Save()

# set config for inspector
$nipfile = @'
<?xml version="1.0" encoding="utf-16"?>
<ArrayOfProfile>
  <Profile>
    <ProfileName>Base Profile</ProfileName>
    <Executeables/>
    <Settings/>
  </Profile>
</ArrayOfProfile>
'@
Set-Content -Path "$env:SystemRoot\Temp\inspector.nip" -Value $nipfile -Force

# import nip
Start-Process -Wait "$env:SystemDrive\Program Files (x86)\Nvidia Profile Inspector\Nvidia Profile Inspector.exe" -ArgumentList "-silentImport -silent $env:SystemRoot\Temp\inspector.nip"

# open nvidiacontrolpanel
Start-Process "shell:appsFolder\NVIDIACorp.NVIDIAControlPanel_56jybvy8sckqj!NVIDIACorp.NVIDIAControlPanel"
    }

Add-Tweak -Id 'amd-settings' -Category 'Graphics' -Name 'AMD settings' -Risk Caution `
    -Description 'Apply optimized AMD driver settings' `
    -Apply {
# open & close amd software adrenalin edition settings page so settings stick
Start-Process "$env:SystemDrive\Program Files\AMD\CNext\CNext\RadeonSoftware.exe"
Start-Sleep -Seconds 30
Stop-Process -Name "RadeonSoftware" -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 2

# import amd software adrenalin edition settings
# system
# manual check for updates
cmd /c "reg add `"HKCU\Software\AMD\CN`" /v `"AutoUpdate`" /t REG_DWORD /d `"0`" /f >nul 2>&1"

# disable issue detection
cmd /c "reg add `"HKCU\Software\AMD\AIM`" /v `"LaunchBugTool`" /t REG_DWORD /d `"0`" /f >nul 2>&1"

# hotkeys
# disable use hotkeys
cmd /c "reg add `"HKCU\Software\AMD\DVR`" /v `"HotkeysDisabled`" /t REG_DWORD /d `"1`" /f >nul 2>&1"

# preferences
# disable system tray menu
cmd /c "reg add `"HKCU\Software\AMD\CN`" /v `"SystemTray`" /t REG_SZ /d `"false`" /f >nul 2>&1"

# disable in game overlay
cmd /c "reg add `"HKCU\Software\AMD\DVR`" /v `"ShowRSOverlay`" /t REG_SZ /d `"false`" /f >nul 2>&1"

# disable web browser
cmd /c "reg add `"HKCU\Software\AMD\CN`" /v `"RSXBrowserUnavailable`" /t REG_SZ /d `"true`" /f >nul 2>&1"

# disable advertisements
cmd /c "reg add `"HKCU\Software\AMD\CN`" /v `"AllowWebContent`" /t REG_SZ /d `"false`" /f >nul 2>&1"

# disable toast notifications
cmd /c "reg add `"HKCU\Software\AMD\CN`" /v `"CN_Hide_Toast_Notification`" /t REG_SZ /d `"true`" /f >nul 2>&1"

# disable animation & effects
cmd /c "reg add `"HKCU\Software\AMD\CN`" /v `"AnimationEffect`" /t REG_SZ /d `"false`" /f >nul 2>&1"

# graphics
# graphics profile - custom
cmd /c "reg add `"HKCU\Software\AMD\CN`" /v `"WizardProfile`" /t REG_SZ /d `"PROFILE_CUSTOM`" /f >nul 2>&1"

# radeon anti-lag - enabled
$basePath = "HKLM:\System\ControlSet001\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}"
$adapterKeys = Get-ChildItem -Path $basePath -ErrorAction SilentlyContinue
foreach ($key in $adapterKeys) {
if ($key.PSChildName -match '^\d{4}$') {
$regPath = $key.Name
cmd /c "reg add `"$regPath`" /v `"KMD_DeLagEnabled`" /t REG_DWORD /d `"1`" /f >nul 2>&1"
}
}

# wait for vertical refresh - always off
$basePath = "HKLM:\System\ControlSet001\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}"
$allKeys = Get-ChildItem -Path $basePath -Recurse -ErrorAction SilentlyContinue
$optionKeys = $allKeys | Where-Object { $_.PSChildName -eq "UMD" }
foreach ($key in $optionKeys) {
$regPath = $key.Name
cmd /c "reg add `"$regPath`" /v `"VSyncControl`" /t REG_BINARY /d `"3000`" /f >nul 2>&1"
}

# texture filtering quality - performance
$basePath = "HKLM:\System\ControlSet001\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}"
$allKeys = Get-ChildItem -Path $basePath -Recurse -ErrorAction SilentlyContinue
$optionKeys = $allKeys | Where-Object { $_.PSChildName -eq "UMD" }
foreach ($key in $optionKeys) {
$regPath = $key.Name
cmd /c "reg add `"$regPath`" /v `"TFQ`" /t REG_BINARY /d `"3200`" /f >nul 2>&1"
}

# tessellation mode - override application settings
# maximum tessellation level - off
$basePath = "HKLM:\System\ControlSet001\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}"
$allKeys = Get-ChildItem -Path $basePath -Recurse -ErrorAction SilentlyContinue
$optionKeys = $allKeys | Where-Object { $_.PSChildName -eq "UMD" }
foreach ($key in $optionKeys) {
$regPath = $key.Name
cmd /c "reg add `"$regPath`" /v `"Tessellation`" /t REG_BINARY /d `"3100`" /f >nul 2>&1"
cmd /c "reg add `"$regPath`" /v `"Tessellation_OPTION`" /t REG_BINARY /d `"3200`" /f >nul 2>&1"
}

# display
# accept custom resolution eula
cmd /c "reg add `"HKCU\Software\AMD\CN\CustomResolutions`" /v `"EulaAccepted`" /t REG_SZ /d `"true`" /f >nul 2>&1"

# accept overrides eula
cmd /c "reg add `"HKCU\Software\AMD\CN\DisplayOverride`" /v `"EulaAccepted`" /t REG_SZ /d `"true`" /f >nul 2>&1"

# vari-bright - maximize brightness
$basePath = "HKLM:\System\ControlSet001\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}"
$allKeys = Get-ChildItem -Path $basePath -Recurse -ErrorAction SilentlyContinue
$optionKeys = $allKeys | Where-Object { $_.PSChildName -eq "power_v1" }
foreach ($key in $optionKeys) {
$regPath = $key.Name
cmd /c "reg add `"$regPath`" /v `"abmlevel`" /t REG_BINARY /d `"00000000`" /f >nul 2>&1"
}

# performance
# tuning
# manual tuning - custom
$basePath = "HKLM:\System\ControlSet001\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}"
$adapterKeys = Get-ChildItem -Path $basePath -ErrorAction SilentlyContinue
foreach ($key in $adapterKeys) {
if ($key.PSChildName -match '^\d{4}$') {
$regPath = $key.Name
cmd /c "reg add `"$regPath`" /v `"IsAutoDefault`" /t REG_BINARY /d `"00000000`" /f >nul 2>&1"
}
}

# gpu tuning - enabled
# fan tuning - enabled
# vram tuning - enabled
# power tuning - enabled
$basePath = "HKLM:\System\ControlSet001\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}"
$adapterKeys = Get-ChildItem -Path $basePath -ErrorAction SilentlyContinue
foreach ($key in $adapterKeys) {
if ($key.PSChildName -match '^\d{4}$') {
$regPath = $key.Name
cmd /c "reg add `"$regPath`" /v `"IsComponentControl`" /t REG_BINARY /d `"0f000000`" /f >nul 2>&1"
}
}

# notifications - remove
cmd /c "reg delete `"HKCU\Software\AMD\CN\Notification`" /f >nul 2>&1"
cmd /c "reg add `"HKCU\Software\AMD\CN\Notification`" /f >nul 2>&1"
cmd /c "reg add `"HKCU\Software\AMD\CN\FreeSync`" /v `"AlreadyNotified`" /t REG_DWORD /d `"1`" /f >nul 2>&1"
cmd /c "reg add `"HKCU\Software\AMD\CN\OverlayNotification`" /v `"AlreadyNotified`" /t REG_DWORD /d `"1`" /f >nul 2>&1"
cmd /c "reg add `"HKCU\Software\AMD\CN\VirtualSuperResolution`" /v `"AlreadyNotified`" /t REG_DWORD /d `"1`" /f >nul 2>&1"
    } `
    -Revert {
# import amd software adrenalin edition settings
# system
# revert manual check for updates
cmd /c "reg delete `"HKCU\Software\AMD\CN`" /v `"AutoUpdate`" /f >nul 2>&1"

# revert disable issue detection
cmd /c "reg add `"HKCU\Software\AMD\AIM`" /v `"LaunchBugTool`" /t REG_DWORD /d `"1`" /f >nul 2>&1"

# hotkeys
# revert disable use hotkeys
cmd /c "reg delete `"HKCU\Software\AMD\DVR`" /v `"HotkeysDisabled`" /f >nul 2>&1"

# preferences
# revert disable system tray menu
cmd /c "reg delete `"HKCU\Software\AMD\CN`" /v `"SystemTray`" /f >nul 2>&1"

# revert disable in game overlay
cmd /c "reg delete `"HKCU\Software\AMD\DVR`" /v `"ShowRSOverlay`" /f >nul 2>&1"

# revert disable web browser
cmd /c "reg delete `"HKCU\Software\AMD\CN`" /v `"RSXBrowserUnavailable`" /f >nul 2>&1"

# revert disable advertisements
cmd /c "reg delete `"HKCU\Software\AMD\CN`" /v `"AllowWebContent`" /f >nul 2>&1"

# revert disable toast notifications
cmd /c "reg delete `"HKCU\Software\AMD\CN`" /v `"CN_Hide_Toast_Notification`" /f >nul 2>&1"

# revert disable animation & effects
cmd /c "reg delete `"HKCU\Software\AMD\CN`" /v `"AnimationEffect`" /f >nul 2>&1"

# graphics
# revert graphics profile - custom
cmd /c "reg delete `"HKCU\Software\AMD\CN`" /v `"WizardProfile`" /f >nul 2>&1"

# revert radeon anti-lag - enabled
$basePath = "HKLM:\System\ControlSet001\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}"
$adapterKeys = Get-ChildItem -Path $basePath -ErrorAction SilentlyContinue
foreach ($key in $adapterKeys) {
if ($key.PSChildName -match '^\d{4}$') {
$regPath = $key.Name
cmd /c "reg add `"$regPath`" /v `"KMD_DeLagEnabled`" /t REG_DWORD /d `"0`" /f >nul 2>&1"
}
}

# revert wait for vertical refresh - always off
$basePath = "HKLM:\System\ControlSet001\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}"
$allKeys = Get-ChildItem -Path $basePath -Recurse -ErrorAction SilentlyContinue
$optionKeys = $allKeys | Where-Object { $_.PSChildName -eq "UMD" }
foreach ($key in $optionKeys) {
$regPath = $key.Name
cmd /c "reg add `"$regPath`" /v `"VSyncControl`" /t REG_BINARY /d `"31000000`" /f >nul 2>&1"
}

# revert texture filtering quality - performance
$basePath = "HKLM:\System\ControlSet001\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}"
$allKeys = Get-ChildItem -Path $basePath -Recurse -ErrorAction SilentlyContinue
$optionKeys = $allKeys | Where-Object { $_.PSChildName -eq "UMD" }
foreach ($key in $optionKeys) {
$regPath = $key.Name
cmd /c "reg delete `"$regPath`" /v `"TFQ`" /f >nul 2>&1"
}

# revert tessellation mode - override application settings
# revert maximum tessellation level - off
$basePath = "HKLM:\System\ControlSet001\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}"
$allKeys = Get-ChildItem -Path $basePath -Recurse -ErrorAction SilentlyContinue
$optionKeys = $allKeys | Where-Object { $_.PSChildName -eq "UMD" }
foreach ($key in $optionKeys) {
$regPath = $key.Name
cmd /c "reg add `"$regPath`" /v `"Tessellation`" /t REG_BINARY /d `"360034000000`" /f >nul 2>&1"
cmd /c "reg add `"$regPath`" /v `"Tessellation_OPTION`" /t REG_BINARY /d `"30000000`" /f >nul 2>&1"
}

# display
# revert accept custom resolution eula
cmd /c "reg delete `"HKCU\Software\AMD\CN\CustomResolutions`" /f >nul 2>&1"

# revert accept overrides eula
cmd /c "reg delete `"HKCU\Software\AMD\CN\DisplayOverride`" /f >nul 2>&1"

# revert vari-bright - maximize brightness
$basePath = "HKLM:\System\ControlSet001\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}"
$allKeys = Get-ChildItem -Path $basePath -Recurse -ErrorAction SilentlyContinue
$optionKeys = $allKeys | Where-Object { $_.PSChildName -eq "power_v1" }
foreach ($key in $optionKeys) {
$regPath = $key.Name
cmd /c "reg delete `"$regPath`" /v `"abmlevel`" /f >nul 2>&1"
}

# performance
# tuning
# revert manual tuning - custom
$basePath = "HKLM:\System\ControlSet001\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}"
$adapterKeys = Get-ChildItem -Path $basePath -ErrorAction SilentlyContinue
foreach ($key in $adapterKeys) {
if ($key.PSChildName -match '^\d{4}$') {
$regPath = $key.Name
cmd /c "reg add `"$regPath`" /v `"IsAutoDefault`" /t REG_DWORD /d `"1`" /f >nul 2>&1"
}
}

# revert gpu tuning - enabled
# revert fan tuning - enabled
# revert vram tuning - enabled
# revert power tuning - enabled
$basePath = "HKLM:\System\ControlSet001\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}"
$adapterKeys = Get-ChildItem -Path $basePath -ErrorAction SilentlyContinue
foreach ($key in $adapterKeys) {
if ($key.PSChildName -match '^\d{4}$') {
$regPath = $key.Name
cmd /c "reg add `"$regPath`" /v `"IsComponentControl`" /t REG_BINARY /d `"00000000`" /f >nul 2>&1"
}
}

# revert notifications - remove
cmd /c "reg delete `"HKCU\Software\AMD\CN\Notification`" /f >nul 2>&1"
cmd /c "reg delete `"HKCU\Software\AMD\CN\FreeSync`" /f >nul 2>&1"
cmd /c "reg delete `"HKCU\Software\AMD\CN\OverlayNotification`" /f >nul 2>&1"
cmd /c "reg delete `"HKCU\Software\AMD\CN\VirtualSuperResolution`" /f >nul 2>&1"
    }

Add-Tweak -Id 'intel-settings' -Category 'Graphics' -Name 'Intel settings' -Risk Caution `
    -Description 'Apply optimized Intel graphics settings' `
    -Apply {
# create 3dkeys key
$basePath = "HKLM:\System\ControlSet001\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}"
$adapterKeys = Get-ChildItem -Path $basePath -ErrorAction SilentlyContinue
foreach ($key in $adapterKeys) {
if ($key.PSChildName -match '^\d{4}$') {
$regPath = $key.Name
cmd /c "reg add `"$regPath\3DKeys`" /f >nul 2>&1"
}
}

# graphics
# frame synchronization - vsync off
$basePath = "HKLM:\System\ControlSet001\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}"
$allKeys = Get-ChildItem -Path $basePath -Recurse -ErrorAction SilentlyContinue
$optionKeys = $allKeys | Where-Object { $_.PSChildName -eq "3DKeys" }
foreach ($key in $optionKeys) {
$regPath = $key.Name
cmd /c "reg add `"$regPath`" /v `"Global_AsyncFlipMode`" /t REG_DWORD /d `"2`" /f >nul 2>&1"
}

# low latency mode - on
$basePath = "HKLM:\System\ControlSet001\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}"
$allKeys = Get-ChildItem -Path $basePath -Recurse -ErrorAction SilentlyContinue
$optionKeys = $allKeys | Where-Object { $_.PSChildName -eq "3DKeys" }
foreach ($key in $optionKeys) {
$regPath = $key.Name
cmd /c "reg add `"$regPath`" /v `"Global_LowLatency`" /t REG_DWORD /d `"1`" /f >nul 2>&1"
}

# disable global windows variable refresh rate to stop screen flicker/driver conflict
cmd /c "reg add `"HKEY_CURRENT_USER\Software\Microsoft\DirectX\UserGpuPreferences`" /v `"DirectXUserGlobalSettings`" /t REG_SZ /d `"SwapEffectUpgradeEnable=1;VRROptimizeEnable=0;`" /f >nul 2>&1"
    } `
    -Revert {
# delete 3dkeys
$basePath = "HKLM:\System\ControlSet001\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}"
$adapterKeys = Get-ChildItem -Path $basePath -ErrorAction SilentlyContinue
foreach ($key in $adapterKeys) {
if ($key.PSChildName -match '^\d{4}$') {
$regPath = $key.Name
cmd /c "reg delete `"$regPath\3DKeys`" /f >nul 2>&1"
}
}
    }

Add-Tweak -Id 'hdcp' -Category 'Graphics' -Name 'HDCP' -Risk Caution `
    -Description 'Turn NVIDIA HDCP off' `
    -Apply {
        Write-Host "NVIDIA High Bandwidth Digital Content Protection"
Write-Host "HDCP: Off..."

# hdcp off
$subkeys = (Get-ChildItem -Path "Registry::HKLM\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}" -Force -ErrorAction SilentlyContinue).Name
foreach($key in $subkeys){
if ($key -notlike '*Configuration'){
reg add "$key" /v "RMHdcpKeyglobZero" /t REG_DWORD /d "1" /f | Out-Null
}
}
$subkeys = (Get-ChildItem -Path "Registry::HKLM\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}" -Force -ErrorAction SilentlyContinue).Name
foreach($key in $subkeys){
if ($key -notlike '*Configuration'){
Get-ItemProperty -Path "Registry::$key" -Name 'RMHdcpKeyglobZero'
}
}

Pause
    } `
    -Revert {
        Write-Host "NVIDIA High Bandwidth Digital Content Protection"
Write-Host "HDCP: Default..."

# hdcp on
$subkeys = (Get-ChildItem -Path "Registry::HKLM\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}" -Force -ErrorAction SilentlyContinue).Name
foreach($key in $subkeys){
if ($key -notlike '*Configuration'){
reg add "$key" /v "RMHdcpKeyglobZero" /t REG_DWORD /d "0" /f | Out-Null
}
}
$subkeys = (Get-ChildItem -Path "Registry::HKLM\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}" -Force -ErrorAction SilentlyContinue).Name
foreach($key in $subkeys){
if ($key -notlike '*Configuration'){
Get-ItemProperty -Path "Registry::$key" -Name 'RMHdcpKeyglobZero'
}
}

Pause
    }

Add-Tweak -Id 'p0-state' -Category 'Graphics' -Name 'P0 state' -Risk Caution `
    -Description 'Keep the NVIDIA GPU at its highest performance power state' `
    -Apply {
        Write-Host "NVIDIA Highest Performance Power State"
		Write-Host "Always Force Max Boost Clock`n"
Write-Host "P0 State: On..."

# get gpu driver id
$subkeys = (Get-ChildItem -Path "Registry::HKLM\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}" -Force -ErrorAction SilentlyContinue).Name
foreach($key in $subkeys){
if ($key -notlike '*Configuration'){

# enable p0 state regedit
reg add "$key" /v "DisableDynamicPstate" /t REG_DWORD /d "1" /f | Out-Null
}
}

$subkeys = (Get-ChildItem -Path "Registry::HKLM\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}" -Force -ErrorAction SilentlyContinue).Name
foreach($key in $subkeys){
if ($key -notlike '*Configuration'){

# show regedit value
Get-ItemProperty -Path "Registry::$key" -Name 'DisableDynamicPstate'
}
}

Pause
    } `
    -Revert {
        Write-Host "NVIDIA Highest Performance Power State"
		Write-Host "Always Force Max Boost Clock`n"
Write-Host "P0 State: Default.."

# get gpu driver id
$subkeys = (Get-ChildItem -Path "Registry::HKLM\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}" -Force -ErrorAction SilentlyContinue).Name
foreach($key in $subkeys){
if ($key -notlike '*Configuration'){

# disable p0 state regedit
reg add "$key" /v "DisableDynamicPstate" /t REG_DWORD /d "0" /f | Out-Null
}
}

$subkeys = (Get-ChildItem -Path "Registry::HKLM\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}" -Force -ErrorAction SilentlyContinue).Name
foreach($key in $subkeys){
if ($key -notlike '*Configuration'){

# show regedit value
Get-ItemProperty -Path "Registry::$key" -Name 'DisableDynamicPstate'
}
}

Pause
    }

Add-Tweak -Id 'msi-mode' -Category 'Graphics' -Name 'MSI mode' -Risk Caution `
    -Description 'Turn MSI mode on for the GPU (Default turns it off)' `
    -Apply {
# get all gpu driver ids
$gpuDevices = Get-PnpDevice -Class Display
foreach ($gpu in $gpuDevices) {
$instanceID = $gpu.InstanceId

# enable msi mode for all gpus regedit
reg add "HKLM\SYSTEM\ControlSet001\Enum\$instanceID\Device Parameters\Interrupt Management\MessageSignaledInterruptProperties" /v "MSISupported" /t REG_DWORD /d "1" /f | Out-Null
}

# display msi mode for all gpus
foreach ($gpu in $gpuDevices) {
$instanceID = $gpu.InstanceId
$regPath = "Registry::HKLM\SYSTEM\ControlSet001\Enum\$instanceID\Device Parameters\Interrupt Management\MessageSignaledInterruptProperties"
try {
$msiSupported = Get-ItemProperty -Path $regPath -Name "MSISupported" -ErrorAction Stop
Write-Output "$instanceID"
Write-Output "MSISupported: $($msiSupported.MSISupported)"
} catch {
Write-Output "$instanceID"
Write-Output "MSISupported: Not found or error accessing the registry."
}
}

Write-Host ""

Pause
    } `
    -Revert {
# get all gpu driver ids
$gpuDevices = Get-PnpDevice -Class Display
foreach ($gpu in $gpuDevices) {
$instanceID = $gpu.InstanceId

# disable msi mode for all gpus regedit
reg add "HKLM\SYSTEM\ControlSet001\Enum\$instanceID\Device Parameters\Interrupt Management\MessageSignaledInterruptProperties" /v "MSISupported" /t REG_DWORD /d "0" /f | Out-Null
}

# display msi mode for all gpus
foreach ($gpu in $gpuDevices) {
$instanceID = $gpu.InstanceId
$regPath = "Registry::HKLM\SYSTEM\ControlSet001\Enum\$instanceID\Device Parameters\Interrupt Management\MessageSignaledInterruptProperties"
try {
$msiSupported = Get-ItemProperty -Path $regPath -Name "MSISupported" -ErrorAction Stop
Write-Output "$instanceID"
Write-Output "MSISupported: $($msiSupported.MSISupported)"
} catch {
Write-Output "$instanceID"
Write-Output "MSISupported: Not found or error accessing the registry."
}
}

Write-Host ""

Pause
    }

Add-Tweak -Id 'directx' -Category 'Graphics' -Kind Action -Button 'Install' -Name 'DirectX' -Risk Safe `
    -Description 'Download and install DirectX' `
    -Apply {
if (-not (Test-Connection -ComputerName '8.8.8.8' -Count 1 -Quiet -ErrorAction SilentlyContinue)) { Write-Log 'Internet connection required'; return }
Write-Host "Downloading: DirectX..."

# download 7zip
IWR "https://github.com/isleap9/AkariOS-Files/releases/download/Files/7zip.exe" -OutFile "$env:SystemRoot\Temp\7zip.exe"

# install 7zip
Start-Process -Wait "$env:SystemRoot\Temp\7zip.exe" -ArgumentList "/S"

# set config for 7zip
cmd /c "reg add `"HKEY_CURRENT_USER\Software\7-Zip\Options`" /v `"ContextMenu`" /t REG_DWORD /d `"259`" /f >nul 2>&1"
cmd /c "reg add `"HKEY_CURRENT_USER\Software\7-Zip\Options`" /v `"CascadedMenu`" /t REG_DWORD /d `"0`" /f >nul 2>&1"

# cleaner start menu shortcut path
Move-Item -Path "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\7-Zip\7-Zip File Manager.lnk" -Destination "$env:ProgramData\Microsoft\Windows\Start Menu\Programs" -Force -ErrorAction SilentlyContinue | Out-Null
Remove-Item "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\7-Zip" -Recurse -Force -ErrorAction SilentlyContinue | Out-Null

# download directx
IWR "https://github.com/isleap9/AkariOS-Files/releases/download/Files/directx.exe" -OutFile "$env:SystemRoot\Temp\directx.exe"

# extract directx with 7zip
& "$env:SystemDrive\Program Files\7-Zip\7z.exe" x "$env:SystemRoot\Temp\directx.exe" -o"$env:SystemRoot\Temp\directx" -y | Out-Null

Write-Host "Installing: DirectX..."

# install directx
Start-Process -Wait "$env:SystemRoot\Temp\directx\DXSETUP.exe" -ArgumentList "/silent" -WindowStyle Hidden
    }

Add-Tweak -Id 'cpp' -Category 'Graphics' -Kind Action -Button 'Install' -Name 'C++ redistributables' -Risk Safe `
    -Description 'Download and install all C++ redistributables' `
    -Apply {
if (-not (Test-Connection -ComputerName '8.8.8.8' -Count 1 -Quiet -ErrorAction SilentlyContinue)) { Write-Log 'Internet connection required'; return }
Write-Host "Downloading: C++..."

# download c++
IWR "https://github.com/isleap9/AkariOS-Files/releases/download/Files/vcredist2005_x86.exe" -OutFile "$env:SystemRoot\Temp\vcredist2005_x86.exe"
IWR "https://github.com/isleap9/AkariOS-Files/releases/download/Files/vcredist2005_x64.exe" -OutFile "$env:SystemRoot\Temp\vcredist2005_x64.exe"
IWR "https://github.com/isleap9/AkariOS-Files/releases/download/Files/vcredist2008_x86.exe" -OutFile "$env:SystemRoot\Temp\vcredist2008_x86.exe"
IWR "https://github.com/isleap9/AkariOS-Files/releases/download/Files/vcredist2008_x64.exe" -OutFile "$env:SystemRoot\Temp\vcredist2008_x64.exe"
IWR "https://github.com/isleap9/AkariOS-Files/releases/download/Files/vcredist2010_x86.exe" -OutFile "$env:SystemRoot\Temp\vcredist2010_x86.exe"
IWR "https://github.com/isleap9/AkariOS-Files/releases/download/Files/vcredist2010_x64.exe" -OutFile "$env:SystemRoot\Temp\vcredist2010_x64.exe"
IWR "https://github.com/isleap9/AkariOS-Files/releases/download/Files/vcredist2012_x86.exe" -OutFile "$env:SystemRoot\Temp\vcredist2012_x86.exe"
IWR "https://github.com/isleap9/AkariOS-Files/releases/download/Files/vcredist2012_x64.exe" -OutFile "$env:SystemRoot\Temp\vcredist2012_x64.exe"
IWR "https://github.com/isleap9/AkariOS-Files/releases/download/Files/vcredist2013_x86.exe" -OutFile "$env:SystemRoot\Temp\vcredist2013_x86.exe"
IWR "https://github.com/isleap9/AkariOS-Files/releases/download/Files/vcredist2013_x64.exe" -OutFile "$env:SystemRoot\Temp\vcredist2013_x64.exe"
IWR "https://github.com/isleap9/AkariOS-Files/releases/download/Files/vcredist2015_2017_2019_2022_x86.exe" -OutFile "$env:SystemRoot\Temp\vcredist2015_2017_2019_2022_x86.exe"
IWR "https://github.com/isleap9/AkariOS-Files/releases/download/Files/vcredist2015_2017_2019_2022_x64.exe" -OutFile "$env:SystemRoot\Temp\vcredist2015_2017_2019_2022_x64.exe"

Write-Host "Installing: C++..."

# install c++
Start-Process -Wait "$env:SystemRoot\Temp\vcredist2005_x86.exe" -ArgumentList "/Q /C:`"msiexec /i vcredist.msi /qn /norestart`"" -WindowStyle Hidden
Start-Process -Wait "$env:SystemRoot\Temp\vcredist2005_x64.exe" -ArgumentList "/Q /C:`"msiexec /i vcredist.msi /qn /norestart`"" -WindowStyle Hidden
Start-Process -Wait "$env:SystemRoot\Temp\vcredist2008_x86.exe" -ArgumentList "/q" -WindowStyle Hidden
Start-Process -Wait "$env:SystemRoot\Temp\vcredist2008_x64.exe" -ArgumentList "/q" -WindowStyle Hidden
Start-Process -Wait "$env:SystemRoot\Temp\vcredist2010_x86.exe" -ArgumentList "/quiet /norestart" -WindowStyle Hidden
Start-Process -Wait "$env:SystemRoot\Temp\vcredist2010_x64.exe" -ArgumentList "/quiet /norestart" -WindowStyle Hidden
Start-Process -Wait "$env:SystemRoot\Temp\vcredist2012_x86.exe" -ArgumentList "/quiet /norestart" -WindowStyle Hidden
Start-Process -Wait "$env:SystemRoot\Temp\vcredist2012_x64.exe" -ArgumentList "/quiet /norestart" -WindowStyle Hidden
Start-Process -Wait "$env:SystemRoot\Temp\vcredist2013_x86.exe" -ArgumentList "/quiet /norestart" -WindowStyle Hidden
Start-Process -Wait "$env:SystemRoot\Temp\vcredist2013_x64.exe" -ArgumentList "/quiet /norestart" -WindowStyle Hidden
Start-Process -Wait "$env:SystemRoot\Temp\vcredist2015_2017_2019_2022_x86.exe" -ArgumentList "/quiet /norestart" -WindowStyle Hidden
Start-Process -Wait "$env:SystemRoot\Temp\vcredist2015_2017_2019_2022_x64.exe" -ArgumentList "/quiet /norestart" -WindowStyle Hidden
    }

Add-Tweak -Id 'resolution' -Category 'Graphics' -Kind Action -Button 'Open' -Name 'Resolution and refresh rate' -Risk Safe `
    -Description 'Open the display settings' `
    -Apply {
Start-Process "ms-settings:display"
    }

Add-Tweak -Id 'hags-windowed' -Category 'Graphics' -Kind Action -Button 'Open' -Name 'HAGS and windowed optimizations' -Risk Safe `
    -Description 'Open the advanced graphics settings' `
    -Apply {
Start-Process "ms-settings:display-advancedgraphics"
    }
