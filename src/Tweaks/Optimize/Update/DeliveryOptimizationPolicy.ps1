# From ZOICWARE (https://github.com/zoicware/ZOICWARE, MIT) src\RegTweaks.txt "Disable delivery optimization": the policy
# value (update-delivery-optimization sets the service's own setting).
@{
    Id          = 'update-delivery-optimization-policy'
    Name        = 'Block update sharing by policy'
    Section     = 'Optimize'
    Category    = 'Update'
    Risk        = 'Caution'
    Guided      = $false
    Description = 'Group policy makes Windows download updates only from Microsoft, never from or to other PCs, and locks the setting.'
    Registry    = @(
        @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization'; Name = 'DODownloadMode'; Type = 'DWord'; Value = 0; Default = $null }
    )
}
