# From ZOICWARE (https://github.com/zoicware/ZOICWARE, MIT) src\UltimateContextMenu\Snipping11.reg "Snipping Tool": a
# desktop submenu. One Tweak for both Windows versions (ms-screenclip works on Windows 10 too); ZOICWARE's Windows 10 file
# (the old SnippingTool.exe /clip) is not used. Revert deletes the key.
$k = 'HKLM:\SOFTWARE\Classes\DesktopBackground\Shell\SnippingTool'
@{
    Id          = 'context-add-snipping-tool'
    Name        = 'Add Snipping Tool to the desktop menu'
    Section     = 'Customize'
    Category    = 'Context menu'
    Risk        = 'Safe'
    Guided      = $false
    Description = 'Right-clicking the desktop shows a Snipping Tool submenu: take a screen snip or open the Snipping Tool.'
    Registry    = @(
        @{ Path = $k; Name = 'MUIVerb'; Type = 'String'; Value = '@SnippingTool.exe,-101'; Default = $null }
        @{ Path = $k; Name = 'Icon'; Type = 'String'; Value = 'SnippingTool.exe'; Default = $null }
        @{ Path = $k; Name = 'Position'; Type = 'String'; Value = 'Bottom'; Default = $null }
        @{ Path = $k; Name = 'SubCommands'; Type = 'String'; Value = ''; Default = $null }
        @{ Path = "$k\shell\Screen Snip"; Name = 'MUIVerb'; Type = 'String'; Value = '@SnippingTool.exe,-15052'; Default = $null }
        @{ Path = "$k\shell\Screen Snip"; Name = 'Icon'; Type = 'String'; Value = 'SnippingTool.exe'; Default = $null }
        @{ Path = "$k\shell\Screen Snip\Command"; Name = '(default)'; Type = 'String'; Value = 'explorer.exe ms-screenclip:'; Default = $null }
        @{ Path = "$k\shell\SnippingTool"; Name = 'MUIVerb'; Type = 'String'; Value = '@SnippingTool.exe,-101'; Default = $null }
        @{ Path = "$k\shell\SnippingTool"; Name = 'Icon'; Type = 'String'; Value = 'SnippingTool.exe'; Default = $null }
        @{ Path = "$k\shell\SnippingTool\Command"; Name = '(default)'; Type = 'String'; Value = 'cmd.exe /c SnippingTool'; Default = $null }
        @{ Path = $k; Value = 'Key'; Default = $null }
    )
}
