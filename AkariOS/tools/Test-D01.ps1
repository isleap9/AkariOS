<#
    Test-D01.ps1 — regression test for Phase 1 defect D-01 / verifier item M9.

    THE BUG
        main.ps1 disabled the Install button at launch (PREF-02) but nothing ever
        ran the pre-flight checks to enable it again. The ONLY re-enable path was
        Invoke-BtnRunChecks on the Check tab. So on a clean machine the primary
        CTA was dead on open, which breaks the single-click core value and blocks
        Phase 2 success criterion 1 (FLOW-01).

    THE FIX
        Run the checks inline during launch and enable from the result, exactly
        as Invoke-BtnRunChecks does with the same return value.

    WHY THE ORIGINAL ATTEMPT CRASHED THE APP
        Commit 6086c0d routed the launch-time call through Invoke-RunInBackground
        because the checks are "slow". That was wrong on two counts, and this file
        asserts BOTH are now avoided rather than trusting a comment:

        1. Invoke-RunInBackground calls Set-Status at dispatch time
           (Invoke-RunInBackground.ps1:43) and Set-Status does a blocking
           Dispatcher.Invoke (main.ps1:24). The launch path must therefore never
           go through that runner.
        2. Invoke-PreFlightChecks needs no dispatcher at all. If it ever grows a
           $sync or Dispatcher reference, calling it before ShowDialog() stops
           being safe and this test goes red. This is the load-bearing
           assertion — it is what makes the synchronous fix safe by construction
           instead of safe by my say-so.

    Run:  powershell -NoProfile -ExecutionPolicy Bypass -File ./tools/Test-D01.ps1
#>

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$failures = 0
$checks = 0

function Assert {
    param([string]$Label, [bool]$Condition, [string]$Detail = "")
    $script:checks++
    if ($Condition) {
        Write-Host ("  PASS  {0}" -f $Label)
    } else {
        $script:failures++
        if ($Detail) { Write-Host ("        {0}" -f $Detail) -ForegroundColor DarkGray }
        Write-Host ("  FAIL  {0}" -f $Label) -ForegroundColor Red
    }
}

function Get-Source { param([string]$Rel) return (Get-Content -LiteralPath (Join-Path $root $Rel) -Raw) }

# Comments are prose that legitimately NAMES the very symbols these assertions
# search for — explaining why a construct is avoided requires writing its name.
# So the structural assertions below run against executable code with all
# comments stripped, otherwise a well-documented fix reads as a broken one.
# This is exactly the false positive that made an earlier draft of this file
# report 4 failures against correct source.
function Remove-Comments {
    param([string]$Text)
    $t = [regex]::Replace($Text, '(?s)<#.*?#>', '')          # block help
    $t = [regex]::Replace($t, '(?m)^\s*#.*$', '')            # whole-line comments
    $t = [regex]::Replace($t, '(?m)(?<!["''])#(?!$).*$', '')  # trailing comments only
    return $t
}

# ─────────────────────────────────────────────────────────────────────────────
Write-Host "D-01: Install button must enable itself at launch"
# ─────────────────────────────────────────────────────────────────────────────

$mainRaw  = Get-Source "scripts/main.ps1"
$main     = Remove-Comments $mainRaw

# ── 1. The actual regression: the launch path must run the checks ───────────
# Not a grep for "Invoke-PreFlightChecks" anywhere — that would match a comment
# or a dead branch. The call has to be executed top-level code, before the
# ShowDialog() call that starts the message loop.

$showDialogAt = $main.IndexOf("ShowDialog()")
Assert "ShowDialog still present (test anchor)" ($showDialogAt -gt 0) `
    "If this is 0 the launch path was restructured and the anchors below need rechecking."

$launchBlock = $main.Substring(0, [Math]::Max($showDialogAt, 0))
$checkAt     = $launchBlock.IndexOf("Invoke-PreFlightChecks")

Assert "launch path calls Invoke-PreFlightChecks before ShowDialog" ($checkAt -gt 0) `
    "Nothing runs the checks at launch, so the Install button can never enable itself."

# ── 2. The button must be enabled FROM the result ───────────────────────────
# Enabling unconditionally would satisfy PREF-02's letter while destroying its
# intent — the whole point of the gate is that a failing check blocks Install.
Assert "enable is gated on CanInstall, not unconditional" `
    ($main -match '\$launchDecision\.CanInstall') `
    "Install must not be enabled without consulting the pre-flight result."

Assert "a blocked pre-flight explains what blocked it" `
    ($main -match 'BlockingFails') `
    "A disabled button with no reason is the exact dead-end D-01 describes."

# ── 3. Both crash mechanisms from 6086c0d must stay gone ────────────────────

Assert "launch path does NOT use Invoke-RunInBackground" `
    ($launchBlock -notmatch 'Invoke-RunInBackground') `
    "That runner calls Set-Status, which does a blocking Dispatcher.Invoke before ShowDialog."

$runner = Get-Source "functions/private/Invoke-RunInBackground.ps1"
Assert "runner still calls Set-Status (documents why launch must avoid it)" `
    ($runner -match 'Set-Status \$StatusStart') `
    "If this ever changes, the reason for avoiding the runner at launch must be revisited."

Assert "Set-Status still uses a blocking Dispatcher.Invoke" `
    ($main -match '(?s)function Set-Status.{0,400}?Dispatcher\.Invoke') `
    "If this becomes BeginInvoke the deadlock analysis changes; re-verify before touching main.ps1."

Assert "no thread-pool workaround left behind" `
    ($main -notmatch 'QueueUserWorkItem|WaitCallback|AkariOSPreflightDecision')

# ── 4. THE LOAD-BEARING ASSERTION ───────────────────────────────────────────
# Invoke-PreFlightChecks must stay UI-free. Calling it before ShowDialog() is
# only safe because it touches no dispatcher and no $sync. If a future change
# adds either, this goes red BEFORE that change ships, instead of the app
# crashing on the user's machine.

$checkSrc = Get-Source "functions/public/Check.ps1"
$fnStart  = $checkSrc.IndexOf("function Invoke-PreFlightChecks")
Assert "found Invoke-PreFlightChecks to inspect" ($fnStart -gt 0)

if ($fnStart -gt 0) {
    # Slice to the next top-level function definition, then strip comments using
    # the same helper, so prose about $sync cannot fail the test.
    $rest    = $checkSrc.Substring($fnStart)
    $nextFn  = [regex]::Match($rest.Substring(1), '(?m)^function\s+\w')
    $fnBody  = if ($nextFn.Success) { $rest.Substring(0, $nextFn.Index + 1) } else { $rest }
    $fnBody  = Remove-Comments $fnBody

    Assert "Invoke-PreFlightChecks references no Dispatcher" ($fnBody -notmatch 'Dispatcher') `
        "A Dispatcher call before ShowDialog() can block the UI thread indefinitely."
    Assert "Invoke-PreFlightChecks references no UI control via $sync" `
        ($fnBody -notmatch '\$sync\.') `
        "Writing UI from here is safe only after ShowDialog(); keep this function pure."
    Assert "Invoke-PreFlightChecks references no Set-Status" ($fnBody -notmatch 'Set-Status') `
        "Set-Status blocks on a Dispatcher.Invoke that cannot be serviced pre-ShowDialog."
}

# ── 5. Failure containment ──────────────────────────────────────────────────
# A throwing check must not take the window down with it. Invoke-PreFlightChecks
# downgrades a throwing check to Warning internally, but the launch call itself
# still needs a guard: anything else that throws between here and ShowDialog()
# leaves the user with no window and no explanation.
Assert "launch pre-flight is wrapped in try/catch" `
    ($main -match '(?s)Invoke-PreFlightChecks.{0,200}?\}.*catch') `
    "An unguarded throw here means no window opens at all."

Assert "catch logs rather than swallowing silently" `
    ($main -match '(?s)Invoke-PreFlightChecks.{0,900}?catch\s*\{[^}]*Write-AkariOSLog')

# ── 6. PREF-02 must still hold on the manual path ───────────────────────────
# The Check tab's own handler is unchanged Phase 1 behaviour; confirm the fix
# was additive and did not remove the user-facing re-run path.
Assert "Check tab still offers a manual re-run" `
    ((Get-Source "functions/public/Check.ps1") -match 'function Invoke-BtnRunChecks')

Assert "Stage 1 resume path can still enable Install" `
    ((Get-Source "functions/public/Resume.ps1") -match 'Set-InstallButtonEnabled -Enabled \$true')

# ── Report ──────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host ("{0} assertions, {1} failures" -f $checks, $failures)
if ($failures -gt 0) { exit 1 }
Write-Host "D-01 OK" -ForegroundColor Green
exit 0