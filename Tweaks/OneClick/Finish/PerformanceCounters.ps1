# One-click's steptwo.ps1 (isleap9/Akari-OS): "rebuild performance counters" (after the services and timer changes).
# Action: lodctr /R rebuilds them from Windows' own files; there is nothing to undo.
@{
    Id          = 'oneclick-performance-counters'
    Name        = 'Rebuild performance counters'
    Section     = 'OneClick'
    Category    = 'Finish'
    Kind        = 'Action'
    Risk        = 'Safe'
    Description = 'Rebuilds the 64- and 32-bit performance counter settings (lodctr /R), so monitoring tools read them right.'
    Apply       = {
        foreach ($d in "$env:SystemRoot\System32", "$env:SystemRoot\SysWOW64") {
            if (Test-Path -LiteralPath "$d\lodctr.exe") { [void](Invoke-AkariExe "$d\lodctr.exe" @('/R')) }
        }
    }
}
