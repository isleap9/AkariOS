# Ported from Chris Titus Tech's winutil (MIT), functions/public/Invoke-WPFPanelAutologin.ps1: Sysinternals Autologon,
# from winget (winutil downloads it from live.sysinternals.com each time).
# Action: it opens a tool; the tool makes the change (and turns it off again).
@{
    Id          = 'tools-autologon'
    Name        = 'AutoLogon'
    Section     = 'Tools'
    Category    = 'Fixes'
    Kind        = 'Action'
    Button      = 'Open'
    Risk        = 'Caution'
    Description = 'Opens Sysinternals Autologon (installed first if missing): signs Windows in to your account by itself at startup. The password is stored encrypted by Windows (LSA).'
    Apply       = { Open-AkariWingetTool 'Microsoft.Sysinternals.Autologon' 'Autologon64.exe' }
}
