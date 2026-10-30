# Ported from AkariOS-Ultimate (FR33THY Ultimate) 7 Hardware "Monitor Optimization" (TestUFO and its checklist).
# Action: it opens a web test; it changes nothing.
@{
    Id          = 'tools-monitor-test'
    Name        = 'Monitor test (TestUFO)'
    Section     = 'Tools'
    Category    = 'Check'
    Kind        = 'Action'
    Button      = 'Open'
    Risk        = 'Safe'
    Description = 'Opens TestUFO to check motion clarity while you tune the monitor''s own menu; the console lists what to change.'
    Apply       = {
        foreach ($l in 'In the monitor''s menu:', '- turn on its overclock mode and run the highest refresh rate',
            '- turn off adaptive brightness and variable backlight',
            '- turn off variable refresh rate (adaptive sync, G-Sync) if you play with a frame cap',
            '- overdrive as high as it goes without overshoot (bright trails behind the UFO)',
            '- colour, brightness and sharpening to taste') { Write-Log $l }
        Start-Process 'https://www.testufo.com/framerates#count=6&background=none&pps=1920'
    }
}
