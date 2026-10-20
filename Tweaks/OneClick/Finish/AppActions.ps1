# One-click's steptwo.ps1 (isleap9/Akari-OS): "disable app actions" (Paint, Photos and the Windows shell offering
# actions on files). Values in the shell's own settings hive (Import-AkariAppSettings).
# Action: the hive has no Default
# Akari can read back.
@{
    Id          = 'oneclick-app-actions'
    Name        = 'Turn off app actions'
    Section     = 'OneClick'
    Category    = 'Finish'
    Kind        = 'Action'
    Risk        = 'Safe'
    Requires    = 'Win11'
    Description = 'Settings > Apps > Actions: Paint, Photos and Windows stop offering their actions on files.'
    Apply       = {
        # the shell host (MicrosoftWindows.Client.CBS) keeps its hive open while these run
        'AppActions', 'CrossDeviceResume', 'DesktopStickerEditorWin32Exe', 'DiscoveryHubApp', 'FESearchHost', 'SearchHost', 'SoftLandingTask',
            'TextInputHost', 'VisualAssistExe', 'WebExperienceHostApp', 'WindowsBackupClient', 'WindowsMigration' | ForEach-Object { Stop-Process -Name $_ -Force -ErrorAction SilentlyContinue }
        Start-Sleep -Seconds 2
        $reg = "Windows Registry Editor Version 5.00`r`n`r`n[HKEY_LOCAL_MACHINE\AkariAppHive\LocalState\DisabledApps]`r`n" +
            "`"Microsoft.Paint_8wekyb3d8bbwe`"=hex(5f5e10b):01,61,ed,11,34,f7,9f,dc,01`r`n" +
            "`"Microsoft.Windows.Photos_8wekyb3d8bbwe`"=hex(5f5e10b):01,61,ed,11,34,f7,9f,dc,01`r`n" +
            "`"MicrosoftWindows.Client.CBS_cw5n1h2txyewy`"=hex(5f5e10b):01,61,ed,11,34,f7,9f,dc,01`r`n"
        if (-not (Import-AkariAppSettings 'MicrosoftWindows.Client.CBS_cw5n1h2txyewy' $reg)) { 'The Windows shell has no settings file yet: nothing to change' }
    }
}
