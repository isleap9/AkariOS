# Ported from AkariOS-Ultimate (FR33THY Ultimate) 6 Windows\4 Context Menu: the extra entries of the right-click menu
# (one topic Toggle). HKEY_CLASSES_ROOT's handlers live in HKLM\SOFTWARE\Classes; each removed one is a key row plus
# value rows holding Windows' own values, so Revert rebuilds it exactly (values first, the key last).
# "Add to Favorites" (*\shell\pintohomefile) exists only on Windows 11.
$c = 'HKLM:\SOFTWARE\Classes'
$verb = '{b455f46e-e4af-4035-b0a4-cf18d2f6f28e}'
$w11 = { param($v) @{ Win10 = $null; Win11 = $v } }
# a shell extension handler: the key and its (default) CLSID
$handler = { param($path, $clsid) @{ Path = $path; Name = '(default)'; Type = 'String'; Value = $null; Default = $clsid }; @{ Path = $path; Value = $null; Default = 'Key' } }
@{
    Id          = 'explorer-trim-context-menu'
    Name        = 'Trim the right-click menu'
    Section     = 'Customize'
    Category    = 'Explorer'
    Risk        = 'Safe'
    AkariOS     = $true
    Explorer    = $true
    Description = 'Removes Customize this folder, Pin to Quick access, Add to Favorites, Troubleshoot compatibility, Open in Terminal, Scan with Defender, Give access to, Include in library, Share, Restore previous versions and Send to.'
    Registry    = @(
        @{ Path = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer'; Name = 'NoCustomizeThisFolder'; Type = 'DWord'; Value = 1; Default = $null }
        @{ Path = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer'; Name = 'NoPreviousVersionsPage'; Type = 'DWord'; Value = 1; Default = $null }
        # Open in Terminal, Scan with Microsoft Defender, Give access to
        foreach ($g in '{9F156763-7844-4DC4-B2B1-901F640F5155}', '{09A47860-11B0-4DA5-AFA5-26D86198A780}', '{f81e9010-6ea4-11ce-a7ff-00aa003ca9f6}') {
            @{ Path = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Shell Extensions\Blocked'; Name = $g; Type = 'String'; Value = ''; Default = $null }
        }
        # Pin to Quick access
        @{ Path = "$c\Folder\shell\pintohome\command"; Name = 'DelegateExecute'; Type = 'String'; Value = $null; Default = $verb }
        @{ Path = "$c\Folder\shell\pintohome"; Name = 'AppliesTo'; Type = 'String'; Value = $null
           Default = 'System.ParsingName:<>"::{f874310e-b6b7-47dc-bc84-b9e6b38f5903}" AND System.ParsingName:<>"::{679f85cb-0220-4080-b29b-5540cc05aab6}" AND System.IsFolder:=System.StructuredQueryType.Boolean#True' }
        @{ Path = "$c\Folder\shell\pintohome"; Name = 'CommandStateHandler'; Type = 'String'; Value = $null; Default = $verb }
        @{ Path = "$c\Folder\shell\pintohome"; Name = 'CommandStateSync'; Type = 'String'; Value = $null; Default = '' }
        @{ Path = "$c\Folder\shell\pintohome"; Name = 'MUIVerb'; Type = 'String'; Value = $null; Default = '@shell32.dll,-51601' }
        @{ Path = "$c\Folder\shell\pintohome"; Name = 'SkipCloudDownload'; Type = 'DWord'; Value = $null; Default = 0 }
        @{ Path = "$c\Folder\shell\pintohome"; Value = $null; Default = 'Key' }
        # Add to Favorites (Windows 11)
        @{ Path = "$c\*\shell\pintohomefile\command"; Name = 'DelegateExecute'; Type = 'String'; Value = $null; Default = (& $w11 $verb) }
        @{ Path = "$c\*\shell\pintohomefile"; Name = 'CommandStateHandler'; Type = 'String'; Value = $null; Default = (& $w11 $verb) }
        @{ Path = "$c\*\shell\pintohomefile"; Name = 'CommandStateSync'; Type = 'String'; Value = $null; Default = (& $w11 '') }
        @{ Path = "$c\*\shell\pintohomefile"; Name = 'MUIVerb'; Type = 'String'; Value = $null; Default = (& $w11 '@shell32.dll,-51608') }
        @{ Path = "$c\*\shell\pintohomefile"; Name = 'NeverDefault'; Type = 'String'; Value = $null; Default = (& $w11 '') }
        @{ Path = "$c\*\shell\pintohomefile"; Name = 'SkipCloudDownload'; Type = 'DWord'; Value = $null; Default = (& $w11 0) }
        @{ Path = "$c\*\shell\pintohomefile"; Value = $null; Default = (& $w11 'Key') }
        # Troubleshoot compatibility, Include in library, Share, Send to
        & $handler "$c\exefile\shellex\ContextMenuHandlers\Compatibility" '{1d27f844-3a1f-4410-85ac-14651078412d}'
        & $handler "$c\Folder\ShellEx\ContextMenuHandlers\Library Location" '{3dad6c5d-2167-4cae-9914-f99e41c12cfa}'
        & $handler "$c\AllFilesystemObjects\shellex\ContextMenuHandlers\ModernSharing" '{e2bf9676-5f8f-435c-97eb-11607a5bedf7}'
        & $handler "$c\AllFilesystemObjects\shellex\ContextMenuHandlers\SendTo" '{7BA4C740-9E81-11CF-99D3-00AA004AE837}'
        & $handler "$c\UserLibraryFolder\shellex\ContextMenuHandlers\SendTo" '{7BA4C740-9E81-11CF-99D3-00AA004AE837}'
    )
}
