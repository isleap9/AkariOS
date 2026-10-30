# From ZOICWARE (https://github.com/zoicware/ZOICWARE, MIT) src\zFunctions.psm1 "Use More Accurate Time Server for
# System Clock": ZOICWARE's w32tm /config /manualpeerlist writes this value (its Type, NTP, is Windows' own). After:
# the Windows Time service rereads it and syncs, on Apply and Revert.
@{
    Id          = 'system-time-server'
    Name        = 'Sync the clock with pool.ntp.org'
    Section     = 'Customize'
    Category    = 'System'
    Risk        = 'Safe'
    Guided      = $false
    Description = 'The clock syncs with the four pool.ntp.org servers instead of time.windows.com.'
    Registry    = @(
        @{ Path = 'HKLM:\SYSTEM\CurrentControlSet\Services\W32Time\Parameters'; Name = 'NtpServer'; Type = 'String'; Value = '0.pool.ntp.org 1.pool.ntp.org 2.pool.ntp.org 3.pool.ntp.org'; Default = 'time.windows.com,0x9' }
    )
    After       = {
        $null = Invoke-AkariW32tm /config /update
        $null = Invoke-AkariW32tm /resync /nowait
    }
}
