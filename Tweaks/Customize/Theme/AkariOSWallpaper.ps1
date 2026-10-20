# The AkariOS wallpaper, as One-click sets it (OneClick\steptwo.ps1): OneClick\img.jpg copied to
# C:\Windows\Web\AkariOS\img.jpg, Fill. It replaces FR33THY's black wallpaper (6 Windows\6 Signout Lockscreen
# Wallpaper Black) and solid-colour background (22 Control Panel Settings): they all set the same value. The image
# stays in OneClick\ (17 MB, one copy) until M4 retires that folder. Revert = Windows' own wallpaper (img0.jpg).
@{
    Id          = 'theme-akarios-wallpaper'
    Name        = 'AkariOS wallpaper'
    Section     = 'Customize'
    Category    = 'Theme'
    Risk        = 'Safe'
    AkariOS     = $true
    Description = 'Sets the AkariOS wallpaper on the desktop.'
    Detect      = {
        $w = Get-AkariRegValue 'HKCU:\Control Panel\Desktop' 'Wallpaper'
        if ($w -eq "$env:SystemRoot\Web\AkariOS\img.jpg") { 'Optimized' }
        elseif ($w -eq "$env:SystemRoot\Web\Wallpaper\Windows\img0.jpg") { 'Default' }
        else { 'Custom' }
    }
    Apply       = {
        $src = Join-Path (Split-Path (Split-Path (Split-Path $AkariTweakDir))) 'OneClick\img.jpg'
        $dst = "$env:SystemRoot\Web\AkariOS\img.jpg"
        if (-not (Test-Path -LiteralPath $src)) { throw "the AkariOS wallpaper is missing: $src" }
        New-Item (Split-Path $dst) -ItemType Directory -Force | Out-Null
        Copy-Item -LiteralPath $src $dst -Force
        Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Wallpapers' 'BackgroundType' 0
        Set-Reg 'HKCU:\Control Panel\Desktop' 'WallpaperStyle' '10' 'String'
        Set-Reg 'HKCU:\Control Panel\Desktop' 'TileWallpaper' '0' 'String'
        Set-Reg 'HKCU:\Control Panel\Desktop' 'JPEGImportQuality' 100
        Set-Reg 'HKCU:\Control Panel\Desktop' 'Wallpaper' $dst 'String'
        Set-AkariDesktopWallpaper $dst
    }
    Revert      = {
        $img0 = "$env:SystemRoot\Web\Wallpaper\Windows\img0.jpg"
        Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Wallpapers' 'BackgroundType' 0
        Set-Reg 'HKCU:\Control Panel\Desktop' 'WallpaperStyle' '10' 'String'
        Set-Reg 'HKCU:\Control Panel\Desktop' 'TileWallpaper' '0' 'String'
        Remove-Reg 'HKCU:\Control Panel\Desktop' 'JPEGImportQuality'
        Set-Reg 'HKCU:\Control Panel\Desktop' 'Wallpaper' $img0 'String'
        Set-AkariDesktopWallpaper $img0
        Remove-Item "$env:SystemRoot\Web\AkariOS" -Recurse -Force -ErrorAction SilentlyContinue
    }
}
