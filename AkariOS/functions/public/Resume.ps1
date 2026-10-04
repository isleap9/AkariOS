# ── Resume detection (PROG-02) ──────────────────────────────────────────────
# On launch we must answer one question: where does this install pick up?
#
#   fresh   - nothing pending, start at Stage 1
#   stage1  - Stage 1 was set up but never completed (re-run Stage 1)
#   stage2  - Safe Mode boot pending: the `*!stepone` RunOnce entry fired (D-03)
#   stage3  - normal boot with a `!steptwo` RunOnce entry still pending (D-03)
#   inconsistent - markers disagree (D-05: show "try again", do NOT auto-recover)
#
# D-01: the cross-reboot state IS the registry + bcdedit. state.json only carries
# within-stage progress, so it is used as corroborating evidence, never as the
# sole source of truth.
#
# Every read of the outside world goes through the two wrappers below so this
# logic can be exercised on a VM (or in a test) with stubbed values — nothing
# here writes to the registry or the boot configuration.

$script:AkariOSRunOnceKeys = @(
    "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce",
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce"
)

# The two stage entries AkariOS writes, matching WinSux exactly:
#   `*!` -> runs in Safe Mode, `!` -> defers deletion until the command succeeds
$script:AkariOSStage2Entry = "*!stepone"
$script:AkariOSStage3Entry = "!steptwo"

function Get-BcdSafebootState {
    <#
    .SYNOPSIS
        Returns the current safeboot setting: "minimal", "network", $null (not set)
        or "unknown" if bcdedit could not be read.
    .DESCRIPTION
        READ-ONLY. Never calls `bcdedit /set` or `/deletevalue` — writing the flag
        is the stage runner's job in Phase 2. Kept as a single wrapper so a VM test
        can stub it.
    #>
    [CmdletBinding()]
    param()

    try {
        $out = & bcdedit.exe /enum "{current}" 2>&1 | Out-String
    } catch {
        return "unknown"
    }

    # bcdedit prints "safeboot             minimal" (or "network") when the flag is set.
    if ($out -match '(?im)^\s*safeboot\s+(minimal|network)\s*$') {
        return $Matches[1]
    }
    # "safeboot" with no value, or an unrecognized value, still means the flag is set.
    if ($out -match '(?im)^\s*safeboot\b') { return "set" }
    return $null
}

function Get-AkariOSRunOnceEntries {
    <#
    .SYNOPSIS
        Reads the AkariOS stage entries out of the RunOnce keys. Read-only.
    .DESCRIPTION
        Checks HKCU first (WinSux's hive, and the only one that carries a user
        context), then HKLM. Returns an object with HasStage2/HasStage3 plus the
        raw value names found, for display in the State page.
    #>
    [CmdletBinding()]
    param([string[]]$Keys = $script:AkariOSRunOnceKeys)

    $hasStage2 = $false
    $hasStage3 = $false
    $found     = @()

    foreach ($key in $Keys) {
        if (-not (Test-Path -LiteralPath $key)) { continue }
        try {
            $props = Get-ItemProperty -LiteralPath $key -ErrorAction Stop
        } catch { continue }

        foreach ($prop in $props.PSObject.Properties) {
            if ($prop.Name -like "PS*") { continue }   # PSPath/PSParentPath/etc.
            # `!` defers deletion until success, so a surviving entry means the
            # command either never ran or failed — either way it is still pending.
            $n = $prop.Name
            if ($n -like "*stepone*")      { $hasStage2 = $true; $found += "$key :: $n" }
            elseif ($n -like "*steptwo*")   { $hasStage3 = $true; $found += "$key :: $n" }
        }
    }

    [pscustomobject]@{
        HasStage2  = $hasStage2
        HasStage3  = $hasStage3
        Found      = $found
    }
}

function Get-ResumePoint {
    <#
    .SYNOPSIS
        Decides where the install resumes (PROG-02).
    .PARAMETER Safeboot
        Overrides the bcdedit probe. Pass "minimal"/"network"/$null to test the
        decision table without touching the boot configuration.
    .PARAMETER RunOnce
        Overrides the RunOnce read. Pass the object shape Get-AkariOSRunOnceEntries
        returns.
    .PARAMETER State
        Overrides the state.json read.
    #>
    [CmdletBinding()]
    param(
        [AllowNull()][string]$Safeboot,
        $RunOnce,
        $State
    )

    # Defaults call the real wrappers; any supplied parameter short-circuits them.
    if (-not $PSBoundParameters.ContainsKey("Safeboot")) { $Safeboot = Get-BcdSafebootState }
    if (-not $PSBoundParameters.ContainsKey("RunOnce")) { $RunOnce = Get-AkariOSRunOnceEntries }
    if (-not $PSBoundParameters.ContainsKey("State"))   { $State   = Get-AkariOSState }

    $safe = ($Safeboot -eq "minimal" -or $Safeboot -eq "network" -or $Safeboot -eq "set")
    $runOnceClean = ($null -eq $RunOnce -or (-not $RunOnce.HasStage2 -and -not $RunOnce.HasStage3))
    $stateDone = ($State -and $State.Status -eq "completed" -and $State.CurrentStage -ge 3)

    $point = "fresh"
    $reason = "No RunOnce entries and no safeboot flag — nothing to resume."

    # --- D-03 priority order: Safe Mode first, then RunOnce, then fresh ---
    if ($safe) {
        if ($RunOnce.HasStage3 -and -not $RunOnce.HasStage2) {
            # Safe Mode set but only the stage-3 entry pending: the stage 2 handoff
            # is ambiguous — we cannot know whether Safe Mode was entered by us.
            $point  = "inconsistent"
            $reason = "Safe Mode is set but only the Stage 3 RunOnce entry is pending. AkariOS cannot tell whether Stage 2 completed."
        } else {
            $point  = "stage2"
            $reason = "Safe Mode boot is active — resuming Stage 2."
        }
    }
    elseif ($RunOnce.HasStage3) {
        $point  = "stage3"
        $reason = "Stage 3 RunOnce entry is pending — resuming Stage 3."
    }
    elseif ($RunOnce.HasStage2) {
        $point  = "stage1"
        $reason = "Stage 2 RunOnce entry exists but the machine is not in Safe Mode — Stage 1 never completed."
    }
    elseif ($stateDone) {
        $point  = "fresh"
        $reason = "A completed install is recorded, but the RunOnce entries are gone. Starting fresh."
    }
    elseif (-not $runOnceClean) {
        $point  = "inconsistent"
        $reason = "RunOnce entries are present but unrecognised."
    }

    [pscustomobject]@{
        ResumePoint = $point
        Reason      = $reason
        Safeboot    = $Safeboot
        HasStage2   = [bool]$RunOnce.HasStage2
        HasStage3   = [bool]$RunOnce.HasStage3
        StateStage  = $State.CurrentStage
        StateStatus = $State.Status
        RunOnceKeys = $script:AkariOSRunOnceKeys
    }
}

function Invoke-BtnResume {
    <#
    .SYNOPSIS
        BtnResume handler (PROG-02). Re-runs detection and moves the UI to the
        stage that is actually pending.
    .DESCRIPTION
        Resume here means "take me to the right place", not "run the stage":
        stages 2 and 3 are already queued as RunOnce console scripts and run at
        boot, so there is nothing for the GUI to launch. Stage 1 is the only case
        the GUI can restart, and it goes through the normal confirmation gate.
    #>
    $resume = Get-ResumePoint
    Write-AkariOSLog -Level INFO -Message ("Resume requested: {0}" -f $resume.ResumePoint)

    if ($resume.ResumePoint -eq "inconsistent") {
        [System.Windows.MessageBox]::Show(
            ("The installation is in an inconsistent state. Please try again. " +
             "If the problem persists, check the log at %ProgramData%\AkariOS\install.log."),
            "AkariOS Setup") | Out-Null
        return
    }

    if ($resume.ResumePoint -eq "stage1") {
        # Stage 1 never completed - restart it through the confirmation gate.
        Show-Panel "PanelHome"
        Set-InstallButtonEnabled -Enabled $true -Hint "Resuming Stage 1 - confirm to continue."
        Invoke-BtnInstall
        return
    }

    $stageNo = switch ($resume.ResumePoint) { "stage2" {2} "stage3" {3} default { 0 } }
    if ($stageNo -eq 0) {
        Show-Panel "PanelHome"
        Set-Status "Nothing to resume - starting fresh." "#AAAAAA"
        return
    }

    # Stage 2/3 run as console scripts at boot; show where we are and stop there.
    Set-CurrentStage -Stage $stageNo -Resume
    Set-Status ("Step {0} of 3 is already queued and will run at the next boot. Do not close this window if it is still installing." -f $stageNo) "#FFA726"
}