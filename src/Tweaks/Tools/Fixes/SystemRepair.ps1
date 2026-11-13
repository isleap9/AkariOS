# Ported from Chris Titus Tech's winutil (MIT), functions/public/Invoke-WPFSystemRepair.ps1: chkdsk, sfc and DISM in
# its order, with its exit codes that still count as done.
# Action: a repair has no Default to go back to.
@{
    Id          = 'tools-system-repair'
    Name        = 'System corruption scan'
    Section     = 'Tools'
    Category    = 'Fixes'
    Kind        = 'Action'
    Button      = 'Scan'
    Risk        = 'Safe'
    Description = 'Checks the disk (chkdsk /scan), then repairs Windows'' files (sfc /scannow) and its image (DISM /RestoreHealth). Takes 20 to 40 minutes.'
    Apply       = {
        $sys = "$env:SystemRoot\System32"
        $steps = @(
            @{ Label = 'Checking the disk for errors'; Exe = 'chkdsk.exe'; Arguments = @('/scan', '/perf'); Ok = @{ 1 = 'errors were found and fixed'; 2 = 'cleanup was done, or skipped without /f' } }
            @{ Label = 'Scanning protected system files'; Exe = 'sfc.exe'; Arguments = @('/scannow'); Ok = @{} }
            @{ Label = 'Repairing the Windows image'; Exe = 'dism.exe'; Arguments = @('/Online', '/Cleanup-Image', '/RestoreHealth'); Ok = @{ 3010 = 'restart Windows for the repair to take effect' } }
        )
        $n = 0
        foreach ($s in $steps) {
            $n++
            Write-Log "System repair ($n of $($steps.Count)): $($s.Label)"
            $code = [int](Invoke-AkariExe "$sys\$($s.Exe)" $s.Arguments)
            if ($code -eq 0) { continue }
            if ($s.Ok.ContainsKey($code)) { Write-Log "System repair: $($s.Label) finished: $($s.Ok[$code])"; continue }
            throw "$($s.Label) failed (exit code $code)"
        }
        Write-Log 'System repair: done'
    }
}
