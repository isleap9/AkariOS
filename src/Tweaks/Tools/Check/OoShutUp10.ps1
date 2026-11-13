# Ported from Chris Titus Tech's winutil (MIT, Copyright (c) 2022 CT Tech Group LLC), config/tweaks.json "WPFOOSUbutton"
# (O&O ShutUp10++, now from winget).
# Action: it opens a tool; it changes nothing.
@{
    Id          = 'tools-oosu10'
    Name        = 'O&O ShutUp10++'
    Section     = 'Tools'
    Category    = 'Check'
    Kind        = 'Action'
    Button      = 'Check'
    Risk        = 'Safe'
    Description = 'Opens O&O ShutUp10++ (installed first if missing): every Windows privacy setting in one list, to check what is still on.'
    Apply       = { Open-AkariWingetTool 'OO-Software.ShutUp10' 'OOSU10.exe' }
}
