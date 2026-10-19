# Rows: Manual mode, the legacy Ultimate row list. Optimize / Default / Run buttons act right away, one Tweak at a time.
# Dot-sourced by Akari.ps1 after UI\Shell.ps1.

# ---- rows
function New-Row($t) {
    $e = { param($s) [Security.SecurityElement]::Escape([string]$s) }
    $riskKey = @{ Safe = 'Mu'; Caution = 'Warn'; Advanced = 'Bad' }[$t.Risk]
    $id = $t.Id
    if ($t.Kind -eq 'Action' -or $t.Kind -eq 'Console') {
        $btns = "<Button Tag=`"$id|Run`" Content=`"$(& $e $t.Button)`" Style=`"{DynamicResource Btn}`"/>"
    } elseif ($t.Kind -eq 'Group') {
        $main = if ($t.Apply) { "<Button Tag=`"$id|Apply`" Content=`"$(& $e $t.Button)`" Style=`"{DynamicResource Btn}`"/>" } else { '' }
        $btns = "$main<Button x:Name=`"Exp`" Tag=`"$id|Expand`" Content=`"Options`" Style=`"{DynamicResource Btn}`"/>"
    } else {
        $defOff = if ($t.Revert -or $t.Registry) { '' } else { ' IsEnabled="False" ToolTip="No safe revert for this script"' }
        $btns = "<Button x:Name=`"Opt`" Tag=`"$id|Apply`" Content=`"Optimize`" Style=`"{DynamicResource Btn}`"/><Button x:Name=`"Def`" Tag=`"$id|Revert`" Content=`"Default`" Style=`"{DynamicResource Btn}`"$defOff/>"
        if ($t.Check) { $btns += "<Button Tag=`"$id|Check`" Content=`"Check`" Style=`"{DynamicResource Btn}`"/>" }
    }
    $sub = ''
    if ($t.Kind -eq 'Group') {
        $i = 0
        foreach ($a in $t.Actions) {
            $sub += @"
<Grid Margin="0,0,0,8"><Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
<StackPanel VerticalAlignment="Center"><TextBlock Text="$(& $e $a.Name)"/><TextBlock Text="$(& $e $a.Description)" Foreground="{DynamicResource Mu}" FontSize="12.5" TextWrapping="Wrap"/></StackPanel>
<Button Grid.Column="1" Tag="$id|Sub|$i" Content="$(& $e $a.Button)" Style="{DynamicResource Btn}"/></Grid>
"@
            $i++
        }
        $sub = "<StackPanel x:Name=`"Sub`" Visibility=`"Collapsed`" Margin=`"22,12,0,0`"><Border BorderBrush=`"{DynamicResource Bd}`" BorderThickness=`"0,1,0,0`" Margin=`"0,0,0,10`"/>$sub</StackPanel>"
    }
    $dotVis = if ($t.Kind -in 'Toggle', 'Choice') { 'Visible' } else { 'Hidden' }
    $xaml = @"
<Border xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Background="{DynamicResource S1}" BorderBrush="{DynamicResource Bd}" BorderThickness="1" CornerRadius="8" Padding="16,12" Margin="0,0,0,6">
  <StackPanel>
  <Grid>
    <Grid.ColumnDefinitions><ColumnDefinition Width="22"/><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
    <Ellipse x:Name="Dot" Visibility="$dotVis" Width="9" Height="9" Stroke="{DynamicResource Mu}" StrokeThickness="1.5" HorizontalAlignment="Left" VerticalAlignment="Center"/>
    <StackPanel Grid.Column="1" VerticalAlignment="Center">
      <TextBlock Text="$(& $e $t.Name)" FontWeight="Medium"/>
      <TextBlock Text="$(& $e $t.Description)" Foreground="{DynamicResource Mu}" FontSize="12.5" TextWrapping="Wrap"/>
    </StackPanel>
    <Border Grid.Column="2" BorderThickness="1" CornerRadius="3" Padding="7,1" Margin="12,0" VerticalAlignment="Center"
            BorderBrush="{DynamicResource $riskKey}"><TextBlock Text="$($t.Risk)" FontSize="12" Foreground="{DynamicResource $riskKey}"/></Border>
    <StackPanel Grid.Column="3" Orientation="Horizontal" VerticalAlignment="Center">$btns</StackPanel>
  </Grid>
  $sub
  </StackPanel>
</Border>
"@
    [Windows.Markup.XamlReader]::Parse($xaml)
}

function Update-Row($t) {
    if ($t.Kind -notin 'Toggle', 'Choice') { return }
    $row = $script:RowCache[$t.Id]
    $s = Get-AkariState $t
    $dot = $row.FindName('Dot')
    # filled = Optimized, empty = Default, dimmed = Custom or Unknown
    $dot.Fill = if ($s -eq 'Optimized') { $window.FindResource('Inv') } else { [Windows.Media.Brushes]::Transparent }
    $dot.Opacity = if ($s -in 'Optimized', 'Default') { 1 } else { 0.35 }
    $row.FindName('Opt').Style = $window.FindResource($(if ($s -eq 'Optimized') { 'BtnP' } else { 'Btn' }))
    $row.FindName('Def').Style = $window.FindResource('Btn')
}

# ---- row buttons (one handler for every Optimize / Default button)
$Rows.AddHandler([Windows.Controls.Primitives.ButtonBase]::ClickEvent, [Windows.RoutedEventHandler] {
    param($s, $ev)
    $b = $ev.OriginalSource -as [Windows.Controls.Button]
    if (-not $b -or -not $b.Tag) { return }
    $id, $kind, $arg = ([string]$b.Tag).Split('|')
    $t = $script:Tweaks | Where-Object { $_.Id -eq $id } | Select-Object -First 1
    if (-not $t) { return }
    # one-file tweaks go through the Runner: the job re-imports the file (a script block must not cross runspaces)
    if (-not $t.Legacy -and $kind -in 'Apply', 'Revert', 'Run') {
        $mode = if ($kind -eq 'Revert') { 'Revert' } else { 'Apply' }
        if ($mode -eq 'Apply' -and -not (Confirm-Run $t.Confirm)) { return }
        $q = { param($s) "'" + ([string]$s -replace "'", "''") + "'" }
        $code = "`$t = Import-AkariTweakFile -Path $(& $q $t.Source) -TweaksRoot $(& $q "$Root\Tweaks"); [void](Invoke-AkariTweak `$t $mode)"
        $verb = if ($t.Kind -eq 'Action') { $t.Button.ToLower() } elseif ($mode -eq 'Apply') { 'optimize' } else { 'default' }
        Invoke-Code $code "$($t.Name): $verb"
        return
    }
    $meta = if ($t.Kind -eq 'Toggle') { @{ Id = $id; Kind = $kind } } else { $null }
    switch ($kind) {
        'Apply'  { if ($t.Apply -and (Confirm-Run $t.Confirm)) { Invoke-Code $t.Apply.ToString() "$($t.Name): $(if ($t.Kind -eq 'Toggle') { 'optimize' } else { $t.Button.ToLower() })" $meta } }
        'Revert' { if ($t.Revert) { Invoke-Code $t.Revert.ToString() "$($t.Name): default" $meta } }
        'Check'  { if ($t.Check)  { Invoke-Code $t.Check.ToString() "$($t.Name): check" } }
        'Run'    {
            if ($t.Apply -and (Confirm-Run $t.Confirm)) { Invoke-Code $t.Apply.ToString() "$($t.Name): $($t.Button.ToLower())" }
        }
        'Sub'    { $a = $t.Actions[[int]$arg]; if (Confirm-Run $a.Confirm) { Invoke-Code $a.Block.ToString() "$($t.Name): $($a.Name)" } }
        'Expand' {
            $row = $script:RowCache[$id]; $sub = $row.FindName('Sub'); $exp = $row.FindName('Exp')
            if ($sub.Visibility -eq 'Visible') { $sub.Visibility = 'Collapsed'; $exp.Content = 'Options' }
            else { $sub.Visibility = 'Visible'; $exp.Content = 'Hide' }
        }
    }
})
