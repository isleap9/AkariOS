# From ZOICWARE (https://github.com/zoicware/ZOICWARE, MIT) src\zFunctions.psm1 "Do not show restart required in
# MSConfig": the dialog's "don't show again" answer. Revert deletes it.
@{
    Id          = 'system-msconfig-no-restart-prompt'
    Name        = 'No restart prompt in System Configuration'
    Section     = 'Customize'
    Category    = 'System'
    Risk        = 'Safe'
    Guided      = $false
    Description = 'Closing System Configuration (msconfig) after a change no longer asks to restart now.'
    Registry    = @(
        @{ Path = 'HKCU:\Software\Microsoft\Shared Tools\MsConfig'; Name = 'NoRebootUI'; Type = 'DWord'; Value = 1; Default = $null }
    )
}
