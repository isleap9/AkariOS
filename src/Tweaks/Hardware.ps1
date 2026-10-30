# Hardware category. GENERATED from the AkariOS-Ultimate '7 Hardware' scripts.

Add-Tweak -Id 'scaling-no-accel' -Category 'Hardware' -Kind Group -Name 'Higher scaling with no mouse acceleration' -Risk Safe `
    -Description 'Pick a display scale with the matching mouse settings' `
    -Actions @(
        @{ Name = '100%'; Description = 'Higher scaling with no mouse acceleration: 100%'; Button = 'Apply'; Block = {
        Write-Host "Higher Scaling With No Acceleration`n"
# 100

# 6-11 pointer speed
cmd /c "reg add `"HKCU\Control Panel\Mouse`" /v `"MouseSensitivity`" /t REG_SZ /d `"10`" /f >nul 2>&1"

# disable enhance pointer precision
cmd /c "reg add `"HKCU\Control Panel\Mouse`" /v `"MouseSpeed`" /t REG_SZ /d `"0`" /f >nul 2>&1"
cmd /c "reg add `"HKCU\Control Panel\Mouse`" /v `"MouseThreshold1`" /t REG_SZ /d `"0`" /f >nul 2>&1"
cmd /c "reg add `"HKCU\Control Panel\Mouse`" /v `"MouseThreshold2`" /t REG_SZ /d `"0`" /f >nul 2>&1"

# mouse curve default
cmd /c "reg add `"HKCU\Control Panel\Mouse`" /v `"SmoothMouseXCurve`" /t REG_BINARY /d `"0000000000000000c0cc0c00000000008099190000000000406626000000000000333300000000000`" /f >nul 2>&1"
cmd /c "reg add `"HKCU\Control Panel\Mouse`" /v `"SmoothMouseYCurve`" /t REG_BINARY /d `"0000000000000000000038000000000000007000000000000000a800000000000000e00000000000`" /f >nul 2>&1"

# use custom scaling
cmd /c "reg add `"HKCU\Control Panel\Desktop`" /v `"Win8DpiScaling`" /t REG_DWORD /d `"1`" /f >nul 2>&1"

# dpi scaling 100%
cmd /c "reg add `"HKCU\Control Panel\Desktop`" /v `"LogPixels`" /t REG_DWORD /d `"96`" /f >nul 2>&1"

# disable fix scaling for apps
cmd /c "reg add `"HKCU\Control Panel\Desktop`" /v `"EnablePerProcessSystemDPI`" /t REG_DWORD /d `"0`" /f >nul 2>&1"
        }},
        @{ Name = '125%'; Description = 'Higher scaling with no mouse acceleration: 125%'; Button = 'Apply'; Block = {
        Write-Host "Higher Scaling With No Acceleration`n"
# 125

# 6-11 pointer speed
cmd /c "reg add `"HKCU\Control Panel\Mouse`" /v `"MouseSensitivity`" /t REG_SZ /d `"10`" /f >nul 2>&1"

# enable enhance pointer precision
cmd /c "reg add `"HKCU\Control Panel\Mouse`" /v `"MouseSpeed`" /t REG_SZ /d `"1`" /f >nul 2>&1"
cmd /c "reg add `"HKCU\Control Panel\Mouse`" /v `"MouseThreshold1`" /t REG_SZ /d `"6`" /f >nul 2>&1"
cmd /c "reg add `"HKCU\Control Panel\Mouse`" /v `"MouseThreshold2`" /t REG_SZ /d `"10`" /f >nul 2>&1"

# mouse curve 125% scaling
cmd /c "reg add `"HKCU\Control Panel\Mouse`" /v `"SmoothMouseXCurve`" /t REG_BINARY /d `"00000000000000000000100000000000000020000000000000003000000000000000400000000000`" /f >nul 2>&1"
cmd /c "reg add `"HKCU\Control Panel\Mouse`" /v `"SmoothMouseYCurve`" /t REG_BINARY /d `"00000000000000000000380000000000000070000000000000A800000000000000E0000000000000`" /f >nul 2>&1"

# use custom scaling
cmd /c "reg add `"HKCU\Control Panel\Desktop`" /v `"Win8DpiScaling`" /t REG_DWORD /d `"1`" /f >nul 2>&1"

# dpi scaling 125%
cmd /c "reg add `"HKCU\Control Panel\Desktop`" /v `"LogPixels`" /t REG_DWORD /d `"120`" /f >nul 2>&1"

# enable fix scaling for apps
cmd /c "reg add `"HKCU\Control Panel\Desktop`" /v `"EnablePerProcessSystemDPI`" /t REG_DWORD /d `"1`" /f >nul 2>&1"
        }},
        @{ Name = '150%'; Description = 'Higher scaling with no mouse acceleration: 150%'; Button = 'Apply'; Block = {
        Write-Host "Higher Scaling With No Acceleration`n"
# 150

# 6-11 pointer speed
cmd /c "reg add `"HKCU\Control Panel\Mouse`" /v `"MouseSensitivity`" /t REG_SZ /d `"10`" /f >nul 2>&1"

# enable enhance pointer precision
cmd /c "reg add `"HKCU\Control Panel\Mouse`" /v `"MouseSpeed`" /t REG_SZ /d `"1`" /f >nul 2>&1"
cmd /c "reg add `"HKCU\Control Panel\Mouse`" /v `"MouseThreshold1`" /t REG_SZ /d `"6`" /f >nul 2>&1"
cmd /c "reg add `"HKCU\Control Panel\Mouse`" /v `"MouseThreshold2`" /t REG_SZ /d `"10`" /f >nul 2>&1"

# mouse curve 150% scaling
cmd /c "reg add `"HKCU\Control Panel\Mouse`" /v `"SmoothMouseXCurve`" /t REG_BINARY /d `"0000000000000000303313000000000060662600000000009099390000000000C0CC4C0000000000`" /f >nul 2>&1"
cmd /c "reg add `"HKCU\Control Panel\Mouse`" /v `"SmoothMouseYCurve`" /t REG_BINARY /d `"0000000000000000000038000000000000007000000000000000A800000000000000E00000000000`" /f >nul 2>&1"

# use custom scaling
cmd /c "reg add `"HKCU\Control Panel\Desktop`" /v `"Win8DpiScaling`" /t REG_DWORD /d `"1`" /f >nul 2>&1"

# dpi scaling 150%
cmd /c "reg add `"HKCU\Control Panel\Desktop`" /v `"LogPixels`" /t REG_DWORD /d `"144`" /f >nul 2>&1"

# enable fix scaling for apps
cmd /c "reg add `"HKCU\Control Panel\Desktop`" /v `"EnablePerProcessSystemDPI`" /t REG_DWORD /d `"1`" /f >nul 2>&1"
        }},
        @{ Name = '175%'; Description = 'Higher scaling with no mouse acceleration: 175%'; Button = 'Apply'; Block = {
        Write-Host "Higher Scaling With No Acceleration`n"
# 175

# 6-11 pointer speed
cmd /c "reg add `"HKCU\Control Panel\Mouse`" /v `"MouseSensitivity`" /t REG_SZ /d `"10`" /f >nul 2>&1"

# enable enhance pointer precision
cmd /c "reg add `"HKCU\Control Panel\Mouse`" /v `"MouseSpeed`" /t REG_SZ /d `"1`" /f >nul 2>&1"
cmd /c "reg add `"HKCU\Control Panel\Mouse`" /v `"MouseThreshold1`" /t REG_SZ /d `"6`" /f >nul 2>&1"
cmd /c "reg add `"HKCU\Control Panel\Mouse`" /v `"MouseThreshold2`" /t REG_SZ /d `"10`" /f >nul 2>&1"

# mouse curve 175% scaling
cmd /c "reg add `"HKCU\Control Panel\Mouse`" /v `"SmoothMouseXCurve`" /t REG_BINARY /d `"00000000000000006066160000000000C0CC2C000000000020334300000000008099590000000000`" /f >nul 2>&1"
cmd /c "reg add `"HKCU\Control Panel\Mouse`" /v `"SmoothMouseYCurve`" /t REG_BINARY /d `"00000000000000000000380000000000000070000000000000A800000000000000E0000000000000`" /f >nul 2>&1"

# use custom scaling
cmd /c "reg add `"HKCU\Control Panel\Desktop`" /v `"Win8DpiScaling`" /t REG_DWORD /d `"1`" /f >nul 2>&1"

# dpi scaling 175%
cmd /c "reg add `"HKCU\Control Panel\Desktop`" /v `"LogPixels`" /t REG_DWORD /d `"168`" /f >nul 2>&1"

# enable fix scaling for apps
cmd /c "reg add `"HKCU\Control Panel\Desktop`" /v `"EnablePerProcessSystemDPI`" /t REG_DWORD /d `"1`" /f >nul 2>&1"
        }},
        @{ Name = '200%'; Description = 'Higher scaling with no mouse acceleration: 200%'; Button = 'Apply'; Block = {
        Write-Host "Higher Scaling With No Acceleration`n"
# 200

# 6-11 pointer speed
cmd /c "reg add `"HKCU\Control Panel\Mouse`" /v `"MouseSensitivity`" /t REG_SZ /d `"10`" /f >nul 2>&1"

# enable enhance pointer precision
cmd /c "reg add `"HKCU\Control Panel\Mouse`" /v `"MouseSpeed`" /t REG_SZ /d `"1`" /f >nul 2>&1"
cmd /c "reg add `"HKCU\Control Panel\Mouse`" /v `"MouseThreshold1`" /t REG_SZ /d `"6`" /f >nul 2>&1"
cmd /c "reg add `"HKCU\Control Panel\Mouse`" /v `"MouseThreshold2`" /t REG_SZ /d `"10`" /f >nul 2>&1"

# mouse curve 200% scaling
cmd /c "reg add `"HKCU\Control Panel\Mouse`" /v `"SmoothMouseXCurve`" /t REG_BINARY /d `"00000000000000009099190000000000203333000000000B0CC4C000000000040666600000000000`" /f >nul 2>&1"
cmd /c "reg add `"HKCU\Control Panel\Mouse`" /v `"SmoothMouseYCurve`" /t REG_BINARY /d `"00000000000000000000380000000000000070000000000000A800000000000000E0000000000000`" /f >nul 2>&1"

# use custom scaling
cmd /c "reg add `"HKCU\Control Panel\Desktop`" /v `"Win8DpiScaling`" /t REG_DWORD /d `"1`" /f >nul 2>&1"

# dpi scaling 200%
cmd /c "reg add `"HKCU\Control Panel\Desktop`" /v `"LogPixels`" /t REG_DWORD /d `"192`" /f >nul 2>&1"

# enable fix scaling for apps
cmd /c "reg add `"HKCU\Control Panel\Desktop`" /v `"EnablePerProcessSystemDPI`" /t REG_DWORD /d `"1`" /f >nul 2>&1"
        }},
        @{ Name = '225%'; Description = 'Higher scaling with no mouse acceleration: 225%'; Button = 'Apply'; Block = {
        Write-Host "Higher Scaling With No Acceleration`n"
# 225

# 6-11 pointer speed
cmd /c "reg add `"HKCU\Control Panel\Mouse`" /v `"MouseSensitivity`" /t REG_SZ /d `"10`" /f >nul 2>&1"

# enable enhance pointer precision
cmd /c "reg add `"HKCU\Control Panel\Mouse`" /v `"MouseSpeed`" /t REG_SZ /d `"1`" /f >nul 2>&1"
cmd /c "reg add `"HKCU\Control Panel\Mouse`" /v `"MouseThreshold1`" /t REG_SZ /d `"6`" /f >nul 2>&1"
cmd /c "reg add `"HKCU\Control Panel\Mouse`" /v `"MouseThreshold2`" /t REG_SZ /d `"10`" /f >nul 2>&1"

# mouse curve 225% scaling
cmd /c "reg add `"HKCU\Control Panel\Mouse`" /v `"SmoothMouseXCurve`" /t REG_BINARY /d `"0000000000000000C0CC1C0000000000809939000000000040665600000000000033730000000000`" /f >nul 2>&1"
cmd /c "reg add `"HKCU\Control Panel\Mouse`" /v `"SmoothMouseYCurve`" /t REG_BINARY /d `"0000000000000000000038000000000000007000000000000000A800000000000000E00000000000`" /f >nul 2>&1"

# use custom scaling
cmd /c "reg add `"HKCU\Control Panel\Desktop`" /v `"Win8DpiScaling`" /t REG_DWORD /d `"1`" /f >nul 2>&1"

# dpi scaling 225%
cmd /c "reg add `"HKCU\Control Panel\Desktop`" /v `"LogPixels`" /t REG_DWORD /d `"216`" /f >nul 2>&1"

# enable fix scaling for apps
cmd /c "reg add `"HKCU\Control Panel\Desktop`" /v `"EnablePerProcessSystemDPI`" /t REG_DWORD /d `"1`" /f >nul 2>&1"
        }},
        @{ Name = '250%'; Description = 'Higher scaling with no mouse acceleration: 250%'; Button = 'Apply'; Block = {
        Write-Host "Higher Scaling With No Acceleration`n"
# 250

# 6-11 pointer speed
cmd /c "reg add `"HKCU\Control Panel\Mouse`" /v `"MouseSensitivity`" /t REG_SZ /d `"10`" /f >nul 2>&1"

# enable enhance pointer precision
cmd /c "reg add `"HKCU\Control Panel\Mouse`" /v `"MouseSpeed`" /t REG_SZ /d `"1`" /f >nul 2>&1"
cmd /c "reg add `"HKCU\Control Panel\Mouse`" /v `"MouseThreshold1`" /t REG_SZ /d `"6`" /f >nul 2>&1"
cmd /c "reg add `"HKCU\Control Panel\Mouse`" /v `"MouseThreshold2`" /t REG_SZ /d `"10`" /f >nul 2>&1"

# mouse curve 250% scaling
cmd /c "reg add `"HKCU\Control Panel\Mouse`" /v `"SmoothMouseXCurve`" /t REG_BINARY /d `"00000000000000000000200000000000000040000000000000006000000000000000800000000000`" /f >nul 2>&1"
cmd /c "reg add `"HKCU\Control Panel\Mouse`" /v `"SmoothMouseYCurve`" /t REG_BINARY /d `"00000000000000000000380000000000000070000000000000A800000000000000E0000000000000`" /f >nul 2>&1"

# use custom scaling
cmd /c "reg add `"HKCU\Control Panel\Desktop`" /v `"Win8DpiScaling`" /t REG_DWORD /d `"1`" /f >nul 2>&1"

# dpi scaling 250%
cmd /c "reg add `"HKCU\Control Panel\Desktop`" /v `"LogPixels`" /t REG_DWORD /d `"240`" /f >nul 2>&1"

# enable fix scaling for apps
cmd /c "reg add `"HKCU\Control Panel\Desktop`" /v `"EnablePerProcessSystemDPI`" /t REG_DWORD /d `"1`" /f >nul 2>&1"
        }},
        @{ Name = '300%'; Description = 'Higher scaling with no mouse acceleration: 300%'; Button = 'Apply'; Block = {
        Write-Host "Higher Scaling With No Acceleration`n"
# 300

# 6-11 pointer speed
cmd /c "reg add `"HKCU\Control Panel\Mouse`" /v `"MouseSensitivity`" /t REG_SZ /d `"10`" /f >nul 2>&1"

# enable enhance pointer precision
cmd /c "reg add `"HKCU\Control Panel\Mouse`" /v `"MouseSpeed`" /t REG_SZ /d `"1`" /f >nul 2>&1"
cmd /c "reg add `"HKCU\Control Panel\Mouse`" /v `"MouseThreshold1`" /t REG_SZ /d `"6`" /f >nul 2>&1"
cmd /c "reg add `"HKCU\Control Panel\Mouse`" /v `"MouseThreshold2`" /t REG_SZ /d `"10`" /f >nul 2>&1"

# mouse curve 300% scaling
cmd /c "reg add `"HKCU\Control Panel\Mouse`" /v `"SmoothMouseXCurve`" /t REG_BINARY /d `"00000000000000006066260000000000C0CC4C000000000020337300000000008099990000000000`" /f >nul 2>&1"
cmd /c "reg add `"HKCU\Control Panel\Mouse`" /v `"SmoothMouseYCurve`" /t REG_BINARY /d `"00000000000000000000380000000000000070000000000000A800000000000000E0000000000000`" /f >nul 2>&1"

# use custom scaling
cmd /c "reg add `"HKCU\Control Panel\Desktop`" /v `"Win8DpiScaling`" /t REG_DWORD /d `"1`" /f >nul 2>&1"

# dpi scaling 300%
cmd /c "reg add `"HKCU\Control Panel\Desktop`" /v `"LogPixels`" /t REG_DWORD /d `"288`" /f >nul 2>&1"

# enable fix scaling for apps
cmd /c "reg add `"HKCU\Control Panel\Desktop`" /v `"EnablePerProcessSystemDPI`" /t REG_DWORD /d `"1`" /f >nul 2>&1"
        }},
        @{ Name = '350%'; Description = 'Higher scaling with no mouse acceleration: 350%'; Button = 'Apply'; Block = {
        Write-Host "Higher Scaling With No Acceleration`n"
# 350

# 6-11 pointer speed
cmd /c "reg add `"HKCU\Control Panel\Mouse`" /v `"MouseSensitivity`" /t REG_SZ /d `"10`" /f >nul 2>&1"

# enable enhance pointer precision
cmd /c "reg add `"HKCU\Control Panel\Mouse`" /v `"MouseSpeed`" /t REG_SZ /d `"1`" /f >nul 2>&1"
cmd /c "reg add `"HKCU\Control Panel\Mouse`" /v `"MouseThreshold1`" /t REG_SZ /d `"6`" /f >nul 2>&1"
cmd /c "reg add `"HKCU\Control Panel\Mouse`" /v `"MouseThreshold2`" /t REG_SZ /d `"10`" /f >nul 2>&1"

# mouse curve 350% scaling
cmd /c "reg add `"HKCU\Control Panel\Mouse`" /v `"SmoothMouseXCurve`" /t REG_BINARY /d `"0000000000000000C0CC2C000000000080995900000000004066860000000000003B300000000000`" /f >nul 2>&1"
cmd /c "reg add `"HKCU\Control Panel\Mouse`" /v `"SmoothMouseYCurve`" /t REG_BINARY /d `"00000000000000000000380000000000000070000000000000A800000000000000E0000000000000`" /f >nul 2>&1"

# use custom scaling
cmd /c "reg add `"HKCU\Control Panel\Desktop`" /v `"Win8DpiScaling`" /t REG_DWORD /d `"1`" /f >nul 2>&1"

# dpi scaling 350%
cmd /c "reg add `"HKCU\Control Panel\Desktop`" /v `"LogPixels`" /t REG_DWORD /d `"336`" /f >nul 2>&1"

# enable fix scaling for apps
cmd /c "reg add `"HKCU\Control Panel\Desktop`" /v `"EnablePerProcessSystemDPI`" /t REG_DWORD /d `"1`" /f >nul 2>&1"
        }}
    )

Add-Tweak -Id 'bg-polling-cap' -Category 'Hardware' -Name 'Background polling rate cap' -Risk Safe `
    -Description 'Remove the background polling rate cap (Default is 125 Hz)' `
    -Apply {
        Write-Host "Background Polling Rate Cap:`n"
# unlock background polling rate cap
cmd /c "reg add `"HKCU\Control Panel\Mouse`" /v `"RawMouseThrottleEnabled`" /t REG_DWORD /d `"0`" /f >nul 2>&1"
    } `
    -Revert {
        Write-Host "Background Polling Rate Cap:`n"
# revert unlock background polling rate cap
cmd /c "reg delete `"HKCU\Control Panel\Mouse`" /v `"RawMouseThrottleEnabled`" /f >nul 2>&1"
    }

Add-Tweak -Id 'mouse-polling-test' -Category 'Hardware' -Kind Action -Button 'Install' -Name 'Mouse polling rate test' -Risk Safe `
    -Description 'Install Mouse Movement Recorder to test polling rate' `
    -Apply {
if (-not (Test-Connection -ComputerName '8.8.8.8' -Count 1 -Quiet -ErrorAction SilentlyContinue)) { Write-Log 'Internet connection required'; return }
Write-Host "Installing: Mouse Movement Recorder...`n"

# new folder
New-Item -Path "$env:SystemDrive\Program Files (x86)\Mouse Movement Recorder" -ItemType Directory -Force -ErrorAction SilentlyContinue | Out-Null

# download mouse movement recorder
IWR "https://github.com/isleap9/AkariOS-Files/releases/download/Files/mousemovementrecorder.exe" -OutFile "$env:SystemDrive\Program Files (x86)\Mouse Movement Recorder\Mouse Movement Recorder.exe"

# create desktop shortcut
$WshShell = New-Object -comObject WScript.Shell
$Desktop = (New-Object -ComObject Shell.Application).Namespace('shell:Desktop').Self.Path
$Shortcut = $WshShell.CreateShortcut("$Desktop\Mouse Movement Recorder.lnk")
$Shortcut.TargetPath = "$env:SystemDrive\Program Files (x86)\Mouse Movement Recorder\Mouse Movement Recorder.exe"
$Shortcut.WorkingDirectory = "$env:SystemDrive\Program Files (x86)\Mouse Movement Recorder"
$Shortcut.IconLocation = "%SystemRoot%\System32\shell32.dll,248"
$Shortcut.Save()

# create start menu shortcut
$WshShell = New-Object -comObject WScript.Shell
$Shortcut = $WshShell.CreateShortcut("$env:ProgramData\Microsoft\Windows\Start Menu\Programs\Mouse Movement Recorder.lnk")
$Shortcut.TargetPath = "$env:SystemDrive\Program Files (x86)\Mouse Movement Recorder\Mouse Movement Recorder.exe"
$Shortcut.WorkingDirectory = "$env:SystemDrive\Program Files (x86)\Mouse Movement Recorder"
$Shortcut.IconLocation = "%SystemRoot%\System32\shell32.dll,248"
$Shortcut.Save()

# open mouse movement recorder
Start-Process "$env:SystemDrive\Program Files (x86)\Mouse Movement Recorder\Mouse Movement Recorder.exe"

Write-Host "Mouse optimizations:`n"
Write-Host "- Turn off motion sync"
Write-Host "- Keep dongle close to mouse"
Write-Host "- Disable angle snapping"
Write-Host "- Set lowest debounce time"
Write-Host "- Use maximum polling rate"
Write-Host "- USB port closest to the CPU`n"
Write-Host "Extreme polling may affect lower end CPU's & certain game engine framerates`n"
Write-Host "Set a comfortable DPI"
Write-Host "Increased DPI reduces pixel skipping & latency`n"
Write-Host "Suggested minimal DPI to reduce pixel skipping:`n"
Write-Host "- 400dpi for 1080p"
Write-Host "- 800dpi for 1440p"
Write-Host "- 1600dpi for 4k`n"
Write-Host "To prevent mouse acceleration when gaming:`n"
Write-Host "- Use 100% scaling"
Write-Host "- Set 6/11 & pointer precision off"
Write-Host "- Enable raw input in games when possible`n"
Write-Host "Some game engines may override 100% scaling for 4K, higher resolutions & laptops"
Write-Host "Scaling may need to manually locked at 100% through Advanced Scaling Settings`n"
Write-Host "For higher scaling with no acceleration see 'Scaling Higher No Accel.ps1'`n"

Pause
    }

Add-Tweak -Id 'controller-oc' -Category 'Hardware' -Kind Action -Button 'Install' -Name 'Controller overclock' -Risk Caution `
    -Description 'Install hidusbf to overclock controller polling' `
    -Apply {
if (-not (Test-Connection -ComputerName '8.8.8.8' -Count 1 -Quiet -ErrorAction SilentlyContinue)) { Write-Log 'Internet connection required'; return }
Write-Host "Installing: hidusbf..."

# download hidusbf
IWR "https://github.com/isleap9/AkariOS-Files/releases/download/Files/hidusbf.zip" -OutFile "$env:SystemRoot\Temp\hidusbf.zip"

# extract file
Expand-Archive -Path "$env:SystemRoot\Temp\hidusbf.zip" -DestinationPath "$env:SystemDrive\Program Files (x86)\hidusbf" -Force

# move files
Move-Item -Path "$env:SystemDrive\Program Files (x86)\hidusbf\hidusbf (BB11.5.25)\*" -Destination "$env:SystemDrive\Program Files (x86)\hidusbf" -Force

# delete folder
Remove-Item "$env:SystemDrive\Program Files (x86)\hidusbf\hidusbf (BB11.5.25)" -Recurse -Force -ErrorAction SilentlyContinue | Out-Null

# create desktop shortcut
$WshShell = New-Object -comObject WScript.Shell
$Desktop = (New-Object -ComObject Shell.Application).Namespace('shell:Desktop').Self.Path
$Shortcut = $WshShell.CreateShortcut("$Desktop\Setup.lnk")
$Shortcut.TargetPath = "$env:SystemDrive\Program Files (x86)\hidusbf\DRIVER\Setup.exe"
$Shortcut.WorkingDirectory = "$env:SystemDrive\Program Files (x86)\hidusbf\DRIVER"
$Shortcut.Save()

# create start menu shortcut
$WshShell = New-Object -comObject WScript.Shell
$Shortcut = $WshShell.CreateShortcut("$env:ProgramData\Microsoft\Windows\Start Menu\Programs\Setup.lnk")
$Shortcut.TargetPath = "$env:SystemDrive\Program Files (x86)\hidusbf\DRIVER\Setup.exe"
$Shortcut.WorkingDirectory = "$env:SystemDrive\Program Files (x86)\hidusbf\DRIVER"
$Shortcut.Save()

# install hidusbf_as.inf
Start-Process -FilePath "rundll32.exe" -ArgumentList "setupapi.dll,InstallHinfSection DefaultInstall 132 $env:SystemDrive\Program Files (x86)\hidusbf\DRIVER\HIDUSBF_AS.INF" -Wait
    }

Add-Tweak -Id 'controller-polling-test' -Category 'Hardware' -Kind Action -Button 'Install' -Name 'Controller polling rate test' -Risk Safe `
    -Description 'Install a tool to test controller polling rate' `
    -Apply {
if (-not (Test-Connection -ComputerName '8.8.8.8' -Count 1 -Quiet -ErrorAction SilentlyContinue)) { Write-Log 'Internet connection required'; return }
Write-Host "Installing: Polling..."

# new folder
New-Item -Path "$env:SystemDrive\Program Files (x86)\Polling" -ItemType Directory -Force -ErrorAction SilentlyContinue | Out-Null

# download gamepadla
IWR "https://github.com/isleap9/AkariOS-Files/releases/download/Files/polling.exe" -OutFile "$env:SystemDrive\Program Files (x86)\Polling\Polling.exe"

# create desktop shortcut
$WshShell = New-Object -comObject WScript.Shell
$Desktop = (New-Object -ComObject Shell.Application).Namespace('shell:Desktop').Self.Path
$Shortcut = $WshShell.CreateShortcut("$Desktop\Polling.lnk")
$Shortcut.TargetPath = "$env:SystemDrive\Program Files (x86)\Polling\Polling.exe"
$Shortcut.WorkingDirectory = "$env:SystemDrive\Program Files (x86)\Polling"
$Shortcut.Save()

# create start menu shortcut
$WshShell = New-Object -comObject WScript.Shell
$Shortcut = $WshShell.CreateShortcut("$env:ProgramData\Microsoft\Windows\Start Menu\Programs\Polling.lnk")
$Shortcut.TargetPath = "$env:SystemDrive\Program Files (x86)\Polling\Polling.exe"
$Shortcut.WorkingDirectory = "$env:SystemDrive\Program Files (x86)\Polling"
$Shortcut.Save()

# open gamepadla
Start-Process "$env:SystemDrive\Program Files (x86)\Polling\Polling.exe"
    }

Add-Tweak -Id 'monitor-opt' -Category 'Hardware' -Kind Action -Button 'Open' -Name 'Monitor optimization' -Risk Safe `
    -Description 'Open a refresh rate test and show monitor tips' `
    -Apply {
# open test ufo
Start-Process "https://www.testufo.com/framerates#count=6&background=none&pps=1920"

Write-Host "Monitor optimizations:"
Write-Host "- Enable overclock mode"
Write-Host "- Run highest refresh rate"
Write-Host "- Disable adaptive brightness and variable back light"
Write-Host "- Turn off variable refresh rate, adaptive sync and g-sync"
Write-Host "- Adjust color, brightness and sharpening to your preference"
Write-Host "- Max overdrive without causing overshoot or reducing motion clarity`n"

Pause
    }

Add-Tweak -Id 'bufferbloat' -Category 'Hardware' -Kind Action -Button 'Open' -Name 'Network bufferbloat test' -Risk Safe `
    -Description 'Open the bufferbloat test website' `
    -Apply {
Start-Process "https://www.waveform.com/tools/bufferbloat"
    }

Add-Tweak -Id 'pc-build' -Category 'Hardware' -Kind Action -Button 'Open' -Name 'PC build guide' -Risk Safe `
    -Description 'Open the PC build guide' `
    -Apply {
Start-Process "https://pcpartpicker.com/user/fr33thy/saved"
    }
