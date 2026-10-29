# From ZOICWARE (https://github.com/zoicware/ZOICWARE, MIT) src\RegTweaks.txt "Disable show recently added apps and
# recommendations": the policy values the start-hide-* Tweaks don't set.
@{
    Id          = 'start-recommendations-policy'
    Name        = 'No app tracking or recommended sites in Start (policy)'
    Section     = 'Customize'
    Category    = 'Start'
    Risk        = 'Safe'
    Guided      = $false
    Explorer    = $true
    Description = 'Group policies that turn off the most-used apps list, Windows'' tracking of the programs you open, and recommended websites in Start, for every user.'
    Registry    = @(
        @{ Path = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer'; Name = 'NoInstrumentation'; Type = 'DWord'; Value = 1; Default = $null }
        @{ Path = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer'; Name = 'NoStartMenuMFUprogramsList'; Type = 'DWord'; Value = 1; Default = $null }
        @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer'; Name = 'HideRecommendedPersonalizedSites'; Type = 'DWord'; Value = 1; Default = $null }
    )
}
