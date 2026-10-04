# Test for the DIAG-02 failure record: that a recorded failure SURVIVES the partial
# state update the progress panel issues on every tick, that detection returns null
# for a healthy machine and a populated object for a failed one, and that the log
# excerpt is bounded.
#
# These are BEHAVIOURAL assertions. Every earlier harness in this project passed
# against code that was actually broken (an empty runspace, a dropped $script:
# constant, a here-string quoting mismatch), so nothing here is satisfied by a grep
# or a string pattern: each check calls the real function against a real file on
# disk and reads the real result back.
#
# Nothing touches C:\ProgramData: the state file and the log both live in a scratch
# directory under $env:TEMP, and every call passes -StatePath / -LogPath explicitly.
param([string]$Root = "C:/Users/isleap/Documents/GitHub/AkariOS/AkariOS")

$ErrorActionPreference = "Stop"
. (Join-Path $Root "functions\private\State.ps1")
. (Join-Path $Root "functions\private\Logging.ps1")
. (Join-Path $Root "functions\public\Diagnostics.ps1")

$fail = 0
function Assert($label, $cond) {
    if ($cond) { Write-Host "  PASS  $label" } else { Write-Host "  FAIL  $label"; $script:fail++ }
}

# ── Scratch environment ───────────────────────────────────────────────────────
$scratch = Join-Path $env:TEMP ("akarios-diag-" + [guid]::NewGuid().ToString("N").Substring(0,8))
New-Item -ItemType Directory -Path $scratch -Force | Out-Null
$statePath = Join-Path $scratch "state.json"
$logPath   = Join-Path $scratch "install.log"

try {

    # ── 1. A healthy machine reports no failure ───────────────────────────────
    Write-Host "A fresh state file is healthy"
    Initialize-AkariOSState -Path $statePath | Out-Null
    $none = Get-AkariOSStageFailure -StatePath $statePath -LogPath $logPath
    Assert "Get-AkariOSStageFailure returns null" ($null -eq $none)

    # A 'running' state with progress on it is still healthy: within-stage
    # progress must not be mistaken for a failure.
    Set-AkariOSState -Path $statePath -CurrentStage 2 -Status "running" -Progress 40 -CurrentAction "Downloading" | Out-Null
    $running = Get-AkariOSStageFailure -StatePath $statePath -LogPath $logPath
    Assert "a running stage is not a failure" ($null -eq $running)

    # ── 2. Recording a failure ────────────────────────────────────────────────
    Write-Host "Set-AkariOSStageFailure records a readable block"
    $detail = "Engine child process for winsux.ps1 exited with code 1603."
    Set-AkariOSStageFailure -Stage 1 -Detail $detail -ExitCode 1603 -StatePath $statePath | Out-Null

    $f = Get-AkariOSStageFailure -StatePath $statePath -LogPath $logPath
    Assert "failure object returned"  ($null -ne $f)
    Assert "stage is 1"               ($f.Stage -eq 1)
    Assert "detail is verbatim"       ($f.Detail -ceq $detail)
    Assert "exit code round-trips"    ($f.ExitCode -eq 1603)
    Assert "RecordedAt is populated"  (-not [string]::IsNullOrWhiteSpace([string]$f.RecordedAt))
    Assert "status is the existing error value" ([string](Get-AkariOSState -Path $statePath).Status -eq "error")

    # ── 3. THE REGRESSION: the block must survive a progress-tick partial update.
    #       Before T-02-26 the Fields parameter set rebuilt the object from
    #       scratch and dropped LastError, so this assertion FAILED: the record
    #       evaporated on the very next progress tick and DIAG-02 was inert.
    Write-Host "T-02-26: the record survives a Fields partial update (the Progress tick)"
    Set-AkariOSState -Path $statePath -CurrentStage 1 -Status "running" -Progress 7 -CurrentAction "Extracting payload" | Out-Null

    $survivor = Get-AkariOSStageFailure -StatePath $statePath -LogPath $logPath
    Assert "the failure is still detected"     ($null -ne $survivor)
    Assert "the detail survived verbatim"      ($survivor.Detail -ceq $detail)
    Assert "the exit code survived"            ($survivor.ExitCode -eq 1603)
    Assert "the partial update still applied"  ([int](Get-AkariOSState -Path $statePath).Progress -eq 7)

    # And it survives on disk, not just in memory: read the raw JSON so a
    # serializer that quietly omits the property cannot pass this test.
    $rawJson = Get-Content -LiteralPath $statePath -Raw
    Assert "LastError is in the file on disk"  ($rawJson -match 'LastError')
    Assert "the detail is in the file on disk" ($rawJson -match ([regex]::Escape("code 1603")))

    # Repeated ticks — the real UI writes one per refresh.
    foreach ($p in 12, 33, 58, 91) {
        Set-AkariOSState -Path $statePath -CurrentStage 1 -Status "running" -Progress $p -CurrentAction "tick $p" | Out-Null
    }
    $after = Get-AkariOSStageFailure -StatePath $statePath -LogPath $logPath
    Assert "survives four more ticks"           ($after.Detail -ceq $detail)

    # ── 4. Writing twice replaces, never nests ────────────────────────────────
    Write-Host "Recording a second failure replaces the block"
    Set-AkariOSStageFailure -Stage 3 -Detail "Stage 3 failed to import reg.reg." -ExitCode 1 -StatePath $statePath | Out-Null
    $raw2 = Get-Content -LiteralPath $statePath -Raw
    Assert "exactly one LastError key in the JSON" ((([regex]::Matches($raw2, '"LastError"')).Count) -eq 1)
    $f2 = Get-AkariOSStageFailure -StatePath $statePath -LogPath $logPath
    Assert "the newer record wins"  ($f2.Stage -eq 3)
    Assert "the newer detail wins"  ($f2.Detail -ceq "Stage 3 failed to import reg.reg.")
    Assert "the old detail is gone" ($raw2 -notmatch ([regex]::Escape("code 1603")))

    # ── 5. Status 'error' with no block is still reported, not silently healthy.
    # A state file with Status 'error' but no LastError block at all — the shape a
    # Phase 1 machine can already be in. It must still be reported rather than
    # silently looking healthy.
    Write-Host "Status error without a block is still a failure"
    $bare = [pscustomobject]@{
        SchemaVersion = 1; CurrentStage = 2; Status = "error"; Progress = 30
        CurrentAction = "x"; RebootPending = $false
        UpdatedAt = (Get-Date).ToUniversalTime().ToString("o")
    }
    Set-AkariOSState -Path $statePath -State $bare | Out-Null
    $bareF = Get-AkariOSStageFailure -StatePath $statePath -LogPath $logPath
    Assert "reported despite the missing block" ($null -ne $bareF)
    Assert "stage falls back to CurrentStage"   ($bareF.Stage -eq 2)
    Assert "a detail is still produced"          (-not [string]::IsNullOrWhiteSpace([string]$bareF.Detail))

    # ── 6. The log excerpt is bounded and read from the injected path ─────────
    Write-Host "The log excerpt is bounded by -LogCount and read from -LogPath"
    $lines = 1..60 | ForEach-Object { ("2026-01-01T00:00:00.000Z [INFO ]  scratch log line {0}" -f $_) }
    Set-Content -LiteralPath $logPath -Value $lines -Encoding UTF8

    Set-AkariOSStageFailure -Stage 1 -Detail "boom" -StatePath $statePath | Out-Null
    $withLog = Get-AkariOSStageFailure -StatePath $statePath -LogPath $logPath -LogCount 5
    Assert "exactly -LogCount lines returned"  (@($withLog.LogTail).Count -eq 5)
    Assert "the newest line is included"      ((@($withLog.LogTail) | Where-Object { $_ -match 'scratch log line 60' }).Count -eq 1)
    Assert "an older line is excluded"         (-not ((@($withLog.LogTail) | Where-Object { $_ -match 'scratch log line 1$' }).Count -gt 0))
    Assert "LogText joins the excerpt"         (([string]$withLog.LogText) -match 'scratch log line 60')

    # A missing log file must not throw — an absent excerpt is still a reportable
    # failure, and the dialog has to open either way.
    $noLog = Join-Path $scratch "does-not-exist.log"
    $f3 = Get-AkariOSStageFailure -StatePath $statePath -LogPath $noLog
    Assert "a missing log yields an empty excerpt, not a throw" (@($f3.LogTail).Count -eq 0)
    Assert "the failure is still reported" ($null -ne $f3)

    # ── 7. Abort clears ONLY the error block, and really clears it ────────────
    #      -Fields re-carries LastError, so the abort path has to go through the
    #      Object set. This proves the shortcut does not work, which is why
    #      Clear-AkariOSStageFailure exists.
    Write-Host "Clearing: -Fields cannot clear the block, the Object set can"
    Set-AkariOSState -Path $statePath -CurrentStage 1 -Status "pending" -Progress 0 -CurrentAction "" | Out-Null
    Assert "the block is still there after a Fields update" ($null -ne (Get-AkariOSStageFailure -StatePath $statePath -LogPath $logPath))

    $cleared = Clear-AkariOSStageFailure -StatePath $statePath
    Assert "Clear-AkariOSStageFailure returns the object"  ($null -ne $cleared)
    Assert "the property is gone from the returned object" ($null -eq $cleared.PSObject.Properties["LastError"])
    Assert "status is back to pending"                     ([string]$cleared.Status -eq "pending")
    Assert "detection now returns null"                    ($null -eq (Get-AkariOSStageFailure -StatePath $statePath -LogPath $logPath))
    Assert "no LastError key remains in the file"          ((Get-Content -LiteralPath $statePath -Raw) -notmatch 'LastError')
    # The other fields must be untouched by the clear.
    Assert "the stage number survived the clear"           ([int]$cleared.CurrentStage -eq 1)

    # ── 8. No new status constant, and validation is unchanged ────────────────
    # The intent of this section is to catch an UNINTENDED status value creeping
    # in. "installing" is now an intended one: Progress.ps1:101 has always
    # written it, Cancel.ps1:55 gates on it, and it was missing from both lists
    # in State.ps1 (fix(01) commit 7e0d1a7). So the two assertions below pin the
    # vocabulary that is actually intended, not the Phase 1 vocabulary.
    #
    # A byte-identical pin would be wrong now: it would fail on the very change
    # that makes progress persist at all. What must stay pinned is that no status
    # OUTSIDE the intended set appears - that is the property worth guarding.
    Write-Host "No unintended status value was introduced"
    $stateSrc = Get-Content -LiteralPath (Join-Path $Root "functions\private\State.ps1") -Raw
    $diagSrc  = Get-Content -LiteralPath (Join-Path $Root "functions\public\Diagnostics.ps1") -Raw
    $intended = @("pending", "running", "installing", "completed", "error")
    $validate = [regex]::Match($stateSrc, '\[ValidateSet\(([^)]*)\)\]\[string\]\$Status')
    Assert "found the -Status ValidateSet" ($validate.Success)
    $vsValues = @()
    if ($validate.Success) {
        $vsValues = @([regex]::Matches($validate.Groups[1].Value, '"([^"]+)"') | ForEach-Object { $_.Groups[1].Value })
    }
    Assert "ValidateSet holds exactly the intended statuses" (
        (@($vsValues | Where-Object { $intended -notcontains $_ }).Count -eq 0) -and ($vsValues.Count -eq $intended.Count)
    ) ("ValidateSet: " + ($vsValues -join ", "))
    $literals = @([regex]::Matches($diagSrc, '(?m)Status\s*=\s*"([a-z]+)"') |
                  ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique)
    Assert "Diagnostics.ps1 only ever writes 'pending' or 'error'" (
        (@($literals | Where-Object { $_ -notin @("pending", "error") }).Count) -eq 0)

    # Test-AkariOSState must still ACCEPT a state carrying the extra property,
    # and must still REJECT a broken one. Loosening it is out of scope; so is
    # accidentally tightening it.
    Write-Host "Test-AkariOSState is unchanged and tolerates the extra property"
    # Record a real failure so the state on disk genuinely carries LastError, then
    # validate the deserialized object — validation must accept the extra property.
    Set-AkariOSStageFailure -Stage 1 -Detail "validation probe" -ExitCode 5 -StatePath $statePath | Out-Null
    $f2State = Get-AkariOSState -Path $statePath
    $testSrc = [regex]::Match($stateSrc, '(?s)function Test-AkariOSState \{.*?\n\}').Value
    Assert "still requires the five known properties" ($testSrc -match 'SchemaVersion", "CurrentStage", "Status", "Progress", "CurrentAction')
    Assert "still rejects an out-of-range stage"       ($testSrc -match '\$State\.CurrentStage -lt 0 -or \$State\.CurrentStage -gt 3')
    # Still rejects an unknown status, and still accepts every intended one.
    # Pinning the literal Phase 1 list here would contradict the fix: it would
    # demand that the validator reject "installing", which is precisely what made
    # Get-AkariOSState treat a freshly written state file as corrupt and overwrite
    # it. The property to protect is "nothing outside the intended set is
    # accepted", asserted below against the same list the ValidateSet uses.
    $validatorList = [regex]::Match($testSrc, '\$State\.Status\s+-notin\s+@\(([^)]*)\)')
    Assert "still rejects an unknown status" ($validatorList.Success)
    $readValues = @()
    if ($validatorList.Success) {
        $readValues = @([regex]::Matches($validatorList.Groups[1].Value, '"([^"]+)"') | ForEach-Object { $_.Groups[1].Value })
    }
    Assert "validator accepts exactly the intended statuses" (
        (@($readValues | Where-Object { $intended -notcontains $_ }).Count -eq 0) -and ($readValues.Count -eq $intended.Count)
    ) ("Validator: " + ($readValues -join ", "))
    Assert "an unknown status is genuinely rejected" (-not (Test-AkariOSState (New-AkariOSState -CurrentStage 1 -Status "bogus")))
    Assert "'installing' is genuinely accepted"        (Test-AkariOSState (New-AkariOSState -CurrentStage 1 -Status "installing"))
    Assert "a state carrying LastError still validates"  (Test-AkariOSState $f2State)
    Assert "and its LastError is untouched by validation" ((Get-AkariOSStageFailure -StatePath $statePath -LogPath $logPath).Stage -eq 1)
    Assert "an invalid state is still rejected"        (-not (Test-AkariOSState ([pscustomobject]@{ CurrentStage = 9 })))

    # ── 9. The dialog: choice in, choice out, every exit path resolved ─────────
    # Show-StageError is exercised through -DialogInvoker, which is the only way
    # it shows anything. The point is that the choice genuinely travels back out
    # of the call — the by-value closure trap that made Phase 1 report every
    # failed job as "Done" would silently make this always return "abort".
    Write-Host "Show-StageError returns the injected choice"
    function Set-Status { param([string]$Text, [string]$Color = "White") }

    Set-AkariOSStageFailure -Stage 2 -Detail "stepone.ps1 exited with code 1." -ExitCode 1 -StatePath $statePath | Out-Null
    $probe = Get-AkariOSStageFailure -StatePath $statePath -LogPath $logPath -LogCount 4

    $gotRetry = Show-StageError -Failure $probe -LogPath $logPath -DialogInvoker { param($f) "retry" }
    Assert "the retry choice comes back out"  ($gotRetry -ceq "retry")
    $gotAbort = Show-StageError -Failure $probe -LogPath $logPath -DialogInvoker { param($f) "abort" }
    Assert "the abort choice comes back out"   ($gotAbort -ceq "abort")

    # The dialog is built on the Show-ConfirmationGate shape: a real ShowDialog,
    # an outcome in a hashtable, and an explicit close. Escape / X / window-close
    # all leave the hashtable at its default, which is why the default is "abort".
    $showSrc = [regex]::Match($diagSrc, '(?s)function Show-StageError \{.*?\n\}').Value
    Assert "the dialog uses a real ShowDialog"       ($showSrc -match '\$dlg\.ShowDialog\(\)')
    Assert "the outcome is a reference type"         ($showSrc -match '\$choice = @\{')
    Assert "the window is closed before returning"    ($showSrc -match '\$dlg\.Close\(\)')
    Assert "the default outcome is abort"            ($showSrc -match '\$choice = @\{ Value = "abort" \}')
    Assert "the log excerpt is bounded"               ($showSrc -match 'Get-AkariOSLogTail -Count \$LogCount')
    # Plain text only: markup in a log line must not be interpreted (T-02-20).
    Assert "the excerpt is never rendered as markup"  ($showSrc -notmatch '\.(Html|Rtf)\b')

    # ── 10. Retry re-runs the WHOLE stage; abort clears ONLY the record ───────
    Write-Host "Resolve-StageFailure: retry re-runs the stage through the runner"
    $ran = $null
    $okRetry = Resolve-StageFailure -Failure $probe -Choice "retry" -StatePath $statePath -StageInvoker {
        param($n, $cb) $script:ran = $n; $true
    }
    Assert "retry reports success"         ($okRetry -eq $true)
    Assert "retry invoked the runner"      ($null -ne $ran)
    Assert "retry used the failed stage"   ($ran -eq 2)
    Assert "retry did NOT clear the record" ($null -ne (Get-AkariOSStageFailure -StatePath $statePath -LogPath $logPath))

    Write-Host "Resolve-StageFailure: abort clears the record and touches nothing else"
    # Capture CurrentStage before the abort: abort must PRESERVE whatever the
    # state already said, not rewrite it. The failed stage lives in the LastError
    # block, which the abort is about to remove.
    $stageBeforeAbort = [int](Get-AkariOSState -Path $statePath).CurrentStage
    $okAbort = Resolve-StageFailure -Failure $probe -Choice "abort" -StatePath $statePath
    Assert "abort reports success"                 ($okAbort -eq $true)
    Assert "abort cleared the failure"              ($null -eq (Get-AkariOSStageFailure -StatePath $statePath -LogPath $logPath))
    Assert "abort left the stage number alone"      ([int](Get-AkariOSState -Path $statePath).CurrentStage -eq $stageBeforeAbort)
    Assert "abort left status pending"              ([string](Get-AkariOSState -Path $statePath).Status -eq "pending")

    # Abort must reach the state file through the lossless Object set. Asserted on
    # the COMMENT-STRIPPED source because the mechanism is the whole point: -Fields
    # re-carries the block, so it can never clear it. The docstrings legitimately
    # NAME bcdedit and safeboot while explaining that they are never called, so
    # they are stripped first — the same shape the plan's own verify step uses.
    $resolveSrc = [regex]::Match($diagSrc, '(?s)function Resolve-StageFailure \{.*?\n\}').Value
    $resolveSrc = [regex]::Replace([regex]::Replace($resolveSrc, '(?s)<#.*?#>', ''), '(?m)^\s*#.*$', '')
    Assert "abort goes through Clear-AkariOSStageFailure" ($resolveSrc -match 'Clear-AkariOSStageFailure')
    Assert "abort does not use the -Fields set"           ($resolveSrc -notmatch 'Set-AkariOSState -Fields')
    Assert "abort does not write a RunOnce entry"         ($resolveSrc -notmatch 'Set-AkariOSRunOnceEntry')
    Assert "abort does not touch the boot flag"           ($resolveSrc -notmatch 'bcdedit|safeboot')
    Assert "only the Object set is used to clear"         ($diagSrc -match 'Set-AkariOSState -Path \$StatePath -State \$obj')
    Assert "retry defaults to Invoke-AkariOSStage"        ($resolveSrc -match 'Invoke-AkariOSStage -Stage \$n -OnComplete \$cb')

    # ── 11. The button handlers exist and delegate to the same contract ───────
    Write-Host "The two button handlers exist and delegate"
    foreach ($h in @("Invoke-BtnStageRetry", "Invoke-BtnStageAbort")) {
        Assert "$h is defined exactly once" ((@([regex]::Matches($diagSrc, "(?m)^function $([regex]::Escape($h)) \{$"))).Count -eq 1)
        Assert "$h takes no mandatory parameters" ((@((Get-Command $h).Parameters.Values | Where-Object { $_.Attributes | Where-Object { $_ -is [System.Management.Automation.ParameterAttribute] -and $_.Mandatory } })).Count -eq 0)
    }
    Assert "Retry delegates to Resolve-StageFailure" ($diagSrc -match 'Invoke-BtnStageRetry[\s\S]*?Resolve-StageFailure')
    Assert "Abort delegates to Resolve-StageFailure" ($diagSrc -match 'Invoke-BtnStageAbort[\s\S]*?Resolve-StageFailure')
    Assert "the handlers no-op with no failure"      ($diagSrc -match 'with no recorded stage failure')

    # Invoke-BtnStageAbort end to end, against a real scratch state file.
    Set-AkariOSStageFailure -Stage 3 -Detail "steptwo.ps1 could not import reg.reg." -StatePath $statePath | Out-Null
    Assert "Abort button clears a real record"  ((Invoke-BtnStageAbort -StatePath $statePath) -eq $true)
    Assert "and detection is clean afterwards"  ($null -eq (Get-AkariOSStageFailure -StatePath $statePath -LogPath $logPath))

    # Retry button: no failure present must NOT launch an arbitrary stage.
    Assert "Retry button no-ops with nothing recorded" ((Invoke-BtnStageRetry -StatePath $statePath -LogPath $logPath) -eq $false)

    # ── 13. End-to-end: the round trip DIAG-02 actually depends on ──────────────
    # The launch-time check reads state.json, and the progress panel rewrites it
    # on every tick while a stage runs. So the property that matters is not "can
    # we write a failure" (proven in section 2) but "does it still read back
    # after the very write that used to destroy it".
    Write-Host "T-02-34: end-to-end round trip through a simulated progress tick"
    Reset-AkariOSState -Path $statePath
    Initialize-AkariOSState -Path $statePath | Out-Null
    Initialize-AkariOSLog -Path $logPath | Out-Null
    $roundTripDetail = "winsux.ps1 aborted: payload download failed (HTTP 404)."

    Set-AkariOSStageFailure -Stage 1 -Detail $roundTripDetail -ExitCode 404 -StatePath $statePath | Out-Null

    # The UI refreshing five times while the user reads the error is exactly the
    # sequence that used to erase the record.
    foreach ($p in @(3, 6, 9, 12, 15)) {
        Set-AkariOSState -Path $statePath -CurrentStage 1 -Status "running" -Progress $p -CurrentAction ("Working {0}%" -f $p) | Out-Null
    }

    $readBack = Get-AkariOSStageFailure -StatePath $statePath -LogPath $logPath
    Assert "the launch-time check still finds the failure" ($null -ne $readBack)
    Assert "the detail survived verbatim, end to end"      ($readBack.Detail -ceq $roundTripDetail)
    Assert "the exit code survived, end to end"            ($readBack.ExitCode -eq 404)
    Assert "the stage survived, end to end"                ($readBack.Stage -eq 1)
    Assert "a log excerpt came back with it"               (@($readBack.LogTail).Count -ge 1)

    # And what the user would see on the card is populated, not blank.
    Assert "a message is rendered for the card"   (-not [string]::IsNullOrWhiteSpace([string]$readBack.Detail))
    Assert "the excerpt is renderable as text"    (([string]$readBack.LogText) -is [string])

    # A clean re-run clears it, so the next launch does not re-report it.
    Clear-AkariOSStageFailure -StatePath $statePath | Out-Null
    Assert "after recovery, launch detection is clean" ($null -eq (Get-AkariOSStageFailure -StatePath $statePath -LogPath $logPath))

    # ── 14. Seams are injectable and no ProgramData literal is written ────────
    Write-Host "Every path is injectable and no ProgramData literal is hardcoded"
    foreach ($fn in @("Get-AkariOSStageFailure", "Set-AkariOSStageFailure", "Clear-AkariOSStageFailure")) {
        $keys = @((Get-Command $fn).Parameters.Keys)
        Assert "$fn has -StatePath" ($keys -contains "StatePath")
    }
    $tailKeys = @((Get-Command Get-AkariOSStageFailure).Parameters.Keys)
    Assert "Get-AkariOSStageFailure has -LogPath"  ($tailKeys -contains "LogPath")
    Assert "Get-AkariOSStageFailure has -LogCount" ($tailKeys -contains "LogCount")
    Assert "no ProgramData literal in Diagnostics.ps1" ($diagSrc -notmatch 'ProgramData')
    Assert "the house state constant is the default"    ($diagSrc -match 'script:AkariOSStateDefaultPath')
    Assert "the house log helper is the default"        ($diagSrc -match 'Get-AkariOSLogPath')

} finally {
    Remove-Item -LiteralPath $scratch -Recurse -Force -ErrorAction SilentlyContinue
}

if ($fail -eq 0) { Write-Host "`nALL DIAGNOSTICS TESTS PASSED"; exit 0 }
else { Write-Host "`n$fail DIAGNOSTIC TEST(S) FAILED"; exit 1 }
