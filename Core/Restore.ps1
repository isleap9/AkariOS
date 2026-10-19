# Restore point: created before the first change of a Run (AkariOS-PLAN.md §3).
# If Windows refuses (System Protection off, or one was made in the last 24 hours), turn protection on
# for the system drive, lift the 24 hour throttle for one more try, then put the throttle back.

$AkariRestoreKey = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SystemRestore'

# throws when no restore point was made; the 24 hour throttle only writes a warning, so it counts as a failure
function Invoke-AkariCheckpoint([string]$Description) {
    $w = $null
    Checkpoint-Computer -Description $Description -RestorePointType MODIFY_SETTINGS -ErrorAction Stop -WarningAction SilentlyContinue -WarningVariable w
    if ($w) { throw [string]$w[0] }
}

# the newest restore point Akari made (described AkariOS, or Akari before Oct 2026), or $null:
# @{ Description; Date }. System Restore is only read through this function (tests mock it).
function Get-AkariRestorePoint {
    $p = @(Get-ComputerRestorePoint -ErrorAction SilentlyContinue | Where-Object { $_.Description -like 'Akari*' }) |
        Sort-Object SequenceNumber -Descending | Select-Object -First 1
    if (-not $p) { return $null }
    $date = try { [Management.ManagementDateTimeConverter]::ToDateTime($p.CreationTime) } catch { $null }
    [pscustomobject]@{ Description = $p.Description; Date = $date }
}

# never throws: returns @{ Ok; Message }
function New-AkariRestorePoint([string]$Description = 'AkariOS') {
    try {
        Invoke-AkariCheckpoint $Description
        Write-Log 'Restore point created'
        return [pscustomobject]@{ Ok = $true; Message = '' }
    } catch { Write-Log "Restore point: $($_.Exception.Message) Trying again with System Protection on." }
    $name = 'SystemRestorePointCreationFrequency'
    $old = try { Get-AkariRegValue $AkariRestoreKey $name } catch { $null }
    try {
        Enable-ComputerRestore -Drive "$env:SystemDrive\" -ErrorAction Stop
        Set-Reg $AkariRestoreKey $name 0
        Invoke-AkariCheckpoint $Description
        Write-Log 'Restore point created'
        [pscustomobject]@{ Ok = $true; Message = '' }
    } catch {
        Write-Log "Restore point failed: $($_.Exception.Message)"
        [pscustomobject]@{ Ok = $false; Message = $_.Exception.Message }
    } finally {
        if ($null -eq $old) { Remove-Reg $AkariRestoreKey $name } else { Set-Reg $AkariRestoreKey $name $old }
    }
}
