# Ported from AkariOS-Ultimate (FR33THY Ultimate) 5 Graphics\10 Msi Mode. Revert removes the value (the driver's own
# choice; the old script wrote 0, which forces line-based interrupts even where the driver wants MSI).
@{
    Id          = 'graphics-msi-mode'
    Name        = 'MSI mode for the GPU'
    Section     = 'Hardware'
    Category    = 'Graphics'
    Risk        = 'Safe'
    Reboot      = $true
    Description = 'The GPU uses message-signaled interrupts instead of shared line interrupts: lower, steadier latency.'
    Detect      = {
        $v = @(Get-AkariGpuDevices | ForEach-Object { Get-AkariRegValue "HKLM:\SYSTEM\CurrentControlSet\Enum\$_\Device Parameters\Interrupt Management\MessageSignaledInterruptProperties" 'MSISupported' })
        if (-not $v.Count) { 'Unknown' } elseif (@($v | Where-Object { $_ -ne 1 }).Count -eq 0) { 'Optimized' } elseif (@($v | Where-Object { $null -ne $_ }).Count -eq 0) { 'Default' } else { 'Custom' }
    }
    Apply       = { Get-AkariGpuDevices | ForEach-Object { Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Enum\$_\Device Parameters\Interrupt Management\MessageSignaledInterruptProperties" 'MSISupported' 1 } }
    Revert      = { Get-AkariGpuDevices | ForEach-Object { Remove-Reg "HKLM:\SYSTEM\CurrentControlSet\Enum\$_\Device Parameters\Interrupt Management\MessageSignaledInterruptProperties" 'MSISupported' } }
}
