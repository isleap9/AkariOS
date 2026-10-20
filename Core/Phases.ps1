# Phases: a Run in steps across restarts (normal boot / Safe Mode), resumed by RunOnce; Safe Mode on / off, restart.
# No tweak logic. RunOnce value names: a leading * also runs in Safe Mode; a leading ! deletes the value only after the
# command ran. Needs Core/Registry.ps1 (Set-Reg maps HKCU to the logged-in user, whose logon runs RunOnce) and, for
# Start-AkariPhases, Core/Runner.ps1 and Core/Log.ps1.

$AkariRunOnceKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce'
# the AkariOS folder (Akari.ps1): this file is Core\Phases.ps1
$AkariRoot = Split-Path $PSScriptRoot
if (-not $AkariRunPath) { $AkariRunPath = Join-Path $env:ProgramData 'Akari\run.json' }

# the command a RunOnce value runs: Akari.ps1 in a maximized console with $Arguments
function Get-AkariResumeCommand([string]$AkariPath, [string]$Arguments) {
    "powershell.exe -nop -ep bypass -WindowStyle Maximized -File `"$AkariPath`" $Arguments"
}

function Register-AkariResume([string]$Name, [string]$Command, [string]$Key = $AkariRunOnceKey) {
    Set-Reg $Key $Name $Command 'String'
}

# the only place that runs bcdedit; returns its exit code. Tests mock this function (never the native command).
function Invoke-AkariBcdEdit([string]$Arguments) {
    cmd /c "bcdedit $Arguments >nul 2>&1"
    $LASTEXITCODE
}

# throws when bcdedit fails, so a phase never restarts into the wrong mode
function Set-AkariSafeBoot([bool]$On) {
    $a = if ($On) { '/set {current} safeboot minimal' } else { '/deletevalue {current} safeboot' }
    $code = Invoke-AkariBcdEdit $a
    # turning it off when it is already off is fine
    if ($code -and $On) { throw "bcdedit could not turn Safe Mode on (exit code $code)" }
}

function Restart-AkariPC([int]$Seconds = 5) {
    Start-Sleep -Seconds $Seconds
    shutdown -r -t 00
}

# $true while Windows runs in Safe Mode (Windows sets SAFEBOOT_OPTION then)
function Test-AkariSafeMode { [bool]$env:SAFEBOOT_OPTION }

# ---- Runs in phases
# A Run: @{ Name; Sid; Next; Phases = @(@{ Name; Boot = 'Normal' | 'SafeMode'; Items = @(@{ Id; Mode; Value }) });
# Outcomes = @(...) }. Saved to $AkariRunPath between restarts.

function New-AkariRun([string]$Name, $Phases) {
    @{ Name = $Name; Sid = (Get-AkariUserSid); Next = 0; Phases = @($Phases); Outcomes = @() }
}

function Save-AkariRun($Run) {
    New-Item (Split-Path $AkariRunPath) -ItemType Directory -Force | Out-Null
    [IO.File]::WriteAllText($AkariRunPath, ($Run | ConvertTo-Json -Depth 8), [Text.UTF8Encoding]::new($false))
}

# the saved Run as hashtables (Items as @{ Id; Mode; Value }), or $null
function Get-AkariRun {
    if (-not (Test-Path -LiteralPath $AkariRunPath)) { return $null }
    try { $j = Get-Content -LiteralPath $AkariRunPath -Raw | ConvertFrom-Json } catch { return $null }
    $phases = foreach ($p in @($j.Phases)) {
        $items = foreach ($i in @($p.Items | Where-Object { $_ })) {
            $h = @{ Id = [string]$i.Id; Mode = [string]$i.Mode }
            if ($i.PSObject.Properties['Value'] -and $null -ne $i.Value) { $h.Value = $i.Value }
            $h
        }
        @{ Name = [string]$p.Name; Boot = [string]$p.Boot; Items = @($items) }
    }
    $outcomes = @($j.Outcomes | Where-Object { $_ } | ForEach-Object { New-AkariOutcome $_.Id $_.Mode $_.Outcome ([bool]$_.Reboot) ([string]$_.Message) })
    @{ Name = [string]$j.Name; Sid = [string]$j.Sid; Next = [int]$j.Next; Phases = @($phases); Outcomes = $outcomes }
}

function Clear-AkariRun {
    Remove-Item -LiteralPath $AkariRunPath -Force -ErrorAction SilentlyContinue
    foreach ($n in '*!akari-resume', '!akari-resume') { Remove-Reg $AkariRunOnceKey $n }
}

# the next boot is $Boot ('Normal' / 'SafeMode') and Akari resumes the Run then
function Set-AkariNextBoot([string]$Boot, [string]$AkariPath) {
    foreach ($n in '*!akari-resume', '!akari-resume') { Remove-Reg $AkariRunOnceKey $n }
    Set-AkariSafeBoot ($Boot -eq 'SafeMode')
    $name = if ($Boot -eq 'SafeMode') { '*!akari-resume' } else { '!akari-resume' }
    Register-AkariResume $name (Get-AkariResumeCommand $AkariPath '-Resume')
}

# runs the Run from its Next phase; returns 'Done', 'Restarting' or 'Stopped'. A phase whose Boot is not the current
# one restarts the PC into it first. Before a phase that ends in a restart (a Tweak that restarts the PC, or a different
# Boot next), the next boot is set up first, so the restart always lands in the right place. In Safe Mode a Failed
# Tweak stops the Run (Safe Mode is turned off, nothing resumes). A multi-phase Run ends with a restart when a Tweak
# in its last phase needs one. $Tweaks: every Tweak and Entry the Run names.
function Start-AkariPhases($Run, $Tweaks, [string]$AkariPath = "$AkariRoot\Akari.ps1") {
    if ($Run.Sid) { $script:AkariUserSid = $Run.Sid }
    Split-AkariSafeModePhases $Run $Tweaks
    $count = @($Run.Phases).Count
    $find = { param($id) $Tweaks | Where-Object { $_.Id -eq $id } | Select-Object -First 1 }
    $lastOut = @()
    $restartsPC = { param($item) $t = & $find $item.Id; [bool]($t -and (Test-AkariRestarts $t $item.Mode)) }
    for ($i = [int]$Run.Next; $i -lt $count; $i++) {
        $ph = $Run.Phases[$i]
        $safe = Test-AkariSafeMode
        if (($ph.Boot -eq 'SafeMode') -ne $safe) {
            $Run.Next = $i; Save-AkariRun $Run
            Set-AkariNextBoot $ph.Boot $AkariPath
            Write-Log "Restarting into $(if ($ph.Boot -eq 'SafeMode') { 'Safe Mode' } else { 'normal mode' }) for: $($ph.Name)"
            Restart-AkariPC
            return 'Restarting'
        }
        Write-Log "Phase $($i + 1) of ${count}: $($ph.Name)"
        Write-ErrLog "$($Run.Name): phase $($i + 1) of ${count}: $($ph.Name)"
        $next = if ($i + 1 -lt $count) { $Run.Phases[$i + 1] } else { $null }
        $restarts = @($ph.Items | Where-Object { & $restartsPC $_ }).Count -gt 0
        $Run.Next = $i + 1; Save-AkariRun $Run
        # a phase that restarts the PC itself (DDU) sets up the next boot first; otherwise that waits until the phase is done
        if ($next -and $restarts) { Set-AkariNextBoot $next.Boot $AkariPath }
        elseif ($restarts -and $safe) { Set-AkariSafeBoot $false }
        $out = @(Invoke-AkariPlan $ph.Items $Tweaks); $lastOut = $out
        $Run.Outcomes = @($Run.Outcomes) + $out
        foreach ($o in $out) { Write-ErrLog ('{0,-9} {1}  {2}' -f $o.Outcome, $o.Id, $o.Message) }
        Save-AkariRun $Run
        $out
        if ($safe -and @($out | Where-Object { $_.Outcome -eq 'Failed' }).Count) {
            Clear-AkariRun
            try { Set-AkariSafeBoot $false } catch { }
            Write-Log "Stopped in Safe Mode: a change failed (see above). Safe Mode is off again; restart when you are ready."
            return 'Stopped'
        }
        # a Tweak restarted the PC: Windows is going down, the next phase resumes after it
        # (if it could not, e.g. its tool was missing, Akari restarts instead)
        if (@($out | Where-Object { $_.Outcome -in 'Applied', 'Reverted' } | Where-Object { & $restartsPC $_ }).Count) {
            if (-not $next) { Clear-AkariRun }
            Restart-AkariPC
            return 'Restarting'
        }
        if ($next -and ($next.Boot -eq 'SafeMode') -ne $safe) {
            if (-not $restarts) { Set-AkariNextBoot $next.Boot $AkariPath }
            Write-Log "Restarting into $(if ($next.Boot -eq 'SafeMode') { 'Safe Mode' } else { 'normal mode' }) for: $($next.Name)"
            Restart-AkariPC
            return 'Restarting'
        }
    }
    Clear-AkariRun
    if (Test-AkariSafeMode) { Set-AkariSafeBoot $false }
    if ($count -gt 1 -and @($lastOut | Where-Object { $_.Reboot }).Count) {
        Write-AkariRunSummary $Run.Outcomes
        Write-Log 'All phases done. Restarting in 15 seconds to finish.'
        Restart-AkariPC 15
        return 'Restarting'
    }
    'Done'
}

# SafeMode Tweaks in a Normal phase (from Next on) move to a Safe Mode phase of their own right after it, followed by
# a Normal one when nothing comes after, so a phase never needs a Safe Mode detour of its own. One already in its
# target State stays (the Runner reports Already). Changes $Run in place.
function Split-AkariSafeModePhases($Run, $Tweaks) {
    $phases = [System.Collections.Generic.List[object]]::new()
    foreach ($p in @($Run.Phases)) { $phases.Add($p) }
    for ($i = [int]$Run.Next; $i -lt $phases.Count; $i++) {
        $p = $phases[$i]
        if ($p.Boot -eq 'SafeMode') { continue }
        $move = @(foreach ($it in @($p.Items)) {
            $t = $Tweaks | Where-Object { $_.Id -eq $it.Id } | Select-Object -First 1
            if (-not $t -or -not $t.SafeMode -or ($t.Kind -eq 'Action' -and $it.Mode -eq 'Revert') -or ($t.Requires -and (Test-AkariRequirement $t))) { continue }
            if ($t.Kind -ne 'Action' -and (Get-AkariState $t) -eq $(if ($it.Mode -eq 'Revert') { 'Default' } else { 'Optimized' })) { continue }
            $it
        })
        if (-not $move.Count) { continue }
        $p.Items = @($p.Items | Where-Object { $_ -notin $move })
        $phases.Insert($i + 1, @{ Name = "$($p.Name) (Safe Mode part)"; Boot = 'SafeMode'; Items = $move })
        if ($i + 2 -ge $phases.Count) { $phases.Add(@{ Name = 'Back to normal'; Boot = 'Normal'; Items = @() }) }
        $i++
    }
    $Run.Phases = @($phases)
}

# every Tweak a Run names: the loaded ones, plus the data-list Entries (appx/<name>, ...) built from their ids
function Get-AkariRunTweaks($Run, $Loaded) {
    $all = [System.Collections.Generic.List[object]]::new()
    foreach ($t in @($Loaded.Tweaks)) { $all.Add($t) }
    $known = @{}; foreach ($t in $all) { $known[$t.Id] = $true }
    foreach ($p in @($Run.Phases)) {
        foreach ($i in @($p.Items)) {
            if ($known.ContainsKey($i.Id) -or $i.Id -notlike '*/*') { continue }
            $e = Resolve-AkariEntry $Loaded.Groups $i.Id
            if ($e) { $all.Add($e); $known[$i.Id] = $true }
        }
    }
    @($all)
}

# a Run for a preset: its wildcards (appx/*, capability/*, feature/*) become the Entries on this PC now, its phases
# the Run's phases (Get-AkariPresetPhases). -> @{ Run; Tweaks (every Tweak and Entry it can name); Unknown }
function New-AkariPresetRun($Preset, $Loaded, [switch]$Revert) {
    $all = [System.Collections.Generic.List[object]]::new()
    foreach ($t in @($Loaded.Tweaks)) { $all.Add($t) }
    if (@($Preset.Entries | Where-Object { $_.Id -like '*/[*]' }).Count) {
        $known = @{}; foreach ($t in $all) { $known[$t.Id] = $true }
        $names = @(Get-AkariAppxInstalled | ForEach-Object { "appx/$_" }) + @(Get-AkariCapabilitiesInstalled | ForEach-Object { "capability/$_" }) +
            @(Get-AkariFeaturesEnabled | ForEach-Object { "feature/$_" })
        foreach ($id in $names) {
            if ($known.ContainsKey($id)) { continue }
            $e = Resolve-AkariEntry $Loaded.Groups $id
            if ($e) { $all.Add($e); $known[$id] = $true }
        }
    }
    $plan = Resolve-AkariPreset $Preset @($all) -Revert:$Revert
    @{ Run = (New-AkariRun $Preset.Name @(Get-AkariPresetPhases $Preset $plan.Items -Revert:$Revert)); Tweaks = @($all); Unknown = $plan.Unknown }
}

# the end of a Run in Akari's console: how many of each Outcome, then every Failed one with its message
function Write-AkariRunSummary($Outcomes) {
    $o = @($Outcomes | Where-Object { $_ })
    $line = 'Done: ' + ((@('Applied', 'Reverted', 'Already', 'Skipped', 'Failed') | ForEach-Object { $n = $_; $c = @($o | Where-Object { $_.Outcome -eq $n }).Count; if ($c) { "$c $($n.ToLower())" } }) -join ', ')
    Write-Log $line; Write-ErrLog $line
    foreach ($f in @($o | Where-Object { $_.Outcome -eq 'Failed' })) { Write-Log "  Failed: $($f.Id): $($f.Message)" }
}
