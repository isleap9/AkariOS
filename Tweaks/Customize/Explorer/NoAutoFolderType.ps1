# From ZOICWARE (https://github.com/zoicware/ZOICWARE, MIT) src\RegTweaks.txt "Disable Windows automatic folder type".
@{
    Id          = 'explorer-no-auto-folder-type'
    Name        = 'No automatic folder type'
    Section     = 'Customize'
    Category    = 'Explorer'
    Risk        = 'Safe'
    Guided      = $false
    Explorer    = $true
    Description = 'File Explorer stops guessing a folder''s type (Pictures, Music, Videos) from its files, so big folders open faster and keep the same columns.'
    Registry    = @(
        @{ Path = 'HKCU:\Software\Classes\Local Settings\Software\Microsoft\Windows\Shell\Bags\AllFolders\Shell'; Name = 'FolderType'; Type = 'String'; Value = 'NotSpecified'; Default = $null }
    )
}
