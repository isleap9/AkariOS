# Install USB (plan docs/plans/2026-10-29-usb-setup-file.md, the prototype's PAGES.usb): Schneegans' unattend
# generator in AkariOS. The drive bar (Save to USB, Save to a folder), then his sections as expanders (UI\Unattend.psd1,
# built by UI\UnattendForm.ps1); Save writes autounattend.xml (Core\Unattend.ps1). The form is built once per session
# and keeps what was typed. Needs UI\Cards.ps1, UI\Apps.ps1 (New-AkariAppsButton) and UI\UnattendForm.ps1.

$script:UnattendSpec = Import-PowerShellDataFile "$Root\UI\Unattend.psd1"
$AkariUnattendSub = 'An autounattend.xml for a Windows install USB, after Schneegans'' generator'  # kept for older callers

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

# a numbered section's heading (the design's page D): the number in AccText, its name
function New-AkariNumberedHeading([int]$N, [string]$Text) {
    $h = [Windows.Controls.StackPanel]::new(); $h.Orientation = 'Horizontal'
    $h.Margin = [Windows.Thickness]::new(4, 8, 0, 8)
    $num = New-AkariText "$N" 14 'AccText' 'SemiBold'; $num.Margin = [Windows.Thickness]::new(0, 0, 10, 0)
    [void]$h.Children.Add($num); [void]$h.Children.Add((New-AkariText $Text 14 'Tx' 'SemiBold'))
    $h
}

# builds the page once (the prototype's PAGES.usb, the design's numbered sections, ADR 0011): 1 Drive (the USB found,
# Refresh, on the glass), the generator's checks, 2 Setup choices (his sections as expanders); Open file... and Reset to
# defaults go in the banner ($p.Commands), Save to a folder... and the accent Save to USB in the glass footer beside the
# USB's name ($p.Footer: Set-AkariPageFooter)
function Get-AkariUnattendView {
    if ($script:UnattendView) { return $script:UnattendView }
    $p = @{}
    $stack = [Windows.Controls.StackPanel]::new()
    [void]$stack.Children.Add((New-AkariNumberedHeading 1 'Drive'))
    # the drive bar (.usbbar) on the glass; its button under the text below 700 px
    $bar = [Windows.Controls.Border]::new()
    $bar.SetResourceReference([Windows.FrameworkElement]::StyleProperty, 'GlassCard')
    $bar.Margin = [Windows.Thickness]::new(0, 0, 0, 20)
    $dp = [Windows.Controls.DockPanel]::new()
    $ic = New-AkariIcon 'usb' 16 'Tx'; $ic.Margin = [Windows.Thickness]::new(0, 0, 12, 0); $ic.VerticalAlignment = 'Center'
    [Windows.Controls.DockPanel]::SetDock($ic, 'Left'); [void]$dp.Children.Add($ic)
    $btns = [Windows.Controls.StackPanel]::new(); $btns.Orientation = 'Horizontal'; $btns.VerticalAlignment = 'Center'
    $p.Refresh = New-AkariAppsButton 'Refresh' 'Look for a Windows setup USB again' { Update-AkariUnattendDrives -Spin } 'refresh-cw'
    $p.Folder = New-AkariAppsButton "Save to a folder$([char]0x2026)" 'Save autounattend.xml anywhere, to copy it to a USB later' { Invoke-AkariUnattendFolder }
    $p.Usb = New-AkariUnattendButton 'Save to USB' 'Accent' { Invoke-AkariUnattendUsb }
    $p.Usb.Margin = [Windows.Thickness]::new(0); $p.Usb.MinWidth = 110
    $p.Refresh.Margin = [Windows.Thickness]::new(0)
    [void]$btns.Children.Add($p.Refresh)
    [Windows.Controls.DockPanel]::SetDock($btns, 'Right'); [void]$dp.Children.Add($btns)
    Enable-AkariBarWrap $dp $btns 628
    $tx = [Windows.Controls.StackPanel]::new(); $tx.VerticalAlignment = 'Center'; $tx.Margin = [Windows.Thickness]::new(0, 0, 8, 0)
    $p.DriveName = New-AkariText 'No Windows setup USB found' 14
    $p.DriveNote = New-AkariText 'Plug one in, then refresh' 12 'Mu'
    $p.Drive = [Windows.Controls.ComboBox]::new()
    $p.Drive.SetResourceReference([Windows.FrameworkElement]::StyleProperty, 'Combo')
    $p.Drive.MinWidth = 260; $p.Drive.HorizontalAlignment = 'Left'; $p.Drive.Margin = [Windows.Thickness]::new(0, 6, 0, 0)
    $p.Drive.Add_SelectionChanged({ Update-AkariUnattendDriveText })
    foreach ($x in $p.DriveName, $p.DriveNote, $p.Drive) { [void]$tx.Children.Add($x) }
    [void]$dp.Children.Add($tx)
    $bar.Child = $dp
    [void]$stack.Children.Add($bar)
    # the generator's own checks show here
    $p.Error = New-AkariText '' 14 'Bad'
    $p.Error.Margin = [Windows.Thickness]::new(0, -8, 0, 12)
    [void]$stack.Children.Add($p.Error)
    # the command bar: in the banner (Show-AkariUnattend)
    $cmd = [Windows.Controls.StackPanel]::new(); $cmd.Orientation = 'Horizontal'
    [void]$cmd.Children.Add((New-AkariAppsButton "Open file$([char]0x2026)" 'A file made on Schneegans'' site or by Akari' { Invoke-AkariUnattendOpen } 'folder-open'))
    $reset = New-AkariAppsButton 'Reset to defaults' 'Every section back to the defaults and this PC''s settings' {
        if (Confirm-AkariDialog "The form goes back to the defaults and this PC's language, keyboard, region and time zone." 'Reset' 'Cancel' 'Question' 'Reset every section?') {
            Set-AkariUnattendStartFields; $script:UnattendParts.Error.Text = ''
        }
    } 'arrow-reset'
    $reset.Margin = [Windows.Thickness]::new(0)
    [void]$cmd.Children.Add($reset)
    $p.Commands = $cmd
    # the footer: the USB it saves to, Save to a folder..., the accent Save to USB
    $ft = [Windows.Controls.DockPanel]::new()
    $fb = [Windows.Controls.StackPanel]::new(); $fb.Orientation = 'Horizontal'
    [void]$fb.Children.Add($p.Folder); [void]$fb.Children.Add($p.Usb)
    [Windows.Controls.DockPanel]::SetDock($fb, 'Right'); [void]$ft.Children.Add($fb)
    $p.FooterName = New-AkariText '' 12 'Mu'; $p.FooterName.VerticalAlignment = 'Center'
    $p.FooterName.TextTrimming = 'CharacterEllipsis'; $p.FooterName.TextWrapping = 'NoWrap'
    [void]$ft.Children.Add($p.FooterName)
    $p.Footer = $ft
    [void]$stack.Children.Add((New-AkariNumberedHeading 2 'Setup choices'))
    New-AkariUaForm $stack $script:UnattendSpec.Sections
    $script:UnattendParts = $p
    Set-AkariUnattendStartFields
    Update-AkariUnattendDrives
    $script:UnattendView = $stack
    $stack
}

# the form on its start (the defaults and this PC's), which each section's header compares with
function Set-AkariUnattendStartFields {
    $start = Get-AkariUnattendStart
    $script:UaSyncing = $true
    try { Set-AkariUaFormFields $start } finally { $script:UaSyncing = $false }
    $script:UaStartFields = Get-AkariUaFormFields
    Update-AkariUaSections
}

function Show-AkariUnattend {
    $view = Get-AkariUnattendView
    Set-AkariHeader @('Install USB') 'An autounattend.xml for a Windows install USB: accounts, language, edition, disk and setup choices, after Christoph Schneegans'' generator.' $script:UnattendParts.Commands
    if ($view.Parent) { $view.Parent.Children.Remove($view) }
    [void]$StepBody.Children.Add($view)
    Set-AkariPageFooter $script:UnattendParts.Footer
}

# the drive bar's text: the drive picked and where the file goes, or "No Windows setup USB found"; Save to USB needs one
function Update-AkariUnattendDriveText {
    $p = $script:UnattendParts
    $it = $p.Drive.SelectedItem
    $p.DriveName.Text = if ($it) { [string]$it.Content } else { 'No Windows setup USB found' }
    $p.DriveNote.Text = if ($it) { 'The file goes to the root of the drive' } else { 'Plug one in, then refresh' }
    $p.Drive.Visibility = if ($p.Drive.Items.Count -gt 1) { 'Visible' } else { 'Collapsed' }
    if ($p.FooterName) { $p.FooterName.Text = $p.DriveName.Text }
    $p.Usb.IsEnabled = [bool]$it
}
# the drive list: drives with Windows setup first (and picked)
function Update-AkariUnattendDrives([switch]$Spin) {
    # Refresh's icon turns once (800 ms, the decelerate curve)
    if ($Spin) { Start-AkariSpin $script:UnattendParts.Refresh.Content.Children[0] 800 }
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
    Update-AkariUnattendDriveText
}

# "Open file": a file made on Schneegans' site or by Akari (its first comment holds the choices)
function Invoke-AkariUnattendOpen {
    $path = Select-AkariUnattendFile
    if (-not $path) { return }
    $fields = ConvertFrom-AkariUnattend ([IO.File]::ReadAllText($path))
    if (-not $fields) { Show-AkariMessage "This file wasn't made by Akari or Schneegans' generator, so its choices can't be read back." 'Warning' 'Unattend Generator'; return }
    $start = Get-AkariUnattendStart
    foreach ($k in $fields.Keys) { $start[$k] = $fields[$k] }
    # a checkbox the file leaves out is off
    Set-AkariUaFormFields $start
    foreach ($b in $script:UaBindings | Where-Object { $_.Kind -eq 'Check' -and -not $fields.ContainsKey($_.Field) }) { $b.Control.IsChecked = $false }
    $script:UnattendParts.Error.Text = ''
    Add-Log "Unattend Generator: opened $path"
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
    Confirm-AkariDialog "This file wipes a disk without asking (Windows PE stage, partitioning). Only use the USB on a PC whose disk you mean to erase.`n`nSave it anyway?" 'Save anyway' 'Cancel' 'Warning' 'Unattend Generator'
}

function Save-AkariUnattendTo($Bytes, [string]$Folder) {
    try {
        $path = Save-AkariUnattend $Bytes $Folder
        Add-Log "Unattend Generator: saved $path"
        Open-AkariFolder $Folder
    } catch {
        $script:UnattendParts.Error.Text = "Not saved: $($_.Exception.Message)"
        Add-Log "Error: Unattend Generator not saved ($($_.Exception.Message))"
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
    if (-not $dr.Tag.Setup -and -not (Confirm-AkariDialog "$root has no Windows setup on it (no sources\install.wim or .esd).`n`nSave the file there anyway?" 'Save anyway' 'Cancel' 'Warning' 'Unattend Generator')) { return }
    if ((Test-Path -LiteralPath (Join-Path $root 'autounattend.xml')) -and -not (Confirm-AkariDialog "$root already has an autounattend.xml.`n`nReplace it?" 'Replace' 'Cancel' 'Question' 'Unattend Generator')) { return }
    Save-AkariUnattendTo $bytes $root
}

# "Save to a folder": anywhere (Ventoy, Rufus, ahead of time)
function Invoke-AkariUnattendFolder {
    $bytes = Get-AkariUnattendBytes
    if (-not $bytes) { return }
    if (-not (Confirm-AkariUnattendWipe)) { return }
    $f = Select-AkariFolder
    if (-not $f) { return }
    if ((Test-Path -LiteralPath (Join-Path $f 'autounattend.xml')) -and -not (Confirm-AkariDialog "This folder already has an autounattend.xml.`n`nReplace it?" 'Replace' 'Cancel' 'Question' 'Unattend Generator')) { return }
    Save-AkariUnattendTo $bytes $f
}
