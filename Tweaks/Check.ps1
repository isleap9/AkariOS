# Check category. GENERATED from the AkariOS-Ultimate '1 Check' scripts.

Add-Tweak -Id 'bios-check' -Category 'Check' -Kind Action -Button 'Open' -Name 'BIOS check' -Risk Safe `
    -Description 'Search your motherboard model online to check for BIOS updates' `
    -Apply {
if (-not (Test-Connection -ComputerName '8.8.8.8' -Count 1 -Quiet -ErrorAction SilentlyContinue)) { Write-Log 'Internet connection required'; return }
# allow password sign in
cmd /c "reg add `"HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\PasswordLess\Device`" /v `"DevicePasswordLessBuildVersion`" /t REG_DWORD /d `"0`" /f >nul 2>&1"

# get motherboard id
$instanceID = (Get-CimInstance Win32_BaseBoard).Product
$query = [uri]::EscapeDataString($instanceID)

# search motherboard id in web browser
Start-Process "https://www.google.com/search?q=$query"

Write-Host "BIOS CHECK"
Write-Host "----------"
Write-Host "UPDATE BIOS & OPTIMIZE SETTINGS`n"
Write-Host "INTEL CPU"
Write-Host "- ENABLE ram profile (XMP DOCP EXPO)"
Write-Host "- DISABLE c-state (K CHIPS ONLY)"
Write-Host "- ENABLE resizable bar (REBAR C.A.M)`n"
Write-Host "AMD CPU"
Write-Host "- ENABLE ram profile (XMP DOCP EXPO)"
Write-Host "- ENABLE precision boost overdrive (PBO)"
Write-Host "- ENABLE resizable bar (REBAR C.A.M)`n"
Write-Host "DISABLE unused features (BT/WIFI/IGPU/ETC)`n"
Write-Host "DISABLE driver installer software"
Write-Host "- Asus armory crate"
Write-Host "- MSI driver utility"
Write-Host "- Gigabyte update utility"
Write-Host "- Asrock motherboard utility`n"
Write-Host "MAX pump and set fans to performance`n"
Write-Host "ENABLE for anticheat games"
Write-Host "- TPM"
Write-Host "- Secure boot`n"

Write-Host "Press Enter to Restart to BIOS" -ForegroundColor Red
Pause

# restart to bios
cmd /c C:\Windows\System32\shutdown.exe /r /fw /t 0
    }

Add-Tweak -Id 'storage-check' -Category 'Check' -Kind Action -Button 'Check' -Name 'Storage check' -Risk Safe `
    -Description 'Show drive space and storage tips' `
    -Apply {
Write-Host "STORAGE CHECK"
Write-Host "-------------"
Write-Host "- Keep SSD's at least 10% free"
Write-Host "- Stick with internal SSD's or NVME's"
Write-Host "- Avoid installing windows & games on HDD's & external drives`n"

# show space for all drives
Get-Volume | Where-Object {$_.DriveLetter} | Sort-Object DriveLetter | ForEach-Object {
try {
$percentRemain = ($_.SizeRemaining / $_.Size) * 100
Write-Host "$($_.DriveLetter): Free space = $($percentRemain.ToString().substring(0,4))%"
} catch {}
}

# open file explorer
Start-Process explorer shell:MyComputerFolder

Write-Host ""

Pause
    }

Add-Tweak -Id 'ram-check' -Category 'Check' -Kind Action -Button 'Check' -Name 'RAM check' -Risk Safe `
    -Description 'Download CPU-Z and show RAM tips' `
    -Apply {
if (-not (Test-Connection -ComputerName '8.8.8.8' -Count 1 -Quiet -ErrorAction SilentlyContinue)) { Write-Log 'Internet connection required'; return }
Write-Host "Downloading: Cpu Z..."

# download cpuz
IWR "https://github.com/isleap9/AkariOS-Files/releases/download/Files/cpuz.exe" -OutFile "$env:SystemRoot\Temp\cpuz.exe"

# start cpuz
Start-Process "$env:SystemRoot\Temp\cpuz.exe"

Write-Host "RAM CHECK"
Write-Host "---------"
Write-Host "- Check RAM profile is enabled"
Write-Host "- Verify RAM is in the correct slots"
Write-Host "- Confirm there is no mismatch in RAM modules"
Write-Host "- At least two RAM sticks (dual channel) is ideal`n"

Pause
    }

Add-Tweak -Id 'gpu-check' -Category 'Check' -Kind Action -Button 'Check' -Name 'GPU check' -Risk Safe `
    -Description 'Download GPU-Z and show GPU tips' `
    -Apply {
if (-not (Test-Connection -ComputerName '8.8.8.8' -Count 1 -Quiet -ErrorAction SilentlyContinue)) { Write-Log 'Internet connection required'; return }
Write-Host "Downloading: Gpu Z..."

# download gpuz
IWR "https://github.com/isleap9/AkariOS-Files/releases/download/Files/gpuz.exe" -OutFile "$env:SystemRoot\Temp\gpuz.exe"

# start gpuz
Start-Process "$env:SystemRoot\Temp\gpuz.exe"

Write-Host "GPU CHECK"
Write-Host "---------"
Write-Host "- Check Video Bus is at maximum"
Write-Host "- Check Resizable BAR is enabled"
Write-Host "- Verify monitor cable is connected to the GPU"
Write-Host "- Confirm GPU is in the top PCIe motherboard slot"
Write-Host "- Running multiple graphics cards is not recommended`n"

Pause
    }

Add-Tweak -Id 'occt' -Category 'Check' -Kind Action -Button 'Open' -Name 'Storage, RAM and CPU test' -Risk Safe `
    -Description 'Download OCCT for stress tests and benchmarks' `
    -Apply {
if (-not (Test-Connection -ComputerName '8.8.8.8' -Count 1 -Quiet -ErrorAction SilentlyContinue)) { Write-Log 'Internet connection required'; return }
Write-Host "Downloading: OCCT..."

# download occt
IWR "https://github.com/isleap9/AkariOS-Files/releases/download/Files/occt.exe" -OutFile "$env:SystemRoot\Temp\occt.exe"

# start occt
Start-Process "$env:SystemRoot\Temp\occt.exe"

Write-Host "STORAGE RAM CPU TEST"
Write-Host "--------------------"
Write-Host "Run a STORAGE, RAM & CPU stress test"
Write-Host "Check temps, test errors, WHEA errors & storage errors"
Write-Host "Errors should not be ignored as they can lead to"
Write-Host "- Stutters and hitches"
Write-Host "- Corrupted Windows"
Write-Host "- Poor performance"
Write-Host "- Corrupted files"
Write-Host "- Black screens"
Write-Host "- Boot failure"
Write-Host "- Blue screens"
Write-Host "- Input lag"
Write-Host "- Shutdowns`n"
Write-Host "TROUBLESHOOTING"
Write-Host "---------------"
Write-Host "Basic troubleshooting for errors, crashes, issues or boot failure"
Write-Host "- RAM overheating? Typically over 55deg. (fix case flow/ram fan)"
Write-Host "- Unlucky CPU memory controller? (lower RAM speed)"
Write-Host "- CPU overheating? (repaste/retighten/RMA cooler)"
Write-Host "- Overclock? (turn it off/dial it down)"
Write-Host "- CPU cooler over tightened? (loosen)"
Write-Host "- RAM in wrong slots? (check manual)"
Write-Host "- BIOS bugged out? (clear CMOS)"
Write-Host "- Incompatible RAM? (check QVL)"
Write-Host "- BIOS out of date? (update)"
Write-Host "- Mismatched RAM? (replace)"
Write-Host "- Faulty motherboard? (RMA)"
Write-Host "- Faulty RAM stick? (RMA)"
Write-Host "- Bent CPU pin? (RMA)"
Write-Host "- Faulty CPU? (RMA)`n"
Write-Host "STORAGE RAM CPU BENCH"
Write-Host "---------------------"
Write-Host "Run a STORAGE, RAM & CPU benchmark"
Write-Host "- Compare results"
Write-Host "- Confirm hardware is performing optimally`n"

Pause
    }

Add-Tweak -Id 'furmark' -Category 'Check' -Kind Action -Button 'Open' -Name 'GPU test' -Risk Safe `
    -Description 'Download FurMark for GPU stress tests and benchmarks' `
    -Apply {
if (-not (Test-Connection -ComputerName '8.8.8.8' -Count 1 -Quiet -ErrorAction SilentlyContinue)) { Write-Log 'Internet connection required'; return }
Write-Host "Downloading: FurMark..."

# download furmark
IWR "https://github.com/isleap9/AkariOS-Files/releases/download/Files/furmark.zip" -OutFile "$env:SystemRoot\Temp\furmark.zip"

# extract files
Expand-Archive "$env:SystemRoot\Temp\furmark.zip" -DestinationPath "$env:SystemRoot\Temp\furmark" -ErrorAction SilentlyContinue

# start furmark
Start-Process "$env:SystemRoot\Temp\furmark\FurMark_win64\FurMark_GUI.exe"

Write-Host "GPU TEST"
Write-Host "--------"
Write-Host "Run GPU stress test`n"
Write-Host "TROUBLESHOOTING"
Write-Host "---------------"
Write-Host "Basic troubleshooting items to monitor"
Write-Host "- Temps"
Write-Host "- Framerate"
Write-Host "- Artifacts"
Write-Host "- Freezing"
Write-Host "- Driver crashes"
Write-Host "- Shutdowns"
Write-Host "- Blue screens`n"
Write-Host "GPU BENCH"
Write-Host "---------"
Write-Host "Run a GPU benchmark"
Write-Host "- Compare results"
Write-Host "- Confirm GPU is performing optimally`n"

Pause
    }
