# ISO Builder (its tab and Home tile; plans docs/plans/2026-10-31-iso-builder.md, 2026-11-20-iso-builder-wizard.md): a
# custom Windows 11 ISO as a six-step wizard (the native app's IsoBuilderViewModel.Wizard.cs; after Tiny11 Builder's
# layout): Start (the modes), Windows image (a file, UUP Dump, Massgrave; the work folder; the edition, Pro picked),
# Components (Custom: the image's four lists), Build settings (the answer file, AkariOS), Review, Create ISO (the
# stages). Guided's footer: Back, and Next only once a step is complete (Get-AkariIsoFooter). Every slow step runs in
# the background job (Kind Iso*, Complete-AkariIsoJob); meanwhile the page's own controls are off and the rest of Akari
# stays usable (Optimize's changes and installs wait for it). Built once per session. Needs UI\Cards.ps1, UI\Pages.ps1,
# UI\Steps.ps1 (New-AkariStepsHeader), UI\Apps.ps1 (the card grid) and UI\Unattend.ps1 (the generator's page).

$AkariIsoStepNames = @('Start', 'Windows image', 'Components', 'Build settings', 'Review', 'Create ISO')
$AkariIsoLeads = @(
    'Make a Windows 11 ISO with what you don''t want left out and AkariOS on it. Your own Windows and your ISO are not changed.'
    'An ISO you have, or one downloaded here. It is copied to a work folder, so the ISO itself is not changed.'
    'What the new Windows leaves out. Items an image doesn''t have are skipped.'
    'How the new Windows is set up.'
    'Check the image, what goes and where the ISO is saved before building.'
    'Allow 20 to 40 minutes. Optimize''s changes and installs wait meanwhile.'
)
# the modes (Start and Components): only Custom until the modes batch (P7)
$AkariIsoModes = @(
    @{ Id = 'AkariOS'; Name = 'AkariOS'; Icon = 'zap'; Tag = 'Coming soon'; Available = $false; Text = 'The AkariOS setup out of the box: its apps removed, its Tweaks applied, AkariOS on it.' }
    @{ Id = 'Lite'; Name = 'Lite'; Icon = 'disc-3'; Tag = 'Coming soon'; Available = $false; Text = 'A smaller Windows that keeps Windows Update, Defender, recovery and the Store.' }
    @{ Id = 'Minimal'; Name = 'Minimal'; Icon = 'flask-conical'; Tag = 'Coming soon'; Available = $false; Text = 'The smallest image, for test VMs: no updates, recovery or Defender afterwards.' }
    @{ Id = 'Custom'; Name = 'Custom'; Icon = 'settings-2'; Tag = 'Choose yourself'; Available = $true; Text = 'Pick what to remove from the image''s own apps and features.' }
)
$AkariIsoListTitles = [ordered]@{ Apps = 'Store apps'; Capabilities = 'Optional features'; Features = 'Windows features'; Packages = 'OS packages (advanced)' }
# Step: the wizard's step; Mode: the picked mode; Stages: the Create ISO step's @{ Text; State; Elapsed; Clock; Row };
# ResultPath / BuildError: how the last build ended (BuildError also: why Review can't build)
$script:IsoState = @{ Image = ''; Editions = @(); Lists = $null; Massgrave = @(); Uup = $null; Waiting = ''
    Step = 0; Mode = 'Custom'; Stages = @(); ResultPath = ''; BuildError = '' }

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

# zISO's options another picked one rules out (Disable all updates turns the other two off). Not on the page any more;
# the native oracle (IsoOracleTests) still compares it until zISO goes (P9). Pure.
function Get-AkariIsoBlocked($Picked, $Options) {
    @(foreach ($o in @($Options)) { if (@($Picked) -contains $o.Id) { @($o.Excludes) | Where-Object { $_ } } }) | Sort-Object -Unique
}

# Massgrave's products in page order, and a product's languages. Pure.
function Get-AkariMassgraveProducts($Items) { @($Items | ForEach-Object { $_.Product } | Select-Object -Unique) }
function Get-AkariMassgraveFiles($Items, [string]$Product) { @($Items | Where-Object { $_.Product -eq $Product }) }

# the footer on step $Step: Next's text, why it waits ('' = it doesn't), whether Next and Back work. Next only once a
# step is complete; neither while the page's job runs; no Back from a finished build. Pure.
function Get-AkariIsoFooter([int]$Step, [bool]$HasEdition, [bool]$Busy, [bool]$HasResult, [bool]$HasError) {
    $next, $hint = switch ($Step) {
        0 { 'Start', '' }
        1 { 'Next', $(if ($HasEdition) { '' } else { 'Open an ISO and pick an edition first.' }) }
        2 { 'Next', '' }
        3 { 'Review', '' }
        4 { 'Build ISO', $(if ($HasEdition) { '' } else { 'Open an ISO first (Windows image).' }) }
        default { 'Build another', $(if ($HasResult -or $HasError) { '' } else { "Building$([char]0x2026)" }) }
    }
    @{ Next = $next; Hint = $hint; CanNext = (-not $Busy -and -not $hint); CanBack = ($Step -gt 0 -and -not $Busy -and -not ($Step -ge 5 -and $HasResult)) }
}

# the edition picked when an ISO opens: its first Pro, else the first. Pure.
function Get-AkariIsoEditionPick($Editions) {
    $i = 0
    foreach ($e in @($Editions)) { if ("$($e.Name)" -like '* Pro') { return $i }; $i++ }
    0
}

# the image picked so far, beside every step. Pure.
function Get-AkariIsoSummary($Edition) { if ($Edition) { "$($Edition.Name) $([char]0x00B7) $($Edition.Version)" } else { 'No image yet' } }

# the stages' states while the build reports step $Done of $Total (each step as it starts): the ones before it Done,
# it Running, the rest Waiting. Pure.
function Get-AkariIsoStageStates([int]$Done, [int]$Total, [int]$Count) {
    @(for ($i = 0; $i -lt $Count; $i++) { if ($i -lt $Done -or $Done -ge $Total) { 'Done' } elseif ($i -eq $Done) { 'Running' } else { 'Waiting' } })
}
# the build ended: the running stage Done or Failed, the waiting ones Done or Not run. Pure.
function Get-AkariIsoEndStates($States, [bool]$Ok) {
    @(foreach ($s in @($States)) {
        if ($s -eq 'Running') { if ($Ok) { 'Done' } else { 'Failed' } }
        elseif ($s -eq 'Waiting') { if ($Ok) { 'Done' } else { 'Not run' } }
        else { $s }
    })
}
# a stage's time: "3 min 4 s", "12 s". Pure.
function Get-AkariIsoElapsedText([TimeSpan]$Time) {
    if ($Time.TotalMinutes -ge 1) { return "$([int][Math]::Floor($Time.TotalMinutes)) min $($Time.Seconds) s" }
    "$([Math]::Max(0, [int][Math]::Floor($Time.TotalSeconds))) s"
}

# Review's cards: @{ Icon; Title; Lines }. $Info: Summary, Iso, ModeName, ModeIcon, Lists (@{ Title; Ticked; Count },
# the lists read), OutDir, Answer (None / Local / Generator), SkipOobe, User, AkariOS. Pure.
function Get-AkariIsoReviewCards([hashtable]$Info) {
    $lists = @(@($Info.Lists) | Where-Object { $_ } | ForEach-Object { "$($_.Title): $($_.Ticked) of $($_.Count)" })
    $removed = if ($lists.Count) { $lists -join "`n" } else { 'Nothing removed: the image''s lists weren''t read.' }
    $answer = switch ($Info.Answer) {
        'None' { 'None: setup asks everything as usual' }
        'Local' { if ($Info.SkipOobe) { "A local account ($($Info.User)), setup's questions skipped" } else { 'A local account, setup asks the rest' } }
        default { 'Install USB''s choices' }
    }
    $out = "$($Info.OutDir)".Trim()
    @(
        @{ Icon = 'disc-3'; Title = 'Windows image'; Lines = "$($Info.Summary)`n$("$($Info.Iso)".Trim())" }
        @{ Icon = $Info.ModeIcon; Title = $Info.ModeName; Lines = $removed }
        @{ Icon = 'folder'; Title = 'Output and workspace'; Lines = "ISO`n$([IO.Path]::Combine($out, (Get-AkariIsoOutName "$($Info.Iso)".Trim())))`n`nWork folder`n$([IO.Path]::Combine($out, 'AkariIso'))" }
        @{ Icon = 'settings'; Title = 'Installation options'; Lines = "Answer file: $answer`nAkariOS on the new Windows: $(if ($Info.AkariOS) { 'Yes' } else { 'No' })" }
    )
}

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
# a card with a heading: @{ Card; Panel }
function New-AkariIsoCard([string]$Title, [string]$Sub = '') {
    $card = [Windows.Controls.Border]::new()
    $card.SetResourceReference([Windows.FrameworkElement]::StyleProperty, 'SettingCard')
    $card.Margin = [Windows.Thickness]::new(0, 0, 0, 8)
    $card.Padding = [Windows.Thickness]::new(16)
    $sp = [Windows.Controls.StackPanel]::new()
    $h = New-AkariText $Title 14 'Tx' 'SemiBold'
    $h.Margin = [Windows.Thickness]::new(0, 0, 0, 2)
    [void]$sp.Children.Add($h)
    if ($Sub) { $s = New-AkariText $Sub 12 'Mu'; $s.Margin = [Windows.Thickness]::new(0, 0, 0, 8); [void]$sp.Children.Add($s) }
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

# the build modes as tiles in a card grid (Start and Components each have their own); picked = the accent border
function New-AkariIsoModes {
    $g = New-AkariCardGrid 200
    foreach ($m in $AkariIsoModes) {
        $t = New-AkariTile $m.Icon $m.Name $m.Text $m.Tag { param($s, $e) Select-AkariIsoMode ([string]$s.Tag) }
        $t.Tag = $m.Id
        $t.IsEnabled = $m.Available
        $script:IsoParts.ModeTiles.Add($t)
        Add-AkariGridCard $g $t
    }
    Update-AkariCardGrid $g
    $g
}
function Update-AkariIsoModeLook {
    foreach ($t in $script:IsoParts.ModeTiles) {
        if ($t.Tag -eq $script:IsoState.Mode) { $t.SetResourceReference([Windows.Controls.Control]::BorderBrushProperty, 'Acc') }
        else { $t.ClearValue([Windows.Controls.Control]::BorderBrushProperty) }
    }
}

# ---- the page

function Get-AkariIsoView {
    if ($script:IsoParts) { return $script:IsoParts }
    $p = @{ ModeTiles = [Collections.Generic.List[object]]::new(); Steps = @{} }
    $script:IsoParts = $p

    # 1 Start: the modes
    $s = [Windows.Controls.StackPanel]::new()
    [void]$s.Children.Add((New-AkariSection 'Build modes' -First))
    [void]$s.Children.Add((New-AkariIsoModes))
    $n = New-AkariText 'Windows 11 only. Try a new ISO in a virtual machine first.' 12 'Mu'; $n.Margin = [Windows.Thickness]::new(0, 12, 0, 0)
    [void]$s.Children.Add($n)
    $p.Steps[0] = $s

    # 2 Windows image: the ISO, the work folder, the edition
    $s = [Windows.Controls.StackPanel]::new()
    $c = New-AkariIsoCard 'Windows 11 ISO'
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
    $p.OpenNote = New-AkariText '' 13 'Mu'; $p.OpenNote.VerticalAlignment = 'Center'
    [void]$r.Children.Add($p.OpenNote)
    [void]$c.Panel.Children.Add($r)
    [void]$s.Children.Add($c.Card)
    $c = New-AkariIsoCard 'Edition' 'The ISO keeps only this edition. Pro is picked when the ISO has it.'
    $p.Edition = New-AkariIsoCombo 340
    $p.Edition.HorizontalAlignment = 'Left'
    $p.Edition.IsEnabled = $false
    $p.Edition.Add_SelectionChanged({ Update-AkariIsoWizard })
    [void]$c.Panel.Children.Add($p.Edition)
    [void]$s.Children.Add($c.Card)
    $p.Steps[1] = $s

    # 3 Components: the mode again, then Custom's lists (the image's own)
    $s = [Windows.Controls.StackPanel]::new()
    $m = New-AkariIsoModes; $m.Margin = [Windows.Thickness]::new(-4, -4, -4, 8)
    [void]$s.Children.Add($m)
    $c = New-AkariIsoCard 'Apps and features in the image' 'Tick what to remove. Frameworks are left out of the list (apps need them).'
    $r = New-AkariIsoRow
    [void]$r.Children.Add((New-AkariIsoButton 'Read the image''s apps again' 'Btn' { Start-AkariIsoRead }))
    [void]$r.Children.Add((New-AkariIsoButton 'Select recommended' 'Btn' { Select-AkariIsoRecommended }))
    [void]$r.Children.Add((New-AkariIsoButton 'Clear' 'Btn' { foreach ($l in $script:IsoParts.Lists.Values) { foreach ($x in $l.Children) { $x.IsChecked = $false } } }))
    [void]$c.Panel.Children.Add($r)
    $p.ListNote = New-AkariText 'The lists come from the edition itself: reading them mounts it, which takes a few minutes.' 13 'Mu'
    [void]$c.Panel.Children.Add($p.ListNote)
    $p.Lists = [ordered]@{}
    foreach ($k in $AkariIsoListTitles.Keys) {
        $h = New-AkariText $AkariIsoListTitles[$k] 13; $h.FontWeight = 'SemiBold'; $h.Margin = [Windows.Thickness]::new(0, 10, 0, 4)
        $sv = [Windows.Controls.ScrollViewer]::new(); $sv.MaxHeight = 240; $sv.VerticalScrollBarVisibility = 'Auto'
        $lp = [Windows.Controls.StackPanel]::new(); $sv.Content = $lp
        $h.Visibility = 'Collapsed'; $sv.Visibility = 'Collapsed'
        $lp.Tag = @{ Head = $h; View = $sv; Title = $AkariIsoListTitles[$k] }
        [void]$c.Panel.Children.Add($h); [void]$c.Panel.Children.Add($sv)
        $p.Lists[$k] = $lp
    }
    [void]$s.Children.Add($c.Card)
    $p.Steps[2] = $s

    # 4 Build settings: the answer file, AkariOS
    $s = [Windows.Controls.StackPanel]::new()
    $c = New-AkariIsoCard 'Answer file' 'autounattend.xml at the root of the ISO: Windows setup reads it by itself.'
    $p.AnsNone = New-AkariIsoRadio 'iso-ans' 'None: setup asks everything as usual'
    $p.AnsLocal = New-AkariIsoRadio 'iso-ans' 'A local account (this PC''s language, keyboard and time zone; setup still asks for the disk)'
    $p.AnsGen = New-AkariIsoRadio 'iso-ans' 'Install USB''s choices'
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
    [void]$r.Children.Add((New-AkariIsoButton 'Open Install USB' 'Btn' { Select-AkariPage 'Install USB' }))
    [void]$b.Children.Add($r); [void]$c.Panel.Children.Add($b)
    [void]$s.Children.Add($c.Card)
    $c = New-AkariIsoCard 'AkariOS'
    $p.AkariOS = New-AkariIsoCheck 'Put AkariOS on the new Windows (C:\AkariOS, a Start menu and a desktop shortcut; nothing runs by itself)' $true
    [void]$c.Panel.Children.Add($p.AkariOS)
    [void]$s.Children.Add($c.Card)
    $p.Steps[3] = $s

    Update-AkariIsoModeLook
    $p
}

# the edition picked (an opened ISO's), else $null
function Get-AkariIsoEdition {
    if (-not $script:IsoState.Image -or -not $script:IsoParts) { return $null }
    Get-AkariComboTag $script:IsoParts.Edition
}
# the page's own job runs (an ISO, a list, a download, the build): its controls are off meanwhile
function Test-AkariIsoBusy { [bool]($script:Job -and "$($script:Job.Kind)" -like 'Iso*') }

function Show-AkariIsoBuilder {
    $st = $script:IsoState
    $p = Get-AkariIsoView
    if ($st.Step -eq 0) { Set-AkariHeader @('ISO Builder') } else { Set-AkariHeader @(@('ISO Builder', 'ISO Builder'), $AkariIsoStepNames[$st.Step]) }
    [void]$StepBody.Children.Add((New-AkariLead $AkariIsoLeads[$st.Step]))
    $h = New-AkariStepsHeader $st.Step $AkariIsoStepNames
    $h.Margin = [Windows.Thickness]::new(0, -8, 0, 12)
    [void]$StepBody.Children.Add($h)
    $sum = New-AkariIconText 'disc-3' (Get-AkariIsoSummary (Get-AkariIsoEdition)) 'Mu'
    $sum.Margin = [Windows.Thickness]::new(0, 0, 0, 16)
    $p.SummaryText = $sum.Children[1]
    [void]$StepBody.Children.Add($sum)
    $panel = switch ($st.Step) {
        4 { New-AkariIsoReview }
        5 { New-AkariIsoBuildView }
        default { $p.Steps[$st.Step] }
    }
    if ($panel.Parent) { $panel.Parent.Children.Remove($panel) }
    $col = [Windows.Controls.Grid]::new()
    $cd = [Windows.Controls.ColumnDefinition]::new(); $cd.Width = [Windows.GridLength]::new(1, 'Star'); $cd.MaxWidth = 860
    [void]$col.ColumnDefinitions.Add($cd)
    [void]$col.Children.Add($panel)
    $p.Current = $panel
    [void]$StepBody.Children.Add($col)
    Update-AkariIsoModeLook
    Set-AkariFooter $true
    Update-AkariIsoWizard
}

# the footer (Guided's: "Step n of 6 . Name", the bar, Back, Next) and the page's controls, from the step and the job
function Update-AkariIsoWizard {
    if ($script:Cat -ne 'ISO Builder' -or -not $script:IsoParts) { return }
    $st = $script:IsoState
    $p = $script:IsoParts
    $busy = Test-AkariIsoBusy
    $ed = Get-AkariIsoEdition
    if ($p.SummaryText) { $p.SummaryText.Text = Get-AkariIsoSummary $ed }
    $f = Get-AkariIsoFooter $st.Step ([bool]$ed) $busy ([bool]$st.ResultPath) ([bool]$st.BuildError)
    $StepLabel.Text = "Step $($st.Step + 1) of $($AkariIsoStepNames.Count) $([char]0x00B7) $($AkariIsoStepNames[$st.Step])" + $(if ($f.Hint) { "`n$($f.Hint)" } else { '' })
    Start-AkariMotion $StepFill Fill $null (($st.Step + 1) / $AkariIsoStepNames.Count) -Speed Slow
    $StepBack.Content = 'Back'; $StepBack.IsEnabled = $f.CanBack
    $StepNext.Content = $f.Next; $StepNext.IsEnabled = $f.CanNext
    if ($p.Current -and $st.Step -lt 5) { $p.Current.IsEnabled = -not $busy }
}

# the footer's Next: the next step (Components reads the image the first time, in Custom); Review builds; a finished
# build starts again
function Step-AkariIsoNext {
    $st = $script:IsoState
    $f = Get-AkariIsoFooter $st.Step ([bool](Get-AkariIsoEdition)) (Test-AkariIsoBusy) ([bool]$st.ResultPath) ([bool]$st.BuildError)
    if (-not $f.CanNext) { return }
    if ($st.Step -eq 4) { Start-AkariIsoBuild; return }
    if ($st.Step -ge 5) { Reset-AkariIsoBuild; return }
    $st.Step++
    Show-Page
    if ($st.Step -eq 2 -and $st.Mode -eq 'Custom' -and -not $st.Lists -and -not $script:Busy) { Start-AkariIsoRead }
}
function Step-AkariIsoBack {
    $st = $script:IsoState
    $f = Get-AkariIsoFooter $st.Step ([bool](Get-AkariIsoEdition)) (Test-AkariIsoBusy) ([bool]$st.ResultPath) ([bool]$st.BuildError)
    if (-not $f.CanBack) { return }
    $st.Step = if ($st.Step -ge 5) { 4 } else { $st.Step - 1 }
    Show-Page
}
# the crumb "ISO Builder": back to Start, the picks kept (a finished build cleared first); not while a job runs
function Open-AkariIsoStart {
    if (Test-AkariIsoBusy) { return }
    if ($script:IsoState.Step -ge 5) { Reset-AkariIsoBuild; return }
    $script:IsoState.Step = 0
    Show-Page
}
# a mode's tile: picked; on Start, also the next step
function Select-AkariIsoMode([string]$Id) {
    $m = @($AkariIsoModes | Where-Object { $_.Id -eq $Id })[0]
    if (-not $m -or -not $m.Available) { return }
    $script:IsoState.Mode = $Id
    Update-AkariIsoModeLook
    if ($script:IsoState.Step -eq 0) { $script:IsoState.Step = 1; Show-Page }
}
# Build another: back to Start, the mode kept
function Reset-AkariIsoBuild {
    $st = $script:IsoState
    $st.Stages = @(); $st.ResultPath = ''; $st.BuildError = ''; $st.Step = 0
    Show-Page
}

# Review: an InfoBar when it can't build, then the cards
function New-AkariIsoReview {
    $st = $script:IsoState
    $p = $script:IsoParts
    $sp = [Windows.Controls.StackPanel]::new()
    if ($st.BuildError) { [void]$sp.Children.Add((New-AkariInfoBar 'Bad' 'Can''t build yet' $st.BuildError).Bar) }
    $m = @($AkariIsoModes | Where-Object { $_.Id -eq $st.Mode })[0]
    $lists = @(foreach ($lp in $p.Lists.Values) {
        if ($lp.Tag.View.Visibility -eq 'Visible') { @{ Title = $lp.Tag.Title; Ticked = @($lp.Children | Where-Object { $_.IsChecked }).Count; Count = $lp.Children.Count } }
    })
    $answer = if ($p.AnsNone.IsChecked) { 'None' } elseif ($p.AnsLocal.IsChecked) { 'Local' } else { 'Generator' }
    $cards = Get-AkariIsoReviewCards @{ Summary = (Get-AkariIsoSummary (Get-AkariIsoEdition)); Iso = $p.IsoPath.Text; ModeName = $m.Name; ModeIcon = $m.Icon
        Lists = $lists; OutDir = $p.OutDir.Text; Answer = $answer; SkipOobe = [bool]$p.SkipOobe.IsChecked; User = $p.User.Text.Trim(); AkariOS = [bool]$p.AkariOS.IsChecked }
    $g = New-AkariCardGrid 320
    foreach ($c in $cards) {
        $b = [Windows.Controls.Border]::new()
        $b.SetResourceReference([Windows.FrameworkElement]::StyleProperty, 'SettingCard')
        $b.Padding = [Windows.Thickness]::new(20, 16, 20, 16); $b.Margin = [Windows.Thickness]::new(4); $b.MinHeight = 170
        $v = [Windows.Controls.StackPanel]::new()
        $ic = New-AkariIcon $c.Icon 24 'AccText'; $ic.HorizontalAlignment = 'Left'; $ic.Margin = [Windows.Thickness]::new(0, 0, 0, 8)
        [void]$v.Children.Add($ic)
        $t = New-AkariText $c.Title 20; $t.Margin = [Windows.Thickness]::new(0, 0, 0, 8)
        [void]$v.Children.Add($t)
        [void]$v.Children.Add((New-AkariText $c.Lines 12 'Mu'))
        $b.Child = $v
        Add-AkariGridCard $g $b
    }
    Update-AkariCardGrid $g
    [void]$sp.Children.Add($g)
    $sp
}

# Create ISO: how it ended (an InfoBar), then a row per stage (its state, text, time)
function New-AkariIsoBuildView {
    $st = $script:IsoState
    $sp = [Windows.Controls.StackPanel]::new()
    if ($st.ResultPath) {
        $open = New-AkariBarButton 'Open folder' { Open-AkariFolder ([IO.Path]::GetDirectoryName($script:IsoState.ResultPath)) }
        [void]$sp.Children.Add((New-AkariInfoBar 'Ok' 'Your ISO is ready' $st.ResultPath @($open)).Bar)
    }
    if ($st.BuildError) { [void]$sp.Children.Add((New-AkariInfoBar 'Bad' 'Not built' $st.BuildError).Bar) }
    $card = [Windows.Controls.Border]::new()
    $card.SetResourceReference([Windows.FrameworkElement]::StyleProperty, 'SettingCard')
    $card.Padding = [Windows.Thickness]::new(8, 6, 8, 6)
    $rows = [Windows.Controls.StackPanel]::new()
    foreach ($s in @($st.Stages)) {
        $s.Row = New-AkariIsoStageRow $s
        [void]$rows.Children.Add($s.Row)
    }
    $card.Child = $rows
    [void]$sp.Children.Add($card)
    $sp
}
function New-AkariIsoStageRow($Stage) {
    $dp = [Windows.Controls.DockPanel]::new()
    $dp.MinHeight = 32; $dp.Margin = [Windows.Thickness]::new(8, 2, 8, 2)
    $ic = New-AkariIcon 'circle-minus' 16 'Mu'
    $ic.Margin = [Windows.Thickness]::new(0, 0, 12, 0); $ic.VerticalAlignment = 'Center'
    [Windows.Controls.DockPanel]::SetDock($ic, 'Left'); [void]$dp.Children.Add($ic)
    $right = New-AkariText '' 12 'Mu'; $right.VerticalAlignment = 'Center'; $right.TextWrapping = 'NoWrap'
    [Windows.Controls.DockPanel]::SetDock($right, 'Right'); [void]$dp.Children.Add($right)
    $t = New-AkariText $Stage.Text 14; $t.VerticalAlignment = 'Center'
    [void]$dp.Children.Add($t)
    $dp.Tag = @{ Icon = $ic; Right = $right }
    Set-AkariIsoStageLook $dp $Stage
    $dp
}
function Set-AkariIsoStageLook($Row, $Stage) {
    if (-not $Row) { return }
    $icon, $brush = switch ($Stage.State) {
        'Running' { 'refresh-cw', 'AccText' }
        'Done' { 'circle-check', 'Ok' }
        'Failed' { 'circle-x', 'Bad' }
        'Not run' { 'circle-slash', 'Mu' }
        default { 'circle-minus', 'Mu' }
    }
    Set-AkariIcon $Row.Tag.Icon $icon
    $Row.Tag.Icon.Child.SetResourceReference([Windows.Shapes.Shape]::FillProperty, $brush)
    $Row.Tag.Right.Text = "$($Stage.State)$(if ($Stage.Elapsed) { "  $($Stage.Elapsed)" })"
}

# the build's progress (the Shell timer, Done / Total from Set-AkariProgress): each stage's state, its time once done
function Update-AkariIsoStages($Shared) {
    $stages = @($script:IsoState.Stages)
    if (-not $Shared -or -not $Shared.Total -or -not $stages.Count) { return }
    $states = Get-AkariIsoStageStates ([int]$Shared.Done) ([int]$Shared.Total) $stages.Count
    for ($i = 0; $i -lt $stages.Count; $i++) { Set-AkariIsoStageState $stages[$i] $states[$i] }
}
function Set-AkariIsoStageState($Stage, [string]$State) {
    if ($Stage.State -eq $State) { return }
    if ($State -eq 'Running') { $Stage.Clock = [Diagnostics.Stopwatch]::StartNew() }
    elseif ($Stage.Clock -and $Stage.State -eq 'Running') { $Stage.Elapsed = Get-AkariIsoElapsedText $Stage.Clock.Elapsed }
    $Stage.State = $State
    Set-AkariIsoStageLook $Stage.Row $Stage
}

# ---- background work (Start-AkariJob; the Shell timer calls Complete-AkariIsoJob). One job at a time: another one
# running refuses it, saying so. The page stays usable (no lock): its own controls are off (Update-AkariIsoWizard).

function Start-AkariIsoJob([string]$Kind, [string]$Code, [hashtable]$Shared, [string]$Label) {
    if ($script:Busy) { Show-AkariMessage "$($script:BusyLabel) is still running. Try again when it is done." 'Info' 'ISO Builder'; return $false }
    $Shared = [hashtable]::Synchronized($Shared)
    Set-Busy $true $Label $false
    Add-Log $Label
    $script:Job = Start-AkariJob $Code $script:Queue "$Root\Core" $Shared
    $script:Job.Label = $Label
    $script:Job.Kind = $Kind
    Update-AkariIsoWizard
    $true
}

function Start-AkariIsoOpen {
    $p = $script:IsoParts
    $iso = $p.IsoPath.Text.Trim()
    if (-not $iso -or -not (Test-Path -LiteralPath $iso)) { $p.OpenNote.Text = 'Pick an ISO file first (or download one above).'; return }
    if (-not $p.OutDir.Text.Trim()) { $p.OpenNote.Text = 'Pick a work and output folder.'; return }
    $code = '$AkariShared.Result = try { Open-AkariIsoSource $AkariShared.Iso $AkariShared.Out } catch { @{ Error = $_.Exception.Message } }'
    [void](Start-AkariIsoJob 'IsoOpen' $code @{ Iso = $iso; Out = $p.OutDir.Text.Trim() } 'Copying the ISO and reading its editions')
}

function Start-AkariIsoRead {
    $p = $script:IsoParts
    $ed = Get-AkariIsoEdition
    if (-not $ed) { $p.ListNote.Text = 'Open the ISO and pick an edition first (Windows image).'; return }
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
    if (Start-AkariIsoJob 'IsoRead' $code @{ Out = $p.OutDir.Text.Trim(); Image = $script:IsoState.Image; Index = [int]$ed.Index } "Reading the apps in $($ed.Name)") {
        $p.ListNote.Text = "Reading the apps in $($ed.Name)$([char]0x2026) (mounting it takes a few minutes)"
    }
}

# Review's Build ISO: the answer file, one question, then the build in the background and the Create ISO step
function Start-AkariIsoBuild {
    $st = $script:IsoState
    $p = $script:IsoParts
    $st.BuildError = ''
    $ed = Get-AkariIsoEdition
    if (-not $ed) { $st.BuildError = 'Open the ISO and pick an edition first (Windows image).'; Show-Page; return }
    $answer = $null
    try {
        if ($p.AnsLocal.IsChecked) { $answer = New-AkariUnattend (Get-AkariIsoAnswerFields (Get-AkariUnattendStart) $p.User.Text $p.Password.Text ([bool]$p.SkipOobe.IsChecked)) }
        elseif ($p.AnsGen.IsChecked) {
            [void](Get-AkariUnattendView)
            if (-not (Confirm-AkariUnattendWipe)) { return }
            $answer = Get-AkariUnattendBytes
            if (-not $answer) { $st.BuildError = 'Install USB''s choices have a problem: open it to see what.'; Show-Page; return }
        }
    } catch { $st.BuildError = "The answer file could not be made: $($_.Exception.Message)"; Show-Page; return }
    $sel = { param($k) @(if ($p.Lists[$k]) { $p.Lists[$k].Children | Where-Object { $_.IsChecked } | ForEach-Object { [string]$_.Tag } }) }
    $choices = @{
        OutDir = $p.OutDir.Text.Trim(); Iso = $p.IsoPath.Text.Trim(); Image = $st.Image; Index = [int]$ed.Index; Edition = $ed.Name
        Options = @(); Apps = (& $sel 'Apps'); Capabilities = (& $sel 'Capabilities'); Features = (& $sel 'Features'); Packages = (& $sel 'Packages')
        AkariDir = $(if ($p.AkariOS.IsChecked) { $Root } else { '' }); Unattend = $answer
    }
    $name = Get-AkariIsoOutName $choices.Iso
    $n = $choices.Apps.Count + $choices.Capabilities.Count + $choices.Features.Count + $choices.Packages.Count
    $q = "Build $name from $($ed.Name)?`n`n$n apps and features to remove. It takes 20 to 40 minutes; Optimize's changes and installs wait meanwhile."
    if (-not (Confirm-AkariDialog $q 'Build ISO' 'Cancel' 'Question' 'ISO Builder')) { return }
    $plan = New-AkariIsoPlan $choices @()
    $code = '$AkariShared.Result = Invoke-AkariIsoBuild $AkariShared.Choices'
    if (-not (Start-AkariIsoJob 'IsoBuild' $code @{ Choices = $choices } "Building $name")) { return }
    $st.Stages = @(foreach ($s in $plan) { @{ Text = $s.Text; State = 'Waiting'; Elapsed = ''; Clock = $null; Row = $null } })
    $st.ResultPath = ''
    $st.Step = 5
    Show-Page
}

function Start-AkariUupList([ValidateSet('Build', 'Editions')][string]$Step) {
    $p = $script:IsoParts
    $v = Get-AkariComboTag $p.UupVersion
    if (-not $v) { return }
    if ($Step -eq 'Build') {
        $p.UupLang.Items.Clear(); $p.UupEdition.Items.Clear()
        $code = '$b = Get-AkariUupBuild $AkariShared.Version; $AkariShared.Build = $b; if ($b.Ok) { $AkariShared.Langs = Get-AkariUupLanguages $b.Build.Id }'
        [void](Start-AkariIsoJob 'IsoUupList' $code @{ Step = 'Build'; Version = $v } "Asking UUP Dump for Windows 11 $v")
    } else {
        $lang = Get-AkariComboTag $p.UupLang
        if (-not $lang -or -not $script:IsoState.Uup) { return }
        $code = '$AkariShared.Editions = Get-AkariUupEditions $AkariShared.Id $AkariShared.Lang'
        [void](Start-AkariIsoJob 'IsoUupList' $code @{ Step = 'Editions'; Id = $script:IsoState.Uup.Id; Lang = $lang.Code } 'Asking UUP Dump for its editions')
    }
}

function Start-AkariUupDownload {
    $p = $script:IsoParts
    $v = Get-AkariComboTag $p.UupVersion; $lang = Get-AkariComboTag $p.UupLang; $t = Get-AkariComboTag $p.UupEdition
    if (-not $v -or -not $lang -or -not $t -or -not $script:IsoState.Uup) { $p.UupNote.Text = 'Pick a version, a language and an edition first.'; return }
    if (-not $p.OutDir.Text.Trim()) { $p.UupNote.Text = 'Pick a work and output folder below first.'; return }
    $q = "Download Windows 11 $v $($t.Label) ($($lang.Name)) with UUP Dump?`n`nIt downloads several GB from Microsoft and builds the ISO: allow 20 to 60 minutes. Optimize's changes and installs wait meanwhile."
    if (-not (Confirm-AkariDialog $q 'Download' 'Cancel' 'Question' 'ISO Builder')) { return }
    $code = '$AkariShared.Result = Save-AkariUupIso $AkariShared.Version $AkariShared.Build $AkariShared.Lang $AkariShared.Target $AkariShared.Out'
    [void](Start-AkariIsoJob 'IsoUup' $code @{ Version = $v; Build = $script:IsoState.Uup; Lang = $lang.Code; Target = $t; Out = $p.OutDir.Text.Trim() } "Downloading Windows 11 $v $($t.Label)")
}

function Start-AkariMassgraveList {
    $script:IsoParts.MgNote.Text = 'Reading Massgrave''s list' + [char]0x2026
    [void](Start-AkariIsoJob 'IsoMassgrave' '$AkariShared.Result = Get-AkariMassgraveCatalogue' @{} 'Reading Massgrave''s list')
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
    $lp.Tag.Head.Text = "$($lp.Tag.Title) ($($lp.Children.Count))"
    $lp.Tag.Head.Visibility = 'Visible'; $lp.Tag.View.Visibility = 'Visible'
}

function Complete-AkariIsoJob($Job) {
    $p = $script:IsoParts
    $st = $script:IsoState
    $s = $Job.Shared
    switch ($Job.Kind) {
        'IsoOpen' {
            $r = $s.Result
            if (-not $r -or $r.Error) { $p.OpenNote.Text = "Not opened: $(if ($r) { $r.Error } else { 'see the log' })"; return }
            $st.Image = $r.Image
            $st.Lists = $null
            foreach ($l in $p.Lists.Values) { $l.Children.Clear(); $l.Tag.Head.Visibility = 'Collapsed'; $l.Tag.View.Visibility = 'Collapsed' }
            $sup = @($r.Editions | Where-Object { $_.Supported })
            Set-AkariComboItems $p.Edition $sup { param($e) "$($e.Name) ($($e.Version))" }
            if ($sup.Count) { $p.Edition.SelectedIndex = Get-AkariIsoEditionPick $sup }
            $p.Edition.IsEnabled = $true
            $p.OpenNote.Text = "Opened: $($sup.Count) Windows 11 editions."
        }
        'IsoRead' {
            if ($s.Error) { $p.ListNote.Text = "Not read: $($s.Error)"; return }
            $st.Lists = @{ Apps = $s.Apps }
            Set-AkariIsoList 'Apps' $s.Apps { param($i) $i.Name } { param($i) $i.Package }
            Set-AkariIsoList 'Capabilities' $s.Capabilities { param($i) $i.Name } { param($i) $i.Name }
            Set-AkariIsoList 'Features' $s.Features { param($i) $i.Name } { param($i) $i.Name }
            Set-AkariIsoList 'Packages' $s.Packages { param($i) $i.Name } { param($i) $i.Name }
            $p.ListNote.Text = 'Tick what to remove. Frameworks are left out of the list (apps need them).'
        }
        'IsoBuild' {
            $r = $s.Result
            $ok = [bool]($r -and $r.Ok)
            # the last step the build reached, then how it ended
            Update-AkariIsoStages $s
            $stages = @($st.Stages)
            $end = Get-AkariIsoEndStates @($stages | ForEach-Object { $_.State }) $ok
            for ($i = 0; $i -lt $stages.Count; $i++) { Set-AkariIsoStageState $stages[$i] $end[$i] }
            if ($ok) {
                $st.ResultPath = $r.Path
                $st.Image = ''; $st.Lists = $null; $p.Edition.Items.Clear(); $p.Edition.IsEnabled = $false
                $p.OpenNote.Text = 'The work folder was removed: open the ISO again to build another.'
                Show-AkariToast 'Your ISO is ready' $r.Path
            } else {
                $st.BuildError = "$(if ($r) { $r.Message } else { 'see the log' })"
                Show-AkariToast 'The ISO was not built' $st.BuildError
            }
        }
        'IsoUupList' {
            if ($s.Step -eq 'Build') {
                if (-not $s.Build.Ok) { $p.UupNote.Text = $s.Build.Message; return }
                $st.Uup = $s.Build.Build
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
            $st.Massgrave = $r.Items
            Set-AkariComboItems $p.MgProduct (Get-AkariMassgraveProducts $r.Items) { param($x) $x }
            Update-AkariMassgraveLanguages
            $p.MgNote.Text = 'Pick an ISO and open its page. Massgrave''s links go to file hosts Akari can''t download from: your browser does, then Akari finds the file in Downloads.'
        }
    }
}

# closing while an ISO job runs: the Shell's one closing question names it (Get-AkariRunningLines; the next launch
# discards a half-built image)
