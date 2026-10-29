# Install USB: the answer file engine, a PowerShell port of Christoph Schneegans' unattend generator (MIT,
# https://github.com/cschneegans/unattend-generator, Main.cs / Util.cs / Extensions.cs; its license is Data\LICENSE.txt).
# The choices are his form's fields (the same names and values as https://schneegans.de/windows/unattend-generator/),
# a hashtable name -> string (a multi-select: string[]). One function per modifier works on the XML document like his.

$AkariUaData = Join-Path $PSScriptRoot 'Data'
$AkariUaMyNs = 'https://schneegans.de/windows/unattend-generator/'
$AkariUaSite = 'https://schneegans.de/windows/unattend-generator/'

# ---- the data files (Data\*.json), read once
$script:AkariUaCache = @{}
function Get-AkariUaList([string]$Name) {
    if (-not $script:AkariUaCache.ContainsKey($Name)) {
        # 5.1's ConvertFrom-Json writes a JSON array as one object: the parentheses unroll it
        $script:AkariUaCache[$Name] = @((ConvertFrom-Json ([IO.File]::ReadAllText((Join-Path $AkariUaData "$Name.json"), [Text.Encoding]::UTF8))) | ForEach-Object { $_ })
    }
    $script:AkariUaCache[$Name]
}
# one item of a data file by Id (case-insensitive, like his dictionaries); throws when it is missing
function Get-AkariUaItem([string]$Name, [string]$Id) {
    $i = @(Get-AkariUaList $Name | Where-Object { $_.Id -eq $Id })[0]
    if (-not $i) { throw "Could not find an element of type '$Name' with key '$Id'." }
    $i
}
function Get-AkariUaResource([string]$Name) { [IO.File]::ReadAllText((Join-Path $AkariUaData $Name), [Text.Encoding]::UTF8).TrimStart([char]0xFEFF) }

# ---- the fields
function Get-AkariUaField($C, [string]$Name, [string]$Default = '') { $v = $C.Fields[$Name]; if ($null -eq $v) { $Default } else { [string]@($v)[0] } }
# a checkbox: present and 'true' / 'on'
function Test-AkariUaOn($C, [string]$Name) { (Get-AkariUaField $C $Name) -in 'true', 'True', 'on' }

# ---- XML helpers (Util.cs, Extensions.cs)
function Select-AkariUaNode($Node, [string]$XPath, $Ns) {
    $n = $Node.SelectSingleNode($XPath, $Ns)
    if (-not $n) { throw "No node matches XPath '$XPath'." }
    $n
}
function Remove-AkariUaNode($Node) { [void]$Node.ParentNode.RemoveChild($Node) }
function Get-AkariUaComponent($C, [string]$Pass, [string]$Component) {
    $setting = Select-AkariUaNode $C.Doc "/u:unattend/u:settings[@pass='$Pass']" $C.Ns
    $elem = $setting.SelectSingleNode("u:component[@name='$Component']", $C.Ns)
    if (-not $elem) {
        $elem = $C.Doc.CreateElement('component', $C.Ns.LookupNamespace('u'))
        $elem.SetAttribute('name', $Component)
        $elem.SetAttribute('processorArchitecture', 'x86')
        $elem.SetAttribute('publicKeyToken', '31bf3856ad364e35')
        $elem.SetAttribute('language', 'neutral')
        $elem.SetAttribute('versionScope', 'nonSxS')
        [void]$setting.AppendChild($elem)
    }
    $elem
}
function Get-AkariUaComponentChild($C, [string]$Pass, [string]$Component, [string]$Element) {
    $comp = Get-AkariUaComponent $C $Pass $Component
    $elem = $comp.SelectSingleNode("u:$Element", $C.Ns)
    if (-not $elem) { $elem = $C.Doc.CreateElement($Element, $C.Ns.LookupNamespace('u')); [void]$comp.AppendChild($elem) }
    $elem
}
function New-AkariUaElement($C, [string]$Name, $Parent) {
    $e = $C.Doc.CreateElement($Name, $C.Ns.LookupNamespace('u'))
    [void]$Parent.AppendChild($e)
    $e
}
function New-AkariUaSimple($C, [string]$Name, $Parent, [string]$Text) {
    $e = New-AkariUaElement $C $Name $Parent
    $e.InnerText = $Text
    $e
}
# InsertTextWithIndentation: the text on its own lines, the closing tag indented to the element's depth
function Add-AkariUaText($Element, [string]$Text) {
    $level = @($Element.SelectNodes('ancestor::*')).Count
    [void]$Element.AppendChild($Element.OwnerDocument.CreateTextNode("`r`n$($Text.Trim())`r`n$("`t" * $level)"))
}
function Split-AkariUaLines([string]$Text) { if ($null -eq $Text) { return @() }; @($Text -split "`r`n|`n|`r") }

# ---- commands (CommandConfig, CommandAppender, CommandBuilder)
# $Where: WindowsPE (Microsoft-Windows-Setup RunSynchronous Path), Specialize (Microsoft-Windows-Deployment RunSynchronous
# Path) or Oobe (Microsoft-Windows-Shell-Setup FirstLogonCommands CommandLine)
function Add-AkariUaCommand($C, [string]$Where, [string[]]$Values) {
    foreach ($v in $Values) {
        $e = switch ($Where) {
            'WindowsPE' { New-AkariUaElement $C 'Path' (New-AkariUaElement $C 'RunSynchronousCommand' (Get-AkariUaComponentChild $C 'windowsPE' 'Microsoft-Windows-Setup' 'RunSynchronous')) }
            'Specialize' { New-AkariUaElement $C 'Path' (New-AkariUaElement $C 'RunSynchronousCommand' (Get-AkariUaComponentChild $C 'specialize' 'Microsoft-Windows-Deployment' 'RunSynchronous')) }
            'Oobe' { New-AkariUaElement $C 'CommandLine' (New-AkariUaElement $C 'SynchronousCommand' (Get-AkariUaComponentChild $C 'oobeSystem' 'Microsoft-Windows-Shell-Setup' 'FirstLogonCommands')) }
        }
        $e.InnerText = $v
    }
}
function Get-AkariUaShell([string]$Command) { "cmd.exe /c `"$Command`"" }
function Get-AkariUaReg([string]$Value) { "reg.exe $Value" }
function Get-AkariUaWindowStyle($C) { if ($C.HidePowerShell) { 'Hidden' } else { 'Normal' } }
function Get-AkariUaPowerShell($C, [string]$Value) {
    if ($Value.Contains('"')) { throw "PowerShell command '$Value' must not contain '`"'." }
    if (-not ($Value.EndsWith(';') -or $Value.EndsWith('}'))) { throw "PowerShell command '$Value' must end with either ';' or '}'." }
    "powershell.exe -WindowStyle `"$(Get-AkariUaWindowStyle $C)`" -NoProfile -Command `"$Value`""
}
function Get-AkariUaPowerShellFile($C, [string]$Path) { "powershell.exe -WindowStyle `"$(Get-AkariUaWindowStyle $C)`" -ExecutionPolicy `"Unrestricted`" -NoProfile -File `"$Path`"" }
function Get-AkariUaVBScript([string]$Path) { "cscript.exe //E:vbscript `"$Path`"" }

# EchoProcessor: lines as echo statements for a .cmd file (trimmed, empty ones dropped, cmd's special characters escaped)
function ConvertTo-AkariUaEcho([string[]]$Lines, [bool]$Escape = $true) {
    foreach ($l in $Lines) {
        $t = $l.Trim()
        if (-not $t) { continue }
        if ($Escape) { $t = [regex]::Replace($t, '[\^&<>|%)"]', '^$0') }
        "echo:$t"
    }
}
# WriteToFilePE: commands that append $Lines to $Path, each command at most 255 characters
function Get-AkariUaWriteToFile([string]$Path, [string[]]$Lines) {
    if ($Path -match '\s') { throw "Path '$Path' must not contain whitespace characters." }
    $segments = [Collections.Generic.List[string]]::new()
    foreach ($s in @(ConvertTo-AkariUaEcho $Lines)) { $segments.Add($s) }
    $result = [Collections.Generic.List[string]]::new()
    while ($segments.Count -gt 0) {
        $prev = $null; $current = $null
        for ($take = 1; $take -le $segments.Count; $take++) {
            $current = "cmd.exe /c >>$Path ($($segments.GetRange(0, $take) -join '&'))"
            if ($current.Length -gt 255) {
                if ($null -eq $prev) { throw "Line '$current' is too long. You need to add line breaks to your input to make it shorter." }
                $result.Add($prev)
                $segments.RemoveRange(0, $take - 1)
                $current = $null
                break
            }
            $prev = $current
        }
        if ($null -ne $current) { $result.Add($current); break }
    }
    $result
}

# ---- PowerShell sequences (Specialize, FirstLogon, UserOnce, DefaultUser): commands run one by one, logged
function New-AkariUaSequence([string]$Activity, [string]$LogFile) {
    @{ Commands = [Collections.Generic.List[string]]::new(); Restart = $false; Activity = $Activity; LogFile = $LogFile }
}
function Get-AkariUaSequenceScript($Seq) {
    $w = [Text.StringBuilder]::new()
    $block = {
        param($command)
        [void]$w.Append("`t{`r`n")
        foreach ($line in Split-AkariUaLines $command) { [void]$w.Append("`t`t$line`r`n") }
        [void]$w.Append("`t};`r`n")
    }
    [void]$w.Append("`$scripts = @(`r`n")
    foreach ($c in $Seq.Commands) { & $block $c }
    if ($Seq.Restart) { & $block (Get-AkariUaResource 'RestartExplorer.ps1') }
    [void]$w.Append(");`r`n`r`n")
    $l = [char]0xAB; $r = [char]0xBB; $dots = [char]0x2026
    [void]$w.Append(@"
& {
  [float] `$complete = 0;
  [float] `$increment = 100 / `$scripts.Count;
  foreach( `$script in `$scripts ) {
    Write-Progress -Id 0 -Activity '$($Seq.Activity) Do not close this window.' -PercentComplete `$complete;
    '*** Will now execute command $l{0}$r.' -f `$(
      `$script.ToString().Trim() -replace '\s+', ' ' -replace '^(.{99})(.+)`$', '`$1$dots';
    );
    `$start = [datetime]::Now;
    & `$script;
    '*** Finished executing command after {0:0} ms.' -f [datetime]::Now.Subtract( `$start ).TotalMilliseconds;
    "``r``n" * 3;
    `$complete += `$increment;
  }
} *>&1 | Out-String -Width 1KB -Stream >> "$($Seq.LogFile)";
"@)
    [void]$w.Append("`r`n")
    $w.ToString()
}

# ---- files embedded in the answer file (Extensions\File), written by the ExtractScript at the start of specialize
function Add-AkariUaFile($C, [string]$Name, [string]$Content) {
    $path = if ($Name.Contains('\')) { $Name } else { "C:\Windows\Setup\Scripts\$Name" }
    $ext = Select-AkariUaNode $C.Doc '/u:unattend/s:Extensions' $C.Ns
    $extract = $ext.SelectSingleNode('s:ExtractScript', $C.Ns)
    if (-not $extract) {
        $extract = $C.Doc.CreateElement('ExtractScript', $AkariUaMyNs)
        [void]$ext.AppendChild($extract)
        Add-AkariUaText $extract (Get-AkariUaResource 'ExtractScripts.ps1')
        Add-AkariUaCommand $C 'Specialize' (Get-AkariUaPowerShell $C '$xml = [xml]::new(); $xml.Load(''C:\Windows\Panther\unattend.xml''); $sb = [scriptblock]::Create( $xml.unattend.Extensions.ExtractScript ); Invoke-Command -ScriptBlock $sb -ArgumentList $xml;')
    }
    $file = $C.Doc.CreateElement('File', $AkariUaMyNs)
    $file.SetAttribute('path', $path)
    [void]$ext.AppendChild($file)
    Add-AkariUaText $file $Content
    $path
}
# EmbedTextFile: the content followed by a line break
function Add-AkariUaTextFile($C, [string]$Name, [string]$Content) { Add-AkariUaFile $C $Name "$Content`r`n" }
# EmbedXmlFile: the document indented with tabs, no declaration
function Add-AkariUaXmlFile($C, [string]$Name, [xml]$Xml) {
    $sw = [IO.StringWriter]::new()
    $s = [Xml.XmlWriterSettings]::new(); $s.OmitXmlDeclaration = $true; $s.Indent = $true; $s.IndentChars = "`t"; $s.NewLineChars = "`r`n"; $s.CloseOutput = $true
    $xw = [Xml.XmlWriter]::Create($sw, $s); $Xml.Save($xw); $xw.Close()
    Add-AkariUaFile $C $Name $sw.ToString()
}

# ---- the document

# the effective PE stage: the site makes it Generated when partitioning isn't left to setup
function Get-AkariUaPEMode($C) {
    $m = Get-AkariUaField $C 'PEMode' 'Default'
    if ($m -eq 'Default' -and (Get-AkariUaField $C 'PartitionMode' 'Interactive') -ne 'Interactive') { 'Generated' } else { $m }
}

# the answer file for $Fields as an XmlDocument (GenerateXml)
function New-AkariUnattendXml([hashtable]$Fields) {
    $doc = [xml]::new()
    $doc.Load((Join-Path $AkariUaData 'autounattend.xml'))
    $ns = [Xml.XmlNamespaceManager]::new($doc.NameTable)
    $ns.AddNamespace('u', 'urn:schemas-microsoft-com:unattend')
    $ns.AddNamespace('wcm', 'http://schemas.microsoft.com/WMIConfig/2002/State')
    $ns.AddNamespace('s', $AkariUaMyNs)
    $C = @{ Doc = $doc; Ns = $ns; Fields = $Fields }
    $C.HidePowerShell = Test-AkariUaOn $C 'HidePowerShellWindows'
    $C.PEMode = Get-AkariUaPEMode $C
    $C.Specialize = New-AkariUaSequence 'Running scripts to customize your Windows installation.' 'C:\Windows\Setup\Scripts\Specialize.log'
    $C.FirstLogon = New-AkariUaSequence 'Running scripts to finalize your Windows installation.' 'C:\Windows\Setup\Scripts\FirstLogon.log'
    $C.UserOnce = New-AkariUaSequence 'Running scripts to configure this user account.' '$env:TEMP\UserOnce.log'
    $C.DefaultUser = New-AkariUaSequence "Running scripts to modify the default user$([char]0x2019)$([char]0x2019)s registry hive." 'C:\Windows\Setup\Scripts\DefaultUser.log'
    foreach ($m in $AkariUaModifiers) { & "Invoke-AkariUa$m" $C }
    $doc
}

# Serialize: ASCII (setup only reads ASCII; other characters become references), tabs, CRLF, a utf-8 declaration
function ConvertTo-AkariUaBytes([xml]$Doc) {
    $ms = [IO.MemoryStream]::new()
    $head = [Text.Encoding]::ASCII.GetBytes("<?xml version=`"1.0`" encoding=`"utf-8`"?>`r`n")
    $ms.Write($head, 0, $head.Length)
    $s = [Xml.XmlWriterSettings]::new(); $s.Encoding = [Text.Encoding]::ASCII; $s.OmitXmlDeclaration = $true; $s.CloseOutput = $false
    $s.Indent = $true; $s.IndentChars = "`t"; $s.NewLineChars = "`r`n"
    $xw = [Xml.XmlWriter]::Create($ms, $s); $Doc.Save($xw); $xw.Close()
    , $ms.ToArray()
}

# the modifiers in GenerateXml's order (Core\Unattend\*.ps1). Build is not ported: no commit hash in AkariOS.
$AkariUaModifiers = 'Accessibility', 'ComputerName', 'Bypass', 'ProductKey', 'Locales', 'Disk', 'Users', 'Bloatware', 'ExpressSettings',
    'Wifi', 'EmptyElements', 'Lockout', 'PasswordExpiration', 'Optimizations', 'Personalization', 'TimeZone', 'AppLocker', 'Script',
    'Specialize', 'UserOnce', 'DefaultUser', 'Delete', 'FirstLogon', 'Components', 'Order', 'ProcessorArchitecture', 'Pretty'
