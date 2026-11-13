# Ported from Chris Titus Tech's winutil (MIT), functions/public/Invoke-WPFFixesNetwork.ps1.
# Action: a reset has no Default to go back to.
@{
    Id          = 'tools-fix-network'
    Name        = 'Network reset'
    Section     = 'Tools'
    Category    = 'Fixes'
    Kind        = 'Action'
    Button      = 'Reset'
    Risk        = 'Caution'
    Reboot      = $true
    Confirm     = 'This resets Winsock and the TCP/IP stack. VPN and firewall programs may need setting up again afterwards. Restart Windows to finish.'
    Description = 'Resets Winsock and the TCP/IP stack, for a connection that stopped working (netsh winsock reset, netsh int ip reset).'
    Apply       = {
        $netsh = "$env:SystemRoot\System32\netsh.exe"
        [void](Invoke-AkariExe $netsh @('winsock', 'reset'))
        [void](Invoke-AkariExe $netsh @('int', 'ip', 'reset'))
        Write-Log 'Network reset: done. Restart Windows to finish.'
    }
}
