# From ZOICWARE (https://github.com/zoicware/ZOICWARE, MIT) src\zFunctions.psm1 "Do not warn when closing multiple tabs
# in Terminal": confirmCloseAllTabs in the real user's Windows Terminal settings.json. The file may hold comments, so it
# is edited as text: Apply adds the line after the first "{" (or sets an existing one), Revert removes it (Windows
# Terminal's default is true). Unknown while Terminal has no settings file.
@{
    Id          = 'apps-terminal-no-close-tabs-warning'
    Name        = 'Windows Terminal: no warning when closing tabs'
    Section     = 'Customize'
    Category    = 'Apps'
    Risk        = 'Safe'
    Guided      = $false
    Description = 'Closing a Windows Terminal window with several tabs open no longer asks first.'
    Detect      = {
        . "$AkariTweakDir\Files\TerminalSettings.ps1"
        $text = Get-AkariTerminalSettings
        if ($null -eq $text) { return 'Unknown' }
        if ($text -match '"confirmCloseAllTabs"\s*:\s*false') { 'Optimized' } elseif ($text -match '"confirmCloseAllTabs"\s*:\s*(?!true)') { 'Custom' } else { 'Default' }
    }
    Apply       = { . "$AkariTweakDir\Files\TerminalSettings.ps1"; Set-AkariTerminalCloseTabs $true }
    Revert      = { . "$AkariTweakDir\Files\TerminalSettings.ps1"; Set-AkariTerminalCloseTabs $false }
}
