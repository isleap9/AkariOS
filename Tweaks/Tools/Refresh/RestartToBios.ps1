# Ported from AkariOS-Ultimate (FR33THY Ultimate) 2 Refresh "To Bios" (shutdown /r /fw, through Restart-AkariFirmware).
# Action: a restart; there is nothing to revert.
@{
    Id          = 'tools-restart-to-bios'
    Name        = 'Restart to BIOS'
    Section     = 'Tools'
    Category    = 'Refresh'
    Kind        = 'Action'
    Button      = 'Restart'
    Risk        = 'Caution'
    Restarts    = $true
    Confirm     = 'The PC restarts straight into its BIOS (UEFI) settings. Save your work first. Restart now?'
    Description = 'Restarts the PC straight into its BIOS (UEFI) settings. Needs a UEFI PC.'
    Apply       = {
        $code = Restart-AkariFirmware
        if ($code -ne 0) { throw "this PC can't restart into its firmware settings (shutdown /fw: exit code $code; not a UEFI PC?)" }
    }
}
