# Ported from AkariOS-Ultimate (FR33THY Ultimate) 8 Advanced\16 Keyboard Shortcuts. Scancode Map (6 mappings + end):
# both Win keys, both Alt keys and Esc send nothing; the '=' key (0x0D) sends Esc, as in the old script.
@{
    Id          = 'system-keyboard-shortcuts-off'
    Name        = 'Turn off Windows and Alt key shortcuts'
    Section     = 'Advanced'
    Category    = 'System'
    Risk        = 'Safe'
    Reboot      = $true
    Explorer    = $true
    Description = 'No Win key, Win+ shortcuts, Alt keys or media keys, so nothing pulls you out of a game. Esc moves to the = key.'
    Registry    = @(
        @{ Path = 'HKLM:\SYSTEM\CurrentControlSet\Services\hidserv'; Name = 'Start'; Type = 'DWord'; Value = 4; Default = 3 }
        @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer'; Name = 'NoWinKeys'; Type = 'DWord'; Value = 1; Default = $null }
        @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; Name = 'DisabledHotkeys'; Type = 'DWord'; Value = 1; Default = $null }
        @{ Path = 'HKLM:\SYSTEM\CurrentControlSet\Control\Keyboard Layout'; Name = 'Scancode Map'; Type = 'Binary'; Default = $null
           Value = [byte[]](0,0,0,0, 0,0,0,0, 7,0,0,0, 0,0,0x5b,0xe0, 0,0,0x5c,0xe0, 0,0,0x38,0, 0,0,0x38,0xe0, 0,0,1,0, 1,0,0x0d,0, 0,0,0,0) }
    )
}
