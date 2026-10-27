# Ported from AkariOS-Ultimate (FR33THY Ultimate) 3 Setup "Startup Apps" (Task Manager; it only opens the tab).
# Action: it opens a window and changes nothing, so there is nothing to revert.
@{
    Id          = 'performance-open-startup-taskmgr'
    Name        = 'Startup apps (Task Manager)'
    Section     = 'Optimize'
    Category    = 'Performance'
    Kind        = 'Action'
    Button      = 'Open'
    Risk        = 'Safe'
    Guided      = $false
    Description = 'Opens Task Manager on its Startup apps tab, which also lists startup impact.'
    Apply       = { Start-Process -FilePath 'taskmgr.exe' -ArgumentList '/0', '/startup' }
}
