# Action: adds shortcuts to Start; Akari leaves them for the user to keep or delete (no Default to go back to).
# Ported from AkariOS-Ultimate (FR33THY Ultimate) 6 Windows\3 Start Menu Shortcuts (without opening the two folders).
@{
    Id          = 'start-akarios-shortcuts'
    Name        = 'AkariOS Start shortcuts'
    Section     = 'Customize'
    Category    = 'Start'
    Kind        = 'Action'
    Button      = 'Add'
    Risk        = 'Safe'
    AkariOS     = $true
    Description = 'Adds Recycle Bin, both Start menu folders and both Startup folders to All apps, to tidy Start and startup apps quickly.'
    Detect      = { Test-Path "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\Startup Programs 2.lnk" }
    Apply       = {
        $programs = "$env:ProgramData\Microsoft\Windows\Start Menu\Programs"
        $mine = Get-AkariUserFolder 'Programs'
        $links = [ordered]@{
            'Start Menu Shortcuts 1' = $programs
            'Start Menu Shortcuts 2' = $mine
            'Startup Programs 1'     = "$mine\Startup"
            'Startup Programs 2'     = "$programs\StartUp"
            'Recycle Bin'            = '::{645ff040-5081-101b-9f08-00aa002f954e}'
        }
        $shell = New-Object -ComObject WScript.Shell
        foreach ($n in $links.Keys) {
            $s = $shell.CreateShortcut("$programs\$n.lnk")
            $s.TargetPath = $links[$n]
            $s.Save()
        }
    }
}
