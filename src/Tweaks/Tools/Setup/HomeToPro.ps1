# Ported from AkariOS-Ultimate (FR33THY Ultimate) 3 Setup "Convert Home To Pro", without its "disable internet
# first" step: Microsoft's generic Pro key (published for edition upgrades) switches the edition; activating Pro
# still needs a Pro license.
# Action: an edition upgrade done in Windows' own dialog; Windows has no way back to Home but a reinstall.
@{
    Id          = 'tools-home-to-pro'
    Name        = 'Upgrade Home to Pro'
    Section     = 'Tools'
    Category    = 'Setup'
    Kind        = 'Action'
    Button      = 'Open'
    Risk        = 'Caution'
    Requires    = 'Home'
    Description = 'Copies Microsoft''s generic Pro key and opens "Change product key": paste it to switch to Pro. You need a Pro license to activate it; going back to Home needs a reinstall.'
    Apply       = {
        $key = 'VK7JG-NPHTM-C97JM-9MPGT-3V66T'
        Set-Clipboard -Value $key
        Write-Log "Generic Pro key (copied): $key"
        Start-Process -FilePath "$env:SystemRoot\System32\SystemSettingsAdminFlows.exe" -ArgumentList 'EnterProductKey'
    }
}
