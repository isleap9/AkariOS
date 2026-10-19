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
             "`$miss = @('Switch', 'Combo', 'ComboItem', 'Check', 'SettingCard', 'Section', 'Accent', 'StepDot' | Where-Object { -not `$d.Contains(`$_) }); " +
             "if (`$miss) { 'missing: ' + (`$miss -join ', ') } else { 'ok' }"
        Test-XamlInChild $s | Should Be 'ok'
    }
}

Describe 'Cards' {
    # builds cards in a child STA PowerShell (no window), applies their templates, prints key=value lines
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
function Show($e) { [void]$host_.Children.Add($e.Card); $host_.Measure([Windows.Size]::new(800, 2000)); [void]$e.Control.ApplyTemplate() }
$tog = ConvertTo-AkariTweak @{ Id = 'tog'; Name = 'Tog'; Description = 'D'; Risk = 'Safe'; Reboot = $true } 'x' $false
$adv = ConvertTo-AkariTweak @{ Id = 'adv'; Name = 'Adv'; Description = 'D'; Risk = 'Advanced' } 'x' $false
$act = ConvertTo-AkariTweak @{ Id = 'act'; Name = 'Act'; Description = 'D'; Kind = 'Action'; Risk = 'Safe' } 'x' $false
$ch = ConvertTo-AkariTweak @{ Id = 'ch'; Name = 'Ch'; Description = 'D'; Kind = 'Choice'; Risk = 'Safe'; Recommended = 0x26; Default = 2; Editable = $true
    Choices = @(@{ Value = 0x26; Label = 'A' }, @{ Value = 0x28; Label = 'B' }, @{ Value = 2; Label = 'C' }) } 'x' $false
$e = New-AkariCard $tog 'Default'; Show $e
"togChecked=$($e.Control.IsChecked)"; "togThree=$($e.Control.IsThreeState)"; "togState=$($e.StateLine.Visibility)"; "togDesc=$(($e.Description.Inlines | ForEach-Object { $_.Text }) -join '')"
$e = New-AkariCard $tog 'Unknown'; Show $e
"unkThree=$($e.Control.IsThreeState)"; "unkNull=$($null -eq $e.Control.IsChecked)"; "unkState=$($e.StateLine.Text)"
$e = New-AkariCard $adv 'Default'; Show $e
"advDesc=$(($e.Description.Inlines | ForEach-Object { $_.Text }) -join '')"
$e = New-AkariCard $ch 'Custom' 0x28; Show $e
"chItems=$($e.Control.Items.Count)"; "chRec=$($e.Control.Items[0].Content)"; "chDef=$($e.Control.Items[2].Content)"; "chSel=$($e.Control.SelectedItem.Tag)"
"chState=$($e.StateLine.Text)"; "chValue=$(Get-AkariComboValue $e)"
$e = New-AkariCard $ch 'Custom' 7; Show $e
"chTyped=$($e.Control.Text)"
Set-AkariCardControl $e 2; "chBack=$(Get-AkariComboValue $e)"
$e = New-AkariCard $act 'Unknown'; Show $e
"actType=$($e.Control.GetType().Name)"; "actState=$($e.StateLine.Visibility)"
$e = New-AkariCard $tog 'Default'; Show $e
Set-AkariCardControl $e 'Optimized'; "setOn=$($e.Control.IsChecked)"
'@
    $out = @{}
    & powershell -NoProfile -STA -ExecutionPolicy Bypass -File $probe -Root $Root 2>&1 | ForEach-Object {
        $l = "$_"; $i = $l.IndexOf('='); if ($i -gt 0) { $out[$l.Substring(0, $i)] = $l.Substring($i + 1) } else { $out['error'] += $l }
    }

    It 'builds without errors' { $out['error'] | Should BeNullOrEmpty }

    It 'shows a two-state switch for a known State' {
        $out.togChecked | Should Be 'False'
        $out.togThree | Should Be 'False'
        $out.togState | Should Be 'Collapsed'
        $out.togDesc | Should Match 'Restart required'
    }

    It 'shows a three-state switch for Unknown' {
        $out.unkThree | Should Be 'True'
        $out.unkNull | Should Be 'True'
        $out.unkState | Should Be 'State unknown'
    }

    It 'starts an Advanced description with the Risk' { $out.advDesc | Should Match '^Advanced' }

    It 'lists Choices with Recommended and Windows default marked' {
        $out.chItems | Should Be '3'
        $out.chRec | Should Be 'A (Recommended)'
        $out.chDef | Should Be 'C (Windows default)'
        $out.chSel | Should Be '40'
        $out.chState | Should Be 'Custom value'
        $out.chValue | Should Be '40'
    }

    It 'shows an unlisted value as typed text, and can be set back' {
        $out.chTyped | Should Be '7'
        $out.chBack | Should Be '2'
    }

    It 'uses a checkbox for an Action, with no state line' {
        $out.actType | Should Be 'CheckBox'
        $out.actState | Should Be 'Collapsed'
    }

    It 'sets a switch to a target' { $out.setOn | Should Be 'True' }
}

