# The tasks the Scheduled tasks page lists by default ("Show all" lists every one): the ones FR33THY Ultimate and
# ZOICWARE (https://github.com/zoicware/ZOICWARE, MIT) turn off. Path = the task's folder, Name = its name or a
# wildcard; Source and Note show on the row.
# ZOICWARE src\zFunctions.psm1: telemetry (disable telemetry), "Pause updates" (the Windows Update folders, and
# WindowsUpdate\Scheduled Start), Defender (every "Windows Defender*" task).
# FR33THY 6 Windows\33 Defender Optimize (ExploitGuard, Defender) and 22 Control Panel Settings (ScheduledDefrag).
@{
    Tasks = @(
        @{ Path = '\Microsoft\Windows\Application Experience\'; Name = 'Microsoft Compatibility Appraiser'; Source = 'ZOICWARE'; Note = 'telemetry' }
        @{ Path = '\Microsoft\Windows\Application Experience\'; Name = 'ProgramDataUpdater'; Source = 'ZOICWARE'; Note = 'telemetry' }
        @{ Path = '\Microsoft\Windows\Autochk\'; Name = 'Proxy'; Source = 'ZOICWARE'; Note = 'telemetry' }
        @{ Path = '\Microsoft\Windows\Customer Experience Improvement Program\'; Name = 'Consolidator'; Source = 'ZOICWARE'; Note = 'telemetry' }
        @{ Path = '\Microsoft\Windows\Customer Experience Improvement Program\'; Name = 'UsbCeip'; Source = 'ZOICWARE'; Note = 'telemetry' }
        @{ Path = '\Microsoft\Windows\DiskDiagnostic\'; Name = 'Microsoft-Windows-DiskDiagnosticDataCollector'; Source = 'ZOICWARE'; Note = 'telemetry' }
        @{ Path = '\Microsoft\Windows\InstallService\'; Name = '*'; Source = 'ZOICWARE'; Note = 'Windows Update' }
        @{ Path = '\Microsoft\Windows\UpdateOrchestrator\'; Name = '*'; Source = 'ZOICWARE'; Note = 'Windows Update' }
        @{ Path = '\Microsoft\Windows\UpdateAssistant\'; Name = '*'; Source = 'ZOICWARE'; Note = 'Windows Update' }
        @{ Path = '\Microsoft\Windows\WaaSMedic\'; Name = '*'; Source = 'ZOICWARE'; Note = 'Windows Update' }
        @{ Path = '\Microsoft\Windows\WindowsUpdate\'; Name = '*'; Source = 'ZOICWARE'; Note = 'Windows Update' }
        @{ Path = '\Microsoft\WindowsUpdate\'; Name = '*'; Source = 'ZOICWARE'; Note = 'Windows Update' }
        @{ Path = '\Microsoft\Windows\Windows Defender\'; Name = 'Windows Defender*'; Source = 'FR33THY, ZOICWARE'; Note = 'Defender' }
        @{ Path = '\Microsoft\Windows\ExploitGuard\'; Name = 'ExploitGuard MDM policy Refresh'; Source = 'FR33THY'; Note = 'Defender' }
        @{ Path = '\Microsoft\Windows\Defrag\'; Name = 'ScheduledDefrag'; Source = 'FR33THY'; Note = 'defrag schedule' }
    )
}
