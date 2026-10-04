# -- Completion check and the DIAG-04 "what changed" summary --------------------
#
# After Stage 3 the relaunch task (Relaunch.ps1, D-13) brings the GUI back by
# itself. The first launch that sees a COMPLETED install shows what the install
# actually did, and only then deletes the task (D-17).
#
# TWO RULES SHAPE EVERYTHING IN THIS FILE, AND BOTH EXIST BECAUSE THE NAIVE
# VERSION OF THIS SCREEN LIES:
#
#   D-16  Completion is read off the ONE predicate, not restated. Get-ResumePoint
#         already decided "Status -eq completed AND CurrentStage -ge 3" at
#         Resume.ps1:122; this file calls that same helper rather than keeping a
#         second copy of the rule that can drift. The helper itself lives in
#         Resume.ps1, next to the rule it belongs to.
#
#   D-21  Nothing is reported as applied without LOG EVIDENCE. The catalog below
#         is static data describing what the read-only engine is KNOWN to do, but
#         AkariOS cannot introspect a running stage (D-09), so the only honest
#         signal is what install.log actually says. An item whose Evidence string
#         is absent from the bounded log tail comes back "not-confirmed", never
#         "applied". With an empty log nothing at all is applied - which is the
#         correct and safe direction to fail in.
#
# Every outside-world call sits behind an injectable seam whose default is the
# real call: -StatePath, -LogPath, -LogCount, -ShellInvoker (V7). No test in this
# repository creates a task, writes a registry key, opens System Protection or
# launches explorer.exe; Test-Summary.ps1 injects a stub for every one of them.
#
# The catalog was derived ONCE by reading WinSux-main/WinSux/{stepone,steptwo}.ps1
# and reg.reg, then hard-coded here. It is never parsed out of the engine at run
# time: the engine is a runtime payload, not a dependency of this file.

# Bounded read. The same rule DIAG-02 follows: the whole log is never read, so a
# 40 MB install.log cannot stall the launch path.
$script:AkariOSSummaryLogCount = 400

# Every known log line for a stage's engine child is prefixed "Stage {0} ...", so
# a completion or failure is matched against that token rather than the bare word
# "completed". The ERROR form is the one written by Invoke-AkariOSStage's
# OnComplete ("Stage {0} FAILED: {1}").
$script:AkariOSSummaryStageErrorPattern = '\[ERROR\s*\].*\bStage\s{0}\b'

# ── DIAG-04 catalog (static data) ─────────────────────────────────────────────
#
# Each record is:
#   Group                 Removed | Disabled | Applied
#   Text                  what the item is, in the user's language
#   Stage                 which engine stage performs it (1-3)
#   Evidence              the install.log substring that corroborates it, or $null
#   StageScoped           the match must ALSO name this item's stage number
#   RequiresLogEvidence   $false only for items reported from the ENGINE's own
#                         behaviour, which AkariOS never writes a log line for
#
# THE HONEST PART, stated plainly: AkariOS supervises one child process per stage
# and the engine writes nothing back to install.log (D-09). So the ONLY thing the
# log can corroborate is "stage N ran to completion" - not which of stage 3's
# hundred changes actually landed. Rather than invent a per-item signal that does
# not exist, the three headline items carry the stage-completion evidence and every
# other item is reported as an engine-behaviour claim that AkariOS did not
# personally verify. tools/Test-Summary.ps1 asserts this shape mechanically: an
# Evidence value must be a literal substring of a log message AkariOS really
# writes, or the record must carry RequiresLogEvidence = $false.
$script:AkariOSChangeCatalog = @(
    # ── Removed ──────────────────────────────────────────────────────────────
    [ordered]@{
        Group = "Removed"; Stage = 3; StageScoped = $true; RequiresLogEvidence = $true
        Text  = "Microsoft Edge - browser, WebView2 runtime and the legacy package"
        Evidence = "engine process completed"
    },
    [ordered]@{
        Group = "Removed"; Stage = 3; StageScoped = $false; RequiresLogEvidence = $false
        Text  = "Store apps and provisioned UWP packages"
    },
    [ordered]@{
        Group = "Removed"; Stage = 3; StageScoped = $false; RequiresLogEvidence = $false
        Text  = "Windows capabilities and optional features"
    },
    [ordered]@{
        Group = "Removed"; Stage = 3; StageScoped = $false; RequiresLogEvidence = $false
        Text  = "Legacy apps - brlapi, GameInput, OneDrive, Remote Desktop, Snipping Tool"
    },

    # ── Disabled ─────────────────────────────────────────────────────────────
    [ordered]@{
        Group = "Disabled"; Stage = 2; StageScoped = $true; RequiresLogEvidence = $true
        Text  = "Microsoft Defender and its scheduled scan tasks"
        Evidence = "engine process completed"
    },
    [ordered]@{
        Group = "Disabled"; Stage = 3; StageScoped = $false; RequiresLogEvidence = $false
        Text  = "User Account Control"
    },
    [ordered]@{
        Group = "Disabled"; Stage = 3; StageScoped = $false; RequiresLogEvidence = $false
        Text  = "Memory integrity (Core isolation)"
    },
    [ordered]@{
        Group = "Disabled"; Stage = 3; StageScoped = $false; RequiresLogEvidence = $false
        Text  = "Virtualization Based Security and Hyper-V"
    },
    [ordered]@{
        Group = "Disabled"; Stage = 3; StageScoped = $false; RequiresLogEvidence = $false
        Text  = "The vulnerable-driver blocklist"
    },
    [ordered]@{
        Group = "Disabled"; Stage = 3; StageScoped = $false; RequiresLogEvidence = $false
        Text  = "Windows Update policy keys from reg.reg"
    },

    # ── Applied ──────────────────────────────────────────────────────────────
    [ordered]@{
        Group = "Applied"; Stage = 3; StageScoped = $false; RequiresLogEvidence = $false
        Text  = "Registry import - reg.reg (1494 lines)"
    },
    [ordered]@{
        Group = "Applied"; Stage = 3; StageScoped = $false; RequiresLogEvidence = $false
        Text  = "Ultimate power plan (duplicated GUID, ~100 powercfg values)"
    },
    [ordered]@{
        Group = "Applied"; Stage = 3; StageScoped = $false; RequiresLogEvidence = $false
        Text  = "Set Timer Resolution service"
    },
    [ordered]@{
        Group = "Applied"; Stage = 3; StageScoped = $false; RequiresLogEvidence = $false
        Text  = "Start menu layout - start2.bin on Windows 11, XML on Windows 10"
    },
    [ordered]@{
        Group = "Applied"; Stage = 3; StageScoped = $false; RequiresLogEvidence = $false
        Text  = "Context-menu cleanup"
    },
    [ordered]@{
        Group = "Applied"; Stage = 3; StageScoped = $false; RequiresLogEvidence = $false
        Text  = "Per-device power, wake and write-cache settings"
    },
    [ordered]@{
        Group = "Applied"; Stage = 3; StageScoped = $false; RequiresLogEvidence = $false
        Text  = "Disk cleanup"
    }
)

function Test-AkariOSInstallCompleted {
    <#
    .SYNOPSIS
        The completion gate (D-16): has this install finished all three stages?
    .DESCRIPTION
        Deliberately an INDEPENDENT check, exactly like Get-AkariOSStageFailure:
        Get-ResumePoint answers "where is the machine", this answers "is it done",
        and no new ResumePoint value or resume-switch case is introduced (D-22).
        Get-ResumePoint's decision table stays byte-identical.

        The rule itself is NOT restated here. Test-AkariOSInstallCompletedOn in
        Resume.ps1 owns it, and Get-ResumePoint's own $stateDone line calls the
        same helper - one rule, one place, one test. Restating it would be the
        drift this plan exists to avoid.

        Never throws: a missing or corrupt state file is NOT completed, because
        Get-AkariOSState validates and falls back to pending/stage 0.
    .PARAMETER StatePath
        state.json location. Defaults to the house constant; override for tests.
    #>
    [CmdletBinding()]
    param([string]$StatePath = $script:AkariOSStateDefaultPath)

    $exists = Test-Path -LiteralPath $StatePath
    $state = Get-AkariOSState -Path $StatePath

    $completed = [bool](Test-AkariOSInstallCompletedOn -State $state)

    $reason = if (-not $exists) {
        ("No install state file at {0} - nothing has been installed yet." -f $StatePath)
    } elseif ($completed) {
        ("All three stages completed (state status '{0}', stage {1})." -f [string]$state.Status, [int]$state.CurrentStage)
    } elseif ([string]$state.Status -eq "completed") {
        ("State says 'completed' but only stage {0} of 3 is recorded - the install did not finish." -f [int]$state.CurrentStage)
    } else {
        ("Install is not complete: status '{0}', stage {1} of 3." -f [string]$state.Status, [int]$state.CurrentStage)
    }

    return [pscustomobject]@{
        Completed    = $completed
        Status       = [string]$state.Status
        CurrentStage = [int]$state.CurrentStage
        Reason       = $reason
        StateFound   = [bool]$exists
    }
}

function Test-AkariOSLogEvidence {
    <#
    .SYNOPSIS
        True when a bounded log tail corroborates one catalog item.
    .DESCRIPTION
        PURE: it reads the lines it is handed and never touches the filesystem, so
        the harness can drive the three-state machine directly.

        The match is case-insensitive on the Evidence fragment, and when the record
        is StageScoped the line must ALSO name the record's own stage. That is what
        keeps "Stage 2 completed" from corroborating a Stage 3 item - the whole
        three-state model rests on the two being distinguishable.
    #>
    [CmdletBinding()]
    param(
        [string[]]$Lines = @(),
        [AllowNull()][string]$Evidence,
        [int]$Stage = 0,
        [bool]$StageScoped = $false
    )

    if ([string]::IsNullOrWhiteSpace([string]$Evidence)) { return $false }
    $needle = [regex]::Escape($Evidence)
    foreach ($line in @($Lines)) {
        $text = [string]$line
        if (-not [regex]::IsMatch($text, $needle, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)) { continue }
        if ($StageScoped) {
            if (-not [regex]::IsMatch($text, ('\bStage\s' + $Stage + '\b'), [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)) { continue }
        }
        return $true
    }
    return $false
}

function Get-AkariOSChangeSummary {
    <#
    .SYNOPSIS
        Builds the DIAG-04 "what changed" summary from bounded log evidence (D-21).
    .DESCRIPTION
        Three states per item, and the third one is the point:
          applied       - the item's Evidence matched the log tail
          failed        - an [ERROR] line for the item's stage is in the tail
          not-confirmed - nothing in the tail corroborates it. SAY SO. Claiming
                          "removed" for something the log never mentioned is the
                          failure mode this state exists to prevent.

        The log is read BOUNDED through Get-AkariOSLogTail -Count, never whole: a
        summary that read the entire file would look correct in every other test
        and only misbehave on a real 40 MB log.

        The RestorePoint fields come from the state object's OPTIONAL RestorePoint
        block, which SAFE-01 writes in Wave 2 (Plan 03-02). In this wave it is
        simply absent, so the summary degrades to "no restore point recorded yet"
        and MUST NOT throw - that degradation is asserted, not assumed.
    .PARAMETER StatePath
        state.json location. Override for tests.
    .PARAMETER LogPath
        install.log location. Override for tests.
    .PARAMETER LogCount
        Bound on the log read. The whole file is never read.
    #>
    [CmdletBinding()]
    param(
        [string]$StatePath = $script:AkariOSStateDefaultPath,
        [string]$LogPath   = (Get-AkariOSLogPath),
        [int]$LogCount     = $script:AkariOSSummaryLogCount
    )

    $completion = Test-AkariOSInstallCompleted -StatePath $StatePath
    $state = Get-AkariOSState -Path $StatePath

    $lines = @(Get-AkariOSLogTail -Count $LogCount -Path $LogPath)

    # Which stages logged an ERROR in the tail. Stage N's items are reported as
    # failed, which is DISTINGUISHABLE from not-confirmed in the returned object
    # and on screen - "we saw it fail" and "we have no idea" are different facts.
    $failedStages = New-Object System.Collections.Generic.List[int]
    foreach ($n in 1..3) {
        $pattern = ($script:AkariOSSummaryStageErrorPattern -f $n)
        if (@($lines | Where-Object { [regex]::IsMatch([string]$_, $pattern, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase) }).Count -gt 0) {
            [void]$failedStages.Add($n)
        }
    }

    $items = New-Object System.Collections.ArrayList
    foreach ($record in @($script:AkariOSChangeCatalog)) {
        $stage = [int]$record.Stage
        $requires = [bool]$record.RequiresLogEvidence
        $state3 = if ($failedStages -contains $stage) { "failed" }
                  elseif (-not $requires)   { "not-confirmed" }
                  else {
                      if (Test-AkariOSLogEvidence -Lines $lines -Evidence $record.Evidence -Stage $stage -StageScoped ([bool]$record.StageScoped)) {
                          "applied"
                      } else { "not-confirmed" }
                  }
        [void]$items.Add([pscustomobject]@{
            Group               = [string]$record.Group
            Text                = [string]$record.Text
            Stage               = $stage
            Evidence            = $record.Evidence
            RequiresLogEvidence = $requires
            State               = $state3
        })
    }

    $byGroup = @{}
    foreach ($g in @("Removed", "Disabled", "Applied")) {
        $byGroup[$g] = @($items | Where-Object { $_.Group -eq $g })
    }

    # SAFE-01's optional block. Read DEFENSIVELY: the `Fields` parameter set of
    # Set-AkariOSState rebuilds the object field by field and would drop it, so
    # only the lossless `Object` set ever persists it (T-02-26). Absent is normal.
    $rp = $state.PSObject.Properties["RestorePoint"]
    $rpDescription = ""
    $rpSequence = ""
    $rpCreatedAt = ""
    if ($null -ne $rp -and $null -ne $rp.Value) {
        $v = $rp.Value
        if ($null -ne $v.PSObject.Properties["Description"]) { $rpDescription = [string]$v.Description }
        if ($null -ne $v.PSObject.Properties["Sequence"])    { $rpSequence    = [string]$v.Sequence }
        if ($null -ne $v.PSObject.Properties["CreatedAt"])  { $rpCreatedAt  = [string]$v.CreatedAt }
    }

    $applied       = @($items | Where-Object { $_.State -eq "applied" }).Count
    $notConfirmed  = @($items | Where-Object { $_.State -eq "not-confirmed" }).Count
    $failed        = @($items | Where-Object { $_.State -eq "failed" }).Count

    return [pscustomobject]@{
        Completed    = $completion.Completed
        Status       = $completion.Status
        CurrentStage = $completion.CurrentStage
        Reason       = $completion.Reason
        LogPath      = $LogPath
        LinesRead    = $lines.Count
        LogCount     = $LogCount
        Items        = @($items)
        Groups       = $byGroup
        Applied      = $applied
        NotConfirmed = $notConfirmed
        Failed       = $failed
        Total        = @($items).Count
        FailedStages = @($failedStages)
        RestorePointPresent   = (-not [string]::IsNullOrWhiteSpace($rpDescription))
        RestorePointDescription = $rpDescription
        RestorePointSequence    = $rpSequence
        RestorePointCreatedAt   = $rpCreatedAt
    }
}

function Format-AkariOSChangeGroup {
    <#
    .SYNOPSIS
        Renders one catalog group as plain text for a TextBlock.
    .DESCRIPTION
        Plain text only, never Html or Rtf - the same rule the error card follows
        (T-02-20), so no item text can ever be interpreted as markup. Items are
        prefixed so the three states are visible without a legend: [x] applied,
        [ ] not confirmed, [!] failed.
    #>
    [CmdletBinding()]
    param(
        [string]$Group = "",
        $Summary
    )

    if (-not $Summary) { return "" }
    $items = @($Summary.Groups[$Group])
    if ($items.Count -eq 0) { return "(nothing recorded)" }

    $lines = @()
    foreach ($i in $items) {
        $mark = switch ([string]$i.State) {
            "applied"      { "[x]" }
            "failed"       { "[!]" }
            "not-confirmed"{ "[ ]" }
            default        { "[ ]" }
        }
        $lines += ("{0} {1}" -f $mark, $i.Text)
    }
    return ($lines -join [Environment]::NewLine)
}

function Show-AkariOSChangeSummary {
    <#
    .SYNOPSIS
        Fills the summary panel from a Get-AkariOSChangeSummary result.
    .DESCRIPTION
        Marshalling copies Reveal-StageError exactly: $sync is captured into a
        LOCAL, a [System.Action] is built, and the dispatcher is CheckAccess()ed
        before BeginInvoke - a blocking Invoke from a worker while the UI thread
        waits on it deadlocks. With no window at all (a harness) the action is run
        directly, which is why this function is drivable without WPF.

        Every control write is guarded by a name lookup, so a build whose panel
        failed to splice degrades to a no-op instead of throwing mid-launch.

        The log path shown is the REAL one from Get-AkariOSLogPath (or the injected
        -LogPath), never a hardcoded literal: a link that points somewhere the log
        is not is worse than no link.
    .PARAMETER Summary
        The object Get-AkariOSChangeSummary returned.
    .PARAMETER LogPath
        Path shown to the user. Defaults to the summary's own LogPath.
    #>
    [CmdletBinding()]
    param(
        $Summary,
        [string]$LogPath
    )

    if (-not $LogPath) {
        if ($Summary -and $Summary.LogPath) { $LogPath = [string]$Summary.LogPath }
        else { $LogPath = Get-AkariOSLogPath }
    }

    $syncRef = $sync
    if (-not ($syncRef -and $syncRef.SummaryHeadline)) { return }

    $work = [System.Action]{
        if ($syncRef.SummaryHeadline) {
            $syncRef.SummaryHeadline.Text = if ($Summary -and $Summary.Completed) {
                ("AkariOS is installed. {0} of {1} changes are confirmed from install.log." -f
                    [int]$Summary.Applied, [int]$Summary.Total)
            } elseif ($Summary) {
                ("Install is not complete. {0}" -f [string]$Summary.Reason)
            } else {
                "No summary data."
            }
        }
        foreach ($pair in @(
            @("SummaryRemoved",  "Removed"),
            @("SummaryDisabled", "Disabled"),
            @("SummaryApplied",  "Applied"))) {
            $ctl = $syncRef[$pair[0]]
            if ($ctl) { $ctl.Text = (Format-AkariOSChangeGroup -Group $pair[1] -Summary $Summary) }
        }
        if ($syncRef.SummaryRestorePoint) {
            $syncRef.SummaryRestorePoint.Text = if ($Summary -and $Summary.RestorePointPresent) {
                ("Restore point: {0}" -f [string]$Summary.RestorePointDescription)
            } else {
                "No restore point recorded yet - open System Protection to create one."
            }
        }
        if ($syncRef.SummaryLogLink) {
            $syncRef.SummaryLogLink.Text = ("Install log: {0}" -f [string]$LogPath)
        }
        # Deliberately does NOT set PanelSummary.Visibility here. Show-Panel owns
        # panel visibility in this app, and touching [System.Windows.Visibility]
        # from this function would make it fail hard whenever PresentationFramework
        # is not loaded yet - which is exactly the case Test-Summary.ps1 drives it
        # in. The caller's Show-Panel call reveals the panel; this function only
        # fills it.
    }.GetNewClosure()

    if ($syncRef.window) {
        $d = $syncRef.window.Dispatcher
        if ($d.CheckAccess()) { $work.Invoke() }
        else { $d.BeginInvoke([System.Windows.Threading.DispatcherPriority]::Background, $work) | Out-Null }
    } else {
        $work.Invoke()
    }
}

function Invoke-AkariOSShellOpenDefault {
    <#
    .SYNOPSIS
        The REAL shell-launch path used by the two summary actions.
    .DESCRIPTION
        Reachable only as the -ShellInvoker default. Receives an executable name and
        an argument string, both built from FIXED names - no user input reaches
        either argument beyond the log path, which is AkariOS's own state file.
        Never throws: a failed launch is a WARN, because a dead "open the log"
        button must not take down the app that is already showing the summary.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$FilePath,
        [string]$Arguments = ""
    )

    $argv = if ([string]::IsNullOrWhiteSpace([string]$Arguments)) { @() } else { @($Arguments) }
    if ($argv.Count -eq 0) {
        Start-Process -FilePath $FilePath | Out-Null
    } else {
        Start-Process -FilePath $FilePath -ArgumentList $argv | Out-Null
    }
    return $true
}

function Invoke-BtnOpenRestorePoint {
    <#
    .SYNOPSIS
        BtnOpenRestorePoint handler: open the System Protection property sheet.
    .DESCRIPTION
        SystemPropertiesProtection.exe is the page where a restore point is actually
        chosen and restored - the correct target for "link to the restore point".
        No registry read, no registry write, no WMI, and no attempt to RESTORE
        anything: this opens a window and the user decides.

        Wired by name from main.ps1's Get-Command "Invoke-$btnName" convention, so
        the function name and the button name must match exactly - a typo is a
        silently dead button, the Phase 1 bug.

        Null-invoker fallback as in Invoke-AkariOSEngine (T-02-32): a caller that
        binds -ShellInvoker $null must reach the real launcher rather than
        "& $null", which would launch nothing while reporting success.
    .PARAMETER ShellInvoker
        Overrides the process launch. Receives $FilePath and $Arguments.
    #>
    [CmdletBinding()]
    param([scriptblock]$ShellInvoker)

    if (-not $ShellInvoker) {
        $ShellInvoker = {
            param($FilePath, $Arguments)
            Invoke-AkariOSShellOpenDefault -FilePath $FilePath -Arguments $Arguments
        }
    }

    try {
        & $ShellInvoker "SystemPropertiesProtection.exe" "" | Out-Null
    } catch {
        Write-AkariOSLog -Level WARN -Message ("Could not open System Protection ({0})." -f $_.Exception.Message)
        return $false
    }

    Write-AkariOSLog -Level INFO -Message "Opened System Protection from the change summary."
    return $true
}

function Invoke-BtnOpenLog {
    <#
    .SYNOPSIS
        BtnOpenLog handler: open Explorer with install.log selected.
    .DESCRIPTION
        /select, is the honest link to a log file: it opens the folder AND selects
        the file, which is what the user wants to do with it. The path is quoted,
        because %ProgramData% contains no spaces today and the next machine's
        ProgramData might.

        No registry read or write, same as the restore-point action. Same
        null-invoker fallback (T-02-32).
    .PARAMETER LogPath
        Log file to select. Defaults to the real install.log path.
    .PARAMETER ShellInvoker
        Overrides the process launch. Receives $FilePath and $Arguments.
    #>
    [CmdletBinding()]
    param(
        [string]$LogPath = (Get-AkariOSLogPath),
        [scriptblock]$ShellInvoker
    )

    if (-not $ShellInvoker) {
        $ShellInvoker = {
            param($FilePath, $Arguments)
            Invoke-AkariOSShellOpenDefault -FilePath $FilePath -Arguments $Arguments
        }
    }

    # NOT named $args: that is an automatic variable, and assigning it inside a
    # function with unbound positional parameters silently rewrites the argument
    # array rather than a local.
    $target = if ([string]::IsNullOrWhiteSpace([string]$LogPath)) { Get-AkariOSLogPath } else { $LogPath }
    $selectArg = '/select,"{0}"' -f $target

    try {
        & $ShellInvoker "explorer.exe" $selectArg | Out-Null
    } catch {
        Write-AkariOSLog -Level WARN -Message ("Could not open the install log folder ({0}). The log is at {1}." -f $_.Exception.Message, $target)
        return $false
    }

    Write-AkariOSLog -Level INFO -Message ("Opened the install log folder from the change summary ({0})." -f $target)
    return $true
}