# Ported from AkariOS-Ultimate (FR33THY Ultimate) 2 Refresh "Account Local" (it only opens netplwiz).
# Action: it opens Windows' own User Accounts window; it changes nothing.
@{
    Id          = 'tools-local-account'
    Name        = 'Local account and sign-in'
    Section     = 'Tools'
    Category    = 'Refresh'
    Kind        = 'Action'
    Button      = 'Open'
    Risk        = 'Safe'
    Description = 'Opens the classic User Accounts window (netplwiz): add a local account, or sign in without typing a password.'
    Apply       = { Start-Process 'netplwiz.exe' }
}
