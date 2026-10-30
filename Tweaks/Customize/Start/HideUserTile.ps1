# From ZOICWARE (https://github.com/zoicware/ZOICWARE, MIT) src\zFunctions.psm1 "Hide User Tile In Start Menu": the
# Start policy's device value (Windows has it at 0).
@{
    Id          = 'start-hide-user-tile'
    Name        = 'Hide the account button in Start'
    Section     = 'Customize'
    Category    = 'Start'
    Risk        = 'Safe'
    Guided      = $false
    Explorer    = $true
    Description = 'Start no longer shows your account picture and name (sign out and lock stay on the power button and Ctrl+Alt+Del).'
    Registry    = @(
        @{ Path = 'HKLM:\SOFTWARE\Microsoft\PolicyManager\default\Start\HideUserTile'; Name = 'value'; Type = 'DWord'; Value = 1; Default = 0 }
    )
}
