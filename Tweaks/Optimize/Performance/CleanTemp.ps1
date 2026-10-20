# Action: deleted files can't be put back.
# Ported from AkariOS-Ultimate (FR33THY Ultimate) 6 Windows\35 Cleanup (One-click does the same), without deleting
# C:\XboxGames and C:\inetpub: on a PC in use those hold installed games and IIS sites.
@{
    Id          = 'performance-clean-temp'
    Name        = 'Clean temporary files'
    Section     = 'Optimize'
    Category    = 'Performance'
    Kind        = 'Action'
    Button      = 'Clean'
    Risk        = 'Safe'
    AkariOS     = $true
    Description = 'Empties the temp folders and the Windows Update download cache, deletes Windows.old, PerfLogs and crash logs, then runs Disk Cleanup.'
    Apply       = {
        Remove-Item "$(Get-AkariUserFolder 'Local AppData')\Temp\*" -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Item "$env:SystemRoot\Temp\*" -Recurse -Force -ErrorAction SilentlyContinue
        foreach ($p in 'DumpStack.log', 'Output.txt', 'PerfLogs', 'Windows.old') { Remove-Item "$env:SystemDrive\$p" -Recurse -Force -ErrorAction SilentlyContinue }
        Stop-Service -Name 'wuauserv' -Force -ErrorAction SilentlyContinue
        Remove-Item "$env:SystemRoot\SoftwareDistribution\*" -Recurse -Force -ErrorAction SilentlyContinue
        Start-Process 'cleanmgr.exe' -ArgumentList "/autoclean /d $env:SystemDrive" -Wait -ErrorAction SilentlyContinue
    }
}
