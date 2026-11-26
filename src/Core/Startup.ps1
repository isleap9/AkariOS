# Startup apps (plan docs/plans/2026-11-26-new-features.md, X2; the Tools > Startup page, UI\StartupPage.ps1): what
# starts with Windows from the places Task Manager's Startup apps lists (the Run keys and the Startup folders), each
# on or off through Explorer's StartupApproved values, as Task Manager's own switch (turned back on, it runs as it
# did). Removing an entry deletes its value or file. The native app's AkariOS.Core/Machine/StartupItems.cs does the
# same; StartupOracleTests compares the pure parts.

$AkariStartupApprovedRoot = 'Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved'

# where startup entries live: @{ Location (its label); Scope User | Machine; Kind Registry | Folder; Path (a key or a
# folder); Approved (the StartupApproved key) }. Tests mock this.
function Get-AkariStartupLocations {
    $run = 'Software\Microsoft\Windows\CurrentVersion\Run'
    $common = Get-AkariRegValue 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Shell Folders' 'Common Startup'
    if (-not $common) { $common = Join-Path $env:ProgramData 'Microsoft\Windows\Start Menu\Programs\StartUp' }
    $user = Get-AkariUserFolder 'Startup'
    @(
        @{ Location = 'Registry, this user'; Scope = 'User'; Kind = 'Registry'; Path = "HKCU:\$run"; Approved = "HKCU:\$AkariStartupApprovedRoot\Run" }
        @{ Location = 'Registry, all users'; Scope = 'Machine'; Kind = 'Registry'; Path = "HKLM:\$run"; Approved = "HKLM:\$AkariStartupApprovedRoot\Run" }
        @{ Location = 'Registry, all users (32-bit)'; Scope = 'Machine'; Kind = 'Registry'; Path = 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Run'; Approved = "HKLM:\$AkariStartupApprovedRoot\Run32" }
        if ($user) { @{ Location = 'Startup folder, this user'; Scope = 'User'; Kind = 'Folder'; Path = $user; Approved = "HKCU:\$AkariStartupApprovedRoot\StartupFolder" } }
        @{ Location = 'Startup folder, all users'; Scope = 'Machine'; Kind = 'Folder'; Path = $common; Approved = "HKLM:\$AkariStartupApprovedRoot\StartupFolder" }
    )
}

# (pure) a StartupApproved value: missing = on; else bit 0 of its first byte set = off (02 / 06 on, 03 / 07 off)
function Test-AkariStartupApproved($Bytes) {
    $b = @($Bytes)
    if (-not $b.Count -or $null -eq $Bytes) { return $true }
    -not ([int]$b[0] -band 1)
}

# (pure) the value Task Manager writes: on = 02 and eleven zero bytes; off = 03 00 00 00 and the time as a FILETIME
function ConvertTo-AkariStartupApproved([bool]$Enabled, [datetime]$WhenUtc) {
    $b = [byte[]]::new(12)
    if ($Enabled) { $b[0] = 2; return , $b }
    $b[0] = 3
    [Array]::Copy([BitConverter]::GetBytes($WhenUtc.ToFileTimeUtc()), 0, $b, 4, 8)
    , $b
}

# (pure) the program a command line starts: the quoted part, else up to the first .exe, else the first word
function Get-AkariStartupProgram([string]$Command) {
    $c = "$Command".Trim()
    if (-not $c) { return '' }
    if ($c.StartsWith('"')) {
        $end = $c.IndexOf('"', 1)
        return $(if ($end -gt 0) { $c.Substring(1, $end - 1) } else { $c.Substring(1) })
    }
    $exe = $c.IndexOf('.exe', [StringComparison]::OrdinalIgnoreCase)
    if ($exe -gt 0) { return $c.Substring(0, $exe + 4) }
    $sp = $c.IndexOf(' ')
    if ($sp -gt 0) { $c.Substring(0, $sp) } else { $c }
}

# the company in a program's version information ('' when unknown)
function Get-AkariFilePublisher([string]$Path) {
    try {
        $p = [Environment]::ExpandEnvironmentVariables($Path)
        if ($p -and [IO.File]::Exists($p)) { return "$([Diagnostics.FileVersionInfo]::GetVersionInfo($p).CompanyName)".Trim() }
    } catch { }
    ''
}

# a startup entry's key in the rows and the queue
function Get-AkariStartupKey($Item) { "$($Item.Location)|$($Item.Name)" }

# every startup entry: @{ Key; Name; Command; Location; Scope; Kind; Path; File; Approved; Enabled; Publisher }
function Get-AkariStartupItems {
    foreach ($l in @(Get-AkariStartupLocations)) {
        $entries = @()
        if ($l.Kind -eq 'Registry') {
            $k = Get-Item -LiteralPath (Resolve-AkariRegPath $l.Path) -ErrorAction SilentlyContinue
            if (-not $k) { continue }
            $entries = @(foreach ($n in $k.GetValueNames()) {
                if (-not $n) { continue }
                @{ Name = $n; Command = "$($k.GetValue($n))"; File = '' }
            })
        } else {
            if (-not $l.Path -or -not [IO.Directory]::Exists($l.Path)) { continue }
            $entries = @(foreach ($f in [IO.Directory]::GetFiles($l.Path)) {
                $n = [IO.Path]::GetFileName($f)
                if ($n -eq 'desktop.ini') { continue }
                @{ Name = $n; Command = $f; File = $f }
            })
        }
        foreach ($e in $entries) {
            $item = [pscustomobject]@{
                Key = ''; Name = $e.Name; Command = $e.Command; Location = $l.Location; Scope = $l.Scope; Kind = $l.Kind; Path = $l.Path
                File = $e.File; Approved = $l.Approved; Enabled = (Test-AkariStartupApproved (Get-AkariRegValue $l.Approved $e.Name))
                Publisher = (Get-AkariFilePublisher (Get-AkariStartupProgram $e.Command))
            }
            $item.Key = Get-AkariStartupKey $item
            $item
        }
    }
}

# turns an entry on or off (its StartupApproved value); throws when Windows keeps it as it was
function Set-AkariStartupEnabled($Item, [bool]$Enabled) {
    Set-Reg $Item.Approved $Item.Name (ConvertTo-AkariStartupApproved $Enabled ([datetime]::UtcNow)) 'Binary'
    if ((Test-AkariStartupApproved (Get-AkariRegValue $Item.Approved $Item.Name)) -ne $Enabled) {
        throw "Windows keeps it $(if ($Enabled) { 'off' } else { 'on' })"
    }
}

# deletes an entry: its Run value or its Startup folder file, then its StartupApproved value
function Remove-AkariStartupItem($Item) {
    if ($Item.Kind -eq 'Registry') {
        Remove-Reg $Item.Path $Item.Name
        if ($null -ne (Get-AkariRegValue $Item.Path $Item.Name)) { throw 'Windows keeps it: the value could not be deleted' }
    }
    elseif ($Item.File -and [IO.File]::Exists($Item.File)) { Remove-Item -LiteralPath $Item.File -Force -ErrorAction Stop }
    if ($null -ne (Get-AkariRegValue $Item.Approved $Item.Name)) { Remove-Reg $Item.Approved $Item.Name }
}
