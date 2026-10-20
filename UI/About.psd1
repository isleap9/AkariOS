# The About page's links, credits and license (UI\About.ps1). CREDITS.md keeps the full per-Tweak list.
# A link with an empty Url is hidden until it gets one. Saved as UTF-8 with BOM (PowerShell 5.1 reads · and © right).
@{
    Links = @(
        @{ Name = 'GitHub'; Url = 'https://github.com/isleap9/AkariOS' }
        @{ Name = 'Report a bug'; Url = 'https://github.com/isleap9/AkariOS/issues' }
        @{ Name = 'Discord'; Url = 'https://discord.gg/px2W4VyQK4' }
    )
    Credits = @(
        @{ Name = 'FR33THY Ultimate'; Text = 'Most tweaks, the debloat and its keep-lists, the app installers'; Url = 'https://github.com/FR33THYFR33THY/Ultimate' }
        @{ Name = 'FR33THY WinSux'; Text = 'The base of the original One-click'; Url = 'https://github.com/FR33THYFR33THY/WinSux' }
        @{ Name = 'Raphire Win11Debloat'; Text = 'The app list (names, descriptions, risk levels) and the look of the Guided flow'; Url = 'https://github.com/Raphire/Win11Debloat' }
        @{ Name = 'isleap9/Akari-OS'; Text = 'One-click and the AkariOS wallpaper'; Url = 'https://github.com/isleap9/Akari-OS' }
        @{ Name = 'winget'; Text = 'App installs'; Url = 'https://github.com/microsoft/winget-cli' }
        @{ Name = 'NVIDIA Profile Inspector'; Text = 'NVIDIA driver profiles (Orbmu2k)'; Url = 'https://github.com/Orbmu2k/nvidiaProfileInspector' }
        @{ Name = 'Display Driver Uninstaller'; Text = 'Clean graphics driver removal (Wagnardsoft)'; Url = 'https://www.wagnardsoft.com/display-driver-uninstaller-ddu' }
    )
    FullCredits = 'https://github.com/isleap9/AkariOS/blob/main/CREDITS.md'
    License = @{ Text = 'MIT License · © 2026 isleap9'; Url = 'https://github.com/isleap9/AkariOS/blob/main/LICENSE' }
}
