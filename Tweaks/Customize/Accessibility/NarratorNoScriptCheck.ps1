# From ZOICWARE (https://github.com/zoicware/ZOICWARE, MIT) src\RegTweaks.txt "Disable narrator": the value
# accessibility-shortcuts-off doesn't set.
@{
    Id          = 'accessibility-narrator-no-script-check'
    Name        = 'Narrator doesn''t check for scripts'
    Section     = 'Customize'
    Category    = 'Accessibility'
    Risk        = 'Safe'
    Guided      = $false
    Description = 'Narrator stops looking online for new scripts when it starts.'
    Registry    = @(
        @{ Path = 'HKCU:\Software\Microsoft\Narrator\NoRoam'; Name = 'CheckForScriptsEnabled'; Type = 'DWord'; Value = 0; Default = $null }
    )
}
