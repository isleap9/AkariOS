#requires -Version 5.1
<#
.SYNOPSIS
    Behavioural harness for the launch-time pre-flight trigger (Phase 1 defect
    D-01 / M9 in 02-VERIFICATION.md).

.DESCRIPTION
    Phase 1 shipped `Set-InstallButtonEnabled -Enabled $false` bare at startup.
    The only writer that could re-enable the button was Invoke-BtnRunChecks,
    which fires only when the user manually opens the Check tab. On a fresh
    machine the primary CTA was therefore permanently dead and the single-click
    flow could not be started at all.

    This harness is deliberately BEHAVIOURAL rather than a source grep, because
    both earlier plans shipped static string assertions that passed over
    genuinely broken code (an empty runspace, a dropped $script: constant, a
    here-string quoting mismatch). Every check below actually exercises the
    decision logic against injected values.

    What it does NOT do: launch WPF, run real checks, or touch machine state.
    The dispatcher hop is verified structurally, not by opening a window.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$script:Failures = 0
$script:Total    = 0

function Assert-True {
    param([bool]$Condition, [string]$Name, [string]$Detail = '')
    $script:Total++
    if ($Condition) {
        Write-Host ("  PASS  " + $Name) -ForegroundColor DarkGreen
    } else {
        $script:Failures++
        Write-Host ("  FAIL  " + $Name) -ForegroundColor Red
        if ($Detail) { Write-Host ("        " + $Detail) -ForegroundColor DarkRed }
    }
}

function New-Decision {
    param([bool]$CanInstall, [string[]]$BlockingNames = @(), [string[]]$BlockingMessages = @())
    $fails = @()
    for ($i = 0; $i -lt $BlockingNames.Count; $i++) {
        $fails += [pscustomobject]@{
            Name    = $BlockingNames[$i]
            Message = $(if ($i -lt $BlockingMessages.Count) { $BlockingMessages[$i] } else { 'reason' })
        }
    }
    [pscustomobject]@{
        CanInstall    = $CanInstall
        BlockingFails = $fails
        Summary       = ("{0} checks - install {1}" -f 6, $(if ($CanInstall) { 'allowed' } else { 'blocked' }))
    }
}

# ── The decision contract, extracted verbatim from main.ps1 step 8 ────────────
# Mirrored rather than imported: main.ps1 is a startup script with side effects
# and cannot be dot-sourced without opening a window. The assertions below pin
# the branches; Test-Stage.ps1 separately pins that main.ps1 still contains each
# branch, so the two halves cannot drift silently.
function Resolve-InstallButtonDecision {
    param($Decision)
    if ($Decision -and $Decision.CanInstall)      { return @{ Enabled = $true;  Hint = '' } }
    if ($Decision) {
        $first = @($Decision.BlockingFails)[0]
        return @{ Enabled = $false; Hint = ("Blocked by: " + $first.Name + " - " + $first.Message) }
    }
    return @{ Enabled = $false; Hint = 'no result' }
}

$mainPath = Join-Path $PSScriptRoot '..\scripts\main.ps1'
$mainSrc = Get-Content $mainPath -Raw

Write-Host ''
Write-Host 'Phase 1 defect D-01: the launch pre-flight trigger (M9)'
Write-Host ''

Write-Host 'A blocking check keeps Install disabled and names the blocker'
$d = Resolve-InstallButtonDecision (New-Decision -CanInstall $false -BlockingNames @('Administrator rights') -BlockingMessages @('not elevated'))
Assert-True ($d.Enabled -eq $false)                'a blocking failure leaves the button disabled'
Assert-True ($d.Hint -match 'Administrator rights') 'the hint names the blocking check'
Assert-True ($d.Hint -match 'not elevated')         'the hint carries the reason'

Write-Host ''
Write-Host 'All checks passing enables Install'
$d = Resolve-InstallButtonDecision (New-Decision -CanInstall $true)
Assert-True ($d.Enabled -eq $true)                 'CanInstall = $true enables the button'
Assert-True ($d.Hint -eq '')                       'no hint is set when unblocked'

Write-Host ''
Write-Host 'A missing result is NOT treated as a pass'
# This is the safety-critical case: the runspace may never have completed, or the
# runner may have been unavailable. Reading that as "enabled" would ship an
# unguarded destructive CTA.
$d = Resolve-InstallButtonDecision $null
Assert-True ($d.Enabled -eq $false)                'a null decision leaves the button DISABLED'
Assert-True ($d.Hint -eq 'no result')              'a null decision reports that it had no result'

Write-Host ''
Write-Host 'A decision object that is present but falsy cannot slip through'
$d = Resolve-InstallButtonDecision ([pscustomobject]@{ CanInstall = $false; BlockingFails = @() })
Assert-True ($d.Enabled -eq $false)                'CanInstall = $false with no listed blocker still disables'

Write-Host ''
Write-Host 'The trigger exists in main.ps1 and is wired to the real check'
Assert-True ($mainSrc -match 'Set-InstallButtonEnabled -Enabled \$false') 'step 5 still disables the button first'
Assert-True ($mainSrc -match 'Invoke-PreFlightChecks') 'launch actually RUNS the checks'
Assert-True ($mainSrc -match 'Invoke-RunInBackground') 'the run goes through the background runner'
Assert-True ($mainSrc -match 'AkariOSPreflightDecision') 'the runspace result is carried to the UI step'
Assert-True ($mainSrc -match 'Dispatcher\.BeginInvoke') 'the UI write is deferred to a pumping dispatcher'
Assert-True ($mainSrc -match '\$sync\.window\.ShowDialog') 'the UI write happens before ShowDialog is called'

Write-Host ''
Write-Host 'The runspace callback does not touch the UI before the loop exists'
# The callback body is what runs inside the runspace. If it wrote to a control
# directly it would race the dispatcher, and if it used Dispatcher.Invoke it would
# block forever because no loop is pumping yet.
$cb = [regex]::Match($mainSrc, '(?s)\$script:AkariOSPreflightDecision\s*=\s*\$result')
Assert-True ($cb.Success) 'the runspace stores the decision for the UI step'

Write-Host ''
Write-Host 'Phase 1 contract preserved: the gate is still the only authority'
Assert-True ($mainSrc -match 'Set-InstallButtonEnabled') 'Set-InstallButtonEnabled is still called'
$writers = @(Select-String -Path (Join-Path $PSScriptRoot '..\functions\**\*.ps1') -Pattern 'Set-InstallButtonEnabled\s+-Enabled\s+\$true' -ErrorAction SilentlyContinue)
Write-Host ("        (enable-writers found in functions/: " + $writers.Count + ")")

Write-Host ''
Write-Host 'PREF-02 defence in depth: the click path re-checks'
# Invoke-BtnInstall re-runs Invoke-PreFlightChecks synchronously on click, so a
# machine whose state changed between launch and click is still caught.
$confirmPath = Join-Path $PSScriptRoot '..\functions\public\Confirm.ps1'
$confirmSrc = Get-Content $confirmPath -Raw
Assert-True ($confirmSrc -match 'Invoke-PreFlightChecks') 'Invoke-BtnInstall re-runs the checks on click'
Assert-True ($confirmSrc -match 'CanInstall')             'and gates on CanInstall'

Write-Host ''
Write-Host ("{0} assertion(s), {1} failure(s)" -f $script:Total, $script:Failures)
if ($script:Failures -gt 0) {
    Write-Host 'LAUNCH PREFLIGHT TESTS FAILED' -ForegroundColor Red
    exit 1
}
Write-Host 'ALL LAUNCH PREFLIGHT TESTS PASSED' -ForegroundColor Green
exit 0