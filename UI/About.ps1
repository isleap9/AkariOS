# About & Updates: the version and the update check (Core\Update.ps1); credits, links and license come next.
# Full window, Back goes Home. The check runs in the background on every launch: an update found while the user is
# still on Home asks right away ("Update now / Later"); either way the Home bar shows it until Akari closes.
# Dot-sourced by Akari.ps1 after UI\Rows.ps1.

$script:UpdateStatus = $null
$script:UpdateChecking = $false

$UpdateOpen.Add_Click({ Select-AkariPage 'About' })
$AboutLink.Add_Click({ Select-AkariPage 'About' })

function Show-AkariAbout {
    $StepDots.Children.Clear()
    Set-AkariStepHeader 'About' $Pages['About'].Sub
    $StepBack.Visibility = 'Visible'
    $StepNext.Visibility = 'Collapsed'
    $p = @{}
    $card = [Windows.Controls.Border]::new()
    $card.SetResourceReference([Windows.FrameworkElement]::StyleProperty, 'SettingCard')
    $sp = [Windows.Controls.StackPanel]::new()
    $p.Version = New-AkariText "AkariOS $AkariVersion" 18
    $p.Version.FontWeight = 'SemiBold'
    $p.Status = New-AkariText '' 13 'Mu'
    $p.Status.Margin = [Windows.Thickness]::new(0, 4, 0, 12)
    $bar = [Windows.Controls.StackPanel]::new()
    $bar.Orientation = 'Horizontal'
    $p.Update = [Windows.Controls.Button]::new()
    $p.Update.SetResourceReference([Windows.FrameworkElement]::StyleProperty, 'Accent')
    $p.Update.Content = 'Update now'
    $p.Update.Margin = [Windows.Thickness]::new(0, 0, 8, 0)
    $p.Update.Add_Click({ Start-AkariUpdateInstall })
    $p.Check = [Windows.Controls.Button]::new()
    $p.Check.SetResourceReference([Windows.FrameworkElement]::StyleProperty, 'Btn')
    $p.Check.Content = 'Check for updates'
    $p.Check.Margin = [Windows.Thickness]::new(0, 0, 8, 0)
    $p.Check.Add_Click({ Start-AkariUpdateCheck $true })
    $p.GitHub = [Windows.Controls.Button]::new()
    $p.GitHub.SetResourceReference([Windows.FrameworkElement]::StyleProperty, 'Btn')
    $p.GitHub.Content = 'Open on GitHub'
    $p.GitHub.Add_Click({
        $u = if ($script:UpdateStatus -and $script:UpdateStatus.Release.PageUrl) { $script:UpdateStatus.Release.PageUrl } else { "https://github.com/$AkariRepo/releases" }
        Start-Process $u
    })
    foreach ($b in $p.Update, $p.Check, $p.GitHub) { [void]$bar.Children.Add($b) }
    # the release notes, as plain text
    $p.NotesHead = New-AkariText "What's new" 14
    $p.NotesHead.FontWeight = 'SemiBold'
    $p.NotesHead.Margin = [Windows.Thickness]::new(0, 16, 0, 6)
    $p.Notes = New-AkariText '' 13 'Mu'
    foreach ($x in $p.Version, $p.Status, $bar, $p.NotesHead, $p.Notes) { [void]$sp.Children.Add($x) }
    $card.Child = $sp
    $script:AboutParts = $p
    Update-AkariAboutUpdate
    $StepBody.Children.Clear()
    [void]$StepBody.Children.Add($card)
}

# the About page's update part, from the last check
function Update-AkariAboutUpdate {
    $p = $script:AboutParts
    if (-not $p) { return }
    $s = $script:UpdateStatus
    $p.Status.Text = if ($script:UpdateChecking) { 'Checking for updates' + [char]0x2026 } elseif ($s) { $s.Message } else { 'Not checked yet.' }
    $p.Check.IsEnabled = -not $script:UpdateChecking
    $p.Update.Visibility = if ($s -and $s.Kind -eq 'Available') { 'Visible' } else { 'Collapsed' }
    $notes = if ($s -and $s.Kind -in 'Available', 'Blocked', 'Latest' -and $s.Release.Notes) { ConvertTo-AkariNotesText $s.Release.Notes } else { '' }
    $p.Notes.Text = $notes
    $p.Notes.Visibility = if ($notes) { 'Visible' } else { 'Collapsed' }
    $p.NotesHead.Visibility = $p.Notes.Visibility
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

# the check is done: remember it, show it on Home and About, and on launch ask while the user is still on Home
function Complete-AkariUpdateCheck($Release, [bool]$Manual) {
    $script:UpdateChecking = $false
    $s = Get-AkariUpdateStatus $AkariVersion $Release $AkariInstallDir ([bool]($script:Busy -or $script:Job))
    $script:UpdateStatus = $s
    Add-Log "Update check: $($s.Message)"
    $found = $s.Kind -in 'Available', 'Blocked'
    $UpdateText.Text = $s.Message
    $UpdateBar.Visibility = if ($found) { 'Visible' } else { 'Collapsed' }
    if ($script:Cat -eq 'About') { Update-AkariAboutUpdate }
    if (-not $Manual -and $s.Kind -eq 'Available' -and $script:Cat -eq 'Home' -and -not $Search.Text) { Show-AkariUpdatePrompt $s }
}

# the launch prompt: the notes (shortened) and Update now / Later
function Show-AkariUpdatePrompt($Status) {
    $notes = ConvertTo-AkariNotesText $Status.Release.Notes
    if ($notes.Length -gt 600) { $notes = $notes.Substring(0, 600).TrimEnd() + [char]0x2026 }
    $q = "$($Status.Message)`n`n" + $(if ($notes) { "What's new:`n$notes`n`n" } else { '' }) +
         "Update now? Akari closes, installs it and opens again. Your presets and settings are kept.`n`n(No = later)"
    if ([Windows.MessageBox]::Show($q, 'AkariOS update', 'YesNo', 'Information') -eq 'Yes') { Start-AkariUpdateInstall }
}

# downloads and checks the release in the background; when it is ready the helper is waiting and Akari closes
function Start-AkariUpdateInstall {
    if ($script:Busy -or -not $script:UpdateStatus) { return }
    # checked again: something may have started since the check
    $s = Get-AkariUpdateStatus $AkariVersion $script:UpdateStatus.Release $AkariInstallDir ([bool]$script:Job)
    if ($s.Kind -ne 'Available') { [void][Windows.MessageBox]::Show($s.Message, 'AkariOS update'); return }
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
        [void][Windows.MessageBox]::Show($r.Message, 'AkariOS update', 'OK', 'Warning')
    })
    $t.Start()
}

# every launch: check in the background once the window is up
$window.Add_Loaded({ Start-AkariUpdateCheck $false })
