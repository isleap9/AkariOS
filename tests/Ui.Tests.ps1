$Root = Join-Path (Split-Path $PSScriptRoot) 'src'

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

    # PowerShell 5.1 reads a file without a BOM as ANSI: "›" in a string would show as "â€º"
    It 'UI scripts without a UTF-8 BOM keep non-ASCII text out of their code' {
        $bad = foreach ($f in Get-ChildItem "$Root\UI\*.ps1") {
            $b = [IO.File]::ReadAllBytes($f.FullName)
            if ($b.Length -ge 3 -and $b[0] -eq 0xEF -and $b[1] -eq 0xBB -and $b[2] -eq 0xBF) { continue }
            $n = 0
            foreach ($l in [Text.Encoding]::UTF8.GetString($b) -split "`n") { $n++; if ($l -notmatch '^\s*#' -and $l -match '[^\x00-\x7F]') { "$($f.Name):$n" } }
        }
        @($bad) -join ', ' | Should Be ''
    }

    It 'MainWindow.xaml parses' {
        $s = "Add-Type -AssemblyName PresentationFramework; [void][Windows.Markup.XamlReader]::Parse((Get-Content '$Root\UI\MainWindow.xaml' -Raw)); 'ok'"
        Test-XamlInChild $s | Should Be 'ok'
    }

    It 'has no tuner left' {
        $hits = Select-String -Path @("$Root\Akari.ps1", "$Root\UI\*.ps1", "$Root\UI\*.xaml") -Pattern 'Tuner|Read-Prio|Read-Svc|SvcCur'
        @($hits).Count | Should Be 0
    }

    It 'has no Home spec cards left' {
        Test-Path "$Root\UI\Home.ps1" | Should Be $false
        $hits = Select-String -Path @("$Root\Akari.ps1", "$Root\UI\*.ps1", "$Root\UI\*.xaml") -Pattern 'SpecData|SpecJob|CopySpecs|Get-Specs|Update-Home'
        @($hits).Count | Should Be 0
    }

    It 'Controls.xaml parses and defines every style' {
        $s = "Add-Type -AssemblyName PresentationFramework; `$d = [Windows.Markup.XamlReader]::Parse((Get-Content '$Root\UI\Controls.xaml' -Raw)); " +
             "`$miss = @('Switch', 'Combo', 'ComboItem', 'Segmented', 'SegItem', 'Check', 'SettingCard', 'CategoryCard', 'Accent', 'StepDot', 'ModeCard' | Where-Object { -not `$d.Contains(`$_) }); " +
             "if (`$miss) { 'missing: ' + (`$miss -join ', ') } else { 'ok' }"
        Test-XamlInChild $s | Should Be 'ok'
    }
}

Describe 'Fonts (Assets\Fonts)' {
    Add-Type -AssemblyName PresentationCore, PresentationFramework
    . "$Root\UI\Cards.ps1"
    $dir = "$Root\Assets\Fonts"
    $files = @{ 'Unbounded' = 'Unbounded-SemiBold', 'Unbounded-Bold'; 'Manrope' = 'Manrope-Medium', 'Manrope-SemiBold', 'Manrope-Bold'; 'JetBrains Mono' = 'JetBrainsMono-Medium' }

    It 'ships each static TTF with its family name, and an OFL licence per family' {
        foreach ($fam in $files.Keys) {
            foreach ($n in $files[$fam]) {
                $g = [Windows.Media.GlyphTypeface]::new([Uri]"$dir\$n.ttf")
                "$n=$($g.FamilyNames['en-us'])" | Should Be "$n=$fam"
            }
        }
        foreach ($l in 'Unbounded', 'Manrope', 'JetBrainsMono') { (Get-Content "$dir\$l-OFL.txt" -Raw) | Should Match 'SIL Open Font License' }
    }
    It 'are static, not variable fonts (WPF ignores variable axes)' {
        foreach ($f in Get-ChildItem $dir -Filter *.ttf) {
            $b = [IO.File]::ReadAllBytes($f.FullName); $n = $b[4] * 256 + $b[5]
            $tags = for ($i = 0; $i -lt $n; $i++) { [Text.Encoding]::ASCII.GetString($b, 12 + 16 * $i, 4) }
            "$($f.Name):$($tags -contains 'fvar')" | Should Be "$($f.Name):False"
        }
    }
    It 'load from the folder as FontDisplay, FontText and FontMono with every weight the UI uses' {
        $f = Get-AkariFonts $dir
        $w = { param($k) (@($f[$k].GetTypefaces() | ForEach-Object { "$($_.Weight)" }) | Sort-Object -Unique) -join ',' }
        & $w 'FontDisplay' | Should Be 'Bold,SemiBold'
        & $w 'FontText' | Should Be 'Bold,Medium,SemiBold'
        & $w 'FontMono' | Should Match 'Medium'
    }
    It 'go into the release zip (the workflow ships all of src)' {
        (Get-Content "$Root\..\.github\workflows\release.yml" -Raw) | Should Match 'Copy-Item src/\* dist/AkariOS -Recurse'
    }
    It 'leave no Segoe UI or Consolas in the UI but the fallbacks' {
        @(Select-String -Path "$Root\UI\*.xaml", "$Root\UI\*.ps1" -Pattern 'Segoe UI|Consolas' | Where-Object { $_.Line -notmatch '\./#|^\s*#' }).Count | Should Be 0
    }
}

Describe 'Icons (UI\Icons.xaml, Lucide)' {
    Add-Type -AssemblyName PresentationCore, PresentationFramework
    $text = Get-Content "$Root\UI\Icons.xaml" -Raw
    $dict = [Windows.Markup.XamlReader]::Parse($text)
    $have = @($dict.Keys | ForEach-Object { "$_" })
    . "$Root\UI\Cards.ps1"

    It 'is generated ASCII from Lucide 0.460.0, one geometry per icon inside the 24x24 box' {
        $text | Should Match 'Generated by build/Icons.ps1 from Lucide 0.460.0'
        [regex]::IsMatch($text, '[^\x00-\x7F]') | Should Be $false
        $have.Count | Should BeGreaterThan 50
        foreach ($k in $have) { $b = $dict[$k].Bounds; "$k $($b.Left -ge -0.5 -and $b.Top -ge -0.5 -and $b.Right -le 24.5 -and $b.Bottom -le 24.5)" | Should Be "$k True" }
    }
    It 'has a geometry for every icon the UI names' {
        $used = [Collections.Generic.List[string]]::new()
        foreach ($v in $AkariCategoryGlyphs.Values) { $used.Add($v) }
        $used.Add((Get-AkariCategoryIcon 'Nope'))
        foreach ($f in Get-ChildItem "$Root\UI\*.xaml") { foreach ($m in [regex]::Matches((Get-Content $f.FullName -Raw), 'Ic\.([a-z0-9-]+)\}')) { $used.Add($m.Groups[1].Value) } }
        $patterns = @(
            "Glyph = '([^']+)'",
            "(?:New-AkariIcon|New-AkariGlyph|New-AkariModeCard|New-AkariCatalogueBar|Set-AkariIcon\s+\`$\w+)\s+'([^']+)'",
            "New-AkariMenuItem\s+(?:'[^']*'|\`$\S+)\s+'([^']+)'",
            "New-AkariNavButton\s+'[^']*'\s+'[^']*'\s+'([^']+)'",
            "Set-AkariIcon[^\n]*?\{ '([a-z0-9-]+)' \} else",
            "Set-AkariIcon[^\n]*else \{ '([a-z0-9-]+)' \}",
            "\`$g = if [^\n]*else \{ '([a-z0-9-]+)' \}",
            "'(?:GitHub|Report a bug|Discord)' = '([^']+)'"
        )
        foreach ($f in Get-ChildItem "$Root\UI\*.ps1") {
            $src = Get-Content $f.FullName -Raw
            foreach ($p in $patterns) { foreach ($m in [regex]::Matches($src, $p)) { $used.Add($m.Groups[1].Value) } }
        }
        # the patterns catch every kind of use (guard), then each name must be an icon
        foreach ($n in 'copy', 'square', 'external-link', 'arrow-left', 'file-input', 'triangle-alert', 'house', 'gamepad-2') { "$n $($used -contains $n)" | Should Be "$n True" }
        $miss = @($used | Sort-Object -Unique | Where-Object { "Ic.$_" -notin $have -and $_ -notmatch '^(Bad|Warn|Mu|Ter|Tx|Acc|Ok|Inherit)$' })
        ($miss -join ', ') | Should Be ''
    }
    It 'leaves no Segoe Fluent glyph or Icons font in the UI' {
        @(Select-String -Path "$Root\UI\*.ps1", "$Root\UI\*.xaml" -Pattern "0x[Ee][0-9A-Fa-f]{3}\b|&#x[Ee][0-9A-Fa-f]{3};|'Icons'|Resource Icons\}").Count | Should Be 0
    }
    It 'draws an icon: a 24x24 path, stroke 2, round caps, its geometry once in the resources' {
        $host_ = [Windows.Controls.Border]::new()
        $host_.Resources.MergedDictionaries.Add($dict)
        $host_.Resources['Tx'] = [Windows.Media.Brushes]::Red
        $i = New-AkariIcon 'zap' 20
        $host_.Child = $i
        $p = $i.Child.Children[0]
        "$($i.Width)|$($i.Child.Width)|$($p.StrokeThickness)|$($p.StrokeStartLineCap)|$($p.StrokeLineJoin)|$($null -ne $p.Data)|$($p.Stroke)" | Should Be "20|24|2|Round|Round|True|#FFFF0000"
        Set-AkariIcon $i 'x'
        "$($i.Tag)|$($p.Data -eq $dict['Ic.x'])" | Should Be 'x|True'
    }
}

Describe 'Themes (UI\Theme.Dark.xaml, UI\Theme.Light.xaml)' {
    # brushes, and the colours a DropShadowEffect needs (AccC)
    $keys = { param($f) $x = ([xml](Get-Content $f -Raw)).ResourceDictionary; @($x.SolidColorBrush) + @($x.Color) | Where-Object { $_ } | ForEach-Object { $_.Key } }
    $dark = @(& $keys "$Root\UI\Theme.Dark.xaml" | Sort-Object)
    $light = @(& $keys "$Root\UI\Theme.Light.xaml" | Sort-Object)

    It 'both parse as WPF resource dictionaries' {
        $s = "Add-Type -AssemblyName PresentationFramework; foreach (`$n in 'Dark', 'Light') { [void][Windows.Markup.XamlReader]::Parse((Get-Content ('$Root\UI\Theme.' + `$n + '.xaml') -Raw)) }; 'ok'"
        Test-XamlInChild $s | Should Be 'ok'
    }

    It 'hold the same brush keys' {
        $dark.Count | Should BeGreaterThan 20
        ($dark -join ',') | Should Be ($light -join ',')
    }

    # every brush a XAML file or a SetResourceReference / FindResource names, minus the styles and fonts the UI defines
    It 'define every brush the UI uses' {
        $xaml = Get-ChildItem "$Root\UI\*.xaml" | Where-Object { $_.Name -notlike 'Theme.*' }
        $defined = foreach ($f in $xaml) { ([regex]::Matches((Get-Content $f.FullName -Raw), 'x:Key="([^"{]+)"')) | ForEach-Object { $_.Groups[1].Value } }
        $used = @(
            foreach ($f in $xaml) { [regex]::Matches((Get-Content $f.FullName -Raw), '\{(?:Dynamic|Static)Resource ([A-Za-z0-9]+)\}') | ForEach-Object { $_.Groups[1].Value } }
            foreach ($f in Get-ChildItem "$Root\UI\*.ps1") { [regex]::Matches((Get-Content $f.FullName -Raw), "(?:SetResourceReference\([^,]+,\s*|FindResource\()'([A-Za-z0-9]+)'") | ForEach-Object { $_.Groups[1].Value } }
        ) | Sort-Object -Unique
        # the fonts are put in the window's resources by UI\Shell.ps1 (Get-AkariFonts), not by a theme
        $fonts = 'FontDisplay', 'FontText', 'FontMono'
        $miss = @($used | Where-Object { $_ -notin $defined -and $_ -notin $dark -and $_ -notin $fonts })
        ($miss -join ', ') | Should Be ''
    }

    It 'leave no colour literals in the window, controls or dialog XAML' {
        $hits = Select-String -Path "$Root\UI\MainWindow.xaml", "$Root\UI\Controls.xaml", "$Root\UI\Dialog.xaml" -Pattern '#[0-9A-Fa-f]{6,8}\b'
        @($hits | ForEach-Object { "$($_.Filename):$($_.LineNumber)" }) -join ', ' | Should Be ''
    }

    It 'have no Inv / InvT left (renamed Acc / AccT)' {
        $hits = Select-String -Path "$Root\UI\*.xaml", "$Root\UI\*.ps1" -Pattern "Resource Inv(T)?\}|'Inv(T)?'"
        @($hits).Count | Should Be 0
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
$host_.Resources.MergedDictionaries.Add([Windows.Markup.XamlReader]::Parse((Get-Content "$Root\UI\Icons.xaml" -Raw)))
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
# a Choice with up to 4 values that can't be typed: the segmented picker, driven by the same row code
$seg = ConvertTo-AkariTweak @{ Id = 'seg'; Name = 'Seg'; Description = 'D'; Kind = 'Choice'; Risk = 'Safe'; Recommended = 1; Default = 0
    Registry = @{ Path = 'HKCU:\x'; Name = 'S'; Type = 'DWord' }; Choices = @(@{ Value = 0; Label = 'Off' }, @{ Value = 1; Label = 'On' }, @{ Value = 2; Label = 'Max' }) } 'x' $false
$e = New-AkariTweakRow $seg 'Default' 0; Show $e
Set-AkariRowControl $e 2; $v2 = Get-AkariComboValue $e
Set-AkariRowControl $e 'None'
"seg=$($e.Control.GetType().Name)|$($e.Control.Items.Count)|$v2|$(Get-AkariComboValue $e)|$($e.Control.Style -eq $host_.FindResource('Segmented'))"
"chType=$((New-AkariTweakRow $ch 'Default' 0x26).Control.GetType().Name)"
$e = New-AkariTweakRow $act 'Unknown'; Show $e
"actType=$($e.Control.GetType().Name)"; "actGlyphs=$($e.Glyphs.Children.Count)"
$ak = ConvertTo-AkariTweak @{ Id = 'ak'; Name = 'Ak'; Description = 'D'; Risk = 'Safe'; AkariOS = $true } 'x' $false
$e = New-AkariTweakRow $ak 'Default'; Show $e
function Shown($tb) { [Windows.Documents.TextRange]::new($tb.ContentStart, $tb.ContentEnd).Text }
"akName=$(Shown $e.Control.Content)"; "plainName=$(Shown (New-AkariTweakRow $tog 'Default').Control.Content)"
$c = New-AkariCategoryCard 'Windows' 'app-window' 'Not yet ported'
"cardHead=$($c.Panel.Children[0].Children.Count)|$($c.Panel.Children[0].Children[1].Tag)|$($null -ne $c.Count)"
$b = New-AkariBadge 'Advanced'; "badge=$($b.Tag)|$($b.Child.Text)"
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

    It 'shows a short Choice as the segmented picker (same items, same row code), an editable one as a combobox' {
        $out.seg | Should Be 'ListBox|4|2|None|True'
        $out.chType | Should Be 'ComboBox'
    }

    It 'shows an Action as a checkbox with no state glyph' {
        $out.actType | Should Be 'CheckBox'
        $out.actGlyphs | Should Be '0'
    }

    It 'builds a category card head: count pill, icon blob, note, title' { $out.cardHead | Should Be '4|app-window|True' }
    It 'builds a Risk badge' { $out.badge | Should Be 'Advanced|Advanced' }

    It 'marks a Tweak of the AkariOS setup with (AkariOS) after its name' {
        $out.akName | Should Be 'Ak (AkariOS)'
        $out.plainName | Should Be 'Tog'
    }
}

Describe 'Shell navigation' {
    # builds the shell in a child STA PowerShell with fixture tweaks; the window is never shown (no ShowDialog)
    $probe = "$TestDrive\shell.ps1"
    Set-Content $probe -Value @'
param($Root, $LogFile, $Install)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName PresentationFramework
$AkariLogFile = $LogFile
$AkariPresetDir = Join-Path (Split-Path $LogFile) 'presets'
foreach ($f in 'Log', 'Registry', 'Loader', 'State', 'Runner', 'Restore', 'Version', 'Update', 'Unattend', 'Presets') { . "$Root\Core\$f.ps1" }
# the Install USB page reads no drive and no PC setting here
function Get-AkariSetupDrives { }
function Get-AkariUnattendDefaults { @{} }
$AkariInstallDir = $Install
function L($id, $page, $name) { ConvertTo-AkariTweak @{ Id = $id; Name = $name; Description = 'D'; Section = $page; Category = ''; Risk = 'Safe'; Kind = 'Action'; Button = 'Run'; Apply = { } } 'x' $true }
$script:Tweaks = [System.Collections.Generic.List[object]]::new()
foreach ($t in @((L 'dark' 'Windows' 'Dark theme'), (L 'bios' 'Check' 'BIOS check'), (L 'leg-adv' 'Advanced' 'Old advanced'),
    (ConvertTo-AkariTweak @{ Id = 'tuning'; Name = 'Theme tuning'; Description = 'D'; Section = 'Advanced'; Category = 'Tuning'; Risk = 'Safe'; Kind = 'Action'; Button = 'Run'; Apply = { } } 'x' $false),
    # the Catalogue (Optimize › Advanced): a Toggle that needs Explorer restarted, a Safe Mode Toggle
    (ConvertTo-AkariTweak @{ Id = 'cat-tog'; Name = 'Cat toggle'; Description = 'D'; Section = 'Customize'; Category = 'Taskbar'; Risk = 'Safe'; Explorer = $true; Apply = { }; Revert = { } } 'x' $false),
    (ConvertTo-AkariTweak @{ Id = 'cat-safe'; Name = 'Cat safe'; Description = 'D'; Section = 'Advanced'; Category = 'Security'; Risk = 'Safe'; SafeMode = $true; Reboot = $true; Apply = { }; Revert = { } } 'x' $false))) { $script:Tweaks.Add($t) }
$script:Groups = @(); $script:RowCache = @{}; $script:Cat = 'Home'; $script:Busy = $false; $script:Job = $null
$script:Queue = [System.Collections.Concurrent.ConcurrentQueue[string]]::new()
$loaded = @{ Problems = @() }
function Get-AkariAppxInstalled { @() }; function Start-AkariFeatureRead { }
foreach ($f in 'Dialog', 'Selection', 'Catalogue', 'Cards', 'Apps', 'Steps', 'Shell', 'Rows', 'CataloguePage', 'About', 'UnattendForm', 'Unattend', 'ImportExport') { . "$Root\UI\$f.ps1" }
$timer.Stop()
# the launch prompt is a dialog: record it instead
function Show-AkariUpdatePrompt { $script:Prompted = $true }
function Click($b) { $b.RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Primitives.ButtonBase]::ClickEvent)) }
function Rows { ($Rows.Children | ForEach-Object { if ($_ -is [Windows.Controls.TextBlock]) { 'msg' } else { $_.Child.Children[0].Children[1].Children[0].Text } }) -join ',' }
"nav=$(($Nav.Children | ForEach-Object { $_.Tag }) -join ',')"
Select-AkariPage 'Home'; "home=$($HomePanel.Visibility),$($PaneCol.Width.Value)"
Click $HomeTiles.Children[1]; "optimize=$script:Cat,$($StepsPanel.Visibility),$($PaneCol.Width.Value),$($StepBody.Children[0].Children.Count)"
Click $StepBody.Children[0].Children[1]; "legacy=$script:Cat,$($PaneCol.Width.Value),$(Rows)"
Select-AkariPage 'Advanced'; "advanced=$(Rows)"
Select-AkariPage 'Windows'; "windows=$(Rows),$(($Nav.Children | Where-Object { $_.IsChecked }).Tag)"
($Nav.Children | Where-Object { $_.Tag -eq 'Downloads' }).IsChecked = $true; "downloads=$script:Cat,$script:FlowExit,$($PaneCol.Width.Value)"
Click $StepBack; "dlBack=$script:Cat,$(($Nav.Children | Where-Object { $_.IsChecked }).Tag)"
$Search.Text = 'theme'; "search=$(Rows)"; $Search.Text = ''
$Nav.Children[0].IsChecked = $true; "backToChooser=$script:Cat,$($PaneCol.Width.Value)"
Click $StepBack; "chooserBack=$script:Cat"
Click $HomeTiles.Children[2]; "dlHome=$script:FlowExit"
Select-AkariPage 'Home'; "aboutLink=$($null -eq $window.FindName('AboutLink'))"; Click $AppVersion; "about=$script:Cat,$($StepsPanel.Visibility),$($PaneCol.Width.Value),$($HomePanel.Visibility)"
"aboutVersion=$($script:AboutParts.Version.Text)"
"aboutLinks=$(($script:AboutParts.Links.Children | Where-Object { $_.Visibility -eq 'Visible' } | ForEach-Object { $_.Content }) -join ',')"
"aboutCredits=$($script:AboutParts.Credits.Children.Count),$($script:AboutParts.Credits.Children[0].Children[0].Inlines.FirstInline.Inlines.FirstInline.Text)"
"aboutLicense=$($script:AboutParts.License.Text -replace '[^ -~]', '?')"
# the window is never shown here (no layout pass): check the column's definition
$cd = $script:AboutParts.Column.ColumnDefinitions
$cr = $script:AboutParts.Credits.Children[0]
"aboutLayout=$($cd.Count),$($cd[0].Width.IsStar),$($cd[0].MaxWidth),$($script:AboutParts.Column.Children[0].Children.Count)"
"aboutCreditLink=$($cr.Children[0].Inlines.FirstInline.NavigateUri),$(@($script:AboutParts.Credits.Children | ForEach-Object { $_.Children } | Where-Object { $_ -is [Windows.Controls.Button] }).Count)"
"aboutLicenseLink=$($script:AboutParts.License.Parent.Orientation),$($script:AboutParts.License.Parent.Children[1].Content)"
"appVersion=$($AppVersionText.Text)"
Click $StepBack; "aboutBack=$script:Cat"
# the Install USB tile (fourth of five): full window, Back leads Home
"tiles=$(($HomeTiles.Children | ForEach-Object { $_.Content.Children[1].Text }) -join ',')|$($HomeTiles.Columns)"
Click $HomeTiles.Children[3]; "usbFile=$script:Cat|$($Heading.Text)|$($PaneCol.Width.Value)|$($StepNext.Visibility)|$($null -ne $script:UnattendParts.Drive)"
Click $StepBack; "usbFileBack=$script:Cat"
"title=$($window.FindName('TitleText').Text)"
$fam = { param($e) "$($e.FontFamily.Source)".Split(',')[0] }
"fonts=$(& $fam $window)|$(& $fam $Heading)|$($Heading.FontSize)|$(& $fam $window.FindName('TitleText'))|$(& $fam $AppVersionText)"
"menu=$(($MainMenu.Items | ForEach-Object { if ($_ -is [Windows.Controls.Separator]) { '-' } elseif ($_.IsEnabled) { $_.Header } else { "($($_.Header))" } }) -join ',')"
$MainMenu.Items[$MainMenu.Items.Count - 1].RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.MenuItem]::ClickEvent)); "menuAbout=$script:Cat"
# themes: the menu row cycles Follow Windows -> Dark -> Light, swaps the one theme dictionary and saves the choice
"themeStart=$script:ThemeSetting,$(@($window.Resources.MergedDictionaries | Where-Object { $_.Contains('Acc') }).Count)"
$tm = $MainMenu.Items | Where-Object { $_ -is [Windows.Controls.MenuItem] -and "$($_.Header)" -like 'Theme:*' }
$tm.RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.MenuItem]::ClickEvent))
$tm.RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.MenuItem]::ClickEvent))
"themeLight=$($tm.Header)|$($window.FindResource('Bg').Color)|$(@($window.Resources.MergedDictionaries | Where-Object { $_.Contains('Acc') }).Count)|$(Get-AkariThemeSetting)|$($Body.Background.Color)"
$lightLogo = Split-Path $Logo.Source.UriSource.LocalPath -Leaf
Set-AkariTheme 'Dark'; "themeDark=$($window.FindResource('Bg').Color)|$(Get-AkariThemeSetting)"
"logo=$lightLogo|$(Split-Path $Logo.Source.UriSource.LocalPath -Leaf)"
Set-AkariTheme 'Nonsense'; "themeBad=$script:ThemeSetting"
Set-AkariTheme 'Dark' -Save
Click $StepBack
# Import settings (the menu item): a settings file, picked through the stubbed file dialog, opens Guided on its Tweaks step
$importFile = Join-Path (Split-Path $LogFile) 'import.json'
Set-Content $importFile '{ "Name": "Imported", "Tweaks": [ "cat-tog" ] }'
function Select-AkariSettingsFile($Save) { $importFile }
$MainMenu.Items[0].RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.MenuItem]::ClickEvent))
"import=$script:Cat|$script:Mode|$script:Step|$(@($script:Sel.Keys) -join ',')|$(Test-Path (Join-Path $AkariPresetDir 'import.json'))"
Select-AkariPage 'Home'
$rel = @{ Ok = $true; Version = [version]'9.0.0'; Notes = "## New`n- **fast**"; PageUrl = 'https://example.test/r'; AssetUrl = 'https://example.test/a.zip'; Digest = 'sha256:x' }
$script:Prompted = $false; Complete-AkariUpdateCheck $rel $false; "launch=$script:Prompted,$($UpdateBar.Visibility),$($UpdateText.Text)"
Select-AkariPage 'Optimize'; $script:Prompted = $false; Complete-AkariUpdateCheck $rel $false; "launchAway=$script:Prompted"
Select-AkariPage 'About'; "aboutAvail=$($script:AboutParts.Status.Text)|$($script:AboutParts.Update.Visibility)|$($script:AboutParts.Notes.Text -replace "`n", '/' -replace [char]0x2022, '*')"
Complete-AkariUpdateCheck @{ Ok = $false; Message = 'No releases yet.' } $true; "aboutError=$($script:AboutParts.Status.Text)|$($script:AboutParts.Update.Visibility)"
Complete-AkariUpdateCheck @{ Ok = $true; Version = [version]$AkariVersion } $false; "latest=$($UpdateBar.Visibility)"
# dialogs: built, never shown (ShowDialog would wait for a click)
$d = New-AkariDialog 'Body text' 'AkariOS update' @('Later', 'Update now') 'Warning'
$bs = @($d.FindName('DlgButtons').Children)
"dlg=$($d.FindName('DlgTitle').Text)|$($d.FindName('DlgText').Text)|$(($bs | ForEach-Object { $_.Content }) -join ',')|$($bs[1].Style -eq $window.FindResource('BtnP')),$($bs[1].IsDefault),$($bs[0].IsCancel)|$($d.FindName('DlgIcon').Visibility)|$($d.FindName('DlgInput').Visibility)"
$bs[1].RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Primitives.ButtonBase]::ClickEvent)); "dlgClick=$($d.Tag.Result)"
"dlgPlain=$((New-AkariDialog 'x' 'T' @('OK') 'None').FindName('DlgIcon').Visibility)"
function Invoke-AkariDialog($Dialog) { $script:Shown = $Dialog; 'Update now' }
"confirm=$(Confirm-AkariDialog 'q' 'Update now' 'Later'),$(Confirm-AkariDialog 'q' 'Start One-click'),$($script:Shown.FindName('DlgTitle').Text)"
function Invoke-AkariDialog($Dialog) { $Dialog.FindName('DlgInput').Text = '  My preset  '; 'Save' }
"readText=$(Read-AkariText 'A name:' 'Save')|$($null -eq (Read-AkariText 'A name:' 'Keep'))"
"overlay=$($window.FindName('ModalOverlay').Visibility)"
# the Catalogue (Optimize › Advanced): no real job, restore point or dialog
function Confirm-AkariDialog { $true }
function Add-AkariRestoreFirst($Code, $Button) { $Code }
function Test-AkariSafeMode { $false }
$script:Jobs = @()
function Start-AkariJob($Code, $Queue, $CoreDir, $Shared) { $script:Jobs += , @{ Code = $Code; Shared = $Shared }; @{ Handle = [pscustomobject]@{ IsCompleted = $false }; Shared = $Shared } }
Select-AkariPage 'Optimize'; Click $StepBody.Children[0].Children[0]
"catNav=$(($Nav.Children | ForEach-Object { if ($_ -is [Windows.Controls.TextBlock]) { '#' + $_.Text } else { $_.Tag } }) -join ',')"
"catFirst=$script:Cat|$($Heading.Text)|$($PaneCol.Width.Value)|$(($Nav.Children | Where-Object { $_.IsChecked }).Tag)"
$tog = $script:CatCards['cat-tog']
"catReading=$($tog.StateText.Text -replace '[^ -~]', '.')|$($tog.Control.IsEnabled)|$($script:Jobs.Count)"
Set-AkariCatalogueStates @{ 'cat-tog' = @{ State = 'Default'; Current = $null } }
"catRead=$($tog.StateText.Text)|$($tog.Control.IsChecked)|$($tog.Control.IsEnabled)"
$tog.Control.IsChecked = $true; Click $tog.Control
"catRun=$($tog.StateText.Text -replace '[^ -~]', '.')|$($script:Job.Kind)|$($script:Jobs[-1].Code -match 'Invoke-AkariTweak')|$($script:Jobs[-1].Shared.Mode)"
# a second change while the first runs: it queues
[void](Get-AkariCatalogueCard ($script:Tweaks | Where-Object { $_.Id -eq 'tuning' }))
Invoke-AkariCatalogueChange 'tuning' 'Apply' $null
"catQueued=$($script:CatQueue.Count)|$($script:CatCards['tuning'].StateText.Text -replace '[^ -~]', '.')|$($script:Jobs.Count)"
$j = $script:Job; $j.Shared.Outcome = [pscustomobject]@{ Outcome = 'Applied'; Message = '' }; $j.Shared.State = 'Optimized'; $script:Job = $null
Complete-AkariCatalogueJob $j; Start-AkariCatalogueNext
"catDone=$($tog.StateText.Text)|$($tog.Control.IsChecked)|$($script:RestartBar.Bar.Visibility)|$($script:RestartBar.Text.Text)|$($script:RestartBar.Explorer.Visibility)"
"catNext=$($script:Job.Shared.Id)|$($script:CatQueue.Count)"
$j = $script:Job; $j.Shared.Outcome = [pscustomobject]@{ Outcome = 'Failed'; Message = 'boom' }; $script:Job = $null; Complete-AkariCatalogueJob $j
"catFailed=$($script:CatCards['tuning'].StateText.Text)"
# a Safe Mode Toggle waits in the bar; switched back, it leaves it
Select-AkariPage 'Catalogue:Advanced/Security'
$safe = $script:CatCards['cat-safe']
Set-AkariCatalogueStates @{ 'cat-safe' = @{ State = 'Default'; Current = $null } }
$n = $script:Jobs.Count
$safe.Control.IsChecked = $true; Click $safe.Control
"catSafe=$($script:SafePending['cat-safe'].Mode)|$($safe.StateText.Text)|$($CatBars.Visibility)|$($script:SafeBar.Bar.Visibility)|$($script:Jobs.Count - $n)"
$safe.Control.IsChecked = $false; Click $safe.Control
"catSafeBack=$($script:SafePending.Count)|$($script:SafeBar.Bar.Visibility)|$($safe.Control.IsChecked)"
# Remove apps and Downloads at the top of the sidebar: full window, Back returns to the Catalogue page
($Nav.Children | Where-Object { $_.Tag -eq 'Remove apps' }).IsChecked = $true
"catRemove=$script:Cat|$script:Mode|$script:FlowExit|$($PaneCol.Width.Value)|$($Heading.Text)"
Click $StepBack; "catRemoveBack=$script:Cat|$(($Nav.Children | Where-Object { $_.IsChecked }).Tag)|$($PaneCol.Width.Value)"
($Nav.Children | Where-Object { $_.Tag -eq 'Downloads' }).IsChecked = $true; "catDownloads=$script:Cat|$script:Mode|$script:FlowExit"
Click $StepBack; "catDownloadsBack=$script:Cat"
# the 48 px icon strip has no room for a scrollbar: hidden there (the wheel still scrolls), back when the pane opens
Click $PaneToggle; "paneCompact=$($PaneCol.Width.Value)|$($NavScroll.VerticalScrollBarVisibility)"
Click $PaneToggle; "paneOpen=$($PaneCol.Width.Value)|$($NavScroll.VerticalScrollBarVisibility)"
# search: every Catalogue Tweak, a heading per Section › Category
$Search.Text = 'Cat'
"catSearch=$($Heading.Text)|$(($Rows.Children | Where-Object { $_ -is [Windows.Controls.TextBlock] } | ForEach-Object { $_.Text -replace '[^ -~]', '>' }) -join ',')|$(@($Rows.Children | Where-Object { $_ -is [Windows.Controls.Border] }).Count)"
$Search.Text = ''
# back to Optimize, then Legacy: the sidebar lists the Legacy pages again
Select-AkariPage 'Optimize'; Click $StepBody.Children[0].Children[1]
"catLeft=$script:Cat|$(($Nav.Children | ForEach-Object { $_.Tag }) -join ',')|$($CatBars.Visibility)"
'@
    $out = @{}
    & powershell -NoProfile -STA -ExecutionPolicy Bypass -File $probe -Root $Root -LogFile "$TestDrive\a.log" -Install "$TestDrive\inst" 2>&1 | ForEach-Object {
        $l = "$_"; $i = $l.IndexOf('='); if ($i -gt 0 -and $l -notmatch '^\[') { $out[$l.Substring(0, $i)] = $l.Substring($i + 1) } elseif ($l -notmatch '^\[') { $out['error'] += $l }
    }

    It 'builds without errors' { $out['error'] | Should BeNullOrEmpty }
    It 'the sidebar holds only the way back and the Legacy pages' {
        $out.nav | Should Be 'Optimize,Check,Refresh,Setup,Downloads,Graphics,Windows,Hardware,Advanced'
    }
    It 'Home has no sidebar' { $out.home | Should Be 'Visible,0' }
    It 'the Optimize tile opens the chooser, full window' { $out.optimize | Should Be 'Optimize,Visible,0,2' }
    It 'Legacy opens Check with the sidebar, legacy rows only' {
        $out.legacy | Should Be 'Check,232,BIOS check'
        $out.advanced | Should Be 'Old advanced'
        $out.windows | Should Be 'Dark theme,Windows'
    }
    It 'Downloads from Legacy is full window and Back returns to that page' {
        $out.downloads | Should Be 'Downloads,Windows,0'
        $out.dlBack | Should Be 'Windows,Windows'
    }
    It 'search lists legacy matches only' { $out.search | Should Be 'Dark theme' }
    It '<- Optimize goes to the chooser, whose Back goes Home' {
        $out.backToChooser | Should Be 'Optimize,0'
        $out.chooserBack | Should Be 'Home'
    }
    It 'Downloads from Home exits to Home' { $out.dlHome | Should Be 'Home' }
    It 'the status bar version opens About, full window, and Back goes Home; Home has no About link' {
        $out.aboutLink | Should Be 'True'
        $out.about | Should Be 'About,Visible,0,Collapsed'
        $out.aboutVersion | Should Match '^AkariOS \d+\.\d+\.\d+$'
        $out.aboutBack | Should Be 'Home'
    }
    It 'the Install USB tile opens its form full window, and Back goes Home' {
        $out.tiles | Should Be 'Install AkariOS,Optimize,Downloads,Install USB,Import / Export settings|5'
        $out.usbFile | Should Be 'Install USB|Install USB|0|Collapsed|True'
        $out.usbFileBack | Should Be 'Home'
    }
    It 'About lists the links (a link without a URL is hidden), the credits and the license' {
        $out.aboutLinks | Should Be 'GitHub,Report a bug,Discord,Open log folder'
        $out.aboutCredits | Should Match '^\d+,FR33THY Ultimate$'
        $out.aboutLicense | Should Be 'MIT License ? ? 2026 isleap9'
    }
    # a lone star column with a MaxWidth fills the page up to 800 px and leaves the rest empty on the right
    It 'About is one column on the left, at most 800 px wide, holding the four cards' { $out.aboutLayout | Should Be '1,True,800,4' }
    It 'credit names are links, with no Open buttons; View license sits next to the license text' {
        $out.aboutCreditLink | Should Be 'https://github.com/FR33THYFR33THY/Ultimate,0'
        $out.aboutLicenseLink | Should Be 'Horizontal,View license'
    }
    It 'a dialog: title, text, buttons in order with the last one the white main action (Enter), the first Esc' {
        $out.dlg | Should Be 'AkariOS update|Body text|Later,Update now|True,True,True|Visible|Collapsed'
        $out.dlgClick | Should Be 'Update now'
        $out.dlgPlain | Should Be 'Collapsed'
    }
    It 'Confirm-AkariDialog is $true only for its main action; Read-AkariText trims, and is $null when cancelled' {
        $out.confirm | Should Be 'True,False,AkariOS'
        $out.readText | Should Be 'My preset|True'
        $out.overlay | Should Be 'Collapsed'
    }
    It 'Advanced opens the Catalogue: Section headings and Category pages in the sidebar, the first page open' {
        $out.catNav | Should Be 'Optimize,Remove apps,Downloads,#Customize,Catalogue:Customize/Taskbar,#Advanced,Catalogue:Advanced/Security,Catalogue:Advanced/Tuning'
        $out.catFirst | Should Be 'Catalogue:Customize/Taskbar|Taskbar|232|Catalogue:Customize/Taskbar'
    }
    It 'reads States in the background: the switch waits for its State' {
        $out.catReading | Should Be 'Reading.|False|1'
        $out.catRead | Should Be 'Windows default|False|True'
    }
    It 'a switch applies right away in the job; a second change queues; Explorer changes go to the restart bar' {
        $out.catRun | Should Be 'Applying.|Catalogue|True|Apply'
        $out.catQueued | Should Be '1|Waiting.|2'
        $out.catDone | Should Be 'Optimized|True|Visible|Explorer needs a restart to show 1 change.|Visible'
        $out.catNext | Should Be 'tuning|0'
        $out.catFailed | Should Be 'Failed: boom'
    }
    It 'a Safe Mode Tweak waits in the Safe Mode bar instead of running; switched back, it leaves it' {
        $out.catSafe | Should Be 'Apply|Waiting for Safe Mode|Visible|Visible|0'
        $out.catSafeBack | Should Be '0|Collapsed|False'
    }
    It 'Remove apps and Downloads open full window from the Catalogue sidebar, and Back returns to its page' {
        $out.catRemove | Should Be 'Remove apps|Remove apps|Catalogue:Advanced/Security|0|Remove apps'
        $out.catRemoveBack | Should Be 'Catalogue:Advanced/Security|Catalogue:Advanced/Security|232'
        $out.catDownloads | Should Be 'Downloads|Downloads|Catalogue:Advanced/Security'
        $out.catDownloadsBack | Should Be 'Catalogue:Advanced/Security'
    }
    It 'the compact sidebar hides its scrollbar so the icons keep their 40 px column' {
        $out.paneCompact | Should Be '48|Hidden'
        $out.paneOpen | Should Be '232|Auto'
    }
    It 'search lists every Catalogue match under its Section › Category' {
        $out.catSearch | Should Be 'Search|Customize > Taskbar,Advanced > Security|2'
    }
    It 'leaving for Legacy brings its sidebar back and hides the bars' {
        $out.catLeft | Should Be 'Check|Optimize,Check,Refresh,Setup,Downloads,Graphics,Windows,Hardware,Advanced|Collapsed'
    }
    It 'the title bar says AkariOS' { $out.title | Should Be 'AkariOS' }
    It 'uses Manrope for text, Unbounded 32 for the page title and the wordmark, JetBrains Mono for the version' {
        $out.fonts | Should Be './#Manrope|./#Unbounded|32|./#Unbounded|./#JetBrains Mono'
    }
    It 'the options menu: Import / Export settings, System Restore, the About links, Logs, About' {
        $out.menu | Should Be 'Import settings,Export settings,System Restore,Theme: Follow Windows,-,GitHub,Report a bug,Discord,Logs,About'
        $out.menuAbout | Should Be 'About'
    }
    It 'Import settings opens the file in Guided on the Tweaks step, and keeps a copy in the presets' {
        $out.import | Should Be 'Install AkariOS|Guided|1|cat-tog|True'
    }
    It 'starts on Follow Windows with one theme dictionary' { $out.themeStart | Should Be 'System,1' }
    It 'the Theme menu row cycles to Light: swaps the dictionary, repaints the body and saves the choice' {
        $out.themeLight | Should Be 'Theme: Light|#FFF8F3F1|1|Light|#FFF8F3F1'
    }
    It 'Set-AkariTheme Dark loads the dark brushes without saving' { $out.themeDark | Should Be '#FF0D0A0B|Light' }
    It 'swaps the title bar logo with the theme' { $out.logo | Should Be 'AkariLogo-light.png|AkariLogo-dark.png' }
    It 'an unknown theme falls back to Follow Windows' { $out.themeBad | Should Be 'System' }
    It 'the status bar shows the version' { $out.appVersion | Should Match '^AkariOS \d+\.\d+\.\d+$' }
    It 'a launch check that finds an update asks on Home and shows the Home bar' {
        $out.launch | Should Match '^True,Visible,AkariOS 9\.0\.0 is available'
    }
    It 'a launch check does not ask once the user has left Home' { $out.launchAway | Should Be 'False' }
    It 'About shows the update, its Update button and the notes as text' {
        $out.aboutAvail | Should Match '^AkariOS 9\.0\.0 is available.*\|Visible\|New/\* fast$'
    }
    It 'About shows a failed check and hides Update' { $out.aboutError | Should Be 'No releases yet.|Collapsed' }
    It 'the Home bar hides when there is nothing to install' { $out.latest | Should Be 'Collapsed' }
}

Describe 'About data (UI\About.psd1)' {
    $d = Import-PowerShellDataFile "$Root\UI\About.psd1"
    It 'every link and credit has a name and an https URL (only a link may wait for its URL)' {
        foreach ($l in $d.Links) { $l.Name | Should Not BeNullOrEmpty; if ($l.Url) { $l.Url | Should Match '^https://' } }
        foreach ($c in $d.Credits) { "$($c.Name): $($c.Text) $($c.Url)" | Should Match '^.+: .+ https://\S+$' }
        $d.License.Url | Should Match '^https://'
        $d.FullCredits | Should Match '^https://'
    }
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
