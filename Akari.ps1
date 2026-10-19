#requires -Version 5.1
param([ValidateRange(1, 3)][int]$OneClick, [switch]$List, [string[]]$Apply, [string[]]$Revert)
# Akari. GUI:  powershell -ExecutionPolicy Bypass -File Akari.ps1
# One-click phases (RunOnce after a restart):  Akari.ps1 -OneClick 2|3
# CLI:  Akari.ps1 -List  |  Akari.ps1 -Apply id,id  |  Akari.ps1 -Revert id,id   (Apply/Revert need an elevated shell)

# ---- CLI: no relaunch, no WPF
if ($List -or $Apply -or $Revert) {
    $CoreDir = Join-Path $PSScriptRoot 'Core'
    foreach ($f in 'Log', 'Trusted', 'Registry', 'Loader', 'State', 'Runner', 'Appx', 'Winget', 'AppSetup', 'System') { . "$CoreDir\$f.ps1" }
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
    $mode = if ($Apply) { 'Apply' } else { 'Revert' }
    $ids = if ($Apply) { $Apply } else { $Revert }
    # Outcome lines are the CLI's output; per-tweak log lines are not repeated
    $LogQueue = [Collections.Concurrent.ConcurrentQueue[string]]::new()
    $outcomes = @(Invoke-AkariRun $ids $mode $loaded.Tweaks)
    foreach ($o in $outcomes) {
        $line = '{0,-9} {1}  {2}' -f $o.Outcome, $o.Id, $o.Message
        Write-Output $line
        Write-ErrLog $line
    }
    if ($outcomes | Where-Object { $_.Reboot }) { Write-Output 'Reboot pending' }
    if ($outcomes | Where-Object { $_.Outcome -eq 'Failed' }) { exit 1 }
    exit 0
}

# ---- One-click phases 2 and 3: started by RunOnce after a restart (OneClick\OneClick.ps1); console only, no GUI
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
Write-AkariBanner 'AkariOS is launching...'

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
foreach ($f in 'Log', 'Trusted', 'Registry', 'Loader', 'State', 'Runner', 'Legacy', 'Appx', 'Winget', 'AppSetup', 'Restore', 'System') { . "$Root\Core\$f.ps1" }
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
foreach ($f in 'Selection', 'Cards', 'Apps', 'Steps', 'Shell', 'Rows') { . "$Root\UI\$f.ps1" }
[void]$window.ShowDialog()

# ---- One-click: the window closed to hand this console to the Akari-OS run (it restarts the PC itself)
if ($script:OneClickPath) {
    . "$Root\Core\Phases.ps1"
    . "$Root\OneClick\OneClick.ps1"
    Write-AkariBanner 'AkariOS One-click is running...'
    # an AkariOS restore point before the first change (unless the window said no); if it fails, the user decides
    if ($script:OneClickRestore) {
        $rp = New-AkariRestorePoint 'AkariOS'
        if (-not $rp.Ok) {
            $go = [Windows.MessageBox]::Show("Akari could not create a restore point:`n`n$($rp.Message)`n`nRun AkariOS One-click without a restore point?", 'Akari', 'YesNo', 'Warning')
            if ($go -ne 'Yes') { Write-Log 'One-click cancelled: no restore point.'; exit }
        }
    }
    [void](Invoke-AkariOneClick 1 $Root)
}
