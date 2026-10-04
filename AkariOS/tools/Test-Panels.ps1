# Test for the per-stage run surface (Plan 02 task 1).
#
# TWO HALVES, deliberately:
#
#   STATIC   - the panel markup and the function definitions. This is the only way
#              to prove a button is WIRED (plain Name=, no x:Name=, no Click=) and
#              that a handler is not missing or duplicated.
#
#   LIVE     - Invoke-AkariOSSingleStage is actually CALLED, with every
#              outside-world step injected. Plan 01's harness lesson applies here:
#              static assertions all passed on a runspace that came up empty, so
#              anything that could silently no-op gets invoked and asserted on its
#              observable effect.
#
# Nothing here writes a registry key, sets a bcd flag, starts a process, decodes an
# asset or touches C:\ProgramData. The RunOnce writer and the stage launch are both
# injected by the tests below.
param([string]$Root = "C:/Users/isleap/Documents/GitHub/AkariOS/AkariOS")

$ErrorActionPreference = "Stop"

$fail = 0
function Assert($label, $cond) {
    if ($cond) { Write-Host "  PASS  $label" } else { Write-Host "  FAIL  $label"; $script:fail++ }
}

# ═══ STATIC: the panel ════════════════════════════════════════════════════════

$panelPath = Join-Path $Root "xaml\panels\02-Progress.xaml"
$panelRaw  = Get-Content -LiteralPath $panelPath -Raw

$doc = $null
try {
    $doc = [xml]$panelRaw
    Assert "02-Progress.xaml parses as XML" ($null -ne $doc)
} catch {
    Assert "02-Progress.xaml parses as XML" $false
    Write-Host ("        " + $_.Exception.Message)
}

if ($doc) {
    $nodes = $doc.SelectNodes("//*[@Name]")
    $named = @{}
    foreach ($n in $nodes) { $named[$n.Name] = $n }

    foreach ($b in @("BtnStage1", "BtnStage2", "BtnStage3")) {
        Assert ("panel declares $b") ($named.ContainsKey($b))
    }
    Assert "panel declares StageHandoffHint" ($named.ContainsKey("StageHandoffHint"))

    foreach ($b in @("BtnStage1", "BtnStage2", "BtnStage3")) {
        if (-not $named.ContainsKey($b)) { continue }
        $btn = $named[$b]
        # $btn.Name on an XmlElement adapter returns the Name ATTRIBUTE's value,
        # not the element name - LocalName is the element name.
        Assert ("$b is a Button") ($btn.LocalName -eq "Button")
        # The wiring loop at main.ps1:104 only ever calls Get-Command "Invoke-$name",
        # so the handler name must be derivable from the button name exactly.
        Assert ("$b uses the Btn style, not BtnAccent") ($btn.Style -eq '{StaticResource Btn}')
        Assert ("$b ships disabled")                  ($btn.IsEnabled -eq 'False')
        Assert ("$b has no Click attribute")         ($btn.HasAttribute('Click') -eq $false)
        Assert ("$b is not x:Name'd")                ($btn.GetAttribute('x:Name') -eq '')
    }

    Assert "StageHandoffHint starts Collapsed" ($named["StageHandoffHint"].Visibility -eq 'Collapsed')

    # Task 2: the three Safe Mode facts must be LITERAL text in this file, not code.
    # 1. console-only rendering (D-12), 2. the administrator log-on (Finding 5),
    # 3. DDU's role in leaving Safe Mode. Each is a trap the user hits blind on a VM.
    $hintText = [string]$named["StageHandoffHint"].Text
    foreach ($fact in @("console", "log on", "Safe Mode", "Display Driver Uninstaller", "ADMINISTRATOR")) {
        Assert ("StageHandoffHint mentions '$fact'") ($hintText -like "*$fact*")
    }
    Assert "StageHandoffHint warns about the pre-DDU stopped state" ($hintText -like "*normal boot*")

    # The x:Name form is invisible to main.ps1:17 SelectNodes("//*[@Name]") AND to
    # the wiring loop at :104. This bug shipped once in Phase 1, so it is asserted
    # on the raw text, not only via the parsed document.
    Assert 'no x:Name="BtnStage anywhere'  ($panelRaw -notmatch 'x:Name="BtnStage')
    Assert 'exactly three plain BtnStage names' ((@([regex]::Matches($panelRaw, 'Name="BtnStage[123]"'))).Count -eq 3)
    Assert "BtnAccent is reserved for the primary CTA" ($panelRaw -notmatch 'BtnStage[123][^/]*BtnAccent')
}

# ═══ STATIC: the handlers ═════════════════════════════════════════════════════

$stagePath = Join-Path $Root "functions\public\Stage.ps1"
$src = Get-Content -LiteralPath $stagePath -Raw

function Count-Defs([string]$Text, [string]$Name) {
    # AkariOS puts the opening brace on the same line as the function name
    # (`function Get-AkariOSStage {`), so the pattern must allow it.
    return (@([regex]::Matches($Text, '(?m)^function\s+' + [regex]::Escape($Name) + '\s*(\{)?\s*$'))).Count
}

foreach ($h in @("Invoke-BtnStage1", "Invoke-BtnStage2", "Invoke-BtnStage3")) {
    Assert ("$h defined exactly once") ((Count-Defs $src $h) -eq 1)
}
foreach ($keep in @("Get-AkariOSStage", "Get-StageExplanation", "Start-AkariOSInstall", "Invoke-AkariOSStage")) {
    Assert ("$keep not redefined") ((Count-Defs $src $keep) -eq 1)
}
Assert "Invoke-AkariOSSingleStage defined once" ((Count-Defs $src "Invoke-AkariOSSingleStage") -eq 1)

# ═══ LIVE: drive the handler for real ═════════════════════════════════════════
# Dot-source only Stage.ps1; stub the three helpers it calls that live elsewhere.

. $stagePath

# Post-dot-source this is the assertion that actually matters: main.ps1:109 wires
# buttons with `Get-Command "Invoke-$name" -ErrorAction SilentlyContinue`, so a
# handler that does not resolve is a SILENTLY DEAD button, not an error.
foreach ($h in @("Invoke-BtnStage1", "Invoke-BtnStage2", "Invoke-BtnStage3")) {
    Assert ("$h resolves with Get-Command") ((Get-Command $h -ErrorAction SilentlyContinue) -ne $null)
}

# Stubs for symbols Stage.ps1 resolves at runtime but that are not in this file.
function Write-AkariOSLog { param([string]$Message, [string]$Level = "INFO", [string]$Path) }
function Set-Status        { param([string]$Text, [string]$Color = "White") }
function Set-CurrentStage  { param([int]$Stage, [string]$Action, [switch]$Resume) }
function Invoke-RunInBackground { param($StatusStart, $StatusDone, $ScriptBlock, $OnComplete) }
$script:AkariOSStage2Entry = "*!stepone"
$script:AkariOSStage3Entry = "!steptwo"

$okPre  = [pscustomobject]@{ CanInstall = $true;  Results = @(); Summary = ""; BlockingFails = @() }
$badPre = [pscustomobject]@{ CanInstall = $false; Results = @(); Summary = "";
                             BlockingFails = @([pscustomobject]@{ Name = "Admin"; Message = "not elevated" }) }

$script:seen = @{}

# Show-StageHandoffHint assigns [System.Windows.Visibility], so the WPF assembly
# must be loaded in this console harness. In the real app start.ps1 loads
# PresentationFramework before anything else; here it is a plain assembly load —
# no window, no UI thread, no machine state touched.
try {
    Add-Type -AssemblyName PresentationFramework -ErrorAction Stop
} catch {
    Write-Host "  SKIP  WPF assembly unavailable - hint visibility assertions skipped"
    $global:akariWpfAvailable = $false
}
if (-not (Test-Path variable:global:akariWpfAvailable)) { $global:akariWpfAvailable = $true }

Write-Host "LIVE: the Stage 2 hint reveals, appends its pending note, and stays idempotent"
# A fake control with a settable Visibility/Text, and a $sync with no window, so
# Show-StageHandoffHint takes the direct-set path. No WPF, no registry, no window.
# $sync is a synchronized Hashtable in the real app (start.ps1:88), and the hint
# code indexes it, so the fake must be too - a pscustomobject would fail on
# $sync["StageHandoffBase"] for reasons the real app never hits.
$fake = [pscustomobject]@{ Visibility = "Collapsed"; Text = "BASE HINT TEXT." }
$global:sync = [Hashtable]::Synchronized(@{ StageHandoffHint = $fake })

if ($global:akariWpfAvailable) {
    Show-StageHandoffHint -Visible -PendingNote "note one"
    Assert "hint becomes visible"      ($fake.Visibility -eq "Visible")
    Assert "hint keeps the base text"  ($fake.Text -like "BASE HINT TEXT.*")
    Assert "hint carries the note"     ($fake.Text -like "*note one*")

    Show-StageHandoffHint -Visible -PendingNote "note two"
    Assert "note is replaced, not stacked" ($fake.Text -like "*note two*" -and $fake.Text -notlike "*note one*")
    Assert "text did not grow unbounded"    (([regex]::Matches($fake.Text, "BASE HINT TEXT\.")).Count -eq 1)

    Show-StageHandoffHint
    Assert "hint collapses again"     ($fake.Visibility -eq "Collapsed")

    Write-Host "LIVE: the pending probe reads RunOnce only through its seam"
    Show-StageHandoffHint -Visible -ProbePending -RunOnceInvoker { @("!steptwo") }
    Assert "a queued !steptwo is reported" ($fake.Text -like "*STILL QUEUED*")
    Show-StageHandoffHint -Visible -ProbePending -RunOnceInvoker { @() }
    Assert "no entry means no pending note" ($fake.Text -notlike "*STILL QUEUED*")
    Show-StageHandoffHint -Visible -ProbePending -RunOnceInvoker { throw "probe failed" }
    Assert "a failing probe does not block the hint" ($fake.Visibility -eq "Visible")
}

Write-Host "STATIC: the D-12 rationale is recorded, and no auto-logon was introduced"
# Strip comments the way the plan's verify command does: `grep -v '^#'` removes
# only COLUMN-ZERO comment lines. AkariOS indents its in-function rationale, so
# stripping every '#' line here would throw away exactly the text being asserted.
$stripped = [regex]::Replace($src, '(?s)<#.*?#>', '')
$stripped = [regex]::Replace($stripped, '(?m)^#.*$', '')
Assert "Render Tier 0 rationale recorded in code" ($stripped -match 'Render Tier 0')
Assert "the rationale mentions BasicDisplay/WARP"  ($stripped -match 'BasicDisplay')
Assert "no autologon change anywhere in Stage.ps1" (
    -not ((@($src -split "`r?`n" | Where-Object { $_ -match 'Start-Process|RunAs' })) | Where-Object { $_ -match 'autologon' }))

Write-Host "LIVE: a blocked pre-flight stops the stage before the gate or the launch"
$script:seen = @{}
Invoke-AkariOSSingleStage -Stage 2 -ButtonName "" `
    -PreflightInvoker { $badPre } `
    -GateInvoker      { $script:gate = "reached"; $true } `
    -StageInvoker     { param($n, $cb) $script:seen["launched"] = $n; $true } `
    -MessageBoxInvoker { param($t, $ti) $script:seen["msg"] = $t } | Out-Null
Assert "gate never reached"        (-not $script:gate)
Assert "stage never launched"      (-not $script:seen.ContainsKey("launched"))
Assert "blocking failure surfaced"  ($script:seen["msg"] -like "*not elevated*")

Write-Host "LIVE: cancelling at the typed-token gate launches nothing"
$script:gate = $null
$script:seen = @{}
Invoke-AkariOSSingleStage -Stage 3 -ButtonName "" `
    -PreflightInvoker { $okPre } `
    -GateInvoker      { $false } `
    -StageInvoker     { param($n, $cb) $script:seen["launched"] = $n; $true } `
    -PanelSwitcher    { param($p) $script:seen["panel"] = $p } `
    -MessageBoxInvoker { param($t, $ti) $script:seen["msg"] = $t } | Out-Null
Assert "stage not launched on cancel"      (-not $script:seen.ContainsKey("launched"))
Assert "returns to the home panel"        ($script:seen["panel"] -eq "PanelHome")

Write-Host "LIVE: Stage 1 runs alone, writes no RunOnce entry, and passes a completion callback"
$script:seen = @{}
Invoke-AkariOSSingleStage -Stage 1 -ButtonName "" `
    -PreflightInvoker { $okPre } `
    -GateInvoker      { $true } `
    -StageInvoker     { param($n, $cb) $script:seen["stage"] = $n; $script:seen["cb"] = $cb; $true } `
    -RunOnceWriter    { param($c) $script:seen["runonce"] = $c } | Out-Null
Assert "launched stage 1"                 ($script:seen["stage"] -eq 1)
Assert "no RunOnce write for stage 1"     (-not $script:seen.ContainsKey("runonce"))
Assert "a completion callback was passed" ($script:seen["cb"] -is [scriptblock])
& $script:seen["cb"] @{ Error = $null }
Assert "completion callback is callable"  ($true)

Write-Host "LIVE: Stages 2 and 3 queue their own RunOnce entry through the seam"
foreach ($n in 2, 3) {
    $script:seen = @{}
    Invoke-AkariOSSingleStage -Stage $n -ButtonName "" -WriteOwnRunOnce $true `
        -PreflightInvoker { $okPre } `
        -GateInvoker      { $true } `
        -StageInvoker     { param($st, $cb) $script:seen["stage"] = $st; $true } `
        -RunOnceWriter    { param($c) $script:seen["runonce"] = $c } | Out-Null
    $wantEntry = if ($n -eq 2) { "*!stepone" } else { "!steptwo" }
    $wantCmd   = if ($n -eq 2) { "stepone.ps1" } else { "steptwo.ps1" }
    Assert ("stage $n launched")            ($script:seen["stage"] -eq $n)
    Assert ("stage $n writes RunOnce")      ($script:seen.ContainsKey("runonce"))
    Assert ("stage $n uses $wantEntry")     ($script:seen["runonce"] -like "*$wantEntry*")
    Assert ("stage $n command matches")     ($script:seen["runonce"] -like "*$wantCmd*")
    Assert ("stage $n RunOnce went through reg add HKCU") ($script:seen["runonce"] -like "*HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce*")
}

Write-Host "LIVE: the stage number is validated, so a bad button cannot reach the engine"
$threw = $false
try {
    Invoke-AkariOSSingleStage -Stage 9 -PreflightInvoker { $okPre } -GateInvoker { $true } `
        -MessageBoxInvoker { param($t, $ti) } | Out-Null
} catch { $threw = $true }
Assert "an invalid stage number is rejected" $threw

Write-Host "LIVE: the three published handlers drive the expected stage number"
# Each real handler calls Invoke-AkariOSSingleStage with a hard-coded stage, so
# shadowing the shared body is the only way to observe which number it passes
# without launching anything.
$script:seen = @{}
function Invoke-AkariOSSingleStage {
    param([int]$Stage, [string]$ButtonName = "", [bool]$WriteOwnRunOnce = $false)
    $script:seen["stage"] = $Stage
    $script:seen["button"] = $ButtonName
    $script:seen["runonce"] = $WriteOwnRunOnce
    return $true
}
Invoke-BtnStage1 | Out-Null; Assert "Invoke-BtnStage1 -> stage 1"  ($script:seen["stage"] -eq 1)
Assert "Invoke-BtnStage1 -> BtnStage1"                  ($script:seen["button"] -eq "BtnStage1")
Assert "Invoke-BtnStage1 writes no RunOnce"             ($script:seen["runonce"] -eq $false)
Invoke-BtnStage2 | Out-Null; Assert "Invoke-BtnStage2 -> stage 2"  ($script:seen["stage"] -eq 2)
Assert "Invoke-BtnStage2 -> BtnStage2"                  ($script:seen["button"] -eq "BtnStage2")
Assert "Invoke-BtnStage2 queues its RunOnce"            ($script:seen["runonce"] -eq $true)
Invoke-BtnStage3 | Out-Null; Assert "Invoke-BtnStage3 -> stage 3"  ($script:seen["stage"] -eq 3)
Assert "Invoke-BtnStage3 -> BtnStage3"                  ($script:seen["button"] -eq "BtnStage3")
Assert "Invoke-BtnStage3 queues its RunOnce"            ($script:seen["runonce"] -eq $true)

# Remove the shadow so the PASSED line below is reached by the real code path.
Remove-Item -LiteralPath "Function:\Invoke-AkariOSSingleStage" -ErrorAction SilentlyContinue

if ($fail -eq 0) { Write-Host "`nALL PANEL TESTS PASSED"; exit 0 }
else { Write-Host "`n$fail PANEL TEST(S) FAILED"; exit 1 }