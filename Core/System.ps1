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

# the boot entry's settings as text lines ("bcdedit /enum {current}"; read only). Changes go through
# Invoke-AkariBcdEdit (Core\Phases.ps1).
function Read-AkariBcd { & "$env:SystemRoot\System32\bcdedit.exe" /enum '{current}' 2>&1 | ForEach-Object { "$_" } }

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
