# Ported from AkariOS-Ultimate (FR33THY Ultimate) 3 Setup\10 Edge Settings: its policies. Its removal of Edge's
# updaters, services and tasks is Apps > Remove's job (remove-edge); its Default reinstalled Edge.
@{
    Id          = 'apps-edge-settings'
    Name        = 'Microsoft Edge: uBlock Origin, no background running'
    Section     = 'Customize'
    Category    = 'Apps'
    Risk        = 'Safe'
    Description = 'For a kept Edge: installs uBlock Origin, and stops Edge running in the background or preloading at sign-in. Hardware acceleration off.'
    Registry    = @(
        @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Edge\ExtensionInstallForcelist'; Name = '1'; Type = 'String'; Value = 'odfafepnkmbhccpbejgmiehpchacaeak;https://edge.microsoft.com/extensionwebstorebase/v1/crx'; Default = $null }
        @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Edge'; Name = 'HardwareAccelerationModeEnabled'; Type = 'DWord'; Value = 0; Default = $null }
        @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Edge'; Name = 'BackgroundModeEnabled'; Type = 'DWord'; Value = 0; Default = $null }
        @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Edge'; Name = 'StartupBoostEnabled'; Type = 'DWord'; Value = 0; Default = $null }
    )
}
