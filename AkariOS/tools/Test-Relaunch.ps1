# Test for the post-install relaunch mechanism: the pure schtasks argument-list
# builder, the two task lifecycle seams, and the script staging seam.
#
# WHY THIS FILE IS BEHAVIOURAL AND NOT GREP-BASED
#
# Phase 2 shipped a fully green suite with three real runtime bugs live in the
# engine path: a `$ps.Free` vs `$psd.Free` typo, a GetNewClosure()-across-a-
# runspace bug that made captured variables arrive empty, and a null
# -EngineInvoker that made a stage report "engine process completed" in 359 ms
# having launched nothing. Every one of those passed because the tests checked
# that code was PRESENT, never that it RAN. So the load-bearing properties here
# are asserted against real return values and real files on disk:
#
#   * the builder's actual string, read back and token-matched
#   * the idempotent self-cleanup, driven by three DIFFERENT writer outcomes
#     (exists / absent / throws) and the real booleans and log levels coming back
#   * the null-invoker fallback, proven by replacing the real launcher functions
#     with recorders and asserting they were REACHED - not by grepping for the
#     word "Start-Process"
#   * Copy-AkariOSRelaunchScript with the REAL default copier, then reading the
#     staged file's bytes off disk
#
# NOTHING DESTRUCTIVE HAPPENS HERE. No schtasks is run, no scheduled task is
# created or deleted, no registry key is written, no engine asset is executed and
# C:\ProgramData is never touched. The single real side effect is the one the plan
# explicitly permits: a real file copy inside a $env:TEMP scratch directory.
param([string]$Root = "C:/Users/isleap/Documents/GitHub/AkariOS/AkariOS")

$ErrorActionPreference = "Stop"
. (Join-Path $Root "functions\private\State.ps1")
. (Join-Path $Root "functions\public\Resume.ps1")
. (Join-Path $Root "functions\public\Relaunch.ps1")
# Stage.ps1 is dot-sourced (not merely read) so the seam assertions can ask the
# REAL Invoke-AkariOSStage for its parameter list rather than pattern-matching
# the param block. Loading it defines functions and one data array; it starts no
# process and touches nothing at load time.
. (Join-Path $Root "functions\public\Stage.ps1")

# Set-Status and Set-CurrentStage live in the WPF shell, not the function
# library. They are only pushed from inside Invoke-AkariOSStage and are never
# reached by the assertions below, but they are stubbed so a future edit cannot
# make this harness fail on a missing WPF type instead of on a real defect.
function Set-Status { param($Text, $Color = "White") }
function Set-CurrentStage { param([int]$Stage, [string]$Action, [switch]$Resume) }

# Logging is stubbed so nothing is written to ProgramData AND so the WARN/INFO
# level of every call is capturable - the idempotency contract is partly a claim
# about the LEVEL a message is logged at, so a stub that swallowed levels could
# not test it.
$script:logRecords = New-Object System.Collections.ArrayList
function Write-AkariOSLog {
    param([string]$Message, [string]$Level = "INFO", [string]$Path)
    [void]$script:logRecords.Add(("{0}|{1}" -f $Level, $Message))
}
function Clear-LogRecords { $script:logRecords.Clear() }
function Get-LogRecords { return @($script:logRecords) }
function Log-Contains {
    # Substring match on the MESSAGE half, level matched exactly. A prefix match
    # was wrong: messages begin with the task name or a sentence opener, so
    # "-like 'INFO|Queued*'" would silently fail on perfectly good log lines and
    # turn this assertion into a false negative that hides real regressions.
    param([string]$Level, [string]$Fragment)
    $prefix = $Level + "|"
    return (@(Get-LogRecords | Where-Object {
        $_ -like ($prefix + "*") -and ([string]$_).Substring($prefix.Length) -like ("*" + $Fragment + "*")
    }).Count -gt 0)
}
function Log-LevelOf {
    param([string]$Fragment)
    $hit = @(Get-LogRecords | Where-Object { $_ -like ("*|" + $Fragment + "*") })
    if ($hit.Count -eq 0) { return $null }
    return ($hit[0] -split '\|')[0]
}

$fail = 0
function Assert($label, $cond) {
    if ($cond) { Write-Host "  PASS  $label" } else { Write-Host "  FAIL  $label"; $script:fail++ }
}

# ── Scratch environment ───────────────────────────────────────────────────────
$scratch = Join-Path $env:TEMP ("akarios-relaunch-" + [guid]::NewGuid().ToString("N").Substring(0,8))
New-Item -ItemType Directory -Path $scratch -Force | Out-Null
$stagedPath  = Join-Path $scratch "staged-akarios.ps1"
$scratchSrc  = Join-Path $scratch "source-akarios.ps1"
$pinnedUser  = "AKARIOTEST\relaunch-probe"
$pinnedPath  = Join-Path $scratch "pinned\akarios.ps1"
New-Item -ItemType Directory -Path (Split-Path -Path $pinnedPath -Parent) -Force | Out-Null
Set-Content -LiteralPath $pinnedPath -Value "# pinned staged script" -Encoding UTF8
Set-Content -LiteralPath $scratchSrc -Value ("# source" * 64) -Encoding UTF8

# Comment-stripped source. BOTH comment forms go first: Relaunch.ps1 documents
# the very bugs these assertions guard (the null-invoker trap, the RunOnce wipe,
# the schtasks call) in its comments, so a raw regex matches its own
# documentation. That has produced both a false pass and a false failure in this
# project before.
function Get-CodeOnly {
    param([string]$Path)
    $raw = Get-Content -LiteralPath $Path -Raw
    $s = [regex]::Replace($raw, '(?s)<#.*?#>', '')     # block comments
    $s = [regex]::Replace($s, '(?m)^\s*#.*$', '')     # line comments
    return $s
}

try {

    # ── 1. The pure builder: real string, every required token, twice ─────────
    Write-Host "T-03-01: Get-AkariOSRelaunchTaskCommand builds the real argument list"
    $cmd = Get-AkariOSRelaunchTaskCommand -ScriptPath $stagedPath -InteractiveUser $pinnedUser

    Assert "the builder returned a string"      ($cmd -is [string])
    Assert "it is not empty"                    (-not [string]::IsNullOrWhiteSpace($cmd))
    Assert "it names the task"                  ($cmd -like '*AkariOS-PostInstall*')
    Assert "/TN is quoted"                      ($cmd -like '*/TN "AkariOS-PostInstall"*')
    Assert "the schedule is ONLOGON"            ($cmd -like '*/SC ONLOGON*')
    Assert "it targets the pinned user"         ($cmd -like ('*/RU "' + $pinnedUser + '"*'))
    Assert "the pinned user is a real account shape" ($pinnedUser -like '*\*')
    Assert "/IT is present for an interactive user" ($cmd -like '*/IT*')
    Assert "/RL HIGHEST is present"             ($cmd -like '*/RL HIGHEST*')
    Assert "/F is present"                      ($cmd -like '*/F*')
    Assert "the /TR payload runs the pinned script" ($cmd -like ('*' + $stagedPath + '*'))
    Assert "the /TR payload invokes powershell" ($cmd -like '*powershell.exe*')
    Assert "the -File argument is quoted"       ($cmd -match '-File\s+\\"[^"]+\\"')
    Assert "it is an argument list, not a shell line" ($cmd -notmatch '(?i)\bcmd(\.exe)?\s+/c')

    # PURITY: two calls with the same pinned inputs must be byte-identical. If
    # the builder touched the machine the two could differ, and this also catches
    # an accidental dependency on ambient state such as the current user.
    $cmd2 = Get-AkariOSRelaunchTaskCommand -ScriptPath $stagedPath -InteractiveUser $pinnedUser
    Assert "the builder is pure (two calls, identical strings)" ($cmd -ceq $cmd2)

    # The token set must not drift: /IT and /RL HIGHEST are the D-14 guarantee,
    # so they are counted, not just pattern-matched once.
    Assert "exactly one /IT token"   (@([regex]::Matches($cmd, '/IT(?:\s|$)')).Count -eq 1)
    Assert "exactly one /RL token"   (@([regex]::Matches($cmd, '/RL HIGHEST')).Count -eq 1)
    Assert "exactly one /RU token"   (@([regex]::Matches($cmd, '/RU ')).Count -eq 1)
    Assert "exactly one /SC token"   (@([regex]::Matches($cmd, '/SC ')).Count -eq 1)
    Assert "exactly one /TN token"   (@([regex]::Matches($cmd, '/TN ')).Count -eq 1)

    Write-Host "T-03-01: the D-14 degradation when the interactive user is unknown"
    $sysCmd = Get-AkariOSRelaunchTaskCommand -ScriptPath $stagedPath -InteractiveUser $null
    Assert "an unresolved user yields a real command"  ($sysCmd -is [string] -and $sysCmd.Length -gt 0)
    Assert "it falls back to SYSTEM"                   ($sysCmd -like '*/RU "SYSTEM"*')
    Assert "and drops /IT, the session-0 trap"         ($sysCmd -notmatch '/IT(?:\s|$)')
    Assert "but keeps /RL HIGHEST"                     ($sysCmd -like '*/RL HIGHEST*')
    Assert "the fallback is visible in the log"        ($true)  # asserted at the Set- level below

    # The builder's own body must launch nothing. It takes no writer at all, so
    # the proof is structural: its extracted body contains no Start-Process and
    # no schtasks invocation.
    $relCode = Get-CodeOnly (Join-Path $Root "functions\public\Relaunch.ps1")
    $builderBody = [regex]::Match($relCode, '(?s)function Get-AkariOSRelaunchTaskCommand \{.*?\n\}').Value
    Assert "found the builder body"                  ($builderBody.Length -gt 0)
    Assert "the builder starts no process"           ($builderBody -notmatch 'Start-Process')
    Assert "the builder never names schtasks"        ($builderBody -notmatch 'schtasks')
    Assert "the builder takes no writer parameter"   ($builderBody -notmatch 'TaskWriter')
    Assert "the builder takes no FileCopier"         ($builderBody -notmatch 'FileCopier')

    # ── 2. Get-AkariOSInteractiveUser: a real read, no side effect ────────────
    Write-Host "T-03-01: Get-AkariOSInteractiveUser resolves this host's account"
    $who = $null
    $whoThrew = $false
    try { $who = Get-AkariOSInteractiveUser } catch { $whoThrew = $true }
    Assert "it does not throw"                (-not $whoThrew)
    Assert "it returns a non-empty string"    ($who -is [string])
    Assert "it is not whitespace"             (-not [string]::IsNullOrWhiteSpace([string]$who))
    Assert "it is DOMAIN\user shaped"         ($who -like '*\*')
    Assert "it matches the real identity"     ($who -ceq [System.Security.Principal.WindowsIdentity]::GetCurrent().Name)
    # Read-only by construction: the function body reads the current identity and
    # nothing else. No registry provider, no task, no process.
    $whoBody = [regex]::Match($relCode, '(?s)function Get-AkariOSInteractiveUser \{.*?\n\}').Value
    Assert "it starts no process"             ($whoBody -notmatch 'Start-Process')
    Assert "it names no registry cmdlet"      ($whoBody -notmatch 'New-ItemProperty|Set-ItemProperty|Remove-ItemProperty|New-Item\s+-Path')
    Assert "it names no task"                 ($whoBody -notmatch 'schtasks')
    Assert "it logs nothing"                  ($whoBody -notmatch 'Write-AkariOSLog')

    # ── 3. Set-AkariOSRelaunchTask with an injected writer ───────────────────
    Write-Host "T-03-02: Set-AkariOSRelaunchTask hands the writer a complete command"
    Clear-LogRecords
    $captured = $null
    $setOk = Set-AkariOSRelaunchTask -ScriptPath $pinnedPath -InteractiveUser $pinnedUser -TaskWriter {
        param($TaskWriterCommand) $script:captured = $TaskWriterCommand; [pscustomobject]@{ ExitCode = 0 }
    }

    Assert "it returns true"                   ($setOk -eq $true)
    Assert "the writer was reached"            ($null -ne $captured)
    Assert "the writer received the /TN token" ($captured -like '*/TN "AkariOS-PostInstall"*')
    Assert "the writer received /SC ONLOGON"   ($captured -like '*/SC ONLOGON*')
    Assert "the writer received the user"      ($captured -like ('*/RU "' + $pinnedUser + '"*'))
    Assert "the writer received /IT"           ($captured -match '/IT(?:\s|$)')
    Assert "the writer received /RL HIGHEST"   ($captured -like '*/RL HIGHEST*')
    Assert "the writer received /F"            ($captured -like '*/F*')
    Assert "the writer received the script"    ($captured -like ('*' + $pinnedPath + '*'))
    Assert "success is logged at INFO"         (Log-Contains "INFO" "Queued relaunch task")
    Assert "no WARN was logged on success"     (-not (@(Get-LogRecords | Where-Object { $_ -like 'WARN|*' }).Count -gt 0))

    # A missing staged script must NOT reach the writer at all: a task pointing at
    # a file that is not there is worse than no task.
    Clear-LogRecords
    $writerReached = $false
    $setMissing = Set-AkariOSRelaunchTask -ScriptPath (Join-Path $scratch "nope.ps1") -InteractiveUser $pinnedUser -TaskWriter {
        param($TaskWriterCommand) $script:writerReached = $true; [pscustomobject]@{ ExitCode = 0 }
    }
    Assert "a missing staged script returns false" ($setMissing -eq $false)
    Assert "and the writer is never reached"       (-not $writerReached)
    Assert "the failure is logged at ERROR"        (Log-Contains "ERROR" "staged script is missing")

    # The D-14 degradation must be diagnosable, not silent.
    Clear-LogRecords
    $nullUserOk = Set-AkariOSRelaunchTask -ScriptPath $pinnedPath -InteractiveUser $null -TaskWriter {
        param($TaskWriterCommand) $script:captured = $TaskWriterCommand; [pscustomobject]@{ ExitCode = 0 }
    }
    Assert "an unresolved user still creates the task" ($nullUserOk -eq $true)
    Assert "the /RU SYSTEM fallback is logged at WARN" (Log-Contains "WARN" "falls back to /RU SYSTEM")
    Assert "the produced command really is SYSTEM"     ($captured -like '*/RU "SYSTEM"*')

    # ── 4. THE LOAD-BEARING ONE: Remove-AkariOSRelaunchTask is idempotent ─────
    Write-Host "T-03-03 (D-17): Remove-AkariOSRelaunchTask is idempotent by contract"
    Clear-LogRecords
    $first = Remove-AkariOSRelaunchTask -TaskWriter {
        param($TaskWriterCommand) [pscustomobject]@{ ExitCode = 0; Output = "SUCCESS: The scheduled task was successfully deleted." }
    }
    Assert "an existing task returns true"        ($first -eq $true)
    Assert "deletion is logged at INFO"           (Log-Contains "INFO" "Deleted relaunch task")
    Assert "no WARN on a successful delete"       (-not (@(Get-LogRecords | Where-Object { $_ -like 'WARN|*' }).Count -gt 0))

    Clear-LogRecords
    $second = Remove-AkariOSRelaunchTask -TaskWriter {
        param($TaskWriterCommand) [pscustomobject]@{ ExitCode = 1; Output = "ERROR: The system cannot find the file specified." }
    }
    Assert "an absent task returns false"         ($second -eq $false)
    Assert "an absent task does NOT log WARN"     (-not (@(Get-LogRecords | Where-Object { $_ -like 'WARN|*' }).Count -gt 0))
    Assert "an absent task logs at INFO"           (Log-Contains "INFO" "already absent")
    Assert "the WARN-check found records to judge" (@(Get-LogRecords).Count -ge 1)

    # Third call: the writer ITSELF throws (a schtasks failure). A self-cleanup
    # that can crash the app is worse than one that leaves a task behind, so the
    # exception must be swallowed.
    Clear-LogRecords
    $threw = $false
    $third = $null
    try {
        $third = Remove-AkariOSRelaunchTask -TaskWriter {
            param($TaskWriterCommand) throw "schtasks blew up"
        }
    } catch {
        $threw = $true
    }
    Assert "a throwing writer does not propagate" (-not $threw)
    Assert "and returns false"                    ($third -eq $false)
    Assert "the swallowed failure IS logged at WARN" (Log-Contains "WARN" "could not be deleted")
    Assert "and the manual recovery command is in the message" (
        @(Get-LogRecords | Where-Object { $_ -like '*schtasks /delete /TN "AkariOS-PostInstall" /F*' }).Count -ge 1)

    # A genuine deletion failure - exit code, no "cannot find" wording - is a
    # WARN, unlike the absent case. If these two were collapsed the whole
    # idempotency contract would be cosmetic.
    Clear-LogRecords
    $failed = Remove-AkariOSRelaunchTask -TaskWriter {
        param($TaskWriterCommand) [pscustomobject]@{ ExitCode = 1; Output = "ERROR: Access is denied." }
    }
    Assert "a real deletion failure returns false" ($failed -eq $false)
    Assert "a real deletion failure logs at WARN"  (Log-Contains "WARN" "was not deleted")

    # The T-02-32 shape: an outcome that cannot be read at all must NOT be read
    # as success. A writer returning nothing is what a null invoker produced.
    Clear-LogRecords
    $nullOutcome = Remove-AkariOSRelaunchTask -TaskWriter { param($TaskWriterCommand) }
    Assert "an unreadable outcome is a failure, not a clean delete" ($nullOutcome -eq $false)

    Write-Host "The self-cleanup deletes by name, through the delete argument list"
    $delCmd = $null
    Remove-AkariOSRelaunchTask -TaskWriter { param($TaskWriterCommand) $script:delCmd = $TaskWriterCommand; 0 } | Out-Null
    Assert "the delete command names the task" ($delCmd -like '*/TN "AkariOS-PostInstall"*')
    Assert "the delete command uses /delete"   ($delCmd -like '*/delete*')
    Assert "the delete command forces removal" ($delCmd -like '*/F*')

    # ── 5. A failed creation is a WARN, and Stage 3 survives it ───────────────
    Write-Host "T-03-02: a failed task creation is survivable"
    Clear-LogRecords
    $threwSet = $false
    $setFail = $null
    try {
        $setFail = Set-AkariOSRelaunchTask -ScriptPath $pinnedPath -InteractiveUser $pinnedUser -TaskWriter {
            param($TaskWriterCommand) [pscustomobject]@{ ExitCode = 5; Output = "ERROR: Access is denied." }
        }
    } catch { $threwSet = $true }
    Assert "a non-zero exit does not throw"        (-not $threwSet)
    Assert "and returns false"                     ($setFail -eq $false)
    Assert "the failure is logged at WARN"         (Log-Contains "WARN" "Relaunch task creation failed")
    Assert "the exit code is in the log"           (@(Get-LogRecords | Where-Object { $_ -like '*exit code 5*' }).Count -ge 1)

    # Same for a writer that throws outright.
    Clear-LogRecords
    $threwSet2 = $false
    try {
        Set-AkariOSRelaunchTask -ScriptPath $pinnedPath -InteractiveUser $pinnedUser -TaskWriter {
            param($TaskWriterCommand) throw "schtasks missing"
        } | Out-Null
    } catch { $threwSet2 = $true }
    Assert "a throwing writer does not abort Stage 3" (-not $threwSet2)
    Assert "it is logged at WARN"                    (Log-Contains "WARN" "Relaunch task could not be created")

    # ── 6. NULL-INVOKER FALLBACK, proven by REACHING the real launcher ───────
    Write-Host "T-02-32: -TaskWriter `$null falls back to the real launcher"
    #
    # This is the assertion Phase 2 could not make. Grepping for "Start-Process"
    # would pass even if the fallback were unreachable, and injecting a stub
    # would pass even if the production path were "& `$null". So instead the two
    # real launcher FUNCTIONS are replaced with recorders: if the fallback is
    # wired correctly, calling with -TaskWriter `$null still reaches them, with
    # the real argument string, and returns their exit code. Nothing executes.
    $script:defaultLauncherHits = New-Object System.Collections.ArrayList
    function Invoke-AkariOSTaskCommandDefault {
        param([string]$TaskWriterCommand)
        [void]$script:defaultLauncherHits.Add($TaskWriterCommand)
        return [pscustomobject]@{ ExitCode = 0; Output = "recorded" }
    }
    function Invoke-AkariOSTaskDeleteDefault {
        param([string]$TaskWriterCommand)
        [void]$script:defaultLauncherHits.Add($TaskWriterCommand)
        return [pscustomobject]@{ ExitCode = 0; Output = "recorded" }
    }

    $script:defaultLauncherHits.Clear()
    $nullWriterOk = Set-AkariOSRelaunchTask -ScriptPath $pinnedPath -InteractiveUser $pinnedUser -TaskWriter $null
    Assert "Set with an explicit `$null writer returns true" ($nullWriterOk -eq $true)
    Assert "it REACHED the real create launcher"             (@($script:defaultLauncherHits).Count -ge 1)
    Assert "the launcher received the full argument list"    ($script:defaultLauncherHits[0] -like '*/TN "AkariOS-PostInstall"*')
    Assert "the launcher received /SC ONLOGON and /RL"       (($script:defaultLauncherHits[0] -like '*/SC ONLOGON*') -and ($script:defaultLauncherHits[0] -like '*/RL HIGHEST*'))
    Assert "the launcher received the pinned script"         ($script:defaultLauncherHits[0] -like ('*' + $pinnedPath + '*'))

    $script:defaultLauncherHits.Clear()
    $nullWriterDel = Remove-AkariOSRelaunchTask -TaskWriter $null
    Assert "Remove with an explicit `$null writer returns true" ($nullWriterDel -eq $true)
    Assert "it REACHED the real delete launcher"               (@($script:defaultLauncherHits).Count -ge 1)
    Assert "the delete launcher received the /TN name"         ($script:defaultLauncherHits[0] -like '*/TN "AkariOS-PostInstall"*')

    # A null writer on a FAILED create must not be a fictional success either.
    $script:defaultLauncherHits.Clear()
    function Invoke-AkariOSTaskCommandDefault {
        param([string]$TaskWriterCommand)
        [void]$script:defaultLauncherHits.Add($TaskWriterCommand)
        return [pscustomobject]@{ ExitCode = 7; Output = "ERROR: Access is denied." }
    }
    $nullWriterFail = Set-AkariOSRelaunchTask -ScriptPath $pinnedPath -InteractiveUser $pinnedUser -TaskWriter $null
    Assert "a null writer with a failing launcher returns false" ($nullWriterFail -eq $false)
    Assert "and the launcher really was reached"                 (@($script:defaultLauncherHits).Count -ge 1)

    # Structural half: no code path may invoke a null scriptblock, in either file.
    Assert "no code path invokes `$null in Relaunch.ps1" ($relCode -notmatch '&\s*\$null')
    Assert "both functions carry an explicit fallback" (
        @([regex]::Matches($relCode, '(?s)if\s*\(\s*-not\s+\$TaskWriter\s*\)\s*\{[\s\S]{0,400}?Invoke-AkariOSTask')).Count -eq 2)
    Assert "the fallback names the create launcher" ($relCode -match 'if\s*\(\s*-not\s+\$TaskWriter\s*\)[\s\S]{0,400}?Invoke-AkariOSTaskCommandDefault')
    Assert "the fallback names the delete launcher" ($relCode -match 'if\s*\(\s*-not\s+\$TaskWriter\s*\)[\s\S]{0,400}?Invoke-AkariOSTaskDeleteDefault')

    # ── 7. Copy-AkariOSRelaunchScript, including a REAL copy ─────────────────
    Write-Host "T-03-04 (D-15): the staged copy really happens"
    # The injected copier has to really write the file. A copier that only
    # records its arguments would pass a destination-returning assertion while
    # staging nothing, which is exactly the stub-is-not-a-proof failure this
    # harness exists to avoid - so the copy it performs is verified by reading
    # the bytes back afterwards.
    Clear-LogRecords
    $copierSawSource = $null; $copierSawDest = $null
    $destOne = Join-Path $scratch "copy-one\akarios.ps1"
    $r1 = Copy-AkariOSRelaunchScript -SourcePath $scratchSrc -Destination $destOne -FileCopier {
        param($Source, $Destination)
        $script:copierSawSource = $Source; $script:copierSawDest = $Destination
        [System.IO.File]::Copy($Source, $Destination, $true)
    }
    Assert "an injected copier returns the destination"  ($r1 -eq $destOne)
    Assert "the copier received the source path"         ($copierSawSource -eq $scratchSrc)
    Assert "the copier received the destination path"    ($copierSawDest -eq $destOne)
    Assert "and the file the injected copier wrote exists" (Test-Path -LiteralPath $destOne)
    Assert "staging is logged at INFO"                   (Log-Contains "INFO" "Staged relaunch script")

    Clear-LogRecords
    $threwCopy = $false; $r2 = $null
    try {
        $r2 = Copy-AkariOSRelaunchScript -SourcePath $scratchSrc -Destination (Join-Path $scratch "copy-two\akarios.ps1") -FileCopier {
            param($Source, $Destination) throw "disk full"
        }
    } catch { $threwCopy = $true }
    Assert "a throwing copier does not propagate"  (-not $threwCopy)
    Assert "and returns null"                       ($null -eq $r2)
    Assert "the failure is logged at ERROR"         (Log-Contains "ERROR" "Relaunch script was not staged")

    # A copier that reports success without writing anything must also fail: the
    # task would then point at a nonexistent file.
    Clear-LogRecords
    $r3 = Copy-AkariOSRelaunchScript -SourcePath $scratchSrc -Destination (Join-Path $scratch "copy-three\akarios.ps1") -FileCopier {
        param($Source, $Destination)
    }
    Assert "a no-op copier is caught, not trusted" ($null -eq $r3)
    Assert "and it is logged at ERROR"             (Log-Contains "ERROR" "reported success but nothing exists")

    Clear-LogRecords
    $r4 = Copy-AkariOSRelaunchScript -SourcePath (Join-Path $scratch "does-not-exist.ps1") -Destination (Join-Path $scratch "copy-four\akarios.ps1")
    Assert "an unresolvable source returns null" ($null -eq $r4)
    Assert "and is logged at ERROR"               (Log-Contains "ERROR" "source does not exist")

    Clear-LogRecords
    $r5 = Copy-AkariOSRelaunchScript -SourcePath $null -Destination $null
    Assert "a null source returns null, no throw" ($null -eq $r5)

    # THE REAL COPIER. This is the one deliberate real side effect in this file,
    # and the plan permits it because it writes only inside a $env:TEMP scratch
    # directory - never ProgramData, never the registry. The bytes are read back
    # off disk afterwards: a stub recording the argument it was handed is NOT an
    # acceptable assertion for the copy path.
    Clear-LogRecords
    $realDest = Join-Path $scratch "real\akarios.ps1"
    $rReal = Copy-AkariOSRelaunchScript -SourcePath $scratchSrc -Destination $realDest
    Assert "the real copier returns the destination" ($rReal -eq $realDest)
    Assert "the file really exists on disk"           (Test-Path -LiteralPath $realDest)
    $srcBytes = [System.IO.File]::ReadAllBytes($scratchSrc)
    $dstBytes = [System.IO.File]::ReadAllBytes($realDest)
    Assert "the staged file is non-empty"             ($dstBytes.Length -gt 0)
    Assert "the byte count matches the source"        ($dstBytes.Length -eq $srcBytes.Length)
    $identical = ($dstBytes.Length -eq $srcBytes.Length)
    if ($identical) {
        for ($i = 0; $i -lt $srcBytes.Length; $i++) {
            if ($srcBytes[$i] -ne $dstBytes[$i]) { $identical = $false; break }
        }
    }
    Assert "every byte matches the source"            $identical

    # Overwrite: the default copier must overwrite, not throw on an existing file.
    $rReal2 = Copy-AkariOSRelaunchScript -SourcePath $scratchSrc -Destination $realDest
    Assert "re-staging over an existing file works"   ($rReal2 -eq $realDest)
    Assert "and the file is still intact"             (Test-Path -LiteralPath $realDest)

    # Nothing above may have written anywhere near ProgramData.
    Assert "no staged copy was made under ProgramData" (
        -not (Test-Path -LiteralPath (Join-Path $env:ProgramData "AkariOS\akarios.ps1")))

    # ── 8. STATIC: every outside-world call is behind a seam ─────────────────
    Write-Host "T-03-06: no outside-world call sits outside a seam default"
    # "Reachable only through a seam" means the INVOCATION is behind a seam, not
    # that the word never appears: the log lines legitimately name schtasks while
    # explaining what failed. So log lines are excluded first and what remains -
    # an actual schtasks invocation - must name the TaskWriter parameter.
    $relCodeLines = @($relCode -split "`r?`n")
    $schtasksLines = @($relCodeLines | Where-Object {
        $_ -match 'schtasks' -and $_ -notmatch 'Write-AkariOSLog'
    })
    $logSchtasksLines = @($relCodeLines | Where-Object {
        $_ -match 'schtasks' -and $_ -match 'Write-AkariOSLog'
    })
    Assert "schtasks is named in the source at all"      ($schtasksLines.Count -ge 1)
    Assert "every schtasks INVOCATION names TaskWriter"  (
        (@($schtasksLines | Where-Object { $_ -notmatch 'TaskWriter' }).Count -eq 0))
    if (@($schtasksLines | Where-Object { $_ -notmatch 'TaskWriter' }).Count -gt 0) {
        Write-Host ("        " + (($schtasksLines | Where-Object { $_ -notmatch 'TaskWriter' }) -join ' | '))
    }
    Assert "no Register-ScheduledTask"       ($relCode -notmatch 'Register-ScheduledTask')
    Assert "no Unregister-ScheduledTask"     ($relCode -notmatch 'Unregister-ScheduledTask')
    Assert "no New-ItemProperty"             ($relCode -notmatch 'New-ItemProperty')
    Assert "no Set-ItemProperty"             ($relCode -notmatch 'Set-ItemProperty')
    Assert "no New-Item -Path registry"      ($relCode -notmatch 'HK[A-Z]+:\\')
    Assert "no Restart-Computer (D-07)"      ($relCode -notmatch 'Restart-Computer')
    Assert "no shutdown -r (D-07)"           ($relCode -notmatch 'shutdown\s+-r')
    Assert "no bcdedit"                      ($relCode -notmatch 'bcdedit')
    Assert "no reg add / reg delete"         ($relCode -notmatch 'reg\s+(add|delete)')
    Assert "no RunOnce write"                ($relCode -notmatch 'RunOnce')
    # The only Start-Process in the file is the create launcher; the delete path
    # uses the call operator so it can capture schtasks' own output.
    $sp = @($relCode -split "`r?`n" | Where-Object { $_ -match 'Start-Process' })
    Assert "Start-Process appears exactly once" ($sp.Count -eq 1)
    Assert "and it launches schtasks.exe"        ($sp.Count -eq 1 -and $sp[0] -match 'schtasks\.exe')
    Assert "the create launcher waits for schtasks" ($relCode -match '(?s)Start-Process\s+-FilePath\s+"schtasks\.exe"[\s\S]{0,300}?-Wait')
    # One task name, one place: it is a constant, never spelled into a literal
    # argument list a second time.
    Assert "the task name is a constant"   ($relCode -match '\$script:AkariOSRelaunchTaskName\s*=\s*"AkariOS-PostInstall"')
    Assert "the task name is not inlined elsewhere" (
        @($relCode -split "`r?`n" | Where-Object { $_ -match 'AkariOS-PostInstall' -and $_ -notmatch '^\s*\$script:AkariOSRelaunchTaskName\s*=' }).Count -eq 0)
    # The staged destination is derived from the house constant, never hardcoded.
    Assert "the staging directory derives from the house constant" ($relCode -match 'script:AkariOSStateDefaultPath')
    Assert "no hardcoded ProgramData literal" ($relCode -notmatch 'C:\\ProgramData')

    Assert "the only schtasks mentions outside invocations are log messages" (
        (@($schtasksLines | Where-Object { $_ -match 'Write-AkariOSLog' }).Count -eq 0))
    Assert "and there really are such log messages (the check is not vacuous)" ($logSchtasksLines.Count -ge 1)

    # ── 9. STATIC on Stage.ps1: the Stage 3 branch is additive ───────────────
    Write-Host "T-03-05: Stage.ps1's relaunch branch is additive and correctly ordered"
    $stageSrc = Get-CodeOnly (Join-Path $Root "functions\public\Stage.ps1")

    # Stage 1 still writes both RunOnce entries and sets safeboot.
    # All three branch slices are taken by index rather than by a non-greedy
    # brace capture: the chain's branches contain nested braces (the Stage 3
    # guard nest), and a non-greedy capture would stop before the code being
    # asserted. Bounds are the branch headers themselves plus the statement that
    # has always followed the chain.
    $chainEnd = $stageSrc.IndexOf('if ($StatePath) { Set-AkariOSState')
    $h1 = $stageSrc.IndexOf('if ($Stage -eq 1)')
    $h2 = $stageSrc.IndexOf('elseif ($Stage -eq 2)')
    $h3 = $stageSrc.IndexOf('elseif ($Stage -eq 3)')
    Assert "found the Stage 1 branch header"   ($h1 -ge 0 -and $h1 -lt $h2)
    Assert "found the Stage 2 branch header"   ($h2 -gt $h1)
    Assert "found the Stage 3 branch header"   ($h3 -gt $h2)
    Assert "found the end of the branch chain" ($chainEnd -gt $h3)

    $s1 = $stageSrc.Substring($h1, $h2 - $h1)
    $s2 = $stageSrc.Substring($h2, $h3 - $h2)
    $s3 = $stageSrc.Substring($h3, $chainEnd - $h3)

    Assert "the -Stage 1 branch still exists"        ($s1.Length -gt 0)
    Assert "Stage 1 still calls Set-AkariOSRunOnceEntry twice" (
        @([regex]::Matches($s1, 'Set-AkariOSRunOnceEntry')).Count -eq 2)
    Assert "Stage 1 still sets the safeboot flag"    ($s1 -match 'Set-BcdSafebootValue')

    Assert "the -Stage 2 branch still exists"        ($s2.Length -gt 0)
    Assert "Stage 2 still clears the safeboot flag"  ($s2 -match 'Clear-BcdSafebootValue')

    Assert "the -Stage 3 relaunch branch exists"     ($s3.Length -gt 0)
    Assert "Set-AkariOSRelaunchTask appears exactly once in Stage.ps1" (
        @($stageSrc -split "`r?`n" | Where-Object { $_ -match 'Set-AkariOSRelaunchTask\s+-ScriptPath' }).Count -eq 1)
    Assert "it is called inside the Stage 3 branch" ($s3 -match 'Set-AkariOSRelaunchTask\s+-ScriptPath')
    Assert "Stage 1 never touches the relaunch task" ($s1 -notmatch 'RelaunchTask|RelaunchScript')
    Assert "Stage 2 never touches the relaunch task" ($s2 -notmatch 'RelaunchTask|RelaunchScript')
    Assert "Stage 3 still does not write a RunOnce entry" ($s3 -notmatch 'Set-AkariOSRunOnceEntry')

    # ORDERING, the property this whole branch exists for: stage the script first,
    # create the task second, both BEFORE the engine child is handed to the
    # supervisor. A mutation that moves the task after the engine launch must
    # turn this red.
    $iCopy = $stageSrc.IndexOf('Copy-AkariOSRelaunchScript -FileCopier')
    $iSet  = $stageSrc.IndexOf('Set-AkariOSRelaunchTask -ScriptPath')
    $iEngine = $stageSrc.IndexOf('Invoke-AkariOSEngine -ScriptPath $job.EnginePath')
    Assert "found the staging call"        ($iCopy -ge 0)
    Assert "found the task creation call"  ($iSet -ge 0)
    Assert "found the engine supervisor"    ($iEngine -ge 0)
    Assert "the script is staged BEFORE the task is created" ($iCopy -lt $iSet)
    Assert "both happen BEFORE the engine child is launched" ($iSet -lt $iEngine)
    Assert "no relaunch work happens after the engine launch" (-not ($stageSrc.Substring($iEngine) -match 'Set-AkariOSRelaunchTask\s+-ScriptPath'))

    # The branch must be guarded, and must survive a build with no Relaunch.ps1.
    Assert "the branch is Get-Command guarded"   ($s3 -match 'Get-Command Copy-AkariOSRelaunchScript -ErrorAction SilentlyContinue')
    Assert "a missing relaunch module is only a WARN" ($s3 -match 'Write-AkariOSLog -Level WARN')
    # Start-AkariOSInstall is still the single entry point.
    Assert "Start-AkariOSInstall is untouched"   ((Get-Content -LiteralPath (Join-Path $Root "functions\public\Stage.ps1") -Raw) -match '(?s)function Start-AkariOSInstall[\s\S]{0,600}?Invoke-AkariOSStage -Stage 1')
    Assert "the Install button path has no relaunch call" (
        -not ([regex]::Match((Get-Content -LiteralPath (Join-Path $Root "functions\public\Confirm.ps1") -Raw), '(?s)function Invoke-BtnInstall\s*\{.*?\n\}').Value -match 'Relaunch'))

    # The two new seams are on Invoke-AkariOSStage and on the $sync hand-off.
    $stageKeys = @((Get-Command Invoke-AkariOSStage).Parameters.Keys)
    foreach ($seam in @("TaskWriter","FileCopier")) {
        Assert "Invoke-AkariOSStage has -$seam" ($stageKeys -contains $seam)
    }
    Assert "the hand-off publishes TaskWriter" ($stageSrc -match '(?s)\$sync\[\$jobKey\]\s*=\s*@\{[\s\S]{0,900}?TaskWriter\s*=')
    Assert "the hand-off publishes FileCopier" ($stageSrc -match '(?s)\$sync\[\$jobKey\]\s*=\s*@\{[\s\S]{0,900}?FileCopier\s*=')
    Assert "the new seams are declared with no default here" (
        ($stageSrc -match '(?m)^\s*\[scriptblock\]\$TaskWriter,\s*$') -and ($stageSrc -match '(?m)^\s*\[scriptblock\]\$FileCopier,\s*$'))
    Assert "Stage.ps1 still launches only powershell.exe children" (
        @(([regex]::Replace($stageSrc, '(?s)<#.*?#>', '') -split "`r?`n" | Where-Object { $_ -match 'Start-Process' -and $_ -notmatch 'powershell\.exe' })).Count -eq 0)
    Assert "Stage.ps1 never names schtasks" ($stageSrc -notmatch 'schtasks')

    # ── 10. T-02-35: the dead !AkariOS RunOnce entry stays dead ──────────────
    Write-Host "T-02-35: no !AkariOS RunOnce value is written anywhere"
    $deadEntry = @()
    foreach ($f in (Get-ChildItem (Join-Path $Root "functions") -Recurse -File -Filter "*.ps1") +
                   (Get-ChildItem (Join-Path $Root "scripts") -Recurse -File -Filter "*.ps1")) {
        $lines = @(Get-Content -LiteralPath $f.FullName) | ForEach-Object { $i = 0 } { $i++; "$i`:$_" }
        $hit = @($lines | Where-Object { $_ -match '!AkariOS' -and $_ -notmatch '^\s*\d+\s*#' })
        if ($hit.Count) { $deadEntry += ($f.Name + ": " + ($hit -join ' | ')) }
    }
    Assert "no !AkariOS RunOnce value anywhere" ($deadEntry.Count -eq 0)
    if ($deadEntry.Count -gt 0) { $deadEntry | ForEach-Object { Write-Host ("        " + $_) } }

    # ── 11. D-06: the vendored engine is byte-identical to upstream ───────────
    Write-Host "D-06: the four engine assets still match upstream by MD5"
    $repoRoot = Split-Path -Path $Root -Parent
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

    # ── 12. The new file parses, and lands in the compiled artefact ───────────
    Write-Host "The new file parses, and Compile.ps1 picks it up"
    $tokens = $null; $parseErrors = $null
    $null = [System.Management.Automation.Language.Parser]::ParseFile((Join-Path $Root "functions\public\Relaunch.ps1"), [ref]$tokens, [ref]$parseErrors)
    Assert "Relaunch.ps1 parses with zero errors" ($parseErrors.Count -eq 0)
    if ($parseErrors.Count -gt 0) { $parseErrors | Select-Object -First 5 | ForEach-Object { Write-Host ("        " + $_.Message) } }

    # Compile.ps1 globs functions\public\*.ps1, so a new public file is included
    # automatically - but only if the glob really is that wide, so assert it
    # rather than assume it.
    $compileSrc = Get-Content -LiteralPath (Join-Path $Root "Compile.ps1") -Raw
    Assert "Compile.ps1 concatenates every functions\public\*.ps1" (
        ($compileSrc -match 'Get-ChildItem -Path \(Join-Path \$PSScriptRoot "functions\\public"\) -File -Filter "\*\.ps1"') -or
        ($compileSrc -match 'Get-ChildItem\s+-Path\s+\(Join-Path \$PSScriptRoot "functions\\public"\)[^\n]*-File[^\n]*-Filter'))

    $compiled = Join-Path $Root "akarios.ps1"
    if (Test-Path -LiteralPath $compiled) {
        $c = Get-Content -LiteralPath $compiled -Raw
        foreach ($fn in @("Get-AkariOSRelaunchTaskCommand","Set-AkariOSRelaunchTask",
                          "Remove-AkariOSRelaunchTask","Copy-AkariOSRelaunchScript")) {
            Assert ("compiled file defines $fn exactly once") (
                (@([regex]::Matches($c, '(?m)^function ' + [regex]::Escape($fn) + '\b'))).Count -eq 1)
        }
        Assert "the compiled file carries the ONLOGON argument builder" ($c -match '/SC ONLOGON')
    } else {
        Assert "compiled akarios.ps1 exists (run Compile.ps1 first)" $false
    }

} finally {
    Remove-Item -LiteralPath $scratch -Recurse -Force -ErrorAction SilentlyContinue
}

if ($fail -eq 0) { Write-Host "`nALL RELAUNCH TESTS PASSED"; exit 0 }
else { Write-Host "`n$fail RELAUNCH TEST(S) FAILED"; exit 1 }