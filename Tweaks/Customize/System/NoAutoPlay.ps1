# Ported from AkariOS-Ultimate (FR33THY Ultimate) 6 Windows\22 Control Panel Settings.
@{
    Id          = 'system-no-autoplay'
    Name        = 'AutoPlay off'
    Section     = 'Customize'
    Category    = 'System'
    Risk        = 'Safe'
    AkariOS     = $true
    Description = 'Nothing opens on its own when you plug in a drive, phone or disc.'
    Registry    = @(
        @{ Path = 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\AutoplayHandlers'; Name = 'DisableAutoplay'; Type = 'DWord'; Value = 1; Default = 0 }
    )
}
