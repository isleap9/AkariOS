# Ported from AkariOS-Ultimate (FR33THY Ultimate) 1 Check "Gpu Test & Bench" (FurMark, now FurMark 2 from winget).
# Action: it opens a tool; it changes nothing.
@{
    Id          = 'tools-furmark'
    Name        = 'GPU test (FurMark)'
    Section     = 'Tools'
    Category    = 'Check'
    Kind        = 'Action'
    Button      = 'Open'
    Risk        = 'Safe'
    Description = 'Opens FurMark 2 (installed first if missing) to stress-test the graphics card and check its temperatures.'
    Apply       = { Open-AkariWingetTool 'Geeks3D.FurMark.2' 'FurMark_GUI.exe' }
}
