# Ported from AkariOS-Ultimate (FR33THY Ultimate) 6 Windows\22 Control Panel Settings.
@{
    Id          = 'gaming-capture-off'
    Name        = 'Game Bar captures off'
    Section     = 'Optimize'
    Category    = 'Gaming'
    Risk        = 'Safe'
    AkariOS     = $true
    Description = 'No background recording, no capture shortcuts (Win+Alt+R and the rest), no microphone or cursor in captures.'
    Registry    = @(
        @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR'; Name = 'AppCaptureEnabled'; Type = 'DWord'; Value = 0; Default = $null }
        @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR'; Name = 'AudioEncodingBitrate'; Type = 'DWord'; Value = 128000; Default = $null }
        @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR'; Name = 'AudioCaptureEnabled'; Type = 'DWord'; Value = 0; Default = $null }
        @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR'; Name = 'CustomVideoEncodingBitrate'; Type = 'DWord'; Value = 4000000; Default = $null }
        @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR'; Name = 'CustomVideoEncodingHeight'; Type = 'DWord'; Value = 720; Default = $null }
        @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR'; Name = 'CustomVideoEncodingWidth'; Type = 'DWord'; Value = 1280; Default = $null }
        @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR'; Name = 'HistoricalBufferLength'; Type = 'DWord'; Value = 30; Default = $null }
        @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR'; Name = 'HistoricalBufferLengthUnit'; Type = 'DWord'; Value = 1; Default = $null }
        @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR'; Name = 'HistoricalCaptureEnabled'; Type = 'DWord'; Value = 0; Default = $null }
        @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR'; Name = 'HistoricalCaptureOnBatteryAllowed'; Type = 'DWord'; Value = 1; Default = $null }
        @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR'; Name = 'HistoricalCaptureOnWirelessDisplayAllowed'; Type = 'DWord'; Value = 1; Default = $null }
        @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR'; Name = 'MaximumRecordLength'; Type = 'QWord'; Value = [uint64]72000000000; Default = $null }
        @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR'; Name = 'VideoEncodingBitrateMode'; Type = 'DWord'; Value = 2; Default = $null }
        @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR'; Name = 'VideoEncodingResolutionMode'; Type = 'DWord'; Value = 2; Default = $null }
        @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR'; Name = 'VideoEncodingFrameRateMode'; Type = 'DWord'; Value = 0; Default = $null }
        @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR'; Name = 'EchoCancellationEnabled'; Type = 'DWord'; Value = 1; Default = $null }
        @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR'; Name = 'CursorCaptureEnabled'; Type = 'DWord'; Value = 0; Default = $null }
        @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR'; Name = 'VKToggleGameBar'; Type = 'DWord'; Value = 0; Default = $null }
        @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR'; Name = 'VKMToggleGameBar'; Type = 'DWord'; Value = 0; Default = $null }
        @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR'; Name = 'VKSaveHistoricalVideo'; Type = 'DWord'; Value = 0; Default = $null }
        @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR'; Name = 'VKMSaveHistoricalVideo'; Type = 'DWord'; Value = 0; Default = $null }
        @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR'; Name = 'VKToggleRecording'; Type = 'DWord'; Value = 0; Default = $null }
        @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR'; Name = 'VKMToggleRecording'; Type = 'DWord'; Value = 0; Default = $null }
        @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR'; Name = 'VKTakeScreenshot'; Type = 'DWord'; Value = 0; Default = $null }
        @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR'; Name = 'VKMTakeScreenshot'; Type = 'DWord'; Value = 0; Default = $null }
        @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR'; Name = 'VKToggleRecordingIndicator'; Type = 'DWord'; Value = 0; Default = $null }
        @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR'; Name = 'VKMToggleRecordingIndicator'; Type = 'DWord'; Value = 0; Default = $null }
        @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR'; Name = 'VKToggleMicrophoneCapture'; Type = 'DWord'; Value = 0; Default = $null }
        @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR'; Name = 'VKMToggleMicrophoneCapture'; Type = 'DWord'; Value = 0; Default = $null }
        @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR'; Name = 'VKToggleCameraCapture'; Type = 'DWord'; Value = 0; Default = $null }
        @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR'; Name = 'VKMToggleCameraCapture'; Type = 'DWord'; Value = 0; Default = $null }
        @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR'; Name = 'VKToggleBroadcast'; Type = 'DWord'; Value = 0; Default = $null }
        @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR'; Name = 'VKMToggleBroadcast'; Type = 'DWord'; Value = 0; Default = $null }
        @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR'; Name = 'MicrophoneCaptureEnabled'; Type = 'DWord'; Value = 0; Default = $null }
        @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR'; Name = 'SystemAudioGain'; Type = 'QWord'; Value = [uint64]10000; Default = $null }
        @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR'; Name = 'MicrophoneGain'; Type = 'QWord'; Value = [uint64]10000; Default = $null }
    )
}
