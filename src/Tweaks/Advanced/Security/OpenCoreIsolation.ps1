# Ported from AkariOS-Ultimate (FR33THY Ultimate) 6 Windows "Core isolation" (it only opens the pages; memory
# integrity itself is in security-defender-settings).
# Action: it opens two pages and changes nothing, so there is nothing to revert.
@{
    Id          = 'security-open-core-isolation'
    Name        = 'Core isolation and System Information'
    Section     = 'Advanced'
    Category    = 'Security'
    Kind        = 'Action'
    Button      = 'Open'
    Risk        = 'Safe'
    Guided      = $false
    Description = 'Opens Windows Security > Core isolation, and System Information (to see whether virtualization-based security runs).'
    Apply       = {
        Start-Process 'msinfo32'
        Start-Process 'windowsdefender://coreisolation/'
    }
}
