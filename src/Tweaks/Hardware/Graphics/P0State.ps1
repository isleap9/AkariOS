# Ported from AkariOS-Ultimate (FR33THY Ultimate) 5 Graphics\9 P0 State. Per NVIDIA adapter key; Default = the value
# absent (the old script wrote 0, which the driver reads the same).
@{
    Id          = 'graphics-p0-state'
    Name        = 'Keep the GPU at full clocks (P0 state)'
    Section     = 'Hardware'
    Category    = 'Graphics'
    Risk        = 'Caution'
    Requires    = 'NVIDIA'
    Reboot      = $true
    Description = 'The GPU never drops to power-saving clocks: steadier frame times, more power and heat at idle.'
    Detect      = {
        $v = @(Get-AkariGpus | Where-Object Vendor -eq 'NVIDIA' | ForEach-Object { Get-AkariRegValue $_.Path 'DisableDynamicPstate' })
        if (-not $v.Count) { 'Unknown' } elseif (@($v | Where-Object { $_ -ne 1 }).Count -eq 0) { 'Optimized' } elseif (@($v | Where-Object { $_ -and $_ -ne 0 }).Count -eq 0) { 'Default' } else { 'Custom' }
    }
    Apply       = { Get-AkariGpus | Where-Object Vendor -eq 'NVIDIA' | ForEach-Object { Set-Reg $_.Path 'DisableDynamicPstate' 1 } }
    Revert      = { Get-AkariGpus | Where-Object Vendor -eq 'NVIDIA' | ForEach-Object { Remove-Reg $_.Path 'DisableDynamicPstate' } }
}
