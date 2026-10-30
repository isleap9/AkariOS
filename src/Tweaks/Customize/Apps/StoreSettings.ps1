# Ported from AkariOS-Ultimate (FR33THY Ultimate) 3 Setup\11 Store Settings (One-click sets it in steptwo.ps1). The
# values live in the Store's own settings hive, typed 0x5f5e10b (first byte 0 = off, then a timestamp). Its
# AutoDownload value is update-store-auto-update's. Detect reads a copy of that hive: Unknown while the Store runs.
@{
    Id          = 'apps-store-settings'
    Name        = 'Microsoft Store: no autoplay, install toasts or personalization'
    Section     = 'Customize'
    Category    = 'Apps'
    Risk        = 'Safe'
    AkariOS     = $true
    Description = 'Store settings: video autoplay off, app install notifications off, personalized experiences off.'
    Detect      = {
        Get-AkariAppSettingState 'Microsoft.WindowsStore_8wekyb3d8bbwe' @(
            @{ Name = 'LocalState\VideoAutoplay'; Value = 0; Default = 1 }
            @{ Name = 'LocalState\EnableAppInstallNotifications'; Value = 0; Default = 1 }
            @{ Name = 'LocalState\PersistentSettings\PersonalizationEnabled'; Value = 0; Default = 1 })
    }
    Apply       = {
        # the settings page first, so the Microsoft account's personalization setting is there to override
        try { Start-Process 'ms-windows-store:settings' } catch { }
        Start-Sleep -Seconds 5
        'WinStore.App', 'backgroundTaskHost', 'StoreDesktopExtension' | ForEach-Object { Stop-Process -Name $_ -Force -ErrorAction SilentlyContinue }
        Start-Sleep -Seconds 2
        $reg = (Get-Content -LiteralPath "$AkariTweakDir\Files\store-settings.reg" -Raw).Replace('{0}', '00')
        if (-not (Import-AkariAppSettings 'Microsoft.WindowsStore_8wekyb3d8bbwe' $reg)) { throw 'the Store''s settings could not be opened (open the Store once, then try again)' }
    }
    Revert      = {
        'WinStore.App', 'backgroundTaskHost', 'StoreDesktopExtension' | ForEach-Object { Stop-Process -Name $_ -Force -ErrorAction SilentlyContinue }
        Start-Sleep -Seconds 2
        $reg = (Get-Content -LiteralPath "$AkariTweakDir\Files\store-settings.reg" -Raw).Replace('{0}', '01')
        if (-not (Import-AkariAppSettings 'Microsoft.WindowsStore_8wekyb3d8bbwe' $reg)) { throw 'the Store''s settings could not be opened' }
    }
}
