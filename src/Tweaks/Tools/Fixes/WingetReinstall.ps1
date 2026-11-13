# Ported from Chris Titus Tech's winutil (MIT), functions/public/Invoke-WPFFixesWinget.ps1, through Akari's own
# winget repair (Install-AkariWingetTool -Force: App Installer from winget-cli's latest release).
# Action: a reinstall has no Default to go back to.
@{
    Id          = 'tools-fix-winget'
    Name        = 'WinGet reinstall'
    Section     = 'Tools'
    Category    = 'Fixes'
    Kind        = 'Action'
    Button      = 'Reinstall'
    Risk        = 'Safe'
    Description = 'Installs App Installer (winget) again from Microsoft''s winget-cli release, for a winget that is broken or won''t install apps.'
    Apply       = { Install-AkariWingetTool -Force }
}
