# From ZOICWARE (https://github.com/zoicware/ZOICWARE, MIT) src\RegTweaks.txt "Disable auto correction".
@{
    Id          = 'input-no-autocorrect'
    Name        = 'No autocorrect'
    Section     = 'Customize'
    Category    = 'Input'
    Risk        = 'Safe'
    Guided      = $false
    Description = 'Windows stops correcting misspelled words as you type with the touch keyboard or a hardware keyboard''s text suggestions.'
    Registry    = @(
        @{ Path = 'HKCU:\Software\Microsoft\TabletTip\1.7'; Name = 'EnableAutocorrection'; Type = 'DWord'; Value = 0; Default = $null }
    )
}
