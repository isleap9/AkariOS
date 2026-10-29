# From ZOICWARE (https://github.com/zoicware/ZOICWARE, MIT) src\RegTweaks.txt "Disable fault tolerant heap".
@{
    Id          = 'security-fault-tolerant-heap-off'
    Name        = 'Turn off the fault tolerant heap'
    Section     = 'Advanced'
    Category    = 'Security'
    Risk        = 'Advanced'
    Guided      = $false
    Reboot      = $true
    Description = 'Windows stops patching the memory handling of programs that crashed before. A program with a heap bug then crashes again instead of running slower.'
    Registry    = @(
        @{ Path = 'HKLM:\SOFTWARE\Microsoft\FTH'; Name = 'Enabled'; Type = 'DWord'; Value = 0; Default = 1 }
    )
}
