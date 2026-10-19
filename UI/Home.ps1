# Home page: live specs (CPU, RAM, GPU, disk, board/BIOS, Windows build), spec cards, Copy specs.
# Dot-sourced by Akari.ps1 before UI\Shell.ps1; the functions use the window elements at call time.

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
