# Settings (plan docs/plans/2026-11-19-winui-3.md decision 6, the prototype's PAGES.settings), in place of the title
# bar's options menu and the About page: Appearance (App theme, Accent colour, Animation effects), Settings files
# (Import, Export), Recovery (System Restore, Logs) and About (the version and the update check, the links, the
# credits from UI\About.psd1). The update check runs in the background on every launch: an update found while the user
# is still on Home asks right away ("Update now / Later"); Home shows it in an InfoBar until it is dismissed.
# Dot-sourced by Akari.ps1 after UI\CataloguePage.ps1.

$script:UpdateStatus = $null
$script:UpdateChecking = $false
# Settings › About's data: links, credits, license (UI\About.psd1)
$script:AboutData = Import-PowerShellDataFile "$Root\UI\About.psd1"

# Settings > Recovery: the support file (Core\Support.ps1), saved where the user picks; nothing is sent anywhere
function Select-AkariSupportFile {
    Add-Type -AssemblyName System.Windows.Forms
    $d = [Windows.Forms.SaveFileDialog]::new()
    $d.Filter = 'Zip files (*.zip)|*.zip'
    $d.FileName = "AkariOS-support-$((Get-Date).ToString('yyyyMMdd-HHmm')).zip"
    if ($d.ShowDialog() -eq 'OK') { $d.FileName } else { $null }
}

function Save-AkariSupportFile {
    $path = Select-AkariSupportFile
    if (-not $path) { return }
    try {
        $r = New-AkariSupportFile $path (Get-AkariSupportFiles) (Get-AkariSupportInfo) (Get-AkariSupportUsers) $env:COMPUTERNAME
    } catch {
        Write-ErrLog "Support file: $($_.Exception.Message)"
        Show-AkariMessage "The support file could not be saved:`n`n$($_.Exception.Message)" 'Error' 'Save a support file'
        return
    }
    Add-Log "Support file saved: $($r.Path)"
    Show-AkariToast 'Support file saved' $r.Path
    Open-AkariFolder (Split-Path $r.Path)
}

function Open-AkariLogFolder { $f = Split-Path $AkariLogFile; if (Test-Path $f) { Start-Process explorer.exe $f } }

# a text link (Link style: AccText, underlined on hover) that opens $Url in the browser
function New-AkariLink([string]$Text, [string]$Url) {
    $b = [Windows.Controls.Button]::new()
    $b.SetResourceReference([Windows.FrameworkElement]::StyleProperty, 'Link')
    $b.Content = $Text
    $b.Tag = $Url
    $b.ToolTip = $Url
    $b.HorizontalAlignment = 'Left'
    if ($Url) { $b.Add_Click({ param($s, $e) Start-Process ([string]$s.Tag) }) }
    $b
}

$AkariThemeLabels = [ordered]@{ Light = 'Light'; Dark = 'Dark'; System = 'Use system setting' }
$AkariAccentLabels = [ordered]@{ Akari = 'Akari crimson'; Windows = 'Windows accent' }

function Show-AkariSettings {
    Set-AkariHeader @('Settings')
    $p = @{}
    [void]$StepBody.Children.Add((New-AkariSection 'Appearance' -First))
    # App theme: an expander with Light / Dark / Use system setting radios (a quick cross-fade on switch)
    $ex = New-AkariExpander 'sun-moon' 'App theme' 'Select which app theme to display' $true
    $radios = [Windows.Controls.StackPanel]::new()
    $radios.Margin = [Windows.Thickness]::new(0, 4, 0, 4)
    foreach ($k in $AkariThemeLabels.Keys) {
        $r = [Windows.Controls.RadioButton]::new()
        $r.SetResourceReference([Windows.FrameworkElement]::StyleProperty, 'Radio')
        $r.GroupName = 'theme'; $r.Content = $AkariThemeLabels[$k]; $r.Tag = $k
        $r.IsChecked = ($k -eq $script:ThemeSetting)
        $r.Add_Checked({ param($s, $e) if ([string]$s.Tag -ne $script:ThemeSetting) { Switch-AkariTheme ([string]$s.Tag) } })
        [void]$radios.Children.Add($r)
    }
    [void]$ex.Body.Children.Add((New-AkariExpanderRow $radios))
    $p.Theme = $radios
    [void]$StepBody.Children.Add($ex.Card)
    # Accent colour, Animation effects
    $acc = [Windows.Controls.ComboBox]::new()
    $acc.SetResourceReference([Windows.FrameworkElement]::StyleProperty, 'Combo')
    $acc.MinWidth = 200
    foreach ($k in $AkariAccentLabels.Keys) { $it = [Windows.Controls.ComboBoxItem]::new(); $it.Content = $AkariAccentLabels[$k]; $it.Tag = $k; [void]$acc.Items.Add($it); if ($k -eq (Get-AkariAccentSetting)) { $acc.SelectedItem = $it } }
    $acc.Add_SelectionChanged({ param($s, $e) if ($s.SelectedItem) { Save-AkariSetting 'Accent' ([string]$s.SelectedItem.Tag); Set-AkariTheme $script:ThemeSetting } })
    $p.Accent = $acc
    $c1 = New-AkariSettingsCard 'palette' 'Accent colour' 'Akari crimson, or your Windows accent' $acc
    $anim = [Windows.Controls.Primitives.ToggleButton]::new()
    $anim.SetResourceReference([Windows.FrameworkElement]::StyleProperty, 'Switch')
    $anim.IsChecked = ([string](Read-AkariSettings).Animations -ne 'Off')
    $anim.Add_Click({
        param($s, $e)
        $on = ($s.IsChecked -eq $true)
        Save-AkariSetting 'Animations' $(if ($on) { 'On' } else { 'Off' })
        # code-driven motion follows at once; the controls' own transitions with the next launch
        $script:AkariMotionOn = $on -and (Test-AkariMotionOn)
    })
    $p.Animations = $anim
    $c2 = New-AkariSettingsCard 'sparkle' 'Animation effects' 'Follows Windows; turn it off here for AkariOS only' $anim
    $st = [Windows.Controls.StackPanel]::new(); $st.Margin = [Windows.Thickness]::new(0, 0, 0, 0)
    [void]$st.Children.Add($c1.Card); [void]$st.Children.Add($c2.Card)
    [void]$StepBody.Children.Add($st)
    # Settings files
    [void]$StepBody.Children.Add((New-AkariSection 'Settings files'))
    $st = [Windows.Controls.StackPanel]::new()
    foreach ($x in @(
        @('file-input', 'Import settings', 'Load choices you saved on another PC into Guided', { Start-AkariImport }),
        @('file-output', 'Export settings', 'Save your current choices to a file', { Start-AkariExport }))) {
        $c = New-AkariSettingsCard $x[0] $x[1] $x[2] (New-AkariIcon 'chevron-right' 12 'Mu') 'CardButton'
        $c.Card.Add_Click($x[3])
        [void]$st.Children.Add($c.Card)
    }
    [void]$StepBody.Children.Add($st)
    # Recovery
    [void]$StepBody.Children.Add((New-AkariSection 'Recovery'))
    $st = [Windows.Controls.StackPanel]::new()
    foreach ($x in @(
        @('arrow-reset', 'System Restore', "Open Windows' restore points", { Start-Process "$env:SystemRoot\System32\rstrui.exe" }),
        @('document', 'Logs', 'Open the folder with akari.log', { Open-AkariLogFolder }),
        @('bug', 'Save a support file', 'A zip of the logs and this PC''s details for a bug report; your names are left out', { Save-AkariSupportFile }))) {
        $c = New-AkariSettingsCard $x[0] $x[1] $x[2] (New-AkariIcon 'external-link' 12 'Mu') 'CardButton'
        $c.Card.Add_Click($x[3])
        [void]$st.Children.Add($c.Card)
    }
    [void]$StepBody.Children.Add($st)
    # About: the version, the update check, then the links and the credits
    [void]$StepBody.Children.Add((New-AkariSection 'About'))
    $d = $script:AboutData
    $p.Status = [Windows.Controls.StackPanel]::new(); $p.Status.Orientation = 'Horizontal'; $p.Status.VerticalAlignment = 'Center'; $p.Status.Margin = [Windows.Thickness]::new(0, 0, 12, 0)
    $p.Update = [Windows.Controls.Button]::new()
    $p.Update.SetResourceReference([Windows.FrameworkElement]::StyleProperty, 'Accent')
    $p.Update.Content = 'Update now'
    $p.Update.Margin = [Windows.Thickness]::new(0, 0, 8, 0)
    $p.Update.Add_Click({ Start-AkariUpdateInstall })
    $p.Check = [Windows.Controls.Button]::new()
    $p.Check.SetResourceReference([Windows.FrameworkElement]::StyleProperty, 'Btn')
    $p.Check.Content = 'Check for updates'
    $p.Check.Margin = [Windows.Thickness]::new(0, 0, 4, 0)
    $p.Check.Add_Click({ Start-AkariUpdateCheck $true })
    $ex = New-AkariExpander 'info' "AkariOS $AkariVersion" ([string]$d.License.Text) $false @($p.Status, $p.Update, $p.Check)
    $p.Version = $ex.Title
    # the links: GitHub, Report a bug, Discord (hidden while their Url is empty), View license, Full credits
    $p.Links = [Windows.Controls.WrapPanel]::new()
    $p.Links.Margin = [Windows.Thickness]::new(0, 6, 0, 4)
    foreach ($l in @($d.Links) + @(@{ Name = 'View license'; Url = $d.License.Url }, @{ Name = 'Full credits'; Url = $d.FullCredits })) {
        $b = New-AkariLink $l.Name $l.Url
        $b.Margin = [Windows.Thickness]::new(0, 0, 16, 0)
        $b.Visibility = if ($l.Url) { 'Visible' } else { 'Collapsed' }
        [void]$p.Links.Children.Add($b)
    }
    [void]$ex.Body.Children.Add((New-AkariExpanderRow $p.Links))
    # what's new, when the check found a release
    $p.Notes = New-AkariText '' 12 'Mu'
    $nh = [Windows.Controls.StackPanel]::new()
    [void]$nh.Children.Add((New-AkariText "What's new" 14 'Tx' 'SemiBold'))
    [void]$nh.Children.Add($p.Notes)
    $p.NotesRow = New-AkariExpanderRow $nh
    [void]$ex.Body.Children.Add($p.NotesRow)
    # the credits: the name (a link), what it gave AkariOS
    $p.Credits = [Collections.Generic.List[object]]::new()
    foreach ($c in $d.Credits) {
        $t = [Windows.Controls.StackPanel]::new()
        [void]$t.Children.Add((New-AkariLink $c.Name $c.Url))
        [void]$t.Children.Add((New-AkariText $c.Text 12 'Mu'))
        $row = New-AkariExpanderRow $t
        $p.Credits.Add($row)
        [void]$ex.Body.Children.Add($row)
    }
    $p.License = $ex.Desc
    [void]$StepBody.Children.Add($ex.Card)
    $script:AboutParts = $p
    Update-AkariAboutUpdate
}

# Settings › About's update part, from the last check: "Checking..." with a ring, then the result
function Update-AkariAboutUpdate {
    $p = $script:AboutParts
    if (-not $p) { return }
    $s = $script:UpdateStatus
    $p.Status.Children.Clear()
    if ($script:UpdateChecking) {
        [void]$p.Status.Children.Add((New-AkariRing 16))
        $t = New-AkariText ('Checking' + [char]0x2026) 12 'Mu'; $t.Margin = [Windows.Thickness]::new(8, 0, 0, 0)
        [void]$p.Status.Children.Add($t)
    } else {
        $msg = if ($s) { $s.Message } else { 'Not checked yet' }
        $t = New-AkariText $msg 12 $(if ($s -and $s.Kind -eq 'Available') { 'AccText' } elseif ($s -and $s.Kind -eq 'Error') { 'Bad' } else { 'Mu' })
        $t.MaxWidth = 280; $t.TextTrimming = 'CharacterEllipsis'; $t.TextWrapping = 'NoWrap'; $t.ToolTip = $msg
        [void]$p.Status.Children.Add($t)
    }
    $p.Check.IsEnabled = -not $script:UpdateChecking
    $p.Update.Visibility = if ($s -and $s.Kind -eq 'Available') { 'Visible' } else { 'Collapsed' }
    $notes = if ($s -and $s.Kind -in 'Available', 'Blocked', 'Latest' -and $s.Release.Notes) { ConvertTo-AkariNotesText $s.Release.Notes } else { '' }
    $p.Notes.Text = $notes
    $p.NotesRow.Visibility = if ($notes) { 'Visible' } else { 'Collapsed' }
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

# the check is done: remember it, show it on Home (its InfoBar) and in Settings, and on launch ask while the user is
# still on Home
function Complete-AkariUpdateCheck($Release, [bool]$Manual) {
    $script:UpdateChecking = $false
    $s = Get-AkariUpdateStatus $AkariVersion $Release $AkariInstallDir ([bool]($script:Busy -or $script:Job))
    $script:UpdateStatus = $s
    Add-Log "Update check: $($s.Message)"
    if ($script:Cat -eq 'Settings') { Update-AkariAboutUpdate }
    if ($script:Cat -eq 'Home' -and $s.Kind -in 'Available', 'Blocked' -and -not $script:UpdateDismissed) { $script:PageMotionKey = ''; Show-Page }
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
