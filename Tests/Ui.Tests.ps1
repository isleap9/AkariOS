$Root = Split-Path $PSScriptRoot

# Parses XAML in a child STA PowerShell (WPF needs STA). No window is created or shown.
function Test-XamlInChild([string]$Script) {
    $out = & powershell -NoProfile -STA -ExecutionPolicy Bypass -Command $Script 2>&1
    @($out | ForEach-Object { "$_" }) -join "`n"
}

Describe 'UI files' {
    It 'UI scripts and Akari.ps1 have no parse errors' {
        foreach ($f in @(Get-ChildItem "$Root\UI\*.ps1") + @(Get-Item "$Root\Akari.ps1")) {
            $errs = $null
            [void][Management.Automation.Language.Parser]::ParseFile($f.FullName, [ref]$null, [ref]$errs)
            "$($f.Name): $($errs.Count)" | Should Be "$($f.Name): 0"
        }
    }

    It 'MainWindow.xaml parses' {
        $s = "Add-Type -AssemblyName PresentationFramework; [void][Windows.Markup.XamlReader]::Parse((Get-Content '$Root\UI\MainWindow.xaml' -Raw)); 'ok'"
        Test-XamlInChild $s | Should Be 'ok'
    }

    It 'has no tuner left' {
        $hits = Select-String -Path @("$Root\Akari.ps1", "$Root\UI\*.ps1", "$Root\UI\*.xaml") -Pattern 'Tuner|Read-Prio|Read-Svc|SvcCur'
        @($hits).Count | Should Be 0
    }

    It 'Controls.xaml parses and defines every style' {
        $s = "Add-Type -AssemblyName PresentationFramework; `$d = [Windows.Markup.XamlReader]::Parse((Get-Content '$Root\UI\Controls.xaml' -Raw)); " +
             "`$miss = @('Switch', 'Combo', 'ComboItem', 'Check', 'SettingCard', 'CategoryCard', 'Accent', 'StepDot', 'ModeCard' | Where-Object { -not `$d.Contains(`$_) }); " +
             "if (`$miss) { 'missing: ' + (`$miss -join ', ') } else { 'ok' }"
        Test-XamlInChild $s | Should Be 'ok'
    }
}

Describe 'Get-AkariMasonry' {
    . "$Root\UI\Cards.ps1"
    It 'puts each card in the shortest column, leftmost on ties' {
        (Get-AkariMasonry @(5, 1, 1, 1) 3) -join ',' | Should Be '0,1,2,1'
    }
    It 'fills two columns' { (Get-AkariMasonry @(3, 3, 1) 2) -join ',' | Should Be '0,1,0' }
}

Describe 'Tweak rows' {
    # builds grid rows in a child STA PowerShell (no window), applies their templates, prints key=value lines
    $probe = "$TestDrive\probe.ps1"
    Set-Content $probe -Value @'
param($Root)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName PresentationFramework
foreach ($f in 'Registry', 'Loader') { . "$Root\Core\$f.ps1" }
. "$Root\UI\Selection.ps1"
. "$Root\UI\Cards.ps1"
$host_ = [Windows.Controls.StackPanel]::new()
$host_.Resources.MergedDictionaries.Add([Windows.Markup.XamlReader]::Parse((Get-Content "$Root\UI\Controls.xaml" -Raw)))
$host_.Resources['Icons'] = [Windows.Media.FontFamily]::new('Segoe MDL2 Assets')
function Show($e) { [void]$host_.Children.Add($e.Row); $host_.Measure([Windows.Size]::new(400, 2000)); [void]$e.Control.ApplyTemplate() }
$tog = ConvertTo-AkariTweak @{ Id = 'tog'; Name = 'Tog'; Description = 'D'; Risk = 'Safe'; Reboot = $true } 'x' $false
$adv = ConvertTo-AkariTweak @{ Id = 'adv'; Name = 'Adv'; Description = 'D'; Risk = 'Advanced' } 'x' $false
$act = ConvertTo-AkariTweak @{ Id = 'act'; Name = 'Act'; Description = 'D'; Kind = 'Action'; Risk = 'Safe' } 'x' $false
$ch = ConvertTo-AkariTweak @{ Id = 'ch'; Name = 'Ch'; Description = 'D'; Kind = 'Choice'; Risk = 'Safe'; Recommended = 0x26; Default = 2; Editable = $true
    Choices = @(@{ Value = 0x26; Label = 'A' }, @{ Value = 0x28; Label = 'B' }, @{ Value = 2; Label = 'C' }) } 'x' $false
$e = New-AkariTweakRow $tog 'Default'; Show $e
"togType=$($e.Control.GetType().Name)"; "togGlyphs=$($e.Glyphs.Children.Count)"; "togTip=$($e.Row.ToolTip -replace "`n", '|')"
"togStartState=$(Get-AkariRowStart $e $true)"
$e = New-AkariTweakRow $tog 'Optimized'; Show $e
"optStartState=$(Get-AkariRowStart $e $true)"; "optStartPlain=$(Get-AkariRowStart $e $false)"
Set-AkariRowControl $e 'Optimized'; "setOn=$($e.Control.IsChecked)"
$e = New-AkariTweakRow $tog 'Unknown'; Show $e
"unkGlyph=$($e.Glyphs.Children[1].ToolTip)"
$e = New-AkariTweakRow $adv 'Default'; Show $e
"advGlyph=$($e.Glyphs.Children[0].ToolTip)"
$e = New-AkariTweakRow $ch 'Custom' 0x28; Show $e
"chItems=$($e.Control.Items.Count)"; "chNone=$($e.Control.Items[0].Content)"; "chRec=$($e.Control.Items[1].Content)"; "chDef=$($e.Control.Items[3].Content)"
"chStart=$(Get-AkariRowStart $e $true)"; "chStartPlain=$(Get-AkariRowStart $e $false)"
Set-AkariRowControl $e 0x28; "chValue=$(Get-AkariComboValue $e)"
Set-AkariRowControl $e 'None'; "chNoChange=$(Get-AkariComboValue $e)"
$e = New-AkariTweakRow $ch 'Custom' 7; Show $e
"chUnlisted=$(Get-AkariRowStart $e $true)"
Set-AkariRowControl $e 7; "chTyped=$($e.Control.Text)"
$e = New-AkariTweakRow $act 'Unknown'; Show $e
"actType=$($e.Control.GetType().Name)"; "actGlyphs=$($e.Glyphs.Children.Count)"
$c = New-AkariCategoryCard 'Windows' 0xE771 'Not yet ported'
"cardHead=$($c.Panel.Children[0].Children.Count)"
'@
    $out = @{}
    & powershell -NoProfile -STA -ExecutionPolicy Bypass -File $probe -Root $Root 2>&1 | ForEach-Object {
        $l = "$_"; $i = $l.IndexOf('='); if ($i -gt 0) { $out[$l.Substring(0, $i)] = $l.Substring($i + 1) } else { $out['error'] += $l }
    }

    It 'builds without errors' { $out['error'] | Should BeNullOrEmpty }

    It 'shows a Toggle as a checkbox with a restart glyph and a tooltip' {
        $out.togType | Should Be 'CheckBox'
        $out.togGlyphs | Should Be '1'
        $out.togTip | Should Be 'D|Restart required.|Now: Default.'
    }

    It 'starts checked only when the State is Optimized and Show current state is on' {
        $out.togStartState | Should Be 'None'
        $out.optStartState | Should Be 'Optimized'
        $out.optStartPlain | Should Be 'None'
        $out.setOn | Should Be 'True'
    }

    It 'marks an unread State and an Advanced Risk with glyphs' {
        $out.unkGlyph | Should Be 'State unknown'
        $out.advGlyph | Should Be 'Advanced'
    }

    It 'lists Choices after No change, with Recommended and Windows default marked' {
        $out.chItems | Should Be '4'
        $out.chNone | Should Be 'No change'
        $out.chRec | Should Be 'A (Recommended)'
        $out.chDef | Should Be 'C (Windows default)'
        $out.chStart | Should Be '40'
        $out.chStartPlain | Should Be 'None'
        $out.chValue | Should Be '40'
        $out.chNoChange | Should Be 'None'
    }

    It 'starts an unlisted value on No change, and can show it as typed text' {
        $out.chUnlisted | Should Be 'None'
        $out.chTyped | Should Be '7'
    }

    It 'shows an Action as a checkbox with no state glyph' {
        $out.actType | Should Be 'CheckBox'
        $out.actGlyphs | Should Be '0'
    }

    It 'builds a category card head: icon, title, note' { $out.cardHead | Should Be '3' }
}

Describe 'Console instead of a log panel' {
    It 'has no log panel in the window' {
        @(Select-String -Path "$Root\UI\MainWindow.xaml" -Pattern 'x:Name="Log"|LogBox').Count | Should Be 0
    }

    It 'keeps the elevated console visible (no hidden relaunch, no -ShowConsole)' {
        @(Select-String -Path "$Root\Akari.ps1" -Pattern 'WindowStyle \$style|ShowConsole|Hidden').Count | Should Be 0
    }

    It 'prints log lines to the console with a timestamp' {
        $s = "Add-Type -AssemblyName PresentationFramework; `$AkariLogFile = '$TestDrive\a.log'; . '$Root\Core\Log.ps1'; " +
             "`$t = [Management.Automation.Language.Parser]::ParseFile('$Root\UI\Shell.ps1', [ref]`$null, [ref]`$null); " +
             "`$f = `$t.FindAll({ param(`$n) `$n -is [Management.Automation.Language.FunctionDefinitionAst] -and `$n.Name -eq 'Add-Log' }, `$true) | Select-Object -First 1; " +
             ". ([scriptblock]::Create(`$f.Extent.Text)); Add-Log 'Applied: Test'"
        $out = & powershell -NoProfile -Command $s 2>&1 | ForEach-Object { "$_" }
        ($out -join "`n") | Should Match '^\[\d\d:\d\d:\d\d\] Applied: Test$'
        Get-Content "$TestDrive\a.log" | Should Match 'Applied: Test'
    }
}
