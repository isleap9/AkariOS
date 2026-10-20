# Ported from AkariOS-Ultimate (FR33THY Ultimate) 6 Windows\22 Control Panel Settings.
@{
    Id          = 'sound-no-scheme'
    Name        = 'No Windows sounds'
    Section     = 'Customize'
    Category    = 'Sound'
    Risk        = 'Safe'
    AkariOS     = $true
    Description = 'The "No Sounds" scheme: no beeps and chimes for errors, notifications, devices or UAC.'
    Registry    = @(
        @{ Path = 'HKCU:\AppEvents\Schemes'; Name = '(default)'; Type = 'String'; Value = '.None'; Default = '.Default' }
        @{ Path = 'HKCU:\AppEvents\Schemes\Apps\.Default\.Default\.Current'; Name = '(default)'; Type = 'String'; Value = ''; Default = 'C:\Windows\media\Windows Background.wav' }
        @{ Path = 'HKCU:\AppEvents\Schemes\Apps\.Default\CriticalBatteryAlarm\.Current'; Name = '(default)'; Type = 'String'; Value = ''; Default = 'C:\Windows\media\Windows Foreground.wav' }
        @{ Path = 'HKCU:\AppEvents\Schemes\Apps\.Default\DeviceConnect\.Current'; Name = '(default)'; Type = 'String'; Value = ''; Default = 'C:\Windows\media\Windows Hardware Insert.wav' }
        @{ Path = 'HKCU:\AppEvents\Schemes\Apps\.Default\DeviceDisconnect\.Current'; Name = '(default)'; Type = 'String'; Value = ''; Default = 'C:\Windows\media\Windows Hardware Remove.wav' }
        @{ Path = 'HKCU:\AppEvents\Schemes\Apps\.Default\DeviceFail\.Current'; Name = '(default)'; Type = 'String'; Value = ''; Default = 'C:\Windows\media\Windows Hardware Fail.wav' }
        @{ Path = 'HKCU:\AppEvents\Schemes\Apps\.Default\FaxBeep\.Current'; Name = '(default)'; Type = 'String'; Value = ''; Default = 'C:\Windows\media\Windows Notify Email.wav' }
        @{ Path = 'HKCU:\AppEvents\Schemes\Apps\.Default\LowBatteryAlarm\.Current'; Name = '(default)'; Type = 'String'; Value = ''; Default = 'C:\Windows\media\Windows Background.wav' }
        @{ Path = 'HKCU:\AppEvents\Schemes\Apps\.Default\MailBeep\.Current'; Name = '(default)'; Type = 'String'; Value = ''; Default = 'C:\Windows\media\Windows Notify Email.wav' }
        @{ Path = 'HKCU:\AppEvents\Schemes\Apps\.Default\MessageNudge\.Current'; Name = '(default)'; Type = 'String'; Value = ''; Default = 'C:\Windows\media\Windows Message Nudge.wav' }
        @{ Path = 'HKCU:\AppEvents\Schemes\Apps\.Default\Notification.Default\.Current'; Name = '(default)'; Type = 'String'; Value = ''; Default = 'C:\Windows\media\Windows Notify System Generic.wav' }
        @{ Path = 'HKCU:\AppEvents\Schemes\Apps\.Default\Notification.IM\.Current'; Name = '(default)'; Type = 'String'; Value = ''; Default = 'C:\Windows\media\Windows Notify Messaging.wav' }
        @{ Path = 'HKCU:\AppEvents\Schemes\Apps\.Default\Notification.Mail\.Current'; Name = '(default)'; Type = 'String'; Value = ''; Default = 'C:\Windows\media\Windows Notify Email.wav' }
        @{ Path = 'HKCU:\AppEvents\Schemes\Apps\.Default\Notification.Proximity\.Current'; Name = '(default)'; Type = 'String'; Value = ''; Default = 'C:\Windows\media\Windows Proximity Notification.wav' }
        @{ Path = 'HKCU:\AppEvents\Schemes\Apps\.Default\Notification.Reminder\.Current'; Name = '(default)'; Type = 'String'; Value = ''; Default = 'C:\Windows\media\Windows Notify Calendar.wav' }
        @{ Path = 'HKCU:\AppEvents\Schemes\Apps\.Default\Notification.SMS\.Current'; Name = '(default)'; Type = 'String'; Value = ''; Default = 'C:\Windows\media\Windows Notify Messaging.wav' }
        @{ Path = 'HKCU:\AppEvents\Schemes\Apps\.Default\ProximityConnection\.Current'; Name = '(default)'; Type = 'String'; Value = ''; Default = 'C:\Windows\media\Windows Proximity Connection.wav' }
        @{ Path = 'HKCU:\AppEvents\Schemes\Apps\.Default\SystemAsterisk\.Current'; Name = '(default)'; Type = 'String'; Value = ''; Default = 'C:\Windows\media\Windows Background.wav' }
        @{ Path = 'HKCU:\AppEvents\Schemes\Apps\.Default\SystemExclamation\.Current'; Name = '(default)'; Type = 'String'; Value = ''; Default = 'C:\Windows\media\Windows Background.wav' }
        @{ Path = 'HKCU:\AppEvents\Schemes\Apps\.Default\SystemHand\.Current'; Name = '(default)'; Type = 'String'; Value = ''; Default = 'C:\Windows\media\Windows Foreground.wav' }
        @{ Path = 'HKCU:\AppEvents\Schemes\Apps\.Default\SystemNotification\.Current'; Name = '(default)'; Type = 'String'; Value = ''; Default = 'C:\Windows\media\Windows Background.wav' }
        @{ Path = 'HKCU:\AppEvents\Schemes\Apps\.Default\WindowsUAC\.Current'; Name = '(default)'; Type = 'String'; Value = ''; Default = 'C:\Windows\media\Windows User Account Control.wav' }
        @{ Path = 'HKCU:\AppEvents\Schemes\Apps\sapisvr\DisNumbersSound\.current'; Name = '(default)'; Type = 'String'; Value = ''; Default = 'C:\Windows\media\Speech Disambiguation.wav' }
        @{ Path = 'HKCU:\AppEvents\Schemes\Apps\sapisvr\HubOffSound\.current'; Name = '(default)'; Type = 'String'; Value = ''; Default = 'C:\Windows\media\Speech Off.wav' }
        @{ Path = 'HKCU:\AppEvents\Schemes\Apps\sapisvr\HubOnSound\.current'; Name = '(default)'; Type = 'String'; Value = ''; Default = 'C:\Windows\media\Speech On.wav' }
        @{ Path = 'HKCU:\AppEvents\Schemes\Apps\sapisvr\HubSleepSound\.current'; Name = '(default)'; Type = 'String'; Value = ''; Default = 'C:\Windows\media\Speech Sleep.wav' }
        @{ Path = 'HKCU:\AppEvents\Schemes\Apps\sapisvr\MisrecoSound\.current'; Name = '(default)'; Type = 'String'; Value = ''; Default = 'C:\Windows\media\Speech Misrecognition.wav' }
        @{ Path = 'HKCU:\AppEvents\Schemes\Apps\sapisvr\PanelSound\.current'; Name = '(default)'; Type = 'String'; Value = ''; Default = 'C:\Windows\media\Speech Disambiguation.wav' }
    )
}
