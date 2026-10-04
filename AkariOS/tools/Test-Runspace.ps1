# Static assertions on Invoke-RunInBackground. The runner needs a WPF thread and a
# DispatcherTimer to execute, which this machine must not host, so this reads the
# file as text and asserts on its shape rather than invoking it.
#
# Why static is enough here: every property under test is a source-level property —
# which variable type carries the result, whether a callback parameter exists,
# whether the session state is built from our own functions. None of them is
# observable without a dispatcher.
param([string]$Root = "C:/Users/isleap/Documents/GitHub/AkariOS/AkariOS")

$ErrorActionPreference = "Stop"

$fail = 0
function Assert($label, $cond) {
    if ($cond) { Write-Host "  PASS  $label" } else { Write-Host "  FAIL  $label"; $script:fail++ }
}

$path = Join-Path $Root "functions\private\Invoke-RunInBackground.ps1"
Assert "the runner exists" (Test-Path -LiteralPath $path)

$raw = Get-Content -LiteralPath $path -Raw

# Strip BOTH comment forms — the docstrings legitimately NAME $done, GetNewClosure
# and CreateRunspace while explaining the bug they describe. We assert on the code.
$src = [regex]::Replace($raw, '(?s)<#.*?#>', '')      # block comments
$src = [regex]::Replace($src, '(?m)^\s*#.*$', '')      # line comments
$lines = @($src -split "`r?`n")

Write-Host "T-02-12: the result travels in a hashtable, not by-value locals"
Assert "the outcome hashtable exists"      ($src -match '\$outcome\s*=\s*@\{')
Assert "it carries Done"                   ($src -match '\$outcome\s*=\s*@\{[^}]*Done')
Assert "it carries Error"                  ($src -match '\$outcome\s*=\s*@\{[^}]*Error')
$errReads = @($lines | Where-Object { $_ -match '\$outcome\.Error' }).Count
Assert "outcome.Error read/written 2+ times" ($errReads -ge 2)
Assert "no bare `$error` local assignment"  ($src -notmatch '(?m)^\s*\$error\s*=')
Assert "no bare `$done` local assignment"   ($src -notmatch '(?m)^\s*\$done\s*=')
# The old shape: a local mutated inside the closure then read outside it.
Assert "no `$error` inside the tick handler" ($src -notmatch '\{\s*\$error\s*=')
Assert "no `[ref]` result hand-back"        ($src -notmatch '\[ref\]')

Write-Host "T-02-13: the -OnComplete seam exists and is documented"
Assert "param declared in the param block"  ($src -match '(?s)param\s*\(.*\[scriptblock\]\$OnComplete')
Assert "documented in the help block"       ($raw -match '\.PARAMETER OnComplete')
Assert "invoked in the tick handler"        ($src -match '&\s*\$OnComplete\s+\$outcome')
Assert "guarded when absent"                ($src -match 'if\s*\(\s*\$OnComplete\s*\)')
Assert "callback failure is swallowed+logged" ($src -match 'OnComplete callback failed')

Write-Host "T-02-14: the runspace really gets our functions and script-scope constants"
Assert "CreateDefault2 is used"             ($src -match 'InitialSessionState\]::CreateDefault2\(\)')
Assert "CreateRunspace takes the ISS"       ($src -match 'CreateRunspace\(\$iss\)')
Assert "no bare CreateRunspace() left"      ($src -notmatch 'CreateRunspace\(\s*\)')
Assert "function files are read from disk"  ($src -match 'Get-ChildItem\s+-LiteralPath\s+\$dir')
Assert "sorted so new files are picked up"  ($src -match 'Sort-Object Name')
Assert "PSScriptRoot anchors the search"    ($src -match '\$PSScriptRoot')
Assert "files are DOT-SOURCED, not AddScript-ed" ($src -match '\$loadLines\s*\+=\s*\(')
Assert "the prelude is added before the job" ($src -match 'if\s*\(\$prelude\)\s*\{\s*\$null\s*=\s*\$ps\.AddScript\(\$prelude\)\s*\}')
Assert "the job scriptblock is added after" ($src -match '\$ps\.AddScript\(\$ScriptBlock\)')
# AddScript on an InitialSessionState does not exist on PowerShell 5.1.
Assert "no ISS.AddScript (does not exist on 5.1)" ($src -notmatch '\$iss\.AddScript')

Write-Host "The prelude order is: AddScript(prelude) BEFORE AddScript(ScriptBlock)"
$preIdx  = $src.IndexOf('AddScript($prelude)')
$jobIdx  = $src.IndexOf('AddScript($ScriptBlock)')
Assert "prelude precedes the job"  ($preIdx -ge 0 -and $jobIdx -gt $preIdx)

Write-Host "Phase 1 behaviour is preserved"
Assert "sync is still injected"             ($src -match 'SessionStateProxy\.SetVariable\("sync"')
Assert "STA apartment kept"                 ($src -match 'ApartmentState\s*=\s*"STA"')
Assert "ReuseThread kept"                   ($src -match 'ThreadOptions\s*=\s*"ReuseThread"')
Assert "runspace tracked for cleanup"       ($src -match '\$sync\.runspaces\.Add\(')
Assert "non-blocking BeginInvoke marshal kept" ($src -match '\$ps\.BeginInvoke\(\)')
Assert "dispatcher timer watcher kept"      ($src -match 'DispatcherTimer' -and $src -match 'Add_Tick')
Assert "failure still shows a red status"   ($src -match '"#FF3333"')

Write-Host "The default parameters stay optional so Phase 1's caller keeps working"
# Match to the LAST closing paren of the block, not the first: [Parameter(Mandatory)]
# contains one, so a non-greedy (.*?)\) would truncate the block.
$block = [regex]::Match($src, '(?s)param\s*\(((?:[^()]|\([^()]*\))*)\)').Groups[1].Value
Assert "param block extracted"        ($block.Length -gt 0)
Assert "only ScriptBlock is mandatory" (@([regex]::Matches($block, 'Mandatory')).Count -eq 1)
Assert "StatusStart has a default"     ($block -match '\$StatusStart\s*=')
Assert "StatusDone has a default"      ($block -match '\$StatusDone\s*=')
Assert "OnComplete is optional"        ($block -match '\$OnComplete' -and $block -notmatch 'Mandatory[^)]*\$OnComplete')

Write-Host "Check.ps1's only call site still binds"
Assert "Invoke-RunInBackground is called"   (@(Get-ChildItem -LiteralPath (Join-Path $Root "functions\public") -File -Filter *.ps1 |
    Select-String -Pattern 'Invoke-RunInBackground').Count -ge 1)

# ── LIVE runspace check ───────────────────────────────────────────────────────
# The static assertions above cannot tell a working session-state build from one
# that silently produces an EMPTY runspace — which is exactly what happened: the
# SessionStateFunctionEntry approach carried the functions over but dropped every
# `$script:` constant, so the RunOnce entry names vanished and nothing errored.
# This builds a runspace the SAME way the runner does (minus the WPF parts: no
# DispatcherTimer, no $sync) and calls our own functions from inside it.
Write-Host "LIVE: a runspace built this way really resolves our functions"
$privateDir = Split-Path -Parent $path
$loadLines = @()
foreach ($dir in @((Join-Path $privateDir "..\public"), $privateDir)) {
    if (-not (Test-Path -LiteralPath $dir)) { continue }
    foreach ($f in (Get-ChildItem -LiteralPath $dir -File -Filter "*.ps1" -ErrorAction SilentlyContinue | Sort-Object Name)) {
        $loadLines += ('. "{0}"' -f $f.FullName.Replace("'", "''"))
    }
}
$prelude = ($loadLines -join "`n")

$iss = [System.Management.Automation.Runspaces.InitialSessionState]::CreateDefault2()
$rs  = [runspacefactory]::CreateRunspace($iss)
$rs.ApartmentState = "STA"
$rs.Open()
try {
    $worker = [powershell]::Create()
    $null = $worker.AddScript($prelude)
    $null = $worker.AddScript({
        $have = @()
        foreach ($fn in @("Get-AkariOSRunOnceCommand","Invoke-AkariOSEngine","Expand-AkariOSEngineAsset",
                          "Set-BcdSafebootValue","Clear-BcdSafebootValue","Set-AkariOSRunOnceEntry",
                          "Invoke-AkariOSStage","Start-AkariOSInstall","Get-ResumePoint",
                          "Get-AkariOSState","Write-AkariOSLog","Invoke-PreFlightChecks")) {
            if (Get-Command $fn -ErrorAction SilentlyContinue) { $have += $fn }
        }
        $cap = $null
        Set-BcdSafebootValue -BcdWriter { param($c) $script:cap = $c } | Out-Null
        [pscustomobject]@{
            Found    = $have
            Command2 = (Get-AkariOSRunOnceCommand -Stage 2)
            Bcd      = $cap
            Entry2   = $script:AkariOSStage2Entry
            AssetReg = (Get-AkariOSAssetFileName -Name "reg")
            Errors   = $ps.Streams.Error.Count
        }
    })
    $worker.Runspace = $rs
    $out = $worker.Invoke()

    $found = @($out[0].Found)
    foreach ($fn in @("Get-AkariOSRunOnceCommand","Invoke-AkariOSEngine","Expand-AkariOSEngineAsset",
                      "Set-BcdSafebootValue","Clear-BcdSafebootValue","Set-AkariOSRunOnceEntry",
                      "Invoke-AkariOSStage","Start-AkariOSInstall","Get-ResumePoint",
                      "Get-AkariOSState","Write-AkariOSLog","Invoke-PreFlightChecks")) {
        Assert "runspace resolves $fn" ($found -contains $fn)
    }
    # The `$script:` constants are the regression this live check exists for.
    Assert "script-scope entry name survives" ($out[0].Entry2 -eq "*!stepone")
    Assert "script-scope asset table survives" ($out[0].AssetReg -eq "reg.reg")
    Assert "a pure function RUNS in-runspace" (
        $out[0].Command2 -ceq ("powershell.exe -nop -ep bypass -WindowStyle Maximized -f $(Join-Path $env:SystemRoot 'Temp')" + "\stepone.ps1"))
    Assert "an injected seam is honoured in-runspace" (
        $out[0].Bcd -ceq 'cmd /c "bcdedit /set {current} safeboot minimal >nul 2>&1"')
    Assert "no errors in the runspace" ($out[0].Errors -eq 0)
} finally {
    $rs.Close()
    $rs.Dispose()
}

if ($fail -eq 0) { Write-Host "`nALL RUNSPACE TESTS PASSED"; exit 0 }
else { Write-Host "`n$fail RUNSPACE TEST(S) FAILED"; exit 1 }