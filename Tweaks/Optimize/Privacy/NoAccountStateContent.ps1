# From ZOICWARE (https://github.com/zoicware/ZOICWARE, MIT) src\zFunctions.psm1 "Hide Ads In Settings": only its
# DisableConsumerAccountStateContent policy (its edit of a Windows file, SettingsExtensions.json, has no stock copy to
# put back). Revert deletes the policy.
@{
    Id          = 'privacy-no-account-state-content'
    Name        = 'No account promotions in Settings and Start'
    Section     = 'Optimize'
    Category    = 'Privacy'
    Risk        = 'Safe'
    Guided      = $false
    Description = 'Settings and Start stop showing Microsoft account, OneDrive and Game Pass cards about your account''s state (sign in, back up, subscribe).'
    Registry    = @(
        @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent'; Name = 'DisableConsumerAccountStateContent'; Type = 'DWord'; Value = 1; Default = $null }
    )
}
