# The AkariOS wallpaper, as the old One-click set it (isleap9/Akari-OS steptwo.ps1): OneClick\img.jpg copied to
# C:\Windows\Web\AkariOS\img.jpg, Fill. It replaces FR33THY's black wallpaper (6 Windows\6 Signout Lockscreen
# Wallpaper Black) and solid-colour background (22 Control Panel Settings): they all set the same value. The image
# is OneClick\img.jpg (one copy, the one One-click sets too). Revert = Windows' own wallpaper (img0.jpg). Detect
# compares the copy with that image: a PC with an older AkariOS wallpaper reads Custom, and Apply puts the current one in.
@{
    Id          = 'theme-akarios-wallpaper'
    Name        = 'AkariOS wallpaper'
    Section     = 'Customize'
    Category    = 'Theme'
    Risk        = 'Safe'
    AkariOS     = $true
    Description = 'Sets the AkariOS wallpaper on the desktop (an older AkariOS wallpaper is replaced with the current one).'
    Detect      = {
        $w = Get-AkariRegValue 'HKCU:\Control Panel\Desktop' 'Wallpaper'
        $src = Join-Path (Split-Path (Split-Path (Split-Path $AkariTweakDir))) 'OneClick\img.jpg'
        $dst = "$env:SystemRoot\Web\AkariOS\img.jpg"
        $same = (Test-Path -LiteralPath $dst) -and (Test-Path -LiteralPath $src) -and (Get-Item -LiteralPath $dst).Length -eq (Get-Item -LiteralPath $src).Length
        if ($w -eq $dst -and $same) { 'Optimized' }
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
