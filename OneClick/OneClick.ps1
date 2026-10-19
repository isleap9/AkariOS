# One-click: the Akari-OS run inside Akari's console, in three phases with restarts in between.
#   1 akarios.ps1 (normal boot): downloads, apps, preparation; then Akari registers phases 2 and 3, turns Safe Mode on, restarts.
#   2 stepone.ps1 (Safe Mode): security settings, UAC, Safe Mode off, DDU (DDU restarts the PC).
#   3 steptwo.ps1 (normal boot): tweaks and cleanup (it clears RunOnce and restarts the PC itself).
# Phases 2 and 3 start through RunOnce as `Akari.ps1 -OneClick 2|3`, so every phase shows Akari's console.
# Needs Core/Log.ps1, Core/Registry.ps1, Core/Phases.ps1.

$AkariOneClickPhases = @{
    1 = @{ Script = 'akarios.ps1'; Title = 'Phase 1 of 3: downloads, apps and preparation' }
    2 = @{ Script = 'stepone.ps1'; Title = 'Phase 2 of 3: Safe Mode (security settings and drivers)' }
    3 = @{ Script = 'steptwo.ps1'; Title = 'Phase 3 of 3: tweaks and cleanup' }
}

# waits for Enter so the user can read why the run stopped
function Wait-AkariKey { Write-Host '  Press Enter to close this window.'; [void][Console]::ReadLine() }

# $Root: the AkariOS folder (Akari.ps1, OneClick\). Returns $true when the phase finished.
function Invoke-AkariOneClick([int]$Phase, [string]$Root) {
    $p = $AkariOneClickPhases[$Phase]
    try {
        $Host.UI.RawUI.WindowTitle = "AkariOS One-click - $($p.Title) - keep this window open"
        $Host.PrivateData.ProgressBackgroundColor = 'Black'
        $Host.PrivateData.ProgressForegroundColor = 'White'
    } catch { }
    Write-Host ''
    Write-Host "  $($p.Title)" -ForegroundColor White
    Write-Host '  Your PC restarts by itself between phases. Do not close this window.' -ForegroundColor DarkGray
    Write-Host ''
    Write-ErrLog "One-click: $($p.Title)"
    $chained = $false
    try {
        & "$Root\OneClick\$($p.Script)"
        if ($Phase -eq 1) {
            # Safe Mode first, then RunOnce (same names and prefixes as the original Akari-OS; *! = runs in Safe Mode).
            # If either fails, both are undone below: phase 3 must never run without phase 2.
            $chained = $true
            Set-AkariSafeBoot $true
            Register-AkariResume '*!akari-oneclick-2' (Get-AkariResumeCommand "$Root\Akari.ps1" '-OneClick 2')
            Register-AkariResume '!akari-oneclick-3' (Get-AkariResumeCommand "$Root\Akari.ps1" '-OneClick 3')
            Write-Host "RESTARTING`n" -ForegroundColor Red
            Write-ErrLog 'One-click: phase 1 done, restarting into Safe Mode'
            Restart-AkariPC
        }
        $true
    } catch {
        if ($chained) {
            foreach ($n in '*!akari-oneclick-2', '!akari-oneclick-3') { Remove-Reg $AkariRunOnceKey $n }
            try { Set-AkariSafeBoot $false } catch { }
        }
        Write-Host ''
        Write-Host "  One-click stopped: $($_.Exception.Message)" -ForegroundColor Red
        Write-ErrLog "One-click stopped in phase ${Phase}: $($_.Exception.Message)"
        Wait-AkariKey
        $false
    }
}
