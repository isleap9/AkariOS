# Installers category. GENERATED from the AkariOS-Ultimate '4 Installers' scripts.

Add-Tweak -Id 'install-7-zip' -Category 'Installers' -Kind Action -Button 'Install' -Name '7-Zip' -Risk Safe `
    -Description 'Download and install 7-Zip' `
    -Apply {
if (-not (Test-Connection -ComputerName '8.8.8.8' -Count 1 -Quiet -ErrorAction SilentlyContinue)) { Write-Log 'Internet connection required'; return }
Write-Host "Installing: 7Zip..."

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

# create desktop shortcut
$WshShell = New-Object -comObject WScript.Shell
$Desktop = (New-Object -ComObject Shell.Application).Namespace('shell:Desktop').Self.Path
$Shortcut = $WshShell.CreateShortcut("$Desktop\7-Zip File Manager.lnk")
$Shortcut.TargetPath = "$env:SystemDrive\Program Files\7-Zip\7zFM.exe"
$Shortcut.WorkingDirectory = "$env:SystemDrive\Program Files\7-Zip"
$Shortcut.Save()

show-menu
    }

Add-Tweak -Id 'install-battle-net' -Category 'Installers' -Kind Action -Button 'Install' -Name 'Battle.net' -Risk Safe `
    -Description 'Download and install Battle.net' `
    -Apply {
if (-not (Test-Connection -ComputerName '8.8.8.8' -Count 1 -Quiet -ErrorAction SilentlyContinue)) { Write-Log 'Internet connection required'; return }
Write-Host "Installing: Battle.net..."
Write-Host "Close launcher when installer is finished"

# download battle.net
IWR "https://github.com/isleap9/AkariOS-Files/releases/download/Files/battlenet.exe" -OutFile "$env:SystemRoot\Temp\battlenet.exe"

# install battle.net
Start-Process -Wait "$env:SystemRoot\Temp\battlenet.exe" -ArgumentList '--lang=enUS --installpath="C:\Program Files (x86)\Battle.net"'

# remove logon battle.net
cmd /c "reg delete `"HKLM\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Run`" /v `"Battle.net`" /f >nul 2>&1"
cmd /c "reg delete `"HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Run`" /v `"Battle.net`" /f >nul 2>&1"

# cleaner start menu shortcut path
Remove-Item "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\Battle.net" -Recurse -Force -ErrorAction SilentlyContinue | Out-Null

# create desktop shortcut
$WshShell = New-Object -comObject WScript.Shell
$Desktop = (New-Object -ComObject Shell.Application).Namespace('shell:Desktop').Self.Path
$Shortcut = $WshShell.CreateShortcut("$Desktop\Battle.net.lnk")
$Shortcut.TargetPath = "$env:SystemDrive\Program Files (x86)\Battle.net\Battle.net Launcher.exe"
$Shortcut.WorkingDirectory = "$env:SystemDrive\Program Files (x86)\Battle.net"
$Shortcut.Save()

# create start menu shortcut
$WshShell = New-Object -comObject WScript.Shell
$Shortcut = $WshShell.CreateShortcut("$env:ProgramData\Microsoft\Windows\Start Menu\Programs\Battle.net.lnk")
$Shortcut.TargetPath = "$env:SystemDrive\Program Files (x86)\Battle.net\Battle.net Launcher.exe"
$Shortcut.WorkingDirectory = "$env:SystemDrive\Program Files (x86)\Battle.net"
$Shortcut.Save()

show-menu
    }

Add-Tweak -Id 'install-brave' -Category 'Installers' -Kind Action -Button 'Install' -Name 'Brave' -Risk Safe `
    -Description 'Download and install Brave' `
    -Apply {
if (-not (Test-Connection -ComputerName '8.8.8.8' -Count 1 -Quiet -ErrorAction SilentlyContinue)) { Write-Log 'Internet connection required'; return }
Write-Host "Installing: Brave..."

# download brave
IWR "https://github.com/isleap9/AkariOS-Files/releases/download/Files/brave.exe" -OutFile "$env:SystemRoot\Temp\brave.exe"

# install brave
Start-Process "$env:SystemRoot\Temp\brave.exe" -ArgumentList "--system-level" -Wait

# install ublock origin
cmd /c "reg add `"HKLM\SOFTWARE\Policies\BraveSoftware\Brave\ExtensionInstallForcelist`" /v `"1`" /t REG_SZ /d `"ddkjiahejlhfcafbddmgiahcphecmpfh;https://clients2.google.com/service/update2/crx`" /f >nul 2>&1"

# add brave policies
cmd /c "reg add `"HKLM\SOFTWARE\Policies\BraveSoftware\Brave`" /v `"HardwareAccelerationModeEnabled`" /t REG_DWORD /d `"0`" /f >nul 2>&1"
cmd /c "reg add `"HKLM\SOFTWARE\Policies\BraveSoftware\Brave`" /v `"BackgroundModeEnabled`" /t REG_DWORD /d `"0`" /f >nul 2>&1"
cmd /c "reg add `"HKLM\SOFTWARE\Policies\BraveSoftware\Brave`" /v `"HighEfficiencyModeEnabled`" /t REG_DWORD /d `"1`" /f >nul 2>&1"

# remove logon brave
$basePath = "HKLM:\Software\Microsoft\Active Setup\Installed Components"
Get-ChildItem $basePath | ForEach-Object {
$val = (Get-ItemProperty $_.PsPath)."(default)"
if ($val -like "*Brave*") {
Remove-Item $_.PsPath -Force -ErrorAction SilentlyContinue
}
}

# remove brave services
$services = Get-Service | Where-Object { $_.Name -match 'Brave' }
foreach ($service in $services) {
cmd /c "sc stop `"$($service.Name)`" >nul 2>&1"
cmd /c "sc delete `"$($service.Name)`" >nul 2>&1"
}

# remove brave scheduled tasks
Get-ScheduledTask | Where-Object { $_.TaskName -like '*Brave*' } | Unregister-ScheduledTask -Confirm:$false -ErrorAction SilentlyContinue

# cleaner start menu shortcut path
Move-Item -Path "$env:AppData\Microsoft\Windows\Start Menu\Programs\Brave.lnk" -Destination "$env:ProgramData\Microsoft\Windows\Start Menu\Programs" -Force -ErrorAction SilentlyContinue | Out-Null

show-menu
    }

Add-Tweak -Id 'install-custom-resolution-utility' -Category 'Installers' -Kind Action -Button 'Install' -Name 'Custom Resolution Utility' -Risk Safe `
    -Description 'Download and install Custom Resolution Utility' `
    -Apply {
if (-not (Test-Connection -ComputerName '8.8.8.8' -Count 1 -Quiet -ErrorAction SilentlyContinue)) { Write-Log 'Internet connection required'; return }
Write-Host "Installing:"
Write-Host "- Custom Resolution Utility..."
Write-Host "- Scaled Resolution Editor..."

# new folder
New-Item -Path "$env:SystemDrive\Program Files (x86)\CRUSRE" -ItemType Directory -Force -ErrorAction SilentlyContinue | Out-Null

# download custom resolution utility
IWR "https://github.com/isleap9/AkariOS-Files/releases/download/Files/cru.exe" -OutFile "$env:SystemDrive\Program Files (x86)\CRUSRE\CRU.exe"

# download scaled resolution editor
IWR "https://github.com/isleap9/AkariOS-Files/releases/download/Files/sre.exe" -OutFile "$env:SystemDrive\Program Files (x86)\CRUSRE\SRE.exe"

# create desktop shortcut
$WshShell = New-Object -comObject WScript.Shell
$Desktop = (New-Object -ComObject Shell.Application).Namespace('shell:Desktop').Self.Path
$Shortcut = $WshShell.CreateShortcut("$Desktop\Custom Resolution Utility.lnk")
$Shortcut.TargetPath = "$env:SystemDrive\Program Files (x86)\CRUSRE\CRU.exe"
$Shortcut.WorkingDirectory = "$env:SystemDrive\Program Files (x86)\CRUSRE"
$Shortcut.Save()

# create start menu shortcut
$WshShell = New-Object -comObject WScript.Shell
$Shortcut = $WshShell.CreateShortcut("$env:ProgramData\Microsoft\Windows\Start Menu\Programs\Custom Resolution Utility.lnk")
$Shortcut.TargetPath = "$env:SystemDrive\Program Files (x86)\CRUSRE\CRU.exe"
$Shortcut.WorkingDirectory = "$env:SystemDrive\Program Files (x86)\CRUSRE"
$Shortcut.Save()

# create desktop shortcut
$WshShell = New-Object -comObject WScript.Shell
$Desktop = (New-Object -ComObject Shell.Application).Namespace('shell:Desktop').Self.Path
$Shortcut = $WshShell.CreateShortcut("$Desktop\Scaled Resolution Editor.lnk")
$Shortcut.TargetPath = "$env:SystemDrive\Program Files (x86)\CRUSRE\SRE.exe"
$Shortcut.WorkingDirectory = "$env:SystemDrive\Program Files (x86)\CRUSRE"
$Shortcut.Save()

# create start menu shortcut
$WshShell = New-Object -comObject WScript.Shell
$Shortcut = $WshShell.CreateShortcut("$env:ProgramData\Microsoft\Windows\Start Menu\Programs\Scaled Resolution Editor.lnk")
$Shortcut.TargetPath = "$env:SystemDrive\Program Files (x86)\CRUSRE\SRE.exe"
$Shortcut.WorkingDirectory = "$env:SystemDrive\Program Files (x86)\CRUSRE"
$Shortcut.Save()

show-menu
    }

Add-Tweak -Id 'install-discord' -Category 'Installers' -Kind Action -Button 'Install' -Name 'Discord' -Risk Safe `
    -Description 'Download and install Discord' `
    -Apply {
if (-not (Test-Connection -ComputerName '8.8.8.8' -Count 1 -Quiet -ErrorAction SilentlyContinue)) { Write-Log 'Internet connection required'; return }
Write-Host "Installing: Discord..."

# set config for discord
New-Item -Path "$env:APPDATA\discord\settings.json" -ItemType File -Force | Out-Null
$DiscordSettings = @'
{
    "SKIP_HOST_UPDATE": true,
    "DEVELOPER_MODE": true,
    "enableHardwareAcceleration": false,
    "MINIMIZE_TO_TRAY": true,
    "OPEN_ON_STARTUP": false,
    "START_MINIMIZED": false,
    "IS_MAXIMIZED": true,
    "IS_MINIMIZED": false,
    "debugLogging": false
}
'@
Set-Content -Path "$env:APPDATA\discord\settings.json" -Value $DiscordSettings -Force | Out-Null

# fix path for space in username
$Global:tempDir = (([System.IO.Path]::GetTempPath())).trimend('\')

# download discord
IWR "https://github.com/isleap9/AkariOS-Files/releases/download/Files/discord.exe" -OutFile "$tempDir\discord.exe"

# install discord
Start-Process "$tempDir\discord.exe"

Start-Sleep -Seconds 10

Get-Process -Name "Update" -ErrorAction SilentlyContinue | Wait-Process -ErrorAction SilentlyContinue

# remove logon discord
cmd /c "reg delete `"HKLM\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Run`" /v `"Discord`" /f >nul 2>&1"
cmd /c "reg delete `"HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Run`" /v `"Discord`" /f >nul 2>&1"

# cleaner start menu shortcut path
Move-Item -Path "$env:AppData\Microsoft\Windows\Start Menu\Programs\Discord.lnk" -Destination "$env:ProgramData\Microsoft\Windows\Start Menu\Programs" -Force -ErrorAction SilentlyContinue | Out-Null
Remove-Item "$env:AppData\Microsoft\Windows\Start Menu\Programs\Discord Inc" -Recurse -Force -ErrorAction SilentlyContinue | Out-Null

show-menu
    }

Add-Tweak -Id 'install-electronic-arts' -Category 'Installers' -Kind Action -Button 'Install' -Name 'Electronic Arts' -Risk Safe `
    -Description 'Download and install Electronic Arts' `
    -Apply {
if (-not (Test-Connection -ComputerName '8.8.8.8' -Count 1 -Quiet -ErrorAction SilentlyContinue)) { Write-Log 'Internet connection required'; return }
Write-Host "Installing: Electronic Arts..."

# download electronic arts
IWR "https://github.com/isleap9/AkariOS-Files/releases/download/Files/ea.exe" -OutFile "$env:SystemRoot\Temp\ea.exe"

# install electronic arts
Start-Process -Wait "$env:SystemRoot\Temp\ea.exe"

# remove logon electronic arts
cmd /c "reg delete `"HKLM\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Run`" /v `"EADM`" /f >nul 2>&1"
cmd /c "reg delete `"HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Run`" /v `"EADM`" /f >nul 2>&1"

# cleaner start menu shortcut path
Move-Item -Path "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\EA\EA.lnk" -Destination "$env:ProgramData\Microsoft\Windows\Start Menu\Programs" -Force -ErrorAction SilentlyContinue | Out-Null
Remove-Item "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\EA" -Recurse -Force -ErrorAction SilentlyContinue | Out-Null

show-menu
    }

Add-Tweak -Id 'install-epic-games' -Category 'Installers' -Kind Action -Button 'Install' -Name 'Epic Games' -Risk Safe `
    -Description 'Download and install Epic Games' `
    -Apply {
if (-not (Test-Connection -ComputerName '8.8.8.8' -Count 1 -Quiet -ErrorAction SilentlyContinue)) { Write-Log 'Internet connection required'; return }
Write-Host "Installing: Epic Games..."

# download epic games
IWR "https://github.com/isleap9/AkariOS-Files/releases/download/Files/epic.msi" -OutFile "$env:SystemRoot\Temp\epic.msi"

# install epic games
Start-Process -Wait "$env:SystemRoot\Temp\epic.msi" -ArgumentList "/quiet"

# remove logon epic games
cmd /c "reg delete `"HKCU\Software\Microsoft\Windows\CurrentVersion\Run`" /v `"EpicGamesLauncher`" /f >nul 2>&1"

show-menu
    }

Add-Tweak -Id 'install-escape-from-tarkov' -Category 'Installers' -Kind Action -Button 'Install' -Name 'Escape From Tarkov' -Risk Safe `
    -Description 'Download and install Escape From Tarkov' `
    -Apply {
if (-not (Test-Connection -ComputerName '8.8.8.8' -Count 1 -Quiet -ErrorAction SilentlyContinue)) { Write-Log 'Internet connection required'; return }
Write-Host "Installing: Escape From Tarkov..."

# download escape from tarkov
IWR "https://github.com/isleap9/AkariOS-Files/releases/download/Files/bsg.exe" -OutFile "$env:SystemRoot\Temp\bsg.exe"

# install escape from tarkov
Start-Process -Wait "$env:SystemRoot\Temp\bsg.exe" -ArgumentList "/VERYSILENT /NORESTART"

# create desktop shortcut
$WshShell = New-Object -comObject WScript.Shell
$Desktop = (New-Object -ComObject Shell.Application).Namespace('shell:Desktop').Self.Path
$Shortcut = $WshShell.CreateShortcut("$Desktop\Battlestate Games Launcher.lnk")
$Shortcut.TargetPath = "$env:SystemDrive\Battlestate Games\BsgLauncher\BsgLauncher.exe"
$Shortcut.WorkingDirectory = "$env:SystemDrive\Battlestate Games\BsgLauncher"
$Shortcut.Save()

# cleaner start menu shortcut path
Move-Item -Path "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\Battlestate Games\Battlestate Games Launcher.lnk" -Destination "$env:ProgramData\Microsoft\Windows\Start Menu\Programs" -Force -ErrorAction SilentlyContinue | Out-Null
Remove-Item "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\Battlestate Games" -Recurse -Force -ErrorAction SilentlyContinue | Out-Null

show-menu
    }

Add-Tweak -Id 'install-firefox' -Category 'Installers' -Kind Action -Button 'Install' -Name 'Firefox' -Risk Safe `
    -Description 'Download and install Firefox' `
    -Apply {
if (-not (Test-Connection -ComputerName '8.8.8.8' -Count 1 -Quiet -ErrorAction SilentlyContinue)) { Write-Log 'Internet connection required'; return }
Write-Host "Installing: Firefox..."

# download firefox
IWR "https://github.com/isleap9/AkariOS-Files/releases/download/Files/firefox.exe" -OutFile "$env:SystemRoot\Temp\firefox.exe"

# install firefox
Start-Process -Wait "$env:SystemRoot\Temp\firefox.exe" -ArgumentList "/S"

# uninstall mozilla maintenance service
Start-Process -FilePath "C:\Program Files (x86)\Mozilla Maintenance Service\uninstall.exe" -ArgumentList "/S" -WindowStyle Hidden -Wait

# remove firefox scheduled tasks
Get-ScheduledTask | Where-Object {$_.Taskname -match 'Firefox'} | Unregister-ScheduledTask -Confirm:$false -ErrorAction SilentlyContinue

# install ublock origin
$uBlockDir = "C:\Program Files\Mozilla Firefox\distribution\extensions"
If (!(Test-Path $ublockDir)) { New-Item -ItemType Directory -Path $ublockDir -Force | Out-Null }
IWR "https://addons.mozilla.org/firefox/downloads/latest/ublock-origin/latest.xpi" -OutFile "$uBlockDir\uBlock0@raymondhill.net.xpi"

# disable firefox updates
cmd /c "reg add `"HKLM\SOFTWARE\Policies\Mozilla\Firefox`" /v `"AppAutoUpdate`" /t REG_DWORD /d `"0`" /f >nul 2>&1"

# start and close firefox hidden to create profiles folder
Start-Process -FilePath "$env:SystemDrive\Program Files\Mozilla Firefox\firefox.exe" -ArgumentList "--headless"
Start-Sleep -Seconds 5
Stop-Process -Name "firefox" -Force -ErrorAction SilentlyContinue

# disable firefox hardware acceleration
$JsFile = @'
user_pref("layers.acceleration.disabled", true);
user_pref("gfx.direct2d.disabled", true);
'@
$FireFoxProfile = Get-ChildItem "$env:APPDATA\Mozilla\Firefox\Profiles" -Directory | Where-Object { $_.Name -match '\.default-release$' } | Sort-Object LastWriteTime -Descending | Select-Object -First 1
if ($FireFoxProfile) {
[System.IO.File]::WriteAllText("$($FireFoxProfile.FullName)\user.js", $JsFile, [System.Text.UTF8Encoding]::new($false))
}

# remove logon firefox
$basePath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
Get-Item $basePath | ForEach-Object {
foreach ($valueName in $_.GetValueNames()) {
if ($valueName -like "*Firefox*") {
Remove-ItemProperty -Path $_.PsPath -Name $valueName -Force -ErrorAction SilentlyContinue
}
}
}

# cleaner start menu shortcut path
Remove-Item "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\Firefox Private Browsing.lnk" -Recurse -Force -ErrorAction SilentlyContinue | Out-Null
Remove-Item "$env:AppData\Microsoft\Windows\Start Menu\Programs\Firefox.lnk" -Recurse -Force -ErrorAction SilentlyContinue | Out-Null

show-menu
    }

Add-Tweak -Id 'install-frame-view' -Category 'Installers' -Kind Action -Button 'Install' -Name 'Frame View' -Risk Safe `
    -Description 'Download and install Frame View' `
    -Apply {
if (-not (Test-Connection -ComputerName '8.8.8.8' -Count 1 -Quiet -ErrorAction SilentlyContinue)) { Write-Log 'Internet connection required'; return }
Write-Host "Installing: Frame View..."

# download frame view
IWR "https://github.com/isleap9/AkariOS-Files/releases/download/Files/frameview.exe" -OutFile "$env:SystemRoot\Temp\frameview.exe"

# install frame view
Start-Process -Wait "$env:SystemRoot\Temp\frameview.exe" -ArgumentList "/s"

# cleaner start menu shortcut path
Move-Item -Path "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\NVIDIA FrameView\FrameView.lnk" -Destination "$env:ProgramData\Microsoft\Windows\Start Menu\Programs" -Force -ErrorAction SilentlyContinue | Out-Null
Remove-Item "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\NVIDIA FrameView" -Recurse -Force -ErrorAction SilentlyContinue | Out-Null

show-menu
    }

Add-Tweak -Id 'install-gog-launcher' -Category 'Installers' -Kind Action -Button 'Install' -Name 'GOG launcher' -Risk Safe `
    -Description 'Download and install GOG launcher' `
    -Apply {
if (-not (Test-Connection -ComputerName '8.8.8.8' -Count 1 -Quiet -ErrorAction SilentlyContinue)) { Write-Log 'Internet connection required'; return }
Write-Host "Installing: GOG launcher..."
Write-Host "Close launcher when installer is finished"

# download gog launcher
IWR "https://github.com/isleap9/AkariOS-Files/releases/download/Files/gog.exe" -OutFile "$env:SystemRoot\Temp\gog.exe"

# install gog launcher
Start-Process -Wait "$env:SystemRoot\Temp\gog.exe"

# remove logon gog launcher
cmd /c "reg delete `"HKCU\Software\Microsoft\Windows\CurrentVersion\Run`" /v `"GalaxyClient`" /f >nul 2>&1"
cmd /c "reg delete `"HKCU\Software\Microsoft\Windows\CurrentVersion\Run`" /v `"GogGalaxy`" /f >nul 2>&1"

# cleaner start menu shortcut path
Move-Item -Path "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\GOG.com\GOG GALAXY\GOG GALAXY.lnk" -Destination "$env:ProgramData\Microsoft\Windows\Start Menu\Programs" -Force -ErrorAction SilentlyContinue | Out-Null
Remove-Item "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\GOG.com" -Recurse -Force -ErrorAction SilentlyContinue | Out-Null

show-menu
    }

Add-Tweak -Id 'install-google-chrome' -Category 'Installers' -Kind Action -Button 'Install' -Name 'Google Chrome' -Risk Safe `
    -Description 'Download and install Google Chrome' `
    -Apply {
if (-not (Test-Connection -ComputerName '8.8.8.8' -Count 1 -Quiet -ErrorAction SilentlyContinue)) { Write-Log 'Internet connection required'; return }
Write-Host "Installing: Google Chrome..."

# download google chrome
IWR "https://github.com/isleap9/AkariOS-Files/releases/download/Files/chrome.exe" -OutFile "$env:SystemRoot\Temp\chrome.exe"

# install google chrome
Start-Process -Wait "$env:SystemRoot\Temp\chrome.exe" -ArgumentList "--silent --install" -WindowStyle Hidden

# install ublock origin lite
cmd /c "reg add `"HKLM\SOFTWARE\Policies\Google\Chrome\ExtensionInstallForcelist`" /v `"1`" /t REG_SZ /d `"ddkjiahejlhfcafbddmgiahcphecmpfh;https://clients2.google.com/service/update2/crx`" /f >nul 2>&1"

# add chrome policies
cmd /c "reg add `"HKLM\SOFTWARE\Policies\Google\Chrome`" /v `"HardwareAccelerationModeEnabled`" /t REG_DWORD /d `"0`" /f >nul 2>&1"
cmd /c "reg add `"HKLM\SOFTWARE\Policies\Google\Chrome`" /v `"BackgroundModeEnabled`" /t REG_DWORD /d `"0`" /f >nul 2>&1"
cmd /c "reg add `"HKLM\SOFTWARE\Policies\Google\Chrome`" /v `"HighEfficiencyModeEnabled`" /t REG_DWORD /d `"1`" /f >nul 2>&1"

# remove logon chrome
$basePath = "HKLM:\Software\Microsoft\Active Setup\Installed Components"
Get-ChildItem $basePath | ForEach-Object {
$val = (Get-ItemProperty $_.PsPath)."(default)"
if ($val -like "*Chrome*") {
Remove-Item $_.PsPath -Force -ErrorAction SilentlyContinue
}
}

# remove chrome services
$services = Get-Service | Where-Object { $_.Name -match 'Google' }
foreach ($service in $services) {
cmd /c "sc stop `"$($service.Name)`" >nul 2>&1"
cmd /c "sc delete `"$($service.Name)`" >nul 2>&1"
}

# remove chrome scheduled tasks
Get-ScheduledTask | Where-Object { $_.TaskName -like '*Google*' } | Unregister-ScheduledTask -Confirm:$false -ErrorAction SilentlyContinue

show-menu
    }

Add-Tweak -Id 'install-helium' -Category 'Installers' -Kind Action -Button 'Install' -Name 'Helium' -Risk Safe `
    -Description 'Download and install Helium' `
    -Apply {
if (-not (Test-Connection -ComputerName '8.8.8.8' -Count 1 -Quiet -ErrorAction SilentlyContinue)) { Write-Log 'Internet connection required'; return }
Write-Host "Installing: Helium..."

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

show-menu
    }

Add-Tweak -Id 'install-league-of-legends' -Category 'Installers' -Kind Action -Button 'Install' -Name 'League Of Legends' -Risk Safe `
    -Description 'Download and install League Of Legends' `
    -Apply {
if (-not (Test-Connection -ComputerName '8.8.8.8' -Count 1 -Quiet -ErrorAction SilentlyContinue)) { Write-Log 'Internet connection required'; return }
Write-Host "Installing: League Of Legends..."

# download league of legends
IWR "https://github.com/isleap9/AkariOS-Files/releases/download/Files/league.exe" -OutFile "$env:SystemRoot\Temp\league.exe"

# install league of legends
Start-Process "$env:SystemRoot\Temp\league.exe" -ArgumentList "--skip-to-install"

Start-Sleep -Seconds 10

Get-Process -Name "league" -ErrorAction SilentlyContinue | Wait-Process -ErrorAction SilentlyContinue

# remove logon league of legends
cmd /c "reg delete `"HKCU\Software\Microsoft\Windows\CurrentVersion\Run`" /v `"RiotClient`" /f >nul 2>&1"

# cleaner start menu shortcut path
Move-Item -Path "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\Riot Games\*" -Destination "$env:ProgramData\Microsoft\Windows\Start Menu\Programs" -Force -ErrorAction SilentlyContinue | Out-Null
Remove-Item "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\Riot Games" -Recurse -Force -ErrorAction SilentlyContinue | Out-Null
Remove-Item "$env:AppData\Microsoft\Windows\Start Menu\Programs\Riot Games" -Recurse -Force -ErrorAction SilentlyContinue | Out-Null

show-menu
    }

Add-Tweak -Id 'install-more-clock-tool' -Category 'Installers' -Kind Action -Button 'Install' -Name 'More Clock Tool' -Risk Safe `
    -Description 'Download and install More Clock Tool' `
    -Apply {
if (-not (Test-Connection -ComputerName '8.8.8.8' -Count 1 -Quiet -ErrorAction SilentlyContinue)) { Write-Log 'Internet connection required'; return }
Write-Host "Installing: More Clock Tool..."

# new folder
New-Item -Path "$env:SystemDrive\Program Files (x86)\More Clock Tool" -ItemType Directory -Force -ErrorAction SilentlyContinue | Out-Null

# download more clock tool
IWR "https://github.com/isleap9/AkariOS-Files/releases/download/Files/moreclocktool.exe" -OutFile "$env:SystemDrive\Program Files (x86)\More Clock Tool\More Clock Tool.exe"

# create desktop shortcut
$WshShell = New-Object -comObject WScript.Shell
$Desktop = (New-Object -ComObject Shell.Application).Namespace('shell:Desktop').Self.Path
$Shortcut = $WshShell.CreateShortcut("$Desktop\More Clock Tool.lnk")
$Shortcut.TargetPath = "$env:SystemDrive\Program Files (x86)\More Clock Tool\More Clock Tool.exe"
$Shortcut.WorkingDirectory = "$env:SystemDrive\Program Files (x86)\More Clock Tool"
$Shortcut.Save()

# create start menu shortcut
$WshShell = New-Object -comObject WScript.Shell
$Shortcut = $WshShell.CreateShortcut("$env:ProgramData\Microsoft\Windows\Start Menu\Programs\More Clock Tool.lnk")
$Shortcut.TargetPath = "$env:SystemDrive\Program Files (x86)\More Clock Tool\More Clock Tool.exe"
$Shortcut.WorkingDirectory = "$env:SystemDrive\Program Files (x86)\More Clock Tool"
$Shortcut.Save()

show-menu
    }

Add-Tweak -Id 'install-notepad' -Category 'Installers' -Kind Action -Button 'Install' -Name 'Notepad ++' -Risk Safe `
    -Description 'Download and install Notepad ++' `
    -Apply {
if (-not (Test-Connection -ComputerName '8.8.8.8' -Count 1 -Quiet -ErrorAction SilentlyContinue)) { Write-Log 'Internet connection required'; return }
Write-Host "Installing: Notepad ++..."

# download notepad ++
IWR "https://github.com/isleap9/AkariOS-Files/releases/download/Files/notepad++.exe" -OutFile "$env:SystemRoot\Temp\notepad++.exe"

# install notepad ++
Start-Process -Wait "$env:SystemRoot\Temp\notepad++.exe" -ArgumentList "/S"

# new folder
New-Item -Path "$env:AppData" -Name "Notepad++" -ItemType Directory -ErrorAction SilentlyContinue | Out-Null

# create config for notepad ++
$NotePadConfig = @'
<?xml version="1.0" encoding="UTF-8" ?>
<NotepadPlus>
    <ProjectPanels>
        <ProjectPanel id="0" workSpaceFile="" />
        <ProjectPanel id="1" workSpaceFile="" />
        <ProjectPanel id="2" workSpaceFile="" />
    </ProjectPanels>
    <ColumnEditor choice="number">
        <text content="" />
        <number initial="-1" increase="-1" repeat="-1" formatChoice="dec" leadingChoice="none" />
    </ColumnEditor>
    <GUIConfigs>
        <GUIConfig name="ToolBar" visible="yes" fluentColor="0" fluentCustomColor="16229943" fluentMono="no">small</GUIConfig>
        <GUIConfig name="StatusBar">show</GUIConfig>
        <GUIConfig name="TabBar" dragAndDrop="yes" drawTopBar="yes" drawInactiveTab="yes" reduce="yes" closeButton="yes" pinButton="yes" showOnlyPinnedButton="no" buttonsOninactiveTabs="no" doubleClick2Close="no" vertical="no" multiLine="no" hide="no" quitOnEmpty="no" iconSetNumber="0" tabCompactLabelLen="0" />
        <GUIConfig name="ScintillaViewsSplitter">vertical</GUIConfig>
        <GUIConfig name="UserDefineDlg" position="undocked">hide</GUIConfig>
        <GUIConfig name="TabSetting" replaceBySpace="no" size="4" backspaceUnindent="no" />
        <GUIConfig name="AppPosition" x="0" y="0" width="1024" height="700" isMaximized="no" />
        <GUIConfig name="FindWindowPosition" left="0" top="0" right="0" bottom="0" isLessModeOn="no" />
        <GUIConfig name="FinderConfig" wrappedLines="no" purgeBeforeEverySearch="no" showOnlyOneEntryPerFoundLine="yes" />
        <GUIConfig name="noUpdate" intervalDays="15" nextUpdateDate="20260401" autoUpdateMode="0">yes</GUIConfig>
        <GUIConfig name="Auto-detection">yes</GUIConfig>
        <GUIConfig name="CheckHistoryFiles">no</GUIConfig>
        <GUIConfig name="TrayIcon">0</GUIConfig>
        <GUIConfig name="MaintainIndent">1</GUIConfig>
        <GUIConfig name="TagsMatchHighLight" TagAttrHighLight="yes" HighLightNonHtmlZone="no">yes</GUIConfig>
        <GUIConfig name="RememberLastSession">no</GUIConfig>
        <GUIConfig name="KeepSessionAbsentFileEntries">no</GUIConfig>
        <GUIConfig name="DetectEncoding">yes</GUIConfig>
        <GUIConfig name="SaveAllConfirm">yes</GUIConfig>
        <GUIConfig name="NewDocDefaultSettings" format="0" encoding="4" lang="0" codepage="-1" openAnsiAsUTF8="yes" addNewDocumentOnStartup="no" useContentAsTabName="no" />
        <GUIConfig name="langsExcluded" gr0="0" gr1="0" gr2="0" gr3="0" gr4="0" gr5="0" gr6="0" gr7="0" gr8="0" gr9="0" gr10="0" gr11="0" gr12="0" langMenuCompact="yes" />
        <GUIConfig name="Print" lineNumber="yes" printOption="3" headerLeft="" headerMiddle="" headerRight="" footerLeft="" footerMiddle="" footerRight="" headerFontName="" headerFontStyle="0" headerFontSize="0" footerFontName="" footerFontStyle="0" footerFontSize="0" margeLeft="0" margeRight="0" margeTop="0" margeBottom="0" />
        <GUIConfig name="Backup" action="0" useCustumDir="no" dir="" isSnapshotMode="no" snapshotBackupTiming="7000" />
        <GUIConfig name="TaskList">yes</GUIConfig>
        <GUIConfig name="MRU">yes</GUIConfig>
        <GUIConfig name="URL">0</GUIConfig>
        <GUIConfig name="uriCustomizedSchemes">svn:// cvs:// git:// imap:// irc:// irc6:// ircs:// ldap:// ldaps:// news: telnet:// gopher:// ssh:// sftp:// smb:// skype: snmp:// spotify: steam:// sms: slack:// chrome:// bitcoin:</GUIConfig>
        <GUIConfig name="globalOverride" fg="no" bg="no" font="no" fontSize="no" bold="no" italic="no" underline="no" />
        <GUIConfig name="auto-completion" autoCAction="3" triggerFromNbChar="1" autoCIgnoreNumbers="yes" insertSelectedItemUseENTER="yes" insertSelectedItemUseTAB="yes" autoCBrief="no" funcParams="yes" />
        <GUIConfig name="auto-insert" parentheses="no" brackets="no" curlyBrackets="no" quotes="no" doubleQuotes="no" htmlXmlTag="no" />
        <GUIConfig name="sessionExt"></GUIConfig>
        <GUIConfig name="workspaceExt"></GUIConfig>
        <GUIConfig name="MenuBar">show</GUIConfig>
        <GUIConfig name="Caret" width="1" blinkRate="600" />
        <GUIConfig name="openSaveDir" value="0" defaultDirPath="" lastUsedDirPath="" />
        <GUIConfig name="titleBar" short="no" />
        <GUIConfig name="insertDateTime" customizedFormat="yyyy-MM-dd HH:mm:ss" reverseDefaultOrder="no" />
        <GUIConfig name="wordCharList" useDefault="yes" charsAdded="" />
        <GUIConfig name="delimiterSelection" leftmostDelimiter="40" rightmostDelimiter="41" delimiterSelectionOnEntireDocument="no" />
        <GUIConfig name="largeFileRestriction" fileSizeMB="200" isEnabled="yes" allowAutoCompletion="no" allowBraceMatch="no" allowSmartHilite="no" allowClickableLink="no" deactivateWordWrap="yes" suppress2GBWarning="no" />
        <GUIConfig name="multiInst" setting="0" clipboardHistory="no" documentList="no" characterPanel="no" folderAsWorkspace="no" projectPanels="no" documentMap="no" fuctionList="no" pluginPanels="no" />
        <GUIConfig name="MISC" fileSwitcherWithoutExtColumn="no" fileSwitcherExtWidth="50" fileSwitcherWithoutPathColumn="yes" fileSwitcherPathWidth="50" fileSwitcherNoGroups="no" backSlashIsEscapeCharacterForSql="yes" writeTechnologyEngine="1" isFolderDroppedOpenFiles="no" docPeekOnTab="no" docPeekOnMap="no" sortFunctionList="no" saveDlgExtFilterToAllTypes="no" muteSounds="yes" enableFoldCmdToggable="no" hideMenuRightShortcuts="no" />
        <GUIConfig name="Searching" monospacedFontFindDlg="no" fillFindFieldWithSelected="yes" fillFindFieldSelectCaret="yes" findDlgAlwaysVisible="no" confirmReplaceInAllOpenDocs="yes" replaceStopsWithoutFindingNext="no" inSelectionAutocheckThreshold="1024" fillFindWhatThreshold="1024" fillDirFieldFromActiveDoc="no" />
        <GUIConfig name="searchEngine" searchEngineChoice="2" searchEngineCustom="" />
        <GUIConfig name="MarkAll" matchCase="no" wholeWordOnly="yes" />
        <GUIConfig name="SmartHighLight" matchCase="no" wholeWordOnly="yes" useFindSettings="no" onAnotherView="no">yes</GUIConfig>
        <GUIConfig name="DarkMode" enable="yes" colorTone="0" customColorTop="2105376" customColorMenuHotTrack="4539717" customColorActive="3684408" customColorMain="2105376" customColorError="176" customColorText="14737632" customColorDarkText="12632256" customColorDisabledText="8421504" customColorLinkText="65535" customColorEdge="6579300" customColorHotEdge="10197915" customColorDisabledEdge="4737096" enableWindowsMode="no" darkThemeName="DarkModeDefault.xml" darkToolBarIconSet="0" darkTbFluentColor="0" darkTbFluentCustomColor="16229943" darkTbFluentMono="no" darkTabIconSet="2" darkTabUseTheme="no" lightThemeName="" lightToolBarIconSet="4" lightTbFluentColor="0" lightTbFluentCustomColor="12873472" lightTbFluentMono="no" lightTabIconSet="0" lightTabUseTheme="yes" />
        <GUIConfig name="ScintillaPrimaryView" lineNumberMargin="show" lineNumberDynamicWidth="yes" bookMarkMargin="show" indentGuideLine="show" folderMarkStyle="box" isChangeHistoryEnabled="1" lineWrapMethod="aligned" currentLineIndicator="1" currentLineFrameWidth="1" virtualSpace="no" scrollBeyondLastLine="yes" rightClickKeepsSelection="no" selectedTextForegroundSingleColor="no" disableAdvancedScrolling="no" wrapSymbolShow="hide" Wrap="no" borderEdge="yes" isEdgeBgMode="no" edgeMultiColumnPos="" zoom="0" zoom2="0" whiteSpaceShow="hide" eolShow="hide" eolMode="1" npcShow="hide" npcMode="1" npcCustomColor="no" npcIncludeCcUniEOL="no" npcNoInputC0="yes" ccShow="yes" borderWidth="2" smoothFont="no" paddingLeft="0" paddingRight="0" distractionFreeDivPart="4" lineCopyCutWithoutSelection="yes" multiSelection="yes" columnSel2MultiEdit="yes" />
        <GUIConfig name="DockingManager" leftWidth="200" rightWidth="200" topHeight="200" bottomHeight="200">
            <ActiveTabs cont="0" activeTab="-1" />
            <ActiveTabs cont="1" activeTab="-1" />
            <ActiveTabs cont="2" activeTab="-1" />
            <ActiveTabs cont="3" activeTab="-1" />
        </GUIConfig>
    </GUIConfigs>
    <FindHistory nbMaxFindHistoryPath="10" nbMaxFindHistoryFilter="10" nbMaxFindHistoryFind="10" nbMaxFindHistoryReplace="10" matchWord="no" matchCase="no" wrap="yes" directionDown="yes" fifRecuisive="yes" fifInHiddenFolder="no" fifProjectPanel1="no" fifProjectPanel2="no" fifProjectPanel3="no" fifFilterFollowsDoc="no" searchMode="0" transparencyMode="1" transparency="150" dotMatchesNewline="no" isSearch2ButtonsMode="no" regexBackward4PowerUser="no" bookmarkLine="no" purge="no" />
    <History nbMaxFile="0" inSubMenu="no" customLength="-1" />
</NotepadPlus>

'@
Set-Content -Path "$env:AppData\Notepad++\config.xml" -Value $NotePadConfig -Force

# create desktop shortcut
$WshShell = New-Object -comObject WScript.Shell
$Desktop = (New-Object -ComObject Shell.Application).Namespace('shell:Desktop').Self.Path
$Shortcut = $WshShell.CreateShortcut("$Desktop\Notepad++.lnk")
$Shortcut.TargetPath = "$env:SystemDrive\Program Files\Notepad++\notepad++.exe"
$Shortcut.WorkingDirectory = "$env:SystemDrive\Program Files\Notepad++"
$Shortcut.Save()

# cleaner start menu shortcut path
Move-Item -Path "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\Notepad++\Notepad++.lnk" -Destination "$env:ProgramData\Microsoft\Windows\Start Menu\Programs" -Force -ErrorAction SilentlyContinue | Out-Null
Remove-Item "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\Notepad++" -Recurse -Force -ErrorAction SilentlyContinue | Out-Null

show-menu
    }

Add-Tweak -Id 'install-nvidia-app' -Category 'Installers' -Kind Action -Button 'Install' -Name 'Nvidia App' -Risk Safe `
    -Description 'Download and install Nvidia App' `
    -Apply {
if (-not (Test-Connection -ComputerName '8.8.8.8' -Count 1 -Quiet -ErrorAction SilentlyContinue)) { Write-Log 'Internet connection required'; return }
Write-Host "Installing: Nvidia App..."

# download nvidia app
IWR "https://github.com/isleap9/AkariOS-Files/releases/download/Files/nvidiaapp.exe" -OutFile "$env:SystemRoot\Temp\nvidiaapp.exe"

# install nvidia app
Start-Process -Wait "$env:SystemRoot\Temp\nvidiaapp.exe" -ArgumentList "/s"

# cleaner start menu shortcut path
Move-Item -Path "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\NVIDIA Corporation\NVIDIA App.lnk" -Destination "$env:ProgramData\Microsoft\Windows\Start Menu\Programs" -Force -ErrorAction SilentlyContinue | Out-Null
Remove-Item "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\NVIDIA Corporation" -Recurse -Force -ErrorAction SilentlyContinue | Out-Null

show-menu
    }

Add-Tweak -Id 'install-nvidia-profile-inspector' -Category 'Installers' -Kind Action -Button 'Install' -Name 'Nvidia Profile Inspector' -Risk Safe `
    -Description 'Download and install Nvidia Profile Inspector' `
    -Apply {
if (-not (Test-Connection -ComputerName '8.8.8.8' -Count 1 -Quiet -ErrorAction SilentlyContinue)) { Write-Log 'Internet connection required'; return }
Write-Host "Installing: Nvidia Profile Inspector..."

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

show-menu
    }

Add-Tweak -Id 'install-obs-studio' -Category 'Installers' -Kind Action -Button 'Install' -Name 'OBS Studio' -Risk Safe `
    -Description 'Download and install OBS Studio' `
    -Apply {
if (-not (Test-Connection -ComputerName '8.8.8.8' -Count 1 -Quiet -ErrorAction SilentlyContinue)) { Write-Log 'Internet connection required'; return }
Write-Host "Installing: OBS Studio..."

# download obs studio
IWR "https://github.com/isleap9/AkariOS-Files/releases/download/Files/obs.exe" -OutFile "$env:SystemRoot\Temp\obs.exe"

# install obs studio
Start-Process -Wait "$env:SystemRoot\Temp\obs.exe" -ArgumentList "/S"

show-menu
    }

Add-Tweak -Id 'install-onboard-memory-manager' -Category 'Installers' -Kind Action -Button 'Install' -Name 'Onboard Memory Manager' -Risk Safe `
    -Description 'Download and install Onboard Memory Manager' `
    -Apply {
if (-not (Test-Connection -ComputerName '8.8.8.8' -Count 1 -Quiet -ErrorAction SilentlyContinue)) { Write-Log 'Internet connection required'; return }
Write-Host "Installing: Onboard Memory Manager..."

# new folder
New-Item -Path "$env:SystemDrive\Program Files (x86)\Onboard Memory Manager" -ItemType Directory -Force -ErrorAction SilentlyContinue | Out-Null

# download onboard memory manager
IWR "https://github.com/isleap9/AkariOS-Files/releases/download/Files/omm.exe" -OutFile "$env:SystemDrive\Program Files (x86)\Onboard Memory Manager\Onboard Memory Manager.exe"

# create desktop shortcut
$WshShell = New-Object -comObject WScript.Shell
$Desktop = (New-Object -ComObject Shell.Application).Namespace('shell:Desktop').Self.Path
$Shortcut = $WshShell.CreateShortcut("$Desktop\Onboard Memory Manager.lnk")
$Shortcut.TargetPath = "$env:SystemDrive\Program Files (x86)\Onboard Memory Manager\Onboard Memory Manager.exe"
$Shortcut.WorkingDirectory = "$env:SystemDrive\Program Files (x86)\Onboard Memory Manager"
$Shortcut.Save()

# create start menu shortcut
$WshShell = New-Object -comObject WScript.Shell
$Shortcut = $WshShell.CreateShortcut("$env:ProgramData\Microsoft\Windows\Start Menu\Programs\Onboard Memory Manager.lnk")
$Shortcut.TargetPath = "$env:SystemDrive\Program Files (x86)\Onboard Memory Manager\Onboard Memory Manager.exe"
$Shortcut.WorkingDirectory = "$env:SystemDrive\Program Files (x86)\Onboard Memory Manager"
$Shortcut.Save()

show-menu
    }

Add-Tweak -Id 'install-pot-player' -Category 'Installers' -Kind Action -Button 'Install' -Name 'Pot Player' -Risk Safe `
    -Description 'Download and install Pot Player' `
    -Apply {
if (-not (Test-Connection -ComputerName '8.8.8.8' -Count 1 -Quiet -ErrorAction SilentlyContinue)) { Write-Log 'Internet connection required'; return }
Write-Host "Installing: Pot Player..."

# download pot player
IWR "https://github.com/isleap9/AkariOS-Files/releases/download/Files/potplayer.exe" -OutFile "$env:SystemRoot\Temp\potplayer.exe"

# install pot player
Start-Process -Wait "$env:SystemRoot\Temp\potplayer.exe" -ArgumentList "/S /allusers"

# cleaner start menu shortcut path
Move-Item -Path "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\PotPlayer\PotPlayer 64 bit.lnk" -Destination "$env:ProgramData\Microsoft\Windows\Start Menu\Programs" -Force -ErrorAction SilentlyContinue | Out-Null
Remove-Item "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\PotPlayer" -Recurse -Force -ErrorAction SilentlyContinue | Out-Null

show-menu
    }

Add-Tweak -Id 'install-roblox' -Category 'Installers' -Kind Action -Button 'Install' -Name 'Roblox' -Risk Safe `
    -Description 'Download and install Roblox' `
    -Apply {
if (-not (Test-Connection -ComputerName '8.8.8.8' -Count 1 -Quiet -ErrorAction SilentlyContinue)) { Write-Log 'Internet connection required'; return }
Write-Host "Installing: Roblox..."

# download roblox
IWR "https://github.com/isleap9/AkariOS-Files/releases/download/Files/roblox.exe" -OutFile "$env:SystemRoot\Temp\roblox.exe"

# install roblox
Start-Process "$env:SystemRoot\Temp\roblox.exe" -ArgumentList "/S"

Start-Sleep -Seconds 5

# stop edge running
$stop = "MicrosoftEdgeUpdate", "msedge", "msedgewebview2"
$stop | ForEach-Object { Stop-Process -Name $_ -Force -ErrorAction SilentlyContinue }
Get-Process | Where-Object { $_.ProcessName -like "*edge*" } | Stop-Process -Force -ErrorAction SilentlyContinue

Start-Sleep -Seconds 5

# cleaner start menu shortcut path
Remove-Item "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\Roblox" -Recurse -Force -ErrorAction SilentlyContinue | Out-Null

# create start menu shortcut
$WshShell = New-Object -comObject WScript.Shell
$Shortcut = $WshShell.CreateShortcut("$env:ProgramData\Microsoft\Windows\Start Menu\Programs\Roblox.url")
$Shortcut.TargetPath = "roblox://placeId=0"
$Shortcut.Save()

# create desktop shortcut
$WshShell = New-Object -comObject WScript.Shell
$Desktop = (New-Object -ComObject Shell.Application).Namespace('shell:Desktop').Self.Path
$Shortcut = $WshShell.CreateShortcut("$Desktop\Roblox.url")
$Shortcut.TargetPath = "roblox://placeId=0"
$Shortcut.Save()

show-menu
    }

Add-Tweak -Id 'install-rockstar-games' -Category 'Installers' -Kind Action -Button 'Install' -Name 'Rockstar Games' -Risk Safe `
    -Description 'Download and install Rockstar Games' `
    -Apply {
if (-not (Test-Connection -ComputerName '8.8.8.8' -Count 1 -Quiet -ErrorAction SilentlyContinue)) { Write-Log 'Internet connection required'; return }
Write-Host "Installing: Rockstar Games..."

# download rockstar games
IWR "https://github.com/isleap9/AkariOS-Files/releases/download/Files/rockstar.exe" -OutFile "$env:SystemRoot\Temp\rockstar.exe"

# install rockstar games
Start-Process -Wait "$env:SystemRoot\Temp\rockstar.exe" -ArgumentList "/s /f"

# cleaner start menu shortcut path
Move-Item -Path "$env:AppData\Microsoft\Windows\Start Menu\Programs\Rockstar Games\Rockstar Games Launcher.lnk" -Destination "$env:ProgramData\Microsoft\Windows\Start Menu\Programs" -Force -ErrorAction SilentlyContinue | Out-Null
Remove-Item "$env:AppData\Microsoft\Windows\Start Menu\Programs\Rockstar Games" -Recurse -Force -ErrorAction SilentlyContinue | Out-Null

show-menu
    }

Add-Tweak -Id 'install-spotify' -Category 'Installers' -Kind Action -Button 'Install' -Name 'Spotify' -Risk Safe `
    -Description 'Download and install Spotify' `
    -Apply {
if (-not (Test-Connection -ComputerName '8.8.8.8' -Count 1 -Quiet -ErrorAction SilentlyContinue)) { Write-Log 'Internet connection required'; return }
Write-Host "Installing: Spotify..."

# set config for spotify
New-Item -Path "$env:APPDATA\Spotify\prefs" -ItemType File -Force | Out-Null
$SpotifySettingsPrefs = @'
app.autostart-configured=true
app.autostart-mode="off"
ui.hardware_acceleration=false
'@
Set-Content -Path "$env:APPDATA\Spotify\prefs" -Value $SpotifySettingsPrefs -Force | Out-Null

# fix path for space in username
$Global:tempDir = (([System.IO.Path]::GetTempPath())).trimend('\')

# download spotify
IWR "https://github.com/isleap9/AkariOS-Files/releases/download/Files/spotify.exe" -OutFile "$tempDir\spotify.exe"

# install spotify
Start-Process "explorer.exe" -ArgumentList "$tempDir\spotify.exe"

Start-Sleep -Seconds 5

Get-Process -Name "spotify" -ErrorAction SilentlyContinue | Wait-Process -ErrorAction SilentlyContinue

# cleaner start menu shortcut path
Move-Item -Path "$env:AppData\Microsoft\Windows\Start Menu\Programs\Spotify.lnk" -Destination "$env:ProgramData\Microsoft\Windows\Start Menu\Programs" -Force -ErrorAction SilentlyContinue | Out-Null

show-menu
    }

Add-Tweak -Id 'install-steam' -Category 'Installers' -Kind Action -Button 'Install' -Name 'Steam' -Risk Safe `
    -Description 'Download and install Steam' `
    -Apply {
if (-not (Test-Connection -ComputerName '8.8.8.8' -Count 1 -Quiet -ErrorAction SilentlyContinue)) { Write-Log 'Internet connection required'; return }
Write-Host "Installing: Steam..."

# download steam
IWR "https://github.com/isleap9/AkariOS-Files/releases/download/Files/steam.exe" -OutFile "$env:SystemRoot\Temp\steam.exe"

# install steam
Start-Process -Wait "$env:SystemRoot\Temp\steam.exe" -ArgumentList "/S"

# remove logon steam
cmd /c "reg delete `"HKCU\Software\Microsoft\Windows\CurrentVersion\Run`" /v `"Steam`" /f >nul 2>&1"

# cleaner start menu shortcut path
Move-Item -Path "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\Steam\Steam.lnk" -Destination "$env:ProgramData\Microsoft\Windows\Start Menu\Programs" -Force -ErrorAction SilentlyContinue | Out-Null
Remove-Item "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\Steam" -Recurse -Force -ErrorAction SilentlyContinue | Out-Null

show-menu
    }

Add-Tweak -Id 'install-ubisoft-connect' -Category 'Installers' -Kind Action -Button 'Install' -Name 'Ubisoft Connect' -Risk Safe `
    -Description 'Download and install Ubisoft Connect' `
    -Apply {
if (-not (Test-Connection -ComputerName '8.8.8.8' -Count 1 -Quiet -ErrorAction SilentlyContinue)) { Write-Log 'Internet connection required'; return }
Write-Host "Installing: Ubisoft Connect..."

# download ubisoft connect
IWR "https://github.com/isleap9/AkariOS-Files/releases/download/Files/ubisoft.exe" -OutFile "$env:SystemRoot\Temp\ubisoft.exe"

# install ubisoft connect
Start-Process -Wait "$env:SystemRoot\Temp\ubisoft.exe" -ArgumentList "/S"

# cleaner start menu shortcut path
Move-Item -Path "$env:AppData\Microsoft\Windows\Start Menu\Programs\Ubisoft\Ubisoft Connect\Ubisoft Connect.lnk" -Destination "$env:ProgramData\Microsoft\Windows\Start Menu\Programs" -Force -ErrorAction SilentlyContinue | Out-Null
Remove-Item "$env:AppData\Microsoft\Windows\Start Menu\Programs\Ubisoft" -Recurse -Force -ErrorAction SilentlyContinue | Out-Null

show-menu
    }

Add-Tweak -Id 'install-valorant' -Category 'Installers' -Kind Action -Button 'Install' -Name 'Valorant' -Risk Safe `
    -Description 'Download and install Valorant' `
    -Apply {
if (-not (Test-Connection -ComputerName '8.8.8.8' -Count 1 -Quiet -ErrorAction SilentlyContinue)) { Write-Log 'Internet connection required'; return }
Write-Host "Installing: Valorant..."

# download valorant
IWR "https://github.com/isleap9/AkariOS-Files/releases/download/Files/valorant.exe" -OutFile "$env:SystemRoot\Temp\valorant.exe"

# install valorant
Start-Process "$env:SystemRoot\Temp\valorant.exe" -ArgumentList "--skip-to-install"

Start-Sleep -Seconds 10

Get-Process -Name "valorant" -ErrorAction SilentlyContinue | Wait-Process -ErrorAction SilentlyContinue

# remove logon valorant
cmd /c "reg delete `"HKCU\Software\Microsoft\Windows\CurrentVersion\Run`" /v `"RiotClient`" /f >nul 2>&1"

# cleaner start menu shortcut path
Move-Item -Path "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\Riot Games\*" -Destination "$env:ProgramData\Microsoft\Windows\Start Menu\Programs" -Force -ErrorAction SilentlyContinue | Out-Null
Remove-Item "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\Riot Games" -Recurse -Force -ErrorAction SilentlyContinue | Out-Null
Remove-Item "$env:AppData\Microsoft\Windows\Start Menu\Programs\Riot Games" -Recurse -Force -ErrorAction SilentlyContinue | Out-Null

show-menu
    }

Add-Tweak -Id 'install-exit' -Category 'Installers' -Kind Action -Button 'Install' -Name 'Exit' -Risk Safe `
    -Description 'Download and install Exit' `
    -Apply {
if (-not (Test-Connection -ComputerName '8.8.8.8' -Count 1 -Quiet -ErrorAction SilentlyContinue)) { Write-Log 'Internet connection required'; return }
    }

Add-Tweak -Id 'msi-afterburner' -Category 'Installers' -Kind Action -Button 'Install' -Name 'MSI Afterburner' -Risk Safe `
    -Description 'Download and install MSI Afterburner with Akari settings' `
    -Apply {
if (-not (Test-Connection -ComputerName '8.8.8.8' -Count 1 -Quiet -ErrorAction SilentlyContinue)) { Write-Log 'Internet connection required'; return }
## explorer "https://www.guru3d.com/download/msi-afterburner-beta-download"
Write-Host "Installing: MSI Afterburner. Please wait...`n"
Write-Host "GPU 'Power' & 'Power Percent' logging disabled"
Write-Host "Causes FPS and 1% low issues`n"

# download msi afterburner
IWR "https://github.com/FR33THYFR33THY/Ultimate/releases/download/Files/msiafterburner.exe" -OutFile "$env:SystemRoot\Temp\msiafterburner.exe"

# install msi afterburner
Start-Process -wait "$env:SystemRoot\Temp\msiafterburner.exe" -ArgumentList "/S"

# new profiles folder
New-Item -Path "$env:SystemDrive\Program Files (x86)\MSI Afterburner" -Name "Profiles" -ItemType Directory -ErrorAction SilentlyContinue | Out-Null

# create msiafterburner.cfg
$MsiAfterBurnerCfg = @"
[Settings]
Views=
LastUpdateCheck=5CD0B9A5h
Skin=MSIMystic.usf
StartWithWindows=0
StartMinimized=0
HwPollPeriod=1000
LockProfiles=0
ShowHints=0
ShowTooltips=0
LCDFont=font4x6.dat
RememberSettings=1
FirstRun=0
FirstUserDefineClick=1
FirstServerRun=0
CurrentGpu=0
Sync=1
Link=1
LinkThermal=1
ShowOSDTime=0
CaptureOSD=0
Profile1Hotkey=00000000h
Profile2Hotkey=00000000h
Profile3Hotkey=00000000h
Profile4Hotkey=00000000h
Profile5Hotkey=00000000h
OSDToggleHotkey=00000000h
OSDOnHotkey=00000000h
OSDOffHotkey=00000000h
OSDServerBlockHotkey=00000000h
LimiterToggleHotkey=00000000h
LimiterOnHotkey=00000000h
LimiterOffHotkey=00000000h
ScreenCaptureHotkey=00000000h
VideoCaptureHotkey=00000000h
VideoPrerecordHotkey=00000000h
PTTHotkey=00000000h
PTT2Hotkey=00000000h
BeginRecordHotkey=00000000h
EndRecordHotkey=00000000h
BeginLoggingHotkey=00000000h
EndLoggingHotkey=00000000h
ClearHistoryHotkey=00000000h
BenchmarkPath=C:\Benchmark.txt
AppendBenchmark=1
ScreenCaptureFormat=png
ScreenCaptureFolder=C:\
ScreenCaptureQuality=100
VideoCaptureFolder=C:\
VideoCaptureFormat=NV12
VideoCaptureQuality=100
VideoCaptureFramerate=60
VideoCaptureFramesize=00000001h
VideoCaptureThreads=FFFFFFFFh
AudioCaptureFlags=00000005h
VideoCaptureFlagsEx=00000000h
AudioCaptureFlags2=00000004h
VideoCaptureContainer=mkv
VideoPrerecordSizeLimit=256
VideoPrerecordTimeLimit=600
AutoPrerecord=0
WindowX=398
WindowY=309
ProfileContents=1
Profile2D=-1
Profile3D=-1
SwAutoFanControl=0
SwAutoFanControlFlags=00000000h
SwAutoFanControlPeriod=5000
SwAutoFanControlCurve=0000010004000000000000000000F0410000204200004842000048420000A0420000A0420000B4420000C8420000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
RestoreAfterSuspendedMode=1
PauseMonitoring=0
ShowPerformanceProfilerStatus=0
ShowPerformanceProfilerPanel=0
AttachMonitoringWindow=1
MonitoringWindowOnTop=1
LogPath=%ABDir%\HardwareMonitoring.hml
EnableLog=0
RecreateLog=0
LogLimit=10
OSDLayout=1
UnlockVoltageControl=1
UnlockVoltageMonitoring=1
OEM=0
ForceConstantVoltage=1
SingleTrayIconMode=0
Fahrenheit=0
Time24=0
LCDGraph=0
UnofficialOverclockingMode=1
UnofficialOverclockingDrvReset=1
UpdateCheckingPeriod=0
LowLevelInterface=1
MMIOUserMode=1
HAL=1
Driver=1
Language=
LayeredWindowMode=0
LayeredWindowAlpha=255
ScaleFactor=100
Sources=+RAM usage,+Memory usage,+CPU1 clock,+CPU2 clock,+CPU3 clock,+CPU4 clock,+CPU5 clock,+CPU6 clock,+CPU7 clock,+CPU8 clock,+CPU9 clock,+CPU10 clock,+CPU11 clock,+CPU12 clock,+CPU13 clock,+CPU14 clock,+CPU15 clock,+CPU16 clock,+CPU1 usage,+CPU2 usage,+CPU3 usage,+CPU4 usage,+CPU5 usage,+CPU6 usage,+CPU7 usage,+CPU8 usage,+CPU9 usage,+CPU10 usage,+CPU11 usage,+CPU12 usage,+CPU13 usage,+CPU14 usage,+CPU15 usage,+CPU16 usage,+CPU1 temperature,+CPU2 temperature,+CPU3 temperature,+CPU4 temperature,+CPU5 temperature,+CPU6 temperature,+CPU7 temperature,+CPU8 temperature,+CPU9 temperature,+CPU10 temperature,+CPU11 temperature,+CPU12 temperature,+CPU13 temperature,+CPU14 temperature,+CPU15 temperature,+CPU16 temperature,+CPU power,+CPU usage,+GPU usage,+Core clock,+Memory clock,+GPU temperature,+Framerate,+Framerate Avg,+Framerate 1% Low,+Framerate 0.1% Low,-Power,-Power percent,-GPU voltage,-Fan speed,-CPU temperature,-CPU clock,-FB usage,-Fan tachometer,-Commit charge,-Framerate Min,-Framerate Max,-Frametime,-Memory usage \ process,-RAM usage \ process,-VID usage,-BUS usage,-Fan speed 2,-Fan tachometer 2,-Temp limit,-Power limit,-Voltage limit,-No load limit,-CPU1 power,-CPU2 power,-CPU3 power,-CPU4 power,-CPU5 power,-CPU6 power,-CPU7 power,-CPU8 power,-CPU9 power,-CPU10 power,-CPU11 power,-CPU12 power,-CPU13 power,-CPU14 power,-CPU15 power,-CPU16 power,-Fan speed 3,-Fan tachometer 3
MonitoringGraphColumns=2
ShowProfiles=0
ShowMonitoring=1
ShowFramerate=0
ShowAdditionalPanel=0
Profile6Hotkey=00000000h
Profile7Hotkey=00000000h
Profile8Hotkey=00000000h
Profile9Hotkey=00000000h
Profile0Hotkey=00000000h
FanSync=1
CurrentFan=0
SwAutoFanControlCurve2=0000010004000000000000000000F0410000204200004842000048420000A0420000A0420000B4420000C8420000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
HideMonitoring=0
VFWindowX=1095
VFWindowY=275
VFWindowW=1037
VFWindowH=822
VFWindowOnTop=1
MonitoringWindowX=945
MonitoringWindowY=109
MonitoringWindowW=800
MonitoringWindowH=550
SwAutoFanControlCurve3=0000010004000000000000000000F0410000204200004842000048420000A0420000A0420000B4420000C8420000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
[ATIADLHAL]
UnofficialOverclockingMode=0
UnofficialOverclockingDrvReset=1
UnifiedActivityMonitoring=0
EraseStartupSettings=1
UnofficialOverclockingEULA=I confirm that I am aware of unofficial overclocking limitations and fully understand that MSI will not provide me any support on it
[Source GPU temperature]
ShowInOSD=0
ShowInLCD=0
ShowInTray=0
AlarmThresholdMin=
AlarmThresholdMax=
AlarmFlags=0
AlarmTimeout=5000
AlarmApp=
AlarmAppCmdLine=
EnableDataFiltering=0
MaxLimit=100
MinLimit=0
Group=\nGPU
Name=
TrayTextColor=FF0000h
TrayIconType=0
OSDItemType=0
GraphColor=00FF00h
Formula=
[Source Framerate Max]
ShowInOSD=1
ShowInLCD=0
ShowInTray=0
AlarmThresholdMin=
AlarmThresholdMax=
AlarmFlags=0
AlarmTimeout=5000
AlarmApp=
AlarmAppCmdLine=
EnableDataFiltering=0
MaxLimit=200
MinLimit=0
Group=
Name=
TrayTextColor=FF0000h
TrayIconType=0
OSDItemType=0
GraphColor=00FF00h
Formula=
[Source GPU usage]
ShowInOSD=0
ShowInLCD=0
ShowInTray=0
AlarmThresholdMin=
AlarmThresholdMax=
AlarmFlags=0
AlarmTimeout=5000
AlarmApp=
AlarmAppCmdLine=
EnableDataFiltering=0
MaxLimit=100
MinLimit=0
Group=GPU
Name=
TrayTextColor=FF0000h
TrayIconType=0
OSDItemType=0
GraphColor=00FF00h
Formula=
[Source FB usage]
ShowInOSD=1
ShowInLCD=0
ShowInTray=0
AlarmThresholdMin=
AlarmThresholdMax=
AlarmFlags=0
AlarmTimeout=5000
AlarmApp=
AlarmAppCmdLine=
EnableDataFiltering=0
MaxLimit=100
MinLimit=0
Group=
Name=
TrayTextColor=FF0000h
TrayIconType=0
OSDItemType=0
GraphColor=00FF00h
Formula=
[Source VID usage]
ShowInOSD=1
ShowInLCD=0
ShowInTray=0
AlarmThresholdMin=
AlarmThresholdMax=
AlarmFlags=0
AlarmTimeout=5000
AlarmApp=
AlarmAppCmdLine=
EnableDataFiltering=0
MaxLimit=100
MinLimit=0
Group=
Name=
TrayTextColor=FF0000h
TrayIconType=0
OSDItemType=0
GraphColor=00FF00h
Formula=
[Source BUS usage]
ShowInOSD=1
ShowInLCD=0
ShowInTray=0
AlarmThresholdMin=
AlarmThresholdMax=
AlarmFlags=0
AlarmTimeout=5000
AlarmApp=
AlarmAppCmdLine=
EnableDataFiltering=0
MaxLimit=100
MinLimit=0
Group=
Name=
TrayTextColor=FF0000h
TrayIconType=0
OSDItemType=0
GraphColor=00FF00h
Formula=
[Source Memory usage]
ShowInOSD=0
ShowInLCD=0
ShowInTray=0
AlarmThresholdMin=
AlarmThresholdMax=
AlarmFlags=0
AlarmTimeout=5000
AlarmApp=
AlarmAppCmdLine=
EnableDataFiltering=0
MaxLimit=8192
MinLimit=0
Group=GPU Mem
Name=
TrayTextColor=FF0000h
TrayIconType=0
OSDItemType=0
GraphColor=00FF00h
Formula=
[Source Core clock]
ShowInOSD=0
ShowInLCD=0
ShowInTray=0
AlarmThresholdMin=
AlarmThresholdMax=
AlarmFlags=0
AlarmTimeout=5000
AlarmApp=
AlarmAppCmdLine=
EnableDataFiltering=0
MaxLimit=2500
MinLimit=0
Group=\nGPU
Name=
TrayTextColor=FF0000h
TrayIconType=0
OSDItemType=0
GraphColor=00FF00h
Formula=
[Source Memory clock]
ShowInOSD=0
ShowInLCD=0
ShowInTray=0
AlarmThresholdMin=
AlarmThresholdMax=
AlarmFlags=0
AlarmTimeout=5000
AlarmApp=
AlarmAppCmdLine=
EnableDataFiltering=0
MaxLimit=10000
MinLimit=0
Group=\nGPU
Name=
TrayTextColor=FF0000h
TrayIconType=0
OSDItemType=0
GraphColor=00FF00h
Formula=
[Source Power]
ShowInOSD=0
ShowInLCD=0
ShowInTray=0
AlarmThresholdMin=
AlarmThresholdMax=
AlarmFlags=0
AlarmTimeout=5000
AlarmApp=
AlarmAppCmdLine=
EnableDataFiltering=0
MaxLimit=150
MinLimit=0
Group=GPU
Name=
TrayTextColor=FF0000h
TrayIconType=0
OSDItemType=0
GraphColor=00FF00h
Formula=
[Source GPU voltage]
ShowInOSD=1
ShowInLCD=0
ShowInTray=0
AlarmThresholdMin=
AlarmThresholdMax=
AlarmFlags=0
AlarmTimeout=5000
AlarmApp=
AlarmAppCmdLine=
EnableDataFiltering=0
MaxLimit=1.20
MinLimit=0.000
Group=\n\nGPU
Name=
TrayTextColor=FF0000h
TrayIconType=0
OSDItemType=0
GraphColor=00FF00h
Formula=
[Source Fan speed]
ShowInOSD=1
ShowInLCD=0
ShowInTray=0
AlarmThresholdMin=
AlarmThresholdMax=
AlarmFlags=0
AlarmTimeout=5000
AlarmApp=
AlarmAppCmdLine=
EnableDataFiltering=0
MaxLimit=100
MinLimit=0
Group=
Name=
TrayTextColor=FF0000h
TrayIconType=0
OSDItemType=0
GraphColor=00FF00h
Formula=
[Source Fan speed 2]
ShowInOSD=1
ShowInLCD=0
ShowInTray=0
AlarmThresholdMin=
AlarmThresholdMax=
AlarmFlags=0
AlarmTimeout=5000
AlarmApp=
AlarmAppCmdLine=
EnableDataFiltering=0
MaxLimit=100
MinLimit=0
Group=
Name=
TrayTextColor=FF0000h
TrayIconType=0
OSDItemType=0
GraphColor=00FF00h
Formula=
[Source Fan tachometer]
ShowInOSD=1
ShowInLCD=0
ShowInTray=0
AlarmThresholdMin=
AlarmThresholdMax=
AlarmFlags=0
AlarmTimeout=5000
AlarmApp=
AlarmAppCmdLine=
EnableDataFiltering=0
MaxLimit=10000
MinLimit=0
Group=
Name=
TrayTextColor=FF0000h
TrayIconType=0
OSDItemType=0
GraphColor=00FF00h
Formula=
[Source Fan tachometer 2]
ShowInOSD=1
ShowInLCD=0
ShowInTray=0
AlarmThresholdMin=
AlarmThresholdMax=
AlarmFlags=0
AlarmTimeout=5000
AlarmApp=
AlarmAppCmdLine=
EnableDataFiltering=0
MaxLimit=10000
MinLimit=0
Group=
Name=
TrayTextColor=FF0000h
TrayIconType=0
OSDItemType=0
GraphColor=00FF00h
Formula=
[Source Temp limit]
ShowInOSD=1
ShowInLCD=0
ShowInTray=0
AlarmThresholdMin=
AlarmThresholdMax=
AlarmFlags=0
AlarmTimeout=5000
AlarmApp=
AlarmAppCmdLine=
EnableDataFiltering=0
MaxLimit=1
MinLimit=0
Group=
Name=
TrayTextColor=FF0000h
TrayIconType=0
OSDItemType=0
GraphColor=00FF00h
Formula=
[Source Power limit]
ShowInOSD=1
ShowInLCD=0
ShowInTray=0
AlarmThresholdMin=
AlarmThresholdMax=
AlarmFlags=0
AlarmTimeout=5000
AlarmApp=
AlarmAppCmdLine=
EnableDataFiltering=0
MaxLimit=1
MinLimit=0
Group=
Name=
TrayTextColor=FF0000h
TrayIconType=0
OSDItemType=0
GraphColor=00FF00h
Formula=
[Source Voltage limit]
ShowInOSD=1
ShowInLCD=0
ShowInTray=0
AlarmThresholdMin=
AlarmThresholdMax=
AlarmFlags=0
AlarmTimeout=5000
AlarmApp=
AlarmAppCmdLine=
EnableDataFiltering=0
MaxLimit=1
MinLimit=0
Group=
Name=
TrayTextColor=FF0000h
TrayIconType=0
OSDItemType=0
GraphColor=00FF00h
Formula=
[Source No load limit]
ShowInOSD=1
ShowInLCD=0
ShowInTray=0
AlarmThresholdMin=
AlarmThresholdMax=
AlarmFlags=0
AlarmTimeout=5000
AlarmApp=
AlarmAppCmdLine=
EnableDataFiltering=0
MaxLimit=1
MinLimit=0
Group=
Name=
TrayTextColor=FF0000h
TrayIconType=0
OSDItemType=0
GraphColor=00FF00h
Formula=
[Source CPU1 temperature]
ShowInOSD=0
ShowInLCD=0
ShowInTray=0
AlarmThresholdMin=
AlarmThresholdMax=
AlarmFlags=0
AlarmTimeout=5000
AlarmApp=
AlarmAppCmdLine=
EnableDataFiltering=0
MaxLimit=100
MinLimit=0
Group=\nCPU 1
Name=
TrayTextColor=FF0000h
TrayIconType=0
OSDItemType=0
GraphColor=00FF00h
Formula=
[Source CPU2 temperature]
ShowInOSD=0
ShowInLCD=0
ShowInTray=0
AlarmThresholdMin=
AlarmThresholdMax=
AlarmFlags=0
AlarmTimeout=5000
AlarmApp=
AlarmAppCmdLine=
EnableDataFiltering=0
MaxLimit=100
MinLimit=0
Group=CPU 2
Name=
TrayTextColor=FF0000h
TrayIconType=0
OSDItemType=0
GraphColor=00FF00h
Formula=
[Source CPU3 temperature]
ShowInOSD=0
ShowInLCD=0
ShowInTray=0
AlarmThresholdMin=
AlarmThresholdMax=
AlarmFlags=0
AlarmTimeout=5000
AlarmApp=
AlarmAppCmdLine=
EnableDataFiltering=0
MaxLimit=100
MinLimit=0
Group=CPU 3
Name=
TrayTextColor=FF0000h
TrayIconType=0
OSDItemType=0
GraphColor=00FF00h
Formula=
[Source CPU4 temperature]
ShowInOSD=0
ShowInLCD=0
ShowInTray=0
AlarmThresholdMin=
AlarmThresholdMax=
AlarmFlags=0
AlarmTimeout=5000
AlarmApp=
AlarmAppCmdLine=
EnableDataFiltering=0
MaxLimit=100
MinLimit=0
Group=CPU 4
Name=
TrayTextColor=FF0000h
TrayIconType=0
OSDItemType=0
GraphColor=00FF00h
Formula=
[Source CPU5 temperature]
ShowInOSD=0
ShowInLCD=0
ShowInTray=0
AlarmThresholdMin=
AlarmThresholdMax=
AlarmFlags=0
AlarmTimeout=5000
AlarmApp=
AlarmAppCmdLine=
EnableDataFiltering=0
MaxLimit=100
MinLimit=0
Group=CPU 5
Name=
TrayTextColor=FF0000h
TrayIconType=0
OSDItemType=0
GraphColor=00FF00h
Formula=
[Source CPU6 temperature]
ShowInOSD=0
ShowInLCD=0
ShowInTray=0
AlarmThresholdMin=
AlarmThresholdMax=
AlarmFlags=0
AlarmTimeout=5000
AlarmApp=
AlarmAppCmdLine=
EnableDataFiltering=0
MaxLimit=100
MinLimit=0
Group=CPU 6
Name=
TrayTextColor=FF0000h
TrayIconType=0
OSDItemType=0
GraphColor=00FF00h
Formula=
[Source CPU temperature]
ShowInOSD=1
ShowInLCD=0
ShowInTray=0
AlarmThresholdMin=
AlarmThresholdMax=
AlarmFlags=0
AlarmTimeout=5000
AlarmApp=
AlarmAppCmdLine=
EnableDataFiltering=0
MaxLimit=100
MinLimit=0
Group=
Name=
TrayTextColor=FF0000h
TrayIconType=0
OSDItemType=0
GraphColor=00FF00h
Formula=
[Source CPU1 usage]
ShowInOSD=0
ShowInLCD=0
ShowInTray=0
AlarmThresholdMin=
AlarmThresholdMax=
AlarmFlags=0
AlarmTimeout=5000
AlarmApp=
AlarmAppCmdLine=
EnableDataFiltering=0
MaxLimit=100
MinLimit=0
Group=\nCPU 1
Name=
TrayTextColor=FF0000h
TrayIconType=0
OSDItemType=0
GraphColor=00FF00h
Formula=
[Source CPU2 usage]
ShowInOSD=0
ShowInLCD=0
ShowInTray=0
AlarmThresholdMin=
AlarmThresholdMax=
AlarmFlags=0
AlarmTimeout=5000
AlarmApp=
AlarmAppCmdLine=
EnableDataFiltering=0
MaxLimit=100
MinLimit=0
Group=CPU 2
Name=
TrayTextColor=FF0000h
TrayIconType=0
OSDItemType=0
GraphColor=00FF00h
Formula=
[Source CPU3 usage]
ShowInOSD=0
ShowInLCD=0
ShowInTray=0
AlarmThresholdMin=
AlarmThresholdMax=
AlarmFlags=0
AlarmTimeout=5000
AlarmApp=
AlarmAppCmdLine=
EnableDataFiltering=0
MaxLimit=100
MinLimit=0
Group=CPU 3
Name=
TrayTextColor=FF0000h
TrayIconType=0
OSDItemType=0
GraphColor=00FF00h
Formula=
[Source CPU4 usage]
ShowInOSD=0
ShowInLCD=0
ShowInTray=0
AlarmThresholdMin=
AlarmThresholdMax=
AlarmFlags=0
AlarmTimeout=5000
AlarmApp=
AlarmAppCmdLine=
EnableDataFiltering=0
MaxLimit=100
MinLimit=0
Group=CPU 4
Name=
TrayTextColor=FF0000h
TrayIconType=0
OSDItemType=0
GraphColor=00FF00h
Formula=
[Source CPU5 usage]
ShowInOSD=0
ShowInLCD=0
ShowInTray=0
AlarmThresholdMin=
AlarmThresholdMax=
AlarmFlags=0
AlarmTimeout=5000
AlarmApp=
AlarmAppCmdLine=
EnableDataFiltering=0
MaxLimit=100
MinLimit=0
Group=CPU 5
Name=
TrayTextColor=FF0000h
TrayIconType=0
OSDItemType=0
GraphColor=00FF00h
Formula=
[Source CPU6 usage]
ShowInOSD=0
ShowInLCD=0
ShowInTray=0
AlarmThresholdMin=
AlarmThresholdMax=
AlarmFlags=0
AlarmTimeout=5000
AlarmApp=
AlarmAppCmdLine=
EnableDataFiltering=0
MaxLimit=100
MinLimit=0
Group=CPU 6
Name=
TrayTextColor=FF0000h
TrayIconType=0
OSDItemType=0
GraphColor=00FF00h
Formula=
[Source CPU usage]
ShowInOSD=0
ShowInLCD=0
ShowInTray=0
AlarmThresholdMin=
AlarmThresholdMax=
AlarmFlags=0
AlarmTimeout=5000
AlarmApp=
AlarmAppCmdLine=
EnableDataFiltering=0
MaxLimit=100
MinLimit=0
Group=\nCPU
Name=
TrayTextColor=FF0000h
TrayIconType=0
OSDItemType=0
GraphColor=00FF00h
Formula=
[Source CPU1 clock]
ShowInOSD=0
ShowInLCD=0
ShowInTray=0
AlarmThresholdMin=
AlarmThresholdMax=
AlarmFlags=0
AlarmTimeout=5000
AlarmApp=
AlarmAppCmdLine=
EnableDataFiltering=0
MaxLimit=5000
MinLimit=0
Group=\nCPU 1
Name=
TrayTextColor=FF0000h
TrayIconType=0
OSDItemType=0
GraphColor=00FF00h
Formula=
[Source CPU2 clock]
ShowInOSD=0
ShowInLCD=0
ShowInTray=0
AlarmThresholdMin=
AlarmThresholdMax=
AlarmFlags=0
AlarmTimeout=5000
AlarmApp=
AlarmAppCmdLine=
EnableDataFiltering=0
MaxLimit=5000
MinLimit=0
Group=CPU 2
Name=
TrayTextColor=FF0000h
TrayIconType=0
OSDItemType=0
GraphColor=00FF00h
Formula=
[Source CPU3 clock]
ShowInOSD=0
ShowInLCD=0
ShowInTray=0
AlarmThresholdMin=
AlarmThresholdMax=
AlarmFlags=0
AlarmTimeout=5000
AlarmApp=
AlarmAppCmdLine=
EnableDataFiltering=0
MaxLimit=5000
MinLimit=0
Group=CPU 3
Name=
TrayTextColor=FF0000h
TrayIconType=0
OSDItemType=0
GraphColor=00FF00h
Formula=
[Source CPU4 clock]
ShowInOSD=0
ShowInLCD=0
ShowInTray=0
AlarmThresholdMin=
AlarmThresholdMax=
AlarmFlags=0
AlarmTimeout=5000
AlarmApp=
AlarmAppCmdLine=
EnableDataFiltering=0
MaxLimit=5000
MinLimit=0
Group=CPU 4
Name=
TrayTextColor=FF0000h
TrayIconType=0
OSDItemType=0
GraphColor=00FF00h
Formula=
[Source CPU5 clock]
ShowInOSD=0
ShowInLCD=0
ShowInTray=0
AlarmThresholdMin=
AlarmThresholdMax=
AlarmFlags=0
AlarmTimeout=5000
AlarmApp=
AlarmAppCmdLine=
EnableDataFiltering=0
MaxLimit=5000
MinLimit=0
Group=CPU 5
Name=
TrayTextColor=FF0000h
TrayIconType=0
OSDItemType=0
GraphColor=00FF00h
Formula=
[Source CPU6 clock]
ShowInOSD=0
ShowInLCD=0
ShowInTray=0
AlarmThresholdMin=
AlarmThresholdMax=
AlarmFlags=0
AlarmTimeout=5000
AlarmApp=
AlarmAppCmdLine=
EnableDataFiltering=0
MaxLimit=5000
MinLimit=0
Group=CPU 6
Name=
TrayTextColor=FF0000h
TrayIconType=0
OSDItemType=0
GraphColor=00FF00h
Formula=
[Source CPU clock]
ShowInOSD=1
ShowInLCD=0
ShowInTray=0
AlarmThresholdMin=
AlarmThresholdMax=
AlarmFlags=0
AlarmTimeout=5000
AlarmApp=
AlarmAppCmdLine=
EnableDataFiltering=0
MaxLimit=5201
MinLimit=0
Group=
Name=
TrayTextColor=FF0000h
TrayIconType=0
OSDItemType=0
GraphColor=00FF00h
Formula=
[Source CPU power]
ShowInOSD=0
ShowInLCD=0
ShowInTray=0
AlarmThresholdMin=
AlarmThresholdMax=
AlarmFlags=0
AlarmTimeout=5000
AlarmApp=
AlarmAppCmdLine=
EnableDataFiltering=0
MaxLimit=200.0
MinLimit=0.0
Group=\nCPU
Name=
TrayTextColor=FF0000h
TrayIconType=0
OSDItemType=0
GraphColor=00FF00h
Formula=
[Source RAM usage]
ShowInOSD=0
ShowInLCD=0
ShowInTray=0
AlarmThresholdMin=
AlarmThresholdMax=
AlarmFlags=0
AlarmTimeout=5000
AlarmApp=
AlarmAppCmdLine=
EnableDataFiltering=0
MaxLimit=16384
MinLimit=0
Group=CPU Mem
Name=
TrayTextColor=FF0000h
TrayIconType=0
OSDItemType=0
GraphColor=00FF00h
Formula=
[Source Commit charge]
ShowInOSD=1
ShowInLCD=0
ShowInTray=0
AlarmThresholdMin=
AlarmThresholdMax=
AlarmFlags=0
AlarmTimeout=5000
AlarmApp=
AlarmAppCmdLine=
EnableDataFiltering=0
MaxLimit=16384
MinLimit=0
Group=
Name=
TrayTextColor=FF0000h
TrayIconType=0
OSDItemType=0
GraphColor=00FF00h
Formula=
[Source Framerate]
ShowInOSD=0
ShowInLCD=0
ShowInTray=0
AlarmThresholdMin=
AlarmThresholdMax=
AlarmFlags=0
AlarmTimeout=5000
AlarmApp=
AlarmAppCmdLine=
EnableDataFiltering=0
MaxLimit=200
MinLimit=0
Group=\nFPS
Name=
TrayTextColor=FF0000h
TrayIconType=0
OSDItemType=0
GraphColor=00FF00h
Formula=
[Source Frametime]
ShowInOSD=1
ShowInLCD=0
ShowInTray=0
AlarmThresholdMin=
AlarmThresholdMax=
AlarmFlags=0
AlarmTimeout=5000
AlarmApp=
AlarmAppCmdLine=
EnableDataFiltering=0
MaxLimit=50.0
MinLimit=0.0
Group=
Name=
TrayTextColor=FF0000h
TrayIconType=0
OSDItemType=0
GraphColor=00FF00h
Formula=
[Source Framerate Min]
ShowInOSD=1
ShowInLCD=0
ShowInTray=0
AlarmThresholdMin=
AlarmThresholdMax=
AlarmFlags=0
AlarmTimeout=5000
AlarmApp=
AlarmAppCmdLine=
EnableDataFiltering=0
MaxLimit=200
MinLimit=0
Group=
Name=
TrayTextColor=FF0000h
TrayIconType=0
OSDItemType=0
GraphColor=00FF00h
Formula=
[Source Framerate Avg]
ShowInOSD=0
ShowInLCD=0
ShowInTray=0
AlarmThresholdMin=
AlarmThresholdMax=
AlarmFlags=0
AlarmTimeout=5000
AlarmApp=
AlarmAppCmdLine=
EnableDataFiltering=0
MaxLimit=200
MinLimit=0
Group=
Name=
TrayTextColor=FF0000h
TrayIconType=0
OSDItemType=0
GraphColor=00FF00h
Formula=
[Source Framerate 1% Low]
ShowInOSD=0
ShowInLCD=0
ShowInTray=0
AlarmThresholdMin=
AlarmThresholdMax=
AlarmFlags=0
AlarmTimeout=5000
AlarmApp=
AlarmAppCmdLine=
EnableDataFiltering=0
MaxLimit=200
MinLimit=0
Group=
Name=
TrayTextColor=FF0000h
TrayIconType=0
OSDItemType=0
GraphColor=00FF00h
Formula=
[Source Framerate 0.1% Low]
ShowInOSD=0
ShowInLCD=0
ShowInTray=0
AlarmThresholdMin=
AlarmThresholdMax=
AlarmFlags=0
AlarmTimeout=5000
AlarmApp=
AlarmAppCmdLine=
EnableDataFiltering=0
MaxLimit=200
MinLimit=0
Group=
Name=
TrayTextColor=FF0000h
TrayIconType=0
OSDItemType=0
GraphColor=00FF00h
Formula=
[OSDLayout1]
FormatHeader=<C0=008040><C1=0080C0><C2=C08080><C3=FF0000><C4=FFFFFF><C250=00AD00><A0=-4><A1=5><S0=-50><S1=50>
ValueAlignmentTag=<A0>;<A>:70,71,72,74,75;<A0>\r:50,51,52,53,54,55,56
UnitsAlignmentTag=<A1>
GroupColorTag=<C4>;<C4>:80,90,91,92,A0,F1,F2,F3,F4,F5,F6,F7,FF,100,50,51,52,53,54,55,56
ValueColorTag=<C250>:50,51,52,53,54,55,56
AlarmColorTag=<C3>
UnitsColorTag=<C250>:50,51,52,53,54,55,56
GraphColorTag=<C4>;<C4>:80,90,91,92,A0,F1,F2,F3,F4,F5,F6,F7,FF,100;<C2>:50,51,52,53,54,55,56
GroupSizeTag=
IndexSizeTag=<S0>
ValueSizeTag=<S1>:70,71,72,74,75
UnitsSizeTag=<S1>
GraphSizeTag=<S1>
PrologSeparator=""
Prolog0Separator=""
Prolog1Separator=""
Prolog2Separator=""
GroupDataSeparator=""
GroupNameSeparator="\t"
EpilogSeparator=""
GroupSeparator=
GraphSeparator=
GraphWidth=-32
GraphWidthEmbedded=-4
GraphHeight=-2
GraphMargin=1
GraphStyle=0
GraphLabel=3
GraphPlacement=2
[Source CPU7 temperature]
ShowInOSD=0
ShowInLCD=0
ShowInTray=0
AlarmThresholdMin=
AlarmThresholdMax=
AlarmFlags=0
AlarmTimeout=5000
AlarmApp=
AlarmAppCmdLine=
EnableDataFiltering=0
MaxLimit=100
MinLimit=0
Group=CPU 7
Name=
TrayTextColor=FF0000h
TrayIconType=0
OSDItemType=0
GraphColor=00FF00h
Formula=
[Source CPU8 temperature]
ShowInOSD=0
ShowInLCD=0
ShowInTray=0
AlarmThresholdMin=
AlarmThresholdMax=
AlarmFlags=0
AlarmTimeout=5000
AlarmApp=
AlarmAppCmdLine=
EnableDataFiltering=0
MaxLimit=100
MinLimit=0
Group=CPU 8
Name=
TrayTextColor=FF0000h
TrayIconType=0
OSDItemType=0
GraphColor=00FF00h
Formula=
[Source CPU9 temperature]
ShowInOSD=0
ShowInLCD=0
ShowInTray=0
AlarmThresholdMin=
AlarmThresholdMax=
AlarmFlags=0
AlarmTimeout=5000
AlarmApp=
AlarmAppCmdLine=
EnableDataFiltering=0
MaxLimit=100
MinLimit=0
Group=CPU 9
Name=
TrayTextColor=FF0000h
TrayIconType=0
OSDItemType=0
GraphColor=00FF00h
Formula=
[Source CPU10 temperature]
ShowInOSD=0
ShowInLCD=0
ShowInTray=0
AlarmThresholdMin=
AlarmThresholdMax=
AlarmFlags=0
AlarmTimeout=5000
AlarmApp=
AlarmAppCmdLine=
EnableDataFiltering=0
MaxLimit=100
MinLimit=0
Group=CPU 10
Name=
TrayTextColor=FF0000h
TrayIconType=0
OSDItemType=0
GraphColor=00FF00h
Formula=
[Source CPU11 temperature]
ShowInOSD=0
ShowInLCD=0
ShowInTray=0
AlarmThresholdMin=
AlarmThresholdMax=
AlarmFlags=0
AlarmTimeout=5000
AlarmApp=
AlarmAppCmdLine=
EnableDataFiltering=0
MaxLimit=100
MinLimit=0
Group=CPU 11
Name=
TrayTextColor=FF0000h
TrayIconType=0
OSDItemType=0
GraphColor=00FF00h
Formula=
[Source CPU12 temperature]
ShowInOSD=0
ShowInLCD=0
ShowInTray=0
AlarmThresholdMin=
AlarmThresholdMax=
AlarmFlags=0
AlarmTimeout=5000
AlarmApp=
AlarmAppCmdLine=
EnableDataFiltering=0
MaxLimit=100
MinLimit=0
Group=CPU 12
Name=
TrayTextColor=FF0000h
TrayIconType=0
OSDItemType=0
GraphColor=00FF00h
Formula=
[Source CPU7 usage]
ShowInOSD=0
ShowInLCD=0
ShowInTray=0
AlarmThresholdMin=
AlarmThresholdMax=
AlarmFlags=0
AlarmTimeout=5000
AlarmApp=
AlarmAppCmdLine=
EnableDataFiltering=0
MaxLimit=100
MinLimit=0
Group=CPU 7
Name=
TrayTextColor=FF0000h
TrayIconType=0
OSDItemType=0
GraphColor=00FF00h
Formula=
[Source CPU8 usage]
ShowInOSD=0
ShowInLCD=0
ShowInTray=0
AlarmThresholdMin=
AlarmThresholdMax=
AlarmFlags=0
AlarmTimeout=5000
AlarmApp=
AlarmAppCmdLine=
EnableDataFiltering=0
MaxLimit=100
MinLimit=0
Group=CPU 8
Name=
TrayTextColor=FF0000h
TrayIconType=0
OSDItemType=0
GraphColor=00FF00h
Formula=
[Source CPU9 usage]
ShowInOSD=0
ShowInLCD=0
ShowInTray=0
AlarmThresholdMin=
AlarmThresholdMax=
AlarmFlags=0
AlarmTimeout=5000
AlarmApp=
AlarmAppCmdLine=
EnableDataFiltering=0
MaxLimit=100
MinLimit=0
Group=CPU 9
Name=
TrayTextColor=FF0000h
TrayIconType=0
OSDItemType=0
GraphColor=00FF00h
Formula=
[Source CPU10 usage]
ShowInOSD=0
ShowInLCD=0
ShowInTray=0
AlarmThresholdMin=
AlarmThresholdMax=
AlarmFlags=0
AlarmTimeout=5000
AlarmApp=
AlarmAppCmdLine=
EnableDataFiltering=0
MaxLimit=100
MinLimit=0
Group=CPU 10
Name=
TrayTextColor=FF0000h
TrayIconType=0
OSDItemType=0
GraphColor=00FF00h
Formula=
[Source CPU11 usage]
ShowInOSD=0
ShowInLCD=0
ShowInTray=0
AlarmThresholdMin=
AlarmThresholdMax=
AlarmFlags=0
AlarmTimeout=5000
AlarmApp=
AlarmAppCmdLine=
EnableDataFiltering=0
MaxLimit=100
MinLimit=0
Group=CPU 11
Name=
TrayTextColor=FF0000h
TrayIconType=0
OSDItemType=0
GraphColor=00FF00h
Formula=
[Source CPU12 usage]
ShowInOSD=0
ShowInLCD=0
ShowInTray=0
AlarmThresholdMin=
AlarmThresholdMax=
AlarmFlags=0
AlarmTimeout=5000
AlarmApp=
AlarmAppCmdLine=
EnableDataFiltering=0
MaxLimit=100
MinLimit=0
Group=CPU 12
Name=
TrayTextColor=FF0000h
TrayIconType=0
OSDItemType=0
GraphColor=00FF00h
Formula=
[Source CPU7 clock]
ShowInOSD=0
ShowInLCD=0
ShowInTray=0
AlarmThresholdMin=
AlarmThresholdMax=
AlarmFlags=0
AlarmTimeout=5000
AlarmApp=
AlarmAppCmdLine=
EnableDataFiltering=0
MaxLimit=5000
MinLimit=0
Group=CPU 7
Name=
TrayTextColor=FF0000h
TrayIconType=0
OSDItemType=0
GraphColor=00FF00h
Formula=
[Source CPU8 clock]
ShowInOSD=0
ShowInLCD=0
ShowInTray=0
AlarmThresholdMin=
AlarmThresholdMax=
AlarmFlags=0
AlarmTimeout=5000
AlarmApp=
AlarmAppCmdLine=
EnableDataFiltering=0
MaxLimit=5000
MinLimit=0
Group=CPU 8
Name=
TrayTextColor=FF0000h
TrayIconType=0
OSDItemType=0
GraphColor=00FF00h
Formula=
[Source CPU9 clock]
ShowInOSD=0
ShowInLCD=0
ShowInTray=0
AlarmThresholdMin=
AlarmThresholdMax=
AlarmFlags=0
AlarmTimeout=5000
AlarmApp=
AlarmAppCmdLine=
EnableDataFiltering=0
MaxLimit=5000
MinLimit=0
Group=CPU 9
Name=
TrayTextColor=FF0000h
TrayIconType=0
OSDItemType=0
GraphColor=00FF00h
Formula=
[Source CPU10 clock]
ShowInOSD=0
ShowInLCD=0
ShowInTray=0
AlarmThresholdMin=
AlarmThresholdMax=
AlarmFlags=0
AlarmTimeout=5000
AlarmApp=
AlarmAppCmdLine=
EnableDataFiltering=0
MaxLimit=5000
MinLimit=0
Group=CPU 10
Name=
TrayTextColor=FF0000h
TrayIconType=0
OSDItemType=0
GraphColor=00FF00h
Formula=
[Source CPU11 clock]
ShowInOSD=0
ShowInLCD=0
ShowInTray=0
AlarmThresholdMin=
AlarmThresholdMax=
AlarmFlags=0
AlarmTimeout=5000
AlarmApp=
AlarmAppCmdLine=
EnableDataFiltering=0
MaxLimit=5000
MinLimit=0
Group=CPU 11
Name=
TrayTextColor=FF0000h
TrayIconType=0
OSDItemType=0
GraphColor=00FF00h
Formula=
[Source CPU12 clock]
ShowInOSD=0
ShowInLCD=0
ShowInTray=0
AlarmThresholdMin=
AlarmThresholdMax=
AlarmFlags=0
AlarmTimeout=5000
AlarmApp=
AlarmAppCmdLine=
EnableDataFiltering=0
MaxLimit=5000
MinLimit=0
Group=CPU 12
Name=
TrayTextColor=FF0000h
TrayIconType=0
OSDItemType=0
GraphColor=00FF00h
Formula=
[Source CPU13 temperature]
ShowInOSD=0
ShowInLCD=0
ShowInTray=0
AlarmThresholdMin=
AlarmThresholdMax=
AlarmFlags=0
AlarmTimeout=5000
AlarmApp=
AlarmAppCmdLine=
EnableDataFiltering=0
MaxLimit=100
MinLimit=0
Group=CPU 13
Name=
TrayTextColor=FF0000h
TrayIconType=0
OSDItemType=0
GraphColor=00FF00h
Formula=
[Source CPU14 temperature]
ShowInOSD=0
ShowInLCD=0
ShowInTray=0
AlarmThresholdMin=
AlarmThresholdMax=
AlarmFlags=0
AlarmTimeout=5000
AlarmApp=
AlarmAppCmdLine=
EnableDataFiltering=0
MaxLimit=100
MinLimit=0
Group=CPU 14
Name=
TrayTextColor=FF0000h
TrayIconType=0
OSDItemType=0
GraphColor=00FF00h
Formula=
[Source CPU15 temperature]
ShowInOSD=0
ShowInLCD=0
ShowInTray=0
AlarmThresholdMin=
AlarmThresholdMax=
AlarmFlags=0
AlarmTimeout=5000
AlarmApp=
AlarmAppCmdLine=
EnableDataFiltering=0
MaxLimit=100
MinLimit=0
Group=CPU 15
Name=
TrayTextColor=FF0000h
TrayIconType=0
OSDItemType=0
GraphColor=00FF00h
Formula=
[Source CPU16 temperature]
ShowInOSD=0
ShowInLCD=0
ShowInTray=0
AlarmThresholdMin=
AlarmThresholdMax=
AlarmFlags=0
AlarmTimeout=5000
AlarmApp=
AlarmAppCmdLine=
EnableDataFiltering=0
MaxLimit=100
MinLimit=0
Group=CPU 16
Name=
TrayTextColor=FF0000h
TrayIconType=0
OSDItemType=0
GraphColor=00FF00h
Formula=
[Source CPU17 temperature]
ShowInOSD=1
ShowInLCD=0
ShowInTray=0
AlarmThresholdMin=
AlarmThresholdMax=
AlarmFlags=0
AlarmTimeout=5000
AlarmApp=
AlarmAppCmdLine=
EnableDataFiltering=0
MaxLimit=100
MinLimit=0
Group=CPU 17
Name=
TrayTextColor=FF0000h
TrayIconType=0
OSDItemType=0
GraphColor=00FF00h
Formula=
[Source CPU18 temperature]
ShowInOSD=1
ShowInLCD=0
ShowInTray=0
AlarmThresholdMin=
AlarmThresholdMax=
AlarmFlags=0
AlarmTimeout=5000
AlarmApp=
AlarmAppCmdLine=
EnableDataFiltering=0
MaxLimit=100
MinLimit=0
Group=CPU 18
Name=
TrayTextColor=FF0000h
TrayIconType=0
OSDItemType=0
GraphColor=00FF00h
Formula=
[Source CPU19 temperature]
ShowInOSD=1
ShowInLCD=0
ShowInTray=0
AlarmThresholdMin=
AlarmThresholdMax=
AlarmFlags=0
AlarmTimeout=5000
AlarmApp=
AlarmAppCmdLine=
EnableDataFiltering=0
MaxLimit=100
MinLimit=0
Group=CPU 19
Name=
TrayTextColor=FF0000h
TrayIconType=0
OSDItemType=0
GraphColor=00FF00h
Formula=
[Source CPU20 temperature]
ShowInOSD=1
ShowInLCD=0
ShowInTray=0
AlarmThresholdMin=
AlarmThresholdMax=
AlarmFlags=0
AlarmTimeout=5000
AlarmApp=
AlarmAppCmdLine=
EnableDataFiltering=0
MaxLimit=100
MinLimit=0
Group=CPU 20
Name=
TrayTextColor=FF0000h
TrayIconType=0
OSDItemType=0
GraphColor=00FF00h
Formula=
[Source CPU21 temperature]
ShowInOSD=1
ShowInLCD=0
ShowInTray=0
AlarmThresholdMin=
AlarmThresholdMax=
AlarmFlags=0
AlarmTimeout=5000
AlarmApp=
AlarmAppCmdLine=
EnableDataFiltering=0
MaxLimit=100
MinLimit=0
Group=CPU 21
Name=
TrayTextColor=FF0000h
TrayIconType=0
OSDItemType=0
GraphColor=00FF00h
Formula=
[Source CPU22 temperature]
ShowInOSD=1
ShowInLCD=0
ShowInTray=0
AlarmThresholdMin=
AlarmThresholdMax=
AlarmFlags=0
AlarmTimeout=5000
AlarmApp=
AlarmAppCmdLine=
EnableDataFiltering=0
MaxLimit=100
MinLimit=0
Group=CPU 22
Name=
TrayTextColor=FF0000h
TrayIconType=0
OSDItemType=0
GraphColor=00FF00h
Formula=
[Source CPU23 temperature]
ShowInOSD=1
ShowInLCD=0
ShowInTray=0
AlarmThresholdMin=
AlarmThresholdMax=
AlarmFlags=0
AlarmTimeout=5000
AlarmApp=
AlarmAppCmdLine=
EnableDataFiltering=0
MaxLimit=100
MinLimit=0
Group=CPU 23
Name=
TrayTextColor=FF0000h
TrayIconType=0
OSDItemType=0
GraphColor=00FF00h
Formula=
[Source CPU24 temperature]
ShowInOSD=1
ShowInLCD=0
ShowInTray=0
AlarmThresholdMin=
AlarmThresholdMax=
AlarmFlags=0
AlarmTimeout=5000
AlarmApp=
AlarmAppCmdLine=
EnableDataFiltering=0
MaxLimit=100
MinLimit=0
Group=CPU 24
Name=
TrayTextColor=FF0000h
TrayIconType=0
OSDItemType=0
GraphColor=00FF00h
Formula=
[Source CPU13 usage]
ShowInOSD=0
ShowInLCD=0
ShowInTray=0
AlarmThresholdMin=
AlarmThresholdMax=
AlarmFlags=0
AlarmTimeout=5000
AlarmApp=
AlarmAppCmdLine=
EnableDataFiltering=0
MaxLimit=100
MinLimit=0
Group=CPU 13
Name=
TrayTextColor=FF0000h
TrayIconType=0
OSDItemType=0
GraphColor=00FF00h
Formula=
[Source CPU14 usage]
ShowInOSD=0
ShowInLCD=0
ShowInTray=0
AlarmThresholdMin=
AlarmThresholdMax=
AlarmFlags=0
AlarmTimeout=5000
AlarmApp=
AlarmAppCmdLine=
EnableDataFiltering=0
MaxLimit=100
MinLimit=0
Group=CPU 14
Name=
TrayTextColor=FF0000h
TrayIconType=0
OSDItemType=0
GraphColor=00FF00h
Formula=
[Source CPU15 usage]
ShowInOSD=0
ShowInLCD=0
ShowInTray=0
AlarmThresholdMin=
AlarmThresholdMax=
AlarmFlags=0
AlarmTimeout=5000
AlarmApp=
AlarmAppCmdLine=
EnableDataFiltering=0
MaxLimit=100
MinLimit=0
Group=CPU 15
Name=
TrayTextColor=FF0000h
TrayIconType=0
OSDItemType=0
GraphColor=00FF00h
Formula=
[Source CPU16 usage]
ShowInOSD=0
ShowInLCD=0
ShowInTray=0
AlarmThresholdMin=
AlarmThresholdMax=
AlarmFlags=0
AlarmTimeout=5000
AlarmApp=
AlarmAppCmdLine=
EnableDataFiltering=0
MaxLimit=100
MinLimit=0
Group=CPU 16
Name=
TrayTextColor=FF0000h
TrayIconType=0
OSDItemType=0
GraphColor=00FF00h
Formula=
[Source CPU17 usage]
ShowInOSD=1
ShowInLCD=0
ShowInTray=0
AlarmThresholdMin=
AlarmThresholdMax=
AlarmFlags=0
AlarmTimeout=5000
AlarmApp=
AlarmAppCmdLine=
EnableDataFiltering=0
MaxLimit=100
MinLimit=0
Group=CPU 17
Name=
TrayTextColor=FF0000h
TrayIconType=0
OSDItemType=0
GraphColor=00FF00h
Formula=
[Source CPU18 usage]
ShowInOSD=1
ShowInLCD=0
ShowInTray=0
AlarmThresholdMin=
AlarmThresholdMax=
AlarmFlags=0
AlarmTimeout=5000
AlarmApp=
AlarmAppCmdLine=
EnableDataFiltering=0
MaxLimit=100
MinLimit=0
Group=CPU 18
Name=
TrayTextColor=FF0000h
TrayIconType=0
OSDItemType=0
GraphColor=00FF00h
Formula=
[Source CPU19 usage]
ShowInOSD=1
ShowInLCD=0
ShowInTray=0
AlarmThresholdMin=
AlarmThresholdMax=
AlarmFlags=0
AlarmTimeout=5000
AlarmApp=
AlarmAppCmdLine=
EnableDataFiltering=0
MaxLimit=100
MinLimit=0
Group=CPU 19
Name=
TrayTextColor=FF0000h
TrayIconType=0
OSDItemType=0
GraphColor=00FF00h
Formula=
[Source CPU20 usage]
ShowInOSD=1
ShowInLCD=0
ShowInTray=0
AlarmThresholdMin=
AlarmThresholdMax=
AlarmFlags=0
AlarmTimeout=5000
AlarmApp=
AlarmAppCmdLine=
EnableDataFiltering=0
MaxLimit=100
MinLimit=0
Group=CPU 20
Name=
TrayTextColor=FF0000h
TrayIconType=0
OSDItemType=0
GraphColor=00FF00h
Formula=
[Source CPU21 usage]
ShowInOSD=1
ShowInLCD=0
ShowInTray=0
AlarmThresholdMin=
AlarmThresholdMax=
AlarmFlags=0
AlarmTimeout=5000
AlarmApp=
AlarmAppCmdLine=
EnableDataFiltering=0
MaxLimit=100
MinLimit=0
Group=CPU 21
Name=
TrayTextColor=FF0000h
TrayIconType=0
OSDItemType=0
GraphColor=00FF00h
Formula=
[Source CPU22 usage]
ShowInOSD=1
ShowInLCD=0
ShowInTray=0
AlarmThresholdMin=
AlarmThresholdMax=
AlarmFlags=0
AlarmTimeout=5000
AlarmApp=
AlarmAppCmdLine=
EnableDataFiltering=0
MaxLimit=100
MinLimit=0
Group=CPU 22
Name=
TrayTextColor=FF0000h
TrayIconType=0
OSDItemType=0
GraphColor=00FF00h
Formula=
[Source CPU23 usage]
ShowInOSD=1
ShowInLCD=0
ShowInTray=0
AlarmThresholdMin=
AlarmThresholdMax=
AlarmFlags=0
AlarmTimeout=5000
AlarmApp=
AlarmAppCmdLine=
EnableDataFiltering=0
MaxLimit=100
MinLimit=0
Group=CPU 23
Name=
TrayTextColor=FF0000h
TrayIconType=0
OSDItemType=0
GraphColor=00FF00h
Formula=
[Source CPU24 usage]
ShowInOSD=1
ShowInLCD=0
ShowInTray=0
AlarmThresholdMin=
AlarmThresholdMax=
AlarmFlags=0
AlarmTimeout=5000
AlarmApp=
AlarmAppCmdLine=
EnableDataFiltering=0
MaxLimit=100
MinLimit=0
Group=CPU 24
Name=
TrayTextColor=FF0000h
TrayIconType=0
OSDItemType=0
GraphColor=00FF00h
Formula=
[Source CPU13 clock]
ShowInOSD=0
ShowInLCD=0
ShowInTray=0
AlarmThresholdMin=
AlarmThresholdMax=
AlarmFlags=0
AlarmTimeout=5000
AlarmApp=
AlarmAppCmdLine=
EnableDataFiltering=0
MaxLimit=5000
MinLimit=0
Group=CPU 13
Name=
TrayTextColor=FF0000h
TrayIconType=0
OSDItemType=0
GraphColor=00FF00h
Formula=
[Source CPU14 clock]
ShowInOSD=0
ShowInLCD=0
ShowInTray=0
AlarmThresholdMin=
AlarmThresholdMax=
AlarmFlags=0
AlarmTimeout=5000
AlarmApp=
AlarmAppCmdLine=
EnableDataFiltering=0
MaxLimit=5000
MinLimit=0
Group=CPU 14
Name=
TrayTextColor=FF0000h
TrayIconType=0
OSDItemType=0
GraphColor=00FF00h
Formula=
[Source CPU15 clock]
ShowInOSD=0
ShowInLCD=0
ShowInTray=0
AlarmThresholdMin=
AlarmThresholdMax=
AlarmFlags=0
AlarmTimeout=5000
AlarmApp=
AlarmAppCmdLine=
EnableDataFiltering=0
MaxLimit=5000
MinLimit=0
Group=CPU 15
Name=
TrayTextColor=FF0000h
TrayIconType=0
OSDItemType=0
GraphColor=00FF00h
Formula=
[Source CPU16 clock]
ShowInOSD=0
ShowInLCD=0
ShowInTray=0
AlarmThresholdMin=
AlarmThresholdMax=
AlarmFlags=0
AlarmTimeout=5000
AlarmApp=
AlarmAppCmdLine=
EnableDataFiltering=0
MaxLimit=5000
MinLimit=0
Group=CPU 16
Name=
TrayTextColor=FF0000h
TrayIconType=0
OSDItemType=0
GraphColor=00FF00h
Formula=
[Source CPU17 clock]
ShowInOSD=1
ShowInLCD=0
ShowInTray=0
AlarmThresholdMin=
AlarmThresholdMax=
AlarmFlags=0
AlarmTimeout=5000
AlarmApp=
AlarmAppCmdLine=
EnableDataFiltering=0
MaxLimit=5000
MinLimit=0
Group=CPU 17
Name=
TrayTextColor=FF0000h
TrayIconType=0
OSDItemType=0
GraphColor=00FF00h
Formula=
[Source CPU18 clock]
ShowInOSD=1
ShowInLCD=0
ShowInTray=0
AlarmThresholdMin=
AlarmThresholdMax=
AlarmFlags=0
AlarmTimeout=5000
AlarmApp=
AlarmAppCmdLine=
EnableDataFiltering=0
MaxLimit=5000
MinLimit=0
Group=CPU 18
Name=
TrayTextColor=FF0000h
TrayIconType=0
OSDItemType=0
GraphColor=00FF00h
Formula=
[Source CPU19 clock]
ShowInOSD=1
ShowInLCD=0
ShowInTray=0
AlarmThresholdMin=
AlarmThresholdMax=
AlarmFlags=0
AlarmTimeout=5000
AlarmApp=
AlarmAppCmdLine=
EnableDataFiltering=0
MaxLimit=5000
MinLimit=0
Group=CPU 19
Name=
TrayTextColor=FF0000h
TrayIconType=0
OSDItemType=0
GraphColor=00FF00h
Formula=
[Source CPU20 clock]
ShowInOSD=1
ShowInLCD=0
ShowInTray=0
AlarmThresholdMin=
AlarmThresholdMax=
AlarmFlags=0
AlarmTimeout=5000
AlarmApp=
AlarmAppCmdLine=
EnableDataFiltering=0
MaxLimit=5000
MinLimit=0
Group=CPU 20
Name=
TrayTextColor=FF0000h
TrayIconType=0
OSDItemType=0
GraphColor=00FF00h
Formula=
[Source CPU21 clock]
ShowInOSD=1
ShowInLCD=0
ShowInTray=0
AlarmThresholdMin=
AlarmThresholdMax=
AlarmFlags=0
AlarmTimeout=5000
AlarmApp=
AlarmAppCmdLine=
EnableDataFiltering=0
MaxLimit=5000
MinLimit=0
Group=CPU 21
Name=
TrayTextColor=FF0000h
TrayIconType=0
OSDItemType=0
GraphColor=00FF00h
Formula=
[Source CPU22 clock]
ShowInOSD=1
ShowInLCD=0
ShowInTray=0
AlarmThresholdMin=
AlarmThresholdMax=
AlarmFlags=0
AlarmTimeout=5000
AlarmApp=
AlarmAppCmdLine=
EnableDataFiltering=0
MaxLimit=5000
MinLimit=0
Group=CPU 22
Name=
TrayTextColor=FF0000h
TrayIconType=0
OSDItemType=0
GraphColor=00FF00h
Formula=
[Source CPU23 clock]
ShowInOSD=1
ShowInLCD=0
ShowInTray=0
AlarmThresholdMin=
AlarmThresholdMax=
AlarmFlags=0
AlarmTimeout=5000
AlarmApp=
AlarmAppCmdLine=
EnableDataFiltering=0
MaxLimit=5000
MinLimit=0
Group=CPU 23
Name=
TrayTextColor=FF0000h
TrayIconType=0
OSDItemType=0
GraphColor=00FF00h
Formula=
[Source CPU24 clock]
ShowInOSD=1
ShowInLCD=0
ShowInTray=0
AlarmThresholdMin=
AlarmThresholdMax=
AlarmFlags=0
AlarmTimeout=5000
AlarmApp=
AlarmAppCmdLine=
EnableDataFiltering=0
MaxLimit=5000
MinLimit=0
Group=CPU 24
Name=
TrayTextColor=FF0000h
TrayIconType=0
OSDItemType=0
GraphColor=00FF00h
Formula=
[Source Power percent]
ShowInOSD=0
ShowInLCD=0
ShowInTray=0
AlarmThresholdMin=
AlarmThresholdMax=
AlarmFlags=0
AlarmTimeout=5000
AlarmApp=
AlarmAppCmdLine=
EnableDataFiltering=0
MaxLimit=150
MinLimit=0
Group=
Name=
TrayTextColor=FF0000h
TrayIconType=0
OSDItemType=0
GraphColor=00FF00h
Formula=
[Source CPU24 power]
ShowInOSD=0
ShowInLCD=0
ShowInTray=0
AlarmThresholdMin=
AlarmThresholdMax=
AlarmFlags=0
AlarmTimeout=5000
AlarmApp=
AlarmAppCmdLine=
EnableDataFiltering=0
MaxLimit=200.0
MinLimit=0.0
Group=
Name=
TrayTextColor=FF0000h
TrayIconType=0
OSDItemType=0
GraphColor=00FF00h
Formula=
[OSDLayout0]
FormatHeader=
ValueAlignmentTag=
UnitsAlignmentTag=
GroupColorTag=
ValueColorTag=
AlarmColorTag=
UnitsColorTag=
GraphColorTag=
GroupSizeTag=
IndexSizeTag=
ValueSizeTag=
UnitsSizeTag=
GraphSizeTag=
PrologSeparator=""
Prolog0Separator=""
Prolog1Separator=""
Prolog2Separator=""
GroupDataSeparator=", "
GroupNameSeparator=" \t: "
EpilogSeparator=""
GroupSeparator=
GraphSeparator=
GraphWidth=-32
GraphWidthEmbedded=-4
GraphHeight=-2
GraphMargin=1
GraphStyle=0
GraphLabel=3
GraphPlacement=2
[OSDLayout3]
FormatHeader=<C0=008040><C1=0080C0><C2=C08080><C3=FF0000><C4=FFFFFF><C5=80000000><C6=80FFFFFF><C250=FF8000><A0=-4><A1=5><S0=-50><S1=50><S2=200>
ValueAlignmentTag=<A0>;<A>:70,71,72,74,75;<A0>\r:50,51,52,53,54,55,56
UnitsAlignmentTag=<A1>
GroupColorTag=<C0>;<C1>:80,90,91,92,A0,F1,F2,F3,F4,F5,F6,F7,FF,100;<C2>:50,51,52,53,54,55,56
ValueColorTag=<C4>:50,51,52,53,54,55,56
AlarmColorTag=<C3>
UnitsColorTag=<C4>:50,51,52,53,54,55,56
GraphColorTag=<C0>;<C1>:80,90,91,92,A0,F1,F2,F3,F4,F5,F6,F7,FF,100;<C2>:50,51,52,53,54,55,56
GroupSizeTag=
IndexSizeTag=<S0>
ValueSizeTag=<S1>:70,71,72,74,75
UnitsSizeTag=<S1>
GraphSizeTag=<S1>
PrologSeparator="<C5><B=0,0>\b<C6><B=0,-1>\b<A=25>www.Guru3D.com<A=-25><BTIME>    %Time%<A><C>\n\n<C4><S2><FR><S><C>\n"
Prolog0Separator="\n"
Prolog1Separator="\n"
Prolog2Separator="\n"
GroupDataSeparator=" "
GroupNameSeparator="\t "
EpilogSeparator="\n<C6><B=0,-1>\b%CPU% | %RAM% | %GPU% | %Driver%<C>"
GroupSeparator=\n:90,80,A0,50,51
GraphSeparator=
GraphWidth=-45
GraphWidthEmbedded=-4
GraphHeight=-2
GraphMargin=1
GraphStyle=0;2:30,90,52,53,54,55,56
GraphLabel=3
GraphPlacement=2;1:30,90;0:50,51,52,53,54,55,56
[Source CPU32 temperature]
ShowInOSD=1
ShowInLCD=0
ShowInTray=0
AlarmThresholdMin=
AlarmThresholdMax=
AlarmFlags=0
AlarmTimeout=5000
AlarmApp=
AlarmAppCmdLine=
EnableDataFiltering=0
MaxLimit=100
MinLimit=0
Group=CPU 32
Name=
TrayTextColor=FF0000h
TrayIconType=0
OSDItemType=0
GraphColor=00FF00h
Formula=
[Source CPU32 usage]
ShowInOSD=1
ShowInLCD=0
ShowInTray=0
AlarmThresholdMin=
AlarmThresholdMax=
AlarmFlags=0
AlarmTimeout=5000
AlarmApp=
AlarmAppCmdLine=
EnableDataFiltering=0
MaxLimit=100
MinLimit=0
Group=CPU 32
Name=
TrayTextColor=FF0000h
TrayIconType=0
OSDItemType=0
GraphColor=00FF00h
Formula=
[Source CPU32 clock]
ShowInOSD=1
ShowInLCD=0
ShowInTray=0
AlarmThresholdMin=
AlarmThresholdMax=
AlarmFlags=0
AlarmTimeout=5000
AlarmApp=
AlarmAppCmdLine=
EnableDataFiltering=0
MaxLimit=5000
MinLimit=0
Group=CPU 32
Name=
TrayTextColor=FF0000h
TrayIconType=0
OSDItemType=0
GraphColor=00FF00h
Formula=
[Source CPU25 clock]
ShowInOSD=1
ShowInLCD=0
ShowInTray=0
AlarmThresholdMin=
AlarmThresholdMax=
AlarmFlags=0
AlarmTimeout=5000
AlarmApp=
AlarmAppCmdLine=
EnableDataFiltering=0
MaxLimit=5000
MinLimit=0
Group=CPU 25
Name=
TrayTextColor=FF0000h
TrayIconType=0
OSDItemType=0
GraphColor=00FF00h
Formula=
[Source CPU26 clock]
ShowInOSD=1
ShowInLCD=0
ShowInTray=0
AlarmThresholdMin=
AlarmThresholdMax=
AlarmFlags=0
AlarmTimeout=5000
AlarmApp=
AlarmAppCmdLine=
EnableDataFiltering=0
MaxLimit=5000
MinLimit=0
Group=CPU 26
Name=
TrayTextColor=FF0000h
TrayIconType=0
OSDItemType=0
GraphColor=00FF00h
Formula=
[Source CPU27 clock]
ShowInOSD=1
ShowInLCD=0
ShowInTray=0
AlarmThresholdMin=
AlarmThresholdMax=
AlarmFlags=0
AlarmTimeout=5000
AlarmApp=
AlarmAppCmdLine=
EnableDataFiltering=0
MaxLimit=5000
MinLimit=0
Group=CPU 27
Name=
TrayTextColor=FF0000h
TrayIconType=0
OSDItemType=0
GraphColor=00FF00h
Formula=
[Source CPU28 clock]
ShowInOSD=1
ShowInLCD=0
ShowInTray=0
AlarmThresholdMin=
AlarmThresholdMax=
AlarmFlags=0
AlarmTimeout=5000
AlarmApp=
AlarmAppCmdLine=
EnableDataFiltering=0
MaxLimit=5000
MinLimit=0
Group=CPU 28
Name=
TrayTextColor=FF0000h
TrayIconType=0
OSDItemType=0
GraphColor=00FF00h
Formula=
[Source CPU29 clock]
ShowInOSD=1
ShowInLCD=0
ShowInTray=0
AlarmThresholdMin=
AlarmThresholdMax=
AlarmFlags=0
AlarmTimeout=5000
AlarmApp=
AlarmAppCmdLine=
EnableDataFiltering=0
MaxLimit=5000
MinLimit=0
Group=CPU 29
Name=
TrayTextColor=FF0000h
TrayIconType=0
OSDItemType=0
GraphColor=00FF00h
Formula=
[Source CPU30 clock]
ShowInOSD=1
ShowInLCD=0
ShowInTray=0
AlarmThresholdMin=
AlarmThresholdMax=
AlarmFlags=0
AlarmTimeout=5000
AlarmApp=
AlarmAppCmdLine=
EnableDataFiltering=0
MaxLimit=5000
MinLimit=0
Group=CPU 30
Name=
TrayTextColor=FF0000h
TrayIconType=0
OSDItemType=0
GraphColor=00FF00h
Formula=
[Source CPU31 clock]
ShowInOSD=1
ShowInLCD=0
ShowInTray=0
AlarmThresholdMin=
AlarmThresholdMax=
AlarmFlags=0
AlarmTimeout=5000
AlarmApp=
AlarmAppCmdLine=
EnableDataFiltering=0
MaxLimit=5000
MinLimit=0
Group=CPU 31
Name=
TrayTextColor=FF0000h
TrayIconType=0
OSDItemType=0
GraphColor=00FF00h
Formula=
[Source CPU25 temperature]
ShowInOSD=1
ShowInLCD=0
ShowInTray=0
AlarmThresholdMin=
AlarmThresholdMax=
AlarmFlags=0
AlarmTimeout=5000
AlarmApp=
AlarmAppCmdLine=
EnableDataFiltering=0
MaxLimit=100
MinLimit=0
Group=CPU 25
Name=
TrayTextColor=FF0000h
TrayIconType=0
OSDItemType=0
GraphColor=00FF00h
Formula=
[Source CPU26 temperature]
ShowInOSD=1
ShowInLCD=0
ShowInTray=0
AlarmThresholdMin=
AlarmThresholdMax=
AlarmFlags=0
AlarmTimeout=5000
AlarmApp=
AlarmAppCmdLine=
EnableDataFiltering=0
MaxLimit=100
MinLimit=0
Group=CPU 26
Name=
TrayTextColor=FF0000h
TrayIconType=0
OSDItemType=0
GraphColor=00FF00h
Formula=
[Source CPU27 temperature]
ShowInOSD=1
ShowInLCD=0
ShowInTray=0
AlarmThresholdMin=
AlarmThresholdMax=
AlarmFlags=0
AlarmTimeout=5000
AlarmApp=
AlarmAppCmdLine=
EnableDataFiltering=0
MaxLimit=100
MinLimit=0
Group=CPU 27
Name=
TrayTextColor=FF0000h
TrayIconType=0
OSDItemType=0
GraphColor=00FF00h
Formula=
[Source CPU28 temperature]
ShowInOSD=1
ShowInLCD=0
ShowInTray=0
AlarmThresholdMin=
AlarmThresholdMax=
AlarmFlags=0
AlarmTimeout=5000
AlarmApp=
AlarmAppCmdLine=
EnableDataFiltering=0
MaxLimit=100
MinLimit=0
Group=CPU 28
Name=
TrayTextColor=FF0000h
TrayIconType=0
OSDItemType=0
GraphColor=00FF00h
Formula=
[Source CPU29 temperature]
ShowInOSD=1
ShowInLCD=0
ShowInTray=0
AlarmThresholdMin=
AlarmThresholdMax=
AlarmFlags=0
AlarmTimeout=5000
AlarmApp=
AlarmAppCmdLine=
EnableDataFiltering=0
MaxLimit=100
MinLimit=0
Group=CPU 29
Name=
TrayTextColor=FF0000h
TrayIconType=0
OSDItemType=0
GraphColor=00FF00h
Formula=
[Source CPU30 temperature]
ShowInOSD=1
ShowInLCD=0
ShowInTray=0
AlarmThresholdMin=
AlarmThresholdMax=
AlarmFlags=0
AlarmTimeout=5000
AlarmApp=
AlarmAppCmdLine=
EnableDataFiltering=0
MaxLimit=100
MinLimit=0
Group=CPU 30
Name=
TrayTextColor=FF0000h
TrayIconType=0
OSDItemType=0
GraphColor=00FF00h
Formula=
[Source CPU31 temperature]
ShowInOSD=1
ShowInLCD=0
ShowInTray=0
AlarmThresholdMin=
AlarmThresholdMax=
AlarmFlags=0
AlarmTimeout=5000
AlarmApp=
AlarmAppCmdLine=
EnableDataFiltering=0
MaxLimit=100
MinLimit=0
Group=CPU 31
Name=
TrayTextColor=FF0000h
TrayIconType=0
OSDItemType=0
GraphColor=00FF00h
Formula=
[Source CPU25 usage]
ShowInOSD=1
ShowInLCD=0
ShowInTray=0
AlarmThresholdMin=
AlarmThresholdMax=
AlarmFlags=0
AlarmTimeout=5000
AlarmApp=
AlarmAppCmdLine=
EnableDataFiltering=0
MaxLimit=100
MinLimit=0
Group=CPU 25
Name=
TrayTextColor=FF0000h
TrayIconType=0
OSDItemType=0
GraphColor=00FF00h
Formula=
[Source CPU26 usage]
ShowInOSD=1
ShowInLCD=0
ShowInTray=0
AlarmThresholdMin=
AlarmThresholdMax=
AlarmFlags=0
AlarmTimeout=5000
AlarmApp=
AlarmAppCmdLine=
EnableDataFiltering=0
MaxLimit=100
MinLimit=0
Group=CPU 26
Name=
TrayTextColor=FF0000h
TrayIconType=0
OSDItemType=0
GraphColor=00FF00h
Formula=
[Source CPU27 usage]
ShowInOSD=1
ShowInLCD=0
ShowInTray=0
AlarmThresholdMin=
AlarmThresholdMax=
AlarmFlags=0
AlarmTimeout=5000
AlarmApp=
AlarmAppCmdLine=
EnableDataFiltering=0
MaxLimit=100
MinLimit=0
Group=CPU 27
Name=
TrayTextColor=FF0000h
TrayIconType=0
OSDItemType=0
GraphColor=00FF00h
Formula=
[Source CPU28 usage]
ShowInOSD=1
ShowInLCD=0
ShowInTray=0
AlarmThresholdMin=
AlarmThresholdMax=
AlarmFlags=0
AlarmTimeout=5000
AlarmApp=
AlarmAppCmdLine=
EnableDataFiltering=0
MaxLimit=100
MinLimit=0
Group=CPU 28
Name=
TrayTextColor=FF0000h
TrayIconType=0
OSDItemType=0
GraphColor=00FF00h
Formula=
[Source CPU29 usage]
ShowInOSD=1
ShowInLCD=0
ShowInTray=0
AlarmThresholdMin=
AlarmThresholdMax=
AlarmFlags=0
AlarmTimeout=5000
AlarmApp=
AlarmAppCmdLine=
EnableDataFiltering=0
MaxLimit=100
MinLimit=0
Group=CPU 29
Name=
TrayTextColor=FF0000h
TrayIconType=0
OSDItemType=0
GraphColor=00FF00h
Formula=
[Source CPU30 usage]
ShowInOSD=1
ShowInLCD=0
ShowInTray=0
AlarmThresholdMin=
AlarmThresholdMax=
AlarmFlags=0
AlarmTimeout=5000
AlarmApp=
AlarmAppCmdLine=
EnableDataFiltering=0
MaxLimit=100
MinLimit=0
Group=CPU 30
Name=
TrayTextColor=FF0000h
TrayIconType=0
OSDItemType=0
GraphColor=00FF00h
Formula=
[Source CPU31 usage]
ShowInOSD=1
ShowInLCD=0
ShowInTray=0
AlarmThresholdMin=
AlarmThresholdMax=
AlarmFlags=0
AlarmTimeout=5000
AlarmApp=
AlarmAppCmdLine=
EnableDataFiltering=0
MaxLimit=100
MinLimit=0
Group=CPU 31
Name=
TrayTextColor=FF0000h
TrayIconType=0
OSDItemType=0
GraphColor=00FF00h
Formula=
[Source GPU temperature 2]
ShowInOSD=0
ShowInLCD=0
ShowInTray=0
AlarmThresholdMin=
AlarmThresholdMax=
AlarmFlags=0
AlarmTimeout=5000
AlarmApp=
AlarmAppCmdLine=
EnableDataFiltering=0
MaxLimit=100
MinLimit=0
Group=\nGPU
Name=
TrayTextColor=FF0000h
TrayIconType=0
OSDItemType=0
GraphColor=00FF00h
Formula=
[Source CPU17 power]
ShowInOSD=0
ShowInLCD=0
ShowInTray=0
AlarmThresholdMin=
AlarmThresholdMax=
AlarmFlags=0
AlarmTimeout=5000
AlarmApp=
AlarmAppCmdLine=
EnableDataFiltering=0
MaxLimit=200.0
MinLimit=0.0
Group=
Name=
TrayTextColor=FF0000h
TrayIconType=0
OSDItemType=0
GraphColor=00FF00h
Formula=
[Source CPU29 power]
ShowInOSD=0
ShowInLCD=0
ShowInTray=0
AlarmThresholdMin=
AlarmThresholdMax=
AlarmFlags=0
AlarmTimeout=5000
AlarmApp=
AlarmAppCmdLine=
EnableDataFiltering=0
MaxLimit=200.0
MinLimit=0.0
Group=
Name=
TrayTextColor=FF0000h
TrayIconType=0
OSDItemType=0
GraphColor=00FF00h
Formula=
[Source CPU32 power]
ShowInOSD=0
ShowInLCD=0
ShowInTray=0
AlarmThresholdMin=
AlarmThresholdMax=
AlarmFlags=0
AlarmTimeout=5000
AlarmApp=
AlarmAppCmdLine=
EnableDataFiltering=0
MaxLimit=200.0
MinLimit=0.0
Group=
Name=
TrayTextColor=FF0000h
TrayIconType=0
OSDItemType=0
GraphColor=00FF00h
Formula=
[Source CPU16 power]
ShowInOSD=0
ShowInLCD=0
ShowInTray=0
AlarmThresholdMin=
AlarmThresholdMax=
AlarmFlags=0
AlarmTimeout=5000
AlarmApp=
AlarmAppCmdLine=
EnableDataFiltering=0
MaxLimit=200.0
MinLimit=0.0
Group=
Name=
TrayTextColor=FF0000h
TrayIconType=0
OSDItemType=0
GraphColor=00FF00h
Formula=
[Source CPU1 power]
ShowInOSD=0
ShowInLCD=0
ShowInTray=0
AlarmThresholdMin=
AlarmThresholdMax=
AlarmFlags=0
AlarmTimeout=5000
AlarmApp=
AlarmAppCmdLine=
EnableDataFiltering=0
MaxLimit=200.0
MinLimit=0.0
Group=
Name=
TrayTextColor=FF0000h
TrayIconType=0
OSDItemType=0
GraphColor=00FF00h
Formula=
[Source CPU13 power]
ShowInOSD=0
ShowInLCD=0
ShowInTray=0
AlarmThresholdMin=
AlarmThresholdMax=
AlarmFlags=0
AlarmTimeout=5000
AlarmApp=
AlarmAppCmdLine=
EnableDataFiltering=0
MaxLimit=200.0
MinLimit=0.0
Group=
Name=
TrayTextColor=FF0000h
TrayIconType=0
OSDItemType=0
GraphColor=00FF00h
Formula=
[Source CPU15 power]
ShowInOSD=0
ShowInLCD=0
ShowInTray=0
AlarmThresholdMin=
AlarmThresholdMax=
AlarmFlags=0
AlarmTimeout=5000
AlarmApp=
AlarmAppCmdLine=
EnableDataFiltering=0
MaxLimit=200.0
MinLimit=0.0
Group=
Name=
TrayTextColor=FF0000h
TrayIconType=0
OSDItemType=0
GraphColor=00FF00h
Formula=
[Source CPU30 power]
ShowInOSD=0
ShowInLCD=0
ShowInTray=0
AlarmThresholdMin=
AlarmThresholdMax=
AlarmFlags=0
AlarmTimeout=5000
AlarmApp=
AlarmAppCmdLine=
EnableDataFiltering=0
MaxLimit=200.0
MinLimit=0.0
Group=
Name=
TrayTextColor=FF0000h
TrayIconType=0
OSDItemType=0
GraphColor=00FF00h
Formula=
[Source CPU31 power]
ShowInOSD=0
ShowInLCD=0
ShowInTray=0
AlarmThresholdMin=
AlarmThresholdMax=
AlarmFlags=0
AlarmTimeout=5000
AlarmApp=
AlarmAppCmdLine=
EnableDataFiltering=0
MaxLimit=200.0
MinLimit=0.0
Group=
Name=
TrayTextColor=FF0000h
TrayIconType=0
OSDItemType=0
GraphColor=00FF00h
Formula=

[Source Fan speed 3]
ShowInOSD=0
ShowInLCD=0
ShowInTray=0
AlarmThresholdMin=
AlarmThresholdMax=
AlarmFlags=0
AlarmTimeout=5000
AlarmApp=
AlarmAppCmdLine=
EnableDataFiltering=0
MaxLimit=100
MinLimit=0
Group=
Name=
TrayTextColor=FF0000h
TrayIconType=0
OSDItemType=0
GraphColor=00FF00h
Formula=
[Source Fan tachometer 3]
ShowInOSD=0
ShowInLCD=0
ShowInTray=0
AlarmThresholdMin=
AlarmThresholdMax=
AlarmFlags=0
AlarmTimeout=5000
AlarmApp=
AlarmAppCmdLine=
EnableDataFiltering=0
MaxLimit=10000
MinLimit=0
Group=
Name=
TrayTextColor=FF0000h
TrayIconType=0
OSDItemType=0
GraphColor=00FF00h
Formula=

"@
Set-Content -Path "$env:SystemDrive\Program Files (x86)\MSI Afterburner\Profiles\MSIAfterburner.cfg" -Value $MsiAfterBurnerCfg -Force

# new profiles folder
New-Item -Path "$env:SystemDrive\Program Files (x86)\RivaTuner Statistics Server" -Name "Profiles" -ItemType Directory -ErrorAction SilentlyContinue | Out-Null

# create config for rivatuner
$Config = @"
[FnOffsetCache64]
OS=6.2 Build 9200
DDRAW.DLL=0009A000 ABE30BB1
IDirectDrawSurface7::Flip=0002D5F0
D3D9.DLL=001B3238 772D8FE5
IDirect3DDevice9::Present=00064060
IDirect3DDevice9::Release=000137C0
IDirect3DDevice9::Reset=000E17E0
IDirect3DSwapChain9::Present=00081A60
IDirect3DDevice9Ex::PresentEx=0001C6A0
IDirect3DDevice9Ex::ResetEx=000284A0
DXGI.DLL=0013D1E0 1AA4D6F0
IDXGISwapChain::Present=00002CA0
IDXGISwapChain::ResizeBuffers=00038C60
IDXGISwapChain::Release=00030790
IDXGISwapChain1::Present1=00003140
IDXGIFactory::CreateSwapChain=0001F2D0
IDXGIFactory2::CreateSwapChainForHwnd=00021170
IDXGIFactory2::CreateSwapChainForCoreWindow=00093580
kernel32.dll=000CC218 F110D2EE
LoadLibraryA=00042D80
LoadLibraryW=0003F7C0
Version=0000000A
D3D12.DLL=0001C9E0 E3291474
ID3D12CommandQueue::ExecuteCommandLists=00009470
IDXGISwapChain3::ResizeBuffers1=0009DC00
IDXGISwapChain::SetFullscreenState=00039450
D3D12Core.DLL=00359D38 C1EDC621
IDXGISwapChain1::m_pCommandQueue=00000138
[FnOffsetCache]
OS=6.2 Build 9200
DDRAW.DLL=00084200 098CDB9C
IDirectDrawSurface7::Flip=00037E80
D3D8.DLL=000B4C00 B36C3FE9
IDirect3DDevice8::Present=0002ABE0
IDirect3DDevice8::Release=0002A200
IDirect3DDevice8::Reset=0002A7C0
D3D9.DLL=00177880 BF6F39A9
IDirect3DDevice9::Present=000E2D20
IDirect3DDevice9::Release=00065920
IDirect3DDevice9::Reset=000E3120
IDirect3DSwapChain9::Present=00043E30
IDirect3DDevice9Ex::PresentEx=000E2DB0
IDirect3DDevice9Ex::ResetEx=000E3220
DXGI.DLL=00103690 F12BEC6B
IDXGISwapChain::Present=000AFAA0
IDXGISwapChain::ResizeBuffers=00026750
IDXGISwapChain::Release=0004B0C0
IDXGISwapChain1::Present1=000464B0
IDXGIFactory::CreateSwapChain=000A6990
IDXGIFactory2::CreateSwapChainForHwnd=000A7060
IDXGIFactory2::CreateSwapChainForCoreWindow=000A6EE0
kernel32.dll=000A6CD0 CC7E18E1
LoadLibraryA=00031B40
LoadLibraryW=0001D820
Version=0000000A
D3D12.DLL=000144C0 DFA0F1A2
ID3D12CommandQueue::ExecuteCommandLists=000850A0
IDXGISwapChain3::ResizeBuffers1=000B10E0
IDXGISwapChain::SetFullscreenState=00028250
D3D12Core.DLL=002C99D0 3C8A4788
IDXGISwapChain1::m_pCommandQueue=000000B8
[Settings]
LastUpdateCheck=666E98C1h
Skin=default.usf
WindowX=1238
WindowY=316
FirstRun=0
StartMinimized=1
StartWithWindows=0
ShowTooltips=0
EnableEncoderServer=1
Enable64Bit=1
Use64BitEncoderServer=1
HidePreCreatedProfiles=1
UpdateCheckingPeriod=0
Language=
LayeredWindowMode=0
LayeredWindowAlpha=255
ScaleFactor=100
[Shared]
Flags=00000005
[Plugins]
OverlayEditor.dll=1
HotkeyHandler.dll=1


"@
Set-Content -Path "$env:SystemDrive\Program Files (x86)\RivaTuner Statistics Server\Profiles\Config" -Value $Config -Force

# create global for rivatuner
$Global = @"
[OSD]
EnableOSD=1
EnableBgnd=0
EnableFill=0
EnableStat=0
BaseColor=FFFFFFFF
BgndColor=00000000
FillColor=80000000
PositionX=1
PositionY=1
ZoomRatio=2
CoordinateSpace=0
EnableFrameColorBar=0
FrameColorBarMode=0
RefreshPeriod=500
IntegerFramerate=1
MaximumFrametime=0
EnableFrametimeHistory=0
FrametimeHistoryWidth=-32
FrametimeHistoryHeight=-4
FrametimeHistoryStyle=0
ScaleToFit=0
[Statistics]
FramerateAveragingInterval=1000
PeakFramerateCalc=0
PercentileCalc=0
FrametimeCalc=0
PercentileBuffer=0
[Framerate]
Limit=0
LimitDenominator=1
LimitTime=0
LimitTimeDenominator=1
SyncDisplay=0
SyncScanline0=0
SyncScanline1=0
SyncPeriods=0
SyncLimiter=0
PassiveWait=1
ReflexSleep=0
ReflexSetLatencyMarker=0
[Hooking]
EnableHooking=1
EnableFloatingInjectionAddress=0
EnableDynamicOffsetDetection=0
HookLoadLibrary=0
HookDirectDraw=0
HookDirect3D8=1
HookDirect3D9=1
HookDirect3DSwapChain9Present=1
HookDXGI=1
HookDirect3D12=1
HookOpenGL=1
HookVulkan=1
InjectionDelay=15000
UseDetours=1
[Font]
Height=-9
Weight=400
Face=Unispace
Load=
[RendererDirect3D8]
Implementation=2
[RendererDirect3D9]
Implementation=2
[RendererDirect3D10]
Implementation=2
[RendererDirect3D11]
Implementation=2
[RendererDirect3D12]
Implementation=2
[RendererOpenGL]
Implementation=2
[RendererVulkan]
Implementation=2
[Info]

Timestamp=19-03-2026, 09:26:06


"@
Set-Content -Path "$env:SystemDrive\Program Files (x86)\RivaTuner Statistics Server\Profiles\Global" -Value $Global -Force

# create overlayeditor.cfg for rivatuner
$OverlayEditorCfg = @"
[Settings]
Layout=akarios.ovl
"@
Set-Content -Path "$env:SystemDrive\Program Files (x86)\RivaTuner Statistics Server\Plugins\Client\OverlayEditor.cfg" -Value $OverlayEditorCfg -Force

# create hotkeyhandler.cfg for rivatuner
$HotkeyHandlerCfg = @"
[Settings]
OSDOnHotkey=00000000
OSDOffHotkey=00000000
OSDToggleHotkey=00000079
LimiterOnHotkey=00000000
LimiterOffHotkey=00000000
LimiterToggleHotkey=00000000
ScreenCaptureHotkey=00000000
VideoCaptureHotkey=00000000
PTTHotkey=00000000
PTT2Hotkey=00000000
VideoPrerecordHotkey=00000000
BenchmarkBeginHotkey=0000007A
BenchmarkEndHotkey=0000007B
PPM1Hotkey=00000000
PPM2Hotkey=00000000
PPM3Hotkey=00000000
PPM4Hotkey=00000000
OVM1Hotkey=00000000
OVM2Hotkey=00000000
OVM3Hotkey=00000000
OVM4Hotkey=00000000
ScreenCaptureFormat=png
ScreenCaptureQuality=100
ScreenCaptureFolder=C:\
CaptureOSD=0
VideoCaptureContainer=mkv
VideoCaptureFormat=NV12
VideoCaptureQuality=100
VideoCaptureFolder=C:\
VideoCaptureFramesize=00000001
VideoCaptureFramerate=60
AudioCaptureFlags=00000001
AudioCaptureFlags2=00000000
VideoCaptureFlagsEx=00000000
PrerecordSizeLimit=256
PrerecordTimeLimit=600
AutoPrerecord=0
BenchmarkPath=C:\Benckmark.txt
AppendBenchmark=1
PPM1Desc=
PPM1Profile=
PPM1Property=
PPM1Type=0
PPM1Value=0
PPM2Desc=
PPM2Profile=
PPM2Property=
PPM2Type=0
PPM2Value=0
PPM3Desc=
PPM3Profile=
PPM3Property=
PPM3Type=0
PPM3Value=0
PPM4Desc=
PPM4Profile=
PPM4Property=
PPM4Type=0
PPM4Value=0
OVM1Desc=
OVM1Message=
OVM1Layer=
OVM1Params=
OVM2Desc=
OVM2Message=
OVM2Layer=
OVM2Params=
OVM3Desc=
OVM3Message=
OVM3Layer=
OVM3Params=
OVM4Desc=
OVM4Message=
OVM4Layer=
OVM4Params=


"@
Set-Content -Path "$env:SystemDrive\Program Files (x86)\RivaTuner Statistics Server\Plugins\Client\HotkeyHandler.cfg" -Value $HotkeyHandlerCfg -Force

# create akarios.ovl for rivatuner
$akariosovl = @"
[Master]
Implementation=2
FontFace=Unispace
FontHeight=-9
FontWeight=400
ZoomRatio=4
[Settings]
Name=
EnvVars=
RefreshPeriod=1000
LockUserSettings=0
EmbeddedImage=
PingAddr=
[General]
Sources=66
Tables=0
Layers=69
[Source0]
Name=RAM usage
Units=MB
Format=
Formula=
Provider=MSI Afterburner
SrcId=00000091
Gpu=00000000
SrcName=
[Source1]
Name=Memory usage
Units=MB
Format=
Formula=
Provider=MSI Afterburner
SrcId=00000031
Gpu=00000000
SrcName=
[Source2]
Name=Memory clock
Units=MHz
Format=
Formula=
Provider=MSI Afterburner
SrcId=00000022
Gpu=00000000
SrcName=
[Source3]
Name=CPU1 clock
Units=MHz
Format=
Formula=
Provider=MSI Afterburner
SrcId=000000A0
Gpu=00000000
SrcName=
[Source4]
Name=CPU2 clock
Units=MHz
Format=
Formula=
Provider=MSI Afterburner
SrcId=000000A0
Gpu=00000001
SrcName=
[Source5]
Name=CPU3 clock
Units=MHz
Format=
Formula=
Provider=MSI Afterburner
SrcId=000000A0
Gpu=00000002
SrcName=
[Source6]
Name=CPU4 clock
Units=MHz
Format=
Formula=
Provider=MSI Afterburner
SrcId=000000A0
Gpu=00000003
SrcName=
[Source7]
Name=CPU5 clock
Units=MHz
Format=
Formula=
Provider=MSI Afterburner
SrcId=000000A0
Gpu=00000004
SrcName=
[Source8]
Name=CPU6 clock
Units=MHz
Format=
Formula=
Provider=MSI Afterburner
SrcId=000000A0
Gpu=00000005
SrcName=
[Source9]
Name=CPU7 clock
Units=MHz
Format=
Formula=
Provider=MSI Afterburner
SrcId=000000A0
Gpu=00000006
SrcName=
[Source10]
Name=CPU8 clock
Units=MHz
Format=
Formula=
Provider=MSI Afterburner
SrcId=000000A0
Gpu=00000007
SrcName=
[Source11]
Name=CPU9 clock
Units=MHz
Format=
Formula=
Provider=MSI Afterburner
SrcId=000000A0
Gpu=00000008
SrcName=
[Source12]
Name=CPU10 clock
Units=MHz
Format=
Formula=
Provider=MSI Afterburner
SrcId=000000A0
Gpu=00000009
SrcName=
[Source13]
Name=CPU11 clock
Units=MHz
Format=
Formula=
Provider=MSI Afterburner
SrcId=000000A0
Gpu=0000000A
SrcName=
[Source14]
Name=CPU12 clock
Units=MHz
Format=
Formula=
Provider=MSI Afterburner
SrcId=000000A0
Gpu=0000000B
SrcName=
[Source15]
Name=CPU13 clock
Units=MHz
Format=
Formula=
Provider=MSI Afterburner
SrcId=000000A0
Gpu=0000000C
SrcName=
[Source16]
Name=CPU14 clock
Units=MHz
Format=
Formula=
Provider=MSI Afterburner
SrcId=000000A0
Gpu=0000000D
SrcName=
[Source17]
Name=CPU15 clock
Units=MHz
Format=
Formula=
Provider=MSI Afterburner
SrcId=000000A0
Gpu=0000000E
SrcName=
[Source18]
Name=CPU16 clock
Units=MHz
Format=
Formula=
Provider=MSI Afterburner
SrcId=000000A0
Gpu=0000000F
SrcName=
[Source19]
Name=CPU1 usage
Units=%
Format=
Formula=
Provider=MSI Afterburner
SrcId=00000090
Gpu=00000000
SrcName=
[Source20]
Name=CPU2 usage
Units=%
Format=
Formula=
Provider=MSI Afterburner
SrcId=00000090
Gpu=00000001
SrcName=
[Source21]
Name=CPU3 usage
Units=%
Format=
Formula=
Provider=MSI Afterburner
SrcId=00000090
Gpu=00000002
SrcName=
[Source22]
Name=CPU4 usage
Units=%
Format=
Formula=
Provider=MSI Afterburner
SrcId=00000090
Gpu=00000003
SrcName=
[Source23]
Name=CPU5 usage
Units=%
Format=
Formula=
Provider=MSI Afterburner
SrcId=00000090
Gpu=00000004
SrcName=
[Source24]
Name=CPU6 usage
Units=%
Format=
Formula=
Provider=MSI Afterburner
SrcId=00000090
Gpu=00000005
SrcName=
[Source25]
Name=CPU7 usage
Units=%
Format=
Formula=
Provider=MSI Afterburner
SrcId=00000090
Gpu=00000006
SrcName=
[Source26]
Name=CPU8 usage
Units=%
Format=
Formula=
Provider=MSI Afterburner
SrcId=00000090
Gpu=00000007
SrcName=
[Source27]
Name=CPU9 usage
Units=%
Format=
Formula=
Provider=MSI Afterburner
SrcId=00000090
Gpu=00000008
SrcName=
[Source28]
Name=CPU10 usage
Units=%
Format=
Formula=
Provider=MSI Afterburner
SrcId=00000090
Gpu=00000009
SrcName=
[Source29]
Name=CPU11 usage
Units=%
Format=
Formula=
Provider=MSI Afterburner
SrcId=00000090
Gpu=0000000A
SrcName=
[Source30]
Name=CPU12 usage
Units=%
Format=
Formula=
Provider=MSI Afterburner
SrcId=00000090
Gpu=0000000B
SrcName=
[Source31]
Name=CPU13 usage
Units=%
Format=
Formula=
Provider=MSI Afterburner
SrcId=00000090
Gpu=0000000C
SrcName=
[Source32]
Name=CPU14 usage
Units=%
Format=
Formula=
Provider=MSI Afterburner
SrcId=00000090
Gpu=0000000D
SrcName=
[Source33]
Name=CPU15 usage
Units=%
Format=
Formula=
Provider=MSI Afterburner
SrcId=00000090
Gpu=0000000E
SrcName=
[Source34]
Name=CPU16 usage
Units=%
Format=
Formula=
Provider=MSI Afterburner
SrcId=00000090
Gpu=0000000F
SrcName=
[Source35]
Name=CPU1 temperature
Units=°C
Format=
Formula=
Provider=MSI Afterburner
SrcId=00000080
Gpu=00000000
SrcName=
[Source36]
Name=CPU2 temperature
Units=°C
Format=
Formula=
Provider=MSI Afterburner
SrcId=00000080
Gpu=00000001
SrcName=
[Source37]
Name=CPU3 temperature
Units=°C
Format=
Formula=
Provider=MSI Afterburner
SrcId=00000080
Gpu=00000002
SrcName=
[Source38]
Name=CPU4 temperature
Units=°C
Format=
Formula=
Provider=MSI Afterburner
SrcId=00000080
Gpu=00000003
SrcName=
[Source39]
Name=CPU5 temperature
Units=°C
Format=
Formula=
Provider=MSI Afterburner
SrcId=00000080
Gpu=00000004
SrcName=
[Source40]
Name=CPU6 temperature
Units=°C
Format=
Formula=
Provider=MSI Afterburner
SrcId=00000080
Gpu=00000005
SrcName=
[Source41]
Name=CPU7 temperature
Units=°C
Format=
Formula=
Provider=MSI Afterburner
SrcId=00000080
Gpu=00000006
SrcName=
[Source42]
Name=CPU8 temperature
Units=°C
Format=
Formula=
Provider=MSI Afterburner
SrcId=00000080
Gpu=00000007
SrcName=
[Source43]
Name=CPU9 temperature
Units=°C
Format=
Formula=
Provider=MSI Afterburner
SrcId=00000080
Gpu=00000008
SrcName=
[Source44]
Name=CPU10 temperature
Units=°C
Format=
Formula=
Provider=MSI Afterburner
SrcId=00000080
Gpu=00000009
SrcName=
[Source45]
Name=CPU11 temperature
Units=°C
Format=
Formula=
Provider=MSI Afterburner
SrcId=00000080
Gpu=0000000A
SrcName=
[Source46]
Name=CPU12 temperature
Units=°C
Format=
Formula=
Provider=MSI Afterburner
SrcId=00000080
Gpu=0000000B
SrcName=
[Source47]
Name=CPU13 temperature
Units=°C
Format=
Formula=
Provider=MSI Afterburner
SrcId=00000080
Gpu=0000000C
SrcName=
[Source48]
Name=CPU14 temperature
Units=°C
Format=
Formula=
Provider=MSI Afterburner
SrcId=00000080
Gpu=0000000D
SrcName=
[Source49]
Name=CPU15 temperature
Units=°C
Format=
Formula=
Provider=MSI Afterburner
SrcId=00000080
Gpu=0000000E
SrcName=
[Source50]
Name=CPU16 temperature
Units=°C
Format=
Formula=
Provider=MSI Afterburner
SrcId=00000080
Gpu=0000000F
SrcName=
[Source51]
Name=CPU power
Units=W
Format=
Formula=
Provider=MSI Afterburner
SrcId=00000100
Gpu=FFFFFFFF
SrcName=
[Source52]
Name=CPU usage
Units=%
Format=
Formula=
Provider=MSI Afterburner
SrcId=00000090
Gpu=FFFFFFFF
SrcName=
[Source53]
Name=GPU usage
Units=%
Format=
Formula=
Provider=MSI Afterburner
SrcId=00000030
Gpu=00000000
SrcName=
[Source54]
Name=Core clock
Units=MHz
Format=
Formula=
Provider=MSI Afterburner
SrcId=00000020
Gpu=00000000
SrcName=
[Source55]
Name=GPU temperature
Units=°C
Format=
Formula=
Provider=MSI Afterburner
SrcId=00000000
Gpu=00000000
SrcName=
[Source56]
Name=Framerate
Units=FPS
Format=
Formula=
Provider=MSI Afterburner
SrcId=00000050
Gpu=FFFFFFFF
SrcName=
[Source57]
Name=IsBenchmarkActive
Units=
Format=
Formula=(rtssflags & 0x100) != 0
Provider=HAL
ID=Stub
[Source58]
Name=Framerate Avg
Units=FPS
Format=
Formula=
Provider=MSI Afterburner
SrcId=00000053
Gpu=FFFFFFFF
SrcName=
[Source59]
Name=Framerate 1% Low
Units=FPS
Format=
Formula=
Provider=MSI Afterburner
SrcId=00000055
Gpu=FFFFFFFF
SrcName=
[Source60]
Name=Framerate 0.1% Low
Units=FPS
Format=
Formula=
Provider=MSI Afterburner
SrcId=00000056
Gpu=FFFFFFFF
SrcName=
[Source61]
Name=Display1 refresh rate
Units=Hz
Format=
Formula=
Provider=HAL
ID=Display1 refresh rate
[Source62]
Name=PresentMode
Units=
Format=
Formula=
Provider=PresentMon
ID=PresentMode
[Source63]
Name=msGpuActive
Units=ms
Format=
Formula=
Provider=PresentMon
ID=msGpuActive
[Source64]
Name=msBetweenPresents
Units=ms
Format=
Formula=
Provider=PresentMon
ID=msBetweenPresents
[Source65]
Name=IsGpuLimited
Units=
Format=
Formula=(msGpuActive / msBetweenPresents) >= 0.75
Provider=HAL
ID=Stub
[Layer0]
Name=Box Header Game
Text=
PositionX=0
PositionY=0
ExtentX=207
ExtentY=8
ExtentOrigin=0
Size=70
TextColor=FFFFFF
BgndColor=DB2B2B2B
[Layer1]
Name=Game Text
Text=GAME
PositionX=1
PositionY=1
ExtentX=-1
ExtentY=-1
ExtentOrigin=0
Size=70
TextColor=FFFFFF
[Layer2]
Name=Game Title
Text=<EXE>
PositionX=18
PositionY=1
ExtentX=188
ExtentY=9
ExtentOrigin=0
Size=70
TextColor=11C511
[Layer3]
Name=Box Info
Text=
PositionX=104
PositionY=9
ExtentX=103
ExtentY=127
ExtentOrigin=0
Size=70
TextColor=FFFFFF
BgndColor=822B2B2B
[Layer4]
Name=Box Header Info Config
Text=
PositionX=104
PositionY=9
ExtentX=103
ExtentY=10
ExtentOrigin=0
Size=70
TextColor=FFFFFF
BgndColor=DB2B2B2B
[Layer5]
Name=Config Text
Text=CONFIG
PositionX=105
PositionY=11
ExtentX=24
ExtentY=1
ExtentOrigin=0
Size=70
TextColor=FFFFFF
[Layer6]
Name=Config
Text=<RES>\n%Display1 refresh rate%hz\n<APP>\n<SWITCH PresentMode><CASE 1>HW:Legacy Flip<CASE 2>HW:Legacy Copy<CASE 3>HW:Independent Flip<CASE 4>COMP:Flip<CASE 5>COMP:CPU Copy<CASE 6>COMP:GPU Copy<CASE 8>HW COMP:Independent Flip
PositionX=105
PositionY=21
ExtentX=0
ExtentY=0
ExtentOrigin=0
FixedAlignment=1
Size=70
TextColor=11C511
[Layer7]
Name=Box Header Info Driver
Text=
PositionX=104
PositionY=51
ExtentX=103
ExtentY=10
ExtentOrigin=0
Size=70
TextColor=FFFFFF
BgndColor=DB2B2B2B
[Layer8]
Name=Driver Text
Text=DRIVER
PositionX=105
PositionY=52
ExtentX=12
ExtentY=7
ExtentOrigin=0
FixedAlignment=1
Size=70
TextColor=FFFFFF
[Layer9]
Name=Driver
Text=%Driver%
PositionX=105
PositionY=63
ExtentX=0
ExtentY=0
ExtentOrigin=0
FixedAlignment=1
Size=70
TextColor=11C511
[Layer10]
Name=Box Header Info Time
Text=
PositionX=104
PositionY=71
ExtentX=103
ExtentY=8
ExtentOrigin=0
Size=70
TextColor=FFFFFF
BgndColor=DB2B2B2B
[Layer11]
Name=Time Text
Text=TIME
PositionX=105
PositionY=72
ExtentX=0
ExtentY=0
ExtentOrigin=0
FixedAlignment=1
Size=70
TextColor=FFFFFF
[Layer12]
Name=Time
Text=%Time12%\n%Date%
PositionX=105
PositionY=82
ExtentX=0
ExtentY=0
ExtentOrigin=0
FixedAlignment=1
Size=70
TextColor=11C511
[Layer13]
Name=Box Header Info Limit
Text=
PositionX=104
PositionY=97
ExtentX=103
ExtentY=10
ExtentOrigin=0
Size=70
TextColor=FFFFFF
BgndColor=DB2B2B2B
[Layer14]
Name=Limit Text
Text=LIMIT
PositionX=105
PositionY=98
ExtentX=20
ExtentY=6
ExtentOrigin=0
FixedAlignment=1
Size=70
TextColor=FFFFFF
[Layer15]
Name=Limit
Text=<IF IsGpuLimited>GPU<ELSE>CPU
PositionX=105
PositionY=109
ExtentX=0
ExtentY=0
ExtentOrigin=0
FixedAlignment=1
Size=70
TextColor=11C511
[Layer16]
Name=Box Header Info FPS
Text=
PositionX=104
PositionY=117
ExtentX=103
ExtentY=10
ExtentOrigin=0
Size=70
TextColor=FFFFFF
BgndColor=DB2B2B2B
[Layer17]
Name=FPS Text
Text=FPS
PositionX=105
PositionY=118
ExtentX=0
ExtentY=0
ExtentOrigin=0
FixedAlignment=1
Size=70
TextColor=FFFFFF
[Layer18]
Name=FPS
Text=<FR> fps
PositionX=105
PositionY=128
ExtentX=0
ExtentY=0
ExtentOrigin=0
FixedAlignment=1
Size=70
TextColor=11C511
[Layer19]
Name=Box CPU
Text=
PositionX=0
PositionY=9
ExtentX=103
ExtentY=147
ExtentOrigin=0
Size=70
TextColor=FFFFFF
BgndColor=822B2B2B
[Layer20]
Name=Box Header CPU
Text=
PositionX=0
PositionY=9
ExtentX=103
ExtentY=10
ExtentOrigin=0
Size=70
TextColor=FFFFFF
BgndColor=DB2B2B2B
[Layer21]
Name=CPU Text
Text=%CPUShort% %RAM%
PositionX=1
PositionY=10
ExtentX=60
ExtentY=6
ExtentOrigin=0
FixedAlignment=1
Size=70
TextColor=FFFFFF
[Layer22]
Name=CPU
Text=%RAM usage%mb
PositionX=34
PositionY=20
ExtentX=60
ExtentY=7
ExtentOrigin=0
Size=70
TextColor=11C511
[Layer23]
Name=CPU Power
Text=%CPU power%w
PositionX=66
PositionY=20
ExtentX=5
ExtentY=7
ExtentOrigin=0
Size=70
TextColor=11C511
[Layer24]
Name=CPU Usage
Text=%CPU usage%%
PositionX=86
PositionY=20
ExtentX=1
ExtentY=7
ExtentOrigin=0
Size=70
TextColor=11C511
[Layer25]
Name=CPU 1 Text
Text=CPU 1
PositionX=1
PositionY=28
ExtentX=0
ExtentY=0
ExtentOrigin=0
FixedAlignment=1
Size=70
TextColor=FFFFFF
[Layer26]
Name=CPU 1
Text=%CPU1 clock%mhz %CPU1 temperature%°C %CPU1 usage%%
PositionX=34
PositionY=28
ExtentX=60
ExtentY=8
ExtentOrigin=0
FixedAlignment=1
Size=70
TextColor=11C511
[Layer27]
Name=CPU 2 Text
Text=CPU 2
PositionX=1
PositionY=36
ExtentX=0
ExtentY=0
ExtentOrigin=0
FixedAlignment=1
Size=70
TextColor=FFFFFF
[Layer28]
Name=CPU 2
Text=%CPU2 clock%mhz %CPU2 temperature%°C %CPU2 usage%%
PositionX=34
PositionY=36
ExtentX=0
ExtentY=0
ExtentOrigin=0
FixedAlignment=1
Size=70
TextColor=11C511
[Layer29]
Name=CPU 3 Text
Text=CPU 3
PositionX=1
PositionY=44
ExtentX=0
ExtentY=0
ExtentOrigin=0
FixedAlignment=1
Size=70
TextColor=FFFFFF
[Layer30]
Name=CPU 3
Text=%CPU3 clock%mhz %CPU3 temperature%°C %CPU3 usage%%
PositionX=34
PositionY=44
ExtentX=0
ExtentY=0
ExtentOrigin=0
FixedAlignment=1
Size=70
TextColor=11C511
[Layer31]
Name=CPU 4 Text
Text=CPU 4
PositionX=1
PositionY=52
ExtentX=0
ExtentY=0
ExtentOrigin=0
FixedAlignment=1
Size=70
TextColor=FFFFFF
[Layer32]
Name=CPU 4
Text=%CPU4 clock%mhz %CPU4 temperature%°C %CPU4 usage%%
PositionX=34
PositionY=52
ExtentX=0
ExtentY=0
ExtentOrigin=0
FixedAlignment=1
Size=70
TextColor=11C511
[Layer33]
Name=CPU 5 Text
Text=CPU 5
PositionX=1
PositionY=60
ExtentX=0
ExtentY=0
ExtentOrigin=0
FixedAlignment=1
Size=70
TextColor=FFFFFF
[Layer34]
Name=CPU 5
Text=%CPU5 clock%mhz %CPU5 temperature%°C %CPU5 usage%%
PositionX=34
PositionY=60
ExtentX=0
ExtentY=0
ExtentOrigin=0
FixedAlignment=1
Size=70
TextColor=11C511
[Layer35]
Name=CPU 6 Text
Text=CPU 6
PositionX=1
PositionY=68
ExtentX=0
ExtentY=0
ExtentOrigin=0
FixedAlignment=1
Size=70
TextColor=FFFFFF
[Layer36]
Name=CPU 6
Text=%CPU6 clock%mhz %CPU6 temperature%°C %CPU6 usage%%
PositionX=34
PositionY=68
ExtentX=0
ExtentY=0
ExtentOrigin=0
FixedAlignment=1
Size=70
TextColor=11C511
[Layer37]
Name=CPU 7 Text
Text=CPU 7
PositionX=1
PositionY=76
ExtentX=0
ExtentY=0
ExtentOrigin=0
FixedAlignment=1
Size=70
TextColor=FFFFFF
[Layer38]
Name=CPU 7
Text=%CPU7 clock%mhz %CPU7 temperature%°C %CPU7 usage%%
PositionX=34
PositionY=76
ExtentX=0
ExtentY=0
ExtentOrigin=0
FixedAlignment=1
Size=70
TextColor=11C511
[Layer39]
Name=CPU 8 Text
Text=CPU 8
PositionX=1
PositionY=84
ExtentX=0
ExtentY=0
ExtentOrigin=0
FixedAlignment=1
Size=70
TextColor=FFFFFF
[Layer40]
Name=CPU 8
Text=%CPU8 clock%mhz %CPU8 temperature%°C %CPU8 usage%%
PositionX=34
PositionY=84
ExtentX=0
ExtentY=0
ExtentOrigin=0
FixedAlignment=1
Size=70
TextColor=11C511
[Layer41]
Name=CPU 9 Text
Text=CPU 9
PositionX=1
PositionY=92
ExtentX=0
ExtentY=0
ExtentOrigin=0
FixedAlignment=1
Size=70
TextColor=FFFFFF
[Layer42]
Name=CPU 9
Text=%CPU9 clock%mhz %CPU9 temperature%°C %CPU9 usage%%
PositionX=34
PositionY=92
ExtentX=0
ExtentY=0
ExtentOrigin=0
FixedAlignment=1
Size=70
TextColor=11C511
[Layer43]
Name=CPU 10 Text
Text=CPU 10
PositionX=1
PositionY=100
ExtentX=0
ExtentY=0
ExtentOrigin=0
FixedAlignment=1
Size=70
TextColor=FFFFFF
[Layer44]
Name=CPU 10
Text=%CPU10 clock%mhz %CPU10 temperature%°C %CPU10 usage%%
PositionX=34
PositionY=100
ExtentX=0
ExtentY=0
ExtentOrigin=0
FixedAlignment=1
Size=70
TextColor=11C511
[Layer45]
Name=CPU 11 Text
Text=CPU 11
PositionX=1
PositionY=108
ExtentX=0
ExtentY=0
ExtentOrigin=0
FixedAlignment=1
Size=70
TextColor=FFFFFF
[Layer46]
Name=CPU 11
Text=%CPU11 clock%mhz %CPU11 temperature%°C %CPU11 usage%%
PositionX=34
PositionY=108
ExtentX=0
ExtentY=0
ExtentOrigin=0
FixedAlignment=1
Size=70
TextColor=11C511
[Layer47]
Name=CPU 12 Text
Text=CPU 12
PositionX=1
PositionY=116
ExtentX=0
ExtentY=0
ExtentOrigin=0
FixedAlignment=1
Size=70
TextColor=FFFFFF
[Layer48]
Name=CPU 12
Text=%CPU12 clock%mhz %CPU12 temperature%°C %CPU12 usage%%
PositionX=34
PositionY=116
ExtentX=0
ExtentY=0
ExtentOrigin=0
FixedAlignment=1
Size=70
TextColor=11C511
[Layer49]
Name=CPU 13 Text
Text=CPU 13
PositionX=1
PositionY=124
ExtentX=0
ExtentY=0
ExtentOrigin=0
FixedAlignment=1
Size=70
TextColor=FFFFFF
[Layer50]
Name=CPU 13
Text=%CPU13 clock%mhz %CPU13 temperature%°C %CPU13 usage%%
PositionX=34
PositionY=124
ExtentX=0
ExtentY=0
ExtentOrigin=0
FixedAlignment=1
Size=70
TextColor=11C511
[Layer51]
Name=CPU 14 Text
Text=CPU 14
PositionX=1
PositionY=132
ExtentX=0
ExtentY=0
ExtentOrigin=0
FixedAlignment=1
Size=70
TextColor=FFFFFF
[Layer52]
Name=CPU 14
Text=%CPU14 clock%mhz %CPU14 temperature%°C %CPU14 usage%%
PositionX=34
PositionY=132
ExtentX=0
ExtentY=0
ExtentOrigin=0
FixedAlignment=1
Size=70
TextColor=11C511
[Layer53]
Name=CPU 15 Text
Text=CPU 15
PositionX=1
PositionY=140
ExtentX=0
ExtentY=0
ExtentOrigin=0
FixedAlignment=1
Size=70
TextColor=FFFFFF
[Layer54]
Name=CPU 15
Text=%CPU15 clock%mhz %CPU15 temperature%°C %CPU15 usage%%
PositionX=34
PositionY=140
ExtentX=0
ExtentY=0
ExtentOrigin=0
FixedAlignment=1
Size=70
TextColor=11C511
[Layer55]
Name=CPU 16 Text
Text=CPU 16
PositionX=1
PositionY=148
ExtentX=0
ExtentY=0
ExtentOrigin=0
FixedAlignment=1
Size=70
TextColor=FFFFFF
[Layer56]
Name=CPU 16
Text=%CPU16 clock%mhz %CPU16 temperature%°C %CPU16 usage%%
PositionX=34
PositionY=148
ExtentX=0
ExtentY=0
ExtentOrigin=0
FixedAlignment=1
Size=70
TextColor=11C511
[Layer57]
Name=Box GPU
Text=
PositionX=0
PositionY=157
ExtentX=103
ExtentY=38
ExtentOrigin=0
Size=70
TextColor=FFFFFF
BgndColor=822B2B2B
[Layer58]
Name=Box Header GPU
Text=
PositionX=0
PositionY=157
ExtentX=103
ExtentY=10
ExtentOrigin=0
Size=70
TextColor=FFFFFF
BgndColor=DB2B2B2B
[Layer59]
Name=GPU Text
Text=%GPU% %VRAM%
PositionX=1
PositionY=158
ExtentX=0
ExtentY=0
ExtentOrigin=0
FixedAlignment=1
Size=70
TextColor=FFFFFF
[Layer60]
Name=GPU Text
Text=GPU
PositionX=1
PositionY=178
ExtentX=0
ExtentY=0
ExtentOrigin=0
FixedAlignment=1
Size=70
TextColor=FFFFFF
[Layer61]
Name=GPU
Text=%Memory usage%mb
PositionX=34
PositionY=170
ExtentX=48
ExtentY=7
ExtentOrigin=0
Size=70
TextColor=11C511
[Layer62]
Name=GPU Usage
Text=%GPU usage%%
PositionX=66
PositionY=170
ExtentX=2
ExtentY=7
ExtentOrigin=0
Size=70
TextColor=11C511
[Layer63]
Name=GPU Clocks
Text=%Core clock%mhz %GPU temperature%°C\n%Memory clock%mhz
PositionX=34
PositionY=178
ExtentX=0
ExtentY=0
ExtentOrigin=0
FixedAlignment=1
Size=70
TextColor=11C511
[Layer64]
Name=Box Benchmark
VisibilitySource=IsBenchmarkActive
Text=
PositionX=104
PositionY=137
ExtentX=67
ExtentY=64
ExtentOrigin=0
Size=70
TextColor=FFFFFF
BgndColor=822B2B2B
[Layer65]
Name=Box Header Benchmark
VisibilitySource=IsBenchmarkActive
Text=
PositionX=104
PositionY=137
ExtentX=67
ExtentY=17
ExtentOrigin=0
Size=70
TextColor=FFFFFF
BgndColor=DB2B2B2B
[Layer66]
Name=Benchmark Time Text
VisibilitySource=IsBenchmarkActive
Text="   Benchmark\n    <BTIME>"
PositionX=107
PositionY=139
ExtentX=0
ExtentY=0
ExtentOrigin=0
FixedAlignment=1
Size=70
TextColor=FFFFFF
[Layer67]
Name=Benchmark Text
VisibilitySource=IsBenchmarkActive
Text=FPS\nAVG\nMAX\nMIN\n1%\n0.1%
PositionX=105
PositionY=156
ExtentX=0
ExtentY=0
ExtentOrigin=0
FixedAlignment=1
Size=70
TextColor=FFFFFF
[Layer68]
Name=Benchmark
VisibilitySource=IsBenchmarkActive
Text=<FR> fps\n<FRAVG> fps\n<FRMAX> fps\n<FRMIN> fps\n<FR10L>  %\n<FR01L>  %
PositionX=138
PositionY=156
ExtentX=0
ExtentY=0
ExtentOrigin=0
FixedAlignment=1
Size=70
TextColor=11C511

"@
Set-Content -Path "$env:SystemDrive\Program Files (x86)\RivaTuner Statistics Server\Plugins\Client\Overlays\akarios.ovl" -Value $akariosovl -Force

# create desktopoverlayhost.cfg for rivatuner
$DesktopOverlayHostCfg = @"
[Settings]
WindowX=0
WindowY=0
WindowW=1024
WindowH=768
Transparent=1
Topmost=1
LockPos=1
ColorKey=1
BgndColor=00000000
Alpha=000000FF
Renderer=1
SuspendInIdle=0
ScaleToFit=0
Maximized=1


"@
Set-Content -Path "$env:SystemDrive\Program Files (x86)\RivaTuner Statistics Server\DesktopOverlayHost.cfg" -Value $DesktopOverlayHostCfg -Force

# cleaner start menu shortcut path
Move-Item -Path "$env:AppData\Microsoft\Windows\Start Menu\Programs\MSI Afterburner\MSI Afterburner.lnk" -Destination "$env:ProgramData\Microsoft\Windows\Start Menu\Programs" -Force -ErrorAction SilentlyContinue | Out-Null
Remove-Item "$env:AppData\Microsoft\Windows\Start Menu\Programs\MSI Afterburner" -Recurse -Force -ErrorAction SilentlyContinue | Out-Null
Remove-Item "$env:AppData\Microsoft\Windows\Start Menu\Programs\RivaTuner Statistics Server" -Recurse -Force -ErrorAction SilentlyContinue | Out-Null
    }
