# Install USB (plan docs/plans/2026-10-29-usb-setup-file.md): a full port of Christoph Schneegans' unattend generator
# (https://schneegans.de/windows/unattend-generator/, MIT), in Core\Unattend\ (Engine, Setup, Disk, ...; his data files
# and license in Core\Unattend\Data\). The choices are his form's fields; a file carries them as its first comment (his
# bookmark URL, without passwords), so a file from his site or from Akari opens again in the form.
foreach ($f in 'Engine', 'Setup', 'Disk', 'Later') { . (Join-Path $PSScriptRoot "Unattend\$f.ps1") }

# the fields a password lives in: never written to the comment
$AkariUaSecretFields = @('BuiltinAdministratorPassword', 'WifiPassword') + @(0..14 | ForEach-Object { "AccountPassword$_" })

# the answer file's bytes for $Fields: the XML (ASCII, as setup reads it) with the choices as its first comment
function New-AkariUnattend([hashtable]$Fields) {
    $doc = New-AkariUnattendXml $Fields
    [void]$doc.DocumentElement.PrependChild($doc.CreateComment((ConvertTo-AkariUnattendQuery $Fields)))
    , (ConvertTo-AkariUaBytes $doc)
}

# the fields as his bookmark URL (no passwords; '--' can't be in a comment, so it is %2D%2D)
function ConvertTo-AkariUnattendQuery([hashtable]$Fields) {
    $pairs = foreach ($k in @($Fields.Keys | Sort-Object)) {
        if ($k -in $AkariUaSecretFields) { continue }
        foreach ($v in @($Fields[$k])) { if ($null -ne $v) { [uri]::EscapeDataString($k) + '=' + [uri]::EscapeDataString([string]$v).Replace('-', '%2D') } }
    }
    "$($AkariUaSite)?$($pairs -join '&')"
}

# the fields of a file made by his site or by Akari (its first comment), or $null
function ConvertFrom-AkariUnattend([string]$Xml) {
    if ($Xml -notmatch '<!--(https://schneegans\.de/windows/unattend-generator/\?[^>]*?)-->') { return $null }
    ConvertFrom-AkariUnattendQuery $Matches[1]
}
function ConvertFrom-AkariUnattendQuery([string]$Url) {
    $f = @{}
    $q = $Url.Substring($Url.IndexOf('?') + 1)
    foreach ($p in $q.Split('&')) {
        if (-not $p) { continue }
        $i = $p.IndexOf('=')
        $k = [uri]::UnescapeDataString($p.Substring(0, [Math]::Max($i, 0)).Replace('+', ' '))
        $v = if ($i -ge 0) { [uri]::UnescapeDataString($p.Substring($i + 1).Replace('+', ' ')) } else { '' }
        if (-not $k) { continue }
        if ($f.ContainsKey($k)) { $f[$k] = @($f[$k]) + $v } else { $f[$k] = $v }
    }
    $f
}

# the text areas' starting text, as his page fills them: the generated scripts for its sample settings
function Get-AkariUnattendSamples {
    $target = @{ Fields = @{ TargetDiskNoPartitions = 'true'; TargetDiskSize = 'true'; TargetDiskMinSize = '100'; TargetDiskMaxSize = '4000'; TargetDiskIndex = 'true'; TargetDisk = '0' } }
    $pe = @{ Fields = @{ PEMode = 'Generated'; PartitionMode = 'Unattended'; TargetDiskMode = 'Generated'; PartitionLayout = 'Automatic'; RecoveryMode = 'Partition'
        SystemSize = '300'; RecoverySize = '1000'; InstallFromMode = 'Edition'; InstallFromEdition = 'pro'; PagingFileMode = 'Automatic'
        Disable8Dot3Names = 'true'; DisableDefender = 'true'; LanguageMode = 'Unattended'; UILanguage = 'en-US'; Locale = 'en-US'; Keyboard = '00000409'; GeoLocation = '244' } + $target.Fields }
    @{
        TargetDiskScript   = (Get-AkariUaTargetDiskScript $target) -join "`r`n"
        DiskpartScript     = (@(Get-AkariUaDiskpartScript '0' 'GPT' $true 300 1000) | Where-Object { $_ }) -join "`r`n"
        PEScript           = (Get-AkariUaPEScript $pe) -join "`r`n"
        ComputerNameScript = "return 'DESKTOP-{0:D3}' -f ( Get-Random -Minimum 0 -Maximum 999 );"
        WifiProfileXml     = Get-AkariUaResource 'WLANProfile.xml'
    }
}

# this PC's display language, locale, keyboard, home location and time zone, as fields (the form starts from them)
function Get-AkariUnattendDefaults {
    $kb = try { @((Get-WinUserLanguageList)[0].InputMethodTips)[0] } catch { $null }
    @{
        UILanguage  = [Globalization.CultureInfo]::InstalledUICulture.Name
        Locale      = (Get-Culture).Name
        Keyboard    = if ($kb -match '^[0-9A-Fa-f]{4}:([0-9A-Fa-f]{8})$') { $Matches[1].ToLowerInvariant() } else { '00000409' }
        GeoLocation = [string]$(try { (Get-WinHomeLocation).GeoId } catch { 244 })
        TimeZone    = (Get-TimeZone).Id
    }
}

# the drives a setup file can go on: removable ones, and any other holding Windows setup (a USB SSD shows as fixed),
# never the system drive. @{ Root = 'E:\'; Label; Setup = holds sources\install.wim|esd|swm }
function Get-AkariSetupDrives {
    foreach ($d in @(Get-CimInstance Win32_LogicalDisk)) {
        if ($d.DeviceID -eq $env:SystemDrive -or $d.DriveType -notin 2, 3) { continue }
        $root = "$($d.DeviceID)\"
        $setup = [bool](@('install.wim', 'install.esd', 'install.swm') | Where-Object { Test-Path -LiteralPath "$($root)sources\$_" })
        if ($d.DriveType -eq 2 -or $setup) { [pscustomobject]@{ Root = $root; Label = "$($d.VolumeName)"; Setup = $setup } }
    }
}

# writes autounattend.xml ($Bytes) in $Folder (made if missing; an existing file is replaced: the page asks first); its path
function Save-AkariUnattend([byte[]]$Bytes, [string]$Folder) {
    $dir = (New-Item -ItemType Directory -Path $Folder -Force).FullName
    $path = Join-Path $dir 'autounattend.xml'
    [IO.File]::WriteAllBytes($path, $Bytes)
    $path
}
