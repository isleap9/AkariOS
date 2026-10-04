<#
    Test-RunspaceClosure.ps1 — regression test for the closure-across-runspace bug
    that made Stage 1 report success while launching nothing.

    THE BUG (confirmed on a VM)
        Stage.ps1 built its worker scriptblock as:

            ScriptBlock = { Invoke-AkariOSEngine -ScriptPath $enginePath ... }.GetNewClosure()

        GetNewClosure() rebinds the closure to the MODULE of the scope that
        created it. That module does not exist in a runspace built by
        [runspacefactory]::, so every captured variable resolves to EMPTY in the
        worker. Proven three ways in the probe this file is modelled on:
          - plain scriptblock over an injected variable -> value returned
          - identical text, variable injected           -> value returned
          - same text through GetNewClosure()          -> "" returned

        So -ScriptPath arrived as "", its mandatory binding threw, and
        Invoke-RunInBackground's outcome handling turned that into an empty
        Results set. The supervisor read that as exit code 0 and logged
        "Stage 1 engine process completed." 359 ms after launch.

        Two signatures, both observed:
          - Stage.ps1:289 ("Engine child process for ... exited with code N"),
            the first unconditional log inside Invoke-AkariOSEngine, never
            appeared in install.log.
          - C:\WINDOWS\Temp held only winsux.ps1 (decoded by AkariOS itself).
            winsux.ps1:28-29 downloads stepone.ps1, steptwo.ps1 and reg.reg on
            its first run, so the engine had demonstrably never executed.

        Every previous harness passed because they all checked that the script
        block was BUILT, or injected their own -EngineInvoker so the empty path
        never mattered. Nothing asserted that the real value survives the trip
        into the worker.

    THE FIX
        Hand state to the worker on $sync, which Invoke-RunInBackground already
        injects (Invoke-RunInBackground.ps1:87), and read it by name inside the
        worker. The scriptblock must contain NO GetNewClosure().

    Run: powershell -NoProfile -ExecutionPolicy Bypass -File ./tools/Test-RunspaceClosure.ps1
#>

param([string]$Root = "C:/Users/isleap/Documents/GitHub/AkariOS/AkariOS")

$ErrorActionPreference = "Stop"
$fail = 0; $checks = 0
$scratch = Join-Path $env:TEMP ("akarios-clos-" + [guid]::NewGuid().ToString("N").Substring(0,8))

function Assert {
    param([string]$Label, [bool]$Condition, [string]$Detail = "")
    $script:checks++
    if ($Condition) { Write-Host "  PASS  $Label" }
    else {
        $script:fail++
        if ($Detail) { Write-Host "        $Detail" -ForegroundColor DarkGray }
        Write-Host "  FAIL  $Label" -ForegroundColor Red
    }
}
function Strip-Comments { param([string]$T)
    $t = [regex]::Replace($T, '(?s)<#.*?#>', '')
    [regex]::Replace($t, '(?m)^\s*#.*$', '')
}

New-Item -ItemType Directory -Path $scratch -Force | Out-Null
try {
# ─────────────────────────────────────────────────────────────────────────────
Write-Host "No worker-bound scriptblock uses GetNewClosure()"
# ─────────────────────────────────────────────────────────────────────────────

$stageSrc = Strip-Comments (Get-Content -LiteralPath (Join-Path $Root "functions\public\Stage.ps1") -Raw)

# The worker ScriptBlock is the one handed to Invoke-RunInBackground. Locate it
# by its defining key and take everything up to the OnComplete key, so the
# assertion cannot be satisfied by a GetNewClosure() in unrelated code.
$sbStart = $stageSrc.IndexOf("ScriptBlock = {")
$ocStart = $stageSrc.IndexOf("OnComplete  = {")
Assert "found the worker ScriptBlock" ($sbStart -gt 0)
Assert "found the OnComplete callback"  ($ocStart -gt 0 -and $ocStart -gt $sbStart)

if ($sbStart -gt 0 -and $ocStart -gt $sbStart) {
    $workerBlock = $stageSrc.Substring($sbStart, $ocStart - $sbStart)
    Assert "worker ScriptBlock does NOT call GetNewClosure()" `
        ($workerBlock -notmatch 'GetNewClosure') `
        "A closure over $enginePath/$EngineInvoker resolves to empty in the worker runspace."
}

# ─────────────────────────────────────────────────────────────────────────────
Write-Host "State is handed to the worker on `$sync, which the runner injects"
# ─────────────────────────────────────────────────────────────────────────────

$runnerSrc = Strip-Comments (Get-Content -LiteralPath (Join-Path $Root "functions\private\Invoke-RunInBackground.ps1") -Raw)
Assert "runner injects `$sync into the worker" ($runnerSrc -match 'SetVariable\(\s*"sync"\s*,\s*\$sync\s*\)') `
    "The hand-off mechanism depends on this. If it is renamed, `$sync lookups in the worker go empty too."

Assert "stage publishes the engine path onto `$sync" `
    ($stageSrc -match '\$sync\[\$jobKey\]\s*=\s*@\{' -and $stageSrc -match 'EnginePath\s*=\s*\$enginePath')
Assert "worker scriptblock reads the hand-off back off `$sync" `
    ($stageSrc -match "\`$sync\['AkariOSJob'\]")
Assert "worker throws when the hand-off is absent" `
    ($stageSrc -match "No AkariOS job hand-off present") `
    "Without this the worker would silently run nothing again."

# ─────────────────────────────────────────────────────────────────────────────
Write-Host "The empty-path failure cannot be mistaken for success again"
# ─────────────────────────────────────────────────────────────────────────────
# The supervisor treats an empty Results set as exit code 0. That inference is
# what turned a hard failure into "Stage 1 engine process completed." The engine
# must therefore never be able to return nothing.
Assert "supervisor flags a job that produced no output at all" `
    ($stageSrc -match '\$producedNothing') `
    "Nothing distinguishes 'the engine ran and returned 0' from 'the engine never ran'. " +
    "Without this an empty Results set silently reads as exit code 0."
# Matching only the identifier is too weak: removing it from the CONDITION leaves
# the assignment and the `elseif ($producedNothing)` branch in place, so a naive
# presence check still passes while the guard no longer protects anything. The
# assertion has to find it in the decision itself.
$ocBlock = $stageSrc.Substring($ocStart)
Assert "the failure condition actually includes the no-output case" `
    ($ocBlock -match '(?s)if\s*\(\s*\$errText\s+-or\s+\$exitCode\s+-ne\s+0\s+-or\s+\$producedNothing\s*\)') `
    "The guard is assigned but not consulted - an empty result set would still read as success."
Assert "empty results are tracked separately from exit code" `
    ($ocBlock -match '\$sawOutput\s*=\s*\$false') `
    "Without an explicit 'did we see any output' flag, Results=@() and Results=@(0) are indistinguishable."

Assert "OnComplete is allowed to close over the main scope (it is main-thread)" `
    ($stageSrc -match '(?s)OnComplete\s*=\s*\{.{0,4000}?GetNewClosure\(\)') `
    "OnComplete fires from the DispatcherTimer on the MAIN thread, where GetNewClosure works. " +
    "Asserting its absence here would be wrong - the two callbacks are not symmetric."

# ─────────────────────────────────────────────────────────────────────────────
Write-Host "Behavioural check: a real closure really does go empty in a worker"
# ─────────────────────────────────────────────────────────────────────────────
# Executed so the comment above is a verified claim rather than an assertion
# taken on faith. Uses a throwaway value and touches nothing.
$val = "akarios-closure-probe"
$closed = { $val }.GetNewClosure()
$direct = & $closed
$rs = [runspacefactory]::CreateRunspace()
try {
    $rs.Open()
    $ps = [powershell]::Create()
    $ps.Runspace = $rs
    $null = $ps.AddScript($closed)
    $worker = $ps.Invoke()
    Assert "GetNewClosure() works on its defining thread" ($direct -eq $val)
    Assert "GetNewClosure() returns empty in a foreign runspace" ([string]$worker -eq "") `
        ("If this ever becomes non-empty the premise changes: got '" + $worker + "'. " +
         "The `$sync hand-off would then be removable.")
    $ps.Dispose()
} finally {
    if ($rs.RunspaceStateInfo.State -eq 'Opened') { $rs.Close() }
    $rs.Dispose()
}

# Plain scriptblock + injected variable is the mechanism that DOES work, so pin
# that it stays available as the thing to fall back on.
$rs2 = [runspacefactory]::CreateRunspace()
try {
    $rs2.Open()
    $rs2.SessionStateProxy.SetVariable("injected", $val)
    $ps2 = [powershell]::Create()
    $ps2.Runspace = $rs2
    $null = $ps2.AddScript({ $injected })
    $got = $ps2.Invoke()
    # Invoke() returns a collection; a single-value script yields one element.
    $gotScalar = @($got)[0]
    Assert "an injected variable survives the trip into a worker" ($gotScalar -eq $val) `
        ("Got: '" + $gotScalar + "'")
    $ps2.Dispose()
} finally {
    if ($rs2.RunspaceStateInfo.State -eq 'Opened') { $rs2.Close() }
    $rs2.Dispose()
}
}
finally {
    Remove-Item -LiteralPath $scratch -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host ""
Write-Host ("{0} assertions, {1} failures" -f $checks, $fail)
if ($fail -gt 0) { exit 1 }
Write-Host "Runspace-closure OK" -ForegroundColor Green
exit 0