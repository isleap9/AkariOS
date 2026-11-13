# Ported from Chris Titus Tech's winutil (MIT), functions/public/Invoke-WPFFixesUpdate.ps1, without its Aggressive
# steps (off by default there too) and without its blanket reset of every policy key, secedit and the GroupPolicy
# folders: that would undo every policy-based AkariOS tweak at once. BITS jobs go through bitsadmin (Get-BitsTransfer
# needs the BITS module), an old Download.bak is deleted first so the rename works again.
# Action: a reset has no Default to go back to.
@{
    Id          = 'tools-fix-windows-update'
    Name        = 'Windows Update reset'
    Section     = 'Tools'
    Category    = 'Fixes'
    Kind        = 'Action'
    Button      = 'Reset'
    Risk        = 'Caution'
    Reboot      = $true
    Confirm     = 'This resets Windows Update: its download cache, DLLs, network stack and update policies (AkariOS'' Update settings go back to Windows'' default). Restart Windows to finish.'
    Description = 'Repairs a stuck Windows Update: stops its services, clears the download cache and BITS jobs, registers its DLLs again, clears the update policies, resets Winsock and starts a new scan.'
    Apply       = {
        $sys = "$env:SystemRoot\System32"
        $services = 'BITS', 'wuauserv', 'appidsvc', 'cryptsvc'
        Write-Log 'Windows Update reset: stopping its services'
        foreach ($s in $services) { Stop-Service -Name $s -Force -ErrorAction SilentlyContinue }

        Write-Log 'Windows Update reset: clearing the BITS queue and the download cache'
        [void](Remove-AkariPaths @("$env:ProgramData\Microsoft\Network\Downloader\qmgr*.dat", "$env:SystemRoot\SoftwareDistribution\Download.bak", "$env:SystemRoot\WindowsUpdate.log"))
        $download = "$env:SystemRoot\SoftwareDistribution\Download"
        if (Test-Path -LiteralPath $download) { Move-Item -LiteralPath $download -Destination "$download.bak" -Force }

        Write-Log 'Windows Update reset: registering its DLLs again'
        $dlls = 'atl.dll', 'urlmon.dll', 'mshtml.dll', 'shdocvw.dll', 'browseui.dll', 'jscript.dll', 'vbscript.dll', 'scrrun.dll', 'msxml.dll', 'msxml3.dll',
            'msxml6.dll', 'actxprxy.dll', 'softpub.dll', 'wintrust.dll', 'dssenh.dll', 'rsaenh.dll', 'gpkcsp.dll', 'sccbase.dll', 'slbcsp.dll', 'cryptdlg.dll',
            'oleaut32.dll', 'ole32.dll', 'shell32.dll', 'initpki.dll', 'wuapi.dll', 'wuaueng.dll', 'wuaueng1.dll', 'wucltui.dll', 'wups.dll', 'wups2.dll',
            'wuweb.dll', 'qmgr.dll', 'qmgrprxy.dll', 'wucltux.dll', 'muweb.dll', 'wuwebv.dll'
        foreach ($d in $dlls) { [void](Invoke-AkariExe "$sys\regsvr32.exe" @('/s', $d)) }

        Write-Log 'Windows Update reset: clearing the WSUS ids and the update policies'
        # '<key>|<value>'
        $values = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate|AccountDomainSid',
            'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate|PingID',
            'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate|SusClientId',
            'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate|ExcludeWUDriversInQualityUpdate',
            'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Device Metadata|PreventDeviceMetadataFromNetwork',
            'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DriverSearching|DontPromptForWindowsUpdate',
            'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DriverSearching|DontSearchWindowsUpdate',
            'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DriverSearching|DriverUpdateWizardWuSearchEnabled',
            'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU|NoAutoRebootWithLoggedOnUsers',
            'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU|AUPowerManagement',
            'HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings|BranchReadinessLevel',
            'HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings|DeferFeatureUpdatesPeriodInDays',
            'HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings|DeferQualityUpdatesPeriodInDays'
        foreach ($v in $values) { $key, $name = $v.Split('|'); Remove-Reg $key $name }

        Write-Log 'Windows Update reset: resetting Winsock, the WinHTTP proxy and the IP stack'
        [void](Invoke-AkariExe "$sys\netsh.exe" @('winsock', 'reset'))
        [void](Invoke-AkariExe "$sys\netsh.exe" @('winhttp', 'reset', 'proxy'))
        [void](Invoke-AkariExe "$sys\netsh.exe" @('int', 'ip', 'reset'))
        [void](Invoke-AkariExe "$sys\bitsadmin.exe" @('/reset', '/allusers'))

        Write-Log 'Windows Update reset: starting its services'
        foreach ($s in $services) {
            Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Services\$s" 'Start' 3 'DWord'
            Start-Service -Name $s -ErrorAction SilentlyContinue
        }
        [void](Invoke-AkariExe "$sys\wuauclt.exe" @('/resetauthorization', '/detectnow'))
        Write-Log 'Windows Update reset: done. Restart Windows to finish.'
    }
}
