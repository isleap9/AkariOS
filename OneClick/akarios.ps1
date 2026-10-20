# AkariOS: phase body of the One-click run (OneClick\OneClick.ps1 runs it in Akari's console;
# elevation, window title and console colours are Akari's job).

        # SCRIPT CHECK INTERNET
        if (!(Test-Connection -ComputerName "8.8.8.8" -Count 1 -Quiet -ErrorAction SilentlyContinue)) {
        throw "Internet connection required. Nothing was changed."
        }

        # SCRIPT SILENT
        $progresspreference = 'silentlycontinue'

        Write-Host "DL`n"
		## explorer "https://github.com/isleap9/Akari-OS"

# copy the files phase 3 reads from Temp (they ship next to this script in AkariOS\OneClick)
# remove stale copies first so a failed copy cannot reuse an old file
foreach ($f in "reg.reg","settimerresolutionservice.cs","start2.txt") { Remove-Item "$env:SystemRoot\Temp\$f" -Force -ErrorAction SilentlyContinue }
foreach ($f in "reg.reg","settimerresolutionservice.cs","start2.txt") { Copy-Item "$PSScriptRoot\$f" "$env:SystemRoot\Temp\$f" -Force -ErrorAction SilentlyContinue }

# stop before changing anything if a required file is missing
$missing = "reg.reg","settimerresolutionservice.cs","start2.txt" | Where-Object { -not (Test-Path "$env:SystemRoot\Temp\$_") -or (Get-Item "$env:SystemRoot\Temp\$_").Length -eq 0 }
if ($missing) {
throw "Missing One-click files: $($missing -join ', '). Nothing was changed."
}

# copy wallpaper, skipped if it fails
try {
New-Item -Path "$env:SystemRoot\Web\AkariOS" -ItemType Directory -Force | Out-Null
Copy-Item "$PSScriptRoot\img.jpg" "$env:SystemRoot\Web\AkariOS\img.jpg" -Force -ErrorAction Stop
} catch { }

        Write-Host "7Z`n"
        ## explorer "https://www.7-zip.org" 

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

        Write-Host "C++`n"
		## explorer "https://learn.microsoft.com/en-us/cpp/windows/latest-supported-vc-redist?view=msvc-170"

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

        Write-Host "DDU`n"
        ## explorer "https://www.wagnardsoft.com/display-driver-uninstaller-ddu"

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

        Write-Host "HELIUM`n"
        ## explorer "https://helium.computer"

# download helium
IWR "https://github.com/isleap9/AkariOS-Files/releases/download/Files/helium.exe" -OutFile "$env:SystemRoot\Temp\helium.exe"

# install helium
Start-Process -Wait "$env:SystemRoot\Temp\helium.exe" -ArgumentList "/S" -WindowStyle Hidden

# add helium policies
cmd /c "reg add `"HKLM\SOFTWARE\Policies\Helium`" /v `"HardwareAccelerationModeEnabled`" /t REG_DWORD /d `"0`" /f >nul 2>&1"
cmd /c "reg add `"HKLM\SOFTWARE\Policies\Helium`" /v `"BackgroundModeEnabled`" /t REG_DWORD /d `"0`" /f >nul 2>&1"
cmd /c "reg add `"HKLM\SOFTWARE\Policies\Helium`" /v `"HighEfficiencyModeEnabled`" /t REG_DWORD /d `"1`" /f >nul 2>&1"

# remove logon helium
$basePath = "HKLM:\Software\Microsoft\Active Setup\Installed Components"
Get-ChildItem $basePath | ForEach-Object {
$val = (Get-ItemProperty $_.PsPath)."(default)"
if ($val -like "*Helium*") {
Remove-Item $_.PsPath -Force -ErrorAction SilentlyContinue
}
}

# remove helium services
$services = Get-Service | Where-Object { $_.Name -match 'Helium' }
foreach ($service in $services) {
cmd /c "sc stop `"$($service.Name)`" >nul 2>&1"
cmd /c "sc delete `"$($service.Name)`" >nul 2>&1"
}

# remove helium scheduled tasks
Get-ScheduledTask | Where-Object { $_.TaskName -like '*Helium*' } | Unregister-ScheduledTask -Confirm:$false -ErrorAction SilentlyContinue

# cleaner start menu shortcut path
Move-Item -Path "$env:AppData\Microsoft\Windows\Start Menu\Programs\Helium.lnk" -Destination "$env:ProgramData\Microsoft\Windows\Start Menu\Programs" -Force -ErrorAction SilentlyContinue | Out-Null

        Write-Host "DIRECTX`n"
        ## explorer "https://www.microsoft.com/en-au/download/details.aspx?id=35"

# download directx
IWR "https://github.com/isleap9/AkariOS-Files/releases/download/Files/directx.exe" -OutFile "$env:SystemRoot\Temp\directx.exe"

# extract directx with 7zip
& "$env:SystemDrive\Program Files\7-Zip\7z.exe" x "$env:SystemRoot\Temp\directx.exe" -o"$env:SystemRoot\Temp\directx" -y | Out-Null

# install directx
Start-Process -Wait "$env:SystemRoot\Temp\directx\DXSETUP.exe" -ArgumentList "/silent" -WindowStyle Hidden

# (the old AkariOS-Ultimate Desktop download is gone: Akari itself has those pages, Optimize > Legacy)

# allow double click powershell scripts
cmd /c "reg add `"HKCR\Applications\powershell.exe\shell\open\command`" /ve /t REG_SZ /d `"C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe -NoLogo -ExecutionPolicy unrestricted -File \`"`"%1\`"`"`" /f >nul 2>&1"
cmd /c "reg add `"HKCU\SOFTWARE\Microsoft\PowerShell\1\ShellIds\Microsoft.PowerShell`" /v `"ExecutionPolicy`" /t REG_SZ /d `"Unrestricted`" /f >nul 2>&1"
cmd /c "reg add `"HKLM\SOFTWARE\Microsoft\PowerShell\1\ShellIds\Microsoft.PowerShell`" /v `"ExecutionPolicy`" /t REG_SZ /d `"Unrestricted`" /f >nul 2>&1"

        Write-Host "REMOVEUWP`n"
        ## ms-settings:appsfeatures
        ## powershell -noexit -command "get-appxpackage | select name | format-table -autosize"

Get-AppXPackage -AllUsers | Where-Object {
# breaks file explorer
$_.Name -notlike '*CBS*' -and
$_.Name -notlike '*Microsoft.AV1VideoExtension*' -and
$_.Name -notlike '*Microsoft.AVCEncoderVideoExtension*' -and
$_.Name -notlike '*Microsoft.HEIFImageExtension*' -and
$_.Name -notlike '*Microsoft.HEVCVideoExtension*' -and
$_.Name -notlike '*Microsoft.MPEG2VideoExtension*' -and
$_.Name -notlike '*Microsoft.Paint*' -and
$_.Name -notlike '*Microsoft.RawImageExtension*' -and
# breaks windows server defender
$_.Name -notlike '*Microsoft.SecHealthUI*' -and
$_.Name -notlike '*Microsoft.VP9VideoExtensions*' -and
$_.Name -notlike '*Microsoft.WebMediaExtensions*' -and
$_.Name -notlike '*Microsoft.WebpImageExtension*' -and
$_.Name -notlike '*Microsoft.Windows.Photos*' -and
# breaks windows server task bar
$_.Name -notlike '*Microsoft.Windows.ShellExperienceHost*' -and
# breaks windows server start menu
$_.Name -notlike '*Microsoft.Windows.StartMenuExperienceHost*' -and
$_.Name -notlike '*Microsoft.WindowsNotepad*' -and
$_.Name -notlike '*Microsoft.WindowsStore*' -and
$_.Name -notlike '*NVIDIACorp.NVIDIAControlPanel*' -and
# breaks windows server immersive control panel
$_.Name -notlike '*windows.immersivecontrolpanel*'
} | Remove-AppxPackage -ErrorAction SilentlyContinue

# allow password sign in
cmd /c "reg add `"HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\PasswordLess\Device`" /v `"DevicePasswordLessBuildVersion`" /t REG_DWORD /d `"0`" /f >nul 2>&1"

# disable open terminal by default
cmd /c "reg add `"HKCU\Console\%%Startup`" /v `"DelegationConsole`" /t REG_SZ /d `"{B23D10C0-E52E-411E-9D5B-C09FDF709C7D}`" /f >nul 2>&1"
cmd /c "reg add `"HKCU\Console\%%Startup`" /v `"DelegationTerminal`" /t REG_SZ /d `"{B23D10C0-E52E-411E-9D5B-C09FDF709C7D}`" /f >nul 2>&1"

# AkariOS: RunOnce (Akari.ps1 -OneClick 2 and 3), Safe Mode on and the restart are done by OneClick\OneClick.ps1
