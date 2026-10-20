# Ported from AkariOS-Ultimate (FR33THY Ultimate) 6 Windows\31 UAC (One-click: stepone.ps1).
@{
    Id          = 'security-uac-off'
    Name        = 'Turn off User Account Control'
    Section     = 'Advanced'
    Category    = 'Security'
    Risk        = 'Advanced'
    AkariOS     = $true
    Reboot      = $true
    Description = 'No UAC prompts: every program you start as an administrator runs elevated without asking. Store apps still work.'
    Registry    = @(
        @{ Path = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System'; Name = 'EnableLUA'; Type = 'DWord'; Value = 0; Default = 1 }
    )
}
