# Ported from AkariOS-Ultimate (FR33THY Ultimate) 6 Windows\33 Defender Optimize, its normal-boot part (One-click:
# steptwo.ps1): SmartScreen for Edge and Store apps, and Defender's scheduled scans and maintenance.
@{
    Id          = 'security-defender-tasks-off'
    Name        = 'No Defender scheduled scans, no SmartScreen for apps'
    Section     = 'Advanced'
    Category    = 'Security'
    Risk        = 'Caution'
    AkariOS     = $true
    Description = 'Defender''s scheduled scan, cleanup, verification and cache tasks off; SmartScreen off for Edge and Store apps.'
    Registry    = @(
        @{ Path = 'HKCU:\SOFTWARE\Microsoft\Edge\SmartScreenEnabled'; Name = '(default)'; Type = 'DWord'; Value = 0; Default = 1 }
        @{ Path = 'HKCU:\SOFTWARE\Microsoft\Edge\SmartScreenPuaEnabled'; Name = '(default)'; Type = 'DWord'; Value = 0; Default = 1 }
        @{ Path = 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppHost'; Name = 'EnableWebContentEvaluation'; Type = 'DWord'; Value = 0; Default = 1 }
    )
    After       = {
        $tasks = @(
            ,@('\Microsoft\Windows\ExploitGuard\', 'ExploitGuard MDM policy Refresh')
            ,@('\Microsoft\Windows\Windows Defender\', 'Windows Defender Cache Maintenance')
            ,@('\Microsoft\Windows\Windows Defender\', 'Windows Defender Cleanup')
            ,@('\Microsoft\Windows\Windows Defender\', 'Windows Defender Scheduled Scan')
            ,@('\Microsoft\Windows\Windows Defender\', 'Windows Defender Verification')
        )
        foreach ($t in $tasks) {
            [void](Set-AkariScheduledTask $t[0] $t[1] ($AkariMode -ne 'Apply'))
        }
    }
}
