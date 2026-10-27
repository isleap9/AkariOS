# Ported from AkariOS-Ultimate (FR33THY Ultimate) 1 Check "Bios Check". Its restart into the firmware is
# tools-restart-to-bios now; its "allow password sign in" value is system-password-sign-in's.
# Action: a check that reads the board and opens a search; it changes nothing.
@{
    Id          = 'tools-bios-check'
    Name        = 'BIOS check'
    Section     = 'Tools'
    Category    = 'Check'
    Kind        = 'Action'
    Button      = 'Check'
    Risk        = 'Safe'
    Description = 'Shows your motherboard and BIOS version in the console, searches the web for its latest BIOS, and lists the BIOS settings worth changing.'
    Apply       = {
        $board = Get-CimInstance -ClassName Win32_BaseBoard
        $bios = Get-CimInstance -ClassName Win32_BIOS
        $date = if ($bios.ReleaseDate) { ' from ' + ([datetime]$bios.ReleaseDate).ToString('yyyy-MM-dd') } else { '' }
        Write-Log "Motherboard: $($board.Manufacturer) $($board.Product), BIOS $($bios.SMBIOSBIOSVersion)$date"
        foreach ($l in 'Update the BIOS, then in its settings:',
            '- turn on the RAM profile (XMP / DOCP / EXPO) and Resizable BAR (ReBAR / C.A.M)',
            '- Intel K CPUs: turn off C-states; AMD CPUs: turn on Precision Boost Overdrive (PBO)',
            '- turn off what you don''t use (Bluetooth, Wi-Fi, integrated GPU) and the driver installer (Armoury Crate, MSI Driver Utility, ...)',
            '- fans and pump on performance; TPM and Secure Boot on for anti-cheat games',
            'Restart to BIOS (Tools > Refresh) gets you there.') { Write-Log $l }
        Start-Process ('https://www.google.com/search?q=' + [uri]::EscapeDataString("$($board.Manufacturer) $($board.Product) BIOS"))
    }
}
