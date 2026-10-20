# Ported from AkariOS-Ultimate (FR33THY Ultimate) 8 Advanced\2 Firewall.
@{
    Id          = 'security-firewall-off'
    Name        = 'Turn off Windows Firewall'
    Section     = 'Advanced'
    Category    = 'Security'
    Risk        = 'Advanced'
    Reboot      = $true
    Description = 'Turns the firewall off for private and public networks. Only behind a router you trust.'
    Registry    = @(
        @{ Path = 'HKLM:\SYSTEM\CurrentControlSet\Services\SharedAccess\Parameters\FirewallPolicy\PublicProfile'; Name = 'EnableFirewall'; Type = 'DWord'; Value = 0; Default = 1 }
        @{ Path = 'HKLM:\SYSTEM\CurrentControlSet\Services\SharedAccess\Parameters\FirewallPolicy\StandardProfile'; Name = 'EnableFirewall'; Type = 'DWord'; Value = 0; Default = 1 }
    )
}
