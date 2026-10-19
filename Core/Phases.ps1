# Phases: resume Akari after a restart (RunOnce), Safe Mode on / off, restart. No tweak logic.
# RunOnce value names: a leading * also runs in Safe Mode; a leading ! deletes the value only after the command ran.
# Needs Core/Registry.ps1 (Set-Reg maps HKCU to the logged-in user, whose logon runs RunOnce).

$AkariRunOnceKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce'

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
    if ($code) { throw "bcdedit could not turn Safe Mode $(if ($On) { 'on' } else { 'off' }) (exit code $code)" }
}

function Restart-AkariPC([int]$Seconds = 5) {
    Start-Sleep -Seconds $Seconds
    shutdown -r -t 00
}
