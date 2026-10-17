#requires -Version 5.1
param([switch]$ShowConsole)
# Akari (Ink UI, vertical slice). Run:  powershell -ExecutionPolicy Bypass -File Akari.ps1

# ---- elevate once, and make sure we are STA (WPF needs it)
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]'Administrator')
$isSta = [Threading.Thread]::CurrentThread.GetApartmentState() -eq 'STA'
if (-not $isAdmin -or -not $isSta) {
    $style = if ($ShowConsole) { 'Normal' } else { 'Hidden' }
    $extra = if ($ShowConsole) { ' -ShowConsole' } else { '' }
    Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -STA -File `"$PSCommandPath`"$extra" -Verb RunAs -WindowStyle $style
    exit
}

Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase, System.Xaml
Add-Type -MemberDefinition @'
[DllImport("dwmapi.dll")] public static extern int DwmSetWindowAttribute(IntPtr hwnd, int attr, ref int val, int size);
[DllImport("user32.dll")] public static extern int GetWindowLong(IntPtr hwnd, int index);
[DllImport("user32.dll")] public static extern int SetWindowLong(IntPtr hwnd, int index, int value);
'@ -Name Dwm -Namespace Akari

$Root = $PSScriptRoot
if (-not $Root) { $Root = Split-Path -Parent $PSCommandPath }
# find the folder that really holds UI\ and Tweaks\ (handles a copy that ended up one level too deep or too high)
foreach ($c in @($Root, (Split-Path -Parent $Root), "$Root\Tweaks")) {
    if ($c -and (Test-Path "$c\UI\MainWindow.xaml") -and (Test-Path "$c\Tweaks")) { $Root = $c; break }
}
$LogFile = "$env:LOCALAPPDATA\Akari\akari.log"
function Write-ErrLog([string]$m) {
    try { New-Item (Split-Path $LogFile) -ItemType Directory -Force | Out-Null; Add-Content $LogFile ("[{0}] {1}" -f (Get-Date -Format s), $m) } catch { }
}
trap { Write-ErrLog "$($_.Exception.Message) $($_.InvocationInfo.PositionMessage)"; [void][Windows.MessageBox]::Show("Akari hit an error:`n`n$($_.Exception.Message)`n`n$($_.InvocationInfo.PositionMessage)", 'Akari'); exit }
# remove 'downloaded from the internet' marks so Windows never nags about these files
Get-ChildItem $Root -Filter *.ps1 -File -ErrorAction SilentlyContinue | Unblock-File -ErrorAction SilentlyContinue
foreach ($sub in 'Tweaks', 'UI') { Get-ChildItem "$Root\$sub" -Recurse -File -ErrorAction SilentlyContinue | Unblock-File -ErrorAction SilentlyContinue }
$script:Tweaks = [System.Collections.Generic.List[object]]::new()
$script:RowCache   = @{}
$script:Cat    = 'Home'
$script:Busy   = $false
$script:Job    = $null
$script:Queue  = [System.Collections.Concurrent.ConcurrentQueue[string]]::new()
$script:SpecData = $null
$script:SpecJob = $null
$script:SpecPending = $false
$script:CopiedUntil = $null
# a spec read still running after this many seconds is abandoned
$script:SpecTimeoutSec = 30
$script:SpecStale = [System.Collections.Generic.List[object]]::new()
$PrioKey = 'HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl'

function Add-Tweak {
    param([string]$Id, [string]$Category, [string]$Name, [string]$Description,
          [ValidateSet('Safe', 'Caution', 'Advanced')][string]$Risk = 'Safe',
          [ValidateSet('Toggle', 'Action', 'Group', 'Console')][string]$Kind = 'Toggle',
          [string]$Button = 'Run', [object[]]$Actions, [string]$Confirm, [string]$Script,
          [scriptblock]$Apply, [scriptblock]$Revert, [scriptblock]$Detect, [scriptblock]$Check)
    $script:Tweaks.Add([pscustomobject]@{ Id = $Id; Category = $Category; Name = $Name; Description = $Description
            Risk = $Risk; Kind = $Kind; Button = $Button; Actions = $Actions; Confirm = $Confirm; Script = $Script
            Apply = $Apply; Revert = $Revert; Detect = $Detect; Check = $Check })
}
foreach ($need in 'UI\MainWindow.xaml', 'Tweaks') {
    if (-not (Test-Path "$Root\$need")) {
        [void][Windows.MessageBox]::Show("Missing: $Root\$need`n`nAkari.ps1 needs UI, Tweaks and Assets folders next to it.", 'Akari')
        exit
    }
}
foreach ($f in Get-ChildItem "$Root\Tweaks" -Filter *.ps1 | Sort-Object Name) { . $f.FullName }

# ---- remembers what Akari last applied (used for the state dot when a tweak has no Detect)
$StateDir = "$env:LOCALAPPDATA\Akari"; $StatePath = "$StateDir\state.json"
$script:State = @{}
if (Test-Path $StatePath) {
    try { (Get-Content $StatePath -Raw | ConvertFrom-Json).PSObject.Properties | ForEach-Object { $script:State[$_.Name] = [bool]$_.Value } } catch { }
}
function Save-State {
    New-Item $StateDir -ItemType Directory -Force | Out-Null
    ($script:State | ConvertTo-Json) | Set-Content $StatePath
}

# ---- helpers that tweak scripts can use inside the background runspace
$Helpers = @'
$ProgressPreference = 'SilentlyContinue'
function Write-Log([string]$m) { if ($m -and $m.Trim()) { [void]$LogQueue.Enqueue($m.TrimEnd()) } }
function Write-Host {
    param([Parameter(Position = 0, ValueFromRemainingArguments = $true)]$Object, $ForegroundColor, $BackgroundColor, [switch]$NoNewline, $Separator = ' ')
    Write-Log (($Object | ForEach-Object { "$_" }) -join $Separator)
}
function Clear-Host { }
function show-menu { }
function Pause { }
function Read-Host {
    param([string]$Prompt = '')
    if ($Prompt) { Write-Log $Prompt }
    Add-Type -AssemblyName Microsoft.VisualBasic -ErrorAction SilentlyContinue
    $result = [Microsoft.VisualBasic.Interaction]::InputBox($Prompt, 'AkariOS-Ultimate')
    Write-Log "> $result"
    if ($result -eq '') { return $null }
    return $result
}
function Get-FilePath {
    param([string]$Filter = 'All Files (*.*)|*.*')
    Add-Type -AssemblyName System.Windows.Forms -ErrorAction SilentlyContinue
    $dlg = New-Object System.Windows.Forms.OpenFileDialog
    $dlg.Filter = $Filter
    $result = $dlg.ShowDialog()
    if ($result -eq [System.Windows.Forms.DialogResult]::OK) { return $dlg.FileName }
    return $null
}
function Get-FolderPath {
    param([string]$Description = 'Select a folder')
    $shell = New-Object -ComObject Shell.Application
    $folder = $shell.BrowseForFolder(0, $Description, 0x00000040)
    if ($folder) { return $folder.Self.Path }
    return $null
}
function Set-Reg($Path, $Name, $Value, $Type = 'DWord') {
    if (-not (Test-Path $Path)) { New-Item -Path $Path -Force | Out-Null }
    New-ItemProperty -Path $Path -Name $Name -Value $Value -PropertyType $Type -Force | Out-Null
}
function Remove-Reg($Path, $Name) { Remove-ItemProperty -Path $Path -Name $Name -ErrorAction SilentlyContinue }
function Run-Trusted([String]$command) {
    try { Stop-Service -Name TrustedInstaller -Force -ErrorAction Stop -WarningAction Stop }
    catch { taskkill /im trustedinstaller.exe /f >$null }
    $service = Get-CimInstance -ClassName Win32_Service -Filter "Name='TrustedInstaller'"
    $DefaultBinPath = $service.PathName
    $trustedInstallerPath = "$env:SystemRoot\servicing\TrustedInstaller.exe"
    if ($DefaultBinPath -ne $trustedInstallerPath) { $DefaultBinPath = $trustedInstallerPath }
    $bytes = [System.Text.Encoding]::Unicode.GetBytes($command)
    $base64Command = [Convert]::ToBase64String($bytes)
    sc.exe config TrustedInstaller binPath= "cmd.exe /c powershell.exe -encodedcommand $base64Command" | Out-Null
    sc.exe start TrustedInstaller | Out-Null
    sc.exe config TrustedInstaller binpath= "`"$DefaultBinPath`"" | Out-Null
    try { Stop-Service -Name TrustedInstaller -Force -ErrorAction Stop -WarningAction Stop }
    catch { taskkill /im trustedinstaller.exe /f >$null }
}
'@

$GetSpecsFunc = @'
function Test-SmbiosValue {
    param([string]$Value)
    if ([string]::IsNullOrWhiteSpace($Value)) { return $false }
    # common smbios placeholder strings
    $fillers = @(
        'To Be Filled By O.E.M.',
        'Default string',
        'None',
        'N/A',
        'Not Specified',
        'Not Available',
        'System Product Name',
        'System Manufacturer',
        'System Version',
        'System Serial Number',
        'Base Board Version',
        'Base Board Product',
        'Base Board Manufacturer',
        'BIOS Version',
        'BIOS Date',
        'x.x',
        '0'
    )
    $trimmed = $Value.Trim()
    if ($fillers -contains $trimmed) { return $false }
    return $true
}

function Get-Specs {
    $result = @{
        CPU = @{ _Status = 'OK' }
        RAM = @{ _Status = 'OK' }
        Windows = @{ _Status = 'OK' }
        GPU = @{ _Status = 'OK'; Adapters = @() }
        Disk = @{ _Status = 'OK'; Volumes = @() }
        Motherboard = @{ _Status = 'OK' }
    }

    # --- CPU ---
    $cpuModel = "Not available"
    $cpuCores = "Not available"
    $cpuThreads = "Not available"
    $cpuSpeedMHz = "Not available"
    # socket count is descriptive and not counted in the status
    $cpuSockets = "Not available"
    $cpuFields = 4
    $cpuSuccess = 0
    try {
        # every socket: cores and threads are summed, model and clock come from the first
        $cpus = @(Get-CimInstance -ClassName Win32_Processor -OperationTimeoutSec 10 -ErrorAction Stop)
        if ($cpus.Count -gt 0) {
            $cpu = $cpus[0]
            $sumCores = [int](($cpus | Measure-Object -Property NumberOfCores -Sum).Sum)
            $sumThreads = [int](($cpus | Measure-Object -Property NumberOfLogicalProcessors -Sum).Sum)
            $cpuSockets = $cpus.Count
            if ($cpu.Name) { $cpuModel = $cpu.Name.Trim(); $cpuSuccess++ }
            if ($sumCores -gt 0) { $cpuCores = $sumCores; $cpuSuccess++ }
            elseif ($sumThreads -gt 0) { $cpuCores = $sumThreads; $cpuSuccess++ }
            if ($sumThreads -gt 0) { $cpuThreads = $sumThreads; $cpuSuccess++ }
            if ($cpu.MaxClockSpeed -gt 0) { $cpuSpeedMHz = $cpu.MaxClockSpeed; $cpuSuccess++ }
        }
    } catch { }
    $result.CPU.Model = $cpuModel
    $result.CPU.Cores = $cpuCores
    $result.CPU.Threads = $cpuThreads
    $result.CPU.SpeedMHz = $cpuSpeedMHz
    $result.CPU.Sockets = $cpuSockets
    if ($cpuSuccess -eq 0) { $result.CPU._Status = 'Failed' }
    elseif ($cpuSuccess -lt $cpuFields) { $result.CPU._Status = 'Partial' }

    # --- RAM ---
    $ramTotalGB = "Not available"
    $ramUsedGB = "Not available"
    $ramFreeGB = "Not available"
    $ramFields = 3
    $ramSuccess = 0
    try {
        $os = Get-CimInstance -ClassName Win32_OperatingSystem -OperationTimeoutSec 10 -ErrorAction Stop
        if ($os -and $os.TotalVisibleMemorySize -gt 0) {
            $totalKB = $os.TotalVisibleMemorySize
            $freeKB = $os.FreePhysicalMemory
            $usedKB = $totalKB - $freeKB
            $ramTotalGB = [math]::Round($totalKB / 1MB, 1); $ramSuccess++
            $ramUsedGB = [math]::Round($usedKB / 1MB, 1); $ramSuccess++
            $ramFreeGB = [math]::Round($freeKB / 1MB, 1); $ramSuccess++
        }
    } catch { }
    $result.RAM.TotalGB = $ramTotalGB
    $result.RAM.UsedGB = $ramUsedGB
    $result.RAM.FreeGB = $ramFreeGB
    if ($ramSuccess -eq 0) { $result.RAM._Status = 'Failed' }
    elseif ($ramSuccess -lt $ramFields) { $result.RAM._Status = 'Partial' }

    # --- Windows ---
    $winEdition = "Not available"
    $winVersion = "Not available"
    $winBuild = "Not available"
    $winFields = 3
    $winSuccess = 0
    try {
        $os = Get-CimInstance -ClassName Win32_OperatingSystem -OperationTimeoutSec 10 -ErrorAction Stop
        if ($os) {
            if ($os.Caption) { $winEdition = $os.Caption; $winSuccess++ }
            if ($os.BuildNumber) { $winBuild = $os.BuildNumber; $winSuccess++ }
        }
    } catch { }
    try {
        $reg = Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -ErrorAction SilentlyContinue
        if ($reg) {
            if ($reg.UBR -and $winBuild -ne "Not available") { $winBuild = "$($winBuild).$($reg.UBR)"; $winSuccess++ }
            if ($reg.DisplayVersion) { $winVersion = $reg.DisplayVersion; $winSuccess++ }
            elseif ($reg.ReleaseId) { $winVersion = $reg.ReleaseId; $winSuccess++ }
        }
    } catch { }
    $result.Windows.Edition = $winEdition
    $result.Windows.Version = $winVersion
    $result.Windows.Build = $winBuild
    if ($winSuccess -eq 0) { $result.Windows._Status = 'Failed' }
    elseif ($winSuccess -lt $winFields) { $result.Windows._Status = 'Partial' }

    # --- GPU ---
    $gpuAdapters = @()
    $gpuFields = 3
    $gpuSuccess = 0
    $gpuTotal = 0
    try {
        $gpus = @(Get-CimInstance -ClassName Win32_VideoController -OperationTimeoutSec 10 -ErrorAction Stop)
        if ($gpus.Count -eq 0) {
            $result.GPU._Status = 'Failed'
        } else {
            # read real vram from display class registry (adapterram is uint32 and caps near 4gb)
            $regVram = @{}
            $regMatch = @()
            try {
                $regPath = 'HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}'
                $regKeys = Get-ChildItem -Path $regPath -ErrorAction SilentlyContinue | Where-Object { $_.PSChildName -match '^\d{4}$' } | Sort-Object PSChildName
                foreach ($key in $regKeys) {
                    $props = Get-ItemProperty -Path $key.PSPath -ErrorAction SilentlyContinue
                    if (-not $props) { continue }
                    # windows writes qwMemorySize; qwSize kept as legacy name
                    $qw = $props.'HardwareInformation.qwMemorySize'
                    if ($null -eq $qw) { $qw = $props.'HardwareInformation.qwSize' }
                    # some drivers store the size as reg_binary
                    if ($qw -is [byte[]]) {
                        if ($qw.Length -ge 8) { $qw = [BitConverter]::ToInt64($qw, 0) } else { $qw = $null }
                    }
                    if ($null -ne $qw -and $qw -gt 0) {
                        $regVram[$key.PSChildName] = $qw
                        if ($props.MatchingDeviceId) { $regMatch += ,@{ Id = [string]$props.MatchingDeviceId; Bytes = $qw } }
                    }
                }
            } catch { }

            for ($i = 0; $i -lt $gpus.Count; $i++) {
                $gpu = $gpus[$i]
                $adapter = @{ Model = 'Not available'; VRAM_GB = 'Not available'; DriverVersion = 'Not available'; Status = 'OK' }
                $gpuTotal += $gpuFields

                if ($gpu.Name) { $adapter.Model = $gpu.Name.Trim(); $gpuSuccess++ }

                $vramBytes = $gpu.AdapterRAM
                # 4294967295 (0xFFFFFFFF) or 4293918720 (0xFFF00000) mean the real size did not fit
                $vramCapped = ($vramBytes -eq 4294967295 -or $vramBytes -ge 4GB -or $vramBytes -ge 4293918720)
                if ($vramCapped) {
                    $regBytes = $null
                    # match registry key by pnp device id first, then by index
                    if ($gpu.PNPDeviceID) {
                        foreach ($m in $regMatch) {
                            if ($gpu.PNPDeviceID.StartsWith($m.Id, [StringComparison]::OrdinalIgnoreCase)) { $regBytes = $m.Bytes; break }
                        }
                    }
                    if ($null -eq $regBytes) {
                        $regKey = '{0:D4}' -f $i
                        if ($regVram.ContainsKey($regKey)) { $regBytes = $regVram[$regKey] }
                    }
                    if ($null -ne $regBytes) { $vramBytes = $regBytes; $vramCapped = $false }
                }
                if (-not $vramCapped -and $vramBytes -gt 0) {
                    $adapter.VRAM_GB = [math]::Round($vramBytes / 1GB, 1)
                    $gpuSuccess++
                }

                if ($gpu.DriverVersion) { $adapter.DriverVersion = $gpu.DriverVersion; $gpuSuccess++ }

                if ($gpu.Status -and $gpu.Status -ne 'OK') { $adapter.Status = $gpu.Status }

                $gpuAdapters += ,$adapter
            }
        }
    } catch {
        $result.GPU._Status = 'Failed'
    }
    $result.GPU.Adapters = $gpuAdapters
    if ($gpuSuccess -eq 0 -and $gpuTotal -gt 0) { $result.GPU._Status = 'Failed' }
    elseif ($gpuSuccess -lt $gpuTotal) { $result.GPU._Status = 'Partial' }

    # --- Disk ---
    $diskVolumes = @()
    # drive, filesystem, totalgb, freegb (label is descriptive and not counted)
    $diskFields = 4
    $diskSuccess = 0
    $diskTotal = 0
    try {
        # fixed drives only (drivetype 3)
        $disks = @(Get-CimInstance -ClassName Win32_LogicalDisk -OperationTimeoutSec 10 -ErrorAction Stop | Where-Object { $_.DriveType -eq 3 })
        if ($disks.Count -eq 0) {
            $result.Disk._Status = 'Failed'
        } else {
            foreach ($disk in $disks) {
                $vol = @{ Drive = 'Not available'; Label = ''; FileSystem = 'Not available'; TotalGB = 'Not available'; FreeGB = 'Not available' }
                $diskTotal += $diskFields

                if ($disk.DeviceID) { $vol.Drive = $disk.DeviceID; $diskSuccess++ }
                # empty label is a valid reading, not a failed field
                if ($disk.VolumeName) { $vol.Label = $disk.VolumeName }
                if ($disk.FileSystem) { $vol.FileSystem = $disk.FileSystem; $diskSuccess++ }
                if ($disk.Size -gt 0) { $vol.TotalGB = [math]::Round($disk.Size / 1GB, 1); $diskSuccess++ }
                # 0 bytes free is a real reading (full disk); only null means not reported
                if ($null -ne $disk.FreeSpace) { $vol.FreeGB = [math]::Round($disk.FreeSpace / 1GB, 1); $diskSuccess++ }

                $diskVolumes += ,$vol
            }
        }
    } catch {
        $result.Disk._Status = 'Failed'
    }
    $result.Disk.Volumes = $diskVolumes
    if ($diskSuccess -eq 0 -and $diskTotal -gt 0) { $result.Disk._Status = 'Failed' }
    elseif ($diskSuccess -lt $diskTotal) { $result.Disk._Status = 'Partial' }

    # --- Motherboard / BIOS ---
    $mbManufacturer = 'Not available'
    $mbProduct = 'Not available'
    $biosVersion = 'Not available'
    $biosDate = 'Not available'
    $mbFields = 4
    $mbSuccess = 0
    try {
        $board = Get-CimInstance -ClassName Win32_BaseBoard -OperationTimeoutSec 10 -ErrorAction Stop | Select-Object -First 1
        if ($board) {
            if (Test-SmbiosValue $board.Manufacturer) { $mbManufacturer = $board.Manufacturer.Trim(); $mbSuccess++ }
            if (Test-SmbiosValue $board.Product) { $mbProduct = $board.Product.Trim(); $mbSuccess++ }
        }
    } catch { }
    try {
        $bios = Get-CimInstance -ClassName Win32_BIOS -OperationTimeoutSec 10 -ErrorAction Stop | Select-Object -First 1
        if ($bios) {
            if (Test-SmbiosValue $bios.SMBIOSBIOSVersion) { $biosVersion = $bios.SMBIOSBIOSVersion.Trim(); $mbSuccess++ }
            # smbios date is midnight utc; format in utc with invariant culture so the day and calendar never shift
            if ($bios.ReleaseDate) { $biosDate = $bios.ReleaseDate.ToUniversalTime().ToString('yyyy-MM-dd', [Globalization.CultureInfo]::InvariantCulture); $mbSuccess++ }
        }
    } catch { }
    $result.Motherboard.Manufacturer = $mbManufacturer
    $result.Motherboard.Product = $mbProduct
    $result.Motherboard.BIOSVersion = $biosVersion
    $result.Motherboard.ReleaseDate = $biosDate
    if ($mbSuccess -eq 0) { $result.Motherboard._Status = 'Failed' }
    elseif ($mbSuccess -lt $mbFields) { $result.Motherboard._Status = 'Partial' }

    return $result
}
'@

$HostIdentityFunc = @'
function Get-HostIdentity {
    $m = 'Not available'
    $mdl = 'Not available'
    try {
        # computer maker and model for the home header
        $cs = Get-CimInstance -ClassName Win32_ComputerSystem -OperationTimeoutSec 10 -ErrorAction Stop | Select-Object -First 1
        if ($cs) {
            if (Test-SmbiosValue $cs.Manufacturer) { $m = $cs.Manufacturer.Trim() }
            if (Test-SmbiosValue $cs.Model) { $mdl = $cs.Model.Trim() }
        }
    } catch { }
    return @{ Manufacturer = $m; Model = $mdl }
}
'@

# composite read run by the home page: a good read emits a hashtable with a Specs key, a throwing read emits a string
$SpecReadCode = $GetSpecsFunc + "`n" + $HostIdentityFunc + "`n" + @'
try { @{ Specs = Get-Specs; Host = Get-HostIdentity } } catch { $_.Exception.Message }
'@

# ---- window
$window = [Windows.Markup.XamlReader]::Parse((Get-Content "$Root\UI\MainWindow.xaml" -Raw))
foreach ($n in 'Nav', 'Search', 'Heading', 'Tuner', 'SvcTuner', 'SvcCur', 'Rows', 'Page', 'Log', 'Hex', 'Dec', 'Logo', 'HomePanel', 'HostName', 'HostSub', 'Cards', 'CopySpecs',
               'Shell', 'Body', 'PaneCol', 'PaneToggle', 'HeaderIcon', 'HeaderSub', 'StatusDot', 'StatusRing', 'StatusText', 'StatusBar',
               'CapMin', 'CapMax', 'CapMaxGlyph', 'CapClose') { Set-Variable $n $window.FindName($n) }

# sidebar pages: icon glyph (Segoe Fluent Icons) and the subtitle under the page title
$Pages = [ordered]@{
    Home       = @{ Glyph = [char]0xE80F; Sub = 'Your PC at a glance' }
    Check      = @{ Glyph = [char]0xE9D9; Sub = 'Check your BIOS, storage, RAM and GPU, and stress test them' }
    Refresh    = @{ Glyph = [char]0xE72C; Sub = 'Reinstall or reset Windows, and get a fresh install ready' }
    Setup      = @{ Glyph = [char]0xE90F; Sub = 'First steps on a new install: activation, startup apps, updates' }
    Installers = @{ Glyph = [char]0xE896; Sub = 'Download and install the apps and launchers you need' }
    Graphics   = @{ Glyph = [char]0xE7F4; Sub = 'Clean and install GPU drivers, and tune NVIDIA, AMD and Intel' }
    Windows    = @{ Glyph = [char]0xE771; Sub = 'Start menu, taskbar, theme and the rest of Windows' }
    Hardware   = @{ Glyph = [char]0xE950; Sub = 'Mouse, controller, monitor and network' }
    Advanced   = @{ Glyph = [char]0xE945; Sub = 'Security, CPU and display pipeline tweaks for experienced users' }
}

$logoPath = "$Root\Assets\AkariLogo.png"
if (Test-Path $logoPath) {
    $bmp = [Windows.Media.Imaging.BitmapImage]::new()
    $bmp.BeginInit(); $bmp.UriSource = [Uri]$logoPath; $bmp.CacheOption = 'OnLoad'; $bmp.EndInit()
    $Logo.Source = $bmp
    $window.Icon = $bmp
}
$window.Add_SourceInitialized({
    $h = [Windows.Interop.WindowInteropHelper]::new($window).Handle
    # no system menu: windows stops drawing its own caption buttons under ours
    [void][Akari.Dwm]::SetWindowLong($h, -16, ([Akari.Dwm]::GetWindowLong($h, -16) -band (-bnot 0x80000)))
    # dark frame (also makes Mica dark)
    $v = 1
    [void][Akari.Dwm]::DwmSetWindowAttribute($h, 20, [ref]$v, 4)
    # mica behind the whole window on windows 11; windows 10 keeps the solid black body
    $build = [Environment]::OSVersion.Version.Build
    if ($build -ge 22000) {
        [Windows.Interop.HwndSource]::FromHwnd($h).CompositionTarget.BackgroundColor = [Windows.Media.Colors]::Transparent
        if ($build -ge 22621) {
            # DWMWA_SYSTEMBACKDROP_TYPE = DWMSBT_MAINWINDOW (mica)
            $v = 2
            $r = [Akari.Dwm]::DwmSetWindowAttribute($h, 38, [ref]$v, 4)
        } else {
            # first windows 11 release: the older undocumented mica switch
            $v = 1
            $r = [Akari.Dwm]::DwmSetWindowAttribute($h, 1029, [ref]$v, 4)
        }
        if ($r -eq 0) { $Body.Background = $window.FindResource('Tint') }
    }
})
# maximized, windows pushes the frame past the screen edge: pad it back in
$window.Add_StateChanged({
    $max = ($window.WindowState -eq 'Maximized')
    $Shell.Margin = if ($max) { [Windows.Thickness]::new(8) } else { [Windows.Thickness]::new(0) }
    # maximize button shows the restore glyph while maximized
    $CapMaxGlyph.Text = [string][char]$(if ($max) { 0xE923 } else { 0xE922 })
    $CapMax.ToolTip = if ($max) { 'Restore' } else { 'Maximize' }
})
# caption buttons
$CapMin.Add_Click({ [Windows.SystemCommands]::MinimizeWindow($window) })
$CapMax.Add_Click({ if ($window.WindowState -eq 'Maximized') { [Windows.SystemCommands]::RestoreWindow($window) } else { [Windows.SystemCommands]::MaximizeWindow($window) } })
$CapClose.Add_Click({ $window.Close() })

function Add-Log([string]$m) {
    $Log.AppendText(("[{0}] {1}`r`n" -f (Get-Date -Format 'HH:mm:ss'), $m))
    $Log.ScrollToEnd()
}

# ---- rows
function New-Row($t) {
    $e = { param($s) [Security.SecurityElement]::Escape([string]$s) }
    $riskKey = @{ Safe = 'Mu'; Caution = 'Warn'; Advanced = 'Bad' }[$t.Risk]
    $id = $t.Id
    if ($t.Kind -eq 'Action' -or $t.Kind -eq 'Console') {
        $btns = "<Button Tag=`"$id|Run`" Content=`"$(& $e $t.Button)`" Style=`"{DynamicResource Btn}`"/>"
    } elseif ($t.Kind -eq 'Group') {
        $main = if ($t.Apply) { "<Button Tag=`"$id|Apply`" Content=`"$(& $e $t.Button)`" Style=`"{DynamicResource Btn}`"/>" } else { '' }
        $btns = "$main<Button x:Name=`"Exp`" Tag=`"$id|Expand`" Content=`"Options`" Style=`"{DynamicResource Btn}`"/>"
    } else {
        $defOff = if ($t.Revert) { '' } else { ' IsEnabled="False" ToolTip="No safe revert for this script"' }
        $btns = "<Button x:Name=`"Opt`" Tag=`"$id|Apply`" Content=`"Optimize`" Style=`"{DynamicResource Btn}`"/><Button x:Name=`"Def`" Tag=`"$id|Revert`" Content=`"Default`" Style=`"{DynamicResource Btn}`"$defOff/>"
        if ($t.Check) { $btns += "<Button Tag=`"$id|Check`" Content=`"Check`" Style=`"{DynamicResource Btn}`"/>" }
    }
    $sub = ''
    if ($t.Kind -eq 'Group') {
        $i = 0
        foreach ($a in $t.Actions) {
            $sub += @"
<Grid Margin="0,0,0,8"><Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
<StackPanel VerticalAlignment="Center"><TextBlock Text="$(& $e $a.Name)"/><TextBlock Text="$(& $e $a.Description)" Foreground="{DynamicResource Mu}" FontSize="12.5" TextWrapping="Wrap"/></StackPanel>
<Button Grid.Column="1" Tag="$id|Sub|$i" Content="$(& $e $a.Button)" Style="{DynamicResource Btn}"/></Grid>
"@
            $i++
        }
        $sub = "<StackPanel x:Name=`"Sub`" Visibility=`"Collapsed`" Margin=`"22,12,0,0`"><Border BorderBrush=`"{DynamicResource Bd}`" BorderThickness=`"0,1,0,0`" Margin=`"0,0,0,10`"/>$sub</StackPanel>"
    }
    $dotVis = if ($t.Kind -eq 'Toggle') { 'Visible' } else { 'Hidden' }
    $xaml = @"
<Border xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Background="{DynamicResource S1}" BorderBrush="{DynamicResource Bd}" BorderThickness="1" CornerRadius="8" Padding="16,12" Margin="0,0,0,6">
  <StackPanel>
  <Grid>
    <Grid.ColumnDefinitions><ColumnDefinition Width="22"/><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
    <Ellipse x:Name="Dot" Visibility="$dotVis" Width="9" Height="9" Stroke="{DynamicResource Mu}" StrokeThickness="1.5" HorizontalAlignment="Left" VerticalAlignment="Center"/>
    <StackPanel Grid.Column="1" VerticalAlignment="Center">
      <TextBlock Text="$(& $e $t.Name)" FontWeight="Medium"/>
      <TextBlock Text="$(& $e $t.Description)" Foreground="{DynamicResource Mu}" FontSize="12.5" TextWrapping="Wrap"/>
    </StackPanel>
    <Border Grid.Column="2" BorderThickness="1" CornerRadius="3" Padding="7,1" Margin="12,0" VerticalAlignment="Center"
            BorderBrush="{DynamicResource $riskKey}"><TextBlock Text="$($t.Risk)" FontSize="12" Foreground="{DynamicResource $riskKey}"/></Border>
    <StackPanel Grid.Column="3" Orientation="Horizontal" VerticalAlignment="Center">$btns</StackPanel>
  </Grid>
  $sub
  </StackPanel>
</Border>
"@
    [Windows.Markup.XamlReader]::Parse($xaml)
}

function Get-State($t) {
    if ($t.Detect) {
        try { $r = & $t.Detect; if ($r -is [bool]) { return $r } } catch { }
    }
    if ($script:State.ContainsKey($t.Id)) { return [bool]$script:State[$t.Id] }
    return $null
}

function Update-Row($t) {
    if ($t.Kind -ne 'Toggle') { return }
    $row = $script:RowCache[$t.Id]
    $s = Get-State $t
    $dot = $row.FindName('Dot')
    $dot.Fill = if ($s -eq $true) { $window.FindResource('Inv') } else { [Windows.Media.Brushes]::Transparent }
    $dot.Opacity = if ($null -eq $s) { 0.35 } else { 1 }
    $row.FindName('Opt').Style = $window.FindResource($(if ($s -eq $true) { 'BtnP' } else { 'Btn' }))
    $row.FindName('Def').Style = $window.FindResource('Btn')
}

function Show-Page {
    $q = $Search.Text.Trim()
    $onHome = (-not $q -and $script:Cat -eq 'Home')
    $Rows.Children.Clear()
    if ($q) {
        $Heading.Text = 'Search'
        $HeaderSub.Text = "Results for `"$q`""
        $HeaderIcon.Text = [string][char]0xE721
        $list = @($script:Tweaks | Where-Object { "$($_.Name) $($_.Description)" -like "*$q*" })
    } else {
        $Heading.Text = $script:Cat
        $HeaderSub.Text = $Pages[$script:Cat].Sub
        $HeaderIcon.Text = [string]$Pages[$script:Cat].Glyph
        $list = @($script:Tweaks | Where-Object { $_.Category -eq $script:Cat })
    }
    $adv = (-not $q -and $script:Cat -eq 'Advanced')
    $Tuner.Visibility = if ($adv) { 'Visible' } else { 'Collapsed' }
    $SvcTuner.Visibility = $Tuner.Visibility
    $HomePanel.Visibility = if ($onHome) { 'Visible' } else { 'Collapsed' }
    foreach ($t in $list) {
        if (-not $script:RowCache.ContainsKey($t.Id)) { $script:RowCache[$t.Id] = New-Row $t }
        [void]$Rows.Children.Add($script:RowCache[$t.Id])
        Update-Row $t
    }
    if (-not $list.Count -and -not $adv -and -not $onHome) {
        $msg = [Windows.Controls.TextBlock]::new()
        $msg.Text = if ($q) { 'No scripts match.' } else { 'Nothing here yet.' }
        $msg.Foreground = $window.FindResource('Mu')
        [void]$Rows.Children.Add($msg)
    }
    # render the last values (or loading) first, then read fresh specs in the background
    if ($onHome) { Update-Home; Start-SpecRead }
}

# ---- running actions in a background runspace
function Set-Busy([bool]$b, [string]$label = '') {
    $script:Busy = $b; $Page.IsEnabled = -not $b
    # status bar: green dot and Ready at rest, spinner + label + progress bar while running
    $StatusDot.Visibility = if ($b) { 'Collapsed' } else { 'Visible' }
    $StatusRing.Visibility = if ($b) { 'Visible' } else { 'Collapsed' }
    $StatusBar.Visibility = $StatusRing.Visibility
    $StatusText.Text = if ($b -and $label) { $label } elseif ($b) { 'Working' + [string][char]0x2026 } else { 'Ready' }
}

function Invoke-Code([string]$code, [string]$label, $meta = $null) {
    if ($script:Busy) { return }
    Set-Busy $true $label
    Add-Log $label
    $rs = [runspacefactory]::CreateRunspace()
    $rs.Open()
    $rs.SessionStateProxy.SetVariable('LogQueue', $script:Queue)
    $ps = [powershell]::Create()
    $ps.Runspace = $rs
    $wrapped = $Helpers + "`ntry {`n& {`n" + $code + "`n} *>&1 | Out-String -Stream | ForEach-Object { if (`$_.Trim()) { Write-Log `$_ } }`n} catch { Write-Log ('Error: ' + `$_.Exception.Message) }"
    [void]$ps.AddScript($wrapped)
    $script:Job = @{ Ps = $ps; Rs = $rs; Handle = $ps.BeginInvoke(); Label = $label; Meta = $meta }
}

# ---- home page (spec cards)
function Fmt-Num($v, [string]$fmt, [string]$unit, [double]$scale = 1) {
    # the 'Not available' sentinel is a string: pass it through with no unit
    if ($null -eq $v -or $v -is [string]) { return $v }
    return ($v / $scale).ToString($fmt, [Globalization.CultureInfo]::InvariantCulture) + " $unit"
}

function New-Card([string]$title) {
    $card = [Windows.Controls.Border]::new()
    $card.Width = 240
    $card.Background = $window.FindResource('S1')
    $card.BorderBrush = $window.FindResource('Bd')
    $card.BorderThickness = [Windows.Thickness]::new(1)
    $card.CornerRadius = [Windows.CornerRadius]::new(8)
    $card.Padding = [Windows.Thickness]::new(16, 12, 16, 12)
    $card.Margin = [Windows.Thickness]::new(0, 0, 8, 8)
    $sp = [Windows.Controls.StackPanel]::new()
    # icon + label header, as Akari-Dash's This PC cards
    $hd = [Windows.Controls.StackPanel]::new()
    $hd.Orientation = 'Horizontal'
    $hd.Margin = [Windows.Thickness]::new(0, 0, 0, 8)
    $ic = [Windows.Controls.TextBlock]::new()
    $ic.Text = [string]@{ CPU = [char]0xE950; GPU = [char]0xE7F4; RAM = [char]0xE964; Disk = [char]0xEDA2; Board = [char]0xE9F5; Windows = [char]0xE7F8 }[$title]
    $ic.FontFamily = $window.FindResource('Icons')
    $ic.FontSize = 16
    $ic.VerticalAlignment = 'Center'
    $ic.Margin = [Windows.Thickness]::new(0, 0, 8, 0)
    $tb = [Windows.Controls.TextBlock]::new()
    $tb.Text = $title
    $tb.FontSize = 12
    $tb.Foreground = $window.FindResource('Mu')
    $tb.VerticalAlignment = 'Center'
    [void]$hd.Children.Add($ic); [void]$hd.Children.Add($tb)
    [void]$sp.Children.Add($hd)
    $card.Child = $sp
    return $card
}

function Add-Loading($card) {
    $tb = [Windows.Controls.TextBlock]::new()
    $tb.Text = 'Loading' + [string][char]0x2026
    $tb.FontSize = 13
    $tb.Foreground = $window.FindResource('Mu')
    [void]$card.Child.Children.Add($tb)
}

function Add-Headline($card, [string]$text, [string]$brushKey = 'Tx') {
    $tb = [Windows.Controls.TextBlock]::new()
    $tb.Text = $text
    $tb.FontSize = 15
    $tb.FontWeight = [Windows.FontWeights]::SemiBold
    # the not available sentinel is always muted, whatever brush the caller asked for
    $tb.Foreground = $window.FindResource($(if ($text -eq 'Not available') { 'Mu' } else { $brushKey }))
    $tb.TextWrapping = [Windows.TextWrapping]::Wrap
    $tb.Margin = [Windows.Thickness]::new(0, 0, 0, 8)
    [void]$card.Child.Children.Add($tb)
}

function Add-Row($card, [string]$label, [string]$value, [string]$brushKey = 'Tx') {
    if (-not $brushKey) { $brushKey = 'Tx' }
    $sp = $card.Child
    $first = (@($sp.Children | Where-Object { $_ -is [Windows.Controls.Grid] }).Count -eq 0)
    $g = [Windows.Controls.Grid]::new()
    $g.Margin = [Windows.Thickness]::new(0, $(if ($first) { 0 } else { 4 }), 0, 0)
    # health rows tagged so they can stay at full opacity during a refresh dim
    $g.Tag = $(if ($brushKey -ne 'Tx') { 'Health' } else { $null })
    $c0 = [Windows.Controls.ColumnDefinition]::new(); $c0.Width = [Windows.GridLength]::new(72)
    $c1 = [Windows.Controls.ColumnDefinition]::new(); $c1.Width = [Windows.GridLength]::new(1, [Windows.GridUnitType]::Star)
    [void]$g.ColumnDefinitions.Add($c0); [void]$g.ColumnDefinitions.Add($c1)
    $l = [Windows.Controls.TextBlock]::new()
    $l.Text = $label
    $l.Width = 72
    $l.FontSize = 12
    $l.Foreground = $window.FindResource('Mu')
    $l.VerticalAlignment = [Windows.VerticalAlignment]::Top
    $v = [Windows.Controls.TextBlock]::new()
    $v.Text = $value
    $v.FontSize = 13
    # the not available sentinel is always muted, whatever brush the caller asked for
    $v.Foreground = $window.FindResource($(if ($value -eq 'Not available') { 'Mu' } else { $brushKey }))
    $v.TextWrapping = [Windows.TextWrapping]::Wrap
    [Windows.Controls.Grid]::SetColumn($v, 1)
    [void]$g.Children.Add($l); [void]$g.Children.Add($v)
    [void]$sp.Children.Add($g)
}

function Add-Divider($card) {
    $d = [Windows.Controls.Border]::new()
    $d.Height = 1
    $d.Background = $window.FindResource('Bd')
    $d.Margin = [Windows.Thickness]::new(0, 12, 0, 12)
    [void]$card.Child.Children.Add($d)
}

function New-FailedSpecs {
    $na = 'Not available'
    return @{
        CPU = @{ _Status = 'Failed'; Model = $na; Cores = $na; Threads = $na; SpeedMHz = $na; Sockets = $na }
        RAM = @{ _Status = 'Failed'; TotalGB = $na; UsedGB = $na; FreeGB = $na }
        Windows = @{ _Status = 'Failed'; Edition = $na; Version = $na; Build = $na }
        GPU = @{ _Status = 'Failed'; Adapters = @() }
        Disk = @{ _Status = 'Failed'; Volumes = @() }
        Motherboard = @{ _Status = 'Failed'; Manufacturer = $na; Product = $na; BIOSVersion = $na; ReleaseDate = $na }
    }
}

# disk health brush: amber below 15% free, red below 10% free, neutral when healthy or a number is missing
function Get-DiskHealth($free, $total) {
    if ($null -eq $free -or $null -eq $total -or $free -is [string] -or $total -is [string]) { return 'Tx' }
    if ([double]$total -le 0) { return 'Tx' }
    $pct = [double]$free * 100 / [double]$total
    if ($pct -lt 10) { return 'Bad' }
    if ($pct -lt 15) { return 'Warn' }
    return 'Tx'
}

# ram health brush: amber above 80% used, red above 90% used, neutral when healthy or a number is missing
function Get-RamHealth($used, $total) {
    if ($null -eq $used -or $null -eq $total -or $used -is [string] -or $total -is [string]) { return 'Tx' }
    if ([double]$total -le 0) { return 'Tx' }
    $pct = [double]$used * 100 / [double]$total
    if ($pct -gt 90) { return 'Bad' }
    if ($pct -gt 80) { return 'Warn' }
    return 'Tx'
}

# card model: the six cards as plain descriptors, shared by the card renderer and the copy text
function Get-HomeModel {
    $na = 'Not available'
    $s = $script:SpecData.Specs
    $model = [System.Collections.Generic.List[object]]::new()

    # cpu card: model, cores / threads, clock
    $cpu = $s.CPU
    $head = if ($cpu._Status -eq 'Failed') { $na } else { [string]$cpu.Model }
    $hasC = ($null -ne $cpu.Cores -and [string]$cpu.Cores -ne $na)
    $hasT = ($null -ne $cpu.Threads -and [string]$cpu.Threads -ne $na)
    $cores = if ($hasC -and $hasT) { "$($cpu.Cores) / $($cpu.Threads) threads" } elseif ($hasC) { "$($cpu.Cores)" } elseif ($hasT) { "$($cpu.Threads) threads" } else { $na }
    $rl = @()
    $rl += @{ Label = 'Cores'; Value = [string]$cores }
    $rl += @{ Label = 'Speed'; Value = [string](Fmt-Num $cpu.SpeedMHz '0.00' 'GHz' 1000) }
    # multi-socket machines: show how many cpus the totals cover
    if ($null -ne $cpu.Sockets -and $cpu.Sockets -isnot [string] -and $cpu.Sockets -gt 1) { $rl += @{ Label = 'Sockets'; Value = "$($cpu.Sockets)" } }
    $model.Add(@{ Title = 'CPU'; Blocks = @(@{ Head = $head; Rows = $rl }); Inline = $false })

    # gpu card: one block per adapter, in read order
    $failed = ($s.GPU._Status -eq 'Failed')
    $list = @($s.GPU.Adapters)
    $bl = @()
    for ($i = 0; $i -lt $list.Count; $i++) {
        $a = $list[$i]
        $rl = @()
        $rl += @{ Label = 'VRAM'; Value = [string](Fmt-Num $a.VRAM_GB '0.0' 'GB') }
        $rl += @{ Label = 'Driver'; Value = [string]$a.DriverVersion }
        if ([string]$a.Status -ne 'OK') { $rl += @{ Label = 'Status'; Value = [string]$a.Status } }
        $bl += @{ Head = $(if ($failed) { $na } else { [string]$a.Model }); Rows = $rl }
    }
    # zero adapters: headline only, no rows
    if (-not $list.Count) { $bl += @{ Head = $na; Rows = @() } }
    $model.Add(@{ Title = 'GPU'; Blocks = $bl; Inline = $false })

    # ram card: total, used, free
    $ram = $s.RAM
    $head = if ($ram._Status -eq 'Failed') { $na } else { [string](Fmt-Num $ram.TotalGB '0.0' 'GB') }
    $rl = @()
    # used value turns amber / red when memory runs low (a failed read is never coloured)
    $key = if ($ram._Status -eq 'Failed') { 'Tx' } else { Get-RamHealth $ram.UsedGB $ram.TotalGB }
    $rl += @{ Label = 'Used'; Value = [string](Fmt-Num $ram.UsedGB '0.0' 'GB'); Key = $key }
    $rl += @{ Label = 'Free'; Value = [string](Fmt-Num $ram.FreeGB '0.0' 'GB') }
    $model.Add(@{ Title = 'RAM'; Blocks = @(@{ Head = $head; Rows = $rl }); Inline = $true })

    # disk card: system drive only (the read still returns every fixed volume)
    $failed = ($s.Disk._Status -eq 'Failed')
    $list = @(@($s.Disk.Volumes) | Where-Object { [string]$_.Drive -eq $env:SystemDrive })
    $bl = @()
    for ($i = 0; $i -lt $list.Count; $i++) {
        $v = $list[$i]
        $head = [string]$v.Drive
        if ($v.Label -is [string] -and -not [string]::IsNullOrWhiteSpace($v.Label)) { $head += '  ' + $v.Label }
        $rl = @()
        # free value turns amber / red when the system drive runs low (a failed read is never coloured)
        $key = if ($failed) { 'Tx' } else { Get-DiskHealth $v.FreeGB $v.TotalGB }
        $rl += @{ Label = 'Free'; Value = [string](Fmt-Num $v.FreeGB '0.0' 'GB'); Key = $key }
        $rl += @{ Label = 'Total'; Value = [string](Fmt-Num $v.TotalGB '0.0' 'GB') }
        $rl += @{ Label = 'File system'; Value = [string]$v.FileSystem }
        $bl += @{ Head = $(if ($failed) { $na } else { $head }); Rows = $rl }
    }
    # zero volumes: headline only, no rows
    if (-not $list.Count) { $bl += @{ Head = $na; Rows = @() } }
    $model.Add(@{ Title = 'Disk'; Blocks = $bl; Inline = $false })

    # board card: maker + product, bios version and date
    $mb = $s.Motherboard
    $parts = @(@($mb.Manufacturer, $mb.Product) | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) -and [string]$_ -ne $na })
    $head = if ($mb._Status -eq 'Failed') { $na } elseif ($parts.Count) { $parts -join ' ' } else { $na }
    $rl = @()
    $rl += @{ Label = 'BIOS'; Value = [string]$mb.BIOSVersion }
    $rl += @{ Label = 'Released'; Value = [string]$mb.ReleaseDate }
    $model.Add(@{ Title = 'Board'; Blocks = @(@{ Head = $head; Rows = $rl }); Inline = $false })

    # windows card: edition (without the leading Microsoft), version, build
    $win = $s.Windows
    $head = if ($win._Status -eq 'Failed') { $na } else { [string]$win.Edition -replace '^Microsoft\s+', '' }
    $rl = @()
    $rl += @{ Label = 'Version'; Value = [string]$win.Version }
    $rl += @{ Label = 'Build'; Value = [string]$win.Build }
    $model.Add(@{ Title = 'Windows'; Blocks = @(@{ Head = $head; Rows = $rl }); Inline = $false })

    return $model.ToArray()
}

# header maker / model line from a read composite: 'Maker - Model' joined by a middle dot, or empty
function Get-HostLine($d) {
    $na = 'Not available'
    $hm = $d.Host.Manufacturer
    $hd = $d.Host.Model
    # smbios filler fallback: one filler value discards the whole system pair for the board pair
    if ($hm -eq $na -or $hd -eq $na -or [string]::IsNullOrWhiteSpace([string]$hm) -or [string]::IsNullOrWhiteSpace([string]$hd)) {
        $hm = $d.Specs.Motherboard.Manufacturer
        $hd = $d.Specs.Motherboard.Product
    }
    $hparts = @(@($hm, $hd) | Where-Object { $_ -and [string]$_ -ne $na })
    if ($hparts.Count -gt 0) {
        $sep = ' ' + [string][char]0x00B7 + ' '
        return ($hparts -join $sep)
    }
    return ''
}

function Update-Home {
    $HostName.Text = $env:COMPUTERNAME
    $Cards.Children.Clear()
    # only the card grid and the maker/model line dim while a read is in flight or waiting out a tweak
    $dim = ($null -ne $script:SpecJob -or $script:SpecPending)
    $Cards.Opacity = if ($dim) { 0.6 } else { 1 }
    $HostSub.Opacity = $Cards.Opacity
    # copy is possible once the first read of the session has finished
    if ($CopySpecs) { $CopySpecs.IsEnabled = ($null -ne $script:SpecData) }
    if ($null -eq $script:SpecData) {
        # first read of the session has not finished yet: every card shows the placeholder
        $HostSub.Text = ''
        $HostSub.ToolTip = $null
        $HostSub.Visibility = 'Collapsed'
        foreach ($title in 'CPU', 'GPU', 'RAM', 'Disk', 'Board', 'Windows') {
            $card = New-Card $title; Add-Loading $card
            [void]$Cards.Children.Add($card)
        }
        return
    }

    # draw every card from the shared card model, divider between blocks
    foreach ($cm in Get-HomeModel) {
        $card = New-Card $cm.Title
        $first = $true
        foreach ($blk in $cm.Blocks) {
            if (-not $first) { Add-Divider $card }
            $first = $false
            Add-Headline $card $blk.Head
            foreach ($r in $blk.Rows) { Add-Row $card $r.Label $r.Value $(if ($r.Key) { $r.Key } else { 'Tx' }) }
        }
        [void]$Cards.Children.Add($card)
    }

    # header maker / model, resolved from the read already in hand (no second query)
    $line = Get-HostLine $script:SpecData
    if ($line) {
        $HostSub.Text = $line
        $HostSub.ToolTip = $HostSub.Text
        $HostSub.Visibility = 'Visible'
    } else {
        $HostSub.Text = ''
        $HostSub.ToolTip = $null
        $HostSub.Visibility = 'Collapsed'
    }
}

# plain-text spec sheet for the clipboard, written from the same card model the cards draw
function Get-SpecText {
    $lines = [System.Collections.Generic.List[string]]::new()
    $lines.Add($env:COMPUTERNAME)
    # maker / model line only when the header shows it
    $hl = Get-HostLine $script:SpecData
    if ($hl) { $lines.Add($hl) }
    $lines.Add('')
    foreach ($cm in Get-HomeModel) {
        foreach ($blk in $cm.Blocks) {
            $line = [string]$cm.Title + ': ' + [string]$blk.Head
            if ($cm.Inline) {
                # ram card: rows ride on the headline line
                $line += ' (' + ((@($blk.Rows) | ForEach-Object { [string]$_.Label + ' ' + [string]$_.Value }) -join ', ') + ')'
                $lines.Add($line)
            } else {
                $lines.Add($line)
                foreach ($r in $blk.Rows) { $lines.Add('  ' + [string]$r.Label + ': ' + [string]$r.Value) }
            }
        }
    }
    return ($lines -join "`r`n")
}

# copy specs button: put the spec sheet on the clipboard and flash the label for about two seconds
function Copy-Specs {
    if ($null -eq $script:SpecData) { return }
    try {
        [Windows.Clipboard]::SetText((Get-SpecText))
        $CopySpecs.Content = 'Copied'
    } catch {
        # another program is holding the clipboard
        $CopySpecs.Content = 'Copy failed'
    }
    $script:CopiedUntil = [DateTime]::UtcNow.AddSeconds(2)
}

function Start-SpecRead {
    # one read in flight at a time
    if ($script:SpecJob) { return }
    # a tweak is running: defer the read until it finishes
    if ($script:Busy) { $script:SpecPending = $true; Set-HomeDim; return }
    try {
        $rs = [runspacefactory]::CreateRunspace()
        $rs.Open()
        $ps = [powershell]::Create()
        $ps.Runspace = $rs
        $resultCollection = [System.Management.Automation.PSDataCollection[object]]::new()
        [void]$ps.AddScript($SpecReadCode)
        # ps 5.1 cannot bind the generic BeginInvoke overload with $null input, pass an empty completed collection
        $inputCollection = [System.Management.Automation.PSDataCollection[object]]::new()
        $inputCollection.Complete()
        $script:SpecJob = @{ Ps = $ps; Rs = $rs; Handle = $ps.BeginInvoke($inputCollection, $resultCollection); ResultCollection = $resultCollection; Deadline = [DateTime]::UtcNow.AddSeconds($script:SpecTimeoutSec); StartTime = [DateTime]::UtcNow; LoggedSlow = $false }
        $script:SpecPending = $false
        Set-HomeDim
    } catch {
        Add-Log "Error: Spec read failed to start: $($_.Exception.Message)"
        $script:SpecJob = $null
        $script:SpecPending = $false
    }
}

function Set-HomeDim {
    # the page drew before the read started: fade the earlier values now (a first-load placeholder stays at full opacity)
    if ($null -eq $script:SpecData -or -not $Cards) { return }
    $Cards.Opacity = 0.6
    $HostSub.Opacity = 0.6
    # health values stay at full opacity so they remain readable during the dim
    foreach ($card in $Cards.Children) {
        foreach ($child in $card.Child.Children) {
            if ($child -is [Windows.Controls.Grid] -and $child.Tag -eq 'Health') { $child.Opacity = 1.0 }
        }
    }
}

$timer = [Windows.Threading.DispatcherTimer]::new()
$timer.Interval = [TimeSpan]::FromMilliseconds(150)
$timer.Add_Tick({
    $m = $null
    while ($script:Queue.TryDequeue([ref]$m)) { Add-Log $m }
    # copy specs label: back to its normal text once the two second flash has passed
    if ($script:CopiedUntil -and [DateTime]::UtcNow -ge $script:CopiedUntil) { $CopySpecs.Content = 'Copy specs'; $script:CopiedUntil = $null }
    # watchdog feedback: log once when a read has been running longer than 5 seconds
    $sj = $script:SpecJob
    if ($sj -and -not $sj.Handle.IsCompleted -and -not $sj.LoggedSlow -and $sj.StartTime -and ([DateTime]::UtcNow - $sj.StartTime).TotalSeconds -gt 5) {
        $sj.LoggedSlow = $true
        Add-Log 'Specs: Reading (taking longer than usual)...'
    }
    # home spec read finished: store the composite and redraw only the cards
    $sj = $script:SpecJob
    # watchdog: a read past its deadline is abandoned so home never stays dimmed
    $late = ($sj -and -not $sj.Handle.IsCompleted -and $sj.Deadline -and [DateTime]::UtcNow -ge $sj.Deadline)
    if ($sj -and ($sj.Handle.IsCompleted -or $late)) {
        $had = ($null -ne $script:SpecData)
        $ok = $false
        $msg = $null
        if ($late) {
            $msg = "timed out after $($script:SpecTimeoutSec) seconds"
            # ask the hung pipeline to stop without waiting; it is disposed once it has ended
            try { [void]$sj.Ps.BeginStop($null, $null) } catch { }
            $script:SpecStale.Add($sj)
        } else {
            try {
                [void]$sj.Ps.EndInvoke($sj.Handle)
                $result = $sj.ResultCollection
                if ($null -ne $result -and $result.Count -gt 0) {
                    $last = $result[$result.Count - 1]
                    if ($last -is [hashtable] -and $last.ContainsKey('Specs')) { $script:SpecData = $last; $ok = $true }
                    else { $msg = [string]$last }
                } else { $msg = 'no result returned' }
            } catch { $msg = $_.Exception.Message }
            foreach ($err in $sj.Ps.Streams.Error) { Add-Log "Error: $($err.ToString())" }
            $sj.Ps.Dispose(); $sj.Rs.Dispose()
        }
        $script:SpecJob = $null
        if (-not $ok) {
            if (-not $msg) { $msg = 'no result returned' }
            if (-not $had) { $script:SpecData = @{ Specs = New-FailedSpecs; Host = @{ Manufacturer = 'Not available'; Model = 'Not available' } } }
            $tail = if ($had) { ' Showing last known values.' } else { ' Switch to another page and back to Home to try again.' }
            Add-Log "Specs: Read failed ($msg).$tail"
        }
        Update-Home
    }
    # abandoned spec reads: dispose each one once its pipeline has really ended
    for ($zi = $script:SpecStale.Count - 1; $zi -ge 0; $zi--) {
        $z = $script:SpecStale[$zi]
        if ($z.Handle.IsCompleted) {
            try { $z.Ps.Dispose(); $z.Rs.Dispose() } catch { }
            $script:SpecStale.RemoveAt($zi)
        }
    }
    $j = $script:Job
    if ($j -and $j.Handle.IsCompleted) {
        try { [void]$j.Ps.EndInvoke($j.Handle) } catch { Add-Log "Error: $($_.Exception.Message)" }
        foreach ($err in $j.Ps.Streams.Error) { Add-Log "Error: $($err.ToString())" }
        while ($script:Queue.TryDequeue([ref]$m)) { Add-Log $m }
        $j.Ps.Dispose(); $j.Rs.Dispose()
        if ($j.Meta) { $script:State[$j.Meta.Id] = ($j.Meta.Kind -eq 'Apply'); Save-State }
        Add-Log "Done: $($j.Label)"
        $script:Job = $null
        Set-Busy $false
        Read-Svc
        Show-Page
        # a home read was requested while the tweak ran: start it now (only on the Home page)
        if ($script:SpecPending -and $script:Cat -eq 'Home') { Start-SpecRead }
    }
})
$timer.Start()

function Confirm-Run([string]$text) {
    if (-not $text) { return $true }
    return ([Windows.MessageBox]::Show($text, 'Akari', 'YesNo', 'Warning') -eq 'Yes')
}

# ---- row buttons (one handler for every Optimize / Default button)
$Rows.AddHandler([Windows.Controls.Primitives.ButtonBase]::ClickEvent, [Windows.RoutedEventHandler] {
    param($s, $ev)
    $b = $ev.OriginalSource -as [Windows.Controls.Button]
    if (-not $b -or -not $b.Tag) { return }
    $id, $kind, $arg = ([string]$b.Tag).Split('|')
    $t = $script:Tweaks | Where-Object { $_.Id -eq $id } | Select-Object -First 1
    if (-not $t) { return }
    $meta = if ($t.Kind -eq 'Toggle') { @{ Id = $id; Kind = $kind } } else { $null }
    switch ($kind) {
        'Apply'  { if ($t.Apply -and (Confirm-Run $t.Confirm)) { Invoke-Code $t.Apply.ToString() "$($t.Name): $(if ($t.Kind -eq 'Toggle') { 'optimize' } else { $t.Button.ToLower() })" $meta } }
        'Revert' { if ($t.Revert) { Invoke-Code $t.Revert.ToString() "$($t.Name): default" $meta } }
        'Check'  { if ($t.Check)  { Invoke-Code $t.Check.ToString() "$($t.Name): check" } }
        'Run'    {
            if ($t.Apply -and (Confirm-Run $t.Confirm)) { Invoke-Code $t.Apply.ToString() "$($t.Name): $($t.Button.ToLower())" }
        }
        'Sub'    { $a = $t.Actions[[int]$arg]; if (Confirm-Run $a.Confirm) { Invoke-Code $a.Block.ToString() "$($t.Name): $($a.Name)" } }
        'Expand' {
            $row = $script:RowCache[$id]; $sub = $row.FindName('Sub'); $exp = $row.FindName('Exp')
            if ($sub.Visibility -eq 'Visible') { $sub.Visibility = 'Collapsed'; $exp.Content = 'Options' }
            else { $sub.Visibility = 'Visible'; $exp.Content = 'Hide' }
        }
    }
})

# ---- sidebar
foreach ($c in $Pages.Keys) {
    # icon in a 40 px column (it stays put when the pane collapses to 48 px), label after it
    $g = [Windows.Controls.Grid]::new()
    $c0 = [Windows.Controls.ColumnDefinition]::new(); $c0.Width = [Windows.GridLength]::new(40)
    [void]$g.ColumnDefinitions.Add($c0); [void]$g.ColumnDefinitions.Add([Windows.Controls.ColumnDefinition]::new())
    $ic = [Windows.Controls.TextBlock]::new()
    $ic.Text = [string]$Pages[$c].Glyph
    $ic.FontFamily = $window.FindResource('Icons')
    $ic.FontSize = 16
    $ic.HorizontalAlignment = 'Center'; $ic.VerticalAlignment = 'Center'
    $lb = [Windows.Controls.TextBlock]::new()
    $lb.Text = $c; $lb.FontSize = 14; $lb.VerticalAlignment = 'Center'; $lb.Margin = [Windows.Thickness]::new(4, 0, 0, 1)
    [Windows.Controls.Grid]::SetColumn($lb, 1)
    [void]$g.Children.Add($ic); [void]$g.Children.Add($lb)
    $rb = [Windows.Controls.RadioButton]::new()
    $rb.Content = $g; $rb.Tag = $c; $rb.GroupName = 'nav'; $rb.ToolTip = $c
    $rb.Style = $window.FindResource('Nav')
    [void]$Nav.Children.Add($rb)
    if ($c -eq 'Home') {
        # section heading under home (not a nav item), as NavigationViewItemHeader
        $hd = [Windows.Controls.TextBlock]::new()
        $hd.Text = 'Scripts'
        $hd.FontSize = 14; $hd.FontWeight = [Windows.FontWeights]::SemiBold
        $hd.Margin = [Windows.Thickness]::new(16, 14, 0, 6)
        $hd.IsHitTestVisible = $false
        $script:NavHeader = $hd
        [void]$Nav.Children.Add($hd)
    }
}
# pane toggle: full 232 px sidebar or the 48 px icon strip
$PaneToggle.Add_Click({
    $open = ($PaneCol.Width.Value -gt 48)
    $PaneCol.Width = [Windows.GridLength]::new($(if ($open) { 48 } else { 232 }))
    $script:NavHeader.Visibility = if ($open) { 'Hidden' } else { 'Visible' }
})
$Nav.AddHandler([Windows.Controls.Primitives.ToggleButton]::CheckedEvent, [Windows.RoutedEventHandler] {
    param($s, $ev)
    $script:Cat = [string]$ev.OriginalSource.Tag
    if ($Search.Text) { $Search.Text = '' }
    Show-Page
})
$Search.Add_TextChanged({ Show-Page })
# copy specs button on the home header
$CopySpecs.Add_Click({ Copy-Specs })

# ---- Win32PrioritySeparation tuner
function Get-Chip([string]$g) {
    foreach ($i in 0..2) { if ($window.FindName("${g}_$i").IsChecked) { return $i } }
    return 0
}
function Update-Tuner {
    $v = ((Get-Chip QL) -shl 4) -bor ((Get-Chip QT) -shl 2) -bor (Get-Chip FB)
    $Hex.Text = '0x{0:X2}' -f $v
    $Dec.Text = "$v decimal"
    return $v
}
function Set-Chips([int]$v) {
    $want = @{ QL = ($v -shr 4) -band 3; QT = ($v -shr 2) -band 3; FB = $v -band 3 }
    foreach ($g in 'QL', 'QT', 'FB') {
        foreach ($i in 0..2) { $window.FindName("${g}_$i").IsChecked = ($i -eq $want[$g]) }
    }
    [void](Update-Tuner)
}
function Read-Prio {
    $cur = (Get-ItemProperty $PrioKey -Name Win32PrioritySeparation -ErrorAction SilentlyContinue).Win32PrioritySeparation
    if ($null -ne $cur) { Set-Chips ([int]$cur) } else { Set-Chips 2 }
}
function Set-Prio([int]$v) {
    $hex = '0x{0:X2}' -f $v
    Invoke-Code "Set-Reg '$PrioKey' 'Win32PrioritySeparation' $v`nWrite-Log 'Win32PrioritySeparation = $hex'" "Win32PrioritySeparation: setting $hex"
}
$Tuner.AddHandler([Windows.Controls.Primitives.ToggleButton]::CheckedEvent, [Windows.RoutedEventHandler] { [void](Update-Tuner) })
$Tuner.AddHandler([Windows.Controls.Primitives.ButtonBase]::ClickEvent, [Windows.RoutedEventHandler] {
    param($s, $ev)
    $b = $ev.OriginalSource -as [Windows.Controls.Button]
    if (-not $b) { return }
    switch ([string]$b.Tag) {
        'read'  { Read-Prio; Add-Log "Current Win32PrioritySeparation: $($Hex.Text)" }
        'def'   { Set-Chips 2; Set-Prio 2 }
        'apply' { Set-Prio (Update-Tuner) }
    }
})
Read-Prio

# ---- SvcHost split threshold tuner
$SvcKey = 'HKLM:\SYSTEM\CurrentControlSet\Control'
function Get-RamKB { [math]::Ceiling((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB) * 1048576 }
function Get-SvcTarget {
    $i = 0; foreach ($k in 0..2) { if ($window.FindName("SV_$k").IsChecked) { $i = $k } }
    switch ($i) { 0 { [uint32]3670016 } 1 { [uint32](Get-RamKB) } 2 { [uint32]4294967295 } }
}
function Read-Svc {
    $cur = (Get-ItemProperty $SvcKey -Name SvcHostSplitThresholdInKB -ErrorAction SilentlyContinue).SvcHostSplitThresholdInKB
    $ramGB = [math]::Round((Get-RamKB) / 1048576)
    $txt = if ($null -ne $cur) { [BitConverter]::ToUInt32([BitConverter]::GetBytes([int]$cur), 0).ToString('N0') + ' KB' } else { 'not set' }
    $SvcCur.Text = "Current: $txt   |   RAM: $ramGB GB"
}
function Set-Svc([uint32]$v) {
    Invoke-Code "Set-Reg '$SvcKey' 'SvcHostSplitThresholdInKB' ([uint32]$v)`nWrite-Log 'SvcHostSplitThresholdInKB = $v (restart to apply)'" "SvcHost split threshold: setting $v KB"
}
$SvcTuner.AddHandler([Windows.Controls.Primitives.ButtonBase]::ClickEvent, [Windows.RoutedEventHandler] {
    param($s, $ev)
    $b = $ev.OriginalSource -as [Windows.Controls.Button]
    if (-not $b) { return }
    switch ([string]$b.Tag) {
        'read'  { Read-Svc }
        'def'   { $window.FindName('SV_0').IsChecked = $true; Set-Svc 3670016 }
        'apply' { Set-Svc (Get-SvcTarget) }
    }
})
$window.FindName('SV_0').IsChecked = $true
Read-Svc

# ---- go
$window.Add_Loaded({
    ($Nav.Children | Where-Object { $_.Tag -eq $script:Cat } | Select-Object -First 1).IsChecked = $true
    Add-Log 'Ready.'
    $script:Busy = $false
})
# errors inside button handlers: show them in the log drawer (and akari.log) instead of losing them
$window.Dispatcher.Add_UnhandledException({
    param($s, $ev)
    $ev.Handled = $true
    Write-ErrLog "UI error: $($ev.Exception.Message)"
    Add-Log "Error: $($ev.Exception.Message)"
    Set-Busy $false
})
$window.Add_Closing({ $timer.Stop() })
[void]$window.ShowDialog()
