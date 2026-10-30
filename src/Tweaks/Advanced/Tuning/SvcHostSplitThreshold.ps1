# "Match RAM" from the old tuner is not a fixed value: any threshold at or above installed RAM means no split,
# so No split (0xFFFFFFFF) is Recommended and the field stays editable for a typed KB value.
@{
    Id          = 'svchost-split-threshold'
    Name        = 'SvcHost split threshold'
    Section     = 'Advanced'
    Category    = 'Tuning'
    Kind        = 'Choice'
    Risk        = 'Safe'
    Reboot      = $true
    Description = 'How many svchost.exe processes Windows creates. Merging them saves memory, but one crash takes more services down.'
    Registry    = @{ Path = 'HKLM:\SYSTEM\CurrentControlSet\Control'; Name = 'SvcHostSplitThresholdInKB'; Type = 'DWord' }
    Choices     = @(
        @{ Value = 3670016; Label = '3.5 GB' }
        @{ Value = 4294967295; Label = 'No split' }
    )
    Editable    = $true
    Recommended = 4294967295
    Default     = 3670016
}
