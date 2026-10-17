# Runner: Applies or Reverts Tweaks and returns one Outcome per Tweak
# (Applied, Reverted, Already, Skipped, Failed). The GUI and the CLI share it.

function New-AkariOutcome([string]$Id, [string]$Mode, [string]$Outcome, [bool]$Reboot = $false, [string]$Message = '') {
    [pscustomobject]@{ Id = $Id; Mode = $Mode; Outcome = $Outcome; Reboot = $Reboot; Message = $Message }
}

function Invoke-AkariTweak($Tweak, [ValidateSet('Apply', 'Revert')][string]$Mode) {
    if ($Tweak.Kind -eq 'Action' -and $Mode -eq 'Revert') {
        Write-Log "Skipped: $($Tweak.Name) (Action has no Revert)"
        return New-AkariOutcome $Tweak.Id $Mode 'Skipped' $false 'Action has no Revert'
    }
    $want = if ($Mode -eq 'Apply') { 'Optimized' } else { 'Default' }
    if ($Tweak.Kind -ne 'Action' -and (Get-AkariState $Tweak) -eq $want) {
        Write-Log "Already: $($Tweak.Name)"
        return New-AkariOutcome $Tweak.Id $Mode 'Already'
    }
    try {
        if ($Tweak.Kind -eq 'Choice') {
            $e = $Tweak.Registry[0]
            $v = if ($Mode -eq 'Apply') { $Tweak.Recommended } else { Resolve-AkariDefault $Tweak.Default }
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

# a Run: one Outcome per id, in order; a Failed Tweak never stops the Run
function Invoke-AkariRun([string[]]$Ids, [ValidateSet('Apply', 'Revert')][string]$Mode, $Tweaks) {
    foreach ($id in $Ids) {
        $t = $Tweaks | Where-Object { $_.Id -eq $id } | Select-Object -First 1
        if (-not $t) { Write-Log "Failed: $id (unknown tweak id)"; New-AkariOutcome $id $Mode 'Failed' $false 'Unknown tweak id'; continue }
        Invoke-AkariTweak $t $Mode
    }
}

# GUI: runs $Code in a background runspace with Core loaded; log lines go to $Queue.
# The caller polls Handle.IsCompleted, then calls Ps.EndInvoke and disposes Ps and Rs.
function Start-AkariJob([string]$Code, $Queue, [string]$CoreDir) {
    $rs = [runspacefactory]::CreateRunspace()
    $rs.Open()
    $rs.SessionStateProxy.SetVariable('LogQueue', $Queue)
    $ps = [powershell]::Create()
    $ps.Runspace = $rs
    $pre = (@('Log', 'Compat', 'Trusted', 'Registry', 'Loader', 'State', 'Runner') | ForEach-Object { ". '$CoreDir\$_.ps1'" }) -join "`n"
    $wrapped = $pre + "`ntry {`n& {`n" + $Code + "`n} *>&1 | Out-String -Stream | ForEach-Object { if (`$_.Trim()) { Write-Log `$_ } }`n} catch { Write-Log ('Error: ' + `$_.Exception.Message) }"
    [void]$ps.AddScript($wrapped)
    @{ Ps = $ps; Rs = $rs; Handle = $ps.BeginInvoke() }
}
