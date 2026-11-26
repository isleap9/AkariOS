# Shell: the window (plan docs/plans/2026-11-19-winui-3.md decision 5, the prototype docs/design/akarios-prototype.html):
# chrome and caption buttons, the theme (Set-AkariTheme) and accent (Set-AkariAccent), Mica, the title bar's Back and
# pane toggle, the NavigationView (pages, Optimize's sections, the stretching indicator, collapse), the search with its
# suggestions, page switching and history, toasts, the busy toast, the background job and the timer that drains the log
# queue. Dot-sourced by Akari.ps1 after UI\Pages.ps1.

# ---- settings.json (next to akari.log): Theme (System / Dark / Light), Accent (Akari / Windows), Animations (On /
# Off), SearchTip (seen)
if (-not $AkariSettingsPath) { $AkariSettingsPath = Join-Path (Split-Path $AkariLogFile) 'settings.json' }
function Read-AkariSettings {
    $s = @{}
    try { (Get-Content $AkariSettingsPath -Raw -ErrorAction Stop | ConvertFrom-Json).PSObject.Properties | ForEach-Object { $s[$_.Name] = $_.Value } } catch { }
    $s
}
function Save-AkariSetting([string]$Name, $Value) {
    $s = Read-AkariSettings
    $s[$Name] = $Value
    try { New-Item (Split-Path $AkariSettingsPath) -ItemType Directory -Force | Out-Null; ($s | ConvertTo-Json) | Set-Content $AkariSettingsPath }
    catch { Write-ErrLog "Could not save the setting ${Name}: $_" }
}
function Save-AkariThemeSetting([string]$Theme) { Save-AkariSetting 'Theme' $Theme }

# Settings › Animation effects off: every animation of this window off, whatever Windows says (read before any XAML)
if ([string](Read-AkariSettings).Animations -eq 'Off') {
    $script:AkariMotionOn = $false
    $script:AkariMotionText = Get-AkariMotionEntries (Get-Content "$Root\UI\Motion.xaml" -Raw) $false
    $AkariMotion = [Windows.Markup.XamlReader]::Parse('<ResourceDictionary xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" ' +
        'xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml">' + $script:AkariMotionText + '</ResourceDictionary>')
}

# ---- window
$window = Get-AkariXaml "$Root\UI\MainWindow.xaml"
# the WinUI controls and the fonts (UI\Controls.xaml), the Fluent icons (Ic.<name>, built by build\Icons.ps1)
$window.Resources.MergedDictionaries.Add((Get-AkariXaml "$Root\UI\Controls.xaml"))
$window.Resources.MergedDictionaries.Add((Get-AkariXaml "$Root\UI\Icons.xaml"))
foreach ($n in 'Shell', 'Body', 'TopBar', 'BackBtn', 'PaneBtn', 'Logo', 'TitleText', 'AppVersionText',
               'Nav', 'SearchBox', 'Search', 'SearchHint', 'SearchKey', 'NavFoot', 'NavList', 'NavLayer', 'NavPill', 'Layer', 'PageScroll', 'Page',
               'PageHeader', 'Crumbs', 'Heading', 'CatBars', 'StepsPanel', 'StepBody', 'HomePanel', 'Rows', 'StepFooter', 'StepBack', 'StepNext',
               'StepLabel', 'StepBar', 'StepFill', 'Toasts', 'BusyToast', 'BusyLogo', 'StatusText', 'StatusBar', 'StatusFill', 'StatusLoop',
               'ModalOverlay') { Set-Variable $n $window.FindName($n) }
$AppVersionText.Text = $AkariVersion
# the page glides on the mouse wheel (UI\Motion.ps1)
Enable-AkariSmoothScroll $PageScroll

# ---- theme: UI\Theme.Dark.xaml or UI\Theme.Light.xaml, merged first into the window's resources (every brush is a
# DynamicResource, so swapping the dictionary repaints the window); System follows Windows' app mode and changes with it
$AkariThemes = @('System', 'Dark', 'Light')
$script:ThemeDict = $null; $script:ThemeSetting = 'System'; $script:Theme = 'Dark'; $script:Mica = $false

function Get-AkariThemeSetting {
    $t = [string](Read-AkariSettings).Theme
    if ($t -in $AkariThemes) { $t } else { 'System' }
}

# System -> Dark or Light from AppsUseLightTheme (1 = light); Dark when it can't be read
function Resolve-AkariTheme([string]$Theme) {
    if ($Theme -ne 'System') { return $Theme }
    try { $v = Get-ItemPropertyValue 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize' 'AppsUseLightTheme' -ErrorAction Stop }
    catch { return 'Dark' }
    if ($v -eq 1) { 'Light' } else { 'Dark' }
}

# the body and the frame follow the theme: Mica (Windows 11) shows through Tint; Windows 10 uses the solid Bg.
# Attribute 20 (immersive dark mode) darkens the frame and Mica; no handle yet = before the window opens.
function Update-AkariFrame {
    $Body.SetResourceReference([Windows.Controls.Border]::BackgroundProperty, $(if ($script:Mica) { 'Tint' } else { 'Bg' }))
    $h = [Windows.Interop.WindowInteropHelper]::new($window).Handle
    if ($h -ne [IntPtr]::Zero) { $v = [int]($script:Theme -eq 'Dark'); [void][Akari.Dwm]::DwmSetWindowAttribute($h, 20, [ref]$v, 4) }
}

# Windows draws the caption buttons (WindowChrome's UseAeroCaptionButtons) on the frame under the window's content:
# Body leaves a hole where they are (DWMWA_CAPTION_BUTTON_BOUNDS, attribute 5, in device pixels from the window's
# corner), so they show through on Mica (Windows 11) or the frame (Windows 10). No bounds = no hole.
function Update-AkariCaptionHole {
    $Body.Clip = $null
    try {
        $h = [Windows.Interop.WindowInteropHelper]::new($window).Handle
        if ($h -eq [IntPtr]::Zero) { return }
        $r = [int[]]::new(4)
        if ([Akari.Dwm]::DwmGetWindowAttribute($h, 5, $r, 16) -ne 0 -or $r[2] -le $r[0]) { return }
        $src = [Windows.Interop.HwndSource]::FromHwnd($h)
        $m = $src.CompositionTarget.TransformFromDevice
        $a = $window.TranslatePoint($m.Transform([Windows.Point]::new($r[0], $r[1])), $Body)
        $b = $window.TranslatePoint($m.Transform([Windows.Point]::new($r[2], $r[3])), $Body)
        $all = [Windows.Media.RectangleGeometry]::new([Windows.Rect]::new(0, 0, $Body.ActualWidth, $Body.ActualHeight))
        $hole = [Windows.Media.RectangleGeometry]::new([Windows.Rect]::new($a, $b))
        $Body.Clip = [Windows.Media.CombinedGeometry]::new('Exclude', $all, $hole)
    } catch { Write-ErrLog "Caption buttons: $_" }
}

# the logo for the theme: Assets\AkariLogo-dark.png (white A) or AkariLogo-light.png (black A), each read once;
# AkariLogo.png when the theme's file is missing. The title bar's, the busy toast's and every toast's.
$script:LogoCache = @{}
function Get-AkariLogo {
    $name = $script:Theme
    if (-not $script:LogoCache.ContainsKey($name)) {
        $p = "$Root\Assets\AkariLogo-$($name.ToLowerInvariant()).png"
        if (-not (Test-Path -LiteralPath $p)) { $p = "$Root\Assets\AkariLogo.png" }
        $script:LogoCache[$name] = if (Test-Path -LiteralPath $p) {
            $bmp = [Windows.Media.Imaging.BitmapImage]::new()
            $bmp.BeginInit(); $bmp.UriSource = [Uri]$p; $bmp.CacheOption = 'OnLoad'; $bmp.EndInit(); $bmp.Freeze()
            $bmp
        }
    }
    $script:LogoCache[$name]
}
function Update-AkariLogo {
    $img = Get-AkariLogo
    foreach ($l in @($Logo, $BusyLogo) + @($script:LogoImages)) { if ($l) { $l.Source = $img } }
}
$script:LogoImages = [Collections.Generic.List[object]]::new()
# an Image of the logo that follows the theme (the hero's, the toasts')
function New-AkariLogoImage([double]$Size) {
    $i = [Windows.Controls.Image]::new()
    $i.Width = $Size; $i.Height = $Size
    [Windows.Media.RenderOptions]::SetBitmapScalingMode($i, 'HighQuality')
    $i.Source = Get-AkariLogo
    $script:LogoImages.Add($i)
    $i
}

# $Theme: System, Dark or Light; -Save keeps it in settings.json. The accent is put back after (Set-AkariAccent).
function Set-AkariTheme([string]$Theme = 'System', [switch]$Save) {
    if ($Theme -notin $AkariThemes) { $Theme = 'System' }
    $name = Resolve-AkariTheme $Theme
    $d = Get-AkariXaml "$Root\UI\Theme.$name.xaml"
    $md = $window.Resources.MergedDictionaries
    if ($script:ThemeDict) { [void]$md.Remove($script:ThemeDict) }
    $md.Insert(0, $d)
    $script:ThemeDict = $d; $script:ThemeSetting = $Theme; $script:Theme = $name
    Set-AkariAccent
    Update-AkariFrame
    Update-AkariLogo
    if ($Save) { Save-AkariThemeSetting $Theme }
}

# Settings' theme radios: a quick cross-fade (the prototype's veil: Bg to 60 % over 120 ms, the theme swapped, then
# faded away over 160 ms); motion off = at once
function Switch-AkariTheme([string]$Theme) {
    if (-not $window.IsVisible) { Set-AkariTheme $Theme -Save; return }
    $script:VeilTheme = $Theme
    Start-AkariVeil $script:ThemeVeil { Set-AkariTheme $script:VeilTheme -Save }
}
$script:ThemeVeil = [Windows.Controls.Border]::new()
$script:ThemeVeil.SetResourceReference([Windows.Controls.Border]::BackgroundProperty, 'Bg')
$script:ThemeVeil.IsHitTestVisible = $false; $script:ThemeVeil.Visibility = 'Collapsed'; $script:ThemeVeil.Opacity = 0
[Windows.Controls.Grid]::SetRowSpan($script:ThemeVeil, 2); [Windows.Controls.Grid]::SetColumnSpan($script:ThemeVeil, 2)
[void]$Shell.Children.Add($script:ThemeVeil)

# ---- accent (decision 2): Akari crimson (the theme files' values), or the Windows accent: the real user's AccentPalette
# (32 bytes, 8 RGBA: Light3, Light2, Light1, Base, Dark1, Dark2, Dark3, unused)
$AkariAccents = @('Akari', 'Windows')
function Get-AkariAccentSetting { $a = [string](Read-AkariSettings).Accent; if ($a -in $AkariAccents) { $a } else { 'Akari' } }

# puts the accent into the current theme dictionary: nothing to do for Akari crimson (the theme's own values)
function Set-AkariAccent {
    $script:Accent = Get-AkariAccentSetting
    if ($script:Accent -ne 'Windows' -or -not $script:ThemeDict) { return }
    $pal = $null
    try { $pal = Get-AkariRegValue 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Accent' 'AccentPalette' } catch { }
    $cols = Get-AkariAccentColors $pal $script:Theme
    if (-not $cols) { return }
    foreach ($k in $cols.Keys) {
        $v = $cols[$k]
        $b = [Windows.Media.SolidColorBrush]::new([Windows.Media.Color]::FromArgb([byte]$v[0], [byte]$v[1], [byte]$v[2], [byte]$v[3]))
        $b.Freeze()
        $script:ThemeDict[$k] = $b
    }
}

Set-AkariTheme (Get-AkariThemeSetting)
Initialize-AkariSteps

# every page: its nav glyph (a UI\Icons.xaml key); the title is the page's name unless it builds its own header
$Pages = [ordered]@{
    Home                = @{ Glyph = 'house' }
    'Install AkariOS'   = @{ Glyph = 'zap' }
    Optimize            = @{ Glyph = 'sliders-horizontal' }
    Downloads           = @{ Glyph = 'download' }
    'Install USB'       = @{ Glyph = 'usb' }
    'ISO Builder'       = @{ Glyph = 'disc-3' }
    Settings            = @{ Glyph = 'settings' }
    Search              = @{ Glyph = 'search' }
    # Legacy pages: the frozen AkariOS-Ultimate tweaks (ADR 0004), from the Optimize page
    Check      = @{ Glyph = 'activity' }
    Refresh    = @{ Glyph = 'refresh-cw' }
    Setup      = @{ Glyph = 'wrench' }
    Graphics   = @{ Glyph = 'monitor' }
    Windows    = @{ Glyph = 'app-window' }
    Hardware   = @{ Glyph = 'cpu' }
    Advanced   = @{ Glyph = 'flask-conical' }
}

# opens at the prototype's 1180 x 760 when the screen has room, else as big as the screen allows
$wa = [Windows.SystemParameters]::WorkArea
$window.Width = [Math]::Max($window.MinWidth, [Math]::Min(1180, $wa.Width - 40))
$window.Height = [Math]::Max($window.MinHeight, [Math]::Min(760, $wa.Height - 40))

# the window and taskbar icon: AkariLogo.ico (the one AkariOS.exe has), else AkariLogo.png
$logoPath = "$Root\Assets\AkariLogo.ico"
if (-not (Test-Path $logoPath)) { $logoPath = "$Root\Assets\AkariLogo.png" }
if (Test-Path $logoPath) {
    $window.Icon = [Windows.Media.Imaging.BitmapFrame]::Create([Uri]$logoPath, 'None', 'OnLoad')
}
$window.Add_SourceInitialized({
    $h = [Windows.Interop.WindowInteropHelper]::new($window).Handle
    # mica behind the whole window on windows 11; windows 10 keeps the solid body. So does a PC where DWM can't draw
    # Mica and the clear body would show black (WinUI's MicaBackdrop falls back the same way): a virtual machine,
    # WPF drawing in software (render tier 0: no GPU driver) or a Remote Desktop session.
    $build = [Environment]::OSVersion.Version.Build
    $noMica = $false
    try {
        $noMica = (Test-AkariVirtualMachine) -or ([Windows.Media.RenderCapability]::Tier -shr 16) -eq 0 -or
                  [Windows.SystemParameters]::IsRemoteSession
    } catch { Write-ErrLog "Mica check: $_" }
    if ($noMica) { Write-ErrLog 'Mica off: a virtual machine, software rendering or Remote Desktop' }
    if ($build -ge 22000 -and -not $noMica) {
        [Windows.Interop.HwndSource]::FromHwnd($h).CompositionTarget.BackgroundColor = [Windows.Media.Colors]::Transparent
        if ($build -ge 22621) {
            # DWMWA_SYSTEMBACKDROP_TYPE = DWMSBT_MAINWINDOW (mica)
            $v = 2
            $r = [Akari.Dwm]::DwmSetWindowAttribute($h, 38, [ref]$v, 4)
        } else {
            # first windows 11 release: the older undocumented mica switch
            $v = 1
            $r = [Akari.Dwm]::DwmSetWindowAttribute($h, 1029, [ref]$v, 4)
        }
        if ($r -eq 0) { $script:Mica = $true }
    }
    Update-AkariFrame
    Update-AkariCaptionHole
    # follow Windows: its app mode (WM_SETTINGCHANGE "ImmersiveColorSet", Theme = System) and its accent colour
    # (WM_DWMCOLORIZATIONCOLORCHANGED, 0x320, Accent = Windows)
    try {
        [Windows.Interop.HwndSource]::FromHwnd($h).AddHook([Windows.Interop.HwndSourceHook] {
            param($hwnd, $msg, $wParam, $lParam, [ref]$handled)
            if ($msg -eq 0x1A -and $lParam -ne [IntPtr]::Zero -and [Runtime.InteropServices.Marshal]::PtrToStringUni($lParam) -eq 'ImmersiveColorSet') {
                if ($script:ThemeSetting -eq 'System') { Set-AkariTheme 'System' } elseif ($script:Accent -eq 'Windows') { Set-AkariAccent }
            }
            if ($msg -eq 0x320 -and $script:Accent -eq 'Windows') { Set-AkariAccent }
            [IntPtr]::Zero
        })
    } catch { Write-ErrLog "Theme hook: $_" }
})
# maximized, windows pushes the frame past the screen edge: pad it back in
$window.Add_StateChanged({
    $max = ($window.WindowState -eq 'Maximized')
    $Shell.Margin = if ($max) { [Windows.Thickness]::new(8) } else { [Windows.Thickness]::new(0) }
    $window.Dispatcher.BeginInvoke([Action] { Update-AkariCaptionHole }, 'Loaded') | Out-Null
})
$window.Add_SizeChanged({ Update-AkariCaptionHole })
$window.Add_DpiChanged({ Update-AkariCaptionHole })

# the live log is the console window next to Akari (no log panel in the window); akari.log keeps a copy
function Add-Log([string]$m) {
    $line = "[{0}] {1}" -f (Get-Date -Format 'HH:mm:ss'), $m
    $color = switch -Regex ($m) {
        '^(Failed|Error)' { 'Red'; break }
        '^(Applied|Reverted|Done|Restore point created)' { 'Green'; break }
        '^(Already|Skipped)' { 'DarkGray'; break }
        '^(Warning|Restore point)' { 'Yellow'; break }
        default { 'Gray' }
    }
    try { [Console]::ForegroundColor = $color; [Console]::Out.WriteLine($line); [Console]::ResetColor() } catch { }
    Write-ErrLog $m
}

# ---- the NavigationView: its items (a NavItem radio button each: the icon, regular and filled for the selected one in
# AccText, the label, Optimize's chevron) and Optimize's sections indented under it (NavKids)
$AkariNav = [ordered]@{ Home = 'house'; 'Install AkariOS' = 'zap'; Optimize = 'sliders-horizontal'; Downloads = 'download'; 'Install USB' = 'usb'; 'ISO Builder' = 'disc-3' }
$script:NavItems = [ordered]@{}
$script:NavSync = $false

function New-AkariNavItem([string]$Page, [string]$Label, [string]$Icon, [double]$Indent = 0, [switch]$Parent) {
    $g = [Windows.Controls.Grid]::new()
    foreach ($w in 'Auto', '*', 'Auto') { $c = [Windows.Controls.ColumnDefinition]::new(); $c.Width = if ($w -eq '*') { [Windows.GridLength]::new(1, 'Star') } else { [Windows.GridLength]::Auto }; [void]$g.ColumnDefinitions.Add($c) }
    $ic = [Windows.Controls.Grid]::new()
    $ic.Margin = [Windows.Thickness]::new($Indent, 0, 0, 0)
    $ic.RenderTransformOrigin = [Windows.Point]::new(0.5, 0.5)
    $r = New-AkariIcon $Icon 16 'Tx'
    $f = New-AkariIcon "$Icon.Filled" 16 'AccText'
    $f.Visibility = 'Collapsed'
    [void]$ic.Children.Add($r); [void]$ic.Children.Add($f)
    [void]$g.Children.Add($ic)
    $lb = [Windows.Controls.TextBlock]::new()
    $lb.Text = $Label; $lb.VerticalAlignment = 'Center'; $lb.Margin = [Windows.Thickness]::new(16, 0, 0, 1)
    $lb.TextTrimming = 'CharacterEllipsis'
    [Windows.Controls.Grid]::SetColumn($lb, 1); [void]$g.Children.Add($lb)
    $chev = $null
    if ($Parent) {
        $chev = New-AkariIcon 'chevron-down' 12 'Mu'
        $chev.RenderTransformOrigin = [Windows.Point]::new(0.5, 0.5)
        $chev.RenderTransform = [Windows.Media.RotateTransform]::new()
        [Windows.Controls.Grid]::SetColumn($chev, 2); [void]$g.Children.Add($chev)
    }
    $rb = [Windows.Controls.RadioButton]::new()
    $rb.SetResourceReference([Windows.FrameworkElement]::StyleProperty, 'NavItem')
    $rb.GroupName = 'nav'
    $rb.Content = $g
    $rb.Tag = $Page
    $rb.Focusable = $true
    # nav icons scale to 90 % while pressed (Motion.Fast)
    $rb.Add_PreviewMouseLeftButtonDown({ param($s, $e) Start-AkariMotion $s.Content.Children[0] Scale $null 0.9 -Speed Fast })
    $rb.Add_PreviewMouseLeftButtonUp({ param($s, $e) Start-AkariMotion $s.Content.Children[0] Scale $null 1 -Speed Fast })
    $rb.Add_MouseLeave({ param($s, $e) Start-AkariMotion $s.Content.Children[0] Scale $null 1 -Speed Fast })
    $rb.Add_Click({ param($s, $e) Invoke-AkariNav ([string]$s.Tag) })
    $item = @{ Button = $rb; Regular = $r; Filled = $f; Label = $lb; Chevron = $chev; Page = $Page }
    $script:NavItems[$Page] = $item
    $item
}

foreach ($k in $AkariNav.Keys) {
    $it = New-AkariNavItem $k $k $AkariNav[$k] -Parent:($k -eq 'Optimize')
    [void]$NavList.Children.Add($it.Button)
    if ($k -eq 'Optimize') {
        # Optimize's sections, indented (the prototype's .kids, 48 px in): their height opens and closes (ADR 0008)
        $script:NavKids = [Windows.Controls.StackPanel]::new()
        $script:NavKids.ClipToBounds = $true
        $script:NavKids.Height = 0
        foreach ($s in $AkariSectionIcons.Keys) {
            $kid = New-AkariNavItem "$AkariCataloguePrefix$s" $s $AkariSectionIcons[$s] 36
            [void]$script:NavKids.Children.Add($kid.Button)
        }
        [void]$NavList.Children.Add($script:NavKids)
    }
}
$settingsItem = New-AkariNavItem 'Settings' 'Settings' 'settings'
[void]$NavFoot.Children.Add($settingsItem.Button)
$script:KidsOpen = $false

# the nav item a page shows as selected: Settings, a section (its kid, or Optimize while the pane is collapsed),
# Optimize for its landing page, the search, the Legacy pages; else the page's own item. Pure but for the tables.
function Get-AkariNavKey([string]$Page, [bool]$Compact = $false) {
    if ($Page -like "$AkariCataloguePrefix*") {
        $sec = (Split-AkariCatalogueKey $Page).Section
        if ($Compact) { return 'Optimize' }
        return "$AkariCataloguePrefix$sec"
    }
    if ($Page -in 'Search', 'Optimize' -or ($Page -in $AkariLegacyPages -and $Page -ne 'Downloads')) { return 'Optimize' }
    if ($Page -eq 'Unattend Generator') { return 'Install USB' }
    if ($Page -eq 'About') { return 'Settings' }
    $Page
}

# Optimize's sections open or close under it: the chevron turns 180 degrees, the height animates (Motion.Base)
function Set-AkariNavKids([bool]$Open) {
    if ($script:Compact) { $Open = $false }
    if ($Open -eq $script:KidsOpen) { return }
    $script:KidsOpen = $Open
    $ch = $script:NavItems['Optimize'].Chevron
    Start-AkariTurn $ch.RenderTransform $(if ($Open) { 180 } else { 0 })
    Set-AkariSize $script:NavKids Height $(if ($Open) { 'Auto' } else { 0 }) Base
    # the indicator follows its item as the list moves
    Start-AkariNavPillLater
}

# the selected item: Sub fill, the filled icon in AccText; the indicator stretches and slides to it
function Update-AkariNav([bool]$Animate = $true) {
    $key = Get-AkariNavKey $script:Cat $script:Compact
    $script:NavSync = $true
    try {
        foreach ($it in $script:NavItems.Values) {
            $on = ($it.Page -eq $key)
            $it.Button.IsChecked = $on
            $it.Regular.Visibility = if ($on) { 'Collapsed' } else { 'Visible' }
            $it.Filled.Visibility = if ($on) { 'Visible' } else { 'Collapsed' }
        }
    } finally { $script:NavSync = $false }
    $script:NavKey = $key
    if ($script:Cat -like "$AkariCataloguePrefix*" -or $script:Cat -in 'Search', 'Optimize') { Set-AkariNavKids $true }
    Start-AkariNavPillLater $Animate
}

# the indicator once the layout is done (an item that just moved or appeared has no place yet)
function Start-AkariNavPillLater([bool]$Animate = $true) {
    [void]$window.Dispatcher.BeginInvoke([Windows.Threading.DispatcherPriority]::Loaded, [Action[object]]{ param($a) Move-AkariNavIndicator $a }, $Animate)
}
function Move-AkariNavIndicator([bool]$Animate = $true) {
    $it = $script:NavItems[$script:NavKey]
    if (-not $it) { return }
    $b = $it.Button
    # a section's kid hidden in a closed list: Optimize's item instead
    if (-not $b.IsVisible -or $b.ActualHeight -le 0 -or ($script:NavKey -like "$AkariCataloguePrefix*" -and -not $script:KidsOpen)) { $b = $script:NavItems['Optimize'].Button }
    if ($b.ActualHeight -le 0) { return }
    $p = $b.TranslatePoint([Windows.Point]::new(0, 0), $NavLayer)
    Move-AkariNavPill $NavPill ($p.Y + ($b.ActualHeight - 16) / 2) $Animate
}

# a nav item was clicked: Optimize on its landing page opens or closes its sections; anything else opens its page
function Invoke-AkariNav([string]$Page) {
    if ($script:NavSync) { return }
    if ($Page -eq 'Optimize' -and $script:Cat -eq 'Optimize') { Set-AkariNavKids (-not $script:KidsOpen); return }
    Select-AkariPage $Page
}

# ---- the pane: 280 px, or 48 (icons only, a tooltip after 600 ms) with the pane toggle or under 1000 px of window
$script:Compact = $false; $script:UserCompact = $null
function Set-AkariCompact([bool]$Compact) {
    if ($Compact -eq $script:Compact) { return }
    $script:Compact = $Compact
    if ($Compact) { Set-AkariNavKids $false }
    Set-AkariSize $Nav Width $(if ($Compact) { 48 } else { 280 }) Slow
    $SearchBox.IsHitTestVisible = -not $Compact
    Start-AkariMotion $SearchBox Fade $null $(if ($Compact) { 0 } else { 1 }) -Speed Base
    foreach ($it in $script:NavItems.Values) {
        Start-AkariMotion $it.Label Fade $null $(if ($Compact) { 0 } else { 1 }) -Speed Fast
        if ($it.Chevron) { $it.Chevron.Visibility = if ($Compact) { 'Hidden' } else { 'Visible' } }
        $it.Button.ToolTip = if ($Compact) { $it.Label.Text } else { $null }
        $it.Button.Width = if ($Compact) { 40 } else { [double]::NaN }
        $it.Button.HorizontalAlignment = if ($Compact) { 'Left' } else { 'Stretch' }
    }
    $PaneBtn.ToolTip = if ($Compact) { 'Expand navigation' } else { 'Collapse navigation' }
    # the indicator moves with the width change (Optimize's item while the sections are hidden)
    $tm = [Windows.Threading.DispatcherTimer]::new()
    $tm.Interval = [TimeSpan]::FromMilliseconds(260)
    $tm.Add_Tick({ param($s, $e) $s.Stop(); Update-AkariNav $false })
    $tm.Start()
}
$PaneBtn.Add_Click({ $script:UserCompact = -not $script:Compact; Set-AkariCompact $script:UserCompact })
function Update-AkariWidth([double]$Width) {
    if ($Width -le 0) { return }
    if ($null -eq $script:UserCompact) { Set-AkariCompact ($Width -lt 1000) }
}
$window.Add_SizeChanged({ Update-AkariWidth $window.ActualWidth })
# the pages that fold on a narrow content layer (Home's tiles and facts)
$Layer.Add_SizeChanged({ param($s, $e) Update-AkariHomeWidth $e.NewSize.Width })

# ---- pages and history

# the page header (the native app's rule): the last part is the heading; the parts before it, when there are any, are a
# small line of links above it (Mu, Tx on hover) with a chevron after each. $Parts: strings, or @(label, page) for a
# link. $Parts empty = no header (Home).
function Set-AkariHeader($Parts) {
    $Crumbs.Children.Clear()
    $parts = @($Parts)
    if (-not $parts.Count) { $PageHeader.Visibility = 'Collapsed'; return }
    $PageHeader.Visibility = 'Visible'
    for ($i = 0; $i -lt $parts.Count - 1; $i++) {
        $p = $parts[$i]
        $b = [Windows.Controls.Button]::new()
        $b.SetResourceReference([Windows.FrameworkElement]::StyleProperty, 'Crumb')
        $b.Content = if ($p -is [array]) { $p[0] } else { $p }
        $b.Tag = if ($p -is [array]) { $p[1] } else { $p }
        $b.Add_Click({ param($s, $e) Open-AkariCrumb ([string]$s.Tag) })
        [void]$Crumbs.Children.Add($b)
        $c = New-AkariIcon 'chevron-right' 12 'Mu'
        $c.Margin = [Windows.Thickness]::new(6, 1, 6, 0); $c.VerticalAlignment = 'Center'
        [void]$Crumbs.Children.Add($c)
    }
    $Crumbs.Visibility = if ($parts.Count -gt 1) { 'Visible' } else { 'Collapsed' }
    $last = $parts[-1]
    $Heading.Text = if ($last -is [array]) { $last[0] } else { $last }
}
# a breadcrumb link: Install AkariOS goes back to its chooser
function Open-AkariCrumb([string]$Page) {
    if ($Page -eq 'Install AkariOS' -and $script:Mode -ne 'Choose') { Push-AkariHistory; $script:Mode = 'Choose'; $script:Step = 0; Show-Page; return }
    # the ISO Builder's crumb: its Start step, the picks kept (UI\IsoBuilder.ps1)
    if ($Page -eq 'ISO Builder' -and $script:Cat -eq 'ISO Builder') { Open-AkariIsoStart; return }
    Select-AkariPage $Page
}

# Back (the title bar, Alt+Left) walks the history: pages, the search, and the steps of a flow
$script:History = [Collections.Generic.List[object]]::new()
function Push-AkariHistory {
    $script:History.Add(@{ Cat = $script:Cat; Mode = $script:Mode; Step = $script:Step; Query = $script:Query })
    $BackBtn.IsEnabled = $true
}
function Step-AkariHistoryBack {
    # not while the page is locked (a Run); a background change leaves it usable
    if (-not $script:History.Count -or -not $Page.IsEnabled) { return }
    $h = $script:History[$script:History.Count - 1]
    $script:History.RemoveAt($script:History.Count - 1)
    $BackBtn.IsEnabled = [bool]$script:History.Count
    $script:Cat = $h.Cat; $script:Query = $h.Query
    if ($h.Cat -eq 'Install AkariOS' -and $h.Mode -in 'Choose', 'Guided' -and $script:Step -ne 3) { $script:Mode = $h.Mode; $script:Step = $h.Step }
    Show-Page
}
$BackBtn.Add_Click({ Step-AkariHistoryBack })

# shows the current page ($script:Cat); a debug run logs how long each build took
function Show-Page {
    $tm = Start-AkariUiTimer "page $($script:Cat)"
    try { Show-AkariPageNow } finally { Stop-AkariUiTimer $tm }
}

function Show-AkariPageNow {
    # a new page (or another search, or another step of a flow) comes in: scrolled to the top, each top-level child
    # rising from 28 px, staggered (Start-AkariPageEntrance)
    $key = "$($script:Cat)|$($script:Query)|$($script:Mode)|$($script:Step)|$(if ($script:Cat -eq 'ISO Builder') { $script:IsoState.Step })"
    $script:PageMoved = ($key -ne $script:PageMotionKey)
    $script:PageMotionKey = $key
    if ($script:PageMoved) { Reset-AkariScroll $PageScroll }
    Update-AkariNav
    $Rows.Children.Clear(); $StepBody.Children.Clear()
    $StepsPanel.Visibility = 'Collapsed'; $HomePanel.Visibility = 'Collapsed'
    Set-AkariFooter $false
    switch -Wildcard ($script:Cat) {
        'Home' { Set-AkariHeader @(); $HomePanel.Visibility = 'Visible'; Show-AkariHome }
        'Search' { Show-AkariCataloguePage $script:Query }
        "$AkariCataloguePrefix*" { Show-AkariCataloguePage '' }
        default {
            $StepsPanel.Visibility = 'Visible'
            switch ($script:Cat) {
                'Install AkariOS' { Show-AkariSteps }
                'Optimize' { Show-AkariOptimize }
                'Downloads' { Show-AkariDownloads }
                'Install USB' { Show-AkariUnattend }
                'ISO Builder' { Show-AkariIsoBuilder }
                'Settings' { Show-AkariSettings }
                default {
                    # Optimize › Legacy: the legacy tweaks of this page, each row acting right away
                    $StepsPanel.Visibility = 'Collapsed'
                    Set-AkariHeader @(@('Optimize', 'Optimize'), $script:Cat)
                    foreach ($t in @(Get-AkariLegacyList $script:Tweaks $script:Cat '')) {
                        if (-not $script:RowCache.ContainsKey($t.Id)) { $script:RowCache[$t.Id] = New-Row $t }
                        [void]$Rows.Children.Add($script:RowCache[$t.Id])
                        Update-Row $t
                    }
                    if (-not $Rows.Children.Count) { [void]$Rows.Children.Add((New-AkariEmpty 'search' 'Nothing here yet' '')) }
                }
            }
        }
    }
    Update-AkariCatalogueBars
    if ($script:PageMoved) { Start-AkariPageEntrance (@($PageHeader) + @($CatBars.Children) + @($StepBody.Children) + @($HomePanel.Children) + @($Rows.Children)) }
}

# opens page $Name, remembering the one left (Back)
function Open-AkariPage([string]$Name, [string]$From) {
    if ($Name -eq 'Unattend Generator') { $Name = 'Install USB' }
    if ($Name -eq 'About') { $Name = 'Settings' }
    # the Remove apps page is Downloads' Windows apps now
    if ($Name -eq 'Remove apps') { $Name = 'Downloads'; $script:DlSection = 'Windows' }
    if ($Name -ne $script:Cat -or $script:Query) { Push-AkariHistory }
    $script:Cat = $Name
    $script:Query = ''
    if ($Search.Text -and -not $Search.IsKeyboardFocusWithin) { $script:SearchQuiet = $true; try { $Search.Text = '' } finally { $script:SearchQuiet = $false } }
    Show-Page
}
function Select-AkariPage([string]$Name) { Open-AkariPage $Name $script:Cat }
# the Optimize page seen last (kept for callers): the landing page
function Get-AkariOptimizeTarget { 'Optimize' }

# ---- Guided's footer (.foot): slides up from the bottom when Guided shows, down when it leaves (Motion.Slow)
function Set-AkariFooter([bool]$On) {
    $was = $StepFooter.Visibility -eq 'Visible'
    if ($On -eq $was) { return }
    if ($On) {
        $StepFooter.Visibility = 'Visible'
        $StepFooter.UpdateLayout()
        Start-AkariMotion $StepFooter SlideY ([Math]::Max(72, $StepFooter.ActualHeight)) 0 -Speed Slow
    } else { $StepFooter.Visibility = 'Collapsed' }
}

# ---- toasts (.toast): the logo, a title, a line, a close button; stacking upwards at the bottom right, sliding in 40 px
# from the right (Motion.Page) and out (Motion.Base, the exit curve); they leave after about 4 seconds
function Show-AkariToast([string]$Title, [string]$Text = '') {
    $b = [Windows.Controls.Border]::new()
    $b.Width = 340; $b.Margin = [Windows.Thickness]::new(0, 8, 0, 0); $b.Padding = [Windows.Thickness]::new(16, 14, 16, 14)
    $b.CornerRadius = [Windows.CornerRadius]::new(8); $b.BorderThickness = [Windows.Thickness]::new(1)
    $b.SetResourceReference([Windows.Controls.Border]::BackgroundProperty, 'S2')
    $b.SetResourceReference([Windows.Controls.Border]::BorderBrushProperty, 'Fly')
    $fx = [Windows.Media.Effects.DropShadowEffect]::new(); $fx.BlurRadius = 16; $fx.ShadowDepth = 8; $fx.Direction = 270
    # an Effect is not a FrameworkElement: its colour is the theme's ShadeFly now (a toast lives seconds)
    $fx.Color = $window.FindResource('ShadeFly')
    $b.Effect = $fx
    $dp = [Windows.Controls.DockPanel]::new()
    $lg = New-AkariLogoImage 20
    $lg.Margin = [Windows.Thickness]::new(0, 0, 12, 0); $lg.VerticalAlignment = 'Top'
    [Windows.Controls.DockPanel]::SetDock($lg, 'Left'); [void]$dp.Children.Add($lg)
    $x = [Windows.Controls.Button]::new()
    $x.SetResourceReference([Windows.FrameworkElement]::StyleProperty, 'Ghost')
    $x.Width = 24; $x.Height = 24; $x.MinHeight = 24; $x.Padding = [Windows.Thickness]::new(0); $x.VerticalAlignment = 'Top'
    $x.Content = New-AkariIcon 'x' 12 'Mu'
    $x.Tag = $b
    $x.Add_Click({ param($s, $e) Hide-AkariToast $s.Tag })
    [Windows.Controls.DockPanel]::SetDock($x, 'Right'); [void]$dp.Children.Add($x)
    $sp = [Windows.Controls.StackPanel]::new()
    [void]$sp.Children.Add((New-AkariText $Title 14 'Tx' 'SemiBold'))
    if ($Text) { $t = New-AkariText $Text 12 'Mu'; $t.Margin = [Windows.Thickness]::new(0, 2, 0, 0); [void]$sp.Children.Add($t) }
    [void]$dp.Children.Add($sp)
    $b.Child = $dp
    $Toasts.Children.Insert(0, $b)
    Start-AkariMotion $b Fade 0 1 -Speed Page
    Start-AkariMotion $b Slide 40 0 -Speed Page
    $tm = [Windows.Threading.DispatcherTimer]::new()
    $tm.Interval = [TimeSpan]::FromMilliseconds(4200)
    $tm.Tag = $b
    $tm.Add_Tick({ param($s, $e) $s.Stop(); Hide-AkariToast $s.Tag })
    $tm.Start()
    $b
}
function Hide-AkariToast($Toast) {
    if (-not $Toast -or -not $Toast.Parent) { return }
    if (-not $script:AkariMotionOn) { $Toasts.Children.Remove($Toast); return }
    $Toast.IsHitTestVisible = $false
    Start-AkariMotion $Toast Fade 1 0 -Speed Base -Easing Exit
    Start-AkariMotion $Toast Slide 0 40 -Speed Base -Easing Exit
    $tm = [Windows.Threading.DispatcherTimer]::new()
    $tm.Interval = $AkariMotion['Motion.Base'].TimeSpan
    $tm.Tag = $Toast
    $tm.Add_Tick({ param($s, $e) $s.Stop(); if ($s.Tag.Parent) { $Toasts.Children.Remove($s.Tag) } })
    $tm.Start()
}

# ---- running actions in a background runspace: the sticky busy toast (the job's label, its progress, else the
# indeterminate bar). $Lock: the page can't be used meanwhile (the Catalogue keeps it usable: its changes queue up)
# -Quiet: no toast (a background read that leaves the page usable)
function Set-Busy([bool]$b, [string]$label = '', [bool]$Lock = $true, [switch]$Quiet) {
    $script:Busy = $b; $Page.IsEnabled = -not ($b -and $Lock); $StepFooter.IsEnabled = $Page.IsEnabled
    $StatusText.Text = if ($b -and $label) { $label } elseif ($b) { 'Working' + [char]0x2026 } else { 'Ready' }
    $script:BusyLabel = $StatusText.Text
    if ($b -and -not $Quiet) {
        if ($BusyToast.Visibility -ne 'Visible') {
            $BusyToast.Visibility = 'Visible'
            if ($Toasts.Children.IndexOf($BusyToast) -ne $Toasts.Children.Count - 1) { $Toasts.Children.Remove($BusyToast); [void]$Toasts.Children.Add($BusyToast) }
            Start-AkariMotion $BusyToast Fade 0 1 -Speed Page
            Start-AkariMotion $BusyToast Slide 40 0 -Speed Page
        }
    } else { $BusyToast.Visibility = 'Collapsed' }
    Set-AkariStatusProgress $null
}

# the busy toast's text and bar for a job's progress (Set-AkariProgress in the job: Done, Total, Step): a bar filled to
# Done / Total with "label (n of total): step", or the sliding bar while the job doesn't say
function Get-AkariProgressText([string]$Label, $Shared) {
    if (-not $Shared -or -not $Shared.Total) { return $Label }
    $n = [Math]::Min([int]$Shared.Done + 1, [int]$Shared.Total)
    $t = "$Label ($n of $($Shared.Total))"
    if ($Shared.Step) { $t += ": $($Shared.Step)" }
    $t
}
function Set-AkariStatusProgress($Shared) {
    $on = ($Shared -and $Shared.Total)
    $StatusLoop.Visibility = if ($on) { 'Collapsed' } else { 'Visible' }
    $was = $StatusFill.Visibility -eq 'Visible'
    $StatusFill.Visibility = if ($on) { 'Visible' } else { 'Collapsed' }
    if ($on) {
        $share = [Math]::Min(1, [double]$Shared.Done / [double]$Shared.Total)
        Start-AkariMotion $StatusFill Fill $(if ($was) { $null } else { $share }) $share -Speed Slow
        $StatusText.Text = Get-AkariProgressText $script:BusyLabel $Shared
    }
}

function Invoke-Code([string]$code, [string]$label, $meta = $null) {
    if ($script:Busy) { return }
    Set-Busy $true $label
    Add-Log $label
    $script:Job = Start-AkariJob $code $script:Queue "$Root\Core"
    $script:Job.Label = $label
    $script:Job.Meta = $meta
}

$timer = [Windows.Threading.DispatcherTimer]::new()
$timer.Interval = [TimeSpan]::FromMilliseconds(150)
$timer.Add_Tick({
    $m = $null
    while ($script:Queue.TryDequeue([ref]$m)) { Add-Log $m }
    $j = $script:Job
    if ($j -and $j.Shared -and -not $j.Handle.IsCompleted) {
        Set-AkariStatusProgress $j.Shared
        # the run page's rows and the Remove apps rows follow the job (UI\Steps.ps1, UI\Apps.ps1)
        if ($j.Kind -eq 'Apply') { Update-AkariRunPage $j.Shared }
        if ($j.Kind -eq 'Remove') { Update-AkariRemoveProgress $j.Shared }
        # the ISO Builder's Create ISO step: each stage's state (UI\IsoBuilder.ps1)
        if ($j.Kind -eq 'IsoBuild') { Update-AkariIsoStages $j.Shared }
    }
    if ($j -and $j.Handle.IsCompleted) {
        try { [void]$j.Ps.EndInvoke($j.Handle) } catch { Add-Log "Error: $($_.Exception.Message)" }
        foreach ($err in $j.Ps.Streams.Error) { Add-Log "Error: $($err.ToString())" }
        while ($script:Queue.TryDequeue([ref]$m)) { Add-Log $m }
        $j.Ps.Dispose(); $j.Rs.Dispose()
        if ($j.Meta) { Set-AkariRememberedState $j.Meta.Id ($j.Meta.Kind -eq 'Apply') }
        Add-Log "Done: $($j.Label)"
        $script:Job = $null
        Set-Busy $false
        $show = $true
        switch ($j.Kind) {
            'Apply' { Complete-AkariApply $j.Shared }
            'Remove' { Complete-AkariApply $j.Shared -Kind Remove }
            'Install' { Complete-AkariInstall $j.Shared; $show = $false }
            # Downloads' Uninstall and its installed read (UI\Steps.ps1)
            'Uninstall' { Complete-AkariUninstall $j.Shared; $show = $false }
            'AppsInstalled' { Complete-AkariInstalledRead $j.Shared; $show = $false }
            'Export' { Complete-AkariExport $j.Shared; $show = $false }
        }
        # the ISO Builder's jobs (UI\IsoBuilder.ps1): after Set-Busy, so a finished step can start the next
        if ("$($j.Kind)" -like 'Iso*') { Complete-AkariIsoJob $j }
        # Home's stats are read again the next time it shows
        $script:StatsFresh = $false
        # a Catalogue change updates its card only (the page stays as it is)
        if ("$($j.Kind)" -like 'Catalogue*') { Complete-AkariCatalogueJob $j } elseif ($show) { Show-Page }
        # what queued up meanwhile: Catalogue changes, installs
        Start-AkariCatalogueNext
        Start-AkariInstallNext
    }
})
$timer.Start()

function Confirm-Run([string]$text) {
    if (-not $text) { return $true }
    return (Confirm-AkariDialog $text 'Continue')
}

# ---- search (the nav's AutoSuggestBox): up to six Tweaks as you type, the match highlighted in AccText with
# "Section › Category" below; arrows move, Enter shows the results page, a suggestion opens its section and flashes the
# row; no match says so. Esc clears. Ctrl+F or Ctrl+E from anywhere.
$script:Suggest = [Windows.Controls.Primitives.Popup]::new()
$script:Suggest.AllowsTransparency = $true
$script:Suggest.PlacementTarget = $SearchBox
$script:Suggest.Placement = 'Bottom'
$script:Suggest.VerticalOffset = -8
$script:Suggest.HorizontalOffset = -16
$script:Suggest.StaysOpen = $false
$script:SuggestHi = 0

# the suggestions for $Query: the first six Tweaks whose name or description holds it. Pure but for the Catalogue.
function Get-AkariSuggestions([string]$Query, [int]$Max = 6) {
    if (-not $Query) { return @() }
    @(@((Get-AkariCatalogueOf $script:Tweaks).Tweaks) | Where-Object { "$($_.Name) $($_.Description)" -like "*$Query*" } | Select-Object -First $Max)
}

function Show-AkariSuggestions([string]$Query) {
    if (-not $Query) { $script:Suggest.IsOpen = $false; return }
    $hits = Get-AkariSuggestions $Query
    $outer = [Windows.Controls.Border]::new()
    $outer.Margin = [Windows.Thickness]::new(16, 12, 16, 24)
    $b = [Windows.Controls.Border]::new()
    $b.Width = 360; $b.MaxHeight = 420; $b.Padding = [Windows.Thickness]::new(0, 4, 0, 4)
    $b.CornerRadius = [Windows.CornerRadius]::new(8); $b.BorderThickness = [Windows.Thickness]::new(1)
    $b.SetResourceReference([Windows.Controls.Border]::BackgroundProperty, 'S2')
    $b.SetResourceReference([Windows.Controls.Border]::BorderBrushProperty, 'Fly')
    $sp = [Windows.Controls.StackPanel]::new()
    $script:SuggestRows = @()
    foreach ($t in $hits) {
        $r = [Windows.Controls.Border]::new()
        $r.Margin = [Windows.Thickness]::new(4, 2, 4, 2); $r.Padding = [Windows.Thickness]::new(12, 8, 12, 8)
        $r.CornerRadius = [Windows.CornerRadius]::new(4)
        $r.Background = [Windows.Media.Brushes]::Transparent
        $r.Tag = $t.Id
        $dp = [Windows.Controls.DockPanel]::new()
        $ic = New-AkariIcon (Get-AkariCategoryIcon $t.Category) 16 'Tx'
        $ic.Margin = [Windows.Thickness]::new(0, 0, 12, 0); $ic.VerticalAlignment = 'Center'
        [Windows.Controls.DockPanel]::SetDock($ic, 'Left'); [void]$dp.Children.Add($ic)
        $tx = [Windows.Controls.StackPanel]::new()
        $nm = [Windows.Controls.TextBlock]::new(); $nm.TextTrimming = 'CharacterEllipsis'
        foreach ($p in [regex]::Split([string]$t.Name, '(' + [regex]::Escape($Query) + ')', 'IgnoreCase')) {
            if (-not $p) { continue }
            $run = [Windows.Documents.Run]::new($p)
            if ($p -ieq $Query) { $run.FontWeight = 'SemiBold'; $run.SetResourceReference([Windows.Documents.TextElement]::ForegroundProperty, 'AccText') }
            [void]$nm.Inlines.Add($run)
        }
        [void]$tx.Children.Add($nm)
        $hs = if ($AkariCatalogueHeaders.ContainsKey($t.Section)) { $AkariCatalogueHeaders[$t.Section] } else { $t.Section }
        $where = New-AkariText "$hs $([char]0x203A) $($t.Category)" 12 'Ter'; $where.TextWrapping = 'NoWrap'; $where.TextTrimming = 'CharacterEllipsis'
        [void]$tx.Children.Add($where)
        [void]$dp.Children.Add($tx)
        $r.Child = $dp
        $r.Add_MouseEnter({ param($s, $e) $s.SetResourceReference([Windows.Controls.Border]::BackgroundProperty, 'Sub') })
        $r.Add_MouseLeave({ param($s, $e) if ($script:SuggestRows[$script:SuggestHi] -ne $s) { $s.Background = [Windows.Media.Brushes]::Transparent } })
        $r.Add_MouseLeftButtonUp({ param($s, $e) Open-AkariSuggestion ([string]$s.Tag) })
        [void]$sp.Children.Add($r)
        $script:SuggestRows += $r
    }
    $more = New-AkariText $(if ($hits.Count) { 'Press Enter to see every result' } else { "No Tweaks match `"$Query`"" }) 12 $(if ($hits.Count) { 'AccText' } else { 'Mu' })
    $more.Margin = [Windows.Thickness]::new(16, 8, 16, 8)
    [void]$sp.Children.Add($more)
    $b.Child = [Windows.Controls.ScrollViewer]::new()
    $b.Child.VerticalScrollBarVisibility = 'Auto'
    $b.Child.Content = $sp
    $outer.Child = $b
    $script:Suggest.Child = $outer
    $script:SuggestHi = 0
    Set-AkariSuggestHi 0
    $script:Suggest.IsOpen = $true
    Start-AkariMotion $outer Fade 0 1 -Speed Slow
    Start-AkariMotion $outer SlideY -12 0 -Speed Slow
}
function Set-AkariSuggestHi([int]$i) {
    $rows = @($script:SuggestRows)
    if (-not $rows.Count) { return }
    $script:SuggestHi = ($i + $rows.Count) % $rows.Count
    for ($n = 0; $n -lt $rows.Count; $n++) {
        if ($n -eq $script:SuggestHi) { $rows[$n].SetResourceReference([Windows.Controls.Border]::BackgroundProperty, 'Sub') } else { $rows[$n].Background = [Windows.Media.Brushes]::Transparent }
    }
}

# a suggestion: its section opens, scrolls to the row and flashes it
function Open-AkariSuggestion([string]$Id) {
    $script:Suggest.IsOpen = $false
    $t = Find-AkariTweak $Id
    if (-not $t) { return }
    $script:SearchQuiet = $true; try { $Search.Text = '' } finally { $script:SearchQuiet = $false }
    Select-AkariPage "$AkariCataloguePrefix$($t.Section)/$($t.Category)"
    $script:FlashId = $Id
    [void]$window.Dispatcher.BeginInvoke([Windows.Threading.DispatcherPriority]::ContextIdle, [Action]{
        $e = $script:CatCards[$script:FlashId]
        if (-not $e -or -not $e.Card.IsVisible) { return }
        $p = $e.Card.TranslatePoint([Windows.Point]::new(0, 0), $PageScroll)
        Start-AkariScrollTo $PageScroll ($PageScroll.VerticalOffset + $p.Y - ($PageScroll.ActualHeight - $e.Card.ActualHeight) / 2)
        # the flash: the card dims and comes back twice (the prototype's highlight)
        Start-AkariFlash $e.Card
    })
}

# Enter: the results page for the text
function Open-AkariSearch([string]$Query) {
    $script:Suggest.IsOpen = $false
    if (-not $Query) { return }
    Push-AkariHistory
    $script:Cat = 'Search'; $script:Query = $Query
    Show-Page
}

if ($null -eq $AkariSearchDelay) { $AkariSearchDelay = 0 }
$Search.Add_TextChanged({
    if ($script:SearchQuiet) { return }
    Hide-AkariSearchTip
    Show-AkariSuggestions $Search.Text.Trim()
})
$Search.Add_PreviewKeyDown({
    param($s, $e)
    switch ($e.Key) {
        'Down' { Set-AkariSuggestHi ($script:SuggestHi + 1); $e.Handled = $true }
        'Up' { Set-AkariSuggestHi ($script:SuggestHi - 1); $e.Handled = $true }
        'Return' { Open-AkariSearch $Search.Text.Trim(); $e.Handled = $true }
        'Escape' { $script:SearchQuiet = $true; try { $Search.Text = '' } finally { $script:SearchQuiet = $false }; $script:Suggest.IsOpen = $false; [void]$PageScroll.Focus(); $e.Handled = $true }
    }
})
$Search.Add_GotKeyboardFocus({ $SearchKey.Visibility = 'Collapsed' })
$Search.Add_LostKeyboardFocus({ $SearchKey.Visibility = 'Visible' })
function Enter-AkariSearch {
    if ($script:Compact) { $script:UserCompact = $false; Set-AkariCompact $false }
    [void]$Search.Focus()
    $Search.SelectAll()
}
$window.Add_PreviewKeyDown({
    param($s, $e)
    $ctrl = [Windows.Input.Keyboard]::Modifiers -eq 'Control'
    if ($ctrl -and $e.Key -in 'F', 'E') { Enter-AkariSearch; $e.Handled = $true }
    if ([Windows.Input.Keyboard]::Modifiers -eq 'Alt' -and $e.SystemKey -eq 'Left') { Step-AkariHistoryBack; $e.Handled = $true }
})

# the first run: a TeachingTip next to the search box ("Search every Tweak", Ctrl+F), gone on Got it or any click
$script:SearchTip = $null
function Show-AkariSearchTip {
    if ([string](Read-AkariSettings).SearchTip -eq 'Seen' -or $script:Compact) { return }
    $n = @((Get-AkariCatalogueOf $script:Tweaks).Tweaks).Count
    $p = [Windows.Controls.Primitives.Popup]::new()
    $p.AllowsTransparency = $true; $p.PlacementTarget = $SearchBox; $p.Placement = 'Right'; $p.HorizontalOffset = 0; $p.VerticalOffset = -20
    $b = [Windows.Controls.Border]::new()
    $b.Width = 300; $b.Padding = [Windows.Thickness]::new(16); $b.Margin = [Windows.Thickness]::new(14, 12, 16, 24)
    $b.CornerRadius = [Windows.CornerRadius]::new(8); $b.BorderThickness = [Windows.Thickness]::new(1)
    $b.SetResourceReference([Windows.Controls.Border]::BackgroundProperty, 'S2')
    $b.SetResourceReference([Windows.Controls.Border]::BorderBrushProperty, 'Fly')
    $sp = [Windows.Controls.StackPanel]::new()
    $t = New-AkariText 'Search every Tweak' 14 'Tx' 'SemiBold'; $t.Margin = [Windows.Thickness]::new(0, 0, 0, 4)
    [void]$sp.Children.Add($t)
    [void]$sp.Children.Add((New-AkariText "$n Tweaks across Optimize, Customize, Hardware, Advanced and Tools. Press Ctrl+F from anywhere." 12 'Mu'))
    $ok = [Windows.Controls.Button]::new()
    $ok.SetResourceReference([Windows.FrameworkElement]::StyleProperty, 'Accent')
    $ok.MinWidth = 0; $ok.Content = 'Got it'; $ok.HorizontalAlignment = 'Right'; $ok.Margin = [Windows.Thickness]::new(0, 12, 0, 0)
    $ok.Add_Click({ Hide-AkariSearchTip })
    [void]$sp.Children.Add($ok)
    $b.Child = $sp
    $p.Child = $b
    $script:SearchTip = $p
    $p.IsOpen = $true
    Start-AkariMotion $b Fade 0 1 -Speed Slow
    Start-AkariMotion $b SlideY -12 0 -Speed Slow
}
function Hide-AkariSearchTip {
    if (-not $script:SearchTip) { return }
    $script:SearchTip.IsOpen = $false
    $script:SearchTip = $null
    Save-AkariSetting 'SearchTip' 'Seen'
}
$window.Add_PreviewMouseDown({ param($s, $e) if ($script:SearchTip -and -not $script:SearchTip.IsMouseOver) { Hide-AkariSearchTip } })

# ---- go
$window.Add_Loaded({
    # a debug run ($env:AKARI_UI_TIMING): launch time and UI-thread stalls to akari.log (UI\Motion.ps1)
    Start-AkariStallWatch { $script:Cat }
    Update-AkariWidth $window.ActualWidth
    Show-Page
    Write-AkariProblems $loaded.Problems { param($m) Add-Log $m }
    Add-Log 'Ready.'
    $script:Busy = $false
    # the first-run tip, once the page is in
    $tt = [Windows.Threading.DispatcherTimer]::new()
    $tt.Interval = [TimeSpan]::FromMilliseconds(1400)
    $tt.Add_Tick({ param($s, $e) $s.Stop(); if ($script:Cat -eq 'Home') { Show-AkariSearchTip } })
    $tt.Start()
})
# errors inside button handlers: show them in the console (and akari.log) instead of losing them
$window.Dispatcher.Add_UnhandledException({
    param($s, $ev)
    $ev.Handled = $true
    Add-Log "Error: UI: $($ev.Exception.Message)"
    Set-Busy $false
})
# ---- closing while something runs or waits: one question naming it all (the native app's ClosingGuard), then, with
# nothing running, the Safe Mode changes waiting (Request-AkariSafeModeClose, UI\CataloguePage.ps1)
function Get-AkariRunningLines {
    @(
        if ($script:Job -and "$($script:Job.Kind)" -ne 'AppsInstalled') { if ($script:Job.Label) { [string]$script:Job.Label } else { [string]$script:BusyLabel } }
        $w = @($script:InstallQueue).Count - $(if ($script:Installing) { 1 } else { 0 })
        if ($w -gt 0) { "$w app$(if ($w -ne 1) { 's' }) waiting to install" }
        $c = @($script:CatQueue).Count
        if ($c -gt 0) { "$c change$(if ($c -ne 1) { 's' }) from Optimize waiting" }
    )
}
# the question's text (pure)
function Get-AkariClosingText([string[]]$Lines) {
    "These are still running:`n" + ((@($Lines) | ForEach-Object { "- $_" }) -join "`n") +
        "`n`nClose AkariOS anyway? What is running may be left half done, and what waits won't run."
}
$window.Add_Closing({
    param($s, $ev)
    $lines = @(Get-AkariRunningLines)
    if ($lines.Count) {
        if (-not (Confirm-AkariDialog (Get-AkariClosingText $lines) 'Close anyway' 'Wait' 'Warning' 'Close AkariOS?')) { $ev.Cancel = $true; return }
    } elseif (Get-Command Request-AkariSafeModeClose -ErrorAction SilentlyContinue) {
        if (Request-AkariSafeModeClose) { $ev.Cancel = $true; return }
    }
    $timer.Stop()
})
