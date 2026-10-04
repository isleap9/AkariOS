# ── AkariOS Setup — UI wiring ────────────────────────────────────────────────
# Last block of the compiled akarios.ps1. Consumes everything defined above it:
# start.ps1 ($sync, DwmApi), the function files, the embedded $inputXML, and the
# base64 $sync.assets.

# ── Parse XAML ───────────────────────────────────────────────────────────────
try {
    $sync.window = [Windows.Markup.XamlReader]::Parse($inputXML)
} catch {
    [System.Windows.MessageBox]::Show("XAML Error: $_", "AkariOS Setup")
    exit
}

# Store every named control in $sync so functions can reach it by name.
# SelectNodes("//*[@Name]") matches the plain `Name="..."` attribute — panels must
# use `Name`, never the `x:Name` alias, or the control will not be registered here.
([xml]$inputXML).SelectNodes("//*[@Name]") | ForEach-Object {
    $sync[$_.Name] = $sync.window.FindName($_.Name)
}

# ── Status bar helper (call from runspaces via Dispatcher) ───────────────────
function Set-Status {
    param([string]$Text, [string]$Color = "White")
    $sync.window.Dispatcher.Invoke([action]{
        if ($sync.StatusText) {
            $sync.StatusText.Text       = $Text
            $sync.StatusText.Foreground = $Color
        }
    }, "Normal")
}

# ── Mica + dark title bar on window load ─────────────────────────────────────
$sync.window.Add_Loaded({
    $helper = New-Object System.Windows.Interop.WindowInteropHelper($sync.window)
    $hwnd   = $helper.Handle

    try {
        # Dark title bar (DWMWA_USE_IMMERSIVE_DARK_MODE = 20)
        $dark = 1
        [DwmApi]::DwmSetWindowAttribute($hwnd, 20, [ref]$dark, 4) | Out-Null

        # Extend frame so Mica reaches the title bar
        $m = New-Object DwmApi+MARGINS
        $m.Left = -1; $m.Right = -1; $m.Top = -1; $m.Bottom = -1
        [DwmApi]::DwmExtendFrameIntoClientArea($hwnd, [ref]$m) | Out-Null

        # Mica Alt (DWMWA_SYSTEMBACKDROP_TYPE = 38, value 4 = MicaAlt / 2 = Mica)
        $mica = 2
        [DwmApi]::DwmSetWindowAttribute($hwnd, 38, [ref]$mica, 4) | Out-Null

        # Make the WPF background transparent so Mica shows through
        $sync.window.Background = [System.Windows.Media.Brushes]::Transparent
    } catch {
        # Mica unavailable (Win10 / older build) — keep fallback dark background from XAML
    }
})

# ── Navigation switching ─────────────────────────────────────────────────────
# $panels : every ScrollViewer page name in the UI. Only one is visible at a time;
#           the rest are collapsed. The names must match Name= in xaml/panels/*.xaml.
# $navMap : sidebar RadioButton (NavXyz in MainWindow.xaml) -> the panel it shows.
# To add a page: add a NavXyz to MainWindow.xaml, a xaml/panels/NN-Xyz.xaml
# fragment, and register the pair in $panels/$navMap/$navNames below.
$panels = @(
    "PanelHome", "PanelCheck", "PanelProgress", "PanelState"
)

$navMap = @{
    NavHome     = "PanelHome"
    NavCheck    = "PanelCheck"
    NavProgress = "PanelProgress"
    NavState    = "PanelState"
}

$navNames = @("NavHome","NavCheck","NavProgress","NavState")

# Show a specific panel, optionally selecting the matching sidebar row.
function Show-Panel {
    param([string]$PanelName)
    if (-not $PanelName -or -not $sync[$PanelName]) { return }
    foreach ($p in $panels) {
        if ($sync[$p]) { $sync[$p].Visibility = [System.Windows.Visibility]::Collapsed }
    }
    $sync[$PanelName].Visibility = [System.Windows.Visibility]::Visible
    $navKey = ($navMap.GetEnumerator() | Where-Object { $_.Value -eq $PanelName } | Select-Object -First 1).Key
    if ($navKey -and $sync[$navKey] -and -not $sync[$navKey].IsChecked) { $sync[$navKey].IsChecked = $true }
}

foreach ($navName in $navMap.Keys) {
    $target = $navMap[$navName]
    $sync[$navName].Add_Checked({
        param($s, $e)
        $t = $navMap[$s.Name]
        $panels | ForEach-Object {
            if ($sync[$_]) { $sync[$_].Visibility = [System.Windows.Visibility]::Collapsed }
        }
        $sync[$t].Visibility = [System.Windows.Visibility]::Visible
    }.GetNewClosure())
}

# ── Wire all buttons to their Invoke-* functions ─────────────────────────────
# Convention: a Button named BtnInstall is handled by Invoke-BtnInstall in
# functions/public/. Keep button Name and function name in sync.
$sync.Keys | Where-Object { $_ -like "Btn*" } | ForEach-Object {
    $btnName = $_
    if ($sync[$btnName] -and $sync[$btnName].GetType().Name -eq "Button") {
        $sync[$btnName].Add_Click({
            $fn = "Invoke-$($btnName)"
            if (Get-Command $fn -ErrorAction SilentlyContinue) {
                & $fn
            }
        }.GetNewClosure())
    }
}

# ── Launch-time integration ───────────────────────────────────────────────────

# 1. Log first, so anything that fails afterwards is recorded.
#    The missing-asset line is the cheapest guard against RESEARCH Finding 6 (a
#    .reg or .ps1 that Compile.ps1 silently skipped): it lands in install.log,
#    which is the only thing readable off a VM when a stage fails for no visible
#    reason.
try {
    $assetNames = @()
    if ($sync.assets) { $assetNames = @($sync.assets.Keys) }
    $requiredAssets = @("winsux", "stepone", "steptwo", "reg")
    $missingAssets = @($requiredAssets | Where-Object { $assetNames -notcontains $_ })
    Initialize-AkariOSLog -Banner @(
        ("State file: " + $script:AkariOSStateDefaultPath),
        ("Assets embedded: " + ($assetNames -join ", ")),
        ("Missing engine assets: " + $(if ($missingAssets.Count) { $missingAssets -join ", " } else { "none" }))
    )
    if ($missingAssets.Count) {
        Write-AkariOSLog -Level ERROR -Message ("Missing engine assets: " + ($missingAssets -join ", "))
    }
} catch {
    # Logging must never block startup.
}

# 2. Seed the progress panel with the UI-SPEC stage descriptions (SAFE-03).
foreach ($n in 1..3) {
    $info = Get-StageExplanation -Number $n
    $ctl  = $sync["Stage{0}Headline" -f $n]
    if ($ctl -and $info.Description) { $ctl.Text = $info.Description }
}
Set-ProgressIdle

# 3. Resume detection on launch (PROG-02). Get-ResumePoint reads the bcdedit
#    safeboot flag and the RunOnce entries; state.json only corroborates.
#    Failures here must not stop the app - the user can still start fresh.
try {
    $resume = Get-ResumePoint
    Write-AkariOSLog -Level INFO -Message ("Resume detection: {0} ({1})" -f $resume.ResumePoint, $resume.Reason)

    $evidence = "safeboot: {0} - RunOnce: stage2={1}, stage3={2} - state.json: stage {3} ({4})" -f `
        $(if ($resume.Safeboot) { $resume.Safeboot } else { "not set" }),
        $resume.HasStage2, $resume.HasStage3, $resume.StateStage, $resume.StateStatus
    if ($sync.StateEvidence)  { $sync.StateEvidence.Text  = $evidence }
    if ($sync.StateDetail)   { $sync.StateDetail.Text   = $resume.Reason }

    switch ($resume.ResumePoint) {
        "fresh" {
            if ($sync.StateHeadline) { $sync.StateHeadline.Text = "Ready to install" }
            if ($sync.BtnResume)     { $sync.BtnResume.Visibility = [System.Windows.Visibility]::Collapsed }
        }
        { $_ -in @("stage1","stage2","stage3") } {
            $stageNo = switch ($resume.ResumePoint) { "stage1" {1} "stage2" {2} "stage3" {3} }
            if ($sync.StateHeadline) { $sync.StateHeadline.Text = Format-ResumeStep -Stage $stageNo }
            if ($sync.BtnResume) {
                $sync.BtnResume.Visibility = [System.Windows.Visibility]::Visible
                $sync.BtnResume.IsEnabled  = $true
            }
            if ($resume.ResumePoint -ne "stage1") {
                # Safe Mode / later stages cannot be cancelled or driven from the
                # GUI; the console stage script is already queued via RunOnce.
                Set-Status "Resuming Step $stageNo of 3 - the queued stage script will run at boot." "#FFA726"
            }
        }
        "inconsistent" {
            # D-05: no CTA, the user must resolve it manually.
            if ($sync.StateHeadline)      { $sync.StateHeadline.Text = "Inconsistent state detected" }
            if ($sync.StateInconsistent)  { $sync.StateInconsistent.Visibility = [System.Windows.Visibility]::Visible }
            if ($sync.BtnResume)          { $sync.BtnResume.Visibility = [System.Windows.Visibility]::Collapsed }
            Set-Status "Inconsistent installation state - see the State page." "#FF6B6B"
            Write-AkariOSLog -Level ERROR -Message ("Inconsistent state: " + $resume.Reason)
            Show-Panel "PanelState"
        }
    }
} catch {
    Write-AkariOSLog -Level WARN -Message "Resume detection failed: $_"
    if ($sync.StateHeadline) { $sync.StateHeadline.Text = "Ready to install" }
}

# 4. Cancel starts disabled: nothing is running (SAFE-04).
Sync-CancelButton | Out-Null

# 5. Install stays disabled until pre-flight checks pass (PREF-02).
Set-InstallButtonEnabled -Enabled $false

# 6. Stage-status reconciliation (Plan 02-02).
#    Decides two things from what the ENGINE actually did, not from what the UI
#    last drew:
#      - whether the Safe Mode handoff copy has to be visible, and
#      - whether the per-stage run buttons are live.
#
#    It runs its own try/catch for the same reason step 3 does: a throw between
#    here and ShowDialog() would leave the user with no window at all and no
#    explanation.
#
#    Source of truth is Get-ResumePoint (bcdedit + RunOnce), per D-01. It is
#    deliberately NOT state.json: Progress.ps1:101 writes -Status "installing",
#    which is not in the ValidateSet at State.ps1:111, so that call throws into
#    its own catch and within-stage progress is never persisted. Fixing that is
#    out of Phase 2's scope, and reading state.json here would show a stage the
#    machine is not actually in. $resume.StateStage is logged as corroboration
#    only, and never decides what the UI claims (T-02-15).
#
#    The resume switch at step 3 is NOT modified and no "error" case is added to
#    it (RESEARCH §7 Decision 3): Phase 1's verified D-03/D-05 behaviour must stay
#    byte-identical. Everything below works off the value step 3 already computed,
#    which is why a failed resume detection simply leaves the buttons disabled.
try {
    if ($resume -and $resume.ResumePoint -and $resume.ResumePoint -in @("stage1", "stage2", "stage3")) {
        $pendingStage = switch ($resume.ResumePoint) { "stage1" {1} "stage2" {2} "stage3" {3} }

        # A machine that came back into NORMAL boot with stage2 pending is the
        # recoverable case the hint text describes (safeboot cleared by
        # stepone.ps1:148, no reboot performed because DDU never launched). The
        # user needs the Stage 2 explanation on screen, so show it here too and
        # not only when Stage 2 is launched by hand.
        if ($resume.ResumePoint -eq "stage2") {
            if (Get-Command Show-StageHandoffHint -ErrorAction SilentlyContinue) {
                Show-StageHandoffHint -Visible -ProbePending
            } elseif ($sync.StageHandoffHint) {
                $sync.StageHandoffHint.Visibility = [System.Windows.Visibility]::Visible
            }
        }

        # Per-stage buttons are a testing affordance (T-02-18): they are live only
        # when there is a real pending stage to act on. On "fresh" they stay
        # disabled exactly as 02-Progress.xaml declares them.
        foreach ($n in 1..3) {
            $btn = $sync["BtnStage{0}" -f $n]
            if ($btn) { $btn.IsEnabled = $true }
        }

        Write-AkariOSLog -Level INFO -Message (
            "Stage buttons enabled; pending {0} (state.json corroborates stage {1}, status '{2}')" -f
            $pendingStage, $resume.StateStage, $resume.StateStatus)
    } else {
        foreach ($n in 1..3) {
            $btn = $sync["BtnStage{0}" -f $n]
            if ($btn) { $btn.IsEnabled = $false }
        }
        Write-AkariOSLog -Level INFO -Message "No pending stage detected - per-stage buttons stay disabled."
    }
} catch {
    # Never fatal: a reconciliation failure must not stop the app opening.
    Write-AkariOSLog -Level WARN -Message "Stage-status reconciliation failed: $_"
}

# ── Show window ───────────────────────────────────────────────────────────────
$sync.window.ShowDialog() | Out-Null