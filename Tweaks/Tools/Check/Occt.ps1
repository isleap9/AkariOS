# Ported from AkariOS-Ultimate (FR33THY Ultimate) 1 Check "Storage Ram Cpu Test & Bench" (OCCT, now from winget:
# install-occt's portable package).
# Action: it opens a tool; it changes nothing.
@{
    Id          = 'tools-occt'
    Name        = 'Storage, RAM and CPU test (OCCT)'
    Section     = 'Tools'
    Category    = 'Check'
    Kind        = 'Action'
    Button      = 'Open'
    Risk        = 'Safe'
    Description = 'Opens OCCT (installed first if missing) to stress-test and benchmark the CPU, RAM and storage.'
    Apply       = { Open-AkariWingetTool 'OCBase.OCCT.Personal' 'OCCT*.exe' }
}
