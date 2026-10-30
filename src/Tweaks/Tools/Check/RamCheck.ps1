# Ported from AkariOS-Ultimate (FR33THY Ultimate) 1 Check "Ram Check" (CPU-Z, now from winget: install-cpu-z's package).
# Action: it opens a tool; it changes nothing.
@{
    Id          = 'tools-ram-check'
    Name        = 'RAM check (CPU-Z)'
    Section     = 'Tools'
    Category    = 'Check'
    Kind        = 'Action'
    Button      = 'Check'
    Risk        = 'Safe'
    Description = 'Opens CPU-Z (installed first if missing). Memory and SPD tabs: is the RAM running at its rated speed, in dual channel?'
    Apply       = { Open-AkariWingetTool 'CPUID.CPU-Z' 'cpuz.exe' }
}
