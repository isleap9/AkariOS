# Registry helpers. HKCU paths always resolve to the real logged-in user's hive (AGENTS.md rule 6),
# so an Akari elevated with another admin account still changes the user sitting at the desk.

# $script:AkariUserSid overrides the detected user (set by Phases when resuming as SYSTEM, and by tests)
function Get-AkariUserSid {
    if ($script:AkariUserSid) { return $script:AkariUserSid }
    if (-not $script:AkariDetectedSid) {
        $sid = $null
        try {
            $session = (Get-Process -Id $PID).SessionId
            $explorer = Get-CimInstance Win32_Process -Filter "Name='explorer.exe' AND SessionId=$session" -ErrorAction Stop | Select-Object -First 1
            if ($explorer) { $sid = (Invoke-CimMethod -InputObject $explorer -MethodName GetOwnerSid -ErrorAction Stop).Sid }
        } catch { }
        if (-not $sid) { $sid = [Security.Principal.WindowsIdentity]::GetCurrent().User.Value }
        $script:AkariDetectedSid = $sid
    }
    $script:AkariDetectedSid
}

function Resolve-AkariRegPath([string]$Path) {
    if ($Path -match '^(HKCU:|HKEY_CURRENT_USER)\\?(.*)$') {
        return "Registry::HKEY_USERS\$(Get-AkariUserSid)\$($Matches[2])"
    }
    $Path
}

# a folder of the real logged-in user (rule 6: not the elevated account's), e.g. 'AppData', 'Local AppData', 'Desktop',
# 'Programs' (their Start menu programs): read from their Shell Folders, else built from their profile path
function Get-AkariUserFolder([string]$Name) {
    $p = Get-AkariRegValue 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Shell Folders' $Name
    if ($p) { return $p }
    $profile = Get-AkariRegValue "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList\$(Get-AkariUserSid)" 'ProfileImagePath'
    if (-not $profile) { $profile = $env:USERPROFILE }
    switch ($Name) {
        'AppData' { "$profile\AppData\Roaming" }
        'Local AppData' { "$profile\AppData\Local" }
        'Programs' { "$profile\AppData\Roaming\Microsoft\Windows\Start Menu\Programs" }
        default { "$profile\$Name" }
    }
}

# $null when the key or value is absent; DWords come back unsigned
function Get-AkariRegValue([string]$Path, [string]$Name) {
    $p = Resolve-AkariRegPath $Path
    $v = (Get-ItemProperty -Path $p -Name $Name -ErrorAction SilentlyContinue).$Name
    if ($v -is [int] -and $v -lt 0) { return [BitConverter]::ToUInt32([BitConverter]::GetBytes($v), 0) }
    $v
}

function Set-Reg($Path, $Name, $Value, $Type = 'DWord') {
    $p = Resolve-AkariRegPath $Path
    if (-not (Test-Path $p)) { New-Item -Path $p -Force | Out-Null }
    # the registry provider wants a signed Int32 for DWords above 2^31
    if ($Type -eq 'DWord' -and [double]$Value -gt [int]::MaxValue) { $Value = [BitConverter]::ToInt32([BitConverter]::GetBytes([uint32]$Value), 0) }
    New-ItemProperty -Path $p -Name $Name -Value $Value -PropertyType $Type -Force | Out-Null
}

function Remove-Reg($Path, $Name) { Remove-ItemProperty -Path (Resolve-AkariRegPath $Path) -Name $Name -ErrorAction SilentlyContinue }

# a Default may be a per-OS map: @{ Win10 = 1; Win11 = 0 }
function Resolve-AkariDefault($Default) {
    if ($Default -is [hashtable] -and ($Default.ContainsKey('Win10') -or $Default.ContainsKey('Win11'))) {
        if ([Environment]::OSVersion.Version.Build -ge 22000) { return $Default['Win11'] }
        return $Default['Win10']
    }
    $Default
}

# $null expected = the value must be absent
function Test-AkariRegMatch($Current, $Expected) {
    if ($null -eq $Expected) { return $null -eq $Current }
    if ($null -eq $Current) { return $false }
    # "$_" per item: -join would use the source text of a number passed as an argument ('0x28', not '40')
    (@($Current | ForEach-Object { "$_" }) -join ',') -eq (@($Expected | ForEach-Object { "$_" }) -join ',')
}

# a key row has no Name: it is about the whole key. Its Value and Default are 'Key' (the key exists, created empty
# if missing) or $null (the key is deleted with everything in it).
function Test-AkariKeyRow([hashtable]$Entry) { -not $Entry.ContainsKey('Name') }

# 'Key' when the key exists, else $null
function Get-AkariRegKey([string]$Path) { if (Test-Path (Resolve-AkariRegPath $Path)) { 'Key' } else { $null } }

# Registry entries are @{ Path; Name; Type; Value; Default } (Default $null = delete on Revert), or key rows
# @{ Path; Value; Default } (see Test-AkariKeyRow). Binary values: Type 'Binary', Value a [byte[]].
function Invoke-AkariRegistry([hashtable[]]$Entries, [ValidateSet('Apply', 'Revert')][string]$Mode) {
    foreach ($e in $Entries) {
        $v = if ($Mode -eq 'Apply') { $e.Value } else { Resolve-AkariDefault $e.Default }
        if (Test-AkariKeyRow $e) {
            $p = Resolve-AkariRegPath $e.Path
            if ($null -eq $v) { if (Test-Path $p) { Remove-Item $p -Recurse -Force } }
            elseif (-not (Test-Path $p)) { New-Item -Path $p -Force | Out-Null }
        }
        elseif ($null -eq $v) { Remove-Reg $e.Path $e.Name } else { Set-Reg $e.Path $e.Name $v $e.Type }
    }
}

function Get-AkariRegistryState([hashtable[]]$Entries) {
    try {
        $cur = @(foreach ($e in $Entries) { if (Test-AkariKeyRow $e) { , (Get-AkariRegKey $e.Path) } else { , (Get-AkariRegValue $e.Path $e.Name) } })
        $opt = $true; $def = $true
        for ($i = 0; $i -lt $Entries.Count; $i++) {
            if (-not (Test-AkariRegMatch $cur[$i] $Entries[$i].Value)) { $opt = $false }
            if (-not (Test-AkariRegMatch $cur[$i] (Resolve-AkariDefault $Entries[$i].Default))) { $def = $false }
        }
        if ($opt) { return 'Optimized' }
        if ($def) { return 'Default' }
        'Custom'
    } catch { 'Unknown' }
}
