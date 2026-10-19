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
    if ($Tweak.Kind -eq 'Action' -and $Mode -eq 'Revert') {
        Write-Log "Skipped: $($Tweak.Name) (Action has no Revert)"
        return New-AkariOutcome $Tweak.Id $Mode 'Skipped' $false 'Action has no Revert'
    }
    $want = if ($Mode -eq 'Apply') { 'Optimized' } else { 'Default' }
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
    }
    try {
        if ($Tweak.Kind -eq 'Choice') {
            $e = $Tweak.Registry[0]
            $v = if ($Mode -eq 'Revert') { Resolve-AkariDefault $Tweak.Default } elseif ($null -ne $Value) { $Value } else { $Tweak.Recommended }
            if ($null -eq $v) { Remove-Reg $e.Path $e.Name } else { Set-Reg $e.Path $e.Name $v $e.Type }
        } elseif ($Tweak.Registry) {
            Invoke-AkariRegistry $Tweak.Registry $Mode
        } else {
            # rebuilt from text so a block loaded in another runspace never runs in that runspace's session state
            $sb = [scriptblock]::Create($Tweak.$Mode.ToString())
            & { $ErrorActionPreference = 'Stop'; & $sb } *>&1 | Out-String -Stream | ForEach-Object { Write-Log $_ }
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

# a Run from a plan: $Items are @{ Id; Mode; Value } (Value optional, Choices only).
# One Outcome per item, in order; a Failed Tweak never stops the Run.
function Invoke-AkariPlan([object[]]$Items, $Tweaks) {
    foreach ($i in $Items) {
        $t = $Tweaks | Where-Object { $_.Id -eq $i.Id } | Select-Object -First 1
        if (-not $t) { Write-Log "Failed: $($i.Id) (unknown tweak id)"; New-AkariOutcome $i.Id $i.Mode 'Failed' $false 'Unknown tweak id'; continue }
        Invoke-AkariTweak $t $i.Mode $i.Value
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
    $pre = (@('Log', 'Compat', 'Trusted', 'Registry', 'Loader', 'State', 'Runner', 'Legacy') | ForEach-Object { ". '$CoreDir\$_.ps1'" }) -join "`n"
    $wrapped = $pre + "`ntry {`n& {`n" + $Code + "`n} *>&1 | Out-String -Stream | ForEach-Object { if (`$_.Trim()) { Write-Log `$_ } }`n} catch { Write-Log ('Error: ' + `$_.Exception.Message) }"
    [void]$ps.AddScript($wrapped)
    @{ Ps = $ps; Rs = $rs; Handle = $ps.BeginInvoke(); Shared = $Shared }
}
