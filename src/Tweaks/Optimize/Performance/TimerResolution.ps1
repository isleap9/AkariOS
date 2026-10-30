# Ported from AkariOS-Ultimate (FR33THY Ultimate) 6 Windows\30 Timer Resolution (One-click does the same): a small
# service, compiled here from OneClick\settimerresolutionservice.cs (the same code as the script's; one copy until M4
# retires OneClick\), that keeps Windows at its finest timer resolution, plus GlobalTimerResolutionRequests so it
# applies to every process on Windows 11.
@{
    Id          = 'performance-timer-resolution'
    Name        = 'Timer resolution service'
    Section     = 'Optimize'
    Category    = 'Performance'
    Risk        = 'Caution'
    AkariOS     = $true
    Reboot      = $true
    Description = 'A service keeps the Windows timer at its finest step (about 0.5 ms) for smoother frame pacing and lower input latency. Uses a little more power.'
    Detect      = {
        $s = Get-Service -Name 'Set Timer Resolution Service' -ErrorAction SilentlyContinue
        if (-not $s) { 'Default' } elseif ($s.StartType -eq 'Automatic') { 'Optimized' } else { 'Custom' }
    }
    Apply       = {
        $src = Join-Path (Split-Path (Split-Path (Split-Path $AkariTweakDir))) 'OneClick\settimerresolutionservice.cs'
        $exe = "$env:SystemRoot\SetTimerResolutionService.exe"
        if (Get-Service -Name 'Set Timer Resolution Service' -ErrorAction SilentlyContinue) {
            Stop-Service -Name 'Set Timer Resolution Service' -Force -ErrorAction SilentlyContinue
            Remove-AkariService 'Set Timer Resolution Service'
            Start-Sleep -Seconds 2
        }
        Invoke-AkariCsc $src $exe
        New-Service -Name 'Set Timer Resolution Service' -BinaryPathName $exe -StartupType Automatic | Out-Null
        Start-Service -Name 'Set Timer Resolution Service' -ErrorAction SilentlyContinue
        Set-Reg 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\kernel' 'GlobalTimerResolutionRequests' 1
    }
    Revert      = {
        Stop-Service -Name 'Set Timer Resolution Service' -Force -ErrorAction SilentlyContinue
        if (Get-Service -Name 'Set Timer Resolution Service' -ErrorAction SilentlyContinue) { Remove-AkariService 'Set Timer Resolution Service' }
        Start-Sleep -Seconds 2
        Remove-Item "$env:SystemRoot\SetTimerResolutionService.exe" -Force -ErrorAction SilentlyContinue
        Remove-Reg 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\kernel' 'GlobalTimerResolutionRequests'
    }
}
