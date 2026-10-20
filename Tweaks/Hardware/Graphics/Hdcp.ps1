# Ported from AkariOS-Ultimate (FR33THY Ultimate) 5 Graphics\8 Hdcp. Per NVIDIA adapter key; Default = the value
# absent (the old script wrote 0, which the driver reads the same).
@{
    Id          = 'graphics-hdcp-off'
    Name        = 'Turn off HDCP (NVIDIA)'
    Section     = 'Hardware'
    Category    = 'Graphics'
    Risk        = 'Caution'
    Requires    = 'NVIDIA'
    Reboot      = $true
    Description = 'Turns off HDCP copy protection on the GPU. Protected video (Netflix and other streaming apps) may stop playing.'
    Detect      = {
        $v = @(Get-AkariGpus | Where-Object Vendor -eq 'NVIDIA' | ForEach-Object { Get-AkariRegValue $_.Path 'RMHdcpKeyglobZero' })
        if (-not $v.Count) { 'Unknown' } elseif (@($v | Where-Object { $_ -ne 1 }).Count -eq 0) { 'Optimized' } elseif (@($v | Where-Object { $_ -and $_ -ne 0 }).Count -eq 0) { 'Default' } else { 'Custom' }
    }
    Apply       = { Get-AkariGpus | Where-Object Vendor -eq 'NVIDIA' | ForEach-Object { Set-Reg $_.Path 'RMHdcpKeyglobZero' 1 } }
    Revert      = { Get-AkariGpus | Where-Object Vendor -eq 'NVIDIA' | ForEach-Object { Remove-Reg $_.Path 'RMHdcpKeyglobZero' } }
}
