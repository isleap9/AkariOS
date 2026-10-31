# System helpers: what this PC is (Requires), and the system commands tweaks share. Every read and every
# system-changing command goes through one function here, so tests mock that function (AGENTS.md rule 12).

# the Windows build number (22000 and up = Windows 11)
function Get-AkariOSBuild { [Environment]::OSVersion.Version.Build }

# the Windows edition's EditionID (Core* = Home, Professional, Enterprise, ...). Read only; tests mock this.
function Get-AkariEdition { "$((Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -ErrorAction SilentlyContinue).EditionID)" }

# 'Laptop' or 'Desktop', from the chassis type (portable, laptop, notebook, tablet, convertible, ...); read once
function Get-AkariChassis {
    if (-not $script:AkariChassis) {
        $types = @(try { (Get-CimInstance Win32_SystemEnclosure -ErrorAction Stop).ChassisTypes } catch { })
        $portable = 8, 9, 10, 11, 12, 14, 18, 21, 30, 31, 32
        $script:AkariChassis = if (@($types | Where-Object { $_ -in $portable }).Count) { 'Laptop' } else { 'Desktop' }
    }
    $script:AkariChassis
}

# the display adapters' driver keys (Class\{4d36e968-...}\0000, 0001, ...): @{ Path; Name; Vendor } with Vendor
# NVIDIA / AMD / Intel / Other. Tweaks write their per-GPU values under Path. Read only; tests mock this.
$AkariGpuClass = 'HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}'
function Get-AkariGpus {
    foreach ($k in @(Get-ChildItem -LiteralPath $AkariGpuClass -ErrorAction SilentlyContinue | Where-Object { $_.PSChildName -match '^\d{4}$' })) {
        $p = Get-ItemProperty -LiteralPath $k.PSPath -ErrorAction SilentlyContinue
        $text = "$($p.ProviderName) $($p.DriverDesc)"
        $vendor = if ($text -match 'NVIDIA') { 'NVIDIA' } elseif ($text -match '\bAMD\b|\bATI\b|Advanced Micro|Radeon') { 'AMD' } elseif ($text -match 'Intel') { 'Intel' } else { 'Other' }
        [pscustomobject]@{ Path = "$AkariGpuClass\$($k.PSChildName)"; Name = "$($p.DriverDesc)"; Vendor = $vendor }
    }
}

# the display adapters' device instance ids (PCI\VEN_...), for values under Enum\<id>\Device Parameters. Read only.
function Get-AkariGpuDevices { @(Get-PnpDevice -Class Display -ErrorAction SilentlyContinue | ForEach-Object { $_.InstanceId }) }

# $null when every Requires value is met on this PC, else the reason ('needs Win11')
function Test-AkariRequirement($Tweak) {
    foreach ($r in @($Tweak.Requires | Where-Object { $_ })) {
        $met = switch ($r) {
            'Win10' { (Get-AkariOSBuild) -lt 22000 }
            'Win11' { (Get-AkariOSBuild) -ge 22000 }
            'Laptop' { (Get-AkariChassis) -eq 'Laptop' }
            'Desktop' { (Get-AkariChassis) -eq 'Desktop' }
            'Home' { (Get-AkariEdition) -like 'Core*' }
            # Pro or higher (Enterprise, Education, IoT, Server): group policies apply there, Home ignores them
            'Pro' { $e = Get-AkariEdition; [bool]$e -and $e -notlike 'Core*' }
            { $_ -in 'NVIDIA', 'AMD', 'Intel' } { [bool](@(Get-AkariGpus) | Where-Object { $_.Vendor -eq $r }) }
            default { $false }
        }
        if (-not $met) { return "needs $r" }
    }
    $null
}

# Explorer shows some changes only after a restart (taskbar, Start, context menu). Windows starts the shell again
# by itself as the signed-in user; starting it from this elevated process would run it elevated.
function Restart-AkariExplorer {
    Write-Log 'Restarting Explorer'
    Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
    # not back after 5 seconds (shell restart turned off): start it, better elevated than no taskbar
    for ($i = 0; $i -lt 10 -and -not (Get-Process -Name explorer -ErrorAction SilentlyContinue); $i++) { Start-Sleep -Milliseconds 500 }
    if (-not (Get-Process -Name explorer -ErrorAction SilentlyContinue)) { Start-Process "$env:SystemRoot\explorer.exe" }
}

# restarts the PC straight into its UEFI firmware settings (shutdown /r /fw); returns shutdown's exit code, not 0
# on a PC without UEFI. The only firmware restart; tests mock this.
function Restart-AkariFirmware {
    $ErrorActionPreference = 'Continue'
    & "$env:SystemRoot\System32\shutdown.exe" /r /fw /t 0 2>&1 | ForEach-Object { Write-Log "shutdown: $_" }
    $LASTEXITCODE
}

# shows $Path as the desktop wallpaper now (the registry value is the tweak's job, in the real user's hive):
# SystemParametersInfo(SPI_SETDESKWALLPAPER) with SPIF_SENDCHANGE only, so the elevated account's profile is not written
function Set-AkariDesktopWallpaper([string]$Path) {
    if (-not ('AkariWallpaper' -as [type])) {
        Add-Type -TypeDefinition 'using System.Runtime.InteropServices; public class AkariWallpaper { [DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern int SystemParametersInfo(int uAction, int uParam, string lpvParam, int fuWinIni); }'
    }
    [void][AkariWallpaper]::SystemParametersInfo(20, 0, $Path, 2)
}

# compiles C# source to an .exe with the .NET Framework's own compiler (always on Windows 10 / 11); throws on failure
function Invoke-AkariCsc([string]$Source, [string]$Out) {
    $csc = "$env:SystemRoot\Microsoft.NET\Framework64\v4.0.30319\csc.exe"
    $log = & $csc -nologo "-out:$Out" $Source 2>&1 | ForEach-Object { "$_" }
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $Out)) { throw "csc failed: $($log -join ' ')" }
}

# a boot store entry's settings as text lines ("bcdedit /enum {current}", or another -Id such as {globalsettings};
# read only). Changes go through Invoke-AkariBcdEdit (Core\Phases.ps1).
function Read-AkariBcd([string]$Id = '{current}') { & "$env:SystemRoot\System32\bcdedit.exe" /enum $Id 2>&1 | ForEach-Object { "$_" } }

# the only w32tm call: starts the Windows Time service when it can (w32tm /config needs it running), then runs w32tm
# with $Arguments; returns its output lines. Continue: see Invoke-AkariPowerCfg.
function Invoke-AkariW32tm {
    param([Parameter(ValueFromRemainingArguments = $true)][string[]]$Arguments)
    $ErrorActionPreference = 'Continue'
    Start-Service W32Time -ErrorAction SilentlyContinue
    & "$env:SystemRoot\System32\w32tm.exe" @Arguments 2>&1 | ForEach-Object { "$_" }
}

# the hosts file: Akari's lines sit in named blocks between "# AkariOS <name> start" and "# AkariOS <name> end"; the
# user's own lines are never touched. Tests point $AkariHostsPath at a test file.
$AkariHostsPath = "$env:SystemRoot\System32\drivers\etc\hosts"

# the lines of block <name>, or $null when the hosts file has no such block
function Get-AkariHostsBlock([string]$Name) {
    if (-not (Test-Path -LiteralPath $AkariHostsPath)) { return $null }
    $lines = @([IO.File]::ReadAllLines($AkariHostsPath))
    $s = [array]::IndexOf($lines, "# AkariOS $Name start"); $e = [array]::IndexOf($lines, "# AkariOS $Name end")
    if ($s -lt 0 -or $e -lt $s) { return $null }
    , @($lines | Select-Object -Skip ($s + 1) -First ($e - $s - 1))
}

# writes block <name> with $Lines at the end of the hosts file (replacing it if there); no $Lines = the block removed
function Set-AkariHostsBlock([string]$Name, [string[]]$Lines) {
    $all = @(if (Test-Path -LiteralPath $AkariHostsPath) { [IO.File]::ReadAllLines($AkariHostsPath) })
    $s = [array]::IndexOf($all, "# AkariOS $Name start"); $e = [array]::IndexOf($all, "# AkariOS $Name end")
    if ($s -ge 0 -and $e -ge $s) { $all = @($all | Select-Object -First $s) + @($all | Select-Object -Skip ($e + 1)) }
    if ($Lines) { $all = @($all) + "# AkariOS $Name start" + $Lines + "# AkariOS $Name end" }
    [IO.File]::WriteAllLines($AkariHostsPath, [string[]]$all, [Text.Encoding]::ASCII)
}

# a protected system file or folder made writable for the administrators group (takeown + icacls, as the old scripts
# did); Windows keeps it that way. Tests mock this.
function Grant-AkariOwnership([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path)) { return }
    & "$env:SystemRoot\System32\takeown.exe" /f $Path /a /r /d y 2>&1 | Out-Null
    & "$env:SystemRoot\System32\icacls.exe" $Path /grant '*S-1-5-32-544:F' /t /q 2>&1 | Out-Null
}

# turns a scheduled task on or off; $false when the task isn't on this PC. Tests mock this.
function Set-AkariScheduledTask([string]$TaskPath, [string]$TaskName, [bool]$Enabled) {
    if (-not (Get-ScheduledTask -TaskPath $TaskPath -TaskName $TaskName -ErrorAction SilentlyContinue)) { return $false }
    if ($Enabled) { [void](Enable-ScheduledTask -TaskPath $TaskPath -TaskName $TaskName -ErrorAction SilentlyContinue) }
    else { [void](Disable-ScheduledTask -TaskPath $TaskPath -TaskName $TaskName -ErrorAction SilentlyContinue) }
    $true
}

# ---- services and scheduled tasks one by one (the Services and Scheduled tasks pages, UI\ServicesPage.ps1,
# UI\TasksPage.ps1): read, then changed through the functions below. Tests mock the reads and point the services root
# at a test key.
$AkariServicesRoot = 'HKLM:\SYSTEM\CurrentControlSet\Services'

# a service's startup type from Win32_Service's StartMode and DelayedAutoStart: Automatic, AutomaticDelayed, Manual,
# Disabled (or Boot / System, a driver-like start nobody picks by hand). Pure.
function ConvertTo-AkariStartType([string]$Mode, [bool]$Delayed) {
    switch ($Mode) { 'Auto' { if ($Delayed) { 'AutomaticDelayed' } else { 'Automatic' } } 'Manual' { 'Manual' } 'Disabled' { 'Disabled' } default { $Mode } }
}

# the registry Start value of a startup type (2 automatic, 3 manual, 4 disabled) and its DelayedAutostart. Pure.
function ConvertFrom-AkariStartType([string]$StartType) {
    switch ($StartType) {
        'Automatic' { @{ Start = 2; Delayed = 0 } }
        'AutomaticDelayed' { @{ Start = 2; Delayed = 1 } }
        'Manual' { @{ Start = 3; Delayed = 0 } }
        'Disabled' { @{ Start = 4; Delayed = 0 } }
        default { throw "unknown startup type: $StartType" }
    }
}

# the per-user service template of an instance name (cbdhsvc_4f2a1 -> cbdhsvc), or '': Windows makes each user's
# instance from the template at sign-in, so a startup type lasts only when the template gets it too. Pure.
function Get-AkariServiceTemplate([string]$Name) {
    if ($Name -match '^(.+)_[0-9a-f]{4,8}$') { $Matches[1] } else { '' }
}

# the services on this PC (all of them, or the one named): @{ Name; DisplayName; Description; Start; Status; CanStop }
# (Start: ConvertTo-AkariStartType). The only service read: tests mock it.
function Get-AkariServices([string]$Name) {
    $p = @{ ClassName = 'Win32_Service'; ErrorAction = 'Stop' }
    if ($Name) { $p.Filter = "Name='$($Name -replace "'", "\'")'" }
    foreach ($s in @(Get-CimInstance @p)) {
        [pscustomobject]@{
            Name = [string]$s.Name; DisplayName = [string]$s.DisplayName; Description = [string]$s.Description
            Start = ConvertTo-AkariStartType $s.StartMode ([bool]$s.DelayedAutoStart); Status = [string]$s.State; CanStop = [bool]$s.AcceptStop
        }
    }
}

# sets a service's startup type (ConvertFrom-AkariStartType's names) in its registry key, and its template's for a
# per-user instance: as admin, else as TrustedInstaller (many service keys are protected); throws when Windows keeps
# the old one (Defender's, for one, change only in Safe Mode). Takes effect at the next start of the service.
function Set-AkariServiceStart([string]$Name, [string]$StartType) {
    $v = ConvertFrom-AkariStartType $StartType
    $names = @($Name, (Get-AkariServiceTemplate $Name)) | Where-Object { $_ -and (Test-Path -LiteralPath "$AkariServicesRoot\$_") }
    if (-not $names) { throw "no service named $Name" }
    $rows = foreach ($n in $names) {
        @{ Path = "$AkariServicesRoot\$n"; Name = 'Start'; Type = 'DWord'; Value = $v.Start; Default = $v.Start }
        @{ Path = "$AkariServicesRoot\$n"; Name = 'DelayedAutostart'; Type = 'DWord'; Value = $v.Delayed; Default = $v.Delayed }
    }
    try { foreach ($r in $rows) { Set-ItemProperty -LiteralPath $r.Path -Name $r.Name -Value $r.Value -Type DWord -ErrorAction Stop } }
    catch { Invoke-AkariRegistryTrusted $rows Apply }
    foreach ($n in $names) {
        if ((Get-ItemProperty -LiteralPath "$AkariServicesRoot\$n" -Name Start -ErrorAction SilentlyContinue).Start -ne $v.Start) {
            throw "Windows keeps the startup type of $n (a protected service: some change only in Safe Mode)"
        }
    }
}

# starts or stops a service now ($Op Start / Stop; Stop also stops the services that depend on it). Tests mock this.
function Invoke-AkariServiceControl([string]$Name, [ValidateSet('Start', 'Stop')][string]$Op) {
    if ($Op -eq 'Start') { Start-Service -Name $Name -ErrorAction Stop } else { Stop-Service -Name $Name -Force -ErrorAction Stop }
}

# a Windows resource string ("@%SystemRoot%\system32\x.dll,-101", or Task Scheduler's "$(@...)") as text; other text
# as it is
function Resolve-AkariIndirectString([string]$Text) {
    $t = $Text
    if ($t -like '$(@*)') { $t = $t.Substring(2, $t.Length - 3) }
    if ($t -notlike '@*') { return $Text }
    if (-not ('AkariIndirect' -as [type])) {
        Add-Type -TypeDefinition 'using System; using System.Text; using System.Runtime.InteropServices; public class AkariIndirect { [DllImport("shlwapi.dll", CharSet = CharSet.Unicode)] public static extern int SHLoadIndirectString(string src, StringBuilder buf, int size, IntPtr reserved); }'
    }
    $b = [Text.StringBuilder]::new(1024)
    if ([AkariIndirect]::SHLoadIndirectString($t, $b, $b.Capacity, [IntPtr]::Zero) -eq 0) { $b.ToString() } else { '' }
}

# the scheduled tasks on this PC (all of them, or the one at $TaskPath + $TaskName): @{ Path; Name; Enabled; State;
# Description; Author }. The only task read for the page: tests mock it.
function Get-AkariTasks([string]$TaskPath, [string]$TaskName) {
    $p = @{ ErrorAction = 'Stop' }
    if ($TaskName) { $p.TaskPath = $TaskPath; $p.TaskName = $TaskName }
    foreach ($t in @(Get-ScheduledTask @p)) {
        [pscustomobject]@{
            Path = [string]$t.TaskPath; Name = [string]$t.TaskName; Enabled = ("$($t.State)" -ne 'Disabled'); State = "$($t.State)"
            Description = Resolve-AkariIndirectString $t.Description; Author = Resolve-AkariIndirectString $t.Author
        }
    }
}

# turns a scheduled task on or off as admin, else as TrustedInstaller (Windows' own tasks such as UpdateOrchestrator's
# refuse an admin); throws when it stays as it was. Tests mock this.
function Set-AkariTaskEnabled([string]$TaskPath, [string]$TaskName, [bool]$Enabled) {
    try {
        if ($Enabled) { [void](Enable-ScheduledTask -TaskPath $TaskPath -TaskName $TaskName -ErrorAction Stop) }
        else { [void](Disable-ScheduledTask -TaskPath $TaskPath -TaskName $TaskName -ErrorAction Stop) }
    } catch {
        $full = "$TaskPath$TaskName" -replace "'", "''"
        Run-Trusted "schtasks.exe /change /tn '$full' $(if ($Enabled) { '/enable' } else { '/disable' })"
    }
    $t = Get-ScheduledTask -TaskPath $TaskPath -TaskName $TaskName -ErrorAction Stop
    if (("$($t.State)" -ne 'Disabled') -ne $Enabled) { throw "Windows keeps this task $(if ($Enabled) { 'off' } else { 'on' })" }
}

# unregisters every scheduled task but the ones named in $Keep (protected ones Windows won't let go are skipped);
# returns how many went. Tests mock this.
function Remove-AkariScheduledTasks([string[]]$Keep) {
    $n = 0
    foreach ($t in @(Get-ScheduledTask -TaskPath '*' -ErrorAction SilentlyContinue | Where-Object { $_.TaskName -notin $Keep })) {
        try { Unregister-ScheduledTask -InputObject $t -Confirm:$false -ErrorAction Stop; $n++ } catch { }
    }
    $n
}

# deletes files and folders (a path may hold wildcards: everything it matches goes, folders with their contents);
# what is in use or protected stays. Returns how many items went. The only bulk delete of the cleanup Actions: tests
# mock this, so a test never deletes real files.
function Remove-AkariPaths([string[]]$Paths) {
    $n = 0
    foreach ($p in $Paths) {
        foreach ($i in @(Get-Item -Path $p -Force -ErrorAction SilentlyContinue)) {
            try { Remove-Item -LiteralPath $i.FullName -Recurse -Force -ErrorAction Stop; $n++ } catch { }
        }
    }
    $n
}

# the only wevtutil call (event logs: "el" lists them, "cl <name>" clears one); returns its output lines. Continue:
# see Invoke-AkariPowerCfg (a log Windows won't clear writes to stderr).
function Invoke-AkariWevtutil {
    param([Parameter(ValueFromRemainingArguments = $true)][string[]]$Arguments)
    $ErrorActionPreference = 'Continue'
    & "$env:SystemRoot\System32\wevtutil.exe" @Arguments 2>&1 | ForEach-Object { "$_" }
}

# runs Disk Cleanup with a saved set of categories (cleanmgr /sagerun:<n>) and waits for it, at most 30 minutes; a
# Disk Cleanup whose CPU time and memory stop changing for 30 seconds is taken as frozen and closed (after ZOICWARE,
# credit @instead1337). Tests mock this.
function Invoke-AkariCleanMgr([int]$Set) {
    $p = Start-Process "$env:SystemRoot\System32\cleanmgr.exe" -ArgumentList "/sagerun:$Set" -PassThru
    $clock = [Diagnostics.Stopwatch]::StartNew(); $last = $null; $still = 0
    while (-not $p.HasExited -and $clock.Elapsed.TotalMinutes -lt 30) {
        Start-Sleep -Seconds 10
        $p.Refresh()
        $now = "$($p.TotalProcessorTime)|$($p.WorkingSet64)"
        if ($now -eq $last) { $still++ } else { $still = 0 }
        $last = $now
        if ($still -ge 3) { break }
    }
    if (-not $p.HasExited) { $p | Stop-Process -Force -ErrorAction SilentlyContinue }
}

# the third-party driver packages in the driver store (Get-WindowsDriver -Online: Driver = oemNN.inf,
# OriginalFileName, ProviderName, ClassName, Version, Date). Read only; tests mock this.
function Get-AkariDriverPackages { @(Get-WindowsDriver -Online -ErrorAction Stop) }

# deletes one driver package from the driver store (pnputil /delete-driver oemNN.inf, never /force: a package a
# device uses stays); returns pnputil's exit code. Tests mock this.
function Remove-AkariDriverPackage([string]$Inf) {
    & "$env:SystemRoot\System32\pnputil.exe" /delete-driver $Inf 2>&1 | Out-Null
    $LASTEXITCODE
}

# runs a program (a tool a tweak ships or installs: 7-Zip, lodctr, ...) and waits; returns its exit code. Tests mock this.
function Invoke-AkariExe([string]$Path, [string[]]$Arguments) {
    & $Path @Arguments 2>&1 | ForEach-Object { "$_" } | Out-Null
    $LASTEXITCODE
}

# the only powercfg call: returns its output lines (stderr included as text). Continue: as an advanced function it
# takes the Runner's -ErrorAction Stop, which would throw on powercfg's stderr (a setting this PC doesn't have).
function Invoke-AkariPowerCfg {
    param([Parameter(ValueFromRemainingArguments = $true)][string[]]$Arguments)
    $ErrorActionPreference = 'Continue'
    & "$env:SystemRoot\System32\powercfg.exe" @Arguments 2>&1 | ForEach-Object { "$_" }
}
