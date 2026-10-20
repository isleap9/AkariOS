# Ported from AkariOS-Ultimate (FR33THY Ultimate) 8 Advanced\6 MMAgent Features. Memory compression is its own Tweak
# (disable-memory-compression); page combining stays off both ways, as in the old script's Default.
@{
    Id          = 'system-mmagent-off'
    Name        = 'Turn off prefetch and app prelaunch'
    Section     = 'Advanced'
    Category    = 'System'
    Risk        = 'Caution'
    Reboot      = $true
    Description = 'Turns off Prefetcher, app launch prefetching, app prelaunch, the operation recorder and page combining. Apps may start slower.'
    Detect      = {
        $m = Get-MMAgent
        $pf = Get-AkariRegValue 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management\PrefetchParameters' 'EnablePrefetcher'
        $off = -not $m.ApplicationLaunchPrefetching -and -not $m.ApplicationPreLaunch -and -not $m.OperationAPI -and $m.MaxOperationAPIFiles -eq 1 -and $pf -eq 0
        $on = $m.ApplicationLaunchPrefetching -and $m.ApplicationPreLaunch -and $m.OperationAPI -and $m.MaxOperationAPIFiles -eq 512 -and $pf -eq 3
        if ($off) { 'Optimized' } elseif ($on) { 'Default' } else { 'Custom' }
    }
    Apply       = {
        Set-Reg 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management\PrefetchParameters' 'EnablePrefetcher' 0
        Disable-MMAgent -ApplicationLaunchPrefetching -ErrorAction SilentlyContinue
        Disable-MMAgent -ApplicationPreLaunch -ErrorAction SilentlyContinue
        Set-MMAgent -MaxOperationAPIFiles 1 -ErrorAction SilentlyContinue
        Disable-MMAgent -OperationAPI -ErrorAction SilentlyContinue
        Disable-MMAgent -PageCombining -ErrorAction SilentlyContinue
    }
    Revert      = {
        Set-Reg 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management\PrefetchParameters' 'EnablePrefetcher' 3
        Enable-MMAgent -ApplicationLaunchPrefetching -ErrorAction SilentlyContinue
        Enable-MMAgent -ApplicationPreLaunch -ErrorAction SilentlyContinue
        Set-MMAgent -MaxOperationAPIFiles 512 -ErrorAction SilentlyContinue
        Enable-MMAgent -OperationAPI -ErrorAction SilentlyContinue
        Disable-MMAgent -PageCombining -ErrorAction SilentlyContinue
    }
}
