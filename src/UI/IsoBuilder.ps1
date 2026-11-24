# ISO Builder (its tab and Home tile; plans docs/plans/2026-10-31-iso-builder.md, 2026-11-20-iso-builder-wizard.md): a
# custom Windows 11 ISO as a six-step wizard (the native app's IsoBuilderViewModel.Wizard.cs; after Tiny11 Builder's
# layout): Start (the modes), Windows image (a file, Microsoft, UUP Dump, Massgrave; the work folder; the edition, Pro picked),
# Components (the removal groups; Custom: the image's four lists), Build settings (the answer file, AkariOS, the first
# sign-in, the build settings), Review, Create ISO (the
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
# the modes (Start and Components): the data's (Core\Iso\Wizard\Modes: AkariOS, Lite, Minimal), then Custom. Data =
# the mode's file (Groups, Settings, AkariOS); Minimal (it prunes the component store) waits for batch P9.
$AkariIsoModeIcons = @{ AkariOS = 'zap'; Lite = 'disc-3'; Minimal = 'flask-conical'; Custom = 'settings-2' }
$AkariIsoModes = @(
    if (Get-Command Get-AkariIsoModes -ErrorAction SilentlyContinue) {
        foreach ($m in @(Get-AkariIsoModes)) {
            $soon = [bool]$m.Minimal
            @{ Id = $m.Id; Name = $m.Name; Icon = $AkariIsoModeIcons[$m.Id]; Tag = $(if ($soon) { 'Coming soon' } else { $m.Tag }); Available = -not $soon; Text = $m.Description; Data = $m }
        }
    }
    @{ Id = 'Custom'; Name = 'Custom'; Icon = 'settings-2'; Tag = 'Choose yourself'; Available = $true; Text = 'Pick the removal groups and the image''s own apps and features yourself.'; Data = $null }
)
# the group Custom starts with: setup's hardware checks skipped, as every build did before the modes
$AkariIsoCustomStart = 'SkipHardwareChecks'
$AkariIsoListTitles = [ordered]@{ Apps = 'Store apps'; Capabilities = 'Optional features'; Features = 'Windows features'; Packages = 'OS packages (advanced)' }
# Step: the wizard's step; Mode: the picked mode; Stages: the Create ISO step's @{ Text; State; Elapsed; Clock; Row;
# Ops (its operations, Update-AkariIsoOpList); Open }; OpsSeen: the build's operations shown so far; Current: the
# operation running; ResultPath / BuildError: how the last build ended (BuildError also: why Review can't build);
# Details: the ISO's size, SHA-256 and the report's path
# Microsoft's download (MsHashes: its SHA-256 rows once read; MsError: why they couldn't be; MsWaiting / MsSince: watching
# Downloads for a Win11*.iso written since)
$AkariMicrosoftHint = 'Microsoft''s page downloads the latest Windows 11 in your browser (pick the language there); Akari then finds it in Downloads and checks it against the SHA-256 values Microsoft publishes.'
$script:IsoState = @{ Image = ''; Editions = @(); Lists = $null; Massgrave = @(); Uup = $null; Waiting = ''
    MsHashes = $null; MsError = ''; MsWaiting = $false; MsSince = [datetime]::MinValue
    Step = 0; Mode = 'Custom'; Stages = @(); ResultPath = ''; BuildError = ''; OpsSeen = 0; Current = ''; Details = '' }

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

# an operation the build reported (@{ Stage; Name; State; Seconds; Note }) into its stage's list: a Running one adds a
# row, an ending one ends the last Running row of that name (none: a row of its own). Returns the row. Pure.
function Update-AkariIsoOpList([Collections.IList]$List, [hashtable]$Op) {
    $row = $null
    if ($Op.State -ne 'Running') {
        for ($i = $List.Count - 1; $i -ge 0; $i--) { if ($List[$i].Name -eq $Op.Name -and $List[$i].State -eq 'Running') { $row = $List[$i]; break } }
    }
    if (-not $row) { $row = @{ Name = $Op.Name; State = 'Running'; Note = ''; Elapsed = '' }; [void]$List.Add($row) }
    if ($Op.State -ne 'Running') {
        $row.State = $Op.State; $row.Note = "$($Op.Note)"
        $row.Elapsed = Get-AkariIsoElapsedText ([TimeSpan]::FromSeconds([double]$Op.Seconds))
    }
    $row
}
# a stage's operations in a line: "3 operations, 1 failed, 1 skipped" ('' with none). Pure.
function Get-AkariIsoOpSummary($Ops) {
    $all = @($Ops)
    if (-not $all.Count) { return '' }
    $failed = @($all | Where-Object { $_.State -eq 'Failed' }).Count
    $skipped = @($all | Where-Object { $_.State -eq 'Skipped' }).Count
    "$($all.Count) $(if ($all.Count -eq 1) { 'operation' } else { 'operations' })" + $(if ($failed) { ", $failed failed" }) + $(if ($skipped) { ", $skipped skipped" })
}
# under the result: the ISO's size and SHA-256 (built), the report's path either way. Pure.
function Get-AkariIsoResultDetails($Report, [bool]$Ok) {
    if (-not $Report) { return '' }
    $file = [IO.Path]::ChangeExtension("$($Report.iso)", '.report.json')
    if (-not $Ok) { return "Report: $file" }
    ('{0:0.00} GB {1} SHA-256 {2}' -f ([double]$Report.size / 1GB), [char]0x00B7, $Report.sha256) + "`nReport: $file"
}

# "n removal groups" over the plan. Pure.
function Get-AkariIsoPlanText([int]$Count) { if ($Count -eq 1) { '1 removal group' } else { "$Count removal groups" } }

# an edition's build from its version (10.0.26100.1742 -> 26100), 0 when it has none. Pure.
function Get-AkariIsoBuildOf([string]$Version) {
    $parts = "$Version".Split('.')
    $b = 0
    if ($parts.Count -gt 2 -and [int]::TryParse($parts[2], [ref]$b)) { $b } else { 0 }
}

# Review's cards: @{ Icon; Title; Lines }. $Info: Summary, Iso, ModeName, ModeIcon, Groups (the picked groups'
# names), Custom (the image's own lists count), Lists (@{ Title; Ticked; Count }, the lists read), Bake (the AkariOS
# mode: @{ InImage; Later; FirstSignIn }, counts), OutDir, Answer (None / Local / Generator), SkipOobe, User,
# AkariOS, Settings (the Build settings, Get-AkariIsoSettings' shape; none = the defaults). Pure.
function Get-AkariIsoReviewCards([hashtable]$Info) {
    $names = @($Info.Groups | Where-Object { $_ })
    $plan = [Collections.Generic.List[string]]::new()
    $plan.Add((Get-AkariIsoPlanText $names.Count))
    foreach ($n in $names) { $plan.Add("- $n") }
    if ($Info.Custom) {
        $lists = @(@($Info.Lists) | Where-Object { $_ } | ForEach-Object { "$($_.Title): $($_.Ticked) of $($_.Count)" })
        $plan.Add('')
        if ($lists.Count) { foreach ($l in $lists) { $plan.Add($l) } } else { $plan.Add('The image''s own lists weren''t read: nothing picked from them.') }
    }
    if ($Info.Bake) {
        $plan.Add('')
        $plan.Add("AkariOS settings written into the image: $($Info.Bake.InImage)")
        $plan.Add($(if ($Info.Bake.FirstSignIn) { "The rest at the first sign-in: $($Info.Bake.Later) changes, one UAC prompt" } else { 'The rest left out: run One-click from the Start menu later' }))
    }
    $removed = $plan -join "`n"
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
        @{ Icon = 'sliders-horizontal'; Title = 'Build settings'; Lines = (Get-AkariIsoSettingsLines (Get-AkariIsoSettings @{ Settings = $Info.Settings })) -join "`n" }
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
    $p.SrcMs = New-AkariIsoRadio 'iso-src' 'Download the latest Windows 11 from Microsoft (checked against Microsoft''s SHA-256)'
    $p.SrcUup = New-AkariIsoRadio 'iso-src' 'Download with UUP Dump (23H2 to 26H2, any language, Home to IoT Enterprise)'
    $p.SrcMg = New-AkariIsoRadio 'iso-src' 'Download from Massgrave (LTSC, IoT LTSC, consumer and business media)'
    $p.SrcFile.IsChecked = $true
    [void]$c.Panel.Children.Add($p.SrcFile)
    $b = New-AkariIsoBranch $p.SrcFile; $r = New-AkariIsoRow
    $p.IsoPath = New-AkariIsoBox
    [void]$r.Children.Add($p.IsoPath)
    [void]$r.Children.Add((New-AkariIsoButton "Browse$([char]0x2026)" 'Btn' { $f = Select-AkariIsoFile; if ($f) { $script:IsoParts.IsoPath.Text = $f } }))
    [void]$b.Children.Add($r); [void]$c.Panel.Children.Add($b)
    [void]$c.Panel.Children.Add($p.SrcMs)
    $b = New-AkariIsoBranch $p.SrcMs
    $p.SrcMs.Add_Checked({ Start-AkariMicrosoftHashes })
    $r = New-AkariIsoRow
    [void]$r.Children.Add((New-AkariIsoButton 'Open Microsoft''s download page' 'Btn' { Open-AkariMicrosoftPage }))
    [void]$b.Children.Add($r)
    $p.MsNote = New-AkariText $AkariMicrosoftHint 13 'Mu'
    [void]$b.Children.Add($p.MsNote); [void]$c.Panel.Children.Add($b)
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

    # 3 Components: the mode again, the removal plan (the mode's groups, or Custom's picks), then Custom's lists (the
    # image's own)
    $s = [Windows.Controls.StackPanel]::new()
    $m = New-AkariIsoModes; $m.Margin = [Windows.Thickness]::new(-4, -4, -4, 8)
    [void]$s.Children.Add($m)
    $c = New-AkariIsoCard 'Removal plan'
    $p.PlanText = New-AkariText '' 12 'Mu'; $p.PlanText.Margin = [Windows.Thickness]::new(0, 0, 0, 6)
    [void]$c.Panel.Children.Add($p.PlanText)
    $p.GroupChecks = [Collections.Generic.List[object]]::new()
    # Minimal's pruning waits for batch P9
    $script:IsoGroups = @(Get-AkariIsoGroups | Where-Object { -not $_.PruneComponentStore })
    foreach ($g in $script:IsoGroups) {
        $r = [Windows.Controls.StackPanel]::new(); $r.Orientation = 'Horizontal'
        $cb = New-AkariIsoCheck $g.Name ($g.Id -eq $AkariIsoCustomStart)
        $cb.Tag = $g.Id
        $cb.Margin = [Windows.Thickness]::new(0, 8, 8, 0)
        $cb.Add_Checked({ if (-not $script:IsoState.Applying) { Update-AkariIsoPlanText } })
        $cb.Add_Unchecked({ if (-not $script:IsoState.Applying) { Update-AkariIsoPlanText } })
        [void]$r.Children.Add($cb)
        if ($g.Risk -in 'Caution', 'Advanced') { $bd = New-AkariBadge $g.Risk; $bd.Margin = [Windows.Thickness]::new(0, 8, 0, 0); [void]$r.Children.Add($bd) }
        [void]$c.Panel.Children.Add($r)
        $t = New-AkariText $g.Description 12 'Mu'; $t.Margin = [Windows.Thickness]::new(28, 0, 0, 0)
        [void]$c.Panel.Children.Add($t)
        $p.GroupChecks.Add($cb)
    }
    $p.PlanText.Text = Get-AkariIsoPlanText @($p.GroupChecks | Where-Object { $_.IsChecked }).Count
    [void]$s.Children.Add($c.Card)
    $c = New-AkariIsoCard 'Apps and features in the image' 'Tick what to remove. Frameworks are left out of the list (apps need them).'
    $p.ListsCard = $c.Card
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
    # the AkariOS mode: the rest of the preset at each new account's first sign-in
    $c = New-AkariIsoCard 'Finish AkariOS at the first sign-in'
    $p.FirstSignIn = New-AkariIsoCheck 'Run the rest of AkariOS when each new account first signs in' $true
    [void]$c.Panel.Children.Add($p.FirstSignIn)
    $t = New-AkariText 'The AkariOS settings that are only registry values are written into the image. The rest (drivers, Windows Security, installs) runs when each new account first signs in, after one UAC prompt. Off: only what can be done in the image; run One-click later.' 12 'Mu'
    $t.Margin = [Windows.Thickness]::new(28, 0, 0, 0)
    [void]$c.Panel.Children.Add($t)
    $p.FirstSignInCard = $c.Card
    $p.FirstSignInCard.Visibility = 'Collapsed'
    [void]$s.Children.Add($c.Card)
    # the build settings (the native app's): the final compression (Recovery ESD at first), three switches
    $c = New-AkariIsoCard 'Build settings'
    $r = New-AkariIsoRow
    [void]$r.Children.Add((New-AkariUaFormLabel 'Final compression '))
    $p.Compression = New-AkariIsoCombo 260
    Set-AkariComboItems $p.Compression @($AkariIsoCompressions.Keys) { param($k) $AkariIsoCompressions[$k] }
    [void]$r.Children.Add($p.Compression); [void]$c.Panel.Children.Add($r)
    [void]$c.Panel.Children.Add((New-AkariText 'Recovery ESD makes the smallest ISO but takes much longer to build. Maximum WIM is the usual choice; Fast WIM builds quickest and is the largest.' 12 'Mu'))
    foreach ($o in @(
            @{ Key = 'Turbo'; Text = 'Turbo feature removal'; Note = 'The Windows features you picked go in one DISM call instead of one each, then each one is checked.' }
            @{ Key = 'CleanLeftovers'; Text = 'Remove leftover image data'; Note = 'Downloaded updates, temp files, archived logs, error reports and crash dumps inside the image. Nothing is removed while the image has updates waiting to finish.' }
            @{ Key = 'LeaveOutNetFx3Files'; Text = 'Leave .NET 3.5''s setup files off the ISO'; Note = 'The ISO''s sources\sxs folder. .NET Framework 3.5 is still added to the image first; the ISO just can''t serve as an offline source for it later.' }
        )) {
        $p[$o.Key] = New-AkariIsoCheck $o.Text
        $p[$o.Key].Margin = [Windows.Thickness]::new(0, 10, 0, 0)
        [void]$c.Panel.Children.Add($p[$o.Key])
        $t = New-AkariText $o.Note 12 'Mu'; $t.Margin = [Windows.Thickness]::new(28, 0, 0, 0)
        [void]$c.Panel.Children.Add($t)
    }
    [void]$s.Children.Add($c.Card)
    $p.Steps[3] = $s

    Update-AkariIsoModeLook
    $p
}

# the Build settings step's picks, as Choices.Settings
function Get-AkariIsoPickedSettings {
    $p = $script:IsoParts
    @{ Compression = [string](Get-AkariComboTag $p.Compression); Turbo = [bool]$p.Turbo.IsChecked
        CleanLeftovers = [bool]$p.CleanLeftovers.IsChecked; LeaveOutNetFx3Files = [bool]$p.LeaveOutNetFx3Files.IsChecked }
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
# a mode's tile: picked (a new one applied: Set-AkariIsoMode); on Start, also the next step
function Select-AkariIsoMode([string]$Id) {
    $m = @($AkariIsoModes | Where-Object { $_.Id -eq $Id })[0]
    if (-not $m -or -not $m.Available) { return }
    if ($script:IsoState.Mode -ne $Id) { $script:IsoState.Mode = $Id; Set-AkariIsoMode }
    Update-AkariIsoModeLook
    if ($script:IsoState.Step -eq 0) { $script:IsoState.Step = 1; Show-Page }
}
# the picked mode applied to the page: its groups ticked and fixed (Custom: Custom's start, ticked by hand), its build
# settings (Custom: Recovery ESD, the switches off), AkariOS on for the AkariOS mode; Custom's lists and the first
# sign-in card shown for their mode
function Set-AkariIsoMode {
    $p = $script:IsoParts
    if (-not $p -or -not $p.GroupChecks) { return }
    $m = @($AkariIsoModes | Where-Object { $_.Id -eq $script:IsoState.Mode })[0].Data
    $script:IsoState.Applying = $true
    try {
        foreach ($cb in $p.GroupChecks) {
            $cb.IsChecked = if ($m) { @($m.Groups) -contains [string]$cb.Tag } else { [string]$cb.Tag -eq $AkariIsoCustomStart }
            $cb.IsEnabled = -not $m
        }
        $set = Get-AkariIsoSettings @{ Settings = $(if ($m) { $m.Settings } else { @{ Compression = 'Recovery' } }) }
        foreach ($it in $p.Compression.Items) { if ($it.Tag -eq $set.Compression) { $p.Compression.SelectedItem = $it } }
        foreach ($k in 'Turbo', 'CleanLeftovers', 'LeaveOutNetFx3Files') { $p[$k].IsChecked = $set[$k] }
        if ($m -and $m.AkariOS) { $p.AkariOS.IsChecked = $true }
    }
    finally { $script:IsoState.Applying = $false }
    $p.ListsCard.Visibility = if ($m) { 'Collapsed' } else { 'Visible' }
    $p.FirstSignInCard.Visibility = if ($m -and $m.AkariOS) { 'Visible' } else { 'Collapsed' }
    Update-AkariIsoPlanText
}
function Update-AkariIsoPlanText {
    $p = $script:IsoParts
    $p.PlanText.Text = Get-AkariIsoPlanText @($p.GroupChecks | Where-Object { $_.IsChecked }).Count
}
# the picked groups' data, in Order
function Get-AkariIsoPickedGroups {
    $ids = @($script:IsoParts.GroupChecks | Where-Object { $_.IsChecked } | ForEach-Object { [string]$_.Tag })
    @($script:IsoGroups | Where-Object { $ids -contains $_.Id })
}
# the AkariOS mode's bake for the picked edition (Get-AkariIsoBake on the AkariOS preset), else $null
function Get-AkariIsoPageBake {
    $m = @($AkariIsoModes | Where-Object { $_.Id -eq $script:IsoState.Mode })[0].Data
    if (-not $m -or -not $m.AkariOS) { return $null }
    $preset = Find-AkariPreset $AkariIsoBakePreset (Join-Path $Root 'Presets')
    if (-not $preset) { return $null }
    $ed = Get-AkariIsoEdition
    Get-AkariIsoBake $preset @($script:Tweaks | Where-Object { -not $_.Legacy }) (Get-AkariIsoBuildOf $(if ($ed) { $ed.Version } else { '' }))
}

# Build another: back to Start, the mode kept
function Reset-AkariIsoBuild {
    $st = $script:IsoState
    $st.Stages = @(); $st.ResultPath = ''; $st.BuildError = ''; $st.Step = 0; $st.OpsSeen = 0; $st.Current = ''; $st.Details = ''
    Show-Page
}

# Review: an InfoBar when it can't build, then the cards
function New-AkariIsoReview {
    $st = $script:IsoState
    $p = $script:IsoParts
    $sp = [Windows.Controls.StackPanel]::new()
    if ($st.BuildError) { [void]$sp.Children.Add((New-AkariInfoBar 'Bad' 'Can''t build yet' $st.BuildError).Bar) }
    $m = @($AkariIsoModes | Where-Object { $_.Id -eq $st.Mode })[0]
    $bake = Get-AkariIsoPageBake
    $bakeInfo = if ($bake) { @{ InImage = @($bake.InImage).Count; Later = @($bake.Later).Count; FirstSignIn = [bool]($p.FirstSignIn.IsChecked -and $p.AkariOS.IsChecked) } } else { $null }
    $lists = @(foreach ($lp in $p.Lists.Values) {
        if ($lp.Tag.View.Visibility -eq 'Visible') { @{ Title = $lp.Tag.Title; Ticked = @($lp.Children | Where-Object { $_.IsChecked }).Count; Count = $lp.Children.Count } }
    })
    $answer = if ($p.AnsNone.IsChecked) { 'None' } elseif ($p.AnsLocal.IsChecked) { 'Local' } else { 'Generator' }
    $cards = Get-AkariIsoReviewCards @{ Summary = (Get-AkariIsoSummary (Get-AkariIsoEdition)); Iso = $p.IsoPath.Text; ModeName = $m.Name; ModeIcon = $m.Icon
        Groups = @(Get-AkariIsoPickedGroups | ForEach-Object { $_.Name }); Custom = (-not $m.Data); Bake = $bakeInfo
        Lists = $lists; OutDir = $p.OutDir.Text; Answer = $answer; SkipOobe = [bool]$p.SkipOobe.IsChecked; User = $p.User.Text.Trim(); AkariOS = [bool]$p.AkariOS.IsChecked
        Settings = (Get-AkariIsoPickedSettings) }
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

# Create ISO: how it ended (an InfoBar: the path, size, SHA-256, the report), the operation running, then a row per
# stage (its state, text, time, its operations under it)
function New-AkariIsoBuildView {
    $st = $script:IsoState
    $sp = [Windows.Controls.StackPanel]::new()
    $details = if ($st.Details) { "`n$($st.Details)" } else { '' }
    if ($st.ResultPath) {
        $open = New-AkariBarButton 'Open folder' { Open-AkariFolder ([IO.Path]::GetDirectoryName($script:IsoState.ResultPath)) }
        [void]$sp.Children.Add((New-AkariInfoBar 'Ok' 'Your ISO is ready' "$($st.ResultPath)$details" @($open)).Bar)
    }
    if ($st.BuildError) { [void]$sp.Children.Add((New-AkariInfoBar 'Bad' 'Not built' "$($st.BuildError)$details").Bar) }
    $cur = New-AkariText '' 12 'Mu'
    $cur.Margin = [Windows.Thickness]::new(0, 0, 0, 8); $cur.TextTrimming = 'CharacterEllipsis'
    $script:IsoParts.CurrentOp = $cur
    Set-AkariIsoCurrentOp
    [void]$sp.Children.Add($cur)
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
# a state's icon and brush (stages and operations)
function Get-AkariIsoStateIcon([string]$State) {
    switch ($State) {
        'Running' { 'refresh-cw', 'AccText' }
        'Done' { 'circle-check', 'Ok' }
        'Failed' { 'circle-x', 'Bad' }
        { $_ -in 'Not run', 'Skipped' } { 'circle-slash', 'Mu' }
        default { 'circle-minus', 'Mu' }
    }
}
# a stage: its row (a click opens its operations when it has some), then its operations' panel
function New-AkariIsoStageRow($Stage) {
    $box = [Windows.Controls.StackPanel]::new()
    $dp = [Windows.Controls.DockPanel]::new()
    $dp.MinHeight = 32; $dp.Margin = [Windows.Thickness]::new(8, 2, 8, 2); $dp.Background = [Windows.Media.Brushes]::Transparent
    $ic = New-AkariIcon 'circle-minus' 16 'Mu'
    $ic.Margin = [Windows.Thickness]::new(0, 0, 12, 0); $ic.VerticalAlignment = 'Center'
    [Windows.Controls.DockPanel]::SetDock($ic, 'Left'); [void]$dp.Children.Add($ic)
    $chev = New-AkariIcon 'chevron-right' 12 'Mu'
    $chev.Margin = [Windows.Thickness]::new(12, 0, 0, 0); $chev.VerticalAlignment = 'Center'
    [Windows.Controls.DockPanel]::SetDock($chev, 'Right'); [void]$dp.Children.Add($chev)
    $right = New-AkariText '' 12 'Mu'; $right.VerticalAlignment = 'Center'; $right.TextWrapping = 'NoWrap'
    [Windows.Controls.DockPanel]::SetDock($right, 'Right'); [void]$dp.Children.Add($right)
    $mid = [Windows.Controls.StackPanel]::new(); $mid.VerticalAlignment = 'Center'
    [void]$mid.Children.Add((New-AkariText $Stage.Text 14))
    $sum = New-AkariText '' 12 'Mu'
    [void]$mid.Children.Add($sum)
    [void]$dp.Children.Add($mid)
    $ops = [Windows.Controls.StackPanel]::new()
    $ops.Margin = [Windows.Thickness]::new(36, 0, 8, 6)
    [void]$box.Children.Add($dp); [void]$box.Children.Add($ops)
    $box.Tag = @{ Icon = $ic; Right = $right; Summary = $sum; Chevron = $chev; Ops = $ops; Stage = $Stage }
    $dp.Tag = $box
    $dp.Add_MouseLeftButtonUp({
            $b = $this.Tag; $s = $b.Tag.Stage
            if (-not @($s.Ops).Count) { return }
            $s.Open = -not $s.Open
            Set-AkariIsoStageLook $b $s
        })
    foreach ($o in @($Stage.Ops)) { $o.Row = $null }
    Set-AkariIsoStageLook $box $Stage
    $box
}
# an operation's row: its icon, name, note, time
function New-AkariIsoOpRow($Op) {
    $dp = [Windows.Controls.DockPanel]::new()
    $dp.Margin = [Windows.Thickness]::new(0, 2, 0, 2)
    $ic = New-AkariIcon 'circle-minus' 14 'Mu'
    $ic.Margin = [Windows.Thickness]::new(0, 2, 10, 0); $ic.VerticalAlignment = 'Top'
    [Windows.Controls.DockPanel]::SetDock($ic, 'Left'); [void]$dp.Children.Add($ic)
    $right = New-AkariText '' 12 'Mu'; $right.TextWrapping = 'NoWrap'; $right.Margin = [Windows.Thickness]::new(12, 0, 0, 0)
    [Windows.Controls.DockPanel]::SetDock($right, 'Right'); [void]$dp.Children.Add($right)
    $mid = [Windows.Controls.StackPanel]::new()
    [void]$mid.Children.Add((New-AkariText $Op.Name 12))
    $note = New-AkariText '' 12 'Mu'
    [void]$mid.Children.Add($note)
    [void]$dp.Children.Add($mid)
    $dp.Tag = @{ Icon = $ic; Right = $right; Note = $note }
    $dp
}
function Set-AkariIsoOpLook($Op) {
    $r = $Op.Row
    if (-not $r) { return }
    $icon, $brush = Get-AkariIsoStateIcon $Op.State
    Set-AkariIcon $r.Tag.Icon $icon
    $r.Tag.Icon.Child.SetResourceReference([Windows.Shapes.Shape]::FillProperty, $brush)
    $r.Tag.Right.Text = "$($Op.State)$(if ($Op.Elapsed) { "  $($Op.Elapsed)" })"
    $r.Tag.Note.Text = $Op.Note
    $r.Tag.Note.Visibility = if ($Op.Note) { 'Visible' } else { 'Collapsed' }
}
function Set-AkariIsoStageLook($Row, $Stage) {
    if (-not $Row) { return }
    $icon, $brush = Get-AkariIsoStateIcon $Stage.State
    $t = $Row.Tag
    Set-AkariIcon $t.Icon $icon
    $t.Icon.Child.SetResourceReference([Windows.Shapes.Shape]::FillProperty, $brush)
    $t.Right.Text = "$($Stage.State)$(if ($Stage.Elapsed) { "  $($Stage.Elapsed)" })"
    $sum = Get-AkariIsoOpSummary $Stage.Ops
    $t.Summary.Text = $sum
    $t.Summary.Visibility = if ($sum) { 'Visible' } else { 'Collapsed' }
    $t.Chevron.Visibility = if ($sum) { 'Visible' } else { 'Hidden' }
    Set-AkariIcon $t.Chevron $(if ($Stage.Open) { 'chevron-down' } else { 'chevron-right' })
    $t.Ops.Visibility = if ($Stage.Open -and $sum) { 'Visible' } else { 'Collapsed' }
    if ($Stage.Open) {
        foreach ($o in @($Stage.Ops)) {
            if (-not $o.Row) { $o.Row = New-AkariIsoOpRow $o; [void]$t.Ops.Children.Add($o.Row) }
            Set-AkariIsoOpLook $o
        }
    }
}
function Set-AkariIsoCurrentOp {
    $c = $script:IsoParts.CurrentOp
    if (-not $c) { return }
    $c.Text = if ($script:IsoState.Current) { "Now: $($script:IsoState.Current)" } else { '' }
    $c.Visibility = if ($script:IsoState.Current) { 'Visible' } else { 'Collapsed' }
}

# the build's progress (the Shell timer, Done / Total from Set-AkariProgress): each stage's state, its time once done;
# the operations reported since (IsoOps) into their stages, the one running
function Update-AkariIsoStages($Shared) {
    $st = $script:IsoState
    $stages = @($st.Stages)
    if (-not $Shared -or -not $stages.Count) { return }
    if ($Shared.Total) {
        $states = Get-AkariIsoStageStates ([int]$Shared.Done) ([int]$Shared.Total) $stages.Count
        for ($i = 0; $i -lt $stages.Count; $i++) { Set-AkariIsoStageState $stages[$i] $states[$i] }
    }
    $ops = $Shared.IsoOps
    if (-not $ops) { return }
    while ($st.OpsSeen -lt $ops.Count) {
        $op = $ops[$st.OpsSeen]
        $st.OpsSeen++
        $i = [int]$op.Stage
        if ($null -eq $op.Stage -or $i -lt 0 -or $i -ge $stages.Count) { continue }
        $s = $stages[$i]
        $row = Update-AkariIsoOpList $s.Ops $op
        $st.Current = if ($op.State -eq 'Running') { $op.Name } else { '' }
        Set-AkariIsoStageLook $s.Row $s
        if ($row.Row) { Set-AkariIsoOpLook $row }
    }
    Set-AkariIsoCurrentOp
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
    # each app's own logo, copied out of the image (it is unmounted after a build)
    $AkariShared.Logos = Get-AkariImageAppLogos $w.Mount $AkariShared.Apps $AkariShared.LogoDir
    $AkariShared.Capabilities = @(Get-AkariImageCapabilities $w.Mount)
    $AkariShared.Features = @(Get-AkariImageFeatures $w.Mount | Where-Object { $_.State -notmatch 'Disabled' })
    $AkariShared.Packages = @(Get-AkariImagePackages $w.Mount)
} catch { $AkariShared.Error = $_.Exception.Message }
'@
    $logoDir = Join-Path (Split-Path $AkariLogFile) 'IsoLogos'
    if (Start-AkariIsoJob 'IsoRead' $code @{ Out = $p.OutDir.Text.Trim(); Image = $script:IsoState.Image; Index = [int]$ed.Index; LogoDir = $logoDir } "Reading the apps in $($ed.Name)") {
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
    $custom = $st.Mode -eq 'Custom'
    $sel = { param($k) @(if ($custom -and $p.Lists[$k]) { $p.Lists[$k].Children | Where-Object { $_.IsChecked } | ForEach-Object { [string]$_.Tag } }) }
    $groups = @(Get-AkariIsoPickedGroups)
    $bake = Get-AkariIsoPageBake
    $ed2 = Get-AkariIsoBuildOf $ed.Version
    $choices = @{
        OutDir = $p.OutDir.Text.Trim(); Iso = $p.IsoPath.Text.Trim(); Image = $st.Image; Index = [int]$ed.Index; Edition = $ed.Name
        Options = @(); Apps = (& $sel 'Apps'); Capabilities = (& $sel 'Capabilities'); Features = (& $sel 'Features'); Packages = (& $sel 'Packages')
        AkariDir = $(if ($p.AkariOS.IsChecked) { $Root } else { '' }); Unattend = $answer; Settings = (Get-AkariIsoPickedSettings)
        # the wizard: the picked groups (never zISO's always-on data), the AkariOS mode's bake and first sign-in
        Groups = @($groups | ForEach-Object { $_.Id }); AppPatterns = (Get-AkariIsoAppPatterns $groups @($script:Tweaks | Where-Object { -not $_.Legacy }))
        Bake = $(if ($bake) { @($bake.InImage) } else { @() }); FirstSignIn = [bool]($bake -and $p.FirstSignIn.IsChecked -and $p.AkariOS.IsChecked); ImageBuild = $ed2
    }
    $name = Get-AkariIsoOutName $choices.Iso
    $n = $choices.Apps.Count + $choices.Capabilities.Count + $choices.Features.Count + $choices.Packages.Count
    $q = "Build $name from $($ed.Name)?`n`n$(Get-AkariIsoPlanText $groups.Count)$(if ($custom) { " and $n of the image's apps and features" }) to remove. It takes 20 to 40 minutes; Optimize's changes and installs wait meanwhile."
    if (-not (Confirm-AkariDialog $q 'Build ISO' 'Cancel' 'Question' 'ISO Builder')) { return }
    $plan = New-AkariIsoPlan $choices @() $groups
    $code = '$AkariShared.Result = Invoke-AkariIsoBuild $AkariShared.Choices'
    $ops = [Collections.ArrayList]::Synchronized([Collections.ArrayList]::new())
    if (-not (Start-AkariIsoJob 'IsoBuild' $code @{ Choices = $choices; IsoOps = $ops } "Building $name")) { return }
    $st.Stages = @(foreach ($s in $plan) {
            @{ Text = $s.Text; State = 'Waiting'; Elapsed = ''; Clock = $null; Row = $null; Ops = [Collections.ArrayList]::new(); Open = $false }
        })
    $st.ResultPath = ''; $st.OpsSeen = 0; $st.Current = ''; $st.Details = ''
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
    Start-AkariIsoWatch
}
# Downloads looked at every 3 seconds: Microsoft's download while one is awaited, else Massgrave's file
function Start-AkariIsoWatch {
    if (-not $script:IsoWatch) {
        $script:IsoWatch = [Windows.Threading.DispatcherTimer]::new()
        $script:IsoWatch.Interval = [TimeSpan]::FromSeconds(3)
        $script:IsoWatch.Add_Tick({ if ($script:IsoState.MsWaiting) { Test-AkariMicrosoftDownload } else { Test-AkariMassgraveDownload } })
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

# ---- Microsoft (the native app's I5): the browser downloads from Microsoft's page, Akari finds the new Win11*.iso in
# Downloads and uses it only when its SHA-256 is one Microsoft publishes (the list unreadable: used, saying so)

# Microsoft's hash table, read once (a question to a website); quietly not while another job runs (the watch asks
# again on its next tick)
function Start-AkariMicrosoftHashes {
    if ($null -ne $script:IsoState.MsHashes -or $script:Busy) { return }
    [void](Start-AkariIsoJob 'IsoMicrosoft' '$AkariShared.Result = Get-AkariMicrosoftHashes' @{} 'Reading Microsoft''s SHA-256 list')
}

# opens Microsoft's page in the browser, then looks for a new Win11*.iso in Downloads every 3 seconds
function Open-AkariMicrosoftPage {
    Open-AkariIsoLink $AkariMicrosoftIsoPage
    $st = $script:IsoState
    $st.MsWaiting = $true
    # a file the browser finishes from now on (a few seconds' slack for the clocks)
    $st.MsSince = [datetime]::UtcNow.AddSeconds(-5)
    $script:IsoParts.MsNote.Text = "Waiting for the Windows 11 ISO in Downloads$([char]0x2026) (choose the language and download it in the browser that just opened)"
    Start-AkariIsoWatch
}

function Test-AkariMicrosoftDownload {
    $st = $script:IsoState
    if ($script:Busy) { return }
    $hit = Find-AkariNewIso $AkariMicrosoftIsoPattern $st.MsSince
    if (-not $hit) { return }
    # the hash list not read yet (its read waited for another job): read it, check on the next tick
    if ($null -eq $st.MsHashes -and -not $st.MsError) { Start-AkariMicrosoftHashes; return }
    if ($script:IsoWatch) { $script:IsoWatch.Stop() }
    $st.MsWaiting = $false
    Start-AkariMicrosoftCheck $hit
}

# the download checked against Microsoft's table in the background (job IsoVerify); no table = used, saying so
function Start-AkariMicrosoftCheck([string]$Iso) {
    $st = $script:IsoState; $p = $script:IsoParts
    if ($null -eq $st.MsHashes) {
        Set-AkariIsoSource $Iso "Downloaded: $Iso (not checked: $($st.MsError.TrimEnd('.')))"
        $p.MsNote.Text = $AkariMicrosoftHint
        return
    }
    $p.MsNote.Text = "Checking $([IO.Path]::GetFileName($Iso)) against Microsoft's SHA-256 values$([char]0x2026)"
    $code = '$AkariShared.Result = try { $h = Test-AkariMicrosoftIso $AkariShared.Iso $AkariShared.Hashes; if ($h) { @{ Match = $h } } else { @{ Match = $null } } } catch { @{ Error = $_.Exception.Message } }'
    [void](Start-AkariIsoJob 'IsoVerify' $code @{ Iso = $Iso; Hashes = @($st.MsHashes) } 'Checking the ISO''s SHA-256')
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

# a list of the image's: a check box each; $Logos (the Store apps): each app's icon beside its name (its own logo,
# else Assets\Apps', else the box)
function Set-AkariIsoList([string]$Key, $Items, [scriptblock]$Label, [scriptblock]$Value, $Logos = $null) {
    $lp = $script:IsoParts.Lists[$Key]
    $lp.Children.Clear()
    foreach ($i in @($Items | Sort-Object { & $Label $_ })) {
        $cb = New-AkariIsoCheck (& $Label $i)
        if ($null -ne $Logos) {
            $row = [Windows.Controls.StackPanel]::new(); $row.Orientation = 'Horizontal'
            $ic = New-AkariAppIcon @{ Id = "appx/$($i.Name)"; Package = $i.Name } 20 $Logos
            $ic.Margin = [Windows.Thickness]::new(0, 0, 8, 0); $ic.VerticalAlignment = 'Center'
            [void]$row.Children.Add($ic)
            [void]$row.Children.Add((New-AkariText (& $Label $i) 14))
            $cb.Content = $row
        }
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
            Set-AkariIsoList 'Apps' $s.Apps { param($i) $i.Name } { param($i) $i.Package } $(if ($s.Logos) { $s.Logos } else { @{} })
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
            # the report's states and times where it has them
            $rep = if ($r) { $r.Report } else { $null }
            $rs = if ($rep) { @($rep.stages) } else { @() }
            if ($rs.Count -eq $stages.Count) {
                for ($i = 0; $i -lt $stages.Count; $i++) {
                    $stages[$i].State = $rs[$i].state
                    $stages[$i].Elapsed = if ($rs[$i].state -eq 'Not run') { '' } else { Get-AkariIsoElapsedText ([TimeSpan]::FromSeconds([double]$rs[$i].seconds)) }
                    Set-AkariIsoStageLook $stages[$i].Row $stages[$i]
                }
            }
            $st.Current = ''
            $st.Details = Get-AkariIsoResultDetails $rep $ok
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
        'IsoMicrosoft' {
            $r = $s.Result
            if ($r -and $r.Ok) { $st.MsHashes = @($r.Items); $st.MsError = '' }
            else {
                $st.MsError = if ($r) { $r.Message } else { 'Microsoft''s SHA-256 list could not be read.' }
                Write-ErrLog "ISO Builder: $($st.MsError)"
            }
        }
        'IsoVerify' {
            $r = $s.Result
            $iso = [string]$s.Iso
            $name = [IO.Path]::GetFileName($iso)
            if ($r -and $r.Match) {
                $p.MsNote.Text = $AkariMicrosoftHint
                Set-AkariIsoSource $iso "Downloaded and checked against Microsoft's SHA-256 ($($r.Match.Language)): $iso"
                Show-AkariToast 'ISO found and checked' $iso
            }
            elseif ($r -and $r.Error) { $p.MsNote.Text = "$name could not be read: $($r.Error)" }
            else {
                $p.MsNote.Text = "$name doesn't match any SHA-256 value Microsoft publishes: it may be damaged or not Microsoft's. Delete it and download it again."
                Write-ErrLog "ISO Builder: $iso matches no SHA-256 on Microsoft's page"
                Show-AkariToast 'ISO not used' 'Its SHA-256 doesn''t match Microsoft''s.'
            }
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
