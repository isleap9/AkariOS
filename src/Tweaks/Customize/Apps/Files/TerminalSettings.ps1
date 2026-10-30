# apps-terminal-no-close-tabs-warning's text edits of Windows Terminal's settings.json (the real user's)
function Get-AkariTerminalSettingsPath {
    Join-Path (Get-AkariUserFolder 'Local AppData') 'Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json'
}

# the file's text, or $null when Terminal has no settings file
function Get-AkariTerminalSettings {
    $p = Get-AkariTerminalSettingsPath
    if (Test-Path -LiteralPath $p) { [IO.File]::ReadAllText($p) } else { $null }
}

# $NoWarning: the line "confirmCloseAllTabs": false after the first "{" (an existing value set to false instead);
# else that line removed. Written back as UTF-8 without a BOM, as Terminal writes it.
function Set-AkariTerminalCloseTabs([bool]$NoWarning) {
    $p = Get-AkariTerminalSettingsPath
    $text = Get-AkariTerminalSettings
    if ($null -eq $text) { throw 'Windows Terminal has no settings file yet (open it once, then try again)' }
    $line = '(?m)^[ \t]*"confirmCloseAllTabs"[ \t]*:[ \t]*(true|false)[ \t]*(,?)[ \t]*\r?\n'
    if ($NoWarning) {
        if ($text -match '"confirmCloseAllTabs"\s*:\s*(true|false)') { $text = $text -replace '("confirmCloseAllTabs"\s*:\s*)(true|false)', '${1}false' }
        else {
            $nl = if ($text.Contains("`r`n")) { "`r`n" } else { "`n" }
            $i = $text.IndexOf('{')
            if ($i -lt 0) { throw 'Windows Terminal''s settings file is not a JSON object' }
            $empty = $text.Substring($i + 1).Trim() -eq '}'
            $text = $text.Substring(0, $i + 1) + $nl + '    "confirmCloseAllTabs": false' + $(if ($empty) { '' } else { ',' }) + $(if ($text.Substring($i + 1).StartsWith($nl)) { '' } else { $nl }) + $text.Substring($i + 1)
        }
    }
    else {
        $m = [regex]::Match($text, $line)
        if (-not $m.Success) { return }
        $before = $text.Substring(0, $m.Index); $after = $text.Substring($m.Index + $m.Length)
        # the last property: the one before it loses its comma
        if (-not $m.Groups[2].Value) { $before = $before -replace ',(\s*)$', '$1' }
        $text = $before + $after
    }
    [IO.File]::WriteAllText($p, $text, (New-Object Text.UTF8Encoding $false))
}
