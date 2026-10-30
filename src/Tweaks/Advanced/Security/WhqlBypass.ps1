# Ported from AkariOS-Ultimate (FR33THY Ultimate) 8 Advanced\15 Driver Whql Secure Boot Bypass.
@{
    Id          = 'security-whql-secure-boot-bypass'
    Name        = 'Allow non-WHQL drivers with Secure Boot'
    Section     = 'Advanced'
    Category    = 'Security'
    Risk        = 'Advanced'
    Reboot      = $true
    Description = 'Lets drivers without Microsoft WHQL signing load while Secure Boot is on (modded or beta GPU drivers).'
    Registry    = @(
        @{ Path = 'HKLM:\SYSTEM\CurrentControlSet\Control\CI\Policy'; Name = 'WHQLSettings'; Type = 'DWord'; Value = 1; Default = $null }
    )
}
