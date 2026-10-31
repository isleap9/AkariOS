# ISO Builder (its tab and Home tile; plan docs/plans/2026-10-31-iso-builder.md): a custom Windows 11 ISO, after
# zoicware's zISO Tweaker. One long page in zISO's order: 1 the ISO (a file, UUP Dump, Massgrave), 2 the edition,
# 3 the answer file, 4 Windows Update, 5 security and privacy, 6 apps, 7 AkariOS, then Build. Every slow step runs in
# the background job (Kind Iso*, Complete-AkariIsoJob). Back leads Home. Built once per session. Needs UI\Steps.ps1
# (New-AkariText, Set-AkariStepHeader) and UI\Unattend.ps1 (Get-AkariUnattendStart, the generator's page).

$AkariIsoSub = 'A custom Windows 11 ISO: apps removed and settings written in before it installs, after zISO Tweaker'
$AkariIsoGroupTitles = [ordered]@{ Update = '4  Windows Update'; Security = '5  Security and privacy'; Apps = '6  Apps' }
$script:IsoState = @{ Image = ''; Editions = @(); Lists = $null; Massgrave = @(); Uup = $null; Waiting = '' }

# ---- pure helpers (tests dot-source this file)

# the answer file fields for "A local account": the Unattend Generator's starting fields with one administrator, or
# a local account made during setup when the setup questions stay. Windows PE stays interactive (setup asks for the
# disk): the partitioning fields are left out. Pure.
function Get-AkariIsoAnswerFields([hashtable]$Start, [string]$User, [string]$Password, [bool]$SkipOobe) {
    $f = @{} + $Start
    foreach ($k in @($f.Keys)) { if ($k -match '^(Partition|TargetDisk|SystemSize|Recovery|InstallFrom|PagingFile|InitPagingFile|MaxPagingFile)') { $f.Remove($k) } }
    $f.PEMode = 'Default'
    if (-not $SkipOobe) { $f.UserAccountMode = 'InteractiveLocal'; return $f }
    if (-not $User.Trim()) { $User = 'Admin' }
    $f.UserAccountMode = 'Unattended'
    $f.AccountName0 = $User.Trim(); $f.AccountDisplayName0 = $User.Trim(); $f.AccountPassword0 = $Password; $f.AccountGroup0 = 'Administrators'
    $f.AutoLogonMode = 'Own'
    $f
}

# the image's apps the Remove tab recommends (Win11Debloat's Safe rows that aren't on FR33THY's keep-list). Pure.
function Get-AkariIsoRecommendedApps($Apps, $Tweaks) {
    $safe = @{}
    foreach ($t in @($Tweaks)) { if ($t.Id -like 'appx/*' -and $t.Risk -eq 'Safe' -and -not $t.Keep) { $safe[$t.Id.Substring(5)] = $true } }
    @($Apps | Where-Object { $safe.ContainsKey($_.Name) } | ForEach-Object { $_.Package })
}

# the options another picked one rules out (Disable all updates turns the other two off, as in zISO). Pure.
function Get-AkariIsoBlocked($Picked, $Options) {
    @(foreach ($o in @($Options)) { if (@($Picked) -contains $o.Id) { @($o.Excludes) | Where-Object { $_ } } }) | Sort-Object -Unique
}

# Massgrave's products in page order, and a product's languages. Pure.
function Get-AkariMassgraveProducts($Items) { @($Items | ForEach-Object { $_.Product } | Select-Object -Unique) }
function Get-AkariMassgraveFiles($Items, [string]$Product) { @($Items | Where-Object { $_.Product -eq $Product }) }

# ---- pickers (tests stub them)

function Select-AkariIsoFile {
    Add-Type -AssemblyName System.Windows.Forms
    $d = [Windows.Forms.OpenFileDialog]::new()
    $d.Filter = 'Windows ISO (*.iso)|*.iso|All files (*.*)|*.*'
    if ($d.ShowDialog() -eq 'OK') { $d.FileName } else { $null }
}
function Select-AkariIsoFolder {
    Add-Type -AssemblyName System.Windows.Forms
    $d = [Windows.Forms.FolderBrowserDialog]::new()
    $d.Description = 'Where should the ISO Builder work and save the ISO? (NTFS, 25 GB free)'
    if ($d.ShowDialog() -eq 'OK') { $d.SelectedPath } else { $null }
}
function Open-AkariIsoLink([string]$Url) { Start-Process $Url }

# ---- building blocks

function New-AkariIsoButton([string]$Text, [string]$Style, [scriptblock]$Click) {
    $b = [Windows.Controls.Button]::new()
    $b.SetResourceReference([Windows.FrameworkElement]::StyleProperty, $Style)
    $b.Content = $Text
    $b.Margin = [Windows.Thickness]::new(0, 0, 8, 0)
    $b.Add_Click($Click)
    $b
}
function New-AkariIsoRow { $r = [Windows.Controls.StackPanel]::new(); $r.Orientation = 'Horizontal'; $r.Margin = [Windows.Thickness]::new(0, 6, 0, 6); $r }
function New-AkariIsoCombo([double]$Width = 220) {
    $c = [Windows.Controls.ComboBox]::new()
    $c.SetResourceReference([Windows.FrameworkElement]::StyleProperty, 'Combo')
    $c.MinWidth = $Width; $c.Margin = [Windows.Thickness]::new(0, 0, 8, 0)
    $c
}
function New-AkariIsoBox([double]$Width = 420) {
    $t = [Windows.Controls.TextBox]::new()
    $t.SetResourceReference([Windows.FrameworkElement]::StyleProperty, 'Flat')
    $t.Width = $Width; $t.Margin = [Windows.Thickness]::new(0, 0, 8, 0)
    $t
}
function New-AkariIsoCheck([string]$Text, [bool]$On = $false) {
    $c = [Windows.Controls.CheckBox]::new()
    $c.SetResourceReference([Windows.FrameworkElement]::StyleProperty, 'Check')
    $c.Content = $Text; $c.IsChecked = $On
    $c.Margin = [Windows.Thickness]::new(0, 3, 0, 3)
    $c
}
function New-AkariIsoRadio([string]$Group, [string]$Text) {
    $r = [Windows.Controls.RadioButton]::new()
    $r.SetResourceReference([Windows.FrameworkElement]::StyleProperty, 'Radio')
    $r.GroupName = $Group; $r.Content = $Text
    $r.Margin = [Windows.Thickness]::new(0, 3, 0, 3)
    $r
}
# a numbered card: @{ Card; Panel }
function New-AkariIsoCard([string]$Title, [string]$Sub = '') {
    $card = [Windows.Controls.Border]::new()
    $card.SetResourceReference([Windows.FrameworkElement]::StyleProperty, 'SettingCard')
    $card.Margin = [Windows.Thickness]::new(0, 0, 0, 12)
    $sp = [Windows.Controls.StackPanel]::new()
    $h = New-AkariText $Title 20
    $h.FontWeight = 'SemiBold'; $h.Margin = [Windows.Thickness]::new(0, 0, 0, 4)
    Set-AkariFont $h 'Display'
    [void]$sp.Children.Add($h)
    if ($Sub) { $s = New-AkariText $Sub 13 'Mu'; $s.Margin = [Windows.Thickness]::new(0, 0, 0, 8); [void]$sp.Children.Add($s) }
    $card.Child = $sp
    @{ Card = $card; Panel = $sp }
}
# a panel shown while $Gate (a radio or check box) is on
function New-AkariIsoBranch($Gate) {
    $p = [Windows.Controls.StackPanel]::new()
    $p.Margin = [Windows.Thickness]::new(28, 2, 0, 6)
    $Gate.Tag = $p
    $sync = { param($s, $e) $s.Tag.Visibility = if ($s.IsChecked) { 'Visible' } else { 'Collapsed' } }
    $Gate.Add_Checked($sync); $Gate.Add_Unchecked($sync)
    $p.Visibility = if ($Gate.IsChecked) { 'Visible' } else { 'Collapsed' }
    $p
}
function Set-AkariComboItems($Combo, $Items, [scriptblock]$Label) {
    $Combo.Items.Clear()
    foreach ($i in @($Items)) {
        $it = [Windows.Controls.ComboBoxItem]::new()
        $it.Content = & $Label $i; $it.Tag = $i
        [void]$Combo.Items.Add($it)
    }
    if ($Combo.Items.Count) { $Combo.SelectedIndex = 0 }
}
function Get-AkariComboTag($Combo) { if ($Combo.SelectedItem) { $Combo.SelectedItem.Tag } else { $null } }

# ---- the page

function Get-AkariIsoView {
    if ($script:IsoView) { return $script:IsoView }
    $p = @{}
    $col = [Windows.Controls.Grid]::new()
    $cd = [Windows.Controls.ColumnDefinition]::new(); $cd.Width = [Windows.GridLength]::new(1, 'Star'); $cd.MaxWidth = 860
    [void]$col.ColumnDefinitions.Add($cd)
    $stack = [Windows.Controls.StackPanel]::new()
    [void]$col.Children.Add($stack)

    # 1 the ISO
    $c = New-AkariIsoCard '1  Windows 11 ISO' 'An ISO you have, or one downloaded here. Akari copies it to a work folder, so the ISO itself is not changed.'
    $p.SrcFile = New-AkariIsoRadio 'iso-src' 'An ISO file I have'
    $p.SrcUup = New-AkariIsoRadio 'iso-src' 'Download with UUP Dump (23H2 to 26H2, any language, Home to IoT Enterprise)'
    $p.SrcMg = New-AkariIsoRadio 'iso-src' 'Download from Massgrave (LTSC, IoT LTSC, consumer and business media)'
    $p.SrcFile.IsChecked = $true
    [void]$c.Panel.Children.Add($p.SrcFile)
    $b = New-AkariIsoBranch $p.SrcFile; $r = New-AkariIsoRow
    $p.IsoPath = New-AkariIsoBox
    [void]$r.Children.Add($p.IsoPath)
    [void]$r.Children.Add((New-AkariIsoButton "Browse$([char]0x2026)" 'Btn' { $f = Select-AkariIsoFile; if ($f) { $script:IsoParts.IsoPath.Text = $f } }))
    [void]$b.Children.Add($r); [void]$c.Panel.Children.Add($b)
    [void]$c.Panel.Children.Add($p.SrcUup)
    $b = New-AkariIsoBranch $p.SrcUup
    $r = New-AkariIsoRow
    $p.UupVersion = New-AkariIsoCombo 110
    Set-AkariComboItems $p.UupVersion @($AkariUupVersions.Keys) { param($v) "Windows 11 $v" }
    $p.UupVersion.SelectedIndex = -1
    $p.UupVersion.Add_SelectionChanged({ Start-AkariUupList 'Build' })
    $p.UupLang = New-AkariIsoCombo 200
    $p.UupLang.Add_SelectionChanged({ if ($this.IsKeyboardFocusWithin -or $this.IsDropDownOpen) { Start-AkariUupList 'Editions' } })
    $p.UupEdition = New-AkariIsoCombo 180
    foreach ($x in $p.UupVersion, $p.UupLang, $p.UupEdition) { [void]$r.Children.Add($x) }
    [void]$b.Children.Add($r)
    $r = New-AkariIsoRow
    [void]$r.Children.Add((New-AkariIsoButton 'Download' 'Btn' { Start-AkariUupDownload }))
    [void]$b.Children.Add($r)
    $p.UupNote = New-AkariText 'Pick a version. UUP Dump builds the ISO from Microsoft''s own files: allow 20 to 60 minutes.' 13 'Mu'
    [void]$b.Children.Add($p.UupNote); [void]$c.Panel.Children.Add($b)
    [void]$c.Panel.Children.Add($p.SrcMg)
    $b = New-AkariIsoBranch $p.SrcMg
    $p.SrcMg.Add_Checked({ if (-not $script:IsoState.Massgrave.Count) { Start-AkariMassgraveList } })
    $r = New-AkariIsoRow
    $p.MgProduct = New-AkariIsoCombo 300
    $p.MgProduct.Add_SelectionChanged({ Update-AkariMassgraveLanguages })
    $p.MgFile = New-AkariIsoCombo 220
    [void]$r.Children.Add($p.MgProduct); [void]$r.Children.Add($p.MgFile)
    [void]$b.Children.Add($r)
    $r = New-AkariIsoRow
    [void]$r.Children.Add((New-AkariIsoButton 'Open download page' 'Btn' { Open-AkariMassgraveFile }))
    [void]$b.Children.Add($r)
    $p.MgNote = New-AkariText 'Massgrave''s links go to file hosts Akari can''t download from: your browser does, then Akari finds the file in Downloads.' 13 'Mu'
    [void]$b.Children.Add($p.MgNote); [void]$c.Panel.Children.Add($b)
    [void]$c.Panel.Children.Add((New-AkariUaFormLabel 'Work and output folder (NTFS, 25 GB free; the ISO is saved here)'))
    $r = New-AkariIsoRow
    $p.OutDir = New-AkariIsoBox
    $p.OutDir.Text = try { Get-AkariUserFolder 'Downloads' } catch { '' }
    [void]$r.Children.Add($p.OutDir)
    [void]$r.Children.Add((New-AkariIsoButton "Browse$([char]0x2026)" 'Btn' { $f = Select-AkariIsoFolder; if ($f) { $script:IsoParts.OutDir.Text = $f } }))
    [void]$c.Panel.Children.Add($r)
    $r = New-AkariIsoRow
    [void]$r.Children.Add((New-AkariIsoButton 'Open ISO' 'Accent' { Start-AkariIsoOpen }))
    [void]$c.Panel.Children.Add($r)
    $p.OpenNote = New-AkariText '' 13 'Mu'
    [void]$c.Panel.Children.Add($p.OpenNote)
    [void]$stack.Children.Add($c.Card)

    # 2 the edition
    $c = New-AkariIsoCard '2  Edition' 'The ISO keeps only this edition.'
    $p.Edition = New-AkariIsoCombo 320
    $p.Edition.IsEnabled = $false
    [void]$c.Panel.Children.Add($p.Edition)
    [void]$stack.Children.Add($c.Card)

    # 3 the answer file
    $c = New-AkariIsoCard '3  Answer file' 'autounattend.xml at the root of the ISO: Windows setup reads it by itself.'
    $p.AnsNone = New-AkariIsoRadio 'iso-ans' 'None: setup asks everything as usual'
    $p.AnsLocal = New-AkariIsoRadio 'iso-ans' 'A local account (this PC''s language, keyboard and time zone; setup still asks for the disk)'
    $p.AnsGen = New-AkariIsoRadio 'iso-ans' 'The Unattend Generator''s choices'
    $p.AnsLocal.IsChecked = $true
    [void]$c.Panel.Children.Add($p.AnsNone); [void]$c.Panel.Children.Add($p.AnsLocal)
    $b = New-AkariIsoBranch $p.AnsLocal
    $p.SkipOobe = New-AkariIsoCheck 'Skip the setup questions (OOBE) and create this administrator' $true
    [void]$b.Children.Add($p.SkipOobe)
    $acct = New-AkariIsoBranch $p.SkipOobe
    $r = New-AkariIsoRow
    $p.User = New-AkariIsoBox 200; $p.User.Text = 'Admin'
    $p.Password = New-AkariIsoBox 200
    [void]$r.Children.Add((New-AkariUaFormLabel 'User name ')); [void]$r.Children.Add($p.User)
    [void]$r.Children.Add((New-AkariUaFormLabel 'Password ')); [void]$r.Children.Add($p.Password)
    [void]$acct.Children.Add($r)
    [void]$acct.Children.Add((New-AkariText 'The password is in the answer file (Base64, not encrypted): anyone with the ISO can read it. Leave it empty for none.' 13 'Mu'))
    [void]$b.Children.Add($acct); [void]$c.Panel.Children.Add($b)
    [void]$c.Panel.Children.Add($p.AnsGen)
    $b = New-AkariIsoBranch $p.AnsGen; $r = New-AkariIsoRow
    [void]$r.Children.Add((New-AkariIsoButton 'Open the Unattend Generator' 'Btn' { Select-AkariPage 'Unattend Generator' }))
    [void]$b.Children.Add($r); [void]$c.Panel.Children.Add($b)
    [void]$stack.Children.Add($c.Card)

    # 4-6 zISO's options, by group; 6 also the image's own lists
    $p.Options = @{}
    $all = Get-AkariIsoOptions
    foreach ($g in $AkariIsoGroupTitles.Keys) {
        $c = New-AkariIsoCard $AkariIsoGroupTitles[$g]
        foreach ($o in @($all | Where-Object { $_.Group -eq $g })) {
            $cb = New-AkariIsoCheck $o.Name
            $cb.Tag = $o.Id
            $cb.ToolTip = $o.Description
            $cb.Add_Click({ Update-AkariIsoOptions })
            [void]$c.Panel.Children.Add($cb)
            $d = New-AkariText $o.Description 12 'Mu'; $d.Margin = [Windows.Thickness]::new(30, 0, 0, 6)
            [void]$c.Panel.Children.Add($d)
            $p.Options[$o.Id] = $cb
        }
        if ($g -eq 'Apps') {
            [void]$c.Panel.Children.Add((New-AkariUaFormLabel 'Apps and features in the image'))
            $r = New-AkariIsoRow
            [void]$r.Children.Add((New-AkariIsoButton 'Read the image''s apps' 'Btn' { Start-AkariIsoRead }))
            [void]$r.Children.Add((New-AkariIsoButton 'Select recommended' 'Btn' { Select-AkariIsoRecommended }))
            [void]$r.Children.Add((New-AkariIsoButton 'Clear' 'Btn' { foreach ($l in $script:IsoParts.Lists.Values) { foreach ($x in $l.Children) { $x.IsChecked = $false } } }))
            [void]$c.Panel.Children.Add($r)
            $p.ListNote = New-AkariText 'Open the ISO first: the lists come from the edition itself (mounting it takes a few minutes).' 13 'Mu'
            [void]$c.Panel.Children.Add($p.ListNote)
            $p.Lists = [ordered]@{}
            foreach ($k in 'Apps', 'Capabilities', 'Features', 'Packages') {
                $title = switch ($k) { 'Apps' { 'Store apps' } 'Capabilities' { 'Optional features' } 'Features' { 'Windows features' } 'Packages' { 'OS packages (advanced)' } }
                $h = New-AkariText $title 13; $h.FontWeight = 'SemiBold'; $h.Margin = [Windows.Thickness]::new(0, 10, 0, 4)
                $sv = [Windows.Controls.ScrollViewer]::new(); $sv.MaxHeight = 240; $sv.VerticalScrollBarVisibility = 'Auto'
                $lp = [Windows.Controls.StackPanel]::new(); $sv.Content = $lp
                $h.Visibility = 'Collapsed'; $sv.Visibility = 'Collapsed'
                $lp.Tag = @{ Head = $h; View = $sv }
                [void]$c.Panel.Children.Add($h); [void]$c.Panel.Children.Add($sv)
                $p.Lists[$k] = $lp
            }
        }
        [void]$stack.Children.Add($c.Card)
    }

    # 7 AkariOS
    $c = New-AkariIsoCard '7  AkariOS'
    $p.AkariOS = New-AkariIsoCheck 'Put AkariOS on the new Windows (C:\AkariOS, a Start menu and a desktop shortcut; nothing runs by itself)' $true
    [void]$c.Panel.Children.Add($p.AkariOS)
    [void]$stack.Children.Add($c.Card)

    # build
    $c = New-AkariIsoCard 'Build' 'Allow 20 to 40 minutes. Akari can''t be used meanwhile; the status bar shows each step.'
    $r = New-AkariIsoRow
    [void]$r.Children.Add((New-AkariIsoButton 'Build ISO' 'Accent' { Start-AkariIsoBuild }))
    $p.OpenOut = New-AkariIsoButton 'Open folder' 'Btn' { Open-AkariFolder $script:IsoParts.OutDir.Text }
    $p.OpenOut.Visibility = 'Collapsed'
    [void]$r.Children.Add($p.OpenOut)
    [void]$c.Panel.Children.Add($r)
    $p.Error = New-AkariText '' 13 'Bad'
    [void]$c.Panel.Children.Add($p.Error)
    $p.Result = New-AkariText '' 13 'Ok'
    [void]$c.Panel.Children.Add($p.Result)
    [void]$stack.Children.Add($c.Card)

    $script:IsoParts = $p
    $script:IsoView = $col
    $col
}

function Show-AkariIsoBuilder {
    $StepDots.Children.Clear()
    Set-AkariStepHeader 'ISO Builder' $AkariIsoSub
    $StepBack.Visibility = 'Visible'
    $StepNext.Visibility = 'Collapsed'
    $view = Get-AkariIsoView
    if ($view.Parent) { $view.Parent.Children.Remove($view) }
    $StepBody.Children.Clear()
    [void]$StepBody.Children.Add($view)
}

# options that rule each other out: the other one unticked and greyed
function Update-AkariIsoOptions {
    $o = $script:IsoParts.Options
    $picked = @($o.Keys | Where-Object { $o[$_].IsChecked })
    $blocked = Get-AkariIsoBlocked $picked (Get-AkariIsoOptions)
    foreach ($id in @($o.Keys)) {
        $off = $blocked -contains $id
        if ($off) { $o[$id].IsChecked = $false }
        $o[$id].IsEnabled = -not $off
    }
}

# ---- background work (Start-AkariJob; the Shell timer calls Complete-AkariIsoJob)

function Start-AkariIsoJob([string]$Kind, [string]$Code, [hashtable]$Shared, [string]$Label, [bool]$Lock = $true) {
    if ($script:Busy) { return $false }
    $Shared = [hashtable]::Synchronized($Shared)
    Set-Busy $true $Label $Lock
    Add-Log $Label
    $script:Job = Start-AkariJob $Code $script:Queue "$Root\Core" $Shared
    $script:Job.Label = $Label
    $script:Job.Kind = $Kind
    $true
}

function Start-AkariIsoOpen {
    $p = $script:IsoParts
    $p.Error.Text = ''
    $iso = $p.IsoPath.Text.Trim()
    if (-not $iso -or -not (Test-Path -LiteralPath $iso)) { $p.OpenNote.Text = 'Pick an ISO file first (or download one above).'; return }
    if (-not $p.OutDir.Text.Trim()) { $p.OpenNote.Text = 'Pick a work and output folder.'; return }
    $code = '$AkariShared.Result = try { Open-AkariIsoSource $AkariShared.Iso $AkariShared.Out } catch { @{ Error = $_.Exception.Message } }'
    [void](Start-AkariIsoJob 'IsoOpen' $code @{ Iso = $iso; Out = $p.OutDir.Text.Trim() } 'Copying the ISO and reading its editions')
}

function Start-AkariIsoRead {
    $p = $script:IsoParts
    $ed = Get-AkariComboTag $p.Edition
    if (-not $script:IsoState.Image -or -not $ed) { $p.ListNote.Text = 'Open the ISO and pick an edition first.'; return }
    $code = @'
try {
    $w = Get-AkariIsoWork $AkariShared.Out
    Mount-AkariIsoEdition $w $AkariShared.Image $AkariShared.Index
    $AkariShared.Apps = @(Get-AkariImageApps $w.Mount)
    $AkariShared.Capabilities = @(Get-AkariImageCapabilities $w.Mount)
    $AkariShared.Features = @(Get-AkariImageFeatures $w.Mount | Where-Object { $_.State -notmatch 'Disabled' })
    $AkariShared.Packages = @(Get-AkariImagePackages $w.Mount)
} catch { $AkariShared.Error = $_.Exception.Message }
'@
    [void](Start-AkariIsoJob 'IsoRead' $code @{ Out = $p.OutDir.Text.Trim(); Image = $script:IsoState.Image; Index = [int]$ed.Index } "Reading the apps in $($ed.Name)")
}

function Start-AkariIsoBuild {
    $p = $script:IsoParts
    $p.Error.Text = ''; $p.Result.Text = ''; $p.OpenOut.Visibility = 'Collapsed'
    $ed = Get-AkariComboTag $p.Edition
    if (-not $script:IsoState.Image -or -not $ed) { $p.Error.Text = 'Open the ISO and pick an edition first (step 1 and 2).'; return }
    $picked = @($p.Options.Keys | Where-Object { $p.Options[$_].IsChecked })
    $bad = Test-AkariIsoOptions $picked (Get-AkariIsoOptions)
    if ($bad) { $p.Error.Text = $bad; return }
    $answer = $null
    try {
        if ($p.AnsLocal.IsChecked) { $answer = New-AkariUnattend (Get-AkariIsoAnswerFields (Get-AkariUnattendStart) $p.User.Text $p.Password.Text ([bool]$p.SkipOobe.IsChecked)) }
        elseif ($p.AnsGen.IsChecked) {
            [void](Get-AkariUnattendView)
            if (-not (Confirm-AkariUnattendWipe)) { return }
            $answer = Get-AkariUnattendBytes
            if (-not $answer) { $p.Error.Text = 'The Unattend Generator''s choices have a problem: open it to see what.'; return }
        }
    } catch { $p.Error.Text = "The answer file could not be made: $($_.Exception.Message)"; return }
    $sel = { param($k) @(if ($p.Lists[$k]) { $p.Lists[$k].Children | Where-Object { $_.IsChecked } | ForEach-Object { [string]$_.Tag } }) }
    $choices = @{
        OutDir = $p.OutDir.Text.Trim(); Iso = $p.IsoPath.Text.Trim(); Image = $script:IsoState.Image; Index = [int]$ed.Index; Edition = $ed.Name
        Options = $picked; Apps = (& $sel 'Apps'); Capabilities = (& $sel 'Capabilities'); Features = (& $sel 'Features'); Packages = (& $sel 'Packages')
        AkariDir = $(if ($p.AkariOS.IsChecked) { $Root } else { '' }); Unattend = $answer
    }
    $name = Get-AkariIsoOutName $choices.Iso
    $n = $choices.Apps.Count + $choices.Capabilities.Count + $choices.Features.Count + $choices.Packages.Count
    $q = "Build $name from $($ed.Name)?`n`n$($picked.Count) options, $n apps and features to remove. It takes 20 to 40 minutes and Akari can't be used meanwhile."
    if (-not (Confirm-AkariDialog $q 'Build ISO' 'Cancel' 'Question' 'ISO Builder')) { return }
    $code = '$AkariShared.Result = Invoke-AkariIsoBuild $AkariShared.Choices'
    [void](Start-AkariIsoJob 'IsoBuild' $code @{ Choices = $choices } "Building $name")
}

function Start-AkariUupList([ValidateSet('Build', 'Editions')][string]$Step) {
    $p = $script:IsoParts
    $v = Get-AkariComboTag $p.UupVersion
    if (-not $v) { return }
    if ($Step -eq 'Build') {
        $p.UupLang.Items.Clear(); $p.UupEdition.Items.Clear()
        $code = '$b = Get-AkariUupBuild $AkariShared.Version; $AkariShared.Build = $b; if ($b.Ok) { $AkariShared.Langs = Get-AkariUupLanguages $b.Build.Id }'
        [void](Start-AkariIsoJob 'IsoUupList' $code @{ Step = 'Build'; Version = $v } "Asking UUP Dump for Windows 11 $v" $false)
    } else {
        $lang = Get-AkariComboTag $p.UupLang
        if (-not $lang -or -not $script:IsoState.Uup) { return }
        $code = '$AkariShared.Editions = Get-AkariUupEditions $AkariShared.Id $AkariShared.Lang'
        [void](Start-AkariIsoJob 'IsoUupList' $code @{ Step = 'Editions'; Id = $script:IsoState.Uup.Id; Lang = $lang.Code } 'Asking UUP Dump for its editions' $false)
    }
}

function Start-AkariUupDownload {
    $p = $script:IsoParts
    $v = Get-AkariComboTag $p.UupVersion; $lang = Get-AkariComboTag $p.UupLang; $t = Get-AkariComboTag $p.UupEdition
    if (-not $v -or -not $lang -or -not $t -or -not $script:IsoState.Uup) { $p.UupNote.Text = 'Pick a version, a language and an edition first.'; return }
    if (-not $p.OutDir.Text.Trim()) { $p.UupNote.Text = 'Pick a work and output folder below first.'; return }
    $q = "Download Windows 11 $v $($t.Label) ($($lang.Name)) with UUP Dump?`n`nIt downloads several GB from Microsoft and builds the ISO: allow 20 to 60 minutes. Akari can't be used meanwhile."
    if (-not (Confirm-AkariDialog $q 'Download' 'Cancel' 'Question' 'ISO Builder')) { return }
    $code = '$AkariShared.Result = Save-AkariUupIso $AkariShared.Version $AkariShared.Build $AkariShared.Lang $AkariShared.Target $AkariShared.Out'
    [void](Start-AkariIsoJob 'IsoUup' $code @{ Version = $v; Build = $script:IsoState.Uup; Lang = $lang.Code; Target = $t; Out = $p.OutDir.Text.Trim() } "Downloading Windows 11 $v $($t.Label)")
}

function Start-AkariMassgraveList {
    $script:IsoParts.MgNote.Text = 'Reading Massgrave''s list' + [char]0x2026
    [void](Start-AkariIsoJob 'IsoMassgrave' '$AkariShared.Result = Get-AkariMassgraveCatalogue' @{} 'Reading Massgrave''s list' $false)
}

function Update-AkariMassgraveLanguages {
    $prod = Get-AkariComboTag $script:IsoParts.MgProduct
    if (-not $prod) { return }
    Set-AkariComboItems $script:IsoParts.MgFile (Get-AkariMassgraveFiles $script:IsoState.Massgrave $prod) { param($i) $i.Language }
}

# opens the chosen file's page in the browser, then looks for it in Downloads every few seconds
function Open-AkariMassgraveFile {
    $f = Get-AkariComboTag $script:IsoParts.MgFile
    if (-not $f) { return }
    Open-AkariIsoLink $f.Url
    $script:IsoState.Waiting = $f.File
    $script:IsoParts.MgNote.Text = "Waiting for $($f.File) in Downloads$([char]0x2026) (download it in the browser that just opened)"
    if (-not $script:IsoWatch) {
        $script:IsoWatch = [Windows.Threading.DispatcherTimer]::new()
        $script:IsoWatch.Interval = [TimeSpan]::FromSeconds(3)
        $script:IsoWatch.Add_Tick({ Test-AkariMassgraveDownload })
    }
    $script:IsoWatch.Start()
}
function Test-AkariMassgraveDownload {
    if (-not $script:IsoState.Waiting) { if ($script:IsoWatch) { $script:IsoWatch.Stop() }; return }
    $hit = Find-AkariDownloadedIso $script:IsoState.Waiting
    if (-not $hit) { return }
    $script:IsoWatch.Stop()
    $script:IsoState.Waiting = ''
    Set-AkariIsoSource $hit "Downloaded: $hit"
}

# a downloaded ISO becomes the source: "An ISO file I have", ready to open
function Set-AkariIsoSource([string]$Path, [string]$Note) {
    $p = $script:IsoParts
    $p.IsoPath.Text = $Path
    $p.SrcFile.IsChecked = $true
    $p.OpenNote.Text = "$Note. Press Open ISO."
    Add-Log "ISO Builder: $Note"
}

function Select-AkariIsoRecommended {
    $l = $script:IsoParts.Lists.Apps
    if (-not $script:IsoState.Lists) { $script:IsoParts.ListNote.Text = 'Read the image''s apps first.'; return }
    $rec = Get-AkariIsoRecommendedApps $script:IsoState.Lists.Apps $script:Tweaks
    foreach ($x in $l.Children) { $x.IsChecked = ($rec -contains [string]$x.Tag) }
}

function Set-AkariIsoList([string]$Key, $Items, [scriptblock]$Label, [scriptblock]$Value) {
    $lp = $script:IsoParts.Lists[$Key]
    $lp.Children.Clear()
    foreach ($i in @($Items | Sort-Object { & $Label $_ })) {
        $cb = New-AkariIsoCheck (& $Label $i)
        $cb.Tag = & $Value $i
        [void]$lp.Children.Add($cb)
    }
    $lp.Tag.Head.Text = "$($lp.Tag.Head.Text -replace ' \(\d+\)$', '') ($($lp.Children.Count))"
    $lp.Tag.Head.Visibility = 'Visible'; $lp.Tag.View.Visibility = 'Visible'
}

function Complete-AkariIsoJob($Job) {
    $p = $script:IsoParts
    $s = $Job.Shared
    switch ($Job.Kind) {
        'IsoOpen' {
            $r = $s.Result
            if (-not $r -or $r.Error) { $p.OpenNote.Text = "Not opened: $(if ($r) { $r.Error } else { 'see the log' })"; return }
            $script:IsoState.Image = $r.Image
            $script:IsoState.Lists = $null
            foreach ($l in $p.Lists.Values) { $l.Children.Clear(); $l.Tag.Head.Visibility = 'Collapsed'; $l.Tag.View.Visibility = 'Collapsed' }
            Set-AkariComboItems $p.Edition @($r.Editions | Where-Object { $_.Supported }) { param($e) "$($e.Name) ($($e.Version))" }
            $p.Edition.IsEnabled = $true
            $p.OpenNote.Text = "Opened: $(@($r.Editions | Where-Object { $_.Supported }).Count) Windows 11 editions."
        }
        'IsoRead' {
            if ($s.Error) { $p.ListNote.Text = "Not read: $($s.Error)"; return }
            $script:IsoState.Lists = @{ Apps = $s.Apps }
            Set-AkariIsoList 'Apps' $s.Apps { param($i) $i.Name } { param($i) $i.Package }
            Set-AkariIsoList 'Capabilities' $s.Capabilities { param($i) $i.Name } { param($i) $i.Name }
            Set-AkariIsoList 'Features' $s.Features { param($i) $i.Name } { param($i) $i.Name }
            Set-AkariIsoList 'Packages' $s.Packages { param($i) $i.Name } { param($i) $i.Name }
            $p.ListNote.Text = 'Tick what to remove. Frameworks are left out of the list (apps need them).'
        }
        'IsoBuild' {
            $r = $s.Result
            if ($r -and $r.Ok) {
                $p.Result.Text = "ISO ready: $($r.Path)"
                $p.OpenOut.Visibility = 'Visible'
                $script:IsoState.Image = ''; $script:IsoState.Lists = $null; $p.Edition.Items.Clear(); $p.Edition.IsEnabled = $false
                $p.OpenNote.Text = 'The work folder was removed: open the ISO again to build another.'
                Show-AkariMessage "Your ISO is ready:`n`n$($r.Path)" 'Info' 'ISO Builder'
            } else {
                $p.Error.Text = "Not built: $(if ($r) { $r.Message } else { 'see the log' })"
            }
        }
        'IsoUupList' {
            if ($s.Step -eq 'Build') {
                if (-not $s.Build.Ok) { $p.UupNote.Text = $s.Build.Message; return }
                $script:IsoState.Uup = $s.Build.Build
                if (-not $s.Langs.Ok) { $p.UupNote.Text = $s.Langs.Message; return }
                $p.UupNote.Text = "$($s.Build.Build.Title). Pick a language and an edition."
                Set-AkariComboItems $p.UupLang $s.Langs.Items { param($l) $l.Name }
                $en = @($p.UupLang.Items | Where-Object { $_.Tag.Code -eq 'en-us' })[0]
                if ($en) { $p.UupLang.SelectedItem = $en }
                Start-AkariUupList 'Editions'
            } else {
                if (-not $s.Editions.Ok) { $p.UupNote.Text = $s.Editions.Message; return }
                Set-AkariComboItems $p.UupEdition $s.Editions.Items { param($t) $t.Label }
                $pro = @($p.UupEdition.Items | Where-Object { $_.Tag.Label -eq 'Pro' })[0]
                if ($pro) { $p.UupEdition.SelectedItem = $pro }
            }
        }
        'IsoUup' {
            $r = $s.Result
            if ($r -and $r.Ok) { Set-AkariIsoSource $r.Path "Downloaded: $($r.Path)" } else { $p.UupNote.Text = "Not downloaded: $(if ($r) { $r.Message } else { 'see the log' })" }
        }
        'IsoMassgrave' {
            $r = $s.Result
            if (-not $r.Ok) { $p.MgNote.Text = $r.Message; return }
            $script:IsoState.Massgrave = $r.Items
            Set-AkariComboItems $p.MgProduct (Get-AkariMassgraveProducts $r.Items) { param($x) $x }
            Update-AkariMassgraveLanguages
            $p.MgNote.Text = 'Pick an ISO and open its page. Massgrave''s links go to file hosts Akari can''t download from: your browser does, then Akari finds the file in Downloads.'
        }
    }
}

# closing while an ISO is being built or downloaded stops it: ask first (the next launch discards a half-built image)
if ($window) {
    $window.Add_Closing({
        param($s, $e)
        if ($script:Job -and "$($script:Job.Kind)" -in 'IsoBuild', 'IsoUup', 'IsoOpen', 'IsoRead') {
            if (-not (Confirm-AkariDialog "The ISO Builder is still working ($($script:Job.Label)). Closing stops it; a half-built image is discarded the next time Akari starts.`n`nClose anyway?" 'Close' 'Keep working' 'Warning' 'ISO Builder')) { $e.Cancel = $true }
        }
    })
}
