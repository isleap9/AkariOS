# Install USB (Home tile, plan docs/plans/2026-10-29-usb-setup-file.md): Schneegans' unattend generator in AkariOS.
# One long page of his sections (UI\Unattend.psd1, built by UI\UnattendForm.ps1), then Save: autounattend.xml
# (Core\Unattend.ps1) to a Windows install USB or a folder. Back leads Home. The form is built once per session and
# keeps what was typed. Needs UI\Steps.ps1 (New-AkariText, Set-AkariStepHeader) and UI\UnattendForm.ps1.

$script:UnattendSpec = Import-PowerShellDataFile "$Root\UI\Unattend.psd1"
$AkariUnattendSub = 'An autounattend.xml for a Windows install USB, after Schneegans'' generator'

function Open-AkariFolder([string]$Path) { Start-Process explorer.exe $Path }

# the folder picker for "Save to a folder": the chosen path, or $null
function Select-AkariFolder {
    Add-Type -AssemblyName System.Windows.Forms
    $d = [Windows.Forms.FolderBrowserDialog]::new()
    $d.Description = 'Where should autounattend.xml go?'
    if ($d.ShowDialog() -eq 'OK') { $d.SelectedPath } else { $null }
}

# the file picker for "Open file": the chosen path, or $null
function Select-AkariUnattendFile {
    Add-Type -AssemblyName System.Windows.Forms
    $d = [Windows.Forms.OpenFileDialog]::new()
    $d.Filter = 'Answer files (*.xml)|*.xml|All files (*.*)|*.*'
    if ($d.ShowDialog() -eq 'OK') { $d.FileName } else { $null }
}

# the form's starting fields: the defaults, the text areas' samples, then this PC's language, region and time zone
function Get-AkariUnattendStart {
    $f = @{} + $script:UnattendSpec.Defaults
    $s = Get-AkariUnattendSamples
    foreach ($k in $s.Keys) { $f[$k] = $s[$k] }
    $pc = try { Get-AkariUnattendDefaults } catch { @{} }
    $known = { param($list, $id) $id -and @(Get-AkariUaList $list | Where-Object { $_.Id -eq $id }).Count }
    if (& $known 'ImageLanguage' $pc.UILanguage) { $f.UILanguage = $pc.UILanguage }
    if (& $known 'UserLocale' $pc.Locale) { $f.Locale = $pc.Locale }
    if (& $known 'KeyboardIdentifier' $pc.Keyboard) { $f.Keyboard = $pc.Keyboard }
    if (& $known 'GeoId' $pc.GeoLocation) { $f.GeoLocation = $pc.GeoLocation }
    if (& $known 'TimeOffset' $pc.TimeZone) { $f.TimeZone = $pc.TimeZone }
    $f
}

function New-AkariUnattendButton([string]$Text, [string]$Style, [scriptblock]$Click) {
    $b = [Windows.Controls.Button]::new()
    $b.SetResourceReference([Windows.FrameworkElement]::StyleProperty, $Style)
    $b.Content = $Text
    $b.Margin = [Windows.Thickness]::new(0, 0, 8, 0)
    $b.Add_Click($Click)
    $b
}

# builds the page once: the tool bar, his sections, the Save card
function Get-AkariUnattendView {
    if ($script:UnattendView) { return $script:UnattendView }
    $p = @{}
    $col = [Windows.Controls.Grid]::new()
    $cd = [Windows.Controls.ColumnDefinition]::new(); $cd.Width = [Windows.GridLength]::new(1, 'Star'); $cd.MaxWidth = 860
    [void]$col.ColumnDefinitions.Add($cd)
    $stack = [Windows.Controls.StackPanel]::new()
    [void]$col.Children.Add($stack)
    $bar = [Windows.Controls.StackPanel]::new()
    $bar.Orientation = 'Horizontal'; $bar.Margin = [Windows.Thickness]::new(0, 0, 0, 12)
    [void]$bar.Children.Add((New-AkariUnattendButton "Open file$([char]0x2026)" 'Btn' { Invoke-AkariUnattendOpen }))
    [void]$bar.Children.Add((New-AkariUnattendButton 'Reset to defaults' 'Btn' { Set-AkariUaFormFields (Get-AkariUnattendStart); $script:UnattendParts.Error.Text = '' }))
    [void]$stack.Children.Add($bar)
    New-AkariUaForm $stack $script:UnattendSpec.Sections
    # save
    $card = [Windows.Controls.Border]::new()
    $card.SetResourceReference([Windows.FrameworkElement]::StyleProperty, 'SettingCard')
    $sv = [Windows.Controls.StackPanel]::new()
    $h = New-AkariText 'Save' 14; $h.FontWeight = 'SemiBold'; $h.Margin = [Windows.Thickness]::new(0, 0, 0, 8)
    [void]$sv.Children.Add($h)
    $drives = [Windows.Controls.StackPanel]::new(); $drives.Orientation = 'Horizontal'
    $p.Drive = [Windows.Controls.ComboBox]::new()
    $p.Drive.SetResourceReference([Windows.FrameworkElement]::StyleProperty, 'Combo')
    $p.Drive.MinWidth = 280; $p.Drive.Margin = [Windows.Thickness]::new(0, 0, 8, 0)
    [void]$drives.Children.Add($p.Drive)
    [void]$drives.Children.Add((New-AkariUnattendButton 'Refresh' 'Btn' { Update-AkariUnattendDrives }))
    [void]$sv.Children.Add($drives)
    $btns = [Windows.Controls.StackPanel]::new(); $btns.Orientation = 'Horizontal'; $btns.Margin = [Windows.Thickness]::new(0, 12, 0, 0)
    [void]$btns.Children.Add((New-AkariUnattendButton 'Save to USB' 'Accent' { Invoke-AkariUnattendUsb }))
    [void]$btns.Children.Add((New-AkariUnattendButton "Save to a folder$([char]0x2026)" 'Btn' { Invoke-AkariUnattendFolder }))
    [void]$sv.Children.Add($btns)
    $p.Error = New-AkariText '' 13 'Bad'
    $p.Error.Margin = [Windows.Thickness]::new(0, 10, 0, 0)
    [void]$sv.Children.Add($p.Error)
    $card.Child = $sv
    [void]$stack.Children.Add($card)
    $script:UnattendParts = $p
    Set-AkariUaFormFields (Get-AkariUnattendStart)
    Update-AkariUnattendDrives
    $script:UnattendView = $col
    $col
}

function Show-AkariUnattend {
    $StepDots.Children.Clear()
    Set-AkariStepHeader 'Install USB' $AkariUnattendSub
    $StepBack.Visibility = 'Visible'
    $StepNext.Visibility = 'Collapsed'
    $view = Get-AkariUnattendView
    if ($view.Parent) { $view.Parent.Children.Remove($view) }
    $StepBody.Children.Clear()
    [void]$StepBody.Children.Add($view)
}

# the drive list: drives with Windows setup first (and picked)
function Update-AkariUnattendDrives {
    $cb = $script:UnattendParts.Drive
    $cb.Items.Clear()
    $drives = @(try { Get-AkariSetupDrives } catch { Add-Log "Warning: drives not read ($($_.Exception.Message))" }) | Where-Object { $_ }
    foreach ($dr in @($drives | Where-Object { $_.Setup }) + @($drives | Where-Object { -not $_.Setup })) {
        $it = [Windows.Controls.ComboBoxItem]::new()
        $name = if ($dr.Label) { "$($dr.Root) $($dr.Label)" } else { $dr.Root }
        $it.Content = if ($dr.Setup) { "$name (Windows setup)" } else { $name }
        $it.Tag = $dr
        [void]$cb.Items.Add($it)
    }
    if ($cb.Items.Count) { $cb.SelectedIndex = 0 }
}

# "Open file": a file made on Schneegans' site or by Akari (its first comment holds the choices)
function Invoke-AkariUnattendOpen {
    $path = Select-AkariUnattendFile
    if (-not $path) { return }
    $fields = ConvertFrom-AkariUnattend ([IO.File]::ReadAllText($path))
    if (-not $fields) { Show-AkariMessage "This file wasn't made by Akari or Schneegans' generator, so its choices can't be read back." 'Warning' 'Install USB'; return }
    $start = Get-AkariUnattendStart
    foreach ($k in $fields.Keys) { $start[$k] = $fields[$k] }
    # a checkbox the file leaves out is off
    Set-AkariUaFormFields $start
    foreach ($b in $script:UaBindings | Where-Object { $_.Kind -eq 'Check' -and -not $fields.ContainsKey($_.Field) }) { $b.Control.IsChecked = $false }
    $script:UnattendParts.Error.Text = ''
    Add-Log "Install USB: opened $path"
}

# the file for the form, or $null with the problem shown
function Get-AkariUnattendBytes {
    $script:UnattendParts.Error.Text = ''
    $fields = Get-AkariUaFormFields
    try { , (New-AkariUnattend $fields) } catch { $script:UnattendParts.Error.Text = $_.Exception.Message; $null }
}

# a file that partitions a disk by itself: say so before it is written
function Confirm-AkariUnattendWipe {
    $f = Get-AkariUaFormFields
    if ($f.PEMode -ne 'Generated' -or $f.PartitionMode -notin 'Unattended', 'Custom') { return $true }
    Confirm-AkariDialog "This file wipes a disk without asking (Windows PE stage, partitioning). Only use the USB on a PC whose disk you mean to erase.`n`nSave it anyway?" 'Save anyway' 'Cancel' 'Warning' 'Install USB'
}

function Save-AkariUnattendTo($Bytes, [string]$Folder) {
    try {
        $path = Save-AkariUnattend $Bytes $Folder
        Add-Log "Install USB: saved $path"
        Open-AkariFolder $Folder
    } catch {
        $script:UnattendParts.Error.Text = "Not saved: $($_.Exception.Message)"
        Add-Log "Error: Install USB not saved ($($_.Exception.Message))"
    }
}

# "Save to USB": at the root of the picked drive; a drive without Windows setup, or a file already there, asks first
function Invoke-AkariUnattendUsb {
    $bytes = Get-AkariUnattendBytes
    if (-not $bytes) { return }
    $dr = $script:UnattendParts.Drive.SelectedItem
    if (-not $dr) { $script:UnattendParts.Error.Text = 'No USB drive found: plug one in and press Refresh, or save to a folder.'; return }
    $root = $dr.Tag.Root
    if (-not (Confirm-AkariUnattendWipe)) { return }
    if (-not $dr.Tag.Setup -and -not (Confirm-AkariDialog "$root has no Windows setup on it (no sources\install.wim or .esd).`n`nSave the file there anyway?" 'Save anyway' 'Cancel' 'Warning' 'Install USB')) { return }
    if ((Test-Path -LiteralPath (Join-Path $root 'autounattend.xml')) -and -not (Confirm-AkariDialog "$root already has an autounattend.xml.`n`nReplace it?" 'Replace' 'Cancel' 'Question' 'Install USB')) { return }
    Save-AkariUnattendTo $bytes $root
}

# "Save to a folder": anywhere (Ventoy, Rufus, ahead of time)
function Invoke-AkariUnattendFolder {
    $bytes = Get-AkariUnattendBytes
    if (-not $bytes) { return }
    if (-not (Confirm-AkariUnattendWipe)) { return }
    $f = Select-AkariFolder
    if (-not $f) { return }
    if ((Test-Path -LiteralPath (Join-Path $f 'autounattend.xml')) -and -not (Confirm-AkariDialog "This folder already has an autounattend.xml.`n`nReplace it?" 'Replace' 'Cancel' 'Question' 'Install USB')) { return }
    Save-AkariUnattendTo $bytes $f
}
