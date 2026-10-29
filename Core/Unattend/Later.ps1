# Install USB: the modifiers of batches 2 and 3, not ported yet (plan docs/plans/2026-10-29-usb-setup-file.md). Each
# replaces its no-op here when it lands.
function Invoke-AkariUaBloatware($C) { }
# (batch 2 ports the rest of Optimizations.cs around this piece, at its place: after the line before "DisableSac")
function Invoke-AkariUaOptimizations($C) {
    if ($C.PEMode -eq 'Generated' -and (Test-AkariUaOn $C 'DisableDefender')) {
        $C.Specialize.Commands.Add('reg.exe add "HKLM\SOFTWARE\Policies\Microsoft\Windows Defender Security Center\Notifications" /v DisableNotifications /t REG_DWORD /d 1 /f;')
    }
}
function Invoke-AkariUaPersonalization($C) { }
function Invoke-AkariUaAppLocker($C) { }
function Invoke-AkariUaScript($C) { }
function Invoke-AkariUaComponents($C) { }
