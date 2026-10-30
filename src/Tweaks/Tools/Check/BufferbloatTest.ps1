# Ported from AkariOS-Ultimate (FR33THY Ultimate) 7 Hardware "Network Bufferbloat Test".
# Action: it opens a web test; it changes nothing.
@{
    Id          = 'tools-bufferbloat-test'
    Name        = 'Network bufferbloat test'
    Section     = 'Tools'
    Category    = 'Check'
    Kind        = 'Action'
    Button      = 'Open'
    Risk        = 'Safe'
    Description = 'Opens Waveform''s bufferbloat test: how much your ping rises while the connection is busy.'
    Apply       = { Start-Process 'https://www.waveform.com/tools/bufferbloat' }
}
