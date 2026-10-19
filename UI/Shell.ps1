# Shell: window chrome, Mica, caption buttons, sidebar, search, page switching, status bar,
# the background job and the timer that drains the log queue. Dot-sourced by Akari.ps1 after UI\Home.ps1.

# ---- window
$window = [Windows.Markup.XamlReader]::Parse((Get-Content "$Root\UI\MainWindow.xaml" -Raw))
# WinUI-style controls for the Manual steps (switch, combobox, setting card, ...)
$window.Resources.MergedDictionaries.Add([Windows.Markup.XamlReader]::Parse((Get-Content "$Root\UI\Controls.xaml" -Raw)))
foreach ($n in 'Nav', 'Search', 'Heading', 'Rows', 'Page', 'Log', 'Logo', 'HomePanel', 'HostName', 'HostSub', 'Cards', 'CopySpecs',
               'Shell', 'Body', 'PaneCol', 'PaneToggle', 'HeaderIcon', 'HeaderSub', 'StatusDot', 'StatusRing', 'StatusText', 'StatusBar',
               'CapMin', 'CapMax', 'CapMaxGlyph', 'CapClose', 'StepsPanel', 'StepDots', 'StepBody', 'StepFooter', 'StepBack', 'StepNext') { Set-Variable $n $window.FindName($n) }
Initialize-AkariSteps

# sidebar pages: icon glyph (Segoe Fluent Icons) and the subtitle under the page title
$Pages = [ordered]@{
    Home       = @{ Glyph = [char]0xE80F; Sub = 'Your PC at a glance' }
    # temporary entry point until M2b puts Manual on the Home page
    Manual     = @{ Glyph = [char]0xE8FD; Sub = 'Choose your changes, review them, then apply them in one go' }
    Check      = @{ Glyph = [char]0xE9D9; Sub = 'Check your BIOS, storage, RAM and GPU, and stress test them' }
    Refresh    = @{ Glyph = [char]0xE72C; Sub = 'Reinstall or reset Windows, and get a fresh install ready' }
    Setup      = @{ Glyph = [char]0xE90F; Sub = 'First steps on a new install: activation, startup apps, updates' }
    Installers = @{ Glyph = [char]0xE896; Sub = 'Download and install the apps and launchers you need' }
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

function Add-Log([string]$m) {
    $Log.AppendText(("[{0}] {1}`r`n" -f (Get-Date -Format 'HH:mm:ss'), $m))
    $Log.ScrollToEnd()
}

function Show-Page {
    $q = $Search.Text.Trim()
    # Manual steps: the header search filters the Tweaks step instead of searching the old pages
    $onSteps = ($script:Cat -eq 'Manual')
    $StepsPanel.Visibility = if ($onSteps) { 'Visible' } else { 'Collapsed' }
    $StepFooter.Visibility = $StepsPanel.Visibility
    if ($onSteps) {
        $Rows.Children.Clear()
        $HomePanel.Visibility = 'Collapsed'
        $Heading.Text = 'Manual'
        $HeaderSub.Text = $Pages['Manual'].Sub
        $HeaderIcon.Text = [string]$Pages['Manual'].Glyph
        Show-AkariSteps
        return
    }
    $onHome = (-not $q -and $script:Cat -eq 'Home')
    $Rows.Children.Clear()
    if ($q) {
        $Heading.Text = 'Search'
        $HeaderSub.Text = "Results for `"$q`""
        $HeaderIcon.Text = [string][char]0xE721
        $list = @($script:Tweaks | Where-Object { $_.Legacy -and $_.Kind -ne 'Toggle' -and "$($_.Name) $($_.Description)" -like "*$q*" })
    } else {
        $Heading.Text = $script:Cat
        $HeaderSub.Text = $Pages[$script:Cat].Sub
        $HeaderIcon.Text = [string]$Pages[$script:Cat].Glyph
        # old pages: legacy Actions and Groups only; Toggles and one-file tweaks are in the Manual steps
        $list = @($script:Tweaks | Where-Object { $_.Legacy -and $_.Kind -ne 'Toggle' -and $_.Section -eq $script:Cat })
    }
    $HomePanel.Visibility = if ($onHome) { 'Visible' } else { 'Collapsed' }
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
    # render the last values (or loading) first, then read fresh specs in the background
    if ($onHome) { Update-Home; Start-SpecRead }
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
    # copy specs label: back to its normal text once the two second flash has passed
    if ($script:CopiedUntil -and [DateTime]::UtcNow -ge $script:CopiedUntil) { $CopySpecs.Content = 'Copy specs'; $script:CopiedUntil = $null }
    # watchdog feedback: log once when a read has been running longer than 5 seconds
    $sj = $script:SpecJob
    if ($sj -and -not $sj.Handle.IsCompleted -and -not $sj.LoggedSlow -and $sj.StartTime -and ([DateTime]::UtcNow - $sj.StartTime).TotalSeconds -gt 5) {
        $sj.LoggedSlow = $true
        Add-Log 'Specs: Reading (taking longer than usual)...'
    }
    # home spec read finished: store the composite and redraw only the cards
    $sj = $script:SpecJob
    # watchdog: a read past its deadline is abandoned so home never stays dimmed
    $late = ($sj -and -not $sj.Handle.IsCompleted -and $sj.Deadline -and [DateTime]::UtcNow -ge $sj.Deadline)
    if ($sj -and ($sj.Handle.IsCompleted -or $late)) {
        $had = ($null -ne $script:SpecData)
        $ok = $false
        $msg = $null
        if ($late) {
            $msg = "timed out after $($script:SpecTimeoutSec) seconds"
            # ask the hung pipeline to stop without waiting; it is disposed once it has ended
            try { [void]$sj.Ps.BeginStop($null, $null) } catch { }
            $script:SpecStale.Add($sj)
        } else {
            try {
                [void]$sj.Ps.EndInvoke($sj.Handle)
                $result = $sj.ResultCollection
                if ($null -ne $result -and $result.Count -gt 0) {
                    $last = $result[$result.Count - 1]
                    if ($last -is [hashtable] -and $last.ContainsKey('Specs')) { $script:SpecData = $last; $ok = $true }
                    else { $msg = [string]$last }
                } else { $msg = 'no result returned' }
            } catch { $msg = $_.Exception.Message }
            foreach ($err in $sj.Ps.Streams.Error) { Add-Log "Error: $($err.ToString())" }
            $sj.Ps.Dispose(); $sj.Rs.Dispose()
        }
        $script:SpecJob = $null
        if (-not $ok) {
            if (-not $msg) { $msg = 'no result returned' }
            if (-not $had) { $script:SpecData = @{ Specs = New-FailedSpecs; Host = @{ Manufacturer = 'Not available'; Model = 'Not available' } } }
            $tail = if ($had) { ' Showing last known values.' } else { ' Switch to another page and back to Home to try again.' }
            Add-Log "Specs: Read failed ($msg).$tail"
        }
        Update-Home
    }
    # abandoned spec reads: dispose each one once its pipeline has really ended
    for ($zi = $script:SpecStale.Count - 1; $zi -ge 0; $zi--) {
        $z = $script:SpecStale[$zi]
        if ($z.Handle.IsCompleted) {
            try { $z.Ps.Dispose(); $z.Rs.Dispose() } catch { }
            $script:SpecStale.RemoveAt($zi)
        }
    }
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
        # a home read was requested while the tweak ran: start it now (only on the Home page)
        if ($script:SpecPending -and $script:Cat -eq 'Home') { Start-SpecRead }
    }
})
$timer.Start()

function Confirm-Run([string]$text) {
    if (-not $text) { return $true }
    return ([Windows.MessageBox]::Show($text, 'Akari', 'YesNo', 'Warning') -eq 'Yes')
}

# ---- sidebar
foreach ($c in $Pages.Keys) {
    # icon in a 40 px column (it stays put when the pane collapses to 48 px), label after it
    $g = [Windows.Controls.Grid]::new()
    $c0 = [Windows.Controls.ColumnDefinition]::new(); $c0.Width = [Windows.GridLength]::new(40)
    [void]$g.ColumnDefinitions.Add($c0); [void]$g.ColumnDefinitions.Add([Windows.Controls.ColumnDefinition]::new())
    $ic = [Windows.Controls.TextBlock]::new()
    $ic.Text = [string]$Pages[$c].Glyph
    $ic.FontFamily = $window.FindResource('Icons')
    $ic.FontSize = 16
    $ic.HorizontalAlignment = 'Center'; $ic.VerticalAlignment = 'Center'
    $lb = [Windows.Controls.TextBlock]::new()
    $lb.Text = $c; $lb.FontSize = 14; $lb.VerticalAlignment = 'Center'; $lb.Margin = [Windows.Thickness]::new(4, 0, 0, 1)
    [Windows.Controls.Grid]::SetColumn($lb, 1)
    [void]$g.Children.Add($ic); [void]$g.Children.Add($lb)
    $rb = [Windows.Controls.RadioButton]::new()
    $rb.Content = $g; $rb.Tag = $c; $rb.GroupName = 'nav'; $rb.ToolTip = $c
    $rb.Style = $window.FindResource('Nav')
    [void]$Nav.Children.Add($rb)
    if ($c -eq 'Manual') {
        # section heading under home (not a nav item), as NavigationViewItemHeader
        $hd = [Windows.Controls.TextBlock]::new()
        $hd.Text = 'Scripts'
        $hd.FontSize = 14; $hd.FontWeight = [Windows.FontWeights]::SemiBold
        $hd.Margin = [Windows.Thickness]::new(16, 14, 0, 6)
        $hd.IsHitTestVisible = $false
        $script:NavHeader = $hd
        [void]$Nav.Children.Add($hd)
    }
}
# pane toggle: full 232 px sidebar or the 48 px icon strip
$PaneToggle.Add_Click({
    $open = ($PaneCol.Width.Value -gt 48)
    $PaneCol.Width = [Windows.GridLength]::new($(if ($open) { 48 } else { 232 }))
    $script:NavHeader.Visibility = if ($open) { 'Hidden' } else { 'Visible' }
})
$Nav.AddHandler([Windows.Controls.Primitives.ToggleButton]::CheckedEvent, [Windows.RoutedEventHandler] {
    param($s, $ev)
    $script:Cat = [string]$ev.OriginalSource.Tag
    if ($Search.Text) { $Search.Text = '' }
    Show-Page
})
$Search.Add_TextChanged({ Show-Page })
# copy specs button on the home header
$CopySpecs.Add_Click({ Copy-Specs })

# ---- go
$window.Add_Loaded({
    ($Nav.Children | Where-Object { $_.Tag -eq $script:Cat } | Select-Object -First 1).IsChecked = $true
    foreach ($p in $loaded.Problems) { Add-Log "$($p.Level): $($p.File): $($p.Message)" }
    Add-Log 'Ready.'
    $script:Busy = $false
})
# errors inside button handlers: show them in the log drawer (and akari.log) instead of losing them
$window.Dispatcher.Add_UnhandledException({
    param($s, $ev)
    $ev.Handled = $true
    Write-ErrLog "UI error: $($ev.Exception.Message)"
    Add-Log "Error: $($ev.Exception.Message)"
    Set-Busy $false
})
$window.Add_Closing({ $timer.Stop() })
