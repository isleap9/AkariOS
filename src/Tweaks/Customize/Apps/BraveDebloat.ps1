# Ported from Chris Titus Tech's winutil (MIT, Copyright (c) 2022 CT Tech Group LLC), config/tweaks.json "WPFTweaksBraveDebloat".
@{
    Id          = 'apps-brave-debloat'
    Name        = 'Brave: no Rewards, Wallet, VPN, Leo, News or stats'
    Section     = 'Customize'
    Category    = 'Apps'
    Risk        = 'Safe'
    Guided      = $false
    Description = 'Group policies turn off Brave''s Rewards, Wallet, VPN, Leo AI chat, News, Talk and Tor windows, and its usage pings and metrics.'
    Registry    = @(
        @{ Path = 'HKLM:\SOFTWARE\Policies\BraveSoftware\Brave'; Name = 'BraveRewardsDisabled'; Type = 'DWord'; Value = 1; Default = $null }
        @{ Path = 'HKLM:\SOFTWARE\Policies\BraveSoftware\Brave'; Name = 'BraveWalletDisabled'; Type = 'DWord'; Value = 1; Default = $null }
        @{ Path = 'HKLM:\SOFTWARE\Policies\BraveSoftware\Brave'; Name = 'BraveVPNDisabled'; Type = 'DWord'; Value = 1; Default = $null }
        @{ Path = 'HKLM:\SOFTWARE\Policies\BraveSoftware\Brave'; Name = 'BraveAIChatEnabled'; Type = 'DWord'; Value = 0; Default = $null }
        @{ Path = 'HKLM:\SOFTWARE\Policies\BraveSoftware\Brave'; Name = 'BraveStatsPingEnabled'; Type = 'DWord'; Value = 0; Default = $null }
        @{ Path = 'HKLM:\SOFTWARE\Policies\BraveSoftware\Brave'; Name = 'BraveNewsDisabled'; Type = 'DWord'; Value = 1; Default = $null }
        @{ Path = 'HKLM:\SOFTWARE\Policies\BraveSoftware\Brave'; Name = 'BraveTalkDisabled'; Type = 'DWord'; Value = 1; Default = $null }
        @{ Path = 'HKLM:\SOFTWARE\Policies\BraveSoftware\Brave'; Name = 'TorDisabled'; Type = 'DWord'; Value = 1; Default = $null }
        @{ Path = 'HKLM:\SOFTWARE\Policies\BraveSoftware\Brave'; Name = 'BraveP3AEnabled'; Type = 'DWord'; Value = 0; Default = $null }
        @{ Path = 'HKLM:\SOFTWARE\Policies\BraveSoftware\Brave'; Name = 'UrlKeyedAnonymizedDataCollectionEnabled'; Type = 'DWord'; Value = 0; Default = $null }
        @{ Path = 'HKLM:\SOFTWARE\Policies\BraveSoftware\Brave'; Name = 'SafeBrowsingExtendedReportingEnabled'; Type = 'DWord'; Value = 0; Default = $null }
        @{ Path = 'HKLM:\SOFTWARE\Policies\BraveSoftware\Brave'; Name = 'MetricsReportingEnabled'; Type = 'DWord'; Value = 0; Default = $null }
    )
}
