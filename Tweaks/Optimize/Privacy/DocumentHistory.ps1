# From ZOICWARE (https://github.com/zoicware/ZOICWARE, MIT) src\RegTweaks.txt "No document history tracking".
@{
    Id          = 'privacy-no-document-history'
    Name        = 'Don''t keep a list of recent documents'
    Section     = 'Optimize'
    Category    = 'Privacy'
    Risk        = 'Safe'
    Guided      = $false
    Description = 'Group policy stops Windows from keeping your recently opened files (Recent folder, jump lists) and clears the list when you sign out.'
    Registry    = @(
        @{ Path = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer'; Name = 'NoRecentDocsHistory'; Type = 'DWord'; Value = 1; Default = $null }
        @{ Path = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer'; Name = 'ClearRecentDocsOnExit'; Type = 'DWord'; Value = 1; Default = $null }
    )
}
