# From ZOICWARE (https://github.com/zoicware/ZOICWARE, MIT) src\RegTweaks.txt "Disable XBOX capture": the policy value
# (gaming-capture-off owns the rest).
@{
    Id          = 'gaming-dvr-policy-off'
    Name        = 'Block game recording by policy'
    Section     = 'Optimize'
    Category    = 'Gaming'
    Risk        = 'Safe'
    Guided      = $false
    Description = 'Group policy turns off Windows game recording and broadcasting for every user, so Game Bar captures can''t be switched back on.'
    Registry    = @(
        @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR'; Name = 'AllowGameDVR'; Type = 'DWord'; Value = 0; Default = $null }
    )
}
