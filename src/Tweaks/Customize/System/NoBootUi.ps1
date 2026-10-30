# From ZOICWARE (https://github.com/zoicware/ZOICWARE, MIT) src\zFunctions.psm1 "Enable No GUI Boot": bootuxdisabled in
# the boot store's {globalsettings}. Revert deletes it (Windows sets nothing there). Detect: the setting present =
# Optimized (bcdedit prints its Yes / No in the system language).
@{
    Id          = 'system-no-boot-ui'
    Name        = 'No boot animation'
    Section     = 'Customize'
    Category    = 'System'
    Risk        = 'Safe'
    Guided      = $false
    Reboot      = $true
    Description = 'Windows starts without the spinning dots and logo: the screen stays black until the sign-in screen.'
    Detect      = { if (@(Read-AkariBcd '{globalsettings}' | Where-Object { $_ -match '^bootuxdisabled\s' }).Count) { 'Optimized' } else { 'Default' } }
    Apply       = { if ((Invoke-AkariBcdEdit '/set {globalsettings} bootuxdisabled on') -ne 0) { throw 'bcdedit could not change the boot settings' } }
    Revert      = { [void](Invoke-AkariBcdEdit '/deletevalue {globalsettings} bootuxdisabled') }
}
