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

# names of the removable packages installed for any user: no frameworks, resource or system packages, no never-list
function Get-AkariAppxInstalled {
    @(Get-AkariAppxPackages | Where-Object {
        -not $_.IsFramework -and -not $_.IsResourcePackage -and -not $_.NonRemovable -and "$($_.SignatureKind)" -ne 'System' -and
        -not (Test-AkariAppxNever $_.Name)
    } | ForEach-Object { $_.Name } | Sort-Object -Unique)
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
