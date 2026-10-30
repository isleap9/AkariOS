# Ported from AkariOS-Ultimate (FR33THY Ultimate) 5 Graphics "Driver Updated Install", Intel (it opens Intel's driver
# downloads). Intel's settings are graphics-intel-settings.
# Action: it opens a page; the driver install is Intel's own.
@{
    Id          = 'tools-driver-intel'
    Name        = 'Install latest Intel driver'
    Section     = 'Tools'
    Category    = 'Drivers'
    Kind        = 'Action'
    Button      = 'Open'
    Risk        = 'Safe'
    Requires    = 'Intel'
    Description = 'Opens Intel''s driver downloads, newest first: get the graphics driver for your GPU and run it. Then apply the Intel graphics settings (Graphics & Hardware).'
    Apply       = { Start-Process 'https://www.intel.com/content/www/us/en/search.html#sortCriteria=%40lastmodifieddt%20descending&f-operatingsystem_en=Windows%2011%20Family*&f-downloadtype=Drivers&cf-tabfilter=Downloads' }
}
