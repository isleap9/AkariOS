# From AkariOS-Ultimate (FR33THY Ultimate) 6 Windows "Gamebar", its Default part: Microsoft's gaming services repair
# tool (from the AkariOS-Files release) puts Gaming Services back after the Xbox apps were removed. The apps themselves
# come back from Downloads (Restore removed apps), WebView2 from install-webview2-runtime.
# Action: a repair tool, run once; there is no setting to revert.
@{
    Id          = 'tools-gaming-repair'
    Name        = 'Repair Gaming Services'
    Section     = 'Tools'
    Category    = 'Refresh'
    Kind        = 'Action'
    Button      = 'Run'
    Risk        = 'Safe'
    Description = 'Downloads and starts Microsoft''s gaming repair tool, which reinstalls Gaming Services (Xbox app, Game Pass and Store games need them).'
    Apply       = {
        $exe = Save-AkariFile 'gamingrepairtool.exe' "$env:SystemRoot\Temp\gamingrepairtool.exe"
        Start-Process -FilePath $exe
    }
}
