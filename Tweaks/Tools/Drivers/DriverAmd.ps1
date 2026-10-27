# Ported from AkariOS-Ultimate (FR33THY Ultimate) 5 Graphics "Driver Updated Install", AMD. AMD's settings are
# graphics-amd-settings, as in "Install & Settings".
# Action: a driver install, done by AMD's own installer; DDU (tools-ddu-clean) removes it.
@{
    Id          = 'tools-driver-amd'
    Name        = 'Install latest AMD driver'
    Section     = 'Tools'
    Category    = 'Drivers'
    Kind        = 'Action'
    Button      = 'Install'
    Risk        = 'Safe'
    Requires    = 'AMD'
    Description = 'Downloads AMD Software: Adrenalin Edition''s setup from AMD''s driver page and starts it (it finds your GPU''s driver). Then apply AMD settings (Graphics & Hardware).'
    Apply       = {
        # AMD's site serves its download links to browsers only
        $browser = @{ 'User-Agent' = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36'
            'Accept' = 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8'; 'Referer' = 'https://www.amd.com/' }
        $link = (Invoke-WebRequest -Uri 'https://www.amd.com/en/support/download/drivers.html' -UseBasicParsing -Headers $browser).Links |
            Where-Object { $_.href -match 'drivers\.amd\.com/drivers/installer/.*/whql/amd-software-adrenalin-edition-.*-minimalsetup-.*_web\.exe' } |
            Select-Object -First 1
        if (-not $link) { throw 'AMD''s driver page has no Adrenalin setup link (the page changed?)' }
        $exe = "$env:SystemRoot\Temp\amddriver.exe"
        Invoke-WebRequest -Uri $link.href -OutFile $exe -UseBasicParsing -Headers $browser
        Start-Process -FilePath $exe
    }
}
