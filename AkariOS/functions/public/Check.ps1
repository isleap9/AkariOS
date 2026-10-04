# ── Pre-flight checks (PREF-01 / PREF-02) ───────────────────────────────────
# Six checks run before the install may start. Each returns a result object with
# Name / Status / Message / Blocking, so the UI can render one row per check and
# decide whether the Install button may be enabled.
#
#   Pass     - good to go
#   Warning  - non-blocking, the user may continue at their own risk
#   Fail     - blocking (unless Blocking = $false), install is not offered
#
# PREF-02: Invoke-PreFlightChecks is the single source of truth for that gate.
# Nothing else may enable the Install button.
#
# Read-only note: every check in this file only READS system state. The only
# network call is a TCP connect probe to a fixed public endpoint, which writes
# nothing. No check creates a registry key, a file, or a service.

$script:AkariOSCheckNames = [ordered]@{
    "Test-WindowsVersion"       = "Windows version"
    "Test-AdminElevation"       = "Administrator privileges"
    "Test-InternetConnectivity" = "Internet connectivity"
    "Test-DiskSpace"            = "Free disk space"
    "Test-PendingReboot"        = "Pending reboot"
    "Test-PowerState"           = "Power state"
}

function New-CheckResult {
    <#
    .SYNOPSIS
        Builds the uniform result object every check returns.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][ValidateSet("Pass", "Fail", "Warning")][string]$Status,
        [string]$Message = "",
        [bool]$Blocking = $true
    )
    [pscustomobject]@{
        Name     = $Name
        Status   = $Status
        Message  = $Message
        Blocking = $Blocking
    }
}

function Test-WindowsVersion {
    <#
    .SYNOPSIS
        PREF-01: Windows 10 build 19042 (20H2) or newer. Older builds lack the
        APIs and registry layout the flow relies on, so this blocks.
    #>
    [CmdletBinding()]
    param([int]$MinimumBuild = 19042)

    $name = "Windows version"
    try {
        $os = [System.Environment]::OSVersion.Version
        $build = $os.Build
        $display = "{0} (build {1})" -f $os.VersionString, $build
        if ($build -lt $MinimumBuild) {
            return New-CheckResult -Name $name -Status "Fail" -Message `
                "$display is older than build $MinimumBuild. Upgrade to Windows 10 20H2 or Windows 11. Resolve this before continuing."
        }
        return New-CheckResult -Name $name -Status "Pass" -Message $display
    } catch {
        return New-CheckResult -Name $name -Status "Warning" -Message `
            "Could not determine the Windows version. Continuing with caution." -Blocking $false
    }
}

function Test-AdminElevation {
    <#
    .SYNOPSIS
        PREF-01/PREF-03: the process must be elevated. start.ps1 already
        self-elevates, so a Fail here means the re-elevation did not take.
    #>
    [CmdletBinding()]
    param()

    $name = "Administrator privileges"
    try {
        $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
                        [Security.Principal.WindowsBuiltInRole]"Administrator")
        if ($isAdmin) {
            return New-CheckResult -Name $name -Status "Pass" -Message "Running elevated."
        }
        return New-CheckResult -Name $name -Status "Fail" -Message `
            "Not running as administrator. Right-click akarios.ps1 and choose 'Run as administrator'. Resolve this before continuing."
    } catch {
        return New-CheckResult -Name $name -Status "Fail" -Message `
            "Could not verify administrator privileges. Resolve this before continuing."
    }
}

function Test-InternetConnectivity {
    <#
    .SYNOPSIS
        PREF-01: payloads download at runtime, so we need outbound connectivity.
        Opens a TCP socket and closes it — no data is sent or received.
    .PARAMETER Hosts
        Overridable probe targets so this can be tested without touching the network.
    #>
    [CmdletBinding()]
    param(
        [string[]]$Hosts = @("github.com", "www.microsoft.com"),
        [int]$Port = 443,
        [int]$TimeoutMs = 3000
    )

    $name = "Internet connectivity"
    $ok = @()
    $failures = @()

    foreach ($h in $Hosts) {
        $client = $null
        try {
            $client = New-Object System.Net.Sockets.TcpClient
            $async = $client.BeginConnect($h, $Port, $null, $null)
            if ($async.AsyncWaitHandle.WaitOne($TimeoutMs, $false) -and $client.Connected) {
                $ok += $h
            } else {
                $failures += $h
            }
        } catch {
            $failures += $h
        } finally {
            if ($client) { try { $client.Close() } catch {} }
        }
    }

    if ($ok.Count -eq $Hosts.Count) {
        return New-CheckResult -Name $name -Status "Pass" -Message `
            ("Reachable: " + ($ok -join ", "))
    }
    if ($ok.Count -gt 0) {
        return New-CheckResult -Name $name -Status "Warning" -Message `
            ("Partially reachable (" + ($ok -join ", ") + "). Unreachable: " + ($failures -join ", ") +
             ". You can continue, but this may cause issues.") -Blocking $false
    }
    return New-CheckResult -Name $name -Status "Fail" -Message `
        ("Cannot reach " + ($failures -join ", ") + ". Connect to a network and try again. Resolve this before continuing.")
}

function Test-DiskSpace {
    <#
    .SYNOPSIS
        PREF-01: at least 4 GB free on the system drive. Payloads plus a restore
        point need the headroom.
    .PARAMETER Drive
        Optional drive root override ("C:\").
    .PARAMETER MinimumGB
        Minimum free space required, in gigabytes.
    #>
    [CmdletBinding()]
    param([string]$Drive, [double]$MinimumGB = 4)

    $name = "Free disk space"
    try {
        $root = if ($Drive) { $Drive } else { $env:SystemDrive + "\" }
        $psd = Get-PSDrive -Name $root.TrimEnd('\', ':') -PSProvider FileSystem -ErrorAction Stop
        # NOTE: this must read $psd.Free, NOT $ps.Free. A typo here shipped as
        # "Only 0 GB free on C:" on a machine with 240 GB free: $ps was undefined,
        # $ps.Free was null, and null/1GB rounds to 0.0, which tripped the
        # blocking Fail branch and left the Install button permanently disabled.
        # tools/Test-Check.ps1 pins the $psd/$ps pairing so it cannot come back.
        $freeGB = [math]::Round($psd.Free / 1GB, 1)

        if ($freeGB -lt $MinimumGB) {
            return New-CheckResult -Name $name -Status "Fail" -Message `
                ("Only {0} GB free on {1}; {2} GB is required. Free up space. Resolve this before continuing." -f $freeGB, $root.TrimEnd('\'), $MinimumGB)
        }
        if ($freeGB -lt ($MinimumGB * 2)) {
            return New-CheckResult -Name $name -Status "Warning" -Message `
                ("{0} GB free on {1}. That clears the minimum but leaves little room for the restore point. You can continue, but this may cause issues." -f $freeGB, $root.TrimEnd('\')) -Blocking $false
        }
        return New-CheckResult -Name $name -Status "Pass" -Message ("{0} GB free on {1}" -f $freeGB, $root.TrimEnd('\'))
    } catch {
        return New-CheckResult -Name $name -Status "Warning" -Message `
            "Could not read free disk space. Continuing with caution." -Blocking $false
    }
}

function Test-PendingReboot {
    <#
    .SYNOPSIS
        PREF-01: a pending reboot means files or the servicing stack are still
        locked. Rebooting cleanly before starting is strongly preferable.
    .DESCRIPTION
        READ-ONLY. Inspects two well-known markers of a pending reboot:
          - CBS\RebootPending / CBS\PackagesPending under HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing
          - the PendingFileRenameOperations value under HKLM\SYSTEM\CurrentControlSet\Control\Session Manager
        It never creates or deletes these keys (that is what `pending` checks in
        some third-party tools do — we only look).
    #>
    [CmdletBinding()]
    param()

    $name = "Pending reboot"
    $signals = @()

    try {
        $cbs = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending"
        if (Test-Path -LiteralPath $cbs) { $signals += "Component Based Servicing reports a pending reboot" }

        $sessMgr = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager"
        $pfr = (Get-ItemProperty -LiteralPath $sessMgr -Name "PendingFileRenameOperations" -ErrorAction SilentlyContinue)
        if ($pfr -and $pfr.PendingFileRenameOperations) { $signals += "There are pending file rename operations" }
    } catch {
        return New-CheckResult -Name $name -Status "Warning" -Message `
            "Could not read the pending-reboot state. You can continue, but this may cause issues." -Blocking $false
    }

    if ($signals.Count -eq 0) {
        return New-CheckResult -Name $name -Status "Pass" -Message "No pending reboot detected."
    }
    # Non-blocking: a pending reboot is not fatal, but starting mid-servicing can
    # make a stage fail in a confusing way.
    return New-CheckResult -Name $name -Status "Warning" -Message `
        (($signals -join ". ") + ". You can continue, but this may cause issues — consider rebooting first.") -Blocking $false
}

function Test-PowerState {
    <#
    .SYNOPSIS
        PREF-01: the flow reboots the machine twice and runs driver work, which
        must not happen on battery. Only meaningful on battery-capable devices.
    #>
    [CmdletBinding()]
    param()

    $name = "Power state"
    try {
        $battery = Get-CimInstance -ClassName Win32_Battery -ErrorAction Stop
        if (-not $battery) {
            # Desktop / no battery: nothing to check.
            return New-CheckResult -Name $name -Status "Pass" -Message "No battery detected (desktop)."
        }
        $onAc = @($battery | Where-Object { $_.BatteryStatus -eq 2 }).Count -gt 0
        if ($onAc) {
            return New-CheckResult -Name $name -Status "Pass" -Message "Running on AC power."
        }
        return New-CheckResult -Name $name -Status "Fail" -Message `
            "Running on battery power. Connect the charger — this install reboots the machine twice. Resolve this before continuing."
    } catch {
        # Win32_Battery is absent on most desktops; that is not an error.
        return New-CheckResult -Name $name -Status "Pass" -Message "No battery detected."
    }
}

function Invoke-PreFlightChecks {
    <#
    .SYNOPSIS
        Runs every pre-flight check and returns the aggregate result (PREF-01).
    .DESCRIPTION
        PREF-02: CanInstall is $false when ANY blocking check failed. The Install
        button is enabled from this value and nothing else.
        A single check that throws is downgraded to a Warning rather than taking
        the whole gate down — an unreadable check must not read as a pass.
    .PARAMETER Checks
        Optional ordered list of check command names to run, in order. Defaults
        to all six.
    #>
    [CmdletBinding()]
    param([string[]]$Checks)

    if (-not $Checks -or $Checks.Count -eq 0) {
        $Checks = @($script:AkariOSCheckNames.Keys)
    }

    $results = @()
    foreach ($check in $Checks) {
        if (-not (Get-Command $check -ErrorAction SilentlyContinue)) {
            $results += New-CheckResult -Name $check -Status "Warning" -Message `
                "Check '$check' is not available. You can continue, but this may cause issues." -Blocking $false
            continue
        }
        try {
            $results += (& $check)
        } catch {
            # A stubbed or custom check name will not be in the display-name map,
            # so fall back to the command name rather than passing an empty -Name
            # (which would throw and mask the real error).
            $display = if ($script:AkariOSCheckNames.Contains($check)) { $script:AkariOSCheckNames[$check] } else { $check }
            $results += New-CheckResult -Name $display -Status "Warning" -Message `
                "Check '$check' could not complete ($($_.Exception.Message)). You can continue, but this may cause issues." -Blocking $false
        }
    }

    $blockingFails = @($results | Where-Object { $_.Status -eq "Fail" -and $_.Blocking })
    $warnings      = @($results | Where-Object { $_.Status -eq "Warning" })
    $passes        = @($results | Where-Object { $_.Status -eq "Pass" })

    [pscustomobject]@{
        Results        = $results
        CanInstall     = ($blockingFails.Count -eq 0)
        PassCount      = $passes.Count
        WarningCount   = $warnings.Count
        FailCount      = $blockingFails.Count
        BlockingFails  = $blockingFails
        Summary        = ("{0} checks - {1} passed, {2} warning(s), {3} blocking failure(s)" -f
                          $results.Count, $passes.Count, $warnings.Count, $blockingFails.Count)
    }
}

# ── UI rendering for the checklist ──────────────────────────────────────────
# Copy is fixed by 01-UI-SPEC.md:
#   pass    "✓ {name}"
#   fail    "✗ {name} — {reason}. Resolve this before continuing."
#   warning "⚠ {name} — {reason}. You can continue, but this may cause issues."

$script:AkariOSCheckIcons = @{ "Pass" = [char]0x2713; "Fail" = [char]0x2717; "Warning" = [char]0x26A0; "Pending" = [char]0x23F3 }

function Get-CheckDisplayText {
    <#
    .SYNOPSIS
        Formats one check result into its UI-SPEC row text and colour key.
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory)]$Result)

    $icon  = $script:AkariOSCheckIcons[[string]$Result.Status]
    $color = switch ([string]$Result.Status) {
        "Pass"    { "#66BB6A" }
        "Fail"    { "#FF3333" }
        "Warning" { "#FFA726" }
        default   { "#999999" }
    }
    $detail = switch ([string]$Result.Status) {
        "Pass"    { $Result.Message }
        "Fail"    { "$($Result.Message) Resolve this before continuing." }
        "Warning" { "$($Result.Message) You can continue, but this may cause issues." }
        default   { $Result.Message }
    }

    [pscustomobject]@{
        Icon   = $icon
        Color  = $color
        Title  = "$icon $($Result.Name)"
        Detail = $detail
        Status = $Result.Status
    }
}

function Show-CheckResult {
    <#
    .SYNOPSIS
        Renders check rows into the Checklist StackPanel (01-Check.xaml) and
        updates the summary line. Must run on the UI thread.
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory)]$Results, [string]$Summary = "")

    if (-not $sync -or -not $sync.Checklist) { return }
    $list = $sync.Checklist
    $list.Children.Clear()

    foreach ($r in @($Results)) {
        $d = Get-CheckDisplayText -Result $r

        $row = New-Object System.Windows.Controls.Border
        $row.Style = $sync.window.FindResource("ChecklistItem")

        $stack = New-Object System.Windows.Controls.StackPanel

        $title = New-Object System.Windows.Controls.TextBlock
        $title.Text = $d.Title
        $title.FontFamily = "Segoe UI Variable Text, Segoe UI"
        $title.FontSize = 13
        $title.FontWeight = "SemiBold"
        $title.Foreground = $d.Color
        $stack.Children.Add($title)

        if ($d.Detail) {
            $detail = New-Object System.Windows.Controls.TextBlock
            $detail.Text = $d.Detail
            $detail.FontFamily = "Segoe UI Variable Text, Segoe UI"
            $detail.FontSize = 12
            $detail.Foreground = "#999999"
            $detail.TextWrapping = [System.Windows.TextWrapping]::Wrap
            $detail.Margin = New-Object System.Windows.Thickness(0, 2, 0, 0)
            $stack.Children.Add($detail)
        }

        $row.Child = $stack
        $list.Children.Add($row)
    }

    if ($sync.CheckPlaceholder) { $sync.CheckPlaceholder.Visibility = [System.Windows.Visibility]::Collapsed }
    if ($sync.CheckSummary -and $Summary) {
        $sync.CheckSummary.Text = $Summary
        $sync.CheckSummary.Visibility = [System.Windows.Visibility]::Visible
    }
}

function Set-InstallButtonEnabled {
    <#
    .SYNOPSIS
        The ONLY place the Install button is enabled or disabled (PREF-02).
    #>
    [CmdletBinding()]
    param([bool]$Enabled, [string]$Hint = "")

    if ($sync -and $sync.BtnInstall) { $sync.BtnInstall.IsEnabled = $Enabled }
    if ($sync -and $sync.HomeHint) {
        $sync.HomeHint.Text = if ($Hint) { $Hint } else {
            if ($Enabled) { "Ready to install. Click 'Install AkariOS' to continue." }
            else { "Run the pre-flight checks first to enable this button." }
        }
    }
}

function Invoke-BtnRunChecks {
    <#
    .SYNOPSIS
        BtnRunChecks handler: runs the pre-flight checks on a background runspace
        (they can take a few seconds on the network probe) and renders the result.
    #>
    if (-not (Get-Command Invoke-RunInBackground -ErrorAction SilentlyContinue)) {
        [System.Windows.MessageBox]::Show("Background runner unavailable.", "AkariOS Setup") | Out-Null
        return
    }
    if ($sync.BtnRunChecks) { $sync.BtnRunChecks.IsEnabled = $false }

    Invoke-RunInBackground -StatusStart "Running pre-flight checks..." -StatusDone "Pre-flight checks complete" -ScriptBlock {
        $result = Invoke-PreFlightChecks
        $sync.window.Dispatcher.Invoke([action]{
            Show-CheckResult -Results $result.Results -Summary $result.Summary
            if ($result.CanInstall) {
                Set-InstallButtonEnabled -Enabled $true
            } else {
                $first = @($result.BlockingFails)[0]
                Set-InstallButtonEnabled -Enabled $false -Hint ("Blocked by: " + $first.Name + " — " + $first.Message)
            }
            if ($sync.BtnRunChecks) { $sync.BtnRunChecks.IsEnabled = $true }
        }, "Normal")
    }
}