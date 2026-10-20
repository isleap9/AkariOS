# Ported from AkariOS-Ultimate (FR33THY Ultimate) 5 Graphics\7 Intel Settings. Per Intel adapter key, in its 3DKeys
# subkey (Revert deletes it, as the old script did). Its DirectXUserGlobalSettings value belongs to
# gaming-windowed-optimizations.
@{
    Id          = 'graphics-intel-settings'
    Name        = 'Intel graphics: VSync off, low latency on'
    Section     = 'Hardware'
    Category    = 'Graphics'
    Risk        = 'Safe'
    Requires    = 'Intel'
    Description = 'Intel Graphics Command Center: frame synchronization off (async flip) and low latency mode on, for every game.'
    Detect      = {
        $s = @(Get-AkariGpus | Where-Object Vendor -eq 'Intel' | ForEach-Object {
            $a = Get-AkariRegValue "$($_.Path)\3DKeys" 'Global_AsyncFlipMode'; $l = Get-AkariRegValue "$($_.Path)\3DKeys" 'Global_LowLatency'
            if ($a -eq 2 -and $l -eq 1) { 'Optimized' } elseif ($null -eq $a -and $null -eq $l) { 'Default' } else { 'Custom' } })
        if (-not $s.Count) { 'Unknown' } elseif (@($s | Select-Object -Unique).Count -eq 1) { $s[0] } else { 'Custom' }
    }
    Apply       = {
        foreach ($g in @(Get-AkariGpus | Where-Object Vendor -eq 'Intel')) {
            Set-Reg "$($g.Path)\3DKeys" 'Global_AsyncFlipMode' 2
            Set-Reg "$($g.Path)\3DKeys" 'Global_LowLatency' 1
        }
    }
    Revert      = {
        foreach ($g in @(Get-AkariGpus | Where-Object Vendor -eq 'Intel')) {
            $k = Resolve-AkariRegPath "$($g.Path)\3DKeys"
            if (Test-Path -LiteralPath $k) { Remove-Item -LiteralPath $k -Recurse -Force }
        }
    }
}
