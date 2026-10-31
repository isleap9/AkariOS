# Makes src\Assets\Apps\<key>.png (or <key>.mono.png), the app icons of the Apps tables (Downloads, Guided Apps step). Dev-only, like
# Icons.ps1; run it again after adding an app: powershell -NoProfile -File build\AppIcons.ps1 [-Force]
# key = the Tweak's Id, or the Store package name for a Store app. Sources, per $Sites row:
#   'domain'            the site's icon, through Google's favicon service ('domain/path': that page's icon)
#   'https://...'       an image file (png, ico)
#   'appx:<package>'    the logo of that Store package installed on this PC (Core\Appx.ps1's Get-AkariAppxLogos)
# The restore card's Store apps (Tweaks\Apps\Install\StoreApps.psd1) are taken from this PC's packages too; Store
# apps on the user's PC are read there at run time. Each icon is saved as a 64 x 64 PNG with no background
# (-Force: make every icon again; -Refresh: download them again too).
# The logos belong to their owners; Akari shows them only to name each app (CREDITS.md).
param([switch]$Force, [switch]$Refresh)

$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot
$out = Join-Path $repo 'src\Assets\Apps'
. (Join-Path $repo 'src\Core\Appx.ps1')
Add-Type -AssemblyName System.Drawing

$Sites = [ordered]@{
    'install-7-zip'                     = '7-zip.org'
    'install-audacity'                  = 'audacityteam.org'
    'install-battle-net'                = 'battle.net'
    'install-bitwarden'                 = 'bitwarden.com'
    'install-brave'                     = 'brave.com'
    'install-bulk-crap-uninstaller'     = 'bcuninstaller.com'
    'install-capframex'                 = 'capframex.com'
    'install-cpu-z'                     = 'cpuid.com'
    'install-custom-resolution-utility' = 'monitortests.com'
    'install-directx'                   = 'microsoft.com'
    'install-discord'                   = 'discord.com'
    'install-dotnet-desktop'            = 'dotnet.microsoft.com'
    'install-electronic-arts'           = 'ea.com'
    'install-epic-games'                = 'epicgames.com'
    'install-everything'                = 'voidtools.com'
    'install-firefox'                   = 'firefox.com'
    'install-foobar2000'                = 'foobar2000.org'
    'install-frame-view'                = 'nvidia.com'
    'install-git'                       = 'git-scm.com'
    'install-gog-launcher'              = 'gog.com'
    'install-google-chrome'             = 'chrome.google.com'
    'install-gpu-z'                     = 'techpowerup.com'
    'install-hwinfo'                    = 'hwinfo.com'
    'install-handbrake'                 = 'handbrake.fr'
    'install-helium'                    = 'helium.computer'
    'install-java'                      = 'adoptium.net'
    'install-librewolf'                 = 'librewolf.net'
    'install-microsoft-edge'            = 'www.microsoft.com/edge'
    'install-microsoft-store'           = 'appx:Microsoft.WindowsStore'
    'install-mpv'                       = 'mpv.io'
    'msi-afterburner'                   = 'msi.com'
    'install-nanazip'                   = 'https://raw.githubusercontent.com/M2Team/NanaZip/main/Assets/NanaZip.png'
    'install-nodejs'                    = 'nodejs.org'
    'install-notepad'                   = 'notepad-plus-plus.org'
    'install-nvidia-app'                = 'nvidia.com'
    'install-nvidia-profile-inspector'  = 'nvidia.com'
    'install-obs-studio'                = 'obsproject.com'
    'install-occt'                      = 'ocbase.com'
    'install-onboard-memory-manager'    = 'logitechg.com'
    'install-onedrive'                  = 'onedrive.live.com'
    'install-opera-gx'                  = 'gx.me'
    'install-parsec'                    = 'parsec.app'
    'install-playnite'                  = 'playnite.link'
    'install-pot-player'                = 'potplayer.tv'
    'install-powertoys'                 = 'microsoft.com'
    'install-process-lasso'             = 'bitsum.com'
    'install-python'                    = 'python.org'
    'install-qbittorrent'               = 'qbittorrent.org'
    'install-remote-desktop-connection' = 'microsoft.com'
    'install-rockstar-games'            = 'rockstargames.com'
    'install-rufus'                     = 'rufus.ie'
    'install-sharex'                    = 'getsharex.com'
    'install-signal'                    = 'signal.org'
    'install-snipping-tool-legacy'      = 'appx:Microsoft.ScreenSketch'
    'install-spotify'                   = 'spotify.com'
    'install-steam'                     = 'store.steampowered.com'
    'install-teamspeak'                 = 'teamspeak.com'
    'install-telegram'                  = 'telegram.org'
    'install-ubisoft-connect'           = 'store.ubisoft.com'
    'install-ungoogled-chromium'        = 'chromium.org'
    'install-vcredist'                  = 'microsoft.com'
    'install-vivaldi'                   = 'vivaldi.com'
    'install-vlc'                       = 'https://images.videolan.org/images/VLC-IconSmall.png'
    'install-vscode'                    = 'code.visualstudio.com'
    'install-webview2-runtime'          = 'www.microsoft.com/edge'
    'install-whatsapp'                  = 'whatsapp.com'
    'install-winrar'                    = 'win-rar.com'
    'install-windows-terminal'          = 'appx:Microsoft.WindowsTerminal'
    'install-zen-browser'               = 'zen-browser.app'
    'remove-edge'                       = 'www.microsoft.com/edge'
    'remove-webview2'                   = 'www.microsoft.com/edge'
    'remove-onedrive'                   = 'onedrive.live.com'
    'remove-remote-desktop-connection'  = 'microsoft.com'
    'remove-snipping-tool-legacy'       = 'appx:Microsoft.ScreenSketch'
    'remove-gameinput'                  = 'xbox.com'
    'remove-update-for-x64'             = 'microsoft.com'
    'remove-update-health-tools'        = 'microsoft.com'
    # restore card apps a developer PC may not have
    'Microsoft.ZuneVideo'                    = 'microsoft.com'
    'Microsoft.GamingServices'               = 'xbox.com'
    'Microsoft.XboxDevices'                  = 'xbox.com'
    'microsoft.windowscommunicationsapps'    = 'outlook.com'
    'Microsoft.Copilot'                      = 'copilot.com'
    'Microsoft.MicrosoftOfficeHub'           = 'microsoft365.com'
    'MicrosoftCorporationII.MicrosoftFamily' = 'microsoft.com'
}

# the restore card's Store apps: their logos from this PC's packages
$store = Import-PowerShellDataFile (Join-Path $repo 'src\Tweaks\Apps\Install\StoreApps.psd1')
foreach ($a in $store.Rows) { if (-not $Sites.Contains($a.Name)) { $Sites[$a.Name] = "appx:$($a.Name)" } }

$logos = Get-AkariAppxLogos @(Get-AkariAppxPackages)

# the image work, per pixel (C# for speed): a plain white or a dark plate behind the logo is cleared (flood-filled from
# the corners, its anti-aliased rim faded out), the logo is cropped and scaled to fill 64 x 64 with a 2 px margin.
# A logo with no colour left (black or white only) becomes a mask: white, alpha = its ink (a Store logo only when it
# is white: its dark grey ones are made for both themes). Returns 'mono' or 'color'.
Add-Type -ReferencedAssemblies System.Drawing -TypeDefinition @'
using System; using System.Drawing; using System.Drawing.Drawing2D; using System.Collections.Generic;
public static class AkariAppIcon {
    static double Lum(Color c) { return (0.299 * c.R + 0.587 * c.G + 0.114 * c.B) / 255.0; }
    static int Span(Color c) { return Math.Max(c.R, Math.Max(c.G, c.B)) - Math.Min(c.R, Math.Min(c.G, c.B)); }
    static double Dist(Color a, Color b) { int r = a.R - b.R, g = a.G - b.G, l = a.B - b.B; return Math.Sqrt(r * r + g * g + l * l); }
    public static string Process(Bitmap src, Bitmap dst, bool allowMono) {
        int n = 64;
        var px = new Color[n, n];
        for (int y = 0; y < n; y++) for (int x = 0; x < n; x++) px[x, y] = src.GetPixel(x, y);
        // seeds: the first opaque pixel on each corner's diagonal, within 7 px (a round logo is further in)
        var seeds = new List<Point>();
        int[,] corners = { { 0, 0, 1, 1 }, { n - 1, 0, -1, 1 }, { 0, n - 1, 1, -1 }, { n - 1, n - 1, -1, -1 } };
        for (int k = 0; k < 4; k++) {
            for (int i = 0; i <= 7; i++) {
                int x = corners[k, 0] + corners[k, 2] * i, y = corners[k, 1] + corners[k, 3] * i;
                Color c = px[x, y];
                if (c.A < 200) continue;
                double l = Lum(c);
                if ((Span(c) <= 28 && l >= 0.82) || l <= 0.22) seeds.Add(new Point(x, y));
                break;
            }
        }
        if (seeds.Count >= 3) {
            Color pc = px[seeds[0].X, seeds[0].Y];
            int alike = 0;
            foreach (var s in seeds) if (Dist(px[s.X, s.Y], pc) < 40) alike++;
            if (alike >= 3) {
                var gone = new bool[n, n];
                var q = new Queue<Point>();
                foreach (var s in seeds) if (Dist(px[s.X, s.Y], pc) < 40) { gone[s.X, s.Y] = true; q.Enqueue(s); }
                var dirs = new[] { new Point(1, 0), new Point(-1, 0), new Point(0, 1), new Point(0, -1) };
                while (q.Count > 0) {
                    var p = q.Dequeue();
                    foreach (var d in dirs) {
                        int x = p.X + d.X, y = p.Y + d.Y;
                        if (x < 0 || y < 0 || x >= n || y >= n || gone[x, y]) continue;
                        Color c = px[x, y];
                        if (c.A < 30 || Dist(c, pc) <= 60) { gone[x, y] = true; q.Enqueue(new Point(x, y)); }
                    }
                }
                for (int y = 0; y < n; y++) for (int x = 0; x < n; x++) {
                    if (gone[x, y]) { px[x, y] = Color.Transparent; continue; }
                    bool rim = (x > 0 && gone[x - 1, y]) || (x < n - 1 && gone[x + 1, y]) || (y > 0 && gone[x, y - 1]) || (y < n - 1 && gone[x, y + 1]);
                    if (!rim) continue;
                    double f = Math.Min(1, Math.Max(0, (Dist(px[x, y], pc) - 60) / 120.0));
                    px[x, y] = Color.FromArgb((int)(px[x, y].A * f), px[x, y]);
                }
            }
        }
        // colour or mono: the mean saturation of what is left
        double sat = 0, lum = 0; int cnt = 0, x0 = n, y0 = n, x1 = -1, y1 = -1;
        for (int y = 0; y < n; y++) for (int x = 0; x < n; x++) {
            Color c = px[x, y];
            if (c.A < 40) continue;
            if (x < x0) x0 = x; if (y < y0) y0 = y; if (x > x1) x1 = x; if (y > y1) y1 = y;
            sat += Span(c) / 255.0; lum += Lum(c); cnt++;
        }
        if (cnt == 0) return "empty";
        bool darkInk = lum / cnt < 0.5;
        bool mono = sat / cnt < 0.10 && (allowMono || !darkInk);
        var tmp = new Bitmap(n, n);
        for (int y = 0; y < n; y++) for (int x = 0; x < n; x++) {
            Color c = px[x, y];
            if (mono) {
                double ink = darkInk ? 1 - Lum(c) : Lum(c);
                c = Color.FromArgb((int)(c.A * Math.Min(1, ink * 1.15)), 255, 255, 255);
            }
            tmp.SetPixel(x, y, c);
        }
        // crop to the logo, scale to fit 60 x 60, centred
        int w = x1 - x0 + 1, h = y1 - y0 + 1;
        double sc = 60.0 / Math.Max(w, h);
        float dw = (float)(w * sc), dh = (float)(h * sc);
        using (var g = Graphics.FromImage(dst)) {
            g.Clear(Color.Transparent);
            g.InterpolationMode = InterpolationMode.HighQualityBicubic;
            g.PixelOffsetMode = PixelOffsetMode.HighQuality;
            g.DrawImage(tmp, new RectangleF((n - dw) / 2, (n - dh) / 2, dw, dh), new RectangleF(x0, y0, w, h), GraphicsUnit.Pixel);
        }
        tmp.Dispose();
        return mono ? "mono" : "color";
    }
}
'@

# any image file -> <key>.png (colour) or <key>.mono.png (a mask the app tints with the theme's text colour)
function Save-Icon([string]$From, [string]$Key, [bool]$AllowMono = $true) {
    $img = [Drawing.Image]::FromFile($From)
    try {
        $big = [Drawing.Bitmap]::new(64, 64)
        $g = [Drawing.Graphics]::FromImage($big)
        $g.InterpolationMode = 'HighQualityBicubic'
        $g.PixelOffsetMode = 'HighQuality'
        $g.DrawImage($img, 0, 0, 64, 64)
        $g.Dispose()
        $bmp = [Drawing.Bitmap]::new(64, 64)
        $kind = [AkariAppIcon]::Process($big, $bmp, $AllowMono)
        $big.Dispose()
        foreach ($old in "$Key.png", "$Key.mono.png") { Remove-Item (Join-Path $out $old) -ErrorAction SilentlyContinue }
        $name = if ($kind -eq 'mono') { "$Key.mono.png" } else { "$Key.png" }
        $bmp.Save((Join-Path $out $name), [Drawing.Imaging.ImageFormat]::Png)
        $bmp.Dispose()
        $kind
    } finally { $img.Dispose() }
}

New-Item $out -ItemType Directory -Force | Out-Null
# downloads are kept in %TEMP%\akari-appicons, so a change to the image work needs no new download (-Refresh: again)
$cache = Join-Path ([IO.Path]::GetTempPath()) 'akari-appicons'
New-Item $cache -ItemType Directory -Force | Out-Null
$missing = @()
foreach ($k in $Sites.Keys) {
    if (-not $Force -and ((Test-Path (Join-Path $out "$k.png")) -or (Test-Path (Join-Path $out "$k.mono.png")))) { continue }
    $src = $Sites[$k]
    try {
        if ($src -like 'appx:*') {
            $file = $logos[$src.Substring(5)]
            if (-not $file) { $missing += "$k ($src not on this PC)"; continue }
        } else {
            $file = Join-Path $cache "$k.bin"
            if ($Refresh -or -not (Test-Path $file)) {
                $url = if ($src -like 'http*') { $src } elseif ($src -like '*/*') { "https://www.google.com/s2/favicons?domain_url=https://$src&sz=128" } else { "https://www.google.com/s2/favicons?domain=$src&sz=128" }
                Invoke-WebRequest $url -OutFile $file -UseBasicParsing
            }
        }
        $kind = Save-Icon $file $k ($src -notlike 'appx:*')
        Write-Host "$k <- $src ($kind)"
    } catch { $missing += "$k ($($_.Exception.Message))" }
}
if ($missing) { Write-Warning ("no icon: " + ($missing -join '; ')) }
