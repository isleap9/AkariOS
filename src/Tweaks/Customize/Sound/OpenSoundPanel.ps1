# Ported from AkariOS-Ultimate (FR33THY Ultimate) 6 Windows "Sound" (it only opens the panel).
# Action: it opens a panel and changes nothing, so there is nothing to revert.
@{
    Id          = 'sound-open-classic-panel'
    Name        = 'Classic Sound panel'
    Section     = 'Customize'
    Category    = 'Sound'
    Kind        = 'Action'
    Button      = 'Open'
    Risk        = 'Safe'
    Guided      = $false
    Description = 'Opens the classic Sound control panel (devices, formats, exclusive mode, communications).'
    Apply       = { Start-Process 'mmsys.cpl' }
}
