# Ported from AkariOS-Ultimate (FR33THY Ultimate) 8 Advanced\14 Ulps. Per AMD adapter key.
@{
    Id          = 'graphics-amd-ulps-off'
    Name        = 'Turn off AMD ULPS'
    Section     = 'Hardware'
    Category    = 'Graphics'
    Risk        = 'Caution'
    Requires    = 'AMD'
    Reboot      = $true
    Description = 'Stops AMD''s Ultra Low Power State, which can cause stutter, black screens and wake problems (more idle power).'
    Detect      = {
        $v = @(Get-AkariGpus | Where-Object Vendor -eq 'AMD' | ForEach-Object { Get-AkariRegValue $_.Path 'EnableUlps' })
        if (-not $v.Count) { 'Unknown' } elseif (@($v | Where-Object { $_ -ne 0 }).Count -eq 0) { 'Optimized' } elseif (@($v | Where-Object { $null -ne $_ -and $_ -ne 1 }).Count -eq 0) { 'Default' } else { 'Custom' }
    }
    Apply       = { Get-AkariGpus | Where-Object Vendor -eq 'AMD' | ForEach-Object { Set-Reg $_.Path 'EnableUlps' 0 } }
    Revert      = { Get-AkariGpus | Where-Object Vendor -eq 'AMD' | ForEach-Object { Set-Reg $_.Path 'EnableUlps' 1 } }
}
