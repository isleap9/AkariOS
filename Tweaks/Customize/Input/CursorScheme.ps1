# Ported from AkariOS-Ultimate (FR33THY Ultimate) 6 Windows\22 Control Panel Settings.
@{
    Id          = 'input-no-cursor-scheme'
    Name        = 'Plain mouse pointers'
    Section     = 'Customize'
    Category    = 'Input'
    Risk        = 'Safe'
    AkariOS     = $true
    Description = 'The "None" pointer scheme (Windows'' basic pointers), no touch and pen feedback.'
    Registry    = @(
        @{ Path = 'HKCU:\Control Panel\Cursors'; Name = 'AppStarting'; Type = 'ExpandString'; Value = ''; Default = 'C:\Windows\cursors\aero_working.ani' }
        @{ Path = 'HKCU:\Control Panel\Cursors'; Name = 'Arrow'; Type = 'ExpandString'; Value = ''; Default = 'C:\Windows\cursors\aero_arrow.cur' }
        @{ Path = 'HKCU:\Control Panel\Cursors'; Name = 'ContactVisualization'; Type = 'DWord'; Value = 0; Default = 1 }
        @{ Path = 'HKCU:\Control Panel\Cursors'; Name = 'GestureVisualization'; Type = 'DWord'; Value = 0; Default = 31 }
        @{ Path = 'HKCU:\Control Panel\Cursors'; Name = 'Hand'; Type = 'ExpandString'; Value = ''; Default = 'C:\Windows\cursors\aero_link.cur' }
        @{ Path = 'HKCU:\Control Panel\Cursors'; Name = 'Help'; Type = 'ExpandString'; Value = ''; Default = 'C:\Windows\cursors\aero_helpsel.cur' }
        @{ Path = 'HKCU:\Control Panel\Cursors'; Name = 'No'; Type = 'ExpandString'; Value = ''; Default = 'C:\Windows\cursors\aero_unavail.cur' }
        @{ Path = 'HKCU:\Control Panel\Cursors'; Name = 'NWPen'; Type = 'ExpandString'; Value = ''; Default = 'C:\Windows\cursors\aero_pen.cur' }
        @{ Path = 'HKCU:\Control Panel\Cursors'; Name = 'Scheme Source'; Type = 'DWord'; Value = 0; Default = 2 }
        @{ Path = 'HKCU:\Control Panel\Cursors'; Name = 'SizeAll'; Type = 'ExpandString'; Value = ''; Default = 'C:\Windows\cursors\aero_move.cur' }
        @{ Path = 'HKCU:\Control Panel\Cursors'; Name = 'SizeNESW'; Type = 'ExpandString'; Value = ''; Default = 'C:\Windows\cursors\aero_nesw.cur' }
        @{ Path = 'HKCU:\Control Panel\Cursors'; Name = 'SizeNS'; Type = 'ExpandString'; Value = ''; Default = 'C:\Windows\cursors\aero_ns.cur' }
        @{ Path = 'HKCU:\Control Panel\Cursors'; Name = 'SizeNWSE'; Type = 'ExpandString'; Value = ''; Default = 'C:\Windows\cursors\aero_nwse.cur' }
        @{ Path = 'HKCU:\Control Panel\Cursors'; Name = 'SizeWE'; Type = 'ExpandString'; Value = ''; Default = 'C:\Windows\cursors\aero_ew.cur' }
        @{ Path = 'HKCU:\Control Panel\Cursors'; Name = 'UpArrow'; Type = 'ExpandString'; Value = ''; Default = 'C:\Windows\cursors\aero_up.cur' }
        @{ Path = 'HKCU:\Control Panel\Cursors'; Name = 'Wait'; Type = 'ExpandString'; Value = ''; Default = 'C:\Windows\cursors\aero_busy.ani' }
        @{ Path = 'HKCU:\Control Panel\Cursors'; Name = '(default)'; Type = 'String'; Value = ''; Default = 'Windows Default' }
    )
}
