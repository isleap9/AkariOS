# Runner: Applies or Reverts Tweaks and returns one Outcome per Tweak
# (Applied, Reverted, Already, Skipped, Failed). The GUI and the CLI share it.

function New-AkariOutcome([string]$Id, [string]$Mode, [string]$Outcome, [bool]$Reboot = $false, [string]$Message = '') {
    [pscustomobject]@{ Id = $Id; Mode = $Mode; Outcome = $Outcome; Reboot = $Reboot; Message = $Message }
}

# $Value: Apply a Choice to this value instead of its Recommended value
function Invoke-AkariTweak($Tweak, [ValidateSet('Apply', 'Revert')][string]$Mode, $Value = $null) {
    if ($null -ne $Value -and $Tweak.Kind -ne 'Choice') {
        Write-Log "Failed: $($Tweak.Name) (Value is only for Choices)"
        return New-AkariOutcome $Tweak.Id $Mode 'Failed' $false 'Value is only for Choices'
    }
    # Requires (Core\System.ps1): a Tweak that makes no sense on this PC is not run either way
    $why = if ($Tweak.Requires) { Test-AkariRequirement $Tweak } else { $null }
    if ($why) {
        Write-Log "Skipped: $($Tweak.Name) ($why)"
        return New-AkariOutcome $Tweak.Id $Mode 'Skipped' $false $why
    }
    if ($Tweak.Kind -eq 'Action' -and $Mode -eq 'Revert') {
        Write-Log "Skipped: $($Tweak.Name) (Action has no Revert)"
        return New-AkariOutcome $Tweak.Id $Mode 'Skipped' $false 'Action has no Revert'
    }
    $want = if ($Mode -eq 'Apply') { 'Optimized' } else { 'Default' }
    # $AkariTweakDir: the tweak file's folder, for files shipped next to it (e.g. Tweaks\Apps\Install\Files); Detect,
    # Apply and Revert blocks all see it
    $AkariTweakDir = if ($Tweak.Source -and (Test-Path -LiteralPath $Tweak.Source)) { Split-Path $Tweak.Source } else { '' }
    if ($null -ne $Value -and $Mode -eq 'Apply') {
        $e = $Tweak.Registry[0]
        $cur = try { Get-AkariRegValue $e.Path $e.Name } catch { $null }
        if ($null -ne $cur -and (Test-AkariRegMatch $cur $Value)) {
            Write-Log "Already: $($Tweak.Name)"
            return New-AkariOutcome $Tweak.Id $Mode 'Already'
        }
    } elseif ($Tweak.Kind -ne 'Action' -and (Get-AkariState $Tweak) -eq $want) {
        Write-Log "Already: $($Tweak.Name)"
        return New-AkariOutcome $Tweak.Id $Mode 'Already'
    } elseif ($Tweak.Kind -eq 'Action' -and $Tweak.Detect -and (& { try { [bool](& ([scriptblock]::Create($Tweak.Detect.ToString()))) } catch { $false } })) {
        # an Action's Detect says it is already done (e.g. the app is already removed)
        Write-Log "Already: $($Tweak.Name)"
        return New-AkariOutcome $Tweak.Id $Mode 'Already'
    }
    try {
        if ($Tweak.Kind -eq 'Choice') {
            $e = $Tweak.Registry[0]
            $v = if ($Mode -eq 'Revert') { Resolve-AkariDefault $Tweak.Default } elseif ($null -ne $Value) { $Value } else { $Tweak.Recommended }
            if ($null -eq $v) { Remove-Reg $e.Path $e.Name } else { Set-Reg $e.Path $e.Name $v $e.Type }
        } elseif ($Tweak.Registry) {
            Invoke-AkariRegistry $Tweak.Registry $Mode
            # a registry Toggle's After: one more step after the values, both ways ($AkariMode = Apply / Revert),
            # e.g. a scheduled task or a database the values need reset
            if ($Tweak.After) {
                $sb = [scriptblock]::Create($Tweak.After.ToString())
                & { $ErrorActionPreference = 'Continue'; $PSDefaultParameterValues = @{ '*:ErrorAction' = 'Stop' }; $AkariMode = $Mode; & $sb } *>&1 |
                    ForEach-Object { if ($_ -is [Management.Automation.ErrorRecord] -and "$($_.FullyQualifiedErrorId)" -like 'NativeCommandError*') { "$($_.Exception.Message)" } else { $_ } } |
                    Out-String -Stream | ForEach-Object { Write-Log $_ }
            }
        } else {
            # rebuilt from text so a block loaded in another runspace never runs in that runspace's session state
            $sb = [scriptblock]::Create($Tweak.$Mode.ToString())
            # cmdlet errors stop the tweak (-ErrorAction Stop by default); a native tool's stderr (reg.exe, powercfg...)
            # is only logged: 5.1 turns it into an error record, and $ErrorActionPreference = 'Stop' would abort on it
            & { $ErrorActionPreference = 'Continue'; $PSDefaultParameterValues = @{ '*:ErrorAction' = 'Stop' }; & $sb } *>&1 |
                ForEach-Object { if ($_ -is [Management.Automation.ErrorRecord] -and "$($_.FullyQualifiedErrorId)" -like 'NativeCommandError*') { "$($_.Exception.Message)" } else { $_ } } |
                Out-String -Stream | ForEach-Object { Write-Log $_ }
        }
    } catch {
        Write-Log "Failed: $($Tweak.Name): $($_.Exception.Message)"
        return New-AkariOutcome $Tweak.Id $Mode 'Failed' $false $_.Exception.Message
    }
    if ($Tweak.Kind -eq 'Toggle' -and -not $Tweak.Detect -and -not $Tweak.Registry) { Set-AkariRememberedState $Tweak.Id ($Mode -eq 'Apply') }
    $done = if ($Mode -eq 'Apply') { 'Applied' } else { 'Reverted' }
    Write-Log "${done}: $($Tweak.Name)"
    New-AkariOutcome $Tweak.Id $Mode $done $Tweak.Reboot
}

# a block that restarts the PC or sets the next boot to Safe Mode (legacy bodies: shutdown /r, Restart-Computer,
# bcdedit ... safeboot minimal): nothing after it in the same Run would get to run
$AkariRestartPattern = '(?im)\bshutdown(\.exe)?\s+(/|-)r\b|\bRestart-Computer\b|\bbcdedit\b[^\r\n]*\bsafeboot\s+(minimal|network)\b'

# $true when running $Tweak in $Mode restarts the PC (or goes into Safe Mode): a block whose text does it (legacy
# bodies, a driver cleaner that restarts). One-file SafeMode Tweaks don't: Core\Phases.ps1 takes them there. Pure.
function Test-AkariRestarts($Tweak, [string]$Mode) {
    # Restarts: an Apply that restarts the PC itself (a driver cleaner run with its own restart switch)
    if ($Tweak.Restarts -and $Mode -eq 'Apply') { return $true }
    $block = if ($Mode -eq 'Revert') { $Tweak.Revert } else { $Tweak.Apply }
    [bool]("$block" -match $AkariRestartPattern)
}

# a Run from a plan: $Items are @{ Id; Mode; Value } (Value optional, Choices only).
# One Outcome per item; a Failed Tweak never stops the Run. Tweaks that restart the PC or go into Safe Mode run last
# (after Explorer's restart), so everything else is done before the PC goes down; the rest keep their order.
# Explorer restarts once when a Tweak with Explorer = $true was Applied or Reverted.
# SafeMode Tweaks outside Safe Mode: once the rest is done, Akari restarts into Safe Mode, runs them there and restarts
# back (Start-AkariPhases); their Outcome says so and needs a restart.
function Invoke-AkariPlan([object[]]$Items, $Tweaks) {
    $explorer = $false
    $now = [System.Collections.Generic.List[object]]::new()
    $last = [System.Collections.Generic.List[object]]::new()
    $safe = [System.Collections.Generic.List[object]]::new()
    # Core\Phases.ps1 (loaded with the Runner everywhere a Run can need Safe Mode)
    $inSafeMode = [bool](Get-Command Test-AkariSafeMode -ErrorAction SilentlyContinue) -and (Test-AkariSafeMode)
    foreach ($i in $Items) {
        $t = $Tweaks | Where-Object { $_.Id -eq $i.Id } | Select-Object -First 1
        if ($t -and $t.SafeMode -and -not $inSafeMode -and -not ($t.Kind -eq 'Action' -and $i.Mode -eq 'Revert') -and -not (Test-AkariRequirement $t) -and ($t.Kind -eq 'Action' -or (Get-AkariState $t) -ne $(if ($i.Mode -eq 'Revert') { 'Default' } else { 'Optimized' }))) { $safe.Add(@{ Item = $i; Tweak = $t }) }
        elseif ($t -and (Test-AkariRestarts $t $i.Mode)) { $last.Add(@{ Item = $i; Tweak = $t }) } else { $now.Add(@{ Item = $i; Tweak = $t }) }
    }
    foreach ($x in $now) {
        $i = $x.Item; $t = $x.Tweak
        if (-not $t) { Write-Log "Failed: $($i.Id) (unknown tweak id)"; New-AkariOutcome $i.Id $i.Mode 'Failed' $false 'Unknown tweak id'; continue }
        $o = Invoke-AkariTweak $t $i.Mode $i.Value
        if ($t.Explorer -and $o.Outcome -in 'Applied', 'Reverted') { $explorer = $true }
        $o
    }
    if ($explorer) { Restart-AkariExplorer }
    # Safe Mode next: it is the restart, so the restarting Tweaks wait for another Run
    if ($safe.Count) {
        foreach ($x in $last) {
            Write-Log "Skipped: $($x.Tweak.Name) (it restarts the PC: select it again after Safe Mode)"
            New-AkariOutcome $x.Tweak.Id $x.Item.Mode 'Skipped' $false 'restarts the PC: run it after Safe Mode'
        }
        foreach ($x in $safe) {
            $verb = if ($x.Item.Mode -eq 'Revert') { 'Reverted' } else { 'Applied' }
            Write-Log "In Safe Mode: $($x.Tweak.Name)"
            New-AkariOutcome $x.Tweak.Id $x.Item.Mode $verb $true 'in Safe Mode, after the restart'
        }
        $run = New-AkariRun 'Safe Mode' @(
            @{ Name = 'Safe Mode'; Boot = 'SafeMode'; Items = @($safe | ForEach-Object { $_.Item }) }
            @{ Name = 'Back to normal'; Boot = 'Normal'; Items = @() }
        )
        [void](Start-AkariPhases $run $Tweaks)
        return
    }
    # only one can run: once it starts the restart, Windows refuses to start anything else ("Access is denied")
    for ($n = 0; $n -lt $last.Count; $n++) {
        $x = $last[$n]
        if ($n -eq 0) {
            Write-Log "Last: $($x.Tweak.Name) (restarts the PC)"
            Invoke-AkariTweak $x.Tweak $x.Item.Mode $x.Item.Value
        } else {
            Write-Log "Skipped: $($x.Tweak.Name) (it restarts the PC too: select it again after this restart)"
            New-AkariOutcome $x.Tweak.Id $x.Item.Mode 'Skipped' $false 'restarts the PC too: run it after this restart'
        }
    }
}

# a Run with one Mode for every id (CLI)
function Invoke-AkariRun([string[]]$Ids, [ValidateSet('Apply', 'Revert')][string]$Mode, $Tweaks) {
    Invoke-AkariPlan @($Ids | ForEach-Object { @{ Id = $_; Mode = $Mode } }) $Tweaks
}

# GUI: runs $Code in a background runspace with Core loaded; log lines go to $Queue.
# $Shared (a synchronized hashtable) is $AkariShared in the job: it hands objects back (Outcomes, States).
# The caller polls Handle.IsCompleted, then calls Ps.EndInvoke and disposes Ps and Rs.
function Start-AkariJob([string]$Code, $Queue, [string]$CoreDir, [hashtable]$Shared = $null) {
    $rs = [runspacefactory]::CreateRunspace()
    $rs.Open()
    $rs.SessionStateProxy.SetVariable('LogQueue', $Queue)
    $rs.SessionStateProxy.SetVariable('AkariShared', $Shared)
    $ps = [powershell]::Create()
    $ps.Runspace = $rs
    $pre = (@('Log', 'Compat', 'Trusted', 'Registry', 'Loader', 'State', 'Runner', 'Legacy', 'Restore', 'Appx', 'Winget', 'AppSetup', 'System', 'Phases') | ForEach-Object { ". '$CoreDir\$_.ps1'" }) -join "`n"
    $wrapped = $pre + "`ntry {`n& {`n" + $Code + "`n} *>&1 | Out-String -Stream | ForEach-Object { if (`$_.Trim()) { Write-Log `$_ } }`n} catch { Write-Log ('Error: ' + `$_.Exception.Message) }"
    [void]$ps.AddScript($wrapped)
    @{ Ps = $ps; Rs = $rs; Handle = $ps.BeginInvoke(); Shared = $Shared }
}
