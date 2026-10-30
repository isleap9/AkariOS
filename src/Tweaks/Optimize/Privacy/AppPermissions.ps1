# Ported from AkariOS-Ultimate (FR33THY Ultimate) 6 Windows\22 Control Panel Settings.
# Default fixed where the script's Default branch is not stock Windows: picturesLibrary|Value.
@{
    Id          = 'privacy-app-permissions'
    Name        = 'Block app permissions'
    Section     = 'Optimize'
    Category    = 'Privacy'
    Risk        = 'Caution'
    AkariOS     = $true
    Description = 'Apps can''t read your contacts, calendar, call history, email, messages, documents, pictures, music, videos or files, or use radios and Windows AI models. Camera and microphone stay allowed.'
    Registry    = @(
        @{ Path = 'HKLM:\Software\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\userNotificationListener'; Name = 'Value'; Type = 'String'; Value = 'Deny'; Default = 'Allow' }
        @{ Path = 'HKLM:\Software\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\userAccountInformation'; Name = 'Value'; Type = 'String'; Value = 'Deny'; Default = 'Allow' }
        @{ Path = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\contacts'; Name = 'Value'; Type = 'String'; Value = 'Deny'; Default = 'Allow' }
        @{ Path = 'HKLM:\Software\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\appointments'; Name = 'Value'; Type = 'String'; Value = 'Deny'; Default = 'Allow' }
        @{ Path = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\phoneCall'; Name = 'Value'; Type = 'String'; Value = 'Deny'; Default = 'Allow' }
        @{ Path = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\phoneCallHistory'; Name = 'Value'; Type = 'String'; Value = 'Deny'; Default = 'Allow' }
        @{ Path = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\email'; Name = 'Value'; Type = 'String'; Value = 'Deny'; Default = 'Allow' }
        @{ Path = 'HKLM:\Software\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\userDataTasks'; Name = 'Value'; Type = 'String'; Value = 'Deny'; Default = 'Allow' }
        @{ Path = 'HKLM:\Software\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\chat'; Name = 'Value'; Type = 'String'; Value = 'Deny'; Default = 'Allow' }
        @{ Path = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\radios'; Name = 'Value'; Type = 'String'; Value = 'Deny'; Default = 'Allow' }
        @{ Path = 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\bluetoothSync'; Name = 'Value'; Type = 'String'; Value = 'Deny'; Default = $null }
        @{ Path = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\appDiagnostics'; Name = 'Value'; Type = 'String'; Value = 'Deny'; Default = 'Allow' }
        @{ Path = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\documentsLibrary'; Name = 'Value'; Type = 'String'; Value = 'Deny'; Default = 'Allow' }
        @{ Path = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\downloadsFolder'; Name = 'Value'; Type = 'String'; Value = 'Deny'; Default = $null }
        @{ Path = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\musicLibrary'; Name = 'Value'; Type = 'String'; Value = 'Deny'; Default = 'Allow' }
        @{ Path = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\picturesLibrary'; Name = 'Value'; Type = 'String'; Value = 'Deny'; Default = 'Allow' }
        @{ Path = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\videosLibrary'; Name = 'Value'; Type = 'String'; Value = 'Deny'; Default = 'Allow' }
        @{ Path = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\broadFileSystemAccess'; Name = 'Value'; Type = 'String'; Value = 'Deny'; Default = 'Allow' }
        @{ Path = 'HKLM:\Software\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\systemAIModels'; Name = 'Value'; Type = 'String'; Value = 'Deny'; Default = 'Allow' }
        @{ Path = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\passkeys'; Name = 'Value'; Type = 'String'; Value = 'Deny'; Default = 'Allow' }
        @{ Path = 'HKLM:\Software\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\passkeysEnumeration'; Name = 'Value'; Type = 'String'; Value = 'Deny'; Default = 'Allow' }
    )
    After       = {
        # Windows keeps its own copy of the choices: reset it so the values above take effect (as the script does)
        Stop-Service -Name 'camsvc' -Force -ErrorAction SilentlyContinue
        Run-Trusted "Remove-Item '$env:ProgramData\Microsoft\Windows\CapabilityAccessManager\CapabilityConsentStorage.db*' -Force"
    }
}
