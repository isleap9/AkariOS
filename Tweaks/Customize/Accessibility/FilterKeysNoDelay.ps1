# From ZOICWARE (https://github.com/zoicware/ZOICWARE, MIT) src\RegTweaks.txt "Disable filter keys": the value
# accessibility-shortcuts-off doesn't set.
@{
    Id          = 'accessibility-filter-keys-no-delay'
    Name        = 'Filter Keys accepts keys at once'
    Section     = 'Customize'
    Category    = 'Accessibility'
    Risk        = 'Safe'
    Guided      = $false
    Description = 'If Filter Keys gets turned on, a key press counts right away instead of after being held for a second.'
    Registry    = @(
        @{ Path = 'HKCU:\Control Panel\Accessibility\Keyboard Response'; Name = 'DelayBeforeAcceptance'; Type = 'String'; Value = '0'; Default = '1000' }
    )
}
