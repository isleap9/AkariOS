# Appx: the engine side of the Remove tab: Store (AppX) apps (AppxRemove), Optional features (CapabilityRemove) and
# Windows features (FeatureDisable). Thin wrappers over the Appx and DISM cmdlets, so tests mock these functions and
# never touch a real package or feature (AGENTS.md rule 12).

# never listed and never removed: without them Explorer, the taskbar, Start or Settings break (FR33THY keep-list)
$AkariAppxNever = '*CBS*', 'Microsoft.Windows.ShellExperienceHost', 'Microsoft.Windows.StartMenuExperienceHost', 'windows.immersivecontrolpanel'

function Test-AkariAppxNever([string]$Package) {
    foreach ($p in $AkariAppxNever) { if ($Package -like $p) { return $true } }
    $false
}

# the raw package list (all users); a function so tests can mock it
function Get-AkariAppxPackages { @(Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue) }

# names of the removable packages installed for any user: no frameworks, resource or system packages, no never-list.
# $Packages: a list already read with Get-AkariAppxPackages (else it is read now)
function Get-AkariAppxInstalled($Packages = $null) {
    if ($null -eq $Packages) { $Packages = Get-AkariAppxPackages }
    @($Packages | Where-Object {
        -not $_.IsFramework -and -not $_.IsResourcePackage -and -not $_.NonRemovable -and "$($_.SignatureKind)" -ne 'System' -and
        -not (Test-AkariAppxNever $_.Name)
    } | ForEach-Object { $_.Name } | Sort-Object -Unique)
}

# package name -> the path of its app list logo (the Start menu's icon), for the Apps tables. Read from each
# package's AppxManifest.xml: the first app's Square44x44Logo, else the package Logo; of the files Windows made of it,
# an unplated 48 / 32 px one first. Packages with no readable logo are left out; never throws.
function Get-AkariAppxLogos($Packages) {
    $logos = @{}
    foreach ($p in @($Packages)) {
        try {
            if (-not $p.InstallLocation -or $logos.ContainsKey($p.Name)) { continue }
            $m = [xml][IO.File]::ReadAllText((Join-Path $p.InstallLocation 'AppxManifest.xml'))
            $bases = @(@($m.Package.Applications.Application | ForEach-Object { $_.VisualElements.Square44x44Logo }) + $m.Package.Properties.Logo | Where-Object { $_ })
            foreach ($b in $bases) {
                $file = Join-Path $p.InstallLocation $b
                $dir = Split-Path $file
                if (-not [IO.Directory]::Exists($dir)) { continue }
                $stem = [IO.Path]::GetFileNameWithoutExtension($file)
                $found = $null
                foreach ($q in 'targetsize-48_altform-unplated', 'targetsize-32_altform-unplated', 'targetsize-48', 'targetsize-32', 'scale-200', 'scale-100') {
                    $f = Join-Path $dir "$stem.$q.png"
                    if ([IO.File]::Exists($f)) { $found = $f; break }
                }
                if (-not $found -and [IO.File]::Exists($file)) { $found = $file }
                if (-not $found) { $found = @([IO.Directory]::GetFiles($dir, "$stem.*.png")) | Select-Object -First 1 }
                if ($found) { $logos[$p.Name] = $found; break }
            }
        } catch { }
    }
    $logos
}

function Test-AkariAppxInstalled([string]$Package) {
    [bool](Get-AkariAppxPackages | Where-Object { $_.Name -eq $Package } | Select-Object -First 1)
}

# removes the package for every user, then its provisioned copy (so a new user doesn't get it back)
function Remove-AkariAppx([string]$Package) {
    if (Test-AkariAppxNever $Package) { throw "$Package is needed by Windows and is never removed" }
    foreach ($p in @(Get-AkariAppxPackages | Where-Object { $_.Name -eq $Package })) {
        Remove-AppxPackage -Package $p.PackageFullName -AllUsers -ErrorAction Stop
    }
    Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -eq $Package } |
        ForEach-Object { Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName -ErrorAction SilentlyContinue | Out-Null }
}

# ---- Optional features (Windows capabilities) and Windows features (optional features): engine side of
# CapabilityRemove and FeatureDisable. Read and changed only through these functions (tests mock them).

# names of the capabilities installed on this PC (full names, with their version: 'App.StepsRecorder~~~~0.0.1.0')
function Get-AkariCapabilitiesInstalled {
    @(Get-WindowsCapability -Online -ErrorAction SilentlyContinue | Where-Object { "$($_.State)" -eq 'Installed' } |
        ForEach-Object { $_.Name } | Sort-Object -Unique)
}

function Test-AkariCapabilityInstalled([string]$Name) {
    "$((Get-WindowsCapability -Online -Name $Name -ErrorAction SilentlyContinue | Select-Object -First 1).State)" -eq 'Installed'
}

function Remove-AkariCapability([string]$Name) { Remove-WindowsCapability -Online -Name $Name -ErrorAction Stop | Out-Null }

# names of the Windows features turned on
function Get-AkariFeaturesEnabled {
    @(Get-WindowsOptionalFeature -Online -ErrorAction SilentlyContinue | Where-Object { "$($_.State)" -eq 'Enabled' } |
        ForEach-Object { $_.FeatureName } | Sort-Object -Unique)
}

function Test-AkariFeatureEnabled([string]$Name) {
    "$((Get-WindowsOptionalFeature -Online -FeatureName $Name -ErrorAction SilentlyContinue | Select-Object -First 1).State)" -eq 'Enabled'
}

function Disable-AkariFeature([string]$Name) {
    Disable-WindowsOptionalFeature -Online -FeatureName $Name -NoRestart -WarningAction SilentlyContinue -ErrorAction Stop | Out-Null
}

# ---- turning them on (Advanced > Features, winutil W2)

# a Windows feature's state as DISM names it (Enabled, Disabled, EnablePending, DisabledWithPayloadRemoved...), $null
# when this Windows has no such feature
function Get-AkariFeatureState([string]$Name) {
    $f = Get-WindowsOptionalFeature -Online -FeatureName $Name -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($f) { "$($f.State)" } else { $null }
}

# turns a Windows feature on with the features it needs, no restart; $Source (a Windows setup's sources\sxs) = its
# files from there, never from Windows Update
function Enable-AkariFeature([string]$Name, [string]$Source = '') {
    $p = @{ Online = $true; FeatureName = $Name; All = $true; NoRestart = $true; WarningAction = 'SilentlyContinue'; ErrorAction = 'Stop' }
    if ($Source) { $p.Source = $Source; $p.LimitAccess = $true }
    Enable-WindowsOptionalFeature @p | Out-Null
}

# a capability's state (Installed, NotPresent...), $null when this Windows has no such capability
function Get-AkariCapabilityState([string]$Name) {
    $c = Get-WindowsCapability -Online -Name $Name -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($c) { "$($c.State)" } else { $null }
}

# adds a capability (its files come from Windows Update)
function Add-AkariCapability([string]$Name) { Add-WindowsCapability -Online -Name $Name -ErrorAction Stop | Out-Null }

# the first <drive>\sources\sxs (a mounted Windows ISO or a setup USB stick), $null when no drive has one. $Roots: the
# drives' roots (default: every ready drive)
function Find-AkariWindowsSource([string[]]$Roots = @([IO.DriveInfo]::GetDrives() | Where-Object { $_.IsReady } | ForEach-Object { $_.RootDirectory.FullName })) {
    foreach ($r in $Roots) {
        $sxs = Join-Path $r 'sources\sxs'
        if (Test-Path -LiteralPath $sxs -PathType Container) { return $sxs }
    }
    $null
}
