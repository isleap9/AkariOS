# ISO Builder removal group, ported from Tiny11 Builder (ntdevlabs, used with its developers' permission: ADR 0010,
# docs/permissions/tiny11builder.md) at commit 38f7ab6b1f177098c026a19b73ec84bca9c4b874: src/Tiny11Builder.Core/OfflineRegistry.cs (Core),
# CleanupCatalog.cs ("language-extras", "legacy-capabilities") and ImageOperations.cs TrimCore. Irreversible: the
# image can't be updated, serviced or repaired and has no recovery environment. Minimal mode only.
@{
    Name        = 'Core: no updates, Defender or recovery'
    Description = 'Windows Update and Defender turned off, speech / OCR / handwriting and retired accessories removed, the component store pruned to what boots and WinRE deleted. The image can never be updated, repaired or have features added.'
    Kind        = 'Setup'
    Risk        = 'Advanced'
    Order       = 20
    Capabilities = @('Language.Handwriting*', 'Language.OCR*', 'Language.Speech*', 'Language.TextToSpeech*', 'Microsoft.Windows.WordPad*', 'App.StepsRecorder*', 'MathRecognizer*', 'Media.WindowsMediaPlayer*', 'Microsoft.Windows.Wallpaper.Extended*')
    PruneComponentStore = $true
    Registry    = @(
        @{ Path = 'SYSTEM\ControlSet001\Services\wuauserv'; Name = 'Start'; Type = 'DWord'; Value = 4 }
        @{ Path = 'SYSTEM\ControlSet001\Services\UsoSvc'; Name = 'Start'; Type = 'DWord'; Value = 4 }
        @{ Path = 'SYSTEM\ControlSet001\Services\WaaSMedicSvc'; Name = 'Start'; Type = 'DWord'; Value = 4; Trusted = $true }
        @{ Path = 'SYSTEM\ControlSet001\Services\WinDefend'; Name = 'Start'; Type = 'DWord'; Value = 4; Trusted = $true }
        @{ Path = 'SYSTEM\ControlSet001\Services\WdNisSvc'; Name = 'Start'; Type = 'DWord'; Value = 4; Trusted = $true }
        @{ Path = 'SYSTEM\ControlSet001\Services\WdNisDrv'; Name = 'Start'; Type = 'DWord'; Value = 4; Trusted = $true }
        @{ Path = 'SYSTEM\ControlSet001\Services\WdFilter'; Name = 'Start'; Type = 'DWord'; Value = 4; Trusted = $true }
        @{ Path = 'SYSTEM\ControlSet001\Services\Sense'; Name = 'Start'; Type = 'DWord'; Value = 4; Trusted = $true }
        @{ Path = 'SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU'; Name = 'NoAutoUpdate'; Type = 'DWord'; Value = 1 }
        @{ Path = 'SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate'; Name = 'DisableWindowsUpdateAccess'; Type = 'DWord'; Value = 1 }
        @{ Path = 'SOFTWARE\Policies\Microsoft\Windows Defender'; Name = 'DisableAntiSpyware'; Type = 'DWord'; Value = 1 }
        @{ Path = 'SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection'; Name = 'DisableRealtimeMonitoring'; Type = 'DWord'; Value = 1 }
    )
    Remove      = @('Windows\System32\Recovery\winre.wim')
}
