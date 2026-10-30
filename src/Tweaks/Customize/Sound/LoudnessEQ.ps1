# Action: it unhides a tab in Sound settings; Windows has no "hidden" state to go back to once a driver shows it.
# Ported from AkariOS-Ultimate (FR33THY Ultimate) 6 Windows\24 Loudness EQ (without the pause and the Sound window).
@{
    Id          = 'sound-loudness-eq-tab'
    Name        = 'Show the Enhancements tab (loudness equalization)'
    Section     = 'Customize'
    Category    = 'Sound'
    Kind        = 'Action'
    Button      = 'Show'
    Risk        = 'Caution'
    Description = 'Unhides Enhancements in each playback device''s properties (mmsys.cpl), where Loudness Equalization lives. Audio stops for a moment. If it misbehaves, roll back the audio driver.'
    Apply       = {
        Stop-Service -Name 'audiosrv' -Force
        Stop-Service -Name 'AudioEndpointBuilder' -Force
        try {
            foreach ($d in @(Get-ChildItem (Resolve-AkariRegPath 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\MMDevices\Audio\Render') -ErrorAction SilentlyContinue)) {
                $fx = Join-Path $d.PSPath 'FxProperties'
                if (-not (Test-Path -LiteralPath $fx)) { New-Item -Path $fx -Force -ErrorAction SilentlyContinue | Out-Null }
                New-ItemProperty -LiteralPath $fx -Name '{d04e05a6-594b-4fb6-a80d-01af5eed7d1d},3' -Value '{5860E1C5-F95C-4a7a-8EC8-8AEF24F379A1}' -PropertyType String -Force -ErrorAction SilentlyContinue | Out-Null
            }
        } finally {
            Start-Service -Name 'AudioEndpointBuilder'
            Start-Service -Name 'audiosrv'
        }
    }
}
