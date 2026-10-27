# Ported from AkariOS-Ultimate (FR33THY Ultimate) 3 Setup "Activation" (it only opens Windows' own page). Its
# neighbour "Keys" (a link to an activation workaround) is never ported.
# Action: it opens a page and changes nothing.
@{
    Id          = 'tools-activation'
    Name        = 'Activation'
    Section     = 'Tools'
    Category    = 'Setup'
    Kind        = 'Action'
    Button      = 'Open'
    Risk        = 'Safe'
    Description = 'Opens Settings > System > Activation: check that Windows is activated, or enter your product key.'
    Apply       = { Start-Process 'ms-settings:activation' }
}
