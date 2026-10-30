# Test helper: reads a .reg file (OneClick\reg.reg) into @{ '<path>|<name>' = <value> }, path as 'HKCU:\...' / 'HKLM:\...'
# (lower case), DWords as numbers, hex as [byte[]], strings as text, '-' (deleted) as $null; '<path>|' = $null for a
# deleted key. Only what the AkariOS marks need; not a full .reg parser.
function Read-AkariRegFile([string]$Path) {
    $map = @{}
    $key = $null
    $lines = (Get-Content $Path -Raw) -replace '\\\r?\n\s*', '' -split '\r?\n'
    foreach ($l in $lines) {
        $l = $l.Trim()
        if (-not $l -or $l.StartsWith(';')) { continue }
        if ($l -match '^\[(-?)(HKEY_[A-Z_]+)\\(.+)\]$') {
            $hive = @{ HKEY_CURRENT_USER = 'HKCU:'; HKEY_LOCAL_MACHINE = 'HKLM:'; HKEY_CLASSES_ROOT = 'HKLM:\SOFTWARE\Classes'; HKEY_USERS = 'Registry::HKEY_USERS' }[$Matches[2]]
            $key = "$hive\$($Matches[3])".ToLower()
            if ($Matches[1]) { $map["$key|"] = $null; $key = $null }
            continue
        }
        if (-not $key -or $l -notmatch '^(@|"(?:[^"\\]|\\.)*")=(.*)$') { continue }
        $name = if ($Matches[1] -eq '@') { '(default)' } else { $Matches[1].Trim('"') -replace '\\\\', '\' }
        $raw = $Matches[2]
        $v = switch -Regex ($raw) {
            '^-$' { $null; break }
            '^dword:([0-9a-fA-F]+)$' { [uint32]::Parse($Matches[1], 'HexNumber'); break }
            # expandable text, 64-bit number, multi-line text, then any other hex as bytes
            # UserPreferencesMask is binary; reg.reg (like FR33THY's script) writes it as hex(2): compare its bytes
            '^hex\(2\):(.*)$' { if ($name -eq 'UserPreferencesMask') { [byte[]]@($Matches[1] -split ',' | Where-Object { $_.Trim() } | ForEach-Object { [Convert]::ToByte($_.Trim(), 16) }); break }
                [Text.Encoding]::Unicode.GetString([byte[]]@($Matches[1] -split ',' | Where-Object { $_.Trim() } | ForEach-Object { [Convert]::ToByte($_.Trim(), 16) })).TrimEnd([char]0); break }
            '^hex\(b\):(.*)$' { [BitConverter]::ToUInt64([byte[]]@($Matches[1] -split ',' | Where-Object { $_.Trim() } | ForEach-Object { [Convert]::ToByte($_.Trim(), 16) }), 0); break }
            '^hex\(7\):(.*)$' { , @([Text.Encoding]::Unicode.GetString([byte[]]@($Matches[1] -split ',' | Where-Object { $_.Trim() } | ForEach-Object { [Convert]::ToByte($_.Trim(), 16) })).TrimEnd([char]0) -split [char]0); break }
            '^hex(\([0-9a-f]+\))?:(.*)$' { [byte[]]@($Matches[2] -split ',' | Where-Object { $_ } | ForEach-Object { [Convert]::ToByte($_.Trim(), 16) }); break }
            '^"(.*)"$' { $Matches[1] -replace '\\\\', '\'; break }
            default { $raw }
        }
        $map["$key|$($name.ToLower())"] = $v
    }
    $map
}

# the reg.reg value for a tweak's Registry row, or the string 'absent' when reg.reg doesn't touch it. A key row
# (no Name): $null when reg.reg deletes the key, 'Key' when it writes something in it.
function Get-AkariRegFileValue($Map, $Row) {
    $p = ([string]$Row.Path).ToLower() -replace '\\controlset001\\', '\currentcontrolset\'
    if (-not $Row.ContainsKey('Name')) {
        if ($Map.ContainsKey("$p|")) { return , $null }
        if (@($Map.Keys | Where-Object { $_.StartsWith("$p|") -or $_.StartsWith("$p\") }).Count) { return 'Key' }
        return 'absent'
    }
    foreach ($cand in @($p, ($p -replace '\\currentcontrolset\\', '\controlset001\'))) {
        $k = "$cand|$(([string]$Row.Name).ToLower())"
        if ($Map.ContainsKey($k)) { return , $Map[$k] }
    }
    'absent'
}
