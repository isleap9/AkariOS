# From ZOICWARE (https://github.com/zoicware/ZOICWARE, MIT) src\zFunctions.psm1 "Check \"Do this for all items\" in
# Explorer": the checkbox's starting state. Revert deletes it.
@{
    Id          = 'explorer-do-for-all-items'
    Name        = 'Tick "Do this for all items" by default'
    Section     = 'Customize'
    Category    = 'Explorer'
    Risk        = 'Safe'
    Guided      = $false
    Description = 'When copying or moving many files runs into conflicts, "Do this for all conflicts" is already ticked.'
    Registry    = @(
        @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\OperationStatusManager'; Name = 'ConfirmationCheckBoxDoForAll'; Type = 'DWord'; Value = 1; Default = $null }
    )
}
