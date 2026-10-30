# Ported from AkariOS-Ultimate (FR33THY Ultimate) 6 Windows "Bloatware", its "UWP features" entry (it opens the page).
# Action: it opens a page; Windows' own page makes the changes.
@{
    Id          = 'tools-optional-features'
    Name        = 'Optional features'
    Section     = 'Tools'
    Category    = 'Check'
    Kind        = 'Action'
    Button      = 'Open'
    Risk        = 'Safe'
    Description = 'Opens Settings > System > Optional features, to check or add back an optional feature (capability) the debloat removed.'
    Apply       = { Start-Process 'ms-settings:optionalfeatures' }
}
