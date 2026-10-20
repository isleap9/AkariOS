#requires -Version 5.1
param([ValidateRange(1, 3)][int]$OneClick, [switch]$List, [string[]]$Apply, [string[]]$Revert, [string]$Preset, [string]$RevertPreset, [switch]$Resume)
# Akari. GUI:  powershell -ExecutionPolicy Bypass -File Akari.ps1
# A Run in phases, after a restart (RunOnce; Core\Phases.ps1):  Akari.ps1 -Resume
# The old imported One-click bodies (OneClick\*.ps1, until the VM check of M4):  Akari.ps1 -OneClick 2|3
# CLI:  Akari.ps1 -List  |  -Apply id,id  |  -Revert id,id  |  -Preset <name|file.json>  |  -RevertPreset <name|file.json>
#       (all but -List need an elevated shell; -RevertPreset reverts in reverse order and skips Actions)

# ---- CLI: no relaunch, no WPF
if ($List -or $Apply -or $Revert -or $Preset -or $RevertPreset) {
    $CoreDir = Join-Path $PSScriptRoot 'Core'
    foreach ($f in 'Log', 'Trusted', 'Registry', 'Loader', 'State', 'Runner', 'Appx', 'Winget', 'AppSetup', 'System', 'Presets', 'Phases', 'Restore') { . "$CoreDir\$f.ps1" }
    $loaded = Get-AkariTweaks (Join-Path $PSScriptRoot 'Tweaks')
    foreach ($p in $loaded.Problems) { [Console]::Error.WriteLine("$($p.Level): $($p.File): $($p.Message)") }
    if ($List) {
        $loaded.Tweaks | Sort-Object Section, Category, Id | ForEach-Object {
            [pscustomobject]@{ Id = $_.Id; Kind = $_.Kind; Section = $_.Section; Category = $_.Category; Risk = $_.Risk; State = Get-AkariState $_ }
        } | Format-Table -AutoSize | Out-String -Width 200 | Write-Output
        exit 0
    }
    $admin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]'Administrator')
    if (-not $admin) { [Console]::Error.WriteLine('Run Akari from an elevated PowerShell to Apply or Revert.'); exit 2 }
    # Outcome lines are the CLI's output; per-tweak log lines are not repeated
    $LogQueue = [Collections.Concurrent.ConcurrentQueue[string]]::new()
    if ($Preset -or $RevertPreset) {
        $name = if ($Preset) { $Preset } else { $RevertPreset }
        $p = Find-AkariPreset $name (Join-Path $PSScriptRoot 'Presets')
        if (-not $p) { [Console]::Error.WriteLine("No preset '$name' (built-in, in $AkariPresetDir, or a .json file)."); exit 2 }
        # wildcards (appx/*, capability/*, feature/*) mean what is on this PC; a preset with Phases restarts the PC
        # between them and goes on in Akari's console (Akari.ps1 -Resume)
        $r = New-AkariPresetRun $p $loaded -Revert:([bool]$RevertPreset)
        foreach ($u in $r.Unknown) { [Console]::Error.WriteLine("Warning: preset $($p.Name): '$u' is not a Tweak here") }
        $outcomes = @(Start-AkariPhases $r.Run $r.Tweaks | Where-Object { $_.Outcome })
    } else {
        $mode = if ($Apply) { 'Apply' } else { 'Revert' }
        $ids = if ($Apply) { $Apply } else { $Revert }
        $outcomes = @(Invoke-AkariRun $ids $mode $loaded.Tweaks)
    }
    foreach ($o in $outcomes) {
        $line = '{0,-9} {1}  {2}' -f $o.Outcome, $o.Id, $o.Message
        Write-Output $line
        Write-ErrLog $line
    }
    if ($outcomes | Where-Object { $_.Reboot }) { Write-Output 'Reboot pending' }
    if ($outcomes | Where-Object { $_.Outcome -eq 'Failed' }) { exit 1 }
    exit 0
}

# ---- a Run in phases goes on after a restart (RunOnce, Core\Phases.ps1); console only, no GUI
if ($Resume) {
    $admin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]'Administrator')
    if (-not $admin) {
        Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -WindowStyle Maximized -File `"$PSCommandPath`" -Resume" -Verb RunAs
        exit
    }
    foreach ($f in 'Log', 'Trusted', 'Registry', 'Loader', 'State', 'Runner', 'Appx', 'Winget', 'AppSetup', 'System', 'Presets', 'Phases', 'Restore') { . "$PSScriptRoot\Core\$f.ps1" }
    Write-AkariBanner 'AkariOS is continuing...'
    $run = Get-AkariRun
    if (-not $run) { Write-Log 'Nothing to continue.'; exit }
    $loaded = Get-AkariTweaks (Join-Path $PSScriptRoot 'Tweaks')
    $status = @(Start-AkariPhases $run (Get-AkariRunTweaks $run $loaded) | Where-Object { $_ -is [string] }) | Select-Object -Last 1
    if ($status -ne 'Restarting') { Write-AkariRunSummary $run.Outcomes; Write-Host '  Press Enter to close this window.'; [void][Console]::ReadLine() }
    exit
}

# ---- One-click phases 2 and 3 of the old imported bodies: started by RunOnce after a restart (OneClick\OneClick.ps1)
if ($OneClick) {
    $admin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]'Administrator')
    if (-not $admin) {
        Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -WindowStyle Maximized -File `"$PSCommandPath`" -OneClick $OneClick" -Verb RunAs
        exit
    }
    foreach ($f in 'Log', 'Registry', 'Phases') { . "$PSScriptRoot\Core\$f.ps1" }
    . "$PSScriptRoot\OneClick\OneClick.ps1"
    Write-AkariBanner 'AkariOS One-click is running...'
    [void](Invoke-AkariOneClick $OneClick $PSScriptRoot)
    exit
}

# ---- elevate once, and make sure we are STA (WPF needs it)
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]'Administrator')
$isSta = [Threading.Thread]::CurrentThread.GetApartmentState() -eq 'STA'
if (-not $isAdmin -or -not $isSta) {
    # the console stays visible next to the window: it is Akari's live log (Win11Debloat / Zoicware style)
    Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -STA -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

# ---- console: launch banner; every log line is printed here while Akari runs
. "$PSScriptRoot\Core\Log.ps1"
. "$PSScriptRoot\Core\Version.ps1"
Write-AkariBanner "AkariOS $AkariVersion is launching..."

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
# ---- Core: helpers, loader, state and runner (the background job loads the same files)
foreach ($f in 'Log', 'Trusted', 'Registry', 'Loader', 'State', 'Runner', 'Legacy', 'Appx', 'Winget', 'AppSetup', 'Restore', 'System', 'Presets', 'Phases', 'Version', 'Update') { . "$Root\Core\$f.ps1" }
# the folder an update replaces (none when run from GitHub through iex: that is always the latest)
$AkariInstallDir = if ($PSScriptRoot) { $Root } else { '' }
# after an update: the previous copy (<folder>.old) and the download folder go
Remove-AkariUpdateLeftover $AkariInstallDir
trap { Write-ErrLog "$($_.Exception.Message) $($_.InvocationInfo.PositionMessage)"; [void][Windows.MessageBox]::Show("Akari hit an error:`n`n$($_.Exception.Message)`n`n$($_.InvocationInfo.PositionMessage)", 'Akari'); exit }
# remove 'downloaded from the internet' marks so Windows never nags about these files
Get-ChildItem $Root -Filter *.ps1 -File -ErrorAction SilentlyContinue | Unblock-File -ErrorAction SilentlyContinue
foreach ($sub in 'Tweaks', 'UI', 'OneClick') { Get-ChildItem "$Root\$sub" -Recurse -File -ErrorAction SilentlyContinue | Unblock-File -ErrorAction SilentlyContinue }
$script:Tweaks = [System.Collections.Generic.List[object]]::new()
$script:RowCache   = @{}
$script:Cat    = 'Home'
$script:Busy   = $false
$script:Job    = $null
$script:Queue  = [System.Collections.Concurrent.ConcurrentQueue[string]]::new()

foreach ($need in 'UI\MainWindow.xaml', 'Tweaks') {
    if (-not (Test-Path "$Root\$need")) {
        [void][Windows.MessageBox]::Show("Missing: $Root\$need`n`nAkari.ps1 needs UI, Tweaks and Assets folders next to it.", 'Akari')
        exit
    }
}
$loaded = Get-AkariTweaks "$Root\Tweaks"
# legacy Add-Tweak files first (adapter), then the one-file tweaks
foreach ($t in @(Import-AkariLegacyTweaks "$Root\Tweaks") + @($loaded.Tweaks)) { $script:Tweaks.Add($t) }
# data-list Groups (the apps list): the Apps step builds Entries for installed apps the data file doesn't list
$script:Groups = @($loaded.Groups)
# legacy ids replaced by one-file Tweaks (Tweaks\Ported.psd1): Guided hides them, Optimize > Legacy keeps them
$script:Ported = $loaded.Ported
foreach ($p in @(Test-AkariPorted $script:Ported $script:Tweaks)) { $loaded.Problems.Add($p) }

# ---- GUI: Guided steps, shell, Legacy rows (UI\*.ps1), then show the window
foreach ($f in 'Selection', 'Cards', 'Apps', 'Steps', 'Shell', 'Rows', 'About') { . "$Root\UI\$f.ps1" }
[void]$window.ShowDialog()

# ---- One-click: the window closed to hand this console to the AkariOS preset's Run (Core\Phases.ps1 restarts the PC
# between its phases and goes on through Akari.ps1 -Resume)
if ($script:OneClickPath) {
    Write-AkariBanner 'AkariOS One-click is running...'
    # an AkariOS restore point before the first change (unless the window said no); if it fails, the user decides
    if ($script:OneClickRestore) {
        $rp = New-AkariRestorePoint 'AkariOS'
        if (-not $rp.Ok) {
            $go = [Windows.MessageBox]::Show("Akari could not create a restore point:`n`n$($rp.Message)`n`nRun AkariOS One-click without a restore point?", 'Akari', 'YesNo', 'Warning')
            if ($go -ne 'Yes') { Write-Log 'One-click cancelled: no restore point.'; exit }
        }
    }
    # not $preset: that is the -Preset parameter ([string]; names ignore case)
    $oneClickPreset = Read-AkariPreset $script:OneClickPath $true
    if (-not $oneClickPreset) { Write-Log "One-click: $($script:OneClickPath) could not be read."; [void][Console]::ReadLine(); exit }
    Write-Log 'Reading the apps and features on this PC...'
    $r = New-AkariPresetRun $oneClickPreset $loaded
    $status = @(Start-AkariPhases $r.Run $r.Tweaks | Where-Object { $_ -is [string] }) | Select-Object -Last 1
    if ($status -ne 'Restarting') { Write-AkariRunSummary $r.Run.Outcomes; Write-Host '  Press Enter to close this window.'; [void][Console]::ReadLine() }
}
