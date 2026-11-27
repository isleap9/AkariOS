# Per-game settings (Optimize > Optimize > Gaming, under its Tweaks; plan docs/plans/2026-11-26-new-features.md, X5):
# the games Core\Games.ps1 finds (Steam, Epic, GOG, added by hand), each with three switches that act right away:
# High-performance GPU, Fullscreen optimizations off, High CPU priority. "Add a game..." picks an exe (games.json);
# an added one has Remove from list. Read once in the background (Refresh reads them again); changes go through the
# Catalogue's queue with the session's restore point first. Dot-sourced by Akari.ps1 after UI\StartupPage.ps1; the
# functions before "the list" are pure.

# a switch's label and tooltip
$AkariGameSwitches = [ordered]@{
    Gpu      = @('High-performance GPU', 'Windows runs it on the high-performance graphics card (Settings > Display > Graphics). Off: Windows decides.')
    Fso      = @('Fullscreen optimizations off', 'Exclusive fullscreen as the game asks, without Windows'' fullscreen optimizations (Compatibility tab). Off: Windows'' default.')
    Priority = @('High CPU priority', 'The game starts at High CPU priority. It applies to every program with this exe''s name. Off: Normal.')
}

# (pure) the games the search leaves (name, exe or source), as listed
function Get-AkariGameView($Games, [string]$Query) {
    $q = "$Query".Trim()
    @($Games | Where-Object { -not $q -or "$($_.Name) $($_.Exe) $($_.Source)".IndexOf($q, [StringComparison]::OrdinalIgnoreCase) -ge 0 })
}

# (pure) the count line
function Get-AkariGameCountText($All, $View) {
    $n = @($All).Count; $v = @($View).Count
    $games = if ($n -eq 1) { 'game' } else { 'games' }
    if ($v -eq $n) { "$n $games found" } else { "$v of $n $games" }
}

# ---- the list

$script:GameList = $null
$script:GameReadError = ''
$script:GameReading = $false
$script:GameRows = @{}       # key -> @{ Game; Card; Switches = @{ setting -> toggle }; StateText; Busy; Error }
$script:GameBar = $null

function Select-AkariGameFile {
    Add-Type -AssemblyName System.Windows.Forms
    $d = [Windows.Forms.OpenFileDialog]::new()
    $d.Filter = 'Programs (*.exe)|*.exe'
    $d.Title = 'Pick the game''s program'
    if ($d.ShowDialog() -eq 'OK') { $d.FileName } else { $null }
}

function Get-AkariGameBar {
    if ($script:GameBar) { return $script:GameBar }
    $bar = [Windows.Controls.DockPanel]::new()
    $bar.Margin = [Windows.Thickness]::new(0, 18, 0, 12)
    $refresh = [Windows.Controls.Button]::new()
    $refresh.SetResourceReference([Windows.FrameworkElement]::StyleProperty, 'Btn')
    $refresh.Content = 'Refresh'
    $refresh.ToolTip = 'Look for games again'
    $refresh.Add_Click({ if (-not $script:GameReading) { $script:GameList = $null; Show-Page } })
    [Windows.Controls.DockPanel]::SetDock($refresh, 'Right')
    [void]$bar.Children.Add($refresh)
    $add = [Windows.Controls.Button]::new()
    $add.SetResourceReference([Windows.FrameworkElement]::StyleProperty, 'Btn')
    $add.Content = 'Add a game' + [char]0x2026
    $add.ToolTip = 'A game the list misses: pick its program (.exe)'
    $add.Margin = [Windows.Thickness]::new(0, 0, 8, 0)
    $add.Add_Click({ Add-AkariOwnGame })
    [Windows.Controls.DockPanel]::SetDock($add, 'Right')
    [void]$bar.Children.Add($add)
    $count = New-AkariText '' 13 'Mu'
    $count.VerticalAlignment = 'Center'
    [void]$bar.Children.Add($count)
    $script:GameBar = @{ Bar = (New-AkariGlassBar $bar); Count = $count }
    $script:GameBar
}

function Show-AkariGameList([string]$Query) {
    $b = Get-AkariGameBar
    if ($b.Bar.Parent) { $b.Bar.Parent.Children.Remove($b.Bar) }; [void]$Rows.Children.Add($b.Bar)
    if ($null -eq $script:GameList) {
        $b.Count.Text = 'Looking for games' + [char]0x2026
        Start-AkariGameRead
        return
    }
    if ($script:GameReadError) {
        $b.Count.Text = ''
        [void]$Rows.Children.Add((New-AkariText "Couldn't look for games: $($script:GameReadError)" 13 'Bad'))
        return
    }
    $view = @(Get-AkariGameView $script:GameList $Query)
    $b.Count.Text = Get-AkariGameCountText $script:GameList $view
    foreach ($g in $view) {
        $e = $script:GameRows[$g.Key]
        if (-not $e) { $e = New-AkariGameRow $g; $script:GameRows[$g.Key] = $e }
        elseif (-not $e.Busy) { $e.Game = $g }
        if ($e.Card.Parent) { $e.Card.Parent.Children.Remove($e.Card) }; [void]$Rows.Children.Add($e.Card)
        Set-AkariGameRow $e
    }
    if (-not $view.Count) { [void]$Rows.Children.Add((New-AkariText $(if (@($script:GameList).Count) { 'No game matches.' } else { 'No Steam, Epic or GOG games found. Add a game to set it up.' }) 13 'Mu')) }
}

function Start-AkariGameRead {
    if ($script:GameReading) { return }
    $script:GameReading = $true
    $shared = [hashtable]::Synchronized(@{ Path = $AkariGamesPath })
    $job = Start-AkariJob 'if ($AkariShared.Path) { $AkariGamesPath = $AkariShared.Path }; try { $AkariShared.List = @(Get-AkariGames) } catch { $AkariShared.Error = $_.Exception.Message }' $script:Queue "$Root\Core" $shared
    $tm = [Windows.Threading.DispatcherTimer]::new()
    $tm.Interval = [TimeSpan]::FromMilliseconds(200)
    $tm.Tag = $job
    $tm.Add_Tick({
        param($s, $a)
        $j = $s.Tag
        if (-not $j.Handle.IsCompleted) { return }
        $s.Stop()
        try { [void]$j.Ps.EndInvoke($j.Handle) } catch { }
        $j.Ps.Dispose(); $j.Rs.Dispose()
        $script:GameReading = $false
        $script:GameReadError = [string]$j.Shared.Error
        $script:GameList = if ($j.Shared.List) { @($j.Shared.List) } else { @() }
        if ($AkariCatalogueLists[$script:Cat].Show -eq 'Show-AkariGameList') { Show-Page }
    })
    $tm.Start()
}

# "Add a game...": an exe picked, kept in games.json, the list read again
function Add-AkariOwnGame {
    $exe = Select-AkariGameFile
    if (-not $exe) { return }
    $path = (Get-AkariGameSources).Own
    $own = @(Get-AkariOwnGames $path)
    if (-not @($own | Where-Object { $_.Exe -eq $exe }).Count) {
        $own += @{ Name = [IO.Path]::GetFileNameWithoutExtension($exe); Exe = $exe }
        Save-AkariOwnGames $path $own
        Add-Log "Game added: $exe"
    }
    $script:GameList = $null
    Show-Page
}

function Remove-AkariOwnGame([string]$Key) {
    $path = (Get-AkariGameSources).Own
    Save-AkariOwnGames $path @(Get-AkariOwnGames $path | Where-Object { $_.Exe.ToLowerInvariant() -ne $Key })
    $script:GameRows.Remove($Key)
    $script:GameList = $null
    Show-Page
}

# ---- a row: the name, the source and the exe, the three switches

function New-AkariGameRow($g) {
    $e = @{ Game = $g; Busy = ''; Error = ''; Switches = @{} }
    $card = [Windows.Controls.Border]::new()
    $card.SetResourceReference([Windows.FrameworkElement]::StyleProperty, 'SettingCard')
    $card.Padding = [Windows.Thickness]::new(18, 10, 18, 10)
    $card.MinHeight = 0
    $card.Margin = [Windows.Thickness]::new(0, 0, 0, 4)
    $st = [Windows.Controls.StackPanel]::new()
    $head = [Windows.Controls.DockPanel]::new()
    if ($g.Source -eq 'Added') {
        $rm = [Windows.Controls.Button]::new()
        $rm.SetResourceReference([Windows.FrameworkElement]::StyleProperty, 'Btn')
        $rm.Content = 'Remove from list'
        $rm.Tag = $g.Key
        $rm.Add_Click({ param($s, $a) Remove-AkariOwnGame ([string]$s.Tag) })
        [Windows.Controls.DockPanel]::SetDock($rm, 'Right')
        [void]$head.Children.Add($rm)
    }
    $name = New-AkariText $g.Name 14
    $name.FontWeight = 'SemiBold'
    [void]$head.Children.Add($name)
    [void]$st.Children.Add($head)
    $meta = New-AkariText "$($g.Source)  $($g.Exe)" 12 'Ter'
    Set-AkariFont $meta 'Mono'
    $meta.TextTrimming = 'CharacterEllipsis'
    $meta.ToolTip = $g.Exe
    $meta.Margin = [Windows.Thickness]::new(0, 3, 0, 6)
    [void]$st.Children.Add($meta)
    $wrap = [Windows.Controls.WrapPanel]::new()
    foreach ($k in $AkariGameSwitches.Keys) {
        $sp = [Windows.Controls.StackPanel]::new(); $sp.Orientation = 'Horizontal'; $sp.Margin = [Windows.Thickness]::new(0, 0, 24, 4)
        $sw = [Windows.Controls.Primitives.ToggleButton]::new()
        $sw.SetResourceReference([Windows.FrameworkElement]::StyleProperty, 'CatSwitch')
        $sw.Tag = "$($g.Key)|$k"
        $sw.ToolTip = $AkariGameSwitches[$k][1]
        $sw.Add_Click({ param($s, $a) $p = ([string]$s.Tag).Split('|'); Invoke-AkariGameChange $p[0] $p[1] ($s.IsChecked -eq $true) })
        [void]$sp.Children.Add($sw)
        $l = New-AkariText $AkariGameSwitches[$k][0] 13
        $l.VerticalAlignment = 'Center'; $l.Margin = [Windows.Thickness]::new(8, 0, 0, 0)
        [void]$sp.Children.Add($l)
        [void]$wrap.Children.Add($sp)
        $e.Switches[$k] = $sw
    }
    [void]$st.Children.Add($wrap)
    $e.StateText = New-AkariText '' 12 'Ter'
    [void]$st.Children.Add($e.StateText)
    $card.Child = $st
    $e.Card = $card
    $e
}

function Set-AkariGameRow($e) {
    foreach ($k in @($e.Switches.Keys)) { $e.Switches[$k].IsChecked = [bool]$e.Game.$k; $e.Switches[$k].IsEnabled = -not $e.Busy }
    $e.StateText.Text = if ($e.Error) { "Failed: $($e.Error)" } elseif ($e.Busy -eq 'Waiting') { 'Waiting' + [char]0x2026 } elseif ($e.Busy) { 'Applying' + [char]0x2026 } else { '' }
    $e.StateText.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, $(if ($e.Error) { 'Bad' } else { 'Ter' }))
    $e.StateText.Visibility = if ($e.StateText.Text) { 'Visible' } else { 'Collapsed' }
}

# ---- changes: through the Catalogue's queue, one at a time

function Invoke-AkariGameChange([string]$Key, [string]$Setting, [bool]$On) {
    $e = $script:GameRows[$Key]
    if (-not $e -or $e.Busy) { return }
    $e.Error = ''
    $e.Busy = 'Waiting'
    Set-AkariGameRow $e
    $e.Switches[$Setting].IsChecked = $On
    $script:CatQueue.Add(@{ Kind = 'Game'; Id = $Key; Setting = $Setting; On = $On })
    Start-AkariCatalogueNext
}

function Start-AkariGameJob($It) {
    $e = $script:GameRows[$It.Id]
    $e.Busy = 'Running'
    Set-AkariGameRow $e
    $e.Switches[$It.Setting].IsChecked = $It.On
    $code = @'
try { Set-AkariGameSetting $AkariShared.Exe $AkariShared.Setting $AkariShared.On }
catch { $AkariShared.Error = $_.Exception.Message; Write-Log "Failed: $($_.Exception.Message)" }
try { $AkariShared.Now = Get-AkariGameSettings $AkariShared.Exe } catch { }
'@
    $code = Add-AkariRestoreFirst $code ''
    $label = "$($e.Game.Name): $($AkariGameSwitches[$It.Setting][0]) $(if ($It.On) { 'on' } else { 'off' })"
    Set-Busy $true $label $false
    Add-Log $label
    $shared = [hashtable]::Synchronized(@{ Id = $It.Id; Exe = $e.Game.Exe; Setting = $It.Setting; On = [bool]$It.On })
    $script:Job = Start-AkariJob $code $script:Queue "$Root\Core" $shared
    $script:Job.Label = $label
    $script:Job.Kind = 'CatalogueGame'
}

function Complete-AkariGameJob($Shared) {
    $e = $script:GameRows[$Shared.Id]
    if (-not $e) { return }
    $e.Busy = ''
    $e.Error = [string]$Shared.Error
    if ($Shared.Now) { foreach ($k in $AkariGameSettings) { $e.Game.$k = [bool]$Shared.Now[$k] } }
    Set-AkariGameRow $e
}
