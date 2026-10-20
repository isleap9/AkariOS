@{
    Id          = 'win32-priority-separation'
    Name        = 'Win32 Priority Separation'
    Section     = 'Advanced'
    Category    = 'Tuning'
    Kind        = 'Choice'
    Risk        = 'Safe'
    AkariOS     = $true
    Reboot      = $true
    Description = 'Short, variable quanta with a 3:1 foreground boost (0x26).'
    Registry    = @{ Path = 'HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl'; Name = 'Win32PrioritySeparation'; Type = 'DWord' }
    Choices     = @(
        @{ Value = 0x26; Label = '0x26 short, variable, 3:1' }
        @{ Value = 0x28; Label = '0x28 short, fixed' }
        @{ Value = 0x18; Label = '0x18 long, fixed, 3:1' }
    )
    Editable    = $true
    Recommended = 0x26
    Default     = 2
}
