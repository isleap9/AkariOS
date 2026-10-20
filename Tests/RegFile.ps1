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
            $hive = @{ HKEY_CURRENT_USER = 'HKCU:'; HKEY_LOCAL_MACHINE = 'HKLM:'; HKEY_CLASSES_ROOT = 'HKCR:'; HKEY_USERS = 'HKU:' }[$Matches[2]]
            $key = "$hive\$($Matches[3])".ToLower()
            if ($Matches[1]) { $map["$key|"] = $null; $key = $null }
            continue
        }
        if (-not $key -or $l -notmatch '^(@|"(?:[^"\\]|\\.)*")=(.*)$') { continue }
        $name = if ($Matches[1] -eq '@') { '' } else { $Matches[1].Trim('"') -replace '\\\\', '\' }
        $raw = $Matches[2]
        $v = switch -Regex ($raw) {
            '^-$' { $null; break }
            '^dword:([0-9a-fA-F]+)$' { [uint32]::Parse($Matches[1], 'HexNumber'); break }
            '^hex(\([0-9a-f]+\))?:(.*)$' { [byte[]]@($Matches[2] -split ',' | Where-Object { $_ } | ForEach-Object { [Convert]::ToByte($_.Trim(), 16) }); break }
            '^"(.*)"$' { $Matches[1] -replace '\\\\', '\'; break }
            default { $raw }
        }
        $map["$key|$($name.ToLower())"] = $v
    }
    $map
}

# the reg.reg value for a tweak's Registry row, or the string 'absent' when reg.reg doesn't touch it
function Get-AkariRegFileValue($Map, $Row) {
    $p = ([string]$Row.Path).ToLower() -replace '\\controlset001\\', '\currentcontrolset\'
    foreach ($cand in @($p, ($p -replace '\\currentcontrolset\\', '\controlset001\'))) {
        $k = "$cand|$(([string]$Row.Name).ToLower())"
        if ($Map.ContainsKey($k)) { return , $Map[$k] }
    }
    'absent'
}
