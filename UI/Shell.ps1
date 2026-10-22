# Shell: window chrome, Mica, caption buttons, sidebar, search, page switching, status bar,
# the background job and the timer that drains the log queue. Dot-sourced by Akari.ps1 after UI\Steps.ps1.

# ---- window
$window = [Windows.Markup.XamlReader]::Parse((Get-Content "$Root\UI\MainWindow.xaml" -Raw))
# WinUI-style controls for Install AkariOS (switch, combobox, setting card, ...)
$window.Resources.MergedDictionaries.Add([Windows.Markup.XamlReader]::Parse((Get-Content "$Root\UI\Controls.xaml" -Raw)))
foreach ($n in 'Nav', 'Search', 'Heading', 'Rows', 'Page', 'Logo', 'HomePanel',
               'Shell', 'Body', 'Main', 'PaneCol', 'PaneToggle', 'HomeTiles', 'HeaderIcon', 'HeaderSub', 'StatusDot', 'StatusRing', 'StatusText', 'StatusBar',
               'CapMin', 'CapMax', 'CapMaxGlyph', 'CapClose', 'StepsPanel', 'StepDots', 'StepBody', 'StepFooter', 'StepBack', 'StepNext',
               'UpdateBar', 'UpdateText', 'UpdateOpen', 'AboutLink', 'AppVersion') { Set-Variable $n $window.FindName($n) }
$AppVersion.Text = "AkariOS $AkariVersion"
Initialize-AkariSteps

# every page: icon glyph (Segoe Fluent Icons) and the subtitle under the page title. Home, Install AkariOS,
# Downloads and the Optimize chooser are full window; the sidebar holds only Optimize › Legacy ($AkariLegacyPages).
$Pages = [ordered]@{
    Home       = @{ Glyph = [char]0xE80F; Sub = 'Choose how you want to optimize Windows' }
    # Install AkariOS: One-click, or Guided (pick the Tweaks, review, apply once)
    'Install AkariOS' = @{ Glyph = [char]0xE896; Sub = 'Optimize Windows in one click, or pick each change yourself' }
    # Optimize (Manual mode): the Legacy / Advanced chooser
    Optimize   = @{ Glyph = [char]0xE713; Sub = 'Manual, in-depth optimization for Windows' }
    # Downloads: the Guided Install cards on their own (apps, runtimes, tools; Store apps the debloat removed)
    Downloads  = @{ Glyph = [char]0xE896; Sub = 'Install apps, runtimes and tools, from winget where possible' }
    # About & Updates (UI\About.ps1): the Home link and the update bar open it
    About      = @{ Glyph = [char]0xE946; Sub = 'Version, updates and credits' }
    # Legacy pages: the frozen AkariOS-Ultimate tweaks (ADR 0004)
    Check      = @{ Glyph = [char]0xE9D9; Sub = 'Check your BIOS, storage, RAM and GPU, and stress test them' }
    Refresh    = @{ Glyph = [char]0xE72C; Sub = 'Reinstall or reset Windows, and get a fresh install ready' }
    Setup      = @{ Glyph = [char]0xE90F; Sub = 'First steps on a new install: activation, startup apps, updates' }
    Graphics   = @{ Glyph = [char]0xE7F4; Sub = 'Clean and install GPU drivers, and tune NVIDIA, AMD and Intel' }
    Windows    = @{ Glyph = [char]0xE771; Sub = 'Start menu, taskbar, theme and the rest of Windows' }
    Hardware   = @{ Glyph = [char]0xE950; Sub = 'Mouse, controller, monitor and network' }
    Advanced   = @{ Glyph = [char]0xE945; Sub = 'Security, CPU and display pipeline tweaks for experienced users' }
}

$logoPath = "$Root\Assets\AkariLogo.png"
if (Test-Path $logoPath) {
    $bmp = [Windows.Media.Imaging.BitmapImage]::new()
    $bmp.BeginInit(); $bmp.UriSource = [Uri]$logoPath; $bmp.CacheOption = 'OnLoad'; $bmp.EndInit()
    $Logo.Source = $bmp
    $window.Icon = $bmp
}
$window.Add_SourceInitialized({
    $h = [Windows.Interop.WindowInteropHelper]::new($window).Handle
    # no system menu: windows stops drawing its own caption buttons under ours
    [void][Akari.Dwm]::SetWindowLong($h, -16, ([Akari.Dwm]::GetWindowLong($h, -16) -band (-bnot 0x80000)))
    # dark frame (also makes Mica dark)
    $v = 1
    [void][Akari.Dwm]::DwmSetWindowAttribute($h, 20, [ref]$v, 4)
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
        if ($r -eq 0) { $Body.Background = $window.FindResource('Tint') }
    }
})
# maximized, windows pushes the frame past the screen edge: pad it back in
$window.Add_StateChanged({
    $max = ($window.WindowState -eq 'Maximized')
    $Shell.Margin = if ($max) { [Windows.Thickness]::new(8) } else { [Windows.Thickness]::new(0) }
    # maximize button shows the restore glyph while maximized
    $CapMaxGlyph.Text = [string][char]$(if ($max) { 0xE923 } else { 0xE922 })
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

# sidebar shown (full or icon strip) or hidden; hidden, the page gets the same 16 px gutter on the left as on the right
function Set-AkariPane([bool]$Show) {
    $PaneCol.Width = [Windows.GridLength]::new($(if (-not $Show) { 0 } elseif ($script:PaneOpen) { 232 } else { 48 }))
    $Main.Margin = [Windows.Thickness]::new($(if ($Show) { 0 } else { 16 }), 0, 0, 0)
}

function Show-Page {
    $q = $Search.Text.Trim()
    # Install AkariOS and Downloads: the header search filters the current step instead of searching the Legacy pages
    $onSteps = ($script:Cat -in 'Install AkariOS', 'Downloads')
    # the Optimize chooser; a search typed there lists Legacy matches instead
    $onChooser = (-not $q -and $script:Cat -eq 'Optimize')
    # About & Updates: full window like the chooser, Back leads home
    $onAbout = (-not $q -and $script:Cat -eq 'About')
    # full-window pages like Home: no sidebar (Back leads home)
    if ($onSteps -or $onChooser -or $onAbout) { Set-AkariPane $false }
    $StepsPanel.Visibility = if ($onSteps -or $onChooser -or $onAbout) { 'Visible' } else { 'Collapsed' }
    $StepFooter.Visibility = $StepsPanel.Visibility
    if ($onSteps -or $onChooser -or $onAbout) {
        $Rows.Children.Clear()
        $HomePanel.Visibility = 'Collapsed'
        $Heading.Text = $script:Cat
        $HeaderSub.Text = $Pages[$script:Cat].Sub
        $HeaderIcon.Text = [string]$Pages[$script:Cat].Glyph
        if ($onChooser) { Show-AkariOptimizeChooser; return }
        if ($onAbout) { Show-AkariAbout; return }
        Enter-AkariFlow $script:Cat
        Show-AkariSteps
        return
    }
    $onHome = (-not $q -and $script:Cat -eq 'Home')
    $Rows.Children.Clear()
    if ($q) {
        $Heading.Text = 'Search'
        $HeaderSub.Text = "Results for `"$q`""
        $HeaderIcon.Text = [string][char]0xE721
    } else {
        $Heading.Text = $script:Cat
        $HeaderSub.Text = $Pages[$script:Cat].Sub
        $HeaderIcon.Text = [string]$Pages[$script:Cat].Glyph
    }
    # Optimize › Legacy: the legacy tweaks of this page (or every legacy match of the search), each row acting right away
    $list = @(if (-not $onHome) { Get-AkariLegacyList $script:Tweaks $script:Cat $q })
    $HomePanel.Visibility = if ($onHome) { 'Visible' } else { 'Collapsed' }
    # Home is a full-window landing page: no sidebar there (Win11Debloat-style); the Legacy pages and search have it
    Set-AkariPane (-not $onHome)
    foreach ($t in $list) {
        if (-not $script:RowCache.ContainsKey($t.Id)) { $script:RowCache[$t.Id] = New-Row $t }
        [void]$Rows.Children.Add($script:RowCache[$t.Id])
        Update-Row $t
    }
    if (-not $list.Count -and -not $onHome) {
        $msg = [Windows.Controls.TextBlock]::new()
        $msg.Text = if ($q) { 'No scripts match.' } else { 'Nothing here yet.' }
        $msg.Foreground = $window.FindResource('Mu')
        [void]$Rows.Children.Add($msg)
    }
}

# ---- running actions in a background runspace
function Set-Busy([bool]$b, [string]$label = '') {
    $script:Busy = $b; $Page.IsEnabled = -not $b; $StepFooter.IsEnabled = -not $b
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
        Show-Page
    }
})
$timer.Start()

function Confirm-Run([string]$text) {
    if (-not $text) { return $true }
    return ([Windows.MessageBox]::Show($text, 'Akari', 'YesNo', 'Warning') -eq 'Yes')
}

# ---- sidebar (Optimize › Legacy only): '← Optimize' back to the chooser, then the Legacy pages
foreach ($c in @('Optimize') + $AkariLegacyPages) {
    # icon in a 40 px column (it stays put when the pane collapses to 48 px), label after it
    $g = [Windows.Controls.Grid]::new()
    $c0 = [Windows.Controls.ColumnDefinition]::new(); $c0.Width = [Windows.GridLength]::new(40)
    [void]$g.ColumnDefinitions.Add($c0); [void]$g.ColumnDefinitions.Add([Windows.Controls.ColumnDefinition]::new())
    $ic = [Windows.Controls.TextBlock]::new()
    $ic.Text = if ($c -eq 'Optimize') { [string][char]0xE72B } else { [string]$Pages[$c].Glyph }
    $ic.FontFamily = $window.FindResource('Icons')
    $ic.FontSize = 16
    $ic.HorizontalAlignment = 'Center'; $ic.VerticalAlignment = 'Center'
    $lb = [Windows.Controls.TextBlock]::new()
    $lb.Text = $c; $lb.FontSize = 14; $lb.VerticalAlignment = 'Center'; $lb.Margin = [Windows.Thickness]::new(4, 0, 0, 1)
    [Windows.Controls.Grid]::SetColumn($lb, 1)
    [void]$g.Children.Add($ic); [void]$g.Children.Add($lb)
    $rb = [Windows.Controls.RadioButton]::new()
    $rb.Content = $g; $rb.Tag = $c; $rb.GroupName = 'nav'
    $rb.ToolTip = if ($c -eq 'Optimize') { 'Back to Optimize' } else { $c }
    $rb.Style = $window.FindResource('Nav')
    # a gap between the way back and the pages
    if ($c -eq 'Optimize') { $rb.Margin = [Windows.Thickness]::new(0, 0, 0, 12) }
    [void]$Nav.Children.Add($rb)
}
# pane toggle: full 232 px sidebar or the 48 px icon strip
$script:PaneOpen = $true
$PaneToggle.Add_Click({
    $script:PaneOpen = -not $script:PaneOpen
    Set-AkariPane $true
})

# opens page $Name ($From = the page left); Downloads remembers where it was opened from
function Open-AkariPage([string]$Name, [string]$From) {
    if ($Name -eq 'Downloads' -and $From -ne 'Downloads') { Set-AkariFlowExit $From }
    $script:Cat = $Name
    if ($Search.Text) { $Search.Text = '' }
    Show-Page
}
$Nav.AddHandler([Windows.Controls.Primitives.ToggleButton]::CheckedEvent, [Windows.RoutedEventHandler] {
    param($s, $ev)
    if ($script:NavSync) { return }
    Open-AkariPage ([string]$ev.OriginalSource.Tag) $script:Cat
})
$Search.Add_TextChanged({ Show-Page })

# any page, in the sidebar or not (Home, Install AkariOS, the Optimize chooser): the sidebar marks it when it lists it
function Select-AkariPage([string]$Name) {
    $script:NavSync = $true
    foreach ($rb in $Nav.Children) { $rb.IsChecked = ([string]$rb.Tag -eq $Name) }
    $script:NavSync = $false
    Open-AkariPage $Name $script:Cat
}

# ---- home tiles: Install AkariOS (One-click or Guided), Optimize (Manual mode), Downloads, Import / Export
$tile = New-AkariModeCard ([string][char]0xE756) 'Install AkariOS' 'Guided optimization for Windows. Recommended for a fresh install.' $true
$tile.Add_Click({ Select-AkariPage 'Install AkariOS' })
[void]$HomeTiles.Children.Add($tile)
$tile = New-AkariModeCard ([string][char]0xE713) 'Optimize' 'Manual, in-depth optimization for Windows. Recommended for power users.' $true
# the Legacy / Advanced chooser
$tile.Add_Click({ Select-AkariPage 'Optimize' })
[void]$HomeTiles.Children.Add($tile)
# Downloads: the Guided Install cards on their own
$tile = New-AkariModeCard ([string][char]0xE896) 'Downloads' 'Install apps, game launchers, runtimes and tools, or bring back Store apps the debloat removed.' $true
$tile.Add_Click({ Select-AkariPage 'Downloads' })
[void]$HomeTiles.Children.Add($tile)
$tile = New-AkariModeCard ([string][char]0xE72D) 'Import / Export settings' 'Save your choices to a file, or load them on another PC. Coming in a later version.' $false
[void]$HomeTiles.Children.Add($tile)
$last = $HomeTiles.Children.Count - 1
foreach ($i in 0..$last) { $HomeTiles.Children[$i].Margin = [Windows.Thickness]::new($(if ($i) { 8 } else { 0 }), 0, $(if ($i -lt $last) { 8 } else { 0 }), 0) }

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
