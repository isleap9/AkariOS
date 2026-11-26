# The support file (plan docs/plans/2026-11-26-new-features.md, X1): a zip with what a bug report needs (akari.log,
# the state, settings and activity files, a saved Run, system.txt), the user's and the PC's names taken out of every
# text. Nothing is sent anywhere. The native app's AkariOS.Core/Support/SupportFile.cs does the same;
# SupportOracleTests compares ConvertTo-AkariSupportText's output.

# profile folders whose name is Windows', not a person's
$AkariSupportKeepProfiles = 'Public', 'Default', 'Default User', 'All Users'

# (pure) the text with every profile path's user folder as <user>, then each user name as <user> and the computer's
# name as <pc>, whole words, ignoring case; names shorter than 2 characters are left alone
function ConvertTo-AkariSupportText([string]$Text, [string[]]$Users, [string]$Computer) {
    if (-not $Text) { return '' }
    $opt = [Text.RegularExpressions.RegexOptions]'IgnoreCase, CultureInvariant'
    $keep = ($AkariSupportKeepProfiles | ForEach-Object { [regex]::Escape($_) }) -join '|'
    $pattern = '(\b[a-z]:(?:\\\\|\\|/)Users(?:\\\\|\\|/))(?!(?:' + $keep + ')(?:\\|/|"|$))[^\\/"\r\n\s]+'
    $Text = [regex]::Replace($Text, $pattern, '$1<user>', $opt)
    $pairs = [Collections.Generic.List[object]]::new()
    foreach ($u in @($Users)) { if ("$u".Trim().Length -ge 2) { $pairs.Add([pscustomobject]@{ Name = "$u".Trim(); Token = '<user>' }) } }
    if ("$Computer".Trim().Length -ge 2) { $pairs.Add([pscustomobject]@{ Name = "$Computer".Trim(); Token = '<pc>' }) }
    # the longest first, so a name inside another one doesn't cut it
    foreach ($p in @($pairs | Sort-Object { - $_.Name.Length })) {
        $Text = [regex]::Replace($Text, '(?<!\w)' + [regex]::Escape($p.Name) + '(?!\w)', $p.Token, $opt)
    }
    $Text
}

# the names to take out: the account Akari runs as and the real user's profile folder (they differ when another
# administrator elevated it)
function Get-AkariSupportUsers {
    $list = [Collections.Generic.List[string]]::new()
    $list.Add([Environment]::UserName)
    try {
        $local = Get-AkariUserFolder 'Local AppData'
        if ($local) { $list.Add([IO.Path]::GetFileName([IO.Path]::GetDirectoryName([IO.Path]::GetDirectoryName($local)))) }
    } catch { }
    @($list | Where-Object { $_ } | Select-Object -Unique)
}

# the files that go in: the ones that exist are added by New-AkariSupportFile
function Get-AkariSupportFiles {
    @($AkariLogFile, $AkariStatePath, $AkariActivityPath, $AkariSettingsPath, $AkariRunPath, $AkariLastUsedPath) | Where-Object { $_ }
}

# system.txt's lines
function Get-AkariSupportInfo([string]$App = 'PowerShell app') {
    $nt = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -ErrorAction SilentlyContinue
    $yes = { param($b) if ($b) { 'Yes' } else { 'No' } }
    $admin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    $lines = [Collections.Generic.List[string]]::new()
    $lines.Add("AkariOS $AkariVersion ($App)")
    $lines.Add("Windows: $($nt.ProductName) $($nt.DisplayVersion), build $($nt.CurrentBuild).$($nt.UBR)")
    $lines.Add("Edition: $(Get-AkariEdition)")
    $lines.Add("Chassis: $(Get-AkariChassis)")
    $lines.Add("Virtual machine: $(& $yes (Test-AkariVirtualMachine))")
    $lines.Add("Safe Mode: $(& $yes (Test-AkariSafeMode))")
    $lines.Add("Administrator: $(& $yes $admin)")
    $gpus = @(Get-AkariGpus)
    if (-not $gpus.Count) { $lines.Add('GPU: none found') }
    foreach ($g in $gpus) {
        $d = Get-ItemProperty -LiteralPath $g.Path -ErrorAction SilentlyContinue
        $lines.Add("GPU: $($g.Name) ($($g.Vendor)), driver $($d.DriverVersion) $($d.DriverDate)".TrimEnd())
    }
    $lines.Add("Created: $((Get-Date).ToString('yyyy-MM-dd HH:mm'))")
    @($lines)
}

# a file's text while another program may be writing it
function Read-AkariSharedText([string]$Path) {
    $s = [IO.FileStream]::new($Path, 'Open', 'Read', 'ReadWrite, Delete')
    try { $r = [IO.StreamReader]::new($s, [Text.Encoding]::UTF8, $true); try { $r.ReadToEnd() } finally { $r.Dispose() } }
    finally { $s.Dispose() }
}

# writes the zip (replacing one already there): @{ Path; Count = the files added, system.txt not counted }
function New-AkariSupportFile([string]$Path, [string[]]$Files, [string[]]$Info, [string[]]$Users, [string]$Computer) {
    Add-Type -AssemblyName System.IO.Compression
    if ([IO.File]::Exists($Path)) { [IO.File]::Delete($Path) }
    $utf8 = [Text.UTF8Encoding]::new($false)
    $count = 0
    $zip = [IO.Compression.ZipArchive]::new([IO.File]::Open($Path, 'CreateNew'), 'Create')
    try {
        $add = {
            param($name, $text)
            $w = [IO.StreamWriter]::new($zip.CreateEntry($name).Open(), $utf8)
            try { $w.Write((ConvertTo-AkariSupportText $text $Users $Computer)) } finally { $w.Dispose() }
        }
        $names = @{}
        foreach ($f in @($Files)) {
            if (-not $f -or -not [IO.File]::Exists($f)) { continue }
            $name = [IO.Path]::GetFileName($f)
            if ($names.ContainsKey($name)) { continue }
            $names[$name] = $true
            try { & $add $name (Read-AkariSharedText $f); $count++ } catch { Write-ErrLog "Support file: $f not added ($($_.Exception.Message))" }
        }
        & $add 'system.txt' ((@($Info) -join "`r`n") + "`r`n")
    } finally { $zip.Dispose() }
    @{ Path = $Path; Count = $count }
}
