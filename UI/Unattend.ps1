# USB setup file (Home tile, plan docs/plans/2026-10-29-usb-setup-file.md): a full window form that writes an
# autounattend.xml (Core\Unattend.ps1) to a Windows install USB or a folder. Back leads Home.
# Needs UI\Steps.ps1 (New-AkariText, Set-AkariStepHeader).

$script:UnattendData = Import-PowerShellDataFile "$Root\UI\Unattend.psd1"
$AkariUnattendSub = 'Make an autounattend.xml for a Windows install USB'

function Open-AkariFolder([string]$Path) { Start-Process explorer.exe $Path }

# the folder picker for "Save to a folder": the chosen path, or $null
function Select-AkariFolder {
    Add-Type -AssemblyName System.Windows.Forms
    $d = [Windows.Forms.FolderBrowserDialog]::new()
    $d.Description = 'Where should autounattend.xml go?'
    if ($d.ShowDialog() -eq 'OK') { $d.SelectedPath } else { $null }
}

# a card with a title: @{ Card; Body }
function New-AkariFormCard([string]$Title) {
    $c = [Windows.Controls.Border]::new()
    $c.SetResourceReference([Windows.FrameworkElement]::StyleProperty, 'SettingCard')
    $c.Margin = [Windows.Thickness]::new(0, 0, 0, 12)
    $sp = [Windows.Controls.StackPanel]::new()
    $h = New-AkariText $Title 14
    $h.FontWeight = 'SemiBold'
    $h.Margin = [Windows.Thickness]::new(0, 0, 0, 10)
    [void]$sp.Children.Add($h)
    $c.Child = $sp
    @{ Card = $c; Body = $sp }
}

# a label with its control under it (and an optional grey note under that)
function New-AkariField([string]$Label, $Control, [string]$Note) {
    $sp = [Windows.Controls.StackPanel]::new()
    $sp.Margin = [Windows.Thickness]::new(0, 0, 12, 12)
    [void]$sp.Children.Add((New-AkariText $Label 13))
    $Control.Margin = [Windows.Thickness]::new(0, 4, 0, 0)
    [void]$sp.Children.Add($Control)
    if ($Note) { $n = New-AkariText $Note 12 'Mu'; $n.Margin = [Windows.Thickness]::new(0, 4, 0, 0); [void]$sp.Children.Add($n) }
    $sp
}

# a dropdown of @{ Tag; Text } items, $Selected picked (added at the top when the list lacks it)
function New-AkariFormCombo($Items, [string]$Selected) {
    $cb = [Windows.Controls.ComboBox]::new()
    $cb.SetResourceReference([Windows.FrameworkElement]::StyleProperty, 'Combo')
    $cb.HorizontalAlignment = 'Stretch'
    if ($Selected -and -not ($Items | Where-Object { $_.Tag -eq $Selected })) { $Items = @(@{ Tag = $Selected; Text = "This PC's ($Selected)" }) + @($Items) }
    foreach ($i in $Items) {
        $it = [Windows.Controls.ComboBoxItem]::new()
        $it.Content = $i.Text; $it.Tag = $i.Tag
        [void]$cb.Items.Add($it)
    }
    $cb.SelectedItem = @($cb.Items | Where-Object { $_.Tag -eq $Selected })[0]
    if ($cb.SelectedIndex -lt 0) { $cb.SelectedIndex = 0 }
    $cb
}

# two fields per row
function New-AkariFieldRow($Left, $Right) {
    $g = [Windows.Controls.Grid]::new()
    foreach ($i in 0, 1) { [void]$g.ColumnDefinitions.Add([Windows.Controls.ColumnDefinition]::new()) }
    [void]$g.Children.Add($Left)
    if ($Right) { [Windows.Controls.Grid]::SetColumn($Right, 1); [void]$g.Children.Add($Right) }
    $g
}

function Show-AkariUnattend {
    $StepDots.Children.Clear()
    Set-AkariStepHeader 'USB setup file' $AkariUnattendSub
    $StepBack.Visibility = 'Visible'
    $StepNext.Visibility = 'Collapsed'
    $d = Get-AkariUnattendDefaults
    $script:UnattendGeoId = if ($d.GeoId) { $d.GeoId } else { 244 }
    $data = $script:UnattendData
    $p = @{}

    # account and PC name
    $acc = New-AkariFormCard 'Account'
    $p.Account = [Windows.Controls.TextBox]::new(); $p.Account.SetResourceReference([Windows.FrameworkElement]::StyleProperty, 'Flat')
    $p.Password = [Windows.Controls.PasswordBox]::new(); $p.Password.SetResourceReference([Windows.FrameworkElement]::StyleProperty, 'FlatPassword')
    $p.Computer = [Windows.Controls.TextBox]::new(); $p.Computer.SetResourceReference([Windows.FrameworkElement]::StyleProperty, 'Flat')
    [void]$acc.Body.Children.Add((New-AkariFieldRow (New-AkariField 'Account name' $p.Account 'A local administrator. No spaces.') (New-AkariField 'Password (optional)' $p.Password 'Empty: Windows signs in by itself.')))
    $p.PasswordWarn = New-AkariText 'The password is stored in the file, encoded but not encrypted: anyone with this USB can recover it.' 12 'Warn'
    $p.PasswordWarn.Margin = [Windows.Thickness]::new(0, 0, 0, 12)
    $p.PasswordWarn.Visibility = 'Collapsed'
    $p.Password.Add_PasswordChanged({ $script:UnattendParts.PasswordWarn.Visibility = if ($script:UnattendParts.Password.Password) { 'Visible' } else { 'Collapsed' } })
    [void]$acc.Body.Children.Add($p.PasswordWarn)
    [void]$acc.Body.Children.Add((New-AkariFieldRow (New-AkariField 'PC name (optional)' $p.Computer 'Up to 15 letters, digits and hyphens. Empty: Windows picks one.') $null))

    # language and region, from this PC
    $loc = New-AkariFormCard 'Language and region'
    $p.Language = New-AkariFormCombo @($data.Languages | ForEach-Object { @{ Tag = $_.Tag; Text = "$($_.Name) ($($_.Tag))" } }) $d.Language
    $p.Keyboard = New-AkariFormCombo @($data.Keyboards | ForEach-Object { @{ Tag = $_.Id; Text = "$($_.Name) ($($_.Id))" } }) $d.Keyboard
    $regions = [Globalization.CultureInfo]::GetCultures('SpecificCultures') | Sort-Object EnglishName | ForEach-Object { @{ Tag = $_.Name; Text = "$($_.EnglishName) ($($_.Name))" } }
    $p.Region = New-AkariFormCombo @($regions) $d.Region
    $p.TimeZone = New-AkariFormCombo @(Get-TimeZone -ListAvailable | ForEach-Object { @{ Tag = $_.Id; Text = $_.DisplayName } }) $d.TimeZone
    # a language change moves the keyboard to the language's default
    $p.Language.Add_SelectionChanged({
        $u = $script:UnattendParts
        $lang = $script:UnattendData.Languages | Where-Object { $_.Tag -eq $u.Language.SelectedItem.Tag }
        $kb = @($u.Keyboard.Items | Where-Object { $lang -and $_.Tag -eq $lang.Keyboard })[0]
        if ($kb) { $u.Keyboard.SelectedItem = $kb }
    })
    [void]$loc.Body.Children.Add((New-AkariFieldRow (New-AkariField 'Windows language' $p.Language 'Must be a language your Windows ISO has.') (New-AkariField 'Keyboard' $p.Keyboard '')))
    [void]$loc.Body.Children.Add((New-AkariFieldRow (New-AkariField 'Region format' $p.Region '') (New-AkariField 'Time zone' $p.TimeZone '')))

    # setup
    $set = New-AkariFormCard 'Setup'
    $p.SkipChecks = [Windows.Controls.CheckBox]::new()
    $p.SkipChecks.SetResourceReference([Windows.FrameworkElement]::StyleProperty, 'Check')
    $p.SkipChecks.Content = "Skip Windows 11's hardware checks (TPM, Secure Boot, CPU, RAM, storage)"
    $p.SkipChecks.IsChecked = $true
    [void]$set.Body.Children.Add($p.SkipChecks)
    $fixed = New-AkariText 'Setup skips the license, Microsoft account, network and privacy questions; the password never expires. It still asks which disk to install on, and the edition.' 12 'Mu'
    $fixed.Margin = [Windows.Thickness]::new(0, 10, 0, 0)
    [void]$set.Body.Children.Add($fixed)

    # save
    $sv = New-AkariFormCard 'Save'
    $p.Drive = [Windows.Controls.ComboBox]::new()
    $p.Drive.SetResourceReference([Windows.FrameworkElement]::StyleProperty, 'Combo')
    $p.Drive.MinWidth = 260
    $bar = [Windows.Controls.StackPanel]::new()
    $bar.Orientation = 'Horizontal'
    $refresh = [Windows.Controls.Button]::new(); $refresh.SetResourceReference([Windows.FrameworkElement]::StyleProperty, 'Btn')
    $refresh.Content = 'Refresh'; $refresh.Margin = [Windows.Thickness]::new(8, 0, 0, 0)
    $refresh.Add_Click({ Update-AkariUnattendDrives })
    [void]$bar.Children.Add($p.Drive); [void]$bar.Children.Add($refresh)
    [void]$sv.Body.Children.Add($bar)
    $btns = [Windows.Controls.StackPanel]::new()
    $btns.Orientation = 'Horizontal'
    $btns.Margin = [Windows.Thickness]::new(0, 12, 0, 0)
    $toUsb = [Windows.Controls.Button]::new(); $toUsb.SetResourceReference([Windows.FrameworkElement]::StyleProperty, 'Accent')
    $toUsb.Content = 'Save to USB'; $toUsb.Margin = [Windows.Thickness]::new(0, 0, 8, 0)
    $toUsb.Add_Click({ Invoke-AkariUnattendUsb })
    $fold = [Windows.Controls.Button]::new(); $fold.SetResourceReference([Windows.FrameworkElement]::StyleProperty, 'Btn')
    $fold.Content = "Save to a folder$([char]0x2026)"
    $fold.Add_Click({ Invoke-AkariUnattendFolder })
    [void]$btns.Children.Add($toUsb); [void]$btns.Children.Add($fold)
    [void]$sv.Body.Children.Add($btns)
    $p.Error = New-AkariText '' 13 'Bad'
    $p.Error.Margin = [Windows.Thickness]::new(0, 10, 0, 0)
    [void]$sv.Body.Children.Add($p.Error)

    $script:UnattendParts = $p
    Update-AkariUnattendDrives
    # one column on the left, at most 800 px wide, like About
    $col = [Windows.Controls.Grid]::new()
    $cd = [Windows.Controls.ColumnDefinition]::new(); $cd.Width = [Windows.GridLength]::new(1, 'Star'); $cd.MaxWidth = 800
    [void]$col.ColumnDefinitions.Add($cd)
    $stack = [Windows.Controls.StackPanel]::new()
    foreach ($c in $acc, $loc, $set, $sv) { [void]$stack.Children.Add($c.Card) }
    [void]$col.Children.Add($stack)
    $StepBody.Children.Clear()
    [void]$StepBody.Children.Add($col)
}

# the drive list: drives with Windows setup first (and picked)
function Update-AkariUnattendDrives {
    $cb = $script:UnattendParts.Drive
    $cb.Items.Clear()
    $drives = @(try { Get-AkariSetupDrives } catch { Add-Log "Warning: drives not read ($($_.Exception.Message))" }) | Where-Object { $_ }
    foreach ($dr in @($drives | Where-Object { $_.Setup }) + @($drives | Where-Object { -not $_.Setup })) {
        $it = [Windows.Controls.ComboBoxItem]::new()
        $name = if ($dr.Label) { $dr.Label } else { $dr.Root }
        $it.Content = if ($dr.Setup) { "$name (Windows setup)" } else { $name }
        $it.Tag = $dr
        [void]$cb.Items.Add($it)
    }
    if ($cb.Items.Count) { $cb.SelectedIndex = 0 }
}

# the form as New-AkariUnattend's options, or $null with the problem shown
function Get-AkariUnattendForm {
    $p = $script:UnattendParts
    $p.Error.Text = ''
    $acc = $p.Account.Text.Trim(); $pc = $p.Computer.Text.Trim()
    $bad = Test-AkariUnattendName $acc 'Account'
    if (-not $bad) { $bad = Test-AkariUnattendName $pc 'Computer'; if ($bad) { $bad = "PC name: $bad" } }
    if ($bad) { $p.Error.Text = $bad; return $null }
    $o = New-AkariUnattendOptions
    $o.Accounts = @(@{ Name = $acc; DisplayName = ''; Password = $p.Password.Password; Group = 'Administrators' }); $o.Computer = $pc
    $o.Language = [string]$p.Language.SelectedItem.Tag; $o.Inputs = @([string]$p.Keyboard.SelectedItem.Tag)
    $o.Region = [string]$p.Region.SelectedItem.Tag; $o.TimeZone = [string]$p.TimeZone.SelectedItem.Tag
    $o.GeoId = [int]$script:UnattendGeoId
    $o.SkipChecks = [bool]$p.SkipChecks.IsChecked
    $o
}

function Save-AkariUnattendForm($Options, [string]$Folder) {
    try {
        $path = Save-AkariUnattend (New-AkariUnattend $Options) $Folder
        Add-Log "USB setup file saved: $path"
        Open-AkariFolder $Folder
    } catch {
        $script:UnattendParts.Error.Text = "Not saved: $($_.Exception.Message)"
        Add-Log "Error: USB setup file not saved ($($_.Exception.Message))"
    }
}

# "Save to USB": at the root of the picked drive; a drive without Windows setup, or a file already there, asks first
function Invoke-AkariUnattendUsb {
    $o = Get-AkariUnattendForm
    if (-not $o) { return }
    $dr = $script:UnattendParts.Drive.SelectedItem
    if (-not $dr) { $script:UnattendParts.Error.Text = 'No USB drive found: plug one in and press Refresh, or save to a folder.'; return }
    $root = $dr.Tag.Root
    if (-not $dr.Tag.Setup -and -not (Confirm-AkariDialog "$root has no Windows setup on it (no sources\install.wim or .esd).`n`nSave the file there anyway?" 'Save anyway' 'Cancel' 'Warning' 'USB setup file')) { return }
    if ((Test-Path -LiteralPath (Join-Path $root 'autounattend.xml')) -and -not (Confirm-AkariDialog "$root already has an autounattend.xml.`n`nReplace it?" 'Replace' 'Cancel' 'Question' 'USB setup file')) { return }
    Save-AkariUnattendForm $o $root
}

# "Save to a folder": anywhere (Ventoy, Rufus, ahead of time)
function Invoke-AkariUnattendFolder {
    $o = Get-AkariUnattendForm
    if (-not $o) { return }
    $f = Select-AkariFolder
    if (-not $f) { return }
    if ((Test-Path -LiteralPath (Join-Path $f 'autounattend.xml')) -and -not (Confirm-AkariDialog "This folder already has an autounattend.xml.`n`nReplace it?" 'Replace' 'Cancel' 'Question' 'USB setup file')) { return }
    Save-AkariUnattendForm $o $f
}
