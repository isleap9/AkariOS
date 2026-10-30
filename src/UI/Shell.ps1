# Shell: window chrome, theme (Set-AkariTheme), Mica, caption buttons, top bar (tabs, Optimize's sub-header), search, page switching, status bar,
# the background job and the timer that drains the log queue. Dot-sourced by Akari.ps1 after UI\Steps.ps1.

# ---- window
$window = [Windows.Markup.XamlReader]::Parse((Get-Content "$Root\UI\MainWindow.xaml" -Raw))
# WinUI-style controls for Install AkariOS (switch, combobox, setting card, ...)
$window.Resources.MergedDictionaries.Add([Windows.Markup.XamlReader]::Parse((Get-Content "$Root\UI\Controls.xaml" -Raw)))
# the Lucide icons (Ic.<name> geometries, built by build\Icons.ps1)
$window.Resources.MergedDictionaries.Add([Windows.Markup.XamlReader]::Parse((Get-Content "$Root\UI\Icons.xaml" -Raw)))
foreach ($n in 'Tabs', 'Search', 'SearchBox', 'SearchBtn', 'SearchHint', 'SubNav', 'Sections', 'Chips', 'RemoveApps', 'Heading', 'Rows', 'Page', 'Logo', 'HomePanel',
               'Shell', 'Body', 'Main', 'TopBar', 'HomeTiles', 'HeaderIcon', 'HeaderSub', 'StatusDot', 'StatusRing', 'StatusText', 'StatusBar',
               'CapMin', 'CapMax', 'CapMaxGlyph', 'CapClose', 'StepsPanel', 'StepDots', 'StepBody', 'StepFooter', 'StepBack', 'StepNext',
               'UpdateBar', 'UpdateText', 'UpdateOpen', 'AppVersion', 'AppVersionText', 'MenuBtn', 'CatBars',
               'PageHeader', 'TitleText', 'HeroOver', 'HeroOneClick', 'HeroChoose', 'HeroStats') { Set-Variable $n $window.FindName($n) }
$AppVersionText.Text = "AkariOS $AkariVersion"

# ---- fonts (Get-AkariFonts, UI\Cards.ps1): FontDisplay, FontText, FontMono; Dialog.ps1 gets them through the
# window's resources
$f = Get-AkariFonts "$Root\Assets\Fonts"
foreach ($k in $f.Keys) { $window.Resources[$k] = $f[$k] }

# ---- theme: UI\Theme.Dark.xaml or UI\Theme.Light.xaml, merged first into the window's resources (every brush is a
# DynamicResource, so swapping the dictionary repaints the window). The choice (System, Dark, Light) is settings.json's
# Theme, next to akari.log; System follows Windows' app mode and changes with it.
if (-not $AkariSettingsPath) { $AkariSettingsPath = Join-Path (Split-Path $AkariLogFile) 'settings.json' }
$AkariThemes = @('System', 'Dark', 'Light')
$script:ThemeDict = $null; $script:ThemeSetting = 'System'; $script:Theme = 'Dark'; $script:Mica = $false

function Read-AkariSettings {
    $s = @{}
    try { (Get-Content $AkariSettingsPath -Raw -ErrorAction Stop | ConvertFrom-Json).PSObject.Properties | ForEach-Object { $s[$_.Name] = $_.Value } } catch { }
    $s
}

function Get-AkariThemeSetting {
    $t = [string](Read-AkariSettings).Theme
    if ($t -in $AkariThemes) { $t } else { 'System' }
}

function Save-AkariThemeSetting([string]$Theme) {
    $s = Read-AkariSettings
    $s.Theme = $Theme
    try { New-Item (Split-Path $AkariSettingsPath) -ItemType Directory -Force | Out-Null; ($s | ConvertTo-Json) | Set-Content $AkariSettingsPath }
    catch { Write-ErrLog "Could not save the theme: $_" }
}

# System -> Dark or Light from AppsUseLightTheme (1 = light); Dark when it can't be read
function Resolve-AkariTheme([string]$Theme) {
    if ($Theme -ne 'System') { return $Theme }
    try { $v = Get-ItemPropertyValue 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize' 'AppsUseLightTheme' -ErrorAction Stop }
    catch { return 'Dark' }
    if ($v -eq 1) { 'Light' } else { 'Dark' }
}

# the body and the frame follow the theme: Mica (Windows 11) shows through Tint in dark only; light and Windows 10
# use the solid Bg. Attribute 20 (immersive dark mode) darkens the frame and Mica; no handle yet = before the window opens.
function Update-AkariFrame {
    $Body.SetResourceReference([Windows.Controls.Border]::BackgroundProperty, $(if ($script:Mica -and $script:Theme -eq 'Dark') { 'Tint' } else { 'Bg' }))
    $h = [Windows.Interop.WindowInteropHelper]::new($window).Handle
    if ($h -ne [IntPtr]::Zero) { $v = [int]($script:Theme -eq 'Dark'); [void][Akari.Dwm]::DwmSetWindowAttribute($h, 20, [ref]$v, 4) }
}

# the title bar logo for the theme: Assets\AkariLogo-dark.png (white A) or AkariLogo-light.png (black A), each read
# once; AkariLogo.png when the theme's file is missing
$script:LogoCache = @{}
function Update-AkariLogo {
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
    if ($Logo) { $Logo.Source = $script:LogoCache[$name] }
}

# $Theme: System, Dark or Light; -Save keeps it in settings.json
function Set-AkariTheme([string]$Theme = 'System', [switch]$Save) {
    if ($Theme -notin $AkariThemes) { $Theme = 'System' }
    $name = Resolve-AkariTheme $Theme
    $d = [Windows.Markup.XamlReader]::Parse((Get-Content "$Root\UI\Theme.$name.xaml" -Raw))
    $md = $window.Resources.MergedDictionaries
    if ($script:ThemeDict) { [void]$md.Remove($script:ThemeDict) }
    $md.Insert(0, $d)
    $script:ThemeDict = $d; $script:ThemeSetting = $Theme; $script:Theme = $name
    Update-AkariFrame
    Update-AkariLogo
    if ($Save) { Save-AkariThemeSetting $Theme }
}
Set-AkariTheme (Get-AkariThemeSetting)
Initialize-AkariSteps

# every page: its icon (a Lucide name, UI\Icons.xaml) and the subtitle under the page title. The tabs open Home,
# Install AkariOS, Optimize (its sub-header: the Catalogue's pages and the Legacy ones, $AkariLegacyPages), Downloads
# and Install USB; About is in the options menu.
$Pages = [ordered]@{
    Home       = @{ Glyph = 'house'; Sub = 'Choose how you want to optimize Windows' }
    # Install AkariOS: One-click, or Guided (pick the Tweaks, review, apply once)
    'Install AkariOS' = @{ Glyph = 'zap'; Sub = 'Optimize Windows in one click, or pick each change yourself' }
    # Downloads: the Guided Install cards on their own (apps, runtimes, tools; Store apps the debloat removed)
    Downloads  = @{ Glyph = 'download'; Sub = 'Install apps, runtimes and tools, from winget where possible' }
    # Remove apps (the Catalogue sidebar): the Guided Remove tables on their own
    'Remove apps' = @{ Glyph = 'trash-2'; Sub = 'Store apps, optional features, Windows features and legacy apps to remove' }
    # Install USB (UI\Unattend.ps1): the Home tile, Schneegans' unattend generator on one long page
    'Install USB' = @{ Glyph = 'usb'; Sub = 'An autounattend.xml for a Windows install USB, after Schneegans'' generator' }
    # About & Updates (UI\About.ps1): the Home link and the update bar open it
    About      = @{ Glyph = 'info'; Sub = 'Version, updates and credits' }
    # Legacy pages: the frozen AkariOS-Ultimate tweaks (ADR 0004)
    Check      = @{ Glyph = 'activity'; Sub = 'Check your BIOS, storage, RAM and GPU, and stress test them' }
    Refresh    = @{ Glyph = 'refresh-cw'; Sub = 'Reinstall or reset Windows, and get a fresh install ready' }
    Setup      = @{ Glyph = 'wrench'; Sub = 'First steps on a new install: activation, startup apps, updates' }
    Graphics   = @{ Glyph = 'monitor'; Sub = 'Clean and install GPU drivers, and tune NVIDIA, AMD and Intel' }
    Windows    = @{ Glyph = 'app-window'; Sub = 'Start menu, taskbar, theme and the rest of Windows' }
    Hardware   = @{ Glyph = 'cpu'; Sub = 'Mouse, controller, monitor and network' }
    Advanced   = @{ Glyph = 'flask-conical'; Sub = 'Security, CPU and display pipeline tweaks for experienced users' }
}

# opens wide enough for the whole top bar (1360 x 800) when the screen has room, else as big as the screen allows
$wa = [Windows.SystemParameters]::WorkArea
$window.Width = [Math]::Max($window.MinWidth, [Math]::Min(1360, $wa.Width - 40))
$window.Height = [Math]::Max($window.MinHeight, [Math]::Min(800, $wa.Height - 40))

# the window and taskbar icon: AkariLogo.ico (the one AkariOS.exe has; Windows picks the frame for each size), else
# AkariLogo.png (the title bar logo follows the theme: Update-AkariLogo)
$logoPath = "$Root\Assets\AkariLogo.ico"
if (-not (Test-Path $logoPath)) { $logoPath = "$Root\Assets\AkariLogo.png" }
if (Test-Path $logoPath) {
    $window.Icon = [Windows.Media.Imaging.BitmapFrame]::Create([Uri]$logoPath, 'None', 'OnLoad')
}
$window.Add_SourceInitialized({
    $h = [Windows.Interop.WindowInteropHelper]::new($window).Handle
    # no system menu: windows stops drawing its own caption buttons under ours
    [void][Akari.Dwm]::SetWindowLong($h, -16, ([Akari.Dwm]::GetWindowLong($h, -16) -band (-bnot 0x80000)))
    # mica behind the whole window on windows 11; windows 10 keeps the solid black body
    $build = [Environment]::OSVersion.Version.Build
    if ($build -ge 22000) {
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
    # the frame (dark or light) and the body over Mica, for the current theme
    Update-AkariFrame
    # Theme = System: follow Windows when its app mode changes (WM_SETTINGCHANGE "ImmersiveColorSet")
    try {
        [Windows.Interop.HwndSource]::FromHwnd($h).AddHook([Windows.Interop.HwndSourceHook] {
            param($hwnd, $msg, $wParam, $lParam, [ref]$handled)
            if ($msg -eq 0x1A -and $script:ThemeSetting -eq 'System' -and $lParam -ne [IntPtr]::Zero -and
                [Runtime.InteropServices.Marshal]::PtrToStringUni($lParam) -eq 'ImmersiveColorSet') { Set-AkariTheme 'System' }
            [IntPtr]::Zero
        })
    } catch { Write-ErrLog "Theme hook: $_" }
})
# maximized, windows pushes the frame past the screen edge: pad it back in
$window.Add_StateChanged({
    $max = ($window.WindowState -eq 'Maximized')
    $Shell.Margin = if ($max) { [Windows.Thickness]::new(8) } else { [Windows.Thickness]::new(0) }
    # maximize button shows the restore glyph while maximized
    Set-AkariIcon $CapMaxGlyph $(if ($max) { 'copy' } else { 'square' })
    $CapMax.ToolTip = if ($max) { 'Restore' } else { 'Maximize' }
})
# caption buttons
$CapMin.Add_Click({ [Windows.SystemCommands]::MinimizeWindow($window) })
$CapMax.Add_Click({ if ($window.WindowState -eq 'Maximized') { [Windows.SystemCommands]::RestoreWindow($window) } else { [Windows.SystemCommands]::MaximizeWindow($window) } })
$CapClose.Add_Click({ $window.Close() })

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

function Show-Page {
    $q = $Search.Text.Trim()
    # Install AkariOS and the apps flows: the search filters the current step instead of searching the Legacy pages
    $onSteps = ($script:Cat -eq 'Install AkariOS' -or $AkariAppFlows.Contains($script:Cat))
    # About and Install USB: full pages, Back leads home
    $onAbout = (-not $q -and $script:Cat -in 'About', 'Install USB')
    $CatBars.Visibility = 'Collapsed'
    # Home: the hero is the title
    $PageHeader.Visibility = if (-not $q -and $script:Cat -eq 'Home') { 'Collapsed' } else { 'Visible' }
    Update-AkariTopBar
    # Optimize › Advanced (the Catalogue, UI\CataloguePage.ps1): its own pages and search
    if ($script:Cat -like "$AkariCataloguePrefix*") { Show-AkariCataloguePage $q; return }
    $StepsPanel.Visibility = if ($onSteps -or $onAbout) { 'Visible' } else { 'Collapsed' }
    $StepFooter.Visibility = $StepsPanel.Visibility
    if ($onSteps -or $onAbout) {
        $Rows.Children.Clear()
        $HomePanel.Visibility = 'Collapsed'
        $Heading.Text = $script:Cat
        $HeaderSub.Text = $Pages[$script:Cat].Sub
        Set-AkariIcon $HeaderIcon ([string]$Pages[$script:Cat].Glyph)
        if ($onAbout) { if ($script:Cat -eq 'About') { Show-AkariAbout } else { Show-AkariUnattend }; return }
        Enter-AkariFlow $script:Cat
        Show-AkariSteps
        return
    }
    $onHome = (-not $q -and $script:Cat -eq 'Home')
    if ($onHome) { Start-AkariHomeStats }
    $Rows.Children.Clear()
    if ($q) {
        $Heading.Text = 'Search'
        $HeaderSub.Text = "Results for `"$q`""
        Set-AkariIcon $HeaderIcon 'search'
    } else {
        $Heading.Text = $script:Cat
        $HeaderSub.Text = $Pages[$script:Cat].Sub
        Set-AkariIcon $HeaderIcon ([string]$Pages[$script:Cat].Glyph)
    }
    # Optimize › Legacy: the legacy tweaks of this page (or every legacy match of the search), each row acting right away
    $list = @(if (-not $onHome) { Get-AkariLegacyList $script:Tweaks $script:Cat $q })
    $HomePanel.Visibility = if ($onHome) { 'Visible' } else { 'Collapsed' }
    foreach ($t in $list) {
        if (-not $script:RowCache.ContainsKey($t.Id)) { $script:RowCache[$t.Id] = New-Row $t }
        [void]$Rows.Children.Add($script:RowCache[$t.Id])
        Update-Row $t
    }
    if (-not $list.Count -and -not $onHome) {
        $msg = [Windows.Controls.TextBlock]::new()
        $msg.Text = if ($q) { 'No scripts match.' } else { 'Nothing here yet.' }
        $msg.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, 'Mu')
        [void]$Rows.Children.Add($msg)
    }
}

# ---- running actions in a background runspace
# $Lock: the page can't be used meanwhile (the Catalogue keeps it usable: its changes queue up)
function Set-Busy([bool]$b, [string]$label = '', [bool]$Lock = $true) {
    $script:Busy = $b; $Page.IsEnabled = -not ($b -and $Lock); $StepFooter.IsEnabled = $Page.IsEnabled
    # status bar: green dot and Ready at rest, spinner + label + progress bar while running
    $StatusDot.Visibility = if ($b) { 'Collapsed' } else { 'Visible' }
    $StatusRing.Visibility = if ($b) { 'Visible' } else { 'Collapsed' }
    $StatusBar.Visibility = $StatusRing.Visibility
    $StatusText.Text = if ($b -and $label) { $label } elseif ($b) { 'Working' + [string][char]0x2026 } else { 'Ready' }
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
    if ($j -and $j.Handle.IsCompleted) {
        try { [void]$j.Ps.EndInvoke($j.Handle) } catch { Add-Log "Error: $($_.Exception.Message)" }
        foreach ($err in $j.Ps.Streams.Error) { Add-Log "Error: $($err.ToString())" }
        while ($script:Queue.TryDequeue([ref]$m)) { Add-Log $m }
        $j.Ps.Dispose(); $j.Rs.Dispose()
        if ($j.Meta) { Set-AkariRememberedState $j.Meta.Id ($j.Meta.Kind -eq 'Apply') }
        Add-Log "Done: $($j.Label)"
        $script:Job = $null
        Set-Busy $false
        if ($j.Kind -eq 'Apply') { Complete-AkariApply $j.Shared }
        if ($j.Kind -eq 'Export') { Complete-AkariExport $j.Shared }
        # a Catalogue change updates its card only (the page stays as it is)
        # Home's stats are read again the next time it shows
        $script:StatsFresh = $false
        if ("$($j.Kind)" -like 'Catalogue*') { Complete-AkariCatalogueJob $j } else { Show-Page }
        # Catalogue changes that queued up meanwhile
        Start-AkariCatalogueNext
    }
})
$timer.Start()

function Confirm-Run([string]$text) {
    if (-not $text) { return $true }
    return (Confirm-AkariDialog $text 'Continue')
}

# ---- top bar: the tabs, Optimize's sub-header (Sections, Category chips, Remove apps) and the search
# the tabs and their icons; Optimize opens the Optimize page seen last (Get-AkariOptimizeTarget)
$AkariTabs = [ordered]@{ Home = 'house'; 'Install AkariOS' = 'zap'; Optimize = 'sliders-horizontal'; Downloads = 'download'; 'Install USB' = 'usb' }

# the tab page $Page belongs to ('' = none: About). Pure.
function Get-AkariTab([string]$Page) {
    if ($Page -in 'Home', 'Install AkariOS', 'Downloads', 'Install USB') { return $Page }
    if ($Page -like "$AkariCataloguePrefix*" -or $Page -in $AkariLegacyPages -or $Page -in 'Optimize', 'Remove apps') { return 'Optimize' }
    ''
}

# the search box's placeholder on page $Page: what the search looks through there. Pure.
function Get-AkariSearchHint([string]$Page) {
    if ($Page -like "$AkariCataloguePrefix*") { return 'Search Optimize' }
    if ($Page -in 'Downloads', 'Remove apps') { return 'Search apps' }
    if ($Page -eq 'Install AkariOS') { return 'Filter this step' }
    'Search Legacy'
}

# Optimize's Sections, Legacy last: @{ Name; Header; Pages = @{ Key; Label; Icon } } (Downloads is a tab of its own)
function Get-AkariOptimizeSections {
    foreach ($c in Get-AkariCataloguePages $script:Tweaks) {
        [pscustomobject]@{ Name = $c.Section; Header = $c.Header
            Pages = @($c.Pages | ForEach-Object { [pscustomobject]@{ Key = $_.Key; Label = $_.Category; Icon = Get-AkariCategoryIcon $_.Category } }) }
    }
    [pscustomobject]@{ Name = 'Legacy'; Header = 'Legacy'
        Pages = @($AkariLegacyPages | Where-Object { $_ -ne 'Downloads' } | ForEach-Object { [pscustomobject]@{ Key = $_; Label = $_; Icon = [string]$Pages[$_].Glyph } }) }
}

# the Optimize tab's page: the Optimize page seen last, else the Catalogue's first, else the first Legacy page
$script:LastOptimize = ''
function Get-AkariOptimizeTarget {
    if ($script:LastOptimize) { return $script:LastOptimize }
    $first = @(Get-AkariCataloguePages $script:Tweaks | ForEach-Object { $_.Pages }) | Select-Object -First 1
    if ($first) { $first.Key } else { $AkariLegacyPages[0] }
}

# a pill with an icon and a label, in the text colour of the control (it changes when checked)
function New-AkariPill([string]$Style, [string]$Tag, [string]$Label, [string]$Icon, [string]$Group, [int]$Size = 16) {
    $sp = [Windows.Controls.StackPanel]::new()
    $sp.Orientation = 'Horizontal'
    $ic = New-AkariIcon $Icon $Size 'Inherit'
    $ic.VerticalAlignment = 'Center'; $ic.Margin = [Windows.Thickness]::new(0, 0, 8, 0)
    $lb = [Windows.Controls.TextBlock]::new()
    $lb.Text = $Label; $lb.VerticalAlignment = 'Center'
    [void]$sp.Children.Add($ic); [void]$sp.Children.Add($lb)
    $rb = [Windows.Controls.RadioButton]::new()
    $rb.Content = $sp; $rb.Tag = $Tag; $rb.GroupName = $Group
    $rb.SetResourceReference([Windows.FrameworkElement]::StyleProperty, $Style)
    $rb
}

$script:TabIcons = @()
foreach ($t in $AkariTabs.Keys) {
    $rb = New-AkariPill 'Tab' $t $t $AkariTabs[$t] 'tabs'
    $script:TabIcons += $rb.Content.Children[0]
    [void]$Tabs.Children.Add($rb)
}

# the Optimize sub-header for the current page: the Section picked, its Categories as chips, the current one checked
$script:OptSections = $null; $script:ChipSection = ''; $script:BarSync = $false
function Update-AkariSubNav {
    if (-not $script:OptSections) {
        $script:OptSections = @(Get-AkariOptimizeSections)
        foreach ($s in $script:OptSections) {
            # a ListBoxItem: a ComboBoxItem in a ListBox ignores clicks
            $it = [Windows.Controls.ListBoxItem]::new()
            $it.Content = $s.Header; $it.Tag = $s.Name
            # Legacy is being retired: a muted pill
            if ($s.Name -eq 'Legacy') { $it.Opacity = 0.65; $it.ToolTip = 'The old AkariOS-Ultimate pages, being retired as the others take them over' }
            [void]$Sections.Items.Add($it)
        }
    }
    $sec = $script:OptSections | Where-Object { @($_.Pages | ForEach-Object { $_.Key }) -contains $script:Cat } | Select-Object -First 1
    if (-not $sec) { return }
    $script:BarSync = $true
    try {
        $Sections.SelectedItem = @($Sections.Items | Where-Object { [string]$_.Tag -eq $sec.Name })[0]
        if ($script:ChipSection -ne $sec.Name) {
            $script:ChipSection = $sec.Name
            $Chips.Children.Clear()
            foreach ($p in $sec.Pages) { [void]$Chips.Children.Add((New-AkariPill 'Chip' $p.Key $p.Label $p.Icon 'chips' 14)) }
        }
        foreach ($c in $Chips.Children) { $c.IsChecked = ([string]$c.Tag -eq $script:Cat) }
    } finally { $script:BarSync = $false }
}

# the top bar for the current page: its tab checked, the sub-header on Optimize's pages, the search placeholder
function Update-AkariTopBar {
    $tab = Get-AkariTab $script:Cat
    $script:BarSync = $true
    try { foreach ($rb in $Tabs.Children) { $rb.IsChecked = ([string]$rb.Tag -eq $tab) } } finally { $script:BarSync = $false }
    $opt = ($script:Cat -like "$AkariCataloguePrefix*" -or ($script:Cat -in $AkariLegacyPages -and $script:Cat -ne 'Downloads'))
    if ($opt) { $script:LastOptimize = $script:Cat; Update-AkariSubNav }
    $SubNav.Visibility = if ($opt) { 'Visible' } else { 'Collapsed' }
    $SearchHint.Text = Get-AkariSearchHint $script:Cat
}

# opens page $Name ($From = the page left); an apps flow remembers where it was opened from; 'Optimize' = its tab's page
function Open-AkariPage([string]$Name, [string]$From) {
    if ($Name -eq 'Optimize') { $Name = Get-AkariOptimizeTarget }
    if ($AkariAppFlows.Contains($Name) -and $From -ne $Name) { Set-AkariFlowExit $From }
    $script:Cat = $Name
    if ($Search.Text) { $Search.Text = '' }
    Show-Page
}

# any page, from a tab, a chip, a tile or a button
function Select-AkariPage([string]$Name) { Open-AkariPage $Name $script:Cat }

$Tabs.AddHandler([Windows.Controls.Primitives.ToggleButton]::CheckedEvent, [Windows.RoutedEventHandler] {
    param($s, $ev)
    if (-not $script:BarSync) { Select-AkariPage ([string]$ev.OriginalSource.Tag) }
})
$Chips.AddHandler([Windows.Controls.Primitives.ToggleButton]::CheckedEvent, [Windows.RoutedEventHandler] {
    param($s, $ev)
    if (-not $script:BarSync) { Select-AkariPage ([string]$ev.OriginalSource.Tag) }
})
# a Section opens its first Category
$Sections.Add_SelectionChanged({
    if ($script:BarSync -or -not $Sections.SelectedItem) { return }
    $s = $script:OptSections | Where-Object { $_.Name -eq [string]$Sections.SelectedItem.Tag } | Select-Object -First 1
    if ($s -and $s.Pages) { Select-AkariPage $s.Pages[0].Key }
})
$RemoveApps.Add_Click({ Select-AkariPage 'Remove apps' })
$Search.Add_TextChanged({ Show-Page })

# narrow window: the top bar needs about 1300 px with the tab icons and the search box, about 980 with neither,
# and 880 without the wordmark too. Under 1320 px the search is an icon button that opens the box and the tabs show
# text only; under 1000 the wordmark goes. Ctrl+K opens and focuses the search at any width.
$script:Narrow = $false
function Set-AkariSearchOpen([bool]$Open) {
    $show = $Open -or -not $script:Narrow
    $SearchBox.Visibility = if ($show) { 'Visible' } else { 'Collapsed' }
    $SearchBtn.Visibility = if ($show) { 'Collapsed' } else { 'Visible' }
}
function Open-AkariSearch {
    Set-AkariSearchOpen $true
    $window.UpdateLayout()
    [void]$Search.Focus()
    $Search.SelectAll()
}
function Update-AkariWidth([double]$Width) {
    $script:Narrow = ($Width -lt 1320)
    $TitleText.Visibility = if ($Width -lt 1000) { 'Collapsed' } else { 'Visible' }
    foreach ($i in $script:TabIcons) { $i.Visibility = if ($script:Narrow) { 'Collapsed' } else { 'Visible' } }
    # Home's mode cards: four in a row, two under 1000 px
    $HomeTiles.Columns = if ($Width -lt 1000) { 2 } else { 4 }
    Set-AkariSearchOpen ([bool]$Search.Text -or $Search.IsKeyboardFocusWithin)
}
$window.Add_SizeChanged({ Update-AkariWidth $window.ActualWidth })
$SearchBtn.Add_Click({ Open-AkariSearch })
$Search.Add_LostKeyboardFocus({ if (-not $Search.Text) { Set-AkariSearchOpen $false } })
$window.Add_PreviewKeyDown({
    param($s, $e)
    if ($e.Key -eq 'K' -and [Windows.Input.Keyboard]::Modifiers -eq 'Control') { Open-AkariSearch; $e.Handled = $true }
})

# ---- Home: the hero (One-click, or Guided from its first step) and its stats
$HeroOver.Text = "AKARIOS $AkariVersion"
$HeroOneClick.Add_Click({ Start-AkariOneClick })
$HeroChoose.Add_Click({
    Select-AkariPage 'Install AkariOS'
    $script:Mode = 'Guided'; $script:Step = 0
    Show-AkariSteps
})

# a stat: a big number over its label, a rule between stats; the numbers are in $script:HomeStat
$script:HomeStat = @{}
foreach ($s in @(@('Tweaks', 'Tweaks'), @('Apps', 'Removable apps'), @('Applied', 'Changes applied'))) {
    if ($HeroStats.Children.Count) {
        $r = [Windows.Controls.Border]::new()
        $r.Width = 1; $r.Margin = [Windows.Thickness]::new(28, 6, 28, 6)
        $r.SetResourceReference([Windows.Controls.Border]::BackgroundProperty, 'Bd')
        [void]$HeroStats.Children.Add($r)
    }
    $sp = [Windows.Controls.StackPanel]::new()
    $n = [Windows.Controls.TextBlock]::new()
    $n.Text = [string][char]0x2014; $n.FontSize = 28; $n.FontWeight = 'Bold'
    Set-AkariFont $n 'Display'
    $l = [Windows.Controls.TextBlock]::new()
    $l.Text = $s[1]; $l.FontSize = 13
    $l.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, 'Mu')
    [void]$sp.Children.Add($n); [void]$sp.Children.Add($l)
    [void]$HeroStats.Children.Add($sp)
    $script:HomeStat[$s[0]] = $n
}

# $Stats: @{ Tweaks; Apps; Applied }, each a count or $null (a dash: not read)
function Set-AkariHomeStats($Stats) {
    foreach ($k in @($Stats.Keys)) {
        if ($script:HomeStat[$k]) { $script:HomeStat[$k].Text = if ($null -eq $Stats[$k]) { [string][char]0x2014 } else { '{0:N0}' -f [int]$Stats[$k] } }
    }
}

# the stats, read once and again after a change: Tweaks = the Catalogue's; removable apps = the Store apps on the PC
# outside the keep-list; changes applied = what Export would save (Get-AkariExportItems), read in a runspace
$script:StatsJob = $null; $script:StatsFresh = $false
function Start-AkariHomeStats {
    if ($script:StatsJob -or $script:StatsFresh) { return }
    $script:StatsFresh = $true
    Set-AkariHomeStats @{ Tweaks = @(Get-AkariCatalogueTweaks $script:Tweaks).Count }
    $q = { param($s) "'" + ([string]$s -replace "'", "''") + "'" }
    $shared = [hashtable]::Synchronized(@{})
    # the job loads the tweaks itself (a script block must not cross runspaces); its log stays quiet
    $code = @"
`$loaded = Get-AkariTweaks $(& $q "$Root\Tweaks")
try { `$AkariShared.Apps = @(Get-AkariAppxInstalled | Where-Object { `$e = Resolve-AkariEntry `$loaded.Groups "appx/`$_"; `$e -and -not `$e.Keep }).Count } catch { }
try { `$AkariShared.Applied = @(Get-AkariExportItems @(`$loaded.Tweaks)).Count } catch { }
"@
    $job = Start-AkariJob $code ([System.Collections.Concurrent.ConcurrentQueue[string]]::new()) "$Root\Core" $shared
    $script:StatsJob = $job
    $tm = [Windows.Threading.DispatcherTimer]::new()
    $tm.Interval = [TimeSpan]::FromMilliseconds(300)
    $tm.Tag = $job
    $tm.Add_Tick({
        param($s, $a)
        $j = $s.Tag
        # each stat as soon as it is read (the apps take seconds, the States about a minute)
        Complete-AkariHomeStats $j.Shared
        if (-not $j.Handle.IsCompleted) { return }
        $s.Stop()
        try { [void]$j.Ps.EndInvoke($j.Handle) } catch { Write-ErrLog "Home stats: $_" }
        $j.Ps.Dispose(); $j.Rs.Dispose()
        $script:StatsJob = $null
        Complete-AkariHomeStats $j.Shared
    })
    $tm.Start()
}
function Complete-AkariHomeStats($Shared) { Set-AkariHomeStats @{ Apps = $Shared.Apps; Applied = $Shared.Applied } }

# ---- Home: the mode cards under the hero: Optimize, Downloads, Install USB, Import / Export
$tile = New-AkariModeCard 'sliders-horizontal' 'Optimize' 'Manual, in-depth optimization for Windows. Recommended for power users.' $true
# the Optimize tab's page
$tile.Add_Click({ Select-AkariPage 'Optimize' })
[void]$HomeTiles.Children.Add($tile)
# Downloads: the Guided Install cards on their own
$tile = New-AkariModeCard 'download' 'Downloads' 'Install apps, game launchers, runtimes and tools, or bring back Store apps the debloat removed.' $true
$tile.Add_Click({ Select-AkariPage 'Downloads' })
[void]$HomeTiles.Children.Add($tile)
# Install USB: Schneegans' unattend generator, an autounattend.xml for a Windows install USB (UI\Unattend.ps1)
$tile = New-AkariModeCard 'usb' 'Install USB' 'Prepare a Windows install USB: an autounattend.xml with accounts, language, edition, disk and setup choices, after Schneegans'' generator.' $true
$tile.Add_Click({ Select-AkariPage 'Install USB' })
[void]$HomeTiles.Children.Add($tile)
$tile = New-AkariModeCard 'arrow-left-right' 'Import / Export settings' 'Save this PC''s settings to a file, or load them on another PC and review them in Guided.' $true
$tile.Add_Click({ Show-AkariImportExport })
[void]$HomeTiles.Children.Add($tile)
# 16 px between cards in any number of columns: 8 around each, the grid pulled out by 8
foreach ($t in $HomeTiles.Children) { $t.Margin = [Windows.Thickness]::new(8) }
$HomeTiles.Margin = [Windows.Thickness]::new(-8)

# ---- go
$window.Add_Loaded({
    Select-AkariPage $script:Cat
    Write-AkariProblems $loaded.Problems { param($m) Add-Log $m }
    Add-Log 'Ready.'
    $script:Busy = $false
})
# errors inside button handlers: show them in the console (and akari.log) instead of losing them
$window.Dispatcher.Add_UnhandledException({
    param($s, $ev)
    $ev.Handled = $true
    Add-Log "Error: UI: $($ev.Exception.Message)"
    Set-Busy $false
})
$window.Add_Closing({ $timer.Stop() })
