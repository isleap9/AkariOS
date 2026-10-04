<#
    Test-EngineLaunch.ps1 — proves the engine child process is REALLY launched.

    THE BUGS THIS CAUGHT (both confirmed on a VM, in sequence)

    1. GetNewClosure() across a runspace (fixed in aa288f9)
       The worker scriptblock was a closure over $enginePath. GetNewClosure()
       rebinds to the defining scope's MODULE, which does not exist in a
       [runspacefactory]:: runspace, so $enginePath arrived as "". Stage 1
       reported "engine process completed" 359 ms after launch having launched
       nothing. Covered by Test-RunspaceClosure.ps1; mentioned here because both
       bugs produced the same false-success signature.

    2. A null $EngineInvoker (fixed in 7bb20ec)
       Invoke-AkariOSStage declared [scriptblock]$EngineInvoker with NO default,
       so omitting the parameter bound $null. The null was published onto $sync,
       read by the worker, and reached "& $null $ScriptPath" - which launches
       nothing and returns nothing. $code stayed $null and the function returned
       its -1 sentinel. The VM showed:

           14:06:54.734  Runspace prelude: loaded embedded function library
           14:06:54.805  Engine child process for winsux.ps1 exited with code -1
           14:06:55.106  [ERROR] Stage 1 FAILED: Engine exited with code -1

       71 ms between those lines is the tell: far too fast for powershell.exe to
       have started. It reported an exit code for a process that never existed.

    WHY EVERY EARLIER HARNESS MISSED THIS
    Invoke-AkariOSStage's -EngineInvoker was only ever exercised with a stub
    injected. The production path - which omits the parameter - had no coverage.
    Grep assertions and stubbed invokers cannot see a missing default value.
    So this file exercises the REAL default invoker and checks a real child ran.

    WHAT IS EXECUTED
        A throwaway .ps1 that writes a marker file and exits with a chosen code
        (0 and 3). Launched by the real Start-Process powershell.exe child. No
        engine asset, no registry, no reboot, no bcdedit, no scheduled task.

    WHY THIS DOES NOT CALL Invoke-AkariOSStage
        Invoke-AkariOSStage is asynchronous: it returns $true the moment the job
        is queued, and the exit code only arrives later via a WPF DispatcherTimer
        (Invoke-RunInBackground.ps1:138-160). A DispatcherTimer needs a running
        WPF message loop, which a console test host does not have - it never
        ticks, so -OnComplete cannot fire here. That is a limitation of a console
        harness, NOT a product defect: in the real app ShowDialog() supplies the
        message loop, and the VM confirmed both the timer firing and the child
        launching.
        So this file asserts on Invoke-AkariOSEngine, which is where the launch
        decision is actually made, and separately pins the structural contract
        that Invoke-AkariOSStage publishes a non-null invoker to the worker.

    Run: powershell -NoProfile -ExecutionPolicy Bypass -STA -File ./tools/Test-EngineLaunch.ps1
#>

param([string]$Root = "C:/Users/isleap/Documents/GitHub/AkariOS/AkariOS")

$ErrorActionPreference = "Stop"
$fail = 0; $checks = 0
$scratch = Join-Path $env:TEMP ("akarios-launch-" + [guid]::NewGuid().ToString("N").Substring(0,8))

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

New-Item -ItemType Directory -Path $scratch -Force | Out-Null
try {
    . (Join-Path $Root "functions\private\State.ps1")
    . (Join-Path $Root "functions\private\Logging.ps1")
    . (Join-Path $Root "functions\private\Invoke-RunInBackground.ps1")
    . (Join-Path $Root "functions\private\Assets.ps1")
    . (Join-Path $Root "functions\public\Stage.ps1")

    # Set-Status lives in the WPF shell (scripts/start.ps1), not the function
    # library. It only pushes UI text and has no role in launching the child.
    if (-not (Get-Command Set-Status -ErrorAction SilentlyContinue)) {
        function Set-Status { param($Text, $Progress) }
    }

    # Invoke-RunInBackground reads $sync.assets and appends to $sync.runspaces, so
    # it must exist and be a synchronized hashtable exactly as in the real app.
    $sync = [Hashtable]::Synchronized(@{})
    $sync.assets    = @{}
    $sync.runspaces = [System.Collections.Generic.List[hashtable]]::new()

    # ───────────────────────────────────────────────────────────────────────
    Write-Host "A real powershell.exe child runs when no invoker is supplied"
    # ───────────────────────────────────────────────────────────────────────
    # This is the exact production shape: Invoke-AkariOSEngine called with only
    # -ScriptPath, so the DEFAULT invoker is what has to work. A stub here would
    # hide the very bug this file exists to catch.
    $marker = Join-Path $scratch "marker.txt"
    $engine = Join-Path $scratch "engine.ps1"
    $engineEsc = $marker -replace "'", "''"
    Set-Content -LiteralPath $engine -Encoding UTF8 -Value @(
        "Set-Content -LiteralPath '$engineEsc' -Value 'child-ran' -Encoding UTF8"
        "exit 0"
    )

    $code = Invoke-AkariOSEngine -ScriptPath $engine

    Assert "the child process actually executed (marker file written)" `
        (Test-Path -LiteralPath $marker) `
        "No marker means no powershell.exe ran. A null `$EngineInvoker made this return -1 in ~71 ms."

    Assert "Invoke-AkariOSEngine returned the child's real exit code, not the -1 sentinel" `
        ($code -eq 0) `
        ("Got: [$code]. -1 means `$result was null - the invoker never launched anything.")

    # ───────────────────────────────────────────────────────────────────────
    Write-Host "A non-zero engine exit is passed through, not swallowed"
    # ───────────────────────────────────────────────────────────────────────
    # A stub is correct HERE on purpose: this exercises the exit-code plumbing
    # without a second real child, and launch behaviour is already proven above.
    $engine3 = Join-Path $scratch "engine3.ps1"
    Set-Content -LiteralPath $engine3 -Encoding UTF8 -Value "exit 3"

    $code3 = Invoke-AkariOSEngine -ScriptPath $engine3 -EngineInvoker { param($p) 3 }
    Assert "exit code 3 is reported as 3, not rounded to success" ($code3 -eq 3) `
        ("Got: [$code3]")

    # ───────────────────────────────────────────────────────────────────────
    Write-Host "A missing engine script is a distinct, loud failure"
    # ───────────────────────────────────────────────────────────────────────
    $codeMissing = Invoke-AkariOSEngine -ScriptPath (Join-Path $scratch "nope.ps1")
    Assert "a missing engine returns 9009, not 0 or -1" ($codeMissing -eq 9009) `
        ("Got: [$codeMissing]")

    # ───────────────────────────────────────────────────────────────────────
    Write-Host "The null-invoker path cannot be reintroduced"
    # ───────────────────────────────────────────────────────────────────────
    $stageSrc = [regex]::Replace(
        (Get-Content -LiteralPath (Join-Path $Root "functions\public\Stage.ps1") -Raw), '(?s)<#.*?#>', '')

    # Invoke-AkariOSStage publishes whatever $EngineInvoker holds onto $sync for
    # the worker. With no default, an omitted parameter binds $null and the worker
    # executes "& $null", launching nothing. This is the bug from 7bb20ec.
    Assert "Invoke-AkariOSStage gives `$EngineInvoker a default" `
        ($stageSrc -match '(?s)\[scriptblock\]\$EngineInvoker\s*=\s*\{[\s\S]{0,500}?Start-Process') `
        "Without a default, an omitted parameter binds `$null and the worker runs nothing."

    Assert "Invoke-AkariOSEngine falls back when given no invoker" `
        ($stageSrc -match '(?s)if\s*\(\s*-not\s+\$EngineInvoker\s*\)[\s\S]{0,500}?Start-Process') `
        "It must stand alone rather than depending on every caller to supply one."

    # Comment lines must go before this check: the explanatory comments in
    # Stage.ps1 quote "& $null" verbatim while describing the very bug this
    # assertion guards, so a raw regex matches its own documentation. (That is
    # the same false-positive shape that made the earlier Test-LaunchPreflight
    # harness meaningless - it matched comments, not code.)
    $stageCode = [regex]::Replace($stageSrc, '(?m)^\s*#.*$', '')

    Assert "the worker invokes the hand-off invoker, never a literal null" `
        ($stageCode -match '(?s)-EngineInvoker\s+\$job\.EngineInvoker' -and
         $stageCode -notmatch '&\s*\$null') `
        "The worker must pass `$job.EngineInvoker through, and no code path may invoke `$null."
}
finally {
    Remove-Item -LiteralPath $scratch -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host ""
Write-Host ("{0} assertions, {1} failures" -f $checks, $fail)
if ($fail -gt 0) { exit 1 }
Write-Host "Engine-launch OK" -ForegroundColor Green
exit 0