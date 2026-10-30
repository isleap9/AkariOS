# Action: the taskbar's pins are the user's own list; once cleared Akari can't know what to pin back.
# Ported from AkariOS-Ultimate (FR33THY Ultimate) 6 Windows\1 Start Menu Taskbar.
@{
    Id          = 'taskbar-unpin-all'
    Name        = 'Unpin all taskbar apps'
    Section     = 'Customize'
    Category    = 'Taskbar'
    Kind        = 'Action'
    Button      = 'Unpin'
    Risk        = 'Caution'
    AkariOS     = $true
    Explorer    = $true
    Description = 'Removes every pinned app from the taskbar (Edge, Store, Explorer...). Pin your own afterwards.'
    Apply       = {
        $band = Resolve-AkariRegPath 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Taskband'
        if (Test-Path $band) { Remove-Item $band -Recurse -Force }
        Remove-Item "$(Get-AkariUserFolder 'AppData')\Microsoft\Internet Explorer\Quick Launch" -Recurse -Force -ErrorAction SilentlyContinue
    }
}
