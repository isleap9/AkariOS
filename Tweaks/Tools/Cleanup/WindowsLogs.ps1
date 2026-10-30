# From ZOICWARE (https://github.com/zoicware/ZOICWARE, MIT) src\zFunctions.psm1 "Clear Windows Logs" (Ultimate Cleanup):
# its list of setup, update, servicing and diagnostic log files. The Update Medic logs are TrustedInstaller's, so they
# are made the administrators' first.
# Action: deleted logs can't come back.
@{
    Id          = 'cleanup-windows-logs'
    Name        = 'Delete Windows log files'
    Section     = 'Tools'
    Category    = 'Cleanup'
    Kind        = 'Action'
    Button      = 'Run'
    Risk        = 'Caution'
    Guided      = $false
    Description = 'Deletes Windows'' setup, update, servicing (CBS, DISM), driver install and diagnostic log files. Logs Windows has open stay.'
    Confirm     = 'Delete Windows'' log files? They help when tracking down setup or update problems.'
    Apply       = {
        $w = $env:SystemRoot
        $local = Get-AkariUserFolder 'Local AppData'
        Grant-AkariOwnership "$w\Logs\waasmedic"
        $n = Remove-AkariPaths @(
            "$w\DtcInstall.log", "$w\comsetup.log", "$w\PFRO.log", "$w\setupact.log", "$w\setuperr.log", "$w\setupapi.log",
            "$w\Panther\*", "$w\inf\setupapi.app.log", "$w\inf\setupapi.dev.log", "$w\inf\setupapi.offline.log",
            "$w\Performance\WinSAT\winsat.log", "$w\debug\PASSWD.LOG", "$w\Logs\CBS\CBS.log", "$w\Logs\DISM\DISM.log",
            "$w\Logs\SIH\*", "$local\Microsoft\CLR_v4.0\UsageTraces\*", "$local\Microsoft\CLR_v4.0_32\UsageTraces\*",
            "$w\Logs\NetSetup\*", "$w\System32\LogFiles\setupcln\*", "$w\Temp\CBS\*", "$w\Logs\waasmedic",
            "$w\System32\catroot2\dberr.txt", "$w\System32\catroot2.log", "$w\System32\catroot2.jrs", "$w\System32\catroot2.edb",
            "$w\System32\catroot2.chk", "$w\Traces\WindowsUpdate\*")
        "Deleted $n log files and folders"
    }
}
