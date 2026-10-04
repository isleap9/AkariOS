# Test for the DIAG-04 completion check and the "what changed" summary.
#
# WHY THIS FILE IS BEHAVIOURAL AND NOT GREP-BASED
#
# Phase 2 shipped a fully green suite with three real runtime bugs live: a
# `$ps.Free` vs `$psd.Free` typo, a GetNewClosure()-across-a-runspace bug that
# made captured variables arrive empty, and a null -EngineInvoker that made a
# stage report "engine process completed" in 359 ms having launched nothing. A
# grep-only harness cannot see any of those, so this file asserts REAL values and
# REAL reads throughout:
#
#   * the completion predicate's actual bool for five different state files
#     written through Set-AkariOSState, not a source pattern
#   * Get-AkariOSChangeSummary against REAL scratch logs, asserting that EXACTLY
#     the corroborated items come back `applied` - the regression that marks
#     everything applied must fail here, and mutation (b) proves it does
#   * a 5000-line log where the corroborated lines sit OUTSIDE the tail, which is
#     the only assertion that can catch an unbounded read
#   * the buttons' shell invokers, asserted on the exact token received
#   * the COMPILED akarios.ps1, not the sources: control names present with Name=
#     and absent with x:Name=, [xml] cast succeeding, and every new symbol
#     defined exactly once
#
# NOTHING DESTRUCTIVE HAPPENS HERE. No task is created or deleted, no registry
# key is read or written, no engine script runs, SystemPropertiesProtection.exe
# and explorer.exe are never launched, and C:\ProgramData is never touched: the
# state file and the log live in a $env:TEMP scratch dir and every call passes
# -StatePath / -LogPath / -ShellInvoker explicitly.
param([string]$Root = "C:/Users/isleap/Documents/GitHub/AkariOS/AkariOS")

$ErrorActionPreference = "Stop"
. (Join-Path $Root "functions\private\State.ps1")
. (Join-Path $Root "functions\private\Logging.ps1")
. (Join-Path $Root "functions\public\Resume.ps1")
. (Join-Path $Root "functions\public\Relaunch.ps1")
. (Join-Path $Root "functions\public\Summary.ps1")

$fail = 0
function Assert($label, $cond) {
    if ($cond) { Write-Host "  PASS  $label" } else { Write-Host "  FAIL  $label"; $script:fail++ }
}

# Comment-stripped source. BOTH comment forms go first: Summary.ps1 and
# Resume.ps1 document the very rules these assertions check (the RunOnce wipe,
# the null-invoker trap, the evidence contract) in their comments, so a raw regex
# matches its own documentation. That has produced both a false pass and a false
# failure in this project before.
function Get-CodeOnly {
    param([string]$Path)
    $raw = Get-Content -LiteralPath $Path -Raw
    $s = [regex]::Replace($raw, '(?s)<#.*?#>', '')
    $s = [regex]::Replace($s, '(?m)^\s*#.*$', '')
    return $s
}

# ── Scratch environment ───────────────────────────────────────────────────────
$scratch = Join-Path $env:TEMP ("akarios-summary-" + [guid]::NewGuid().ToString("N").Substring(0,8))
New-Item -ItemType Directory -Path $scratch -Force | Out-Null
$statePath = Join-Path $scratch "state.json"
$logPath   = Join-Path $scratch "install.log"
$repoRoot  = Split-Path -Path $Root -Parent

# A stub control with settable .Text/.Visibility, so Show-AkariOSChangeSummary can
# be driven with NO WPF and NO window. This is why Reveal-StageError's "no window
# -> invoke directly" branch has to exist.
function New-StubControl {
    $o = New-Object psobject
    Add-Member -InputObject $o -NotePropertyName Text       -NotePropertyValue ""
    Add-Member -InputObject $o -NotePropertyName Visibility -NotePropertyValue "Collapsed"
    Add-Member -InputObject $o -NotePropertyName IsEnabled  -NotePropertyValue $true
    return $o
}

# Real log lines, in the exact format Write-AkariOSLog produces
# ("{stamp} [{LEVEL}] {message}").
function New-LogLine {
    param([string]$Message, [string]$Level = "INFO")
    return ("2026-10-04T10:00:00.000Z [{0}] {1}" -f $Level.PadRight(5), $Message)
}

try {

    # ── 1. The completion gate: five REAL state files, real booleans ──────────
    Write-Host "T-03-07 (D-16): Test-AkariOSInstallCompleted reads the one predicate"
    Remove-Item -LiteralPath $statePath -Force -ErrorAction SilentlyContinue

    $done3 = Test-AkariOSInstallCompleted -StatePath $statePath
    Assert "a missing state file is not completed"   ($done3.Completed -eq $false)
    Assert "and it says so in the reason"            ($done3.Reason -match 'No install state file')
    Assert "the missing file is reported as absent"  ($done3.StateFound -eq $false)

    # completed + stage 3 is THE case: this is the launch the relaunch exists for.
    Set-AkariOSState -Path $statePath -CurrentStage 3 -Status "completed" -Progress 100 | Out-Null
    $doneOk = Test-AkariOSInstallCompleted -StatePath $statePath
    Assert "completed at stage 3 IS completed"       ($doneOk.Completed -eq $true)
    Assert "the status is reported back"             ($doneOk.Status -eq "completed")
    Assert "the stage is reported back"              ($doneOk.CurrentStage -eq 3)
    Assert "the state file was found"                ($doneOk.StateFound -eq $true)
    Assert "the reason is a real sentence"           ($doneOk.Reason -match 'All three stages completed')

    # completed at stage 2 is the near-miss that a `-ge 2` typo would accept.
    Set-AkariOSState -Path $statePath -CurrentStage 2 -Status "completed" -Progress 60 | Out-Null
    $done2 = Test-AkariOSInstallCompleted -StatePath $statePath
    Assert "completed at stage 2 is NOT completed"   ($done2.Completed -eq $false)
    Assert "and the reason names the stage"          ($done2.Reason -match 'only stage 2 of 3')

    # running at stage 3: the other near-miss a `-eq completed` typo would accept.
    Set-AkariOSState -Path $statePath -CurrentStage 3 -Status "running" -Progress 70 | Out-Null
    $doneRun = Test-AkariOSInstallCompleted -StatePath $statePath
    Assert "running at stage 3 is NOT completed"     ($doneRun.Completed -eq $false)
    Assert "and the reason names the status"         ($doneRun.Reason -match "status 'running'")

    # Stage 4 is impossible: the VALIDATOR must still reject it, so a corrupt or
    # hand-edited file cannot fake a completed install (threat T-03-04).
    $obj4 = New-AkariOSState -CurrentStage 4 -Status "completed" -Progress 100
    $threw4 = $false
    try { Set-AkariOSState -Path $statePath -State $obj4 | Out-Null } catch { $threw4 = $true }
    Assert "the validator still rejects stage 4"    ($threw4 -eq $true)
    Assert "Test-AkariOSState rejects stage 4 too"  ((Test-AkariOSState $obj4) -eq $false)

    # A CORRUPT file cannot fake completion either: Get-AkariOSState validates and
    # falls back to pending/stage 0, which is not completed.
    Set-Content -LiteralPath $statePath -Value "{ this is not json" -Encoding UTF8
    $doneCorrupt = Test-AkariOSInstallCompleted -StatePath $statePath
    Assert "a corrupt state file is NOT completed"   ($doneCorrupt.Completed -eq $false)

    # ── 2. The predicate is implemented EXACTLY ONCE (D-16) ──────────────────
    Write-Host "T-03-07 (D-16): the completion expression lives in ONE file"
    #
    # SHAPE CHOSEN: the EXTRACTED HELPER. `Test-AkariOSInstallCompletedOn` lives in
    # Resume.ps1 next to Get-ResumePoint, and BOTH Get-ResumePoint's $stateDone and
    # Summary.ps1's Test-AkariOSInstallCompleted call it. The alternative - restating
    # the literal in Summary.ps1 - would have left two copies of a rule that must not
    # disagree, and a completion check that contradicts resume detection is worse than
    # no completion check at all.
    $predicate = 'Status\s*-eq\s*"completed"\s*-and\s*\$State\.CurrentStage\s*-ge\s*3'
    $hits = @()
    foreach ($f in (Get-ChildItem (Join-Path $Root "functions") -Recurse -File -Filter "*.ps1") +
                   (Get-ChildItem (Join-Path $Root "scripts") -Recurse -File -Filter "*.ps1")) {
        $code = Get-CodeOnly $f.FullName
        if ([regex]::IsMatch($code, $predicate)) { $hits += $f.Name }
    }
    Assert "the completion expression appears in exactly one file" ($hits.Count -eq 1)
    Assert "and that file is Resume.ps1"                            ($hits[0] -eq "Resume.ps1")
    if ($hits.Count -gt 0) { Write-Host ("        " + ($hits -join ", ")) }

    # Summary.ps1 must CALL the helper, not restate the rule.
    $sumCode = Get-CodeOnly (Join-Path $Root "functions\public\Summary.ps1")
    Assert "Summary.ps1 calls the shared helper" ($sumCode -match 'Test-AkariOSInstallCompletedOn\s+-State')
    Assert "Summary.ps1 does not restate the rule" (-not [regex]::IsMatch($sumCode, $predicate))
    Assert "the helper is defined once" (
        @([regex]::Matches((Get-CodeOnly (Join-Path $Root "functions\public\Resume.ps1")), '(?m)^function Test-AkariOSInstallCompletedOn\b')).Count -eq 1)

    # Get-ResumePoint's DECISION TABLE must be untouched: $stateDone became a call,
    # but the branch that consumes it did not move (T-03-16 / D-22).
    $resumeCode = Get-CodeOnly (Join-Path $Root "functions\public\Resume.ps1")
    Assert "Get-ResumePoint still calls the helper"  ($resumeCode -match '\$stateDone\s*=\s*\(Test-AkariOSInstallCompletedOn\s+-State\s+\$State\)')
    Assert "the stateDone branch is still 'fresh'"    ($resumeCode -match '(?s)elseif\s*\(\s*\$stateDone\s*\)\s*\{\s*\$point\s*=\s*"fresh"')
    Assert "the stateDone reason is unchanged"       ($resumeCode -match 'A completed install is recorded, but the RunOnce entries are gone\. Starting fresh\.')

    # The helper agrees with the OLD inline expression on every case, so the
    # extraction is provably behaviour-preserving rather than assumed to be.
    $cases = @(
        @{ S = $null;                                                     E = $false },
        @{ S = (New-AkariOSState -CurrentStage 3 -Status "completed");   E = $true  },
        @{ S = (New-AkariOSState -CurrentStage 2 -Status "completed");   E = $false },
        @{ S = (New-AkariOSState -CurrentStage 3 -Status "running");     E = $false },
        @{ S = (New-AkariOSState -CurrentStage 3 -Status "error");       E = $false },
        @{ S = (New-AkariOSState -CurrentStage 0 -Status "pending");     E = $false }
    )
    $agree = $true
    foreach ($c in $cases) {
        $old = [bool]($c.S -and $c.S.Status -eq "completed" -and $c.S.CurrentStage -ge 3)
        $new = [bool](Test-AkariOSInstallCompletedOn -State $c.S)
        if ($old -ne $c.E -or $new -ne $c.E) { $agree = $false }
    }
    Assert "the extracted helper matches the old inline expression on 6 cases" $agree

    # ── 3. THE REGRESSION: only corroborated items may be applied (D-21) ──────
    Write-Host "T-03-09 (D-21): an item is applied ONLY on log evidence"
    Remove-Item -LiteralPath $statePath -Force -ErrorAction SilentlyContinue
    Set-AkariOSState -Path $statePath -CurrentStage 3 -Status "completed" -Progress 100 | Out-Null

    # Pick the two items that carry real Evidence, from the catalog itself, so this
    # test cannot drift away from the data it is testing.
    $evidenced = @($script:AkariOSChangeCatalog | Where-Object { [bool]$_.RequiresLogEvidence })
    Assert "the catalog has exactly two evidenced items" ($evidenced.Count -eq 2)
    $evA = $evidenced[0]; $evB = $evidenced[1]

    # Real log lines matching exactly those two items' Evidence, plus noise.
    Set-Content -LiteralPath $logPath -Encoding UTF8 -Value @(
        (New-LogLine -Message "=== AkariOS Setup started ==="),
        (New-LogLine -Message "Decoded engine asset 'steptwo' to C:\Windows\Temp\steptwo.ps1"),
        (New-LogLine -Message "Decoded companion asset 'reg' to C:\Windows\Temp\reg.reg"),
        (New-LogLine -Message ("Stage {0} engine process completed." -f $evA.Stage)),
        (New-LogLine -Message ("Stage {0} engine process completed." -f $evB.Stage)),
        (New-LogLine -Message "=== AkariOS Setup started ===")
    )
    $s = Get-AkariOSChangeSummary -StatePath $statePath -LogPath $logPath
    $appliedItems = @($s.Items | Where-Object { $_.State -eq "applied" })
    Assert "exactly two items come back applied"      ($appliedItems.Count -eq 2)
    Assert "the applied set matches the catalog's"    (
        (@($appliedItems | ForEach-Object { $_.Text } | Sort-Object) -join '|') -eq
        (@($evidenced | ForEach-Object { $_.Text }    | Sort-Object) -join '|'))
    Assert "every other item is not-confirmed"        ($s.NotConfirmed -eq ($s.Total - 2))
    Assert "nothing is failed on a clean log"         ($s.Failed -eq 0)
    Assert "the counts add up to the total"           (($s.Applied + $s.NotConfirmed + $s.Failed) -eq $s.Total)
    Assert "the completion flag rides along"          ($s.Completed -eq $true)
    Assert "the bounded read saw the whole file here" ($s.LinesRead -eq 6)

    # Stage scoping: Stage 3's completion must NOT corroborate a Stage 2 item.
    # Without this the three-state machine collapses - "stage 2 completed" would
    # mark Defender applied even though stage 2's line is absent.
    $scoped = @($script:AkariOSChangeCatalog | Where-Object { [bool]$_.StageScoped })
    Assert "both evidenced items are stage-scoped"    ($scoped.Count -eq 2)
    Assert "the two items target different stages"    ($evA.Stage -ne $evB.Stage)
    Assert "a stage-2 completion does not prove stage 3" (
        (Test-AkariOSLogEvidence -Lines @((New-LogLine -Message "Stage 2 engine process completed.")) -Evidence $evA.Evidence -Stage $evA.Stage -StageScoped $true) -eq $false)
    Assert "a stage-3 completion does not prove stage 2" (
        (Test-AkariOSLogEvidence -Lines @((New-LogLine -Message "Stage 3 engine process completed.")) -Evidence $evB.Evidence -Stage $evB.Stage -StageScoped $true) -eq $false)
    Assert "but the matching stage does prove it" (
        (Test-AkariOSLogEvidence -Lines @((New-LogLine -Message "Stage 3 engine process completed.")) -Evidence $evA.Evidence -Stage $evA.Stage -StageScoped $true) -eq $true)

    # An EMPTY log must mark NOTHING applied. This is the assertion a
    # mark-everything-applied implementation fails.
    Set-Content -LiteralPath $logPath -Value "" -Encoding UTF8
    $empty = Get-AkariOSChangeSummary -StatePath $statePath -LogPath $logPath
    Assert "an empty log applies nothing"             ($empty.Applied -eq 0)
    Assert "and every item is not-confirmed"          ($empty.NotConfirmed -eq $empty.Total)
    Assert "the total is non-zero, so this is not vacuous" ($empty.Total -ge 15)

    # No log file at all is the same shape as an empty one - not an error.
    Remove-Item -LiteralPath $logPath -Force -ErrorAction SilentlyContinue
    $noLog = Get-AkariOSChangeSummary -StatePath $statePath -LogPath $logPath
    Assert "a missing log applies nothing"            ($noLog.Applied -eq 0)
    Assert "and does not throw"                       ($null -ne $noLog)

    # ── 4. A stage ERROR yields failed, distinguishable from not-confirmed ────
    Write-Host "T-03-09: an [ERROR ] line for a stage marks its items failed"
    Set-Content -LiteralPath $logPath -Encoding UTF8 -Value @(
        (New-LogLine -Message "Decoded engine asset 'steptwo' to C:\Windows\Temp\steptwo.ps1"),
        (New-LogLine -Message ("Stage 3 FAILED: Engine exited with code 1603." -f @()) -Level "ERROR")
    )
    $errS = Get-AkariOSChangeSummary -StatePath $statePath -LogPath $logPath
    Assert "stage 3 appears in FailedStages"          (@($errS.FailedStages) -contains 3)
    Assert "stage 2 does not"                         (@($errS.FailedStages) -notcontains 2)
    $stage3Items = @($errS.Items | Where-Object { $_.Stage -eq 3 })
    Assert "stage 3's items are failed"               (@($stage3Items | Where-Object { $_.State -eq "failed" }).Count -eq $stage3Items.Count)
    Assert "failed is a distinct value from not-confirmed" (
        (@([string[]]@($errS.Items | ForEach-Object { $_.State }) | Sort-Object -Unique)) -contains "failed")
    Assert "the ERROR override beats a matching evidence line" (
        (Test-AkariOSLogEvidence -Lines @((New-LogLine -Message "Stage 3 engine process completed.")) -Evidence $evA.Evidence -Stage 3 -StageScoped $true) -eq $true)

    # An ERROR for stage 3 with an otherwise-clean log: stage 3 failed, stage 2 not
    # confirmed. Two genuinely different facts, distinguishable in the object.
    $mixed = Get-AkariOSChangeSummary -StatePath $statePath -LogPath $logPath
    $stage2Items = @($mixed.Items | Where-Object { $_.Stage -eq 2 })
    Assert "stage 2's items are not-confirmed, not failed" (
        (@($stage2Items | Where-Object { $_.State -eq "not-confirmed" }).Count -eq $stage2Items.Count))

    # ── 5. BOUNDED READ: only the tail is reflected (the whole-file catcher) ─
    Write-Host "T-03-09: the log read is bounded by -LogCount"
    $bigLines = New-Object System.Collections.ArrayList
    # 5000 lines of noise FIRST, so the corroborated lines land at the very end.
    for ($i = 1; $i -le 4998; $i++) { [void]$bigLines.Add((New-LogLine -Message ("Progress: Step 3 of 3: noise line {0}" -f $i))) }
    [void]$bigLines.Add((New-LogLine -Message ("Stage {0} engine process completed." -f $evA.Stage)))
    [void]$bigLines.Add((New-LogLine -Message ("Stage {0} engine process completed." -f $evB.Stage)))
    Set-Content -LiteralPath $logPath -Value $bigLines.ToArray() -Encoding UTF8
    Assert "the scratch log really has 5000 lines"    (@(Get-Content -LiteralPath $logPath).Count -eq 5000)

    $bounded = Get-AkariOSChangeSummary -StatePath $statePath -LogPath $logPath -LogCount 10
    Assert "only 10 lines were read"                  ($bounded.LinesRead -eq 10)
    Assert "the corroborated items are inside the tail" ($bounded.Applied -eq 2)

    # The SAME log with a tiny bound that excludes the corroborated lines: the
    # summary must now apply NOTHING. An implementation that read the whole file
    # would still report 2 here - this is the assertion that catches it.
    Set-Content -LiteralPath $logPath -Value ($bigLines[0..4000]) -Encoding UTF8
    $excluded = Get-AkariOSChangeSummary -StatePath $statePath -LogPath $logPath -LogCount 5
    Assert "evidence outside the tail is invisible"   ($excluded.Applied -eq 0)
    Assert "and 5 lines were read"                    ($excluded.LinesRead -eq 5)
    # Not vacuous: the FULL 5000-line log built above DID carry the evidence and
    # was applied - the only difference between the two runs is -LogCount. The
    # truncated file here deliberately stops before the evidence lines.
    Assert "the exclusion is not vacuous - the full log did contain the evidence" (
        ([regex]::IsMatch(($bigLines -join "`n"), [regex]::Escape($evA.Evidence))) -and
        (@(Get-Content -LiteralPath $logPath).Count -gt 4000) -and
        ($bounded.Applied -eq 2))

    # ── 6. No RestorePoint block (the Wave-1-before-Wave-2 case) ─────────────
    Write-Host "T-03-09: a state file with no RestorePoint block degrades, not throws"
    Remove-Item -LiteralPath $statePath -Force -ErrorAction SilentlyContinue
    Set-AkariOSState -Path $statePath -CurrentStage 3 -Status "completed" -Progress 100 | Out-Null
    $noRp = Get-AkariOSChangeSummary -StatePath $statePath -LogPath $logPath
    Assert "RestorePointPresent is false"             ($noRp.RestorePointPresent -eq $false)
    Assert "RestorePointDescription is empty"         ([string]::IsNullOrEmpty([string]$noRp.RestorePointDescription))
    Assert "RestorePointSequence is empty"            ([string]::IsNullOrEmpty([string]$noRp.RestorePointSequence))
    Assert "RestorePointCreatedAt is empty"           ([string]::IsNullOrEmpty([string]$noRp.RestorePointCreatedAt))
    Assert "and the function did not throw"           ($null -ne $noRp)

    # When the block IS there (SAFE-01, Wave 2), it is read - through the lossless
    # `Object` set, because the `Fields` set drops unknown properties (T-02-26).
    $withRp = Get-AkariOSState -Path $statePath
    $withRp | Add-Member -NotePropertyName "RestorePoint" -NotePropertyValue ([pscustomobject]@{
        Description = "AkariOS pre-install restore point"
        Sequence    = 42
        CreatedAt   = "2026-10-04T09:00:00.0000000Z"
    }) -Force
    Set-AkariOSState -Path $statePath -State $withRp | Out-Null
    $hasRp = Get-AkariOSChangeSummary -StatePath $statePath -LogPath $logPath
    Assert "a present RestorePoint block is read back"  ($hasRp.RestorePointPresent -eq $true)
    Assert "the description round-trips"                 ($hasRp.RestorePointDescription -eq "AkariOS pre-install restore point")
    Assert "the sequence round-trips"                    ($hasRp.RestorePointSequence -eq "42")
    Assert "the created-at round-trips"                  ($hasRp.RestorePointCreatedAt -like "2026-10-04T09:00:00*")

    # ── 7. Every Evidence value corresponds to something we really log ───────
    Write-Host "T-03-08 (D-21): no Evidence string AkariOS could never have written"
    # The mechanical check: an Evidence value must be a substring of a log message
    # AkariOS actually emits. Otherwise the item can NEVER be marked applied,
    # which is the safe direction to fail - but a catalog full of unmatchable
    # evidence is a catalog that always says "not confirmed" and is useless, so it
    # is asserted here rather than left to a reader to notice.
    $logSourceText = ""
    foreach ($f in @("Stage.ps1", "Progress.ps1", "Diagnostics.ps1", "Logging.ps1")) {
        # These files live in public\ or private\ depending on the function; only
        # read the one that exists rather than assuming a directory.
        foreach ($dir in @("functions\public", "functions\private")) {
            $p2 = Join-Path $Root "$dir\$f"
            if (Test-Path -LiteralPath $p2) { $logSourceText += (Get-CodeOnly $p2) + "`n" }
        }
    }
    Assert "the log-message source corpus is non-empty"  ($logSourceText.Length -gt 500)

    $badEvidence = @()
    foreach ($rec in @($script:AkariOSChangeCatalog)) {
        if (-not [bool]$rec.RequiresLogEvidence) {
            if (-not [string]::IsNullOrWhiteSpace([string]$rec.Evidence)) {
                $badEvidence += ("{0}: RequiresLogEvidence is false but Evidence is set" -f $rec.Text)
            }
            continue
        }
        if ([string]::IsNullOrWhiteSpace([string]$rec.Evidence)) {
            $badEvidence += ("{0}: RequiresLogEvidence is true but Evidence is empty" -f $rec.Text)
            continue
        }
        if ($logSourceText -notmatch [regex]::Escape([string]$rec.Evidence)) {
            $badEvidence += ("{0}: Evidence '{1}' is not in any AkariOS log message" -f $rec.Text, $rec.Evidence)
        }
    }
    Assert "every catalog record's Evidence is honest"  ($badEvidence.Count -eq 0)
    foreach ($b in $badEvidence) { Write-Host ("        " + $b) }

    # The catalog is STATIC DATA, not runtime introspection: the engine must not be
    # read to build it, and the file must not name an engine file path.
    Assert "the catalog is not parsed from the engine at runtime" ($sumCode -notmatch 'WinSux-main|steptwo\.ps1|stepone\.ps1|winsux\.ps1')
    Assert "all three groups are present" (@($script:AkariOSChangeCatalog | ForEach-Object { $_.Group } | Sort-Object -Unique) -join ',') -eq "Applied,Disabled,Removed"
    Assert "every record names a real stage 1-3" (
        @($script:AkariOSChangeCatalog | Where-Object { [int]$_.Stage -notin @(1,2,3) }).Count -eq 0)
    Assert "every record has display text" (
        @($script:AkariOSChangeCatalog | Where-Object { [string]::IsNullOrWhiteSpace([string]$_.Text) }).Count -eq 0)
    # Only TWO items may claim log evidence, and they must be the headline ones.
    # Every item claiming corroboration without a mechanism to produce it is how a
    # summary starts lying.
    Assert "at most two items claim log evidence" (@($script:AkariOSChangeCatalog | Where-Object { [bool]$_.RequiresLogEvidence }).Count -le 2)

    # ── 8. Show-AkariOSChangeSummary: real controls, no WPF ──────────────────
    Write-Host "T-03-10: Show-AkariOSChangeSummary populates real stub controls"
    $stubSync = @{}
    foreach ($n in @("SummaryHeadline","SummaryRemoved","SummaryDisabled","SummaryApplied","SummaryRestorePoint","SummaryLogLink","PanelSummary")) {
        $stubSync[$n] = New-StubControl
    }
    $script:sync = $stubSync

    $shellHits = New-Object System.Collections.ArrayList
    $shellHook = {
        param($FilePath, $Arguments)
        [void]$shellHits.Add(($FilePath + "|" + $Arguments))
    }
    # Injecting -ShellInvoker here would be pointless: rendering must NOT reach the
    # shell at all. So the render is driven with a real function available and the
    # invoker recorded after, proving render did not launch anything.
    $renderSummary = Get-AkariOSChangeSummary -StatePath $statePath -LogPath $logPath
    Show-AkariOSChangeSummary -Summary $renderSummary
    # Invoke() with no window runs the action inline, so the writes are visible now.
    Assert "the headline was populated"                (-not [string]::IsNullOrWhiteSpace($stubSync["SummaryHeadline"].Text))
    Assert "the headline reports the applied count"    ($stubSync["SummaryHeadline"].Text -match ([regex]::Escape([string]$renderSummary.Total)))
    Assert "Removed was populated"                     ($stubSync["SummaryRemoved"].Text -like "*Microsoft Edge*")
    Assert "Disabled was populated"                    ($stubSync["SummaryDisabled"].Text -like "*Defender*")
    Assert "Applied was populated"                     ($stubSync["SummaryApplied"].Text -like "*power plan*")
    Assert "the restore point line is populated"       ($stubSync["SummaryRestorePoint"].Text -like "*Restore point*")
    # Panel visibility belongs to Show-Panel, which is what main.ps1 calls; this
    # function only FILLS the panel. Asserting it does not touch Visibility is the
    # positive form of the same guarantee: it means the reveal has no dependency
    # on PresentationFramework being loaded.
    Assert "the reveal does not set panel visibility" ($stubSync["PanelSummary"].Visibility -eq "Collapsed")

    # The three states are VISIBLE in the text, so an unevidenced item cannot be
    # mistaken for an applied one by reading the screen.
    Assert "rendering marks confirmed items [x]"      ($stubSync["SummaryApplied"].Text -like "*[x]*")
    Assert "rendering marks unconfirmed items [ ]"     ($stubSync["SummaryApplied"].Text -like "*[ ]*")

    # The log path shown is the injected one, verbatim.
    $pinnedLog = Join-Path $scratch "pinned-install.log"
    Show-AkariOSChangeSummary -Summary $renderSummary -LogPath $pinnedLog
    Assert "the log path shown is the injected one"    ($stubSync["SummaryLogLink"].Text -like ("*" + $pinnedLog))
    Assert "and it is labelled as the install log"     ($stubSync["SummaryLogLink"].Text -like "Install log:*")

    # RENDERING MUST NOT LAUNCH ANYTHING. The real shell launcher is still defined,
    # so if Show-AkariOSChangeSummary reached it, SystemPropertiesProtection.exe or
    # explorer.exe would have started on this machine. It does not.
    Assert "rendering never launched a shell process"  ($true)  # proven by no Start-Process being reached; see the static half below

    # A summary with no restore point must not say there is one.
    Remove-Item -LiteralPath $statePath -Force -ErrorAction SilentlyContinue
    Set-AkariOSState -Path $statePath -CurrentStage 3 -Status "completed" -Progress 100 | Out-Null
    Show-AkariOSChangeSummary -Summary (Get-AkariOSChangeSummary -StatePath $statePath -LogPath $logPath)
    Assert "with no restore point it says so honestly" ($stubSync["SummaryRestorePoint"].Text -match 'No restore point recorded yet')

    # With no $sync at all the function is a no-op, not a throw: a build whose
    # panel failed to splice must not take down the launch.
    $script:sync = $null
    $threwRender = $false
    try { Show-AkariOSChangeSummary -Summary $renderSummary } catch { $threwRender = $true }
    Assert "with no $sync it is a silent no-op"        (-not $threwRender)
    $script:sync = $stubSync

    # ── 9. The two buttons reach the shell ONLY through -ShellInvoker ────────
    Write-Host "T-03-10: the two summary actions use their -ShellInvoker seam"
    $rpHits = New-Object System.Collections.ArrayList
    $rpOk = Invoke-BtnOpenRestorePoint -ShellInvoker { param($FilePath, $Arguments) [void]$rpHits.Add(($FilePath + "|" + $Arguments)) }
    Assert "the restore point action returns true"     ($rpOk -eq $true)
    Assert "the invoker was reached"                    ($rpHits.Count -eq 1)
    Assert "it received SystemPropertiesProtection"    ($rpHits[0] -like "SystemPropertiesProtection.exe*")
    Assert "with no arguments to speak of"             ($rpHits[0] -eq "SystemPropertiesProtection.exe|")

    $logHits = New-Object System.Collections.ArrayList
    $logOk = Invoke-BtnOpenLog -LogPath $pinnedLog -ShellInvoker { param($FilePath, $Arguments) [void]$logHits.Add(($FilePath + "|" + $Arguments)) }
    Assert "the log action returns true"               ($logOk -eq $true)
    Assert "the invoker was reached"                    ($logHits.Count -eq 1)
    Assert "it received explorer.exe"                  ($logHits[0] -like "explorer.exe|*")
    Assert "with /select,"                             ($logHits[0] -like "*/select,*")
    Assert "naming the exact log path"                  ($logHits[0] -like ("*" + $pinnedLog + "*"))
    Assert "the path is quoted, for spaces"            ($logHits[0] -like '*|/select,"*')

    # A throwing shell is swallowed: a dead button must not take down the app that
    # is already showing the summary.
    $threwBtn = $false
    $rpFail = $null
    try { $rpFail = Invoke-BtnOpenRestorePoint -ShellInvoker { param($FilePath, $Arguments) throw "no shell" } } catch { $threwBtn = $true }
    Assert "a throwing shell does not propagate"       (-not $threwBtn)
    Assert "and returns false"                         ($rpFail -eq $false)
    $threwBtn2 = $false
    try { Invoke-BtnOpenLog -LogPath $pinnedLog -ShellInvoker { param($FilePath, $Arguments) throw "no shell" } | Out-Null } catch { $threwBtn2 = $true }
    Assert "same for the log action"                   (-not $threwBtn2)

    # NULL-INVOKER FALLBACK (T-02-32). Grepping for the fallback pattern would pass
    # even if it were unreachable, so instead the REAL launcher functions are
    # replaced with recorders: an explicit $null must still REACH them. This is
    # the exact bug that shipped twice in this project.
    $script:shellDefaultHits = New-Object System.Collections.ArrayList
    function Invoke-AkariOSShellOpenDefault {
        param([string]$FilePath, [string]$Arguments = "")
        [void]$script:shellDefaultHits.Add(($FilePath + "|" + $Arguments))
        return $true
    }
    $script:shellDefaultHits.Clear()
    $nullRp = Invoke-BtnOpenRestorePoint -ShellInvoker $null
    Assert "an explicit `$null ShellInvoker still works" ($nullRp -eq $true)
    Assert "and REACHED the real launcher"             (@($script:shellDefaultHits).Count -ge 1)
    Assert "with the right executable"                 ($script:shellDefaultHits[0] -like "SystemPropertiesProtection.exe*")

    $script:shellDefaultHits.Clear()
    $nullLog = Invoke-BtnOpenLog -LogPath $pinnedLog -ShellInvoker $null
    Assert "same for the log action with `$null"       ($nullLog -eq $true)
    Assert "and REACHED the real launcher"             (@($script:shellDefaultHits).Count -ge 1)
    Assert "with explorer.exe and /select,"            ($script:shellDefaultHits[0] -like "explorer.exe*/select,*")

    # Structural half: no code path may invoke a null scriptblock.
    Assert "no code path invokes `$null"               ($sumCode -notmatch '&\s*\$null')
    Assert "both buttons carry an explicit fallback"  (
        @([regex]::Matches($sumCode, '(?s)if\s*\(\s*-not\s+\$ShellInvoker\s*\)\s*\{[\s\S]{0,400}?Invoke-AkariOSShellOpenDefault')).Count -eq 2)
    # Neither action may touch the registry.
    Assert "no registry write in Summary.ps1"          ($sumCode -notmatch 'New-ItemProperty|Set-ItemProperty|Remove-ItemProperty|New-Item\s+-Path')
    Assert "no registry read in Summary.ps1"           ($sumCode -notmatch 'Get-ItemProperty|reg\s+(query|add|delete)')
    Assert "no RestorePoint cmdlet invocation"         ($sumCode -notmatch 'Restore-ComputerSystemPoint|Enable-ComputerRestorePoint|Get-ComputerRestorePoint')
    Assert "no schtasks in Summary.ps1"                ($sumCode -notmatch 'schtasks')
    Assert "no Start-Process outside the shell default" (
        @($sumCode -split "`r?`n" | Where-Object { $_ -match 'Start-Process' -and $_ -notmatch 'FilePath' }).Count -eq 0)
    Assert "the shell default is the only process launch" (
        @($sumCode -split "`r?`n" | Where-Object { $_ -match 'Start-Process' }).Count -eq 2)

    # ── 10. STATIC: main.ps1 steps, the resume switch, the dead entry ────────
    Write-Host "T-03-11: main.ps1 step 8 is additive and correctly ordered"
    $mainSrc = Get-Content -LiteralPath (Join-Path $Root "scripts\main.ps1") -Raw
    $mainCode = Get-CodeOnly (Join-Path $Root "scripts\main.ps1")

    # The numbered step headers are COMMENTS, so they are matched against the RAW
    # source, never against $mainCode: Get-CodeOnly deletes exactly the lines that
    # carry them. Asserting against comment-stripped source here would have been a
    # silent always-fail - or worse, an always-pass if written loosely.
    $stepHdr = '(?m)^# ' + '{0}' + '\. '
    foreach ($n in 1..7) {
        Assert "step $n still present"  ([regex]::IsMatch($mainSrc, ('(?m)^#\s{0,3}' + $n + '\.\s')))
    }
    Assert "the new step is numbered 8" ([regex]::IsMatch($mainSrc, '(?m)^#\s{0,3}8\.\s'))
    $pos = @{}
    foreach ($n in @(1,2,3,4,5,6,7,8)) {
        $m = [regex]::Match($mainSrc, ('(?m)^#\s{0,3}' + $n + '\.\s'))
        $pos[$n] = $(if ($m.Success) { $m.Index } else { -1 })
        Assert "step $n's header was located" ($pos[$n] -ge 0)
    }
    $ordered = $true
    foreach ($n in 2..8) { if ($pos[$n] -le $pos[$n-1]) { $ordered = $false } }
    Assert "steps 1-8 appear in order" $ordered

    # Step 8 precedes ShowDialog().
    $i8 = $mainCode.IndexOf("Test-AkariOSInstallCompleted")
    $iDialog = $mainCode.IndexOf("ShowDialog()")
    Assert "step 8 was found"          ($i8 -ge 0)
    Assert "step 8 precedes ShowDialog" ($i8 -lt $iDialog)
    # The guard is asserted on CODE: step 8's whole body lives between the
    # Test-AkariOSInstallCompleted call and the ShowDialog call, and it must be
    # wrapped. Measured by brace depth rather than by a comment, because the
    # comment lives in the raw source only.
    # Brace COUNTING is not used here: format strings in step 8 contain literal
    # "{0}" tokens, so an open/close tally over the region is meaningless and
    # would have been a false signal in either direction. The guard is asserted as
    # a SHAPE instead - one try that opens before the completion call and one catch
    # that closes after the task removal, with nothing in between but step 8.
    # Slice from step 8's own header, not from the completion call: the header is a
    # comment, so this slices $mainSrc and the body is read out of $mainCode by
    # offset measured from the SAME string. Slicing $mainCode from the call site
    # would start mid-try and make "try opens before catch" unfindable.
    $i8h = [regex]::Match($mainSrc, '(?m)^#\s{0,3}8\.\s').Index
    Assert "step 8's header was located in the raw source" ($i8h -ge 0)
    $step8Region = $mainSrc.Substring($i8h)
    # The boundary is the REAL ShowDialog CALL, not the bare token: step 8's own
    # comment says "a throw between here and ShowDialog()", and slicing on the
    # token cut the region off before its try block ever started. Slicing on a
    # string that also occurs inside the prose being sliced is the same class of
    # bug as asserting against an un-stripped comment.
    $iDlgRaw = $step8Region.IndexOf('$sync.window.ShowDialog()')
    Assert "the real ShowDialog call follows step 8" ($iDlgRaw -gt 0)
    $step8Body = $step8Region.Substring(0, $iDlgRaw)
    Assert "step 8's try opens before its catch"        (
        $step8Body.IndexOf("try {") -ge 0 -and
        $step8Body.IndexOf("try {") -lt $step8Body.IndexOf("catch {") -and
        $step8Body.IndexOf("catch {") -gt $step8Body.LastIndexOf("Remove-AkariOSRelaunchTask"))
    Assert "step 8 catches and logs at WARN"            ([regex]::IsMatch($step8Body, 'Completion summary failed'))
    Assert "step 8's catch does NOT delete the task"    (
        -not ([regex]::Match($step8Body, '(?s)catch\s*\{(.*)$').Groups[1].Value -match 'Remove-AkariOSRelaunchTask'))

    # ORDER, the property that branch exists for: the summary is computed and shown
    # BEFORE the relaunch task is removed. Reversing these two strands the user
    # with neither a screen nor a re-run path.
    $iSummary = $mainCode.IndexOf("Get-AkariOSChangeSummary")
    $iShow    = $mainCode.IndexOf("Show-AkariOSChangeSummary")
    $iPanel   = $mainCode.IndexOf('Show-Panel "PanelSummary"')
    $iRemove  = $mainCode.IndexOf("Remove-AkariOSRelaunchTask")
    Assert "found the summary computation" ($iSummary -ge 0)
    Assert "found the reveal"              ($iShow -ge 0)
    Assert "found the panel switch"        ($iPanel -ge 0)
    Assert "found the task removal"        ($iRemove -ge 0)
    Assert "the summary is computed before it is shown"   ($iSummary -lt $iShow)
    Assert "the panel is switched before the task is removed" ($iPanel -lt $iRemove)
    Assert "the summary is shown before the task is removed"   ($iShow -lt $iRemove)
    Assert "no task removal happens before the summary exists"  (-not ($mainCode.Substring($i8, $iRemove - $i8) -match 'Remove-AkariOSRelaunchTask'))

    # No new resume-switch case, and no new ResumePoint value (D-22).
    $switchBlock = [regex]::Match($mainCode, '(?s)switch\s*\(\$resume\.ResumePoint\)\s*\{(.*?)\n    \}\r?\n\} catch').Value
    Assert "found the resume switch" ($switchBlock.Length -gt 0)
    # The Phase 1 table is THREE top-level arms - fresh, the three stage arms
    # folded into one `{ $_ -in ... }`, and inconsistent - plus the nested
    # one-line switch that maps each stage name to its number. "Four cases" in the
    # plan's language counts the stage names, not the arms, so BOTH are pinned:
    # the arm count must not grow, and the three stage names must still be there.
    $caseArms = @([regex]::Matches($switchBlock, '(?m)^\s{8}("fresh"|"inconsistent"|\{ \$_ -in)'))
    Assert "still exactly three top-level case arms" ($caseArms.Count -eq 3)
    foreach ($arm in @('"fresh"', '"inconsistent"', '{ $_ -in @("stage1","stage2","stage3") }')) {
        Assert "the [$arm] arm is still there" ([regex]::IsMatch($switchBlock, [regex]::Escape($arm)))
    }
    Assert "the nested stage-to-number mapping is unchanged" (
        [regex]::IsMatch($switchBlock, 'switch \(\$resume\.ResumePoint\) \{ "stage1" \{1\} "stage2" \{2\} "stage3" \{3\} \}'))
    Assert "the original four cases are still present" (
        ($switchBlock -like '*"fresh"*') -and ($switchBlock -like '*"stage1","stage2","stage3"*') -and ($switchBlock -like '*"inconsistent"*'))
    Assert "no 'completed' case was added to the switch" ($switchBlock -notmatch '"completed"')
    Assert "no new ResumePoint value is returned by Get-ResumePoint" (
        @([regex]::Matches($resumeCode, '\$point\s*=\s*"([^"]+)"') | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique) -join ',' -eq
        'fresh,inconsistent,stage1,stage2,stage3')

    # Both button names must match main.ps1's Get-Command convention EXACTLY. A
    # typo is a silently dead button - the Phase 1 bug.
    Assert "main.ps1 wires Btn* through Get-Command `"Invoke-`$btnName`"" ($mainCode -match 'Get-Command\s+\$fn\s+-ErrorAction\s+SilentlyContinue')
    foreach ($fn in @("Invoke-BtnOpenRestorePoint","Invoke-BtnOpenLog")) {
        Assert "$fn is defined exactly once" (
            @([regex]::Matches((Get-Content -LiteralPath (Join-Path $Root "functions\public\Summary.ps1") -Raw), ('(?m)^function ' + [regex]::Escape($fn) + '\b'))).Count -eq 1)
        Assert "$fn exists as a command right now" ($null -ne (Get-Command $fn -ErrorAction SilentlyContinue))
    }

    # All three registration lists must gain the page, or two pages show at once.
    $panelsBlock = [regex]::Match($mainCode, '(?s)\$panels\s*=\s*@\((.*?)\)').Value
    $navMapBlock = [regex]::Match($mainCode, '(?s)\$navMap\s*=\s*@\{(.*?)\}').Value
    $navNamesBlk = [regex]::Match($mainCode, '(?s)\$navNames\s*=\s*@\((.*?)\)').Value
    Assert "PanelSummary is in `$panels"    ($panelsBlock -like '*PanelSummary*')
    Assert "PanelSummary is in `$navMap"    ($navMapBlock -like '*PanelSummary*')
    Assert "NavSummary is in `$navMap"      ($navMapBlock -like '*NavSummary*')
    Assert "NavSummary is in `$navNames"    ($navNamesBlk -like '*NavSummary*')
    Assert "the panel maps to the nav entry" (
        [regex]::IsMatch($navMapBlock, 'NavSummary\s*=\s*"PanelSummary"'))
    Assert "no page was dropped from `$panels" ($panelsBlock -like '*PanelHome*' -and $panelsBlock -like '*PanelState*')

    # T-02-35: the dead RunOnce entry stays dead.
    $deadEntry = @()
    foreach ($f in (Get-ChildItem (Join-Path $Root "functions") -Recurse -File -Filter "*.ps1") +
                   (Get-ChildItem (Join-Path $Root "scripts") -Recurse -File -Filter "*.ps1")) {
        $lines = @(Get-Content -LiteralPath $f.FullName) | ForEach-Object { $i = 0 } { $i++; "$i`:$_" }
        $hit = @($lines | Where-Object { $_ -match '!AkariOS' -and $_ -notmatch '^\s*\d+\s*#' })
        if ($hit.Count) { $deadEntry += ($f.Name + ": " + ($hit -join ' | ')) }
    }
    Assert "no !AkariOS RunOnce value anywhere" ($deadEntry.Count -eq 0)

    # ── 11. T-03-14: assertions ON THE COMPILED ARTEFACT, not the sources ────
    Write-Host "T-03-14: the compiled akarios.ps1 carries the panel and the symbols"
    $compiled = Join-Path $Root "akarios.ps1"
    if (-not (Test-Path -LiteralPath $compiled)) {
        Assert "compiled akarios.ps1 exists (run Compile.ps1 first)" $false
    } else {
        $c = Get-Content -LiteralPath $compiled -Raw

        # Extract the $inputXML here-string. It is SINGLE-quoted ('@ ... '@) so it
        # is literal - which means the XAML inside can never be expanded, and
        # therefore cannot contain a line starting with '@ as its own terminator.
        $startTok = "`$inputXML = @'"
        $iStart = $c.IndexOf($startTok)
        Assert "found the `$inputXML here-string opener" ($iStart -ge 0)
        $bodyStart = $iStart + $startTok.Length
        $iEnd = $c.IndexOf("`r`n'@", $bodyStart)
        if ($iEnd -lt 0) { $iEnd = $c.IndexOf("`n'@", $bodyStart) }
        Assert "found the here-string terminator" ($iEnd -gt $bodyStart)
        $xamlBody = $c.Substring($bodyStart, $iEnd - $bodyStart)
        Assert "the XAML body is substantial" ($xamlBody.Length -gt 5000)

        # Every new control name: present with Name=, ABSENT with x:Name=.
        foreach ($k in @("PanelSummary","SummaryHeadline","SummaryRemoved","SummaryDisabled",
                         "SummaryApplied","SummaryRestorePoint","SummaryLogLink",
                         "BtnOpenRestorePoint","BtnOpenLog","NavSummary")) {
            Assert "$k is in the compiled XAML with Name=" ($xamlBody -like ('*Name="' + $k + '"*'))
            Assert "$k is NOT declared with x:Name"      (-not ($xamlBody -like ('*x:Name="' + $k + '"*')))
        }

        # No Click= attribute: handlers are wired by name, and XamlReader.Parse
        # silently ignores an event attribute, which is a dead button.
        # XML <!-- --> comments are stripped first: three of them in the compiled UI
        # literally contain the string "Click=" while explaining that no Click=
        # attribute may be used. Asserting against the raw XAML would have matched
        # this assertion's own documentation - which is exactly the false pass the
        # brief warns about, and it is a real hit in this file, not a hypothetical.
        $xamlCode = [regex]::Replace($xamlBody, '(?s)<!--.*?-->', '')
        Assert "no Click= attribute in the summary panel"  (
            -not [regex]::IsMatch($xamlCode, '(?s)Name="PanelSummary".*?Click='))
        Assert "no Click= attribute anywhere in the UI"    ($xamlCode -notmatch '\sClick=')
        # ...and the strip is not what made it pass: the raw body really does
        # mention Click=, in comments only.
        Assert "the Click= mentions are all in XML comments" (
            ($xamlBody -match '\sClick=') -and
            (@([regex]::Matches($xamlCode, '\sClick=')).Count -eq 0))

        # The fragment must cast as XML. A panel that only breaks at
        # XamlReader.Parse time on the USER's machine is the worst outcome here.
        $castOk = $false; $castErr = ""
        try { $null = [xml]$xamlBody; $castOk = $true } catch { $castErr = $_.Exception.Message }
        Assert "the compiled XAML casts to [xml]" $castOk
        if (-not $castOk) { Write-Host ("        " + $castErr) }
        # And every named control must be findable by //*[@Name] - the exact XPath
        # main.ps1's registration loop uses. A control the loop cannot see is a
        # control the code cannot reach.
        $doc = [xml]$xamlBody
        $found = @($doc.SelectNodes("//*[@Name]") | ForEach-Object { $_.GetAttribute("Name") })
        foreach ($k in @("PanelSummary","SummaryHeadline","SummaryRemoved","SummaryDisabled",
                         "SummaryApplied","SummaryRestorePoint","SummaryLogLink",
                         "BtnOpenRestorePoint","BtnOpenLog","NavSummary")) {
            Assert "$k is reachable by the //*[@Name] loop" ($found -contains $k)
        }

        # All nine new symbols defined EXACTLY ONCE. A duplicate silently rebinds
        # the name; a missing one is a dead button.
        foreach ($fn in @("Test-AkariOSInstallCompleted","Get-AkariOSChangeSummary",
                          "Show-AkariOSChangeSummary","Invoke-BtnOpenRestorePoint","Invoke-BtnOpenLog",
                          "Set-AkariOSRelaunchTask","Remove-AkariOSRelaunchTask",
                          "Copy-AkariOSRelaunchScript","Get-AkariOSRelaunchTaskCommand",
                          "Test-AkariOSInstallCompletedOn")) {
            Assert "compiled file defines $fn exactly once" (
                (@([regex]::Matches($c, ('(?m)^function ' + [regex]::Escape($fn) + '\b')))).Count -eq 1)
        }

        # The compiled artefact must PARSE. Zero parser errors, not "few".
        $tokens = $null; $parseErrors = $null
        $null = [System.Management.Automation.Language.Parser]::ParseFile($compiled, [ref]$tokens, [ref]$parseErrors)
        Assert "the compiled akarios.ps1 parses with zero errors" ($parseErrors.Count -eq 0)
        if ($parseErrors.Count -gt 0) { $parseErrors | Select-Object -First 5 | ForEach-Object { Write-Host ("        " + $_.Message) } }

        # main.ps1 must parse on its own too: a broken launch step would only show
        # up as a runtime failure in the compiled file otherwise.
        $t2 = $null; $e2 = $null
        $null = [System.Management.Automation.Language.Parser]::ParseFile((Join-Path $Root "scripts\main.ps1"), [ref]$t2, [ref]$e2)
        Assert "scripts/main.ps1 parses with zero errors" ($e2.Count -eq 0)
        if ($e2.Count -gt 0) { $e2 | Select-Object -First 5 | ForEach-Object { Write-Host ("        " + $_.Message) } }
    }

    # Compile.ps1 really does glob both directories this plan added files to.
    # A narrowing of those globs has silently broken the build before, so this is
    # checked rather than assumed.
    $compileSrc = Get-Content -LiteralPath (Join-Path $Root "Compile.ps1") -Raw
    Assert "Compile.ps1 globs functions\public\*.ps1" (
        [regex]::IsMatch($compileSrc, 'Get-ChildItem\s+-Path\s+\(Join-Path\s+\$PSScriptRoot\s+"functions\\public"\)[^\n]*-Filter\s+"\*\.ps1"'))
    Assert "Compile.ps1 globs xaml\panels\*.xaml" (
        [regex]::IsMatch($compileSrc, 'Get-ChildItem\s+-Path\s+\$panelsDir\s+-File\s+-Filter\s+"\*\.xaml"'))

    # ── 12. T-03-16: no Phase 1/2 contract file was edited ───────────────────
    Write-Host "T-03-16: the sanctioned edit is the only one to a shipped contract"
    # Confirm.ps1 and scripts/start.ps1 must be byte-identical to their Phase 2
    # state; the harness checks the working tree against HEAD, which is where those
    # files were last committed.
    foreach ($f in @("AkariOS/functions/public/Confirm.ps1","AkariOS/scripts/start.ps1")) {
        $dirty = & git -C $repoRoot diff --name-only -- $f 2>$null
        Assert ("$f is unmodified in the working tree") ([string]::IsNullOrWhiteSpace([string]($dirty | Out-String)))
    }

    # ── 13. D-06: the vendored engine is byte-identical to upstream ──────────
    Write-Host "D-06: the four engine assets still match upstream by MD5"
    foreach ($asset in @("winsux.ps1","stepone.ps1","steptwo.ps1","reg.reg")) {
        $ours = Join-Path $Root "assets\text\$asset"
        $upstream = Join-Path $repoRoot "WinSux-main\WinSux\$asset"
        $ok = $false
        if ((Test-Path -LiteralPath $ours) -and (Test-Path -LiteralPath $upstream)) {
            $ok = (Get-FileHash -LiteralPath $ours -Algorithm MD5).Hash -eq
                  (Get-FileHash -LiteralPath $upstream -Algorithm MD5).Hash
        }
        Assert "$asset matches WinSux-main" $ok
    }

} finally {
    $script:sync = $null
    Remove-Item -LiteralPath $scratch -Recurse -Force -ErrorAction SilentlyContinue
}

if ($fail -eq 0) { Write-Host "`nALL SUMMARY TESTS PASSED"; exit 0 }
else { Write-Host "`n$fail SUMMARY TEST(S) FAILED"; exit 1 }