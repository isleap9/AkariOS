# About & Updates: the version and the update check (Core\Update.ps1); credits, links and license come next.
# Full window, Back goes Home. The check runs in the background on every launch: an update found while the user is
# still on Home asks right away ("Update now / Later"); either way the Home bar shows it until Akari closes.
# Dot-sourced by Akari.ps1 after UI\Rows.ps1.

$script:UpdateStatus = $null
$script:UpdateChecking = $false

$UpdateOpen.Add_Click({ Select-AkariPage 'About' })
# the status bar's "AkariOS <version>" opens About
$AppVersion.Add_Click({ Select-AkariPage 'About' })

function Show-AkariAbout {
    $StepDots.Children.Clear()
    Set-AkariStepHeader 'About' $Pages['About'].Sub
    $StepBack.Visibility = 'Visible'
    $StepNext.Visibility = 'Collapsed'
    $p = @{}
    $card = [Windows.Controls.Border]::new()
    $card.SetResourceReference([Windows.FrameworkElement]::StyleProperty, 'SettingCard')
    $sp = [Windows.Controls.StackPanel]::new()
    $p.Version = New-AkariText "AkariOS $AkariVersion" 20
    $p.Version.FontWeight = 'SemiBold'
    Set-AkariFont $p.Version 'Display'
    $p.Status = New-AkariText '' 13 'Mu'
    $p.Status.Margin = [Windows.Thickness]::new(0, 4, 0, 12)
    $bar = [Windows.Controls.StackPanel]::new()
    $bar.Orientation = 'Horizontal'
    $p.Update = [Windows.Controls.Button]::new()
    $p.Update.SetResourceReference([Windows.FrameworkElement]::StyleProperty, 'Accent')
    $p.Update.Content = 'Update now'
    $p.Update.Margin = [Windows.Thickness]::new(0, 0, 8, 0)
    $p.Update.Add_Click({ Start-AkariUpdateInstall })
    $p.Check = [Windows.Controls.Button]::new()
    $p.Check.SetResourceReference([Windows.FrameworkElement]::StyleProperty, 'Btn')
    $p.Check.Content = 'Check for updates'
    $p.Check.Margin = [Windows.Thickness]::new(0, 0, 8, 0)
    $p.Check.Add_Click({ Start-AkariUpdateCheck $true })
    $p.GitHub = [Windows.Controls.Button]::new()
    $p.GitHub.SetResourceReference([Windows.FrameworkElement]::StyleProperty, 'Btn')
    $p.GitHub.Content = 'Open on GitHub'
    $p.GitHub.Add_Click({
        $u = if ($script:UpdateStatus -and $script:UpdateStatus.Release.PageUrl) { $script:UpdateStatus.Release.PageUrl } else { "https://github.com/$AkariRepo/releases" }
        Start-Process $u
    })
    foreach ($b in $p.Update, $p.Check, $p.GitHub) { [void]$bar.Children.Add($b) }
    # the release notes, as plain text
    $p.NotesHead = New-AkariText "What's new" 14
    $p.NotesHead.FontWeight = 'SemiBold'
    Set-AkariFont $p.NotesHead 'Display'
    $p.NotesHead.Margin = [Windows.Thickness]::new(0, 16, 0, 6)
    $p.Notes = New-AkariText '' 13 'Mu'
    foreach ($x in $p.Version, $p.Status, $bar, $p.NotesHead, $p.Notes) { [void]$sp.Children.Add($x) }
    $card.Child = $sp
    $d = $script:AboutData
    # links: a button each (hidden until it has a URL), then the log folder (for whoever is helping)
    $links = New-AkariAboutCard 'Links'
    $p.Links = [Windows.Controls.WrapPanel]::new()
    foreach ($l in $d.Links) {
        $b = New-AkariAboutButton $l.Name $l.Url
        $b.Visibility = if ($l.Url) { 'Visible' } else { 'Collapsed' }
        [void]$p.Links.Children.Add($b)
    }
    $log = New-AkariAboutButton 'Open log folder' ''
    $log.Add_Click({ Open-AkariLogFolder })
    [void]$p.Links.Children.Add($log)
    [void]$links.Body.Children.Add($p.Links)
    # credits: the name (a link to the project), what it gave AkariOS
    $credits = New-AkariAboutCard 'Credits'
    $p.Credits = [Windows.Controls.StackPanel]::new()
    foreach ($c in $d.Credits) {
        $row = [Windows.Controls.Grid]::new()
        $row.Margin = [Windows.Thickness]::new(0, 0, 0, 6)
        foreach ($w in 220, -1) {
            $cd = [Windows.Controls.ColumnDefinition]::new()
            $cd.Width = if ($w -eq -1) { [Windows.GridLength]::new(1, 'Star') } else { [Windows.GridLength]::new($w) }
            [void]$row.ColumnDefinitions.Add($cd)
        }
        $n = New-AkariLink $c.Name $c.Url
        $n.FontWeight = 'SemiBold'; $n.VerticalAlignment = 'Center'
        $t = New-AkariText $c.Text 13 'Mu'
        $t.VerticalAlignment = 'Center'
        [Windows.Controls.Grid]::SetColumn($t, 1)
        foreach ($x in $n, $t) { [void]$row.Children.Add($x) }
        [void]$p.Credits.Children.Add($row)
    }
    [void]$credits.Body.Children.Add($p.Credits)
    $full = New-AkariAboutButton 'Full credits' $d.FullCredits
    $full.HorizontalAlignment = 'Left'
    $full.Margin = [Windows.Thickness]::new(0, 6, 0, 0)
    [void]$credits.Body.Children.Add($full)
    # license: one line, "View license" right after it
    $lic = New-AkariAboutCard 'License'
    $lp = [Windows.Controls.StackPanel]::new()
    $lp.Orientation = 'Horizontal'
    $p.License = New-AkariText $d.License.Text 13 'Mu'
    $p.License.VerticalAlignment = 'Center'
    $view = New-AkariAboutButton 'View license' $d.License.Url
    $view.Margin = [Windows.Thickness]::new(12, 0, 0, 0)
    [void]$lp.Children.Add($p.License); [void]$lp.Children.Add($view)
    [void]$lic.Body.Children.Add($lp)
    $script:AboutParts = $p
    Update-AkariAboutUpdate
    $StepBody.Children.Clear()
    $card.Margin = [Windows.Thickness]::new(0, 0, 0, 12)
    # one readable column on the left: a grid column that fills the page up to 800 px, so every card has the same width
    $p.Column = [Windows.Controls.Grid]::new()
    $cd = [Windows.Controls.ColumnDefinition]::new()
    $cd.Width = [Windows.GridLength]::new(1, 'Star')
    $cd.MaxWidth = 800
    [void]$p.Column.ColumnDefinitions.Add($cd)
    $stack = [Windows.Controls.StackPanel]::new()
    foreach ($x in $card, $links.Card, $credits.Card, $lic.Card) { [void]$stack.Children.Add($x) }
    [void]$p.Column.Children.Add($stack)
    [void]$StepBody.Children.Add($p.Column)
}

# the About page's data: links, credits, license (UI\About.psd1)
$script:AboutData = Import-PowerShellDataFile "$Root\UI\About.psd1"

# an About card with a title: @{ Card; Body }
function New-AkariAboutCard([string]$Title) {
    $c = [Windows.Controls.Border]::new()
    $c.SetResourceReference([Windows.FrameworkElement]::StyleProperty, 'SettingCard')
    $c.Margin = [Windows.Thickness]::new(0, 0, 0, 12)
    $sp = [Windows.Controls.StackPanel]::new()
    $h = New-AkariText $Title 20
    $h.FontWeight = 'SemiBold'
    Set-AkariFont $h 'Display'
    $h.Margin = [Windows.Thickness]::new(0, 0, 0, 10)
    [void]$sp.Children.Add($h)
    $c.Child = $sp
    @{ Card = $c; Body = $sp }
}

# a button that opens $Url in the browser (no Url: the caller adds its own click)
function New-AkariAboutButton([string]$Text, [string]$Url) {
    $b = [Windows.Controls.Button]::new()
    $b.SetResourceReference([Windows.FrameworkElement]::StyleProperty, 'Btn')
    $b.Content = $Text
    $b.Margin = [Windows.Thickness]::new(0, 0, 8, 0)
    if ($Url) { $b.Tag = $Url; $b.Add_Click({ param($s, $e) Start-Process ([string]$s.Tag) }) }
    $b
}

function Open-AkariLogFolder { $f = Split-Path $AkariLogFile; if (Test-Path $f) { Start-Process explorer.exe $f } }

# a title bar menu row: a Lucide icon (in the row's text colour) and a label; no $Click = greyed out, "coming in a
# later version"
function New-AkariMenuItem([string]$Header, [string]$Icon, [scriptblock]$Click) {
    $it = [Windows.Controls.MenuItem]::new()
    $it.Header = $Header
    $it.Icon = New-AkariIcon $Icon 16 'Inherit'
    if ($Click) { $it.Add_Click($Click) }
    else {
        $it.IsEnabled = $false
        $it.ToolTip = 'Coming in a later version'
        [Windows.Controls.ToolTipService]::SetShowOnDisabled($it, $true)
    }
    $it
}

# the title bar's options menu (after Win11Debloat's): settings files (M5), System Restore, the theme, then the About links,
# the log folder and About
# (links with no Url are left out, as on About)
$MainMenu = [Windows.Controls.ContextMenu]::new()
# 220 px wide plus the 12 px shadow margin on each side (MainWindow.xaml), so it can be right-aligned when it opens
$MainMenu.Width = 244
$MenuBtn.ContextMenu = $MainMenu
$items = [Collections.Generic.List[object]]::new()
$items.Add((New-AkariMenuItem 'Import settings' 'file-input' { Start-AkariImport }))
$items.Add((New-AkariMenuItem 'Export settings' 'file-output' { Start-AkariExport }))
$items.Add((New-AkariMenuItem 'System Restore' 'history' { Start-Process "$env:SystemRoot\System32\rstrui.exe" }))
# Theme: Follow Windows -> Dark -> Light -> ..., applied at once and kept in settings.json (Set-AkariTheme, UI\Shell.ps1)
$AkariThemeLabels = @{ System = 'Theme: Follow Windows'; Dark = 'Theme: Dark'; Light = 'Theme: Light' }
$items.Add((New-AkariMenuItem $AkariThemeLabels[$script:ThemeSetting] 'sun-moon' {
    param($s, $e)
    $next = $AkariThemes[([array]::IndexOf($AkariThemes, $script:ThemeSetting) + 1) % $AkariThemes.Count]
    Set-AkariTheme $next -Save
    $s.Header = $AkariThemeLabels[$next]
}))
$items.Add([Windows.Controls.Separator]::new())
$glyphs = @{ 'GitHub' = 'github'; 'Report a bug' = 'bug'; 'Discord' = 'message-circle' }
foreach ($l in @($script:AboutData.Links | Where-Object { $_.Url })) {
    $g = if ($glyphs[$l.Name]) { $glyphs[$l.Name] } else { 'external-link' }
    $it = New-AkariMenuItem $l.Name $g { param($s, $e) Start-Process ([string]$s.Tag) }
    $it.Tag = $l.Url
    $items.Add($it)
}
$items.Add((New-AkariMenuItem 'Logs' 'folder-open' { Open-AkariLogFolder }))
$items.Add((New-AkariMenuItem 'About' 'info' { Select-AkariPage 'About' }))
foreach ($it in $items) { [void]$MainMenu.Items.Add($it) }
# opens under the caption buttons, its right edge 4 px in from the window's
$MenuBtn.Add_Click({
    $caps = $MenuBtn.Parent
    $MainMenu.PlacementTarget = $caps
    $MainMenu.Placement = 'Bottom'
    $MainMenu.HorizontalOffset = $caps.ActualWidth - $MainMenu.Width + 12 - 4
    $MainMenu.VerticalOffset = -12 + 4
    $MainMenu.IsOpen = $true
})

# a text link that opens $Url in the browser (white, underlined on hover)
function New-AkariLink([string]$Text, [string]$Url) {
    $tb = New-AkariText '' 13
    $h = [Windows.Documents.Hyperlink]::new([Windows.Documents.Run]::new($Text))
    $h.NavigateUri = [Uri]$Url
    $h.ToolTip = $Url
    $h.SetResourceReference([Windows.Documents.TextElement]::ForegroundProperty, 'Tx')
    $h.TextDecorations = $null
    $h.Add_MouseEnter({ param($s, $e) $s.TextDecorations = [Windows.TextDecorations]::Underline })
    $h.Add_MouseLeave({ param($s, $e) $s.TextDecorations = $null })
    $h.Add_RequestNavigate({ param($s, $e) Start-Process $e.Uri.AbsoluteUri; $e.Handled = $true })
    [void]$tb.Inlines.Add($h)
    $tb
}

# the About page's update part, from the last check
function Update-AkariAboutUpdate {
    $p = $script:AboutParts
    if (-not $p) { return }
    $s = $script:UpdateStatus
    $p.Status.Text = if ($script:UpdateChecking) { 'Checking for updates' + [char]0x2026 } elseif ($s) { $s.Message } else { 'Not checked yet.' }
    $p.Check.IsEnabled = -not $script:UpdateChecking
    $p.Update.Visibility = if ($s -and $s.Kind -eq 'Available') { 'Visible' } else { 'Collapsed' }
    $notes = if ($s -and $s.Kind -in 'Available', 'Blocked', 'Latest' -and $s.Release.Notes) { ConvertTo-AkariNotesText $s.Release.Notes } else { '' }
    $p.Notes.Text = $notes
    $p.Notes.Visibility = if ($notes) { 'Visible' } else { 'Collapsed' }
    $p.NotesHead.Visibility = $p.Notes.Visibility
}

# reads the latest release in a background runspace; $Manual = the Check button (the launch check only logs failures)
function Start-AkariUpdateCheck([bool]$Manual) {
    if ($script:UpdateChecking) { return }
    $script:UpdateChecking = $true
    Update-AkariAboutUpdate
    $rs = [runspacefactory]::CreateRunspace(); $rs.Open()
    $ps = [powershell]::Create(); $ps.Runspace = $rs
    $upd = "$Root\Core\Update.ps1" -replace "'", "''"
    [void]$ps.AddScript(". '$upd'; Get-AkariLatestRelease")
    $t = [Windows.Threading.DispatcherTimer]::new()
    $t.Interval = [TimeSpan]::FromMilliseconds(300)
    $t.Tag = @{ Ps = $ps; Rs = $rs; Handle = $ps.BeginInvoke(); Manual = $Manual }
    $t.Add_Tick({
        param($s, $a)
        $j = $s.Tag
        if (-not $j.Handle.IsCompleted) { return }
        $s.Stop()
        $r = $null
        try { $r = @($j.Ps.EndInvoke($j.Handle))[0] } catch { }
        $j.Ps.Dispose(); $j.Rs.Dispose()
        if ($r -isnot [hashtable]) { $r = @{ Ok = $false; Message = "Couldn't check for updates." } }
        Complete-AkariUpdateCheck $r $j.Manual
    })
    $t.Start()
}

# the check is done: remember it, show it on Home and About, and on launch ask while the user is still on Home
function Complete-AkariUpdateCheck($Release, [bool]$Manual) {
    $script:UpdateChecking = $false
    $s = Get-AkariUpdateStatus $AkariVersion $Release $AkariInstallDir ([bool]($script:Busy -or $script:Job))
    $script:UpdateStatus = $s
    Add-Log "Update check: $($s.Message)"
    $found = $s.Kind -in 'Available', 'Blocked'
    $UpdateText.Text = $s.Message
    $UpdateBar.Visibility = if ($found) { 'Visible' } else { 'Collapsed' }
    if ($script:Cat -eq 'About') { Update-AkariAboutUpdate }
    if (-not $Manual -and $s.Kind -eq 'Available' -and $script:Cat -eq 'Home' -and -not $Search.Text) { Show-AkariUpdatePrompt $s }
}

# the launch prompt: the notes (shortened) and Update now / Later
function Show-AkariUpdatePrompt($Status) {
    $notes = ConvertTo-AkariNotesText $Status.Release.Notes
    if ($notes.Length -gt 600) { $notes = $notes.Substring(0, 600).TrimEnd() + [char]0x2026 }
    $q = "$($Status.Message)`n`n" + $(if ($notes) { "What's new:`n$notes`n`n" } else { '' }) +
         "Update now? Akari closes, installs it and opens again. Your presets and settings are kept."
    if (Confirm-AkariDialog $q 'Update now' 'Later' 'Info' 'AkariOS update') { Start-AkariUpdateInstall }
}

# downloads and checks the release in the background; when it is ready the helper is waiting and Akari closes
function Start-AkariUpdateInstall {
    if ($script:Busy -or -not $script:UpdateStatus) { return }
    # checked again: something may have started since the check
    $s = Get-AkariUpdateStatus $AkariVersion $script:UpdateStatus.Release $AkariInstallDir ([bool]$script:Job)
    if ($s.Kind -ne 'Available') { Show-AkariMessage $s.Message 'Info' 'AkariOS update'; return }
    Set-Busy $true "Downloading AkariOS $($s.Release.Version)$([char]0x2026)"
    Add-Log "Update: downloading AkariOS $($s.Release.Version)"
    $rs = [runspacefactory]::CreateRunspace(); $rs.Open()
    $rs.SessionStateProxy.SetVariable('AkariUpdateRelease', $s.Release)
    $rs.SessionStateProxy.SetVariable('AkariUpdateTarget', $AkariInstallDir)
    $ps = [powershell]::Create(); $ps.Runspace = $rs
    $upd = "$Root\Core\Update.ps1" -replace "'", "''"
    [void]$ps.AddScript(". '$upd'; Install-AkariUpdate `$AkariUpdateRelease `$AkariUpdateTarget")
    $t = [Windows.Threading.DispatcherTimer]::new()
    $t.Interval = [TimeSpan]::FromMilliseconds(300)
    $t.Tag = @{ Ps = $ps; Rs = $rs; Handle = $ps.BeginInvoke() }
    $t.Add_Tick({
        param($sender, $a)
        $j = $sender.Tag
        if (-not $j.Handle.IsCompleted) { return }
        $sender.Stop()
        $r = $null
        try { $r = @($j.Ps.EndInvoke($j.Handle))[0] } catch { $r = @{ Ok = $false; Message = $_.Exception.Message } }
        $j.Ps.Dispose(); $j.Rs.Dispose()
        if ($r -isnot [hashtable]) { $r = @{ Ok = $false; Message = 'The update could not be prepared.' } }
        Add-Log "Update: $($r.Message)"
        if ($r.Ok) { $window.Close(); return }
        Set-Busy $false
        Show-AkariMessage $r.Message 'Warning' 'AkariOS update'
    })
    $t.Start()
}

# every launch: check in the background once the window is up
$window.Add_Loaded({ Start-AkariUpdateCheck $false })
