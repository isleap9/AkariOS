# From ZOICWARE (https://github.com/zoicware/ZOICWARE, MIT) src\RegTweaks.txt "Disable device usage".
@{
    Id          = 'privacy-device-usage-off'
    Name        = 'Forget how you use this PC'
    Section     = 'Optimize'
    Category    = 'Privacy'
    Risk        = 'Advanced'
    Guided      = $false
    Description = 'Clears the "device usage" answers from setup (gaming, school, creativity, business and more) that Windows uses for tips, ads and suggestions.'
    Registry    = @(
        @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\CloudExperienceHost\Intent\business'; Name = 'Intent'; Type = 'DWord'; Value = 0; Default = $null }
        @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\CloudExperienceHost\Intent\creative'; Name = 'Intent'; Type = 'DWord'; Value = 0; Default = $null }
        @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\CloudExperienceHost\Intent\developer'; Name = 'Intent'; Type = 'DWord'; Value = 0; Default = $null }
        @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\CloudExperienceHost\Intent\DeviceMetaDataBackup'; Name = 'Intent'; Type = 'DWord'; Value = 0; Default = $null }
        @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\CloudExperienceHost\Intent\entertainment'; Name = 'Intent'; Type = 'DWord'; Value = 0; Default = $null }
        @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\CloudExperienceHost\Intent\family'; Name = 'Intent'; Type = 'DWord'; Value = 0; Default = $null }
        @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\CloudExperienceHost\Intent\gaming'; Name = 'Intent'; Type = 'DWord'; Value = 0; Default = $null }
        @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\CloudExperienceHost\Intent\IntroIneligible'; Name = 'Intent'; Type = 'DWord'; Value = 0; Default = $null }
        @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\CloudExperienceHost\Intent\IntroPostponed'; Name = 'Intent'; Type = 'DWord'; Value = 0; Default = $null }
        @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\CloudExperienceHost\Intent\IntroSkipped'; Name = 'Intent'; Type = 'DWord'; Value = 0; Default = $null }
        @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\CloudExperienceHost\Intent\OffDeviceConsent'; Name = 'Intent'; Type = 'DWord'; Value = 0; Default = $null }
        @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\CloudExperienceHost\Intent\schoolwork'; Name = 'Intent'; Type = 'DWord'; Value = 0; Default = $null }
    )
}
