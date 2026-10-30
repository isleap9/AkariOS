# From ZOICWARE (https://github.com/zoicware/ZOICWARE, MIT) src\zFunctions.psm1 "Do not show uninstall app warning":
# the dialog's "don't show again" answer. Revert deletes it.
@{
    Id          = 'explorer-no-uninstall-dialog'
    Name        = 'No "uninstall this app" question'
    Section     = 'Customize'
    Category    = 'Explorer'
    Risk        = 'Safe'
    Guided      = $false
    Description = 'Uninstall from the Start menu or search starts right away, without asking whether this app and its info will be uninstalled.'
    Registry    = @(
        @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\DontShowMeThisDialogAgain'; Name = '{948e51fb-0a48-44f0-86ac-33c36def540c}'; Type = 'String'; Value = 'NO'; Default = $null }
    )
}
