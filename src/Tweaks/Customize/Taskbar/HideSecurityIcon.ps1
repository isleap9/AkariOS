# Ported from AkariOS-Ultimate (FR33THY Ultimate) 6 Windows\1 Start Menu Taskbar: the Startup apps entry of the
# Windows Security tray icon (bytes as the script writes them; Defender itself keeps running).
@{
    Id          = 'taskbar-hide-security-icon'
    Name        = 'Hide the Windows Security icon'
    Section     = 'Customize'
    Category    = 'Taskbar'
    Risk        = 'Safe'
    AkariOS     = $true
    Reboot      = $true
    Description = 'The shield icon no longer starts with Windows. Windows Security still protects the PC and opens from Settings.'
    Registry    = @{ Path = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run'; Name = 'SecurityHealth'; Type = 'Binary'
                     Value = [byte[]](7, 0, 0, 0, 0x05, 0xdb, 0x8a, 0x69, 0x8a, 0x49, 0xd9, 0x01); Default = [byte[]](4, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0) }
}
