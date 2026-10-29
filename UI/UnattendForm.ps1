# Install USB: builds the form from UI\Unattend.psd1's Sections (WPF), reads it back as Schneegans' fields and fills
# it from fields. Like his page, only the picked branches count: a radio option's or a checkbox's Items are shown
# while it is picked, and a hidden field is left out (his page disables those inputs, so the browser never sends them).
# Needs UI\Steps.ps1 (New-AkariText). No WPF window here: tests build it in a probe.

# every bound control: @{ Field; Kind = Radio|Check|Input|Select|Checks; Control (or Options for Radio / Checks); Gates }
# Gates: the radio buttons and checkboxes that must be picked for the control to count
$script:UaBindings = [Collections.Generic.List[object]]::new()

# the items of a dropdown: a Core\Unattend\Data list (Id, DisplayName; editions only the visible ones) or inline Options
function Get-AkariUaFormItems($Item) {
    $pairs = [Collections.Generic.List[object]]::new()
    if ($Item.List) {
        foreach ($i in Get-AkariUaList $Item.List) {
            if ($Item.List -eq 'WindowsEdition' -and -not $i.Visible) { continue }
            $pairs.Add([Collections.Generic.KeyValuePair[string, string]]::new([string]$i.Id, [string]$i.DisplayName))
        }
    } else { foreach ($o in $Item.Options) { $pairs.Add([Collections.Generic.KeyValuePair[string, string]]::new([string]$o.Id, [string]$o.Name)) } }
    , $pairs
}

function New-AkariUaFormLabel([string]$Text) {
    $t = New-AkariText $Text 13 'Mu'
    $t.Margin = [Windows.Thickness]::new(0, 6, 0, 3)
    $t
}

# the panel of a branch: indented, shown while $Gate is picked
function New-AkariUaFormBranch($Gate) {
    $p = [Windows.Controls.StackPanel]::new()
    $p.Margin = [Windows.Thickness]::new(28, 2, 0, 6)
    $sync = { param($s, $e) $s.Tag.Visibility = if ($s.IsChecked) { 'Visible' } else { 'Collapsed' } }
    $Gate.Tag = $p
    $Gate.Add_Checked($sync); $Gate.Add_Unchecked($sync)
    $p.Visibility = 'Collapsed'
    $p
}

# adds the controls of $Items to $Panel; $Gates: the picks they depend on
function Add-AkariUaFormItems($Panel, $Items, $Gates) {
    foreach ($it in $Items) {
        if ($it.Note) {
            $n = New-AkariText $it.Note 13
            $n.FontWeight = 'SemiBold'; $n.Margin = [Windows.Thickness]::new(0, 10, 0, 4)
            [void]$Panel.Children.Add($n)
        } elseif ($it.Radio) {
            $opts = @{}
            foreach ($o in $it.Options) {
                $rb = [Windows.Controls.RadioButton]::new()
                $rb.SetResourceReference([Windows.FrameworkElement]::StyleProperty, 'Radio')
                $rb.GroupName = "ua-$($it.Radio)"
                $rb.Content = $o.Label
                $rb.Margin = [Windows.Thickness]::new(0, 3, 0, 3)
                [void]$Panel.Children.Add($rb)
                $opts[[string]$o.Value] = $rb
                if ($o.Items) {
                    $b = New-AkariUaFormBranch $rb
                    [void]$Panel.Children.Add($b)
                    Add-AkariUaFormItems $b $o.Items (@($Gates) + $rb)
                }
            }
            $script:UaBindings.Add(@{ Field = $it.Radio; Kind = 'Radio'; Options = $opts; Gates = @($Gates) })
        } elseif ($it.Check) {
            $cb = [Windows.Controls.CheckBox]::new()
            $cb.SetResourceReference([Windows.FrameworkElement]::StyleProperty, 'Check')
            $cb.Content = $it.Label
            $cb.Margin = [Windows.Thickness]::new(0, 3, 0, 3)
            [void]$Panel.Children.Add($cb)
            $script:UaBindings.Add(@{ Field = $it.Check; Kind = 'Check'; Control = $cb; Gates = @($Gates) })
            if ($it.Items) {
                $b = New-AkariUaFormBranch $cb
                [void]$Panel.Children.Add($b)
                Add-AkariUaFormItems $b $it.Items (@($Gates) + $cb)
            }
        } elseif ($it.Input) {
            [void]$Panel.Children.Add((New-AkariUaFormLabel $it.Label))
            $tb = [Windows.Controls.TextBox]::new()
            $tb.SetResourceReference([Windows.FrameworkElement]::StyleProperty, 'Flat')
            if ($it.Kind -eq 'Multi') {
                $tb.AcceptsReturn = $true; $tb.AcceptsTab = $true; $tb.Height = 160
                $tb.FontFamily = [Windows.Media.FontFamily]::new('Consolas')
                $tb.VerticalScrollBarVisibility = 'Auto'; $tb.HorizontalScrollBarVisibility = 'Auto'
            } elseif ($it.Kind -eq 'Number') { $tb.Width = 140; $tb.HorizontalAlignment = 'Left' }
            [void]$Panel.Children.Add($tb)
            $script:UaBindings.Add(@{ Field = $it.Input; Kind = 'Input'; Control = $tb; Gates = @($Gates) })
        } elseif ($it.Select) {
            [void]$Panel.Children.Add((New-AkariUaFormLabel $it.Label))
            $cb = [Windows.Controls.ComboBox]::new()
            $cb.SetResourceReference([Windows.FrameworkElement]::StyleProperty, 'Combo')
            $cb.ItemsSource = Get-AkariUaFormItems $it
            $cb.DisplayMemberPath = 'Value'; $cb.SelectedValuePath = 'Key'
            $cb.IsTextSearchEnabled = $true
            [void]$Panel.Children.Add($cb)
            $script:UaBindings.Add(@{ Field = $it.Select; Kind = 'Select'; Control = $cb; Gates = @($Gates) })
        } elseif ($it.Checks) {
            [void]$Panel.Children.Add((New-AkariUaFormLabel $it.Label))
            $wp = [Windows.Controls.WrapPanel]::new()
            $opts = [ordered]@{}
            foreach ($o in $it.Options) {
                $cb = [Windows.Controls.CheckBox]::new()
                $cb.SetResourceReference([Windows.FrameworkElement]::StyleProperty, 'Check')
                $cb.Content = $o.Name; $cb.Margin = [Windows.Thickness]::new(0, 3, 20, 3)
                [void]$wp.Children.Add($cb)
                $opts[[string]$o.Id] = $cb
            }
            [void]$Panel.Children.Add($wp)
            $script:UaBindings.Add(@{ Field = $it.Checks; Kind = 'Checks'; Options = $opts; Gates = @($Gates) })
        } elseif ($it.Accounts) {
            [void]$Panel.Children.Add((New-AkariUaFormAccounts $Gates))
        }
    }
}

# the account table: 15 rows (name, display name, password, group), the filled ones and one empty shown, Add account
function New-AkariUaFormAccounts($Gates) {
    $sp = [Windows.Controls.StackPanel]::new()
    $head = [Windows.Controls.Grid]::new()
    $script:UaAccountRows = [Collections.Generic.List[object]]::new()
    $cols = { param($g) foreach ($w in 3, 3, 3, 2) { $c = [Windows.Controls.ColumnDefinition]::new(); $c.Width = [Windows.GridLength]::new($w, 'Star'); [void]$g.ColumnDefinitions.Add($c) } }
    & $cols $head
    $i = 0
    foreach ($t in 'Account name', 'Display name', 'Password', 'Group') { $l = New-AkariUaFormLabel $t; [Windows.Controls.Grid]::SetColumn($l, $i++); [void]$head.Children.Add($l) }
    [void]$sp.Children.Add($head)
    foreach ($r in 0..14) {
        $g = [Windows.Controls.Grid]::new(); & $cols $g
        $g.Margin = [Windows.Thickness]::new(0, 0, 0, 4)
        $c = 0
        foreach ($f in 'AccountName', 'AccountDisplayName', 'AccountPassword') {
            $tb = [Windows.Controls.TextBox]::new()
            $tb.SetResourceReference([Windows.FrameworkElement]::StyleProperty, 'Flat')
            $tb.Margin = [Windows.Thickness]::new(0, 0, 6, 0)
            [Windows.Controls.Grid]::SetColumn($tb, $c++)
            [void]$g.Children.Add($tb)
            $script:UaBindings.Add(@{ Field = "$f$r"; Kind = 'Input'; Control = $tb; Gates = @($Gates) })
        }
        $cb = [Windows.Controls.ComboBox]::new()
        $cb.SetResourceReference([Windows.FrameworkElement]::StyleProperty, 'Combo')
        $cb.ItemsSource = Get-AkariUaFormItems @{ Options = @(@{ Id = 'Administrators'; Name = 'Administrators' }, @{ Id = 'Users'; Name = 'Users' }) }
        $cb.DisplayMemberPath = 'Value'; $cb.SelectedValuePath = 'Key'; $cb.SelectedValue = 'Users'
        [Windows.Controls.Grid]::SetColumn($cb, 3)
        [void]$g.Children.Add($cb)
        $script:UaBindings.Add(@{ Field = "AccountGroup$r"; Kind = 'Select'; Control = $cb; Gates = @($Gates) })
        [void]$sp.Children.Add($g)
        $script:UaAccountRows.Add($g)
    }
    $add = [Windows.Controls.Button]::new()
    $add.SetResourceReference([Windows.FrameworkElement]::StyleProperty, 'Btn')
    $add.Content = 'Add account'; $add.HorizontalAlignment = 'Left'; $add.Margin = [Windows.Thickness]::new(0, 4, 0, 8)
    $add.Add_Click({ $next = @($script:UaAccountRows | Where-Object { $_.Visibility -ne 'Visible' })[0]; if ($next) { $next.Visibility = 'Visible' } })
    [void]$sp.Children.Add($add)
    $script:UaAccountAdd = $add
    $sp
}

# shows the account rows with a name, then one empty row
function Update-AkariUaFormAccounts {
    $last = -1
    for ($r = 0; $r -lt $script:UaAccountRows.Count; $r++) { if ($script:UaAccountRows[$r].Children[0].Text) { $last = $r } }
    for ($r = 0; $r -lt $script:UaAccountRows.Count; $r++) { $script:UaAccountRows[$r].Visibility = if ($r -le $last + 1) { 'Visible' } else { 'Collapsed' } }
}

# builds every section as a card into $Panel
function New-AkariUaForm($Panel, $Sections) {
    $script:UaBindings.Clear()
    foreach ($s in $Sections) {
        $card = [Windows.Controls.Border]::new()
        $card.SetResourceReference([Windows.FrameworkElement]::StyleProperty, 'SettingCard')
        $card.Margin = [Windows.Thickness]::new(0, 0, 0, 12)
        $sp = [Windows.Controls.StackPanel]::new()
        $h = New-AkariText $s.Title 14
        $h.FontWeight = 'SemiBold'; $h.Margin = [Windows.Thickness]::new(0, 0, 0, 8)
        [void]$sp.Children.Add($h)
        Add-AkariUaFormItems $sp $s.Items @()
        $card.Child = $sp
        [void]$Panel.Children.Add($card)
    }
}

function Test-AkariUaGates($Binding) { -not @($Binding.Gates | Where-Object { -not $_.IsChecked }).Count }

# the form as fields: only the picked branches, as his page sends them
function Get-AkariUaFormFields {
    $f = @{}
    foreach ($b in $script:UaBindings) {
        if (-not (Test-AkariUaGates $b)) { continue }
        switch ($b.Kind) {
            'Radio' { $v = @($b.Options.Keys | Where-Object { $b.Options[$_].IsChecked })[0]; if ($v) { $f[$b.Field] = $v } }
            'Check' { if ($b.Control.IsChecked) { $f[$b.Field] = 'true' } }
            'Input' { $f[$b.Field] = [string]$b.Control.Text }
            'Select' { if ($null -ne $b.Control.SelectedValue) { $f[$b.Field] = [string]$b.Control.SelectedValue } }
            'Checks' { $v = @($b.Options.Keys | Where-Object { $b.Options[$_].IsChecked }); if ($v.Count) { $f[$b.Field] = $v } }
        }
    }
    $f
}

# fills the form from $Fields: a checkbox is ticked only when its field says so; other fields keep their value
# when $Fields lacks them. A dropdown value the list lacks is added (e.g. a keyboard of this PC).
function Set-AkariUaFormFields([hashtable]$Fields) {
    foreach ($b in $script:UaBindings) {
        $has = $Fields.ContainsKey($b.Field)
        $v = $Fields[$b.Field]
        switch ($b.Kind) {
            'Radio' { if ($has -and $b.Options.Contains([string]$v)) { $b.Options[[string]$v].IsChecked = $true } }
            'Check' { $b.Control.IsChecked = $has -and [string]$v -in 'true', 'True', 'on' }
            'Input' { if ($has) { $b.Control.Text = [string]$v } }
            'Select' {
                if (-not $has) { continue }
                $items = $b.Control.ItemsSource
                if (-not @($items | Where-Object { $_.Key -eq [string]$v }).Count) { $items.Insert(0, [Collections.Generic.KeyValuePair[string, string]]::new([string]$v, [string]$v)); $b.Control.Items.Refresh() }
                $b.Control.SelectedValue = [string]$v
            }
            'Checks' { if ($has) { foreach ($k in $b.Options.Keys) { $b.Options[$k].IsChecked = $k -in @($v) } } }
        }
    }
    if ($script:UaAccountRows) { Update-AkariUaFormAccounts }
}
