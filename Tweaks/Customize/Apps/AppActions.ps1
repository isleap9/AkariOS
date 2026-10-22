# Ported from AkariOS-Ultimate (FR33THY Ultimate) 6 Windows\22 Control Panel Settings and One-click's steptwo.ps1
# (isleap9/Akari-OS): "disable app actions". The values live in the Windows shell's own settings hive
# (MicrosoftWindows.Client.CBS, Import-AkariAppSettings); their first byte is 1 = actions off. FR33THY's Default deletes
# that whole settings file (every shell setting with it): here Revert writes 0 to the same three values instead.
@{
    Id          = 'apps-app-actions-off'
    Name        = 'No app actions'
    Section     = 'Customize'
    Category    = 'Apps'
    Risk        = 'Safe'
    AkariOS     = $true
    Requires    = 'Win11'
    Description = 'Settings > Apps > Actions: Paint, Photos and Windows stop offering their actions on files.'
    Detect      = {
        Get-AkariAppSettingState 'MicrosoftWindows.Client.CBS_cw5n1h2txyewy' @(
            foreach ($a in 'Microsoft.Paint_8wekyb3d8bbwe', 'Microsoft.Windows.Photos_8wekyb3d8bbwe', 'MicrosoftWindows.Client.CBS_cw5n1h2txyewy') {
                @{ Name = "LocalState\DisabledApps\$a"; Value = 1; Default = 0 } })
    }
    Apply       = {
        # the shell host keeps its hive open while these run
        'AppActions', 'CrossDeviceResume', 'DesktopStickerEditorWin32Exe', 'DiscoveryHubApp', 'FESearchHost', 'SearchHost', 'SoftLandingTask',
            'TextInputHost', 'VisualAssistExe', 'WebExperienceHostApp', 'WindowsBackupClient', 'WindowsMigration' | ForEach-Object { Stop-Process -Name $_ -Force -ErrorAction SilentlyContinue }
        Start-Sleep -Seconds 2
        $reg = "Windows Registry Editor Version 5.00`r`n`r`n[HKEY_LOCAL_MACHINE\AkariAppHive\LocalState\DisabledApps]`r`n" +
            (@('Microsoft.Paint_8wekyb3d8bbwe', 'Microsoft.Windows.Photos_8wekyb3d8bbwe', 'MicrosoftWindows.Client.CBS_cw5n1h2txyewy') | ForEach-Object { "`"$_`"=hex(5f5e10b):01,61,ed,11,34,f7,9f,dc,01`r`n" }) -join ''
        $dat = Join-Path (Get-AkariUserFolder 'Local AppData') 'Packages\MicrosoftWindows.Client.CBS_cw5n1h2txyewy\Settings\settings.dat'
        if (-not (Test-Path -LiteralPath $dat)) { 'The Windows shell has no settings file yet: nothing to change'; return }
        if (-not (Import-AkariAppSettings 'MicrosoftWindows.Client.CBS_cw5n1h2txyewy' $reg)) { throw 'the Windows shell''s settings could not be opened' }
    }
    Revert      = {
        'AppActions', 'CrossDeviceResume', 'DesktopStickerEditorWin32Exe', 'DiscoveryHubApp', 'FESearchHost', 'SearchHost', 'SoftLandingTask',
            'TextInputHost', 'VisualAssistExe', 'WebExperienceHostApp', 'WindowsBackupClient', 'WindowsMigration' | ForEach-Object { Stop-Process -Name $_ -Force -ErrorAction SilentlyContinue }
        Start-Sleep -Seconds 2
        $reg = "Windows Registry Editor Version 5.00`r`n`r`n[HKEY_LOCAL_MACHINE\AkariAppHive\LocalState\DisabledApps]`r`n" +
            (@('Microsoft.Paint_8wekyb3d8bbwe', 'Microsoft.Windows.Photos_8wekyb3d8bbwe', 'MicrosoftWindows.Client.CBS_cw5n1h2txyewy') | ForEach-Object { "`"$_`"=hex(5f5e10b):00,61,ed,11,34,f7,9f,dc,01`r`n" }) -join ''
        $dat = Join-Path (Get-AkariUserFolder 'Local AppData') 'Packages\MicrosoftWindows.Client.CBS_cw5n1h2txyewy\Settings\settings.dat'
        if (-not (Test-Path -LiteralPath $dat)) { return }
        if (-not (Import-AkariAppSettings 'MicrosoftWindows.Client.CBS_cw5n1h2txyewy' $reg)) { throw 'the Windows shell''s settings could not be opened' }
    }
}
