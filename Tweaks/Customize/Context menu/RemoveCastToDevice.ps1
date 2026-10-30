# From ZOICWARE (https://github.com/zoicware/ZOICWARE, MIT) src\zFunctions.psm1 "Cast to Device": its handler blocked.
# Revert deletes the block (Windows blocks nothing there).
@{
    Id          = 'context-remove-cast-to-device'
    Name        = 'Remove Cast to Device'
    Section     = 'Customize'
    Category    = 'Context menu'
    Risk        = 'Safe'
    Guided      = $false
    Explorer    = $true
    Description = 'Right-clicking a picture, video or song no longer shows Cast to Device.'
    Registry    = @(
        @{ Path = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Shell Extensions\Blocked'; Name = '{7AD84985-87B4-4a16-BE58-8B72A5B390F7}'; Type = 'String'; Value = ' '; Default = $null }
    )
}
