# Ported from AkariOS-Ultimate (FR33THY Ultimate) 6 Windows "Pointer precision" (it only opens the dialog;
# input-pointer-precision-off is the setting).
# Action: it opens a dialog and changes nothing, so there is nothing to revert.
@{
    Id          = 'input-open-pointer-options'
    Name        = 'Mouse pointer options'
    Section     = 'Customize'
    Category    = 'Input'
    Kind        = 'Action'
    Button      = 'Open'
    Risk        = 'Safe'
    Guided      = $false
    Description = 'Opens the classic Mouse Properties on Pointer Options (pointer speed, Enhance pointer precision).'
    Apply       = { Start-Process 'control.exe' -ArgumentList 'main.cpl ,2' }
}
