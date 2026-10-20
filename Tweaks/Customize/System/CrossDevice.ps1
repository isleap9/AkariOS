# Ported from AkariOS-Ultimate (FR33THY Ultimate) 6 Windows\22 Control Panel Settings.
@{
    Id          = 'system-no-cross-device'
    Name        = 'No phone link and cross-device features'
    Section     = 'Customize'
    Category    = 'System'
    Risk        = 'Safe'
    AkariOS     = $true
    Requires    = 'Win11'
    Description = 'No phone companion in Start, no resuming phone or OneDrive activity, no drag tray, no nearby sharing between your devices.'
    Registry    = @(
        @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\CDP'; Name = 'DragTrayEnabled'; Type = 'DWord'; Value = 0; Default = $null }
        @{ Path = 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\CDP'; Name = 'RomeSdkChannelUserAuthzPolicy'; Type = 'DWord'; Value = 0; Default = 1 }
        @{ Path = 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\CDP'; Name = 'CdpSessionUserAuthzPolicy'; Type = 'DWord'; Value = 0; Default = $null }
        @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Start'; Name = 'RightCompanionToggledOpen'; Type = 'DWord'; Value = 0; Default = $null }
        @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Start\Companions\Microsoft.YourPhone_8wekyb3d8bbwe'; Name = 'IsEnabled'; Type = 'DWord'; Value = 0; Default = $null }
        @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Start\Companions\Microsoft.YourPhone_8wekyb3d8bbwe'; Name = 'IsAvailable'; Type = 'DWord'; Value = 0; Default = $null }
        @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\CrossDeviceResume\Configuration'; Name = 'IsResumeAllowed'; Type = 'DWord'; Value = 0; Default = $null }
        @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\CrossDeviceResume\Configuration'; Name = 'IsOneDriveResumeAllowed'; Type = 'DWord'; Value = 0; Default = $null }
        @{ Path = 'HKLM:\SOFTWARE\Microsoft\PolicyManager\default\Connectivity\DisableCrossDeviceResume'; Name = 'value'; Type = 'DWord'; Value = 1; Default = $null }
        @{ Path = 'HKLM:\SYSTEM\ControlSet001\Control\FeatureManagement\Overrides\8\1387020943'; Name = 'EnabledState'; Type = 'DWord'; Value = 1; Default = $null }
        @{ Path = 'HKLM:\SYSTEM\ControlSet001\Control\FeatureManagement\Overrides\8\1694661260'; Name = 'EnabledState'; Type = 'DWord'; Value = 1; Default = $null }
    )
}
