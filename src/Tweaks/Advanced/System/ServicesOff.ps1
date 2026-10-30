# Ported from AkariOS-Ultimate (FR33THY Ultimate) 8 Advanced\17 Services: "Services: Off", Revert = its "Services:
# Default". A Choice over Files\services.psd1 (helpers in Files\ServiceRows.ps1); per-service picks may come later.
# Many service keys are protected: Safe Mode, TrustedInstaller (then as admin), like FR33THY's .reg import.
# Light and Manual: ZOICWARE's "Disable Services" and "Set all Services to Manual" (https://github.com/zoicware/ZOICWARE, MIT).
@{
    Id          = 'advanced-services-off'
    Name        = 'Turn off most Windows services'
    Section     = 'Advanced'
    Category    = 'System'
    Kind        = 'Choice'
    Risk        = 'Advanced'
    SafeMode    = $true
    Reboot      = $true
    Description = 'Off: FR33THY''s "Services: Off", 216 services disabled or set to manual, among them Windows Update, Wi-Fi, Bluetooth, printing, file sharing, the firewall, the event log, Xbox and telemetry. Light: ZOICWARE''s 31 (Bluetooth, printing, fax, smart cards, maps, diagnostics...). Manual: ZOICWARE''s, 38 automatic services set to start only when needed. Only for a dedicated gaming PC. Needs Safe Mode: Akari restarts into it and back.'
    Confirm     = 'This changes the start type of many Windows services. Off turns off Windows Update, Wi-Fi, Bluetooth, printing, file sharing and the firewall; Light turns off Bluetooth and printing. Things that need them stop working until you revert it. Select it anyway?'
    Choices     = @(
        @{ Value = 'Off'; Label = 'Most services off (FR33THY)' }
        @{ Value = 'Light'; Label = 'Bluetooth, printing and a few more off (ZOICWARE)' }
        @{ Value = 'Manual'; Label = 'Automatic services to manual (ZOICWARE)' }
        @{ Value = 'Default'; Label = 'As Windows ships them' }
    )
    Recommended = 'Off'
    Default     = 'Default'
    Value       = { . "$AkariTweakDir\Files\ServiceRows.ps1"; Get-ServicePick }
    Apply       = { . "$AkariTweakDir\Files\ServiceRows.ps1"; Set-ServicePick $AkariValue }
    Revert      = { . "$AkariTweakDir\Files\ServiceRows.ps1"; Set-ServicePick 'Default' }
}
