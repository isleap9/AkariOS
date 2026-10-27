# Ported from AkariOS-Ultimate (FR33THY Ultimate) 1 Check "Gpu Check" (GPU-Z, now from winget: install-gpu-z's package).
# Action: it opens a tool; it changes nothing.
@{
    Id          = 'tools-gpu-check'
    Name        = 'GPU check (GPU-Z)'
    Section     = 'Tools'
    Category    = 'Check'
    Kind        = 'Action'
    Button      = 'Check'
    Risk        = 'Safe'
    Description = 'Opens GPU-Z (installed first if missing): PCIe link speed, Resizable BAR, driver version and clocks.'
    Apply       = { Open-AkariWingetTool 'TechPowerUp.GPU-Z' 'GPU-Z.exe' }
}
