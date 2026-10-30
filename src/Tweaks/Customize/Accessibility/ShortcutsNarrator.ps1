# Ported from AkariOS-Ultimate (FR33THY Ultimate) 6 Windows\22 Control Panel Settings.
@{
    Id          = 'accessibility-shortcuts-off'
    Name        = 'No accessibility shortcuts and Narrator extras'
    Section     = 'Customize'
    Category    = 'Accessibility'
    Risk        = 'Safe'
    AkariOS     = $true
    Description = 'Pressing Shift five times, Num Lock or Win+Ctrl+Enter no longer turns on Sticky Keys, Toggle Keys, Narrator or the rest; no accessibility sounds; Narrator and Magnifier extras off.'
    Registry    = @(
        @{ Path = 'HKCU:\Software\Microsoft\Narrator\NoRoam'; Name = 'DuckAudio'; Type = 'DWord'; Value = 0; Default = $null }
        @{ Path = 'HKCU:\Software\Microsoft\Narrator\NoRoam'; Name = 'WinEnterLaunchEnabled'; Type = 'DWord'; Value = 0; Default = $null }
        @{ Path = 'HKCU:\Software\Microsoft\Narrator\NoRoam'; Name = 'ScriptingEnabled'; Type = 'DWord'; Value = 0; Default = $null }
        @{ Path = 'HKCU:\Software\Microsoft\Narrator\NoRoam'; Name = 'OnlineServicesEnabled'; Type = 'DWord'; Value = 0; Default = $null }
        @{ Path = 'HKCU:\Software\Microsoft\Narrator'; Name = 'NarratorCursorHighlight'; Type = 'DWord'; Value = 0; Default = $null }
        @{ Path = 'HKCU:\Software\Microsoft\Narrator'; Name = 'CoupleNarratorCursorKeyboard'; Type = 'DWord'; Value = 0; Default = $null }
        @{ Path = 'HKCU:\Software\Microsoft\Ease of Access'; Name = 'selfvoice'; Type = 'DWord'; Value = 0; Default = $null }
        @{ Path = 'HKCU:\Software\Microsoft\Ease of Access'; Name = 'selfscan'; Type = 'DWord'; Value = 0; Default = $null }
        @{ Path = 'HKCU:\Control Panel\Accessibility'; Name = 'Sound on Activation'; Type = 'DWord'; Value = 0; Default = $null }
        @{ Path = 'HKCU:\Control Panel\Accessibility'; Name = 'Warning Sounds'; Type = 'DWord'; Value = 0; Default = $null }
        @{ Path = 'HKCU:\Control Panel\Accessibility\HighContrast'; Name = 'Flags'; Type = 'String'; Value = '4194'; Default = '126' }
        @{ Path = 'HKCU:\Control Panel\Accessibility\Keyboard Response'; Name = 'Flags'; Type = 'String'; Value = '2'; Default = '126' }
        @{ Path = 'HKCU:\Control Panel\Accessibility\Keyboard Response'; Name = 'AutoRepeatRate'; Type = 'String'; Value = '0'; Default = '500' }
        @{ Path = 'HKCU:\Control Panel\Accessibility\Keyboard Response'; Name = 'AutoRepeatDelay'; Type = 'String'; Value = '0'; Default = '1000' }
        @{ Path = 'HKCU:\Control Panel\Accessibility\MouseKeys'; Name = 'Flags'; Type = 'String'; Value = '130'; Default = '62' }
        @{ Path = 'HKCU:\Control Panel\Accessibility\MouseKeys'; Name = 'MaximumSpeed'; Type = 'String'; Value = '39'; Default = '80' }
        @{ Path = 'HKCU:\Control Panel\Accessibility\StickyKeys'; Name = 'Flags'; Type = 'String'; Value = '2'; Default = '510' }
        @{ Path = 'HKCU:\Control Panel\Accessibility\ToggleKeys'; Name = 'Flags'; Type = 'String'; Value = '34'; Default = '62' }
        @{ Path = 'HKCU:\Control Panel\Accessibility\SoundSentry'; Name = 'Flags'; Type = 'String'; Value = '0'; Default = '2' }
        @{ Path = 'HKCU:\Control Panel\Accessibility\SoundSentry'; Name = 'WindowsEffect'; Type = 'String'; Value = '0'; Default = '1' }
        @{ Path = 'HKCU:\Control Panel\Accessibility\SlateLaunch'; Name = 'ATapp'; Type = 'String'; Value = ''; Default = 'narrator' }
        @{ Path = 'HKCU:\Control Panel\Accessibility\SlateLaunch'; Name = 'LaunchAT'; Type = 'DWord'; Value = 0; Default = 1 }
        @{ Path = 'HKCU:\SOFTWARE\Microsoft\ScreenMagnifier'; Name = 'FollowCaret'; Type = 'DWord'; Value = 0; Default = $null }
        @{ Path = 'HKCU:\SOFTWARE\Microsoft\ScreenMagnifier'; Name = 'FollowNarrator'; Type = 'DWord'; Value = 0; Default = $null }
        @{ Path = 'HKCU:\SOFTWARE\Microsoft\ScreenMagnifier'; Name = 'FollowMouse'; Type = 'DWord'; Value = 0; Default = $null }
        @{ Path = 'HKCU:\SOFTWARE\Microsoft\ScreenMagnifier'; Name = 'FollowFocus'; Type = 'DWord'; Value = 0; Default = $null }
        @{ Path = 'HKCU:\SOFTWARE\Microsoft\Narrator'; Name = 'IntonationPause'; Type = 'DWord'; Value = 0; Default = $null }
        @{ Path = 'HKCU:\SOFTWARE\Microsoft\Narrator'; Name = 'ReadHints'; Type = 'DWord'; Value = 0; Default = $null }
        @{ Path = 'HKCU:\SOFTWARE\Microsoft\Narrator'; Name = 'ErrorNotificationType'; Type = 'DWord'; Value = 0; Default = $null }
        @{ Path = 'HKCU:\SOFTWARE\Microsoft\Narrator'; Name = 'EchoChars'; Type = 'DWord'; Value = 0; Default = $null }
        @{ Path = 'HKCU:\SOFTWARE\Microsoft\Narrator'; Name = 'EchoWords'; Type = 'DWord'; Value = 0; Default = $null }
        @{ Path = 'HKCU:\SOFTWARE\Microsoft\Narrator\NarratorHome'; Name = 'MinimizeType'; Type = 'DWord'; Value = 0; Default = $null }
        @{ Path = 'HKCU:\SOFTWARE\Microsoft\Narrator\NarratorHome'; Name = 'AutoStart'; Type = 'DWord'; Value = 0; Default = $null }
        @{ Path = 'HKCU:\SOFTWARE\Microsoft\Narrator\NoRoam'; Name = 'EchoToggleKeys'; Type = 'DWord'; Value = 0; Default = $null }
    )
}
