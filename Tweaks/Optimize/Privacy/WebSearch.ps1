# Ported from AkariOS-Ultimate (FR33THY Ultimate) 6 Windows\22 Control Panel Settings.
@{
    Id          = 'privacy-web-search'
    Name        = 'No web results in search'
    Section     = 'Optimize'
    Category    = 'Privacy'
    Risk        = 'Safe'
    AkariOS     = $true
    Description = 'Start and taskbar search look only on this PC, not on Bing.'
    Registry    = @(
        @{ Path = 'HKCU:\Software\Policies\Microsoft\Windows\Explorer'; Name = 'DisableSearchBoxSuggestions'; Type = 'DWord'; Value = 1; Default = $null }
    )
}
