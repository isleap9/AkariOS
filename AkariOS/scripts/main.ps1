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

# ── Show window ───────────────────────────────────────────────────────────────
$sync.window.ShowDialog() | Out-Null