$Root = Join-Path (Split-Path $PSScriptRoot) 'src'

# Parses XAML in a child STA PowerShell (WPF needs STA). No window is created or shown.
function Test-XamlInChild([string]$Script) {
    $out = & powershell -NoProfile -STA -ExecutionPolicy Bypass -Command $Script 2>&1
    @($out | ForEach-Object { "$_" }) -join "`n"
}
# runs a probe script in a child STA PowerShell, its "key=value" lines as a hashtable ('error' = anything else)
function Invoke-Probe([string]$Path, [hashtable]$Params = @{}) {
    $out = @{}
    $a = @('-NoProfile', '-STA', '-ExecutionPolicy', 'Bypass', '-File', $Path)
    foreach ($k in $Params.Keys) { $a += "-$k"; $a += $Params[$k] }
    & powershell @a 2>&1 | ForEach-Object {
        $l = "$_"; $i = $l.IndexOf('='); if ($i -gt 0 -and $l -notmatch '^\[') { $out[$l.Substring(0, $i)] = $l.Substring($i + 1) } elseif ($l -notmatch '^\[') { $out['error'] += $l }
    }
    $out
}

# the styles the UI files define (Controls.xaml, MainWindow.xaml) and use
$AkariStyles = 'Switch', 'CatSwitch', 'Check', 'Radio', 'Combo', 'ComboItem', 'SettingCard', 'CategoryCard', 'CardRow', 'Panel', 'CardButton', 'ExpHead',
    'Accent', 'ModeCard', 'Selector', 'NavItem', 'Crumb'
$AkariRetired = 'Segmented', 'SegItem', 'Tab', 'Chip', 'ModeCardHot', 'StepNum'

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

    It 'UI XAML files are ASCII without a BOM' {
        $bad = foreach ($f in Get-ChildItem "$Root\UI\*.xaml") {
            $b = [IO.File]::ReadAllBytes($f.FullName)
            if (($b.Length -ge 3 -and $b[0] -eq 0xEF) -or @($b | Where-Object { $_ -gt 0x7F }).Count) { $f.Name }
        }
        @($bad) -join ', ' | Should Be ''
    }

    It 'MainWindow.xaml parses' {
        $s = "Add-Type -AssemblyName PresentationFramework; . '$Root\UI\Motion.ps1'; [void](Get-AkariXaml '$Root\UI\MainWindow.xaml'); 'ok'"
        Test-XamlInChild $s | Should Be 'ok'
    }

    It 'has no tuner left' {
        $hits = Select-String -Path @("$Root\Akari.ps1", "$Root\UI\*.ps1", "$Root\UI\*.xaml") -Pattern 'Tuner|Read-Prio|Read-Svc|SvcCur'
        @($hits).Count | Should Be 0
    }

    It 'Controls.xaml parses and defines every style still used' {
        $s = "Add-Type -AssemblyName PresentationFramework; . '$Root\UI\Motion.ps1'; `$d = Get-AkariXaml '$Root\UI\Controls.xaml'; " +
             "`$w = Get-AkariXaml '$Root\UI\MainWindow.xaml'; `$miss = @('$($AkariStyles -join "','")', 'Btn', 'BtnP', 'Ghost', 'Link', 'Flat' | Where-Object { -not `$d.Contains(`$_) -and -not `$w.Resources.Contains(`$_) }); " +
             "if (`$miss) { 'missing: ' + (`$miss -join ', ') } else { 'ok' }"
        Test-XamlInChild $s | Should Be 'ok'
    }

    It 'every style the code names is defined' {
        $defined = foreach ($f in "$Root\UI\Controls.xaml", "$Root\UI\MainWindow.xaml") { [regex]::Matches((Get-Content $f -Raw), '<Style x:Key="([^"]+)"') | ForEach-Object { $_.Groups[1].Value } }
        $used = foreach ($f in Get-ChildItem "$Root\UI\*.ps1") { [regex]::Matches((Get-Content $f.FullName -Raw), "StyleProperty, '([A-Za-z]+)'") | ForEach-Object { $_.Groups[1].Value } }
        $dyn = foreach ($f in Get-ChildItem "$Root\UI\*.ps1") { [regex]::Matches((Get-Content $f.FullName -Raw), "StyleProperty, \`$\(if \([^)]*\) \{ '([A-Za-z]+)' \} else \{ '([A-Za-z]+)' \}") | ForEach-Object { $_.Groups[1].Value; $_.Groups[2].Value } }
        $miss = @(@($used) + @($dyn) | Sort-Object -Unique | Where-Object { $_ -notin $defined -and $_ -ne 'Plain' })
        ($miss -join ', ') | Should Be ''
    }

    It 'retires Segmented, SegItem, Tab, Chip, ModeCardHot and StepNum' {
        $hits = foreach ($k in $AkariRetired) {
            Select-String -Path "$Root\UI\*.xaml", "$Root\UI\*.ps1" -Pattern "x:Key=`"$k`"|'$k'|StaticResource $k\}|DynamicResource $k\}" | ForEach-Object { "$($_.Filename):$($_.LineNumber) $k" }
        }
        @($hits) -join ', ' | Should Be ''
    }

    # decision 8: 4 px controls and cards, 8 px flyouts, dialogs and tiles; full round for toggles (10) and the focus
    # rings (their radius + 3 / + 1)
    It 'has no CornerRadius above 8 but the toggles and the focus rings' {
        $bad = foreach ($f in "$Root\UI\Controls.xaml", "$Root\UI\MainWindow.xaml", "$Root\UI\Dialog.xaml") {
            $x = [xml](Get-Content $f -Raw)
            foreach ($n in $x.SelectNodes('//*[@CornerRadius]')) {
                $p = $n; $key = ''
                while ($p -and $p.NodeType -eq 'Element') { if ($p.LocalName -eq 'Style') { $key = $p.GetAttribute('x:Key') }; $p = $p.ParentNode }
                if ($key -like 'Focus*' -or $n.CornerRadius -like '{*') { continue }
                $max = ($n.CornerRadius -split ',' | ForEach-Object { [double]$_ } | Measure-Object -Maximum).Maximum
                if ($max -gt 8 -and -not ($key -in 'Switch' -and $max -eq 10)) { "$(Split-Path $f -Leaf) $key $($n.CornerRadius)" }
            }
        }
        @($bad) -join ', ' | Should Be ''
    }
}

Describe 'Type (Segoe UI Variable, decision 3)' {
    It 'names Windows'' own fonts, Segoe UI and Consolas as the fallbacks' {
        $x = Get-Content "$Root\UI\Controls.xaml" -Raw
        $x | Should Match '<FontFamily x:Key="FontDisplay">Segoe UI Variable Display, Segoe UI</FontFamily>'
        $x | Should Match '<FontFamily x:Key="FontText">Segoe UI Variable Text, Segoe UI</FontFamily>'
        $x | Should Match '<FontFamily x:Key="FontSmall">Segoe UI Variable Small, Segoe UI</FontFamily>'
        $x | Should Match '<FontFamily x:Key="FontMono">Cascadia Mono, Consolas</FontFamily>'
    }
    It 'ships no fonts and no font loader' {
        Test-Path "$Root\Assets\Fonts" | Should Be $false
        @(Select-String -Path "$Root\UI\*.ps1" -Pattern 'Get-AkariFonts').Count | Should Be 0
    }
    It 'leaves no Unbounded, Manrope or JetBrains anywhere in src' {
        # (JetBrains Toolbox, an app Downloads installs, is not the font)
        $hits = Get-ChildItem $Root -Recurse -File -Include *.ps1, *.psd1, *.xaml, *.json, *.md, *.txt | Select-String -Pattern 'Unbounded|Manrope|JetBrains Mono|JetBrainsMono' -List
        @($hits | ForEach-Object { $_.Path.Substring($Root.Length) }) -join ', ' | Should Be ''
    }
    It 'uses SemiBold or Normal, never Bold or Medium (the Windows 11 ramp)' {
        $hits = Select-String -Path "$Root\UI\*.xaml", "$Root\UI\*.ps1" -Pattern "FontWeight=`"(Bold|Medium)`"|FontWeight = '(Bold|Medium)'|'(Bold|Medium)'\)"
        @($hits | ForEach-Object { "$($_.Filename):$($_.LineNumber)" }) -join ', ' | Should Be ''
    }
}

Describe 'Icons (UI\Icons.xaml, Fluent System Icons)' {
    Add-Type -AssemblyName PresentationCore, PresentationFramework
    $text = Get-Content "$Root\UI\Icons.xaml" -Raw
    $dict = [Windows.Markup.XamlReader]::Parse($text)
    $have = @($dict.Keys | ForEach-Object { "$_" })
    . "$Root\UI\Cards.ps1"

    It 'is generated ASCII from Fluent System Icons 1.1.344, every geometry parsing inside the 20 x 20 box' {
        $text | Should Match 'Generated by build/Icons.ps1 from Fluent System Icons 1.1.344'
        [regex]::IsMatch($text, '[^\x00-\x7F]') | Should Be $false
        $have.Count | Should BeGreaterThan 90
        foreach ($k in $have) { $b = $dict[$k].Bounds; "$k $($b.Left -ge -0.5 -and $b.Top -ge -0.5 -and $b.Right -le 20.5 -and $b.Bottom -le 20.5)" | Should Be "$k True" }
    }
    It 'has a filled icon for every nav page, Optimize''s sections and the InfoBar severities' {
        $want = @('house', 'zap', 'sliders-horizontal', 'download', 'trash-2', 'usb', 'disc-3', 'settings') + @($AkariSectionIcons.Values) + 'info', 'triangle-alert', 'circle-check', 'error-circle'
        @($want | Where-Object { "Ic.$_.Filled" -notin $have }) -join ', ' | Should Be ''
    }
    It 'has a geometry for every icon the UI names' {
        $used = [Collections.Generic.List[string]]::new()
        foreach ($v in @($AkariCategoryGlyphs.Values) + @($AkariSectionIcons.Values)) { $used.Add($v) }
        $used.Add((Get-AkariCategoryIcon 'Nope'))
        foreach ($f in Get-ChildItem "$Root\UI\*.xaml") { foreach ($m in [regex]::Matches((Get-Content $f.FullName -Raw), 'Ic\.([a-z0-9.-]+)\}')) { $used.Add($m.Groups[1].Value) } }
        $patterns = @(
            "Glyph = '([^']+)'",
            "(?:New-AkariIcon|New-AkariGlyph|New-AkariBlob|New-AkariSettingsCard|New-AkariExpander|New-AkariTile|New-AkariEmpty|Set-AkariIcon\s+\S+)\s+'([a-z0-9.-]+)'",
            "New-AkariAppsButton\s+(?:'[^']*'|""[^""]*"")\s+'[^']*'\s+\{[^\n]*\}\s+'([a-z0-9-]+)'",
            "@\('([a-z0-9-]+)', '[^']+', '[^']+', \{",
            "Add-AkariActivity [^\n]* '([a-z0-9-]+)'$",
            "Icon = '([a-z0-9-]+)'",
            "Set-AkariIcon[^\n]*?\{ '([a-z0-9-]+)' \} else",
            "Set-AkariIcon[^\n]*else \{ '([a-z0-9-]+)' \}"
        )
        foreach ($f in Get-ChildItem "$Root\UI\*.ps1") {
            $src = Get-Content $f.FullName -Raw
            foreach ($p in $patterns) { foreach ($m in [regex]::Matches($src, $p, 'Multiline')) { $used.Add($m.Groups[1].Value) } }
            # the tables of names: $AkariNav, $AkariUaSectionIcons
            foreach ($m in [regex]::Matches($src, '\$AkariNav = \[ordered\]@\{([^\n]+)\}')) { foreach ($v in [regex]::Matches($m.Groups[1].Value, "= '([a-z0-9-]+)'")) { $used.Add($v.Groups[1].Value) } }
            foreach ($m in [regex]::Matches($src, '(?s)\$AkariUaSectionIcons = @\((.*?)\)')) { foreach ($v in [regex]::Matches($m.Groups[1].Value, "'([a-z0-9-]+)'")) { $used.Add($v.Groups[1].Value) } }
        }
        # the patterns catch every kind of use (guard), then each name must be an icon
        foreach ($n in 'external-link', 'usb', 'file-input', 'triangle-alert', 'house', 'gamepad-2', 'wand', 'broom', 'globe') { "$n $($used -contains $n)" | Should Be "$n True" }
        $miss = @($used | Sort-Object -Unique | Where-Object { "Ic.$_" -notin $have -and $_ -notmatch '^(Bad|Warn|Mu|Ter|Tx|Acc|AccText|AccT|Ok|Inherit)$' })
        ($miss -join ', ') | Should Be ''
    }
    It 'leaves no Segoe Fluent glyph, Icons font or stroked icon in the UI' {
        @(Select-String -Path "$Root\UI\*.ps1", "$Root\UI\*.xaml" -Pattern "0x[Ee][0-9A-Fa-f]{3}\b|&#x[Ee][0-9A-Fa-f]{3};|'Icons'|Resource Icons\}").Count | Should Be 0
        (Get-Content "$Root\UI\MainWindow.xaml" -Raw) | Should Not Match '<Style x:Key="Ic"[^>]*>\s*<Setter Property="StrokeThickness"'
    }
    It 'draws an icon: a filled 20 x 20 path in its brush, never stroked; Set-AkariIcon points it at another' {
        $host_ = [Windows.Controls.Border]::new()
        $host_.Resources.MergedDictionaries.Add($dict)
        $host_.Resources['Tx'] = [Windows.Media.Brushes]::Red
        $i = New-AkariIcon 'zap' 16
        $host_.Child = $i
        $p = $i.Child
        "$($i.Width)|$($p.Width)|$($p.Height)|$($null -ne $p.Data)|$($p.Fill)|$($null -eq $p.Stroke)" | Should Be "16|20|20|True|#FFFF0000|True"
        Set-AkariIcon $i 'x'
        "$($i.Tag)|$($p.Data -eq $dict['Ic.x'])" | Should Be 'x|True'
    }
}

Describe 'Themes (UI\Theme.Dark.xaml, UI\Theme.Light.xaml)' {
    # brushes, and the colours DropShadowEffects need (Shade*)
    $keys = { param($f) $x = ([xml](Get-Content $f -Raw)).ResourceDictionary; @($x.SolidColorBrush) + @($x.Color) | Where-Object { $_ } | ForEach-Object { $_.Key } }
    $value = { param($f, $k) $x = ([xml](Get-Content $f -Raw)).ResourceDictionary; @(@($x.SolidColorBrush) | Where-Object { $_.Key -eq $k } | ForEach-Object { $_.Color }) + @(@($x.Color) | Where-Object { $_.Key -eq $k } | ForEach-Object { $_.'#text' }) | Select-Object -First 1 }
    $dark = @(& $keys "$Root\UI\Theme.Dark.xaml" | Sort-Object)
    $light = @(& $keys "$Root\UI\Theme.Light.xaml" | Sort-Object)

    It 'both parse as WPF resource dictionaries' {
        $s = "Add-Type -AssemblyName PresentationFramework; . '$Root\UI\Motion.ps1'; foreach (`$n in 'Dark', 'Light') { [void](Get-AkariXaml ('$Root\UI\Theme.' + `$n + '.xaml')) }; 'ok'"
        Test-XamlInChild $s | Should Be 'ok'
    }

    It 'hold the same keys, the plan''s added ones included, no Glow or AccC' {
        $dark.Count | Should BeGreaterThan 40
        ($dark -join ',') | Should Be ($light -join ',')
        @('S1Alt', 'Div', 'Fly', 'TxDis', 'FocusIn', 'Sub', 'SubP', 'CtlBd2', 'OkSoft', 'BadSoft', 'Info', 'InfoSoft' | Where-Object { $_ -notin $dark }) -join ',' | Should Be ''
        @('Glow', 'AccC' | Where-Object { $_ -in $dark }) -join ',' | Should Be ''
    }

    It 'take the plan''s values (Akari crimson the default accent)' {
        foreach ($c in @(@('Bg', '#202020', '#F3F3F3'), @('Surf', '#4D3A3A3A', '#80FFFFFF'), @('Acc', '#FF6B7D', '#C8102E'), @('AccText', '#FFA3AE', '#9E0C24'),
                         @('AccSoft', '#1FFF6B7D', '#14C8102E'), @('Ter', '#8BFFFFFF', '#8F000000'), @('Scrim', '#4D000000', '#4D000000'), @('Line', '#8BFFFFFF', '#72000000'))) {
            "$($c[0]) $(& $value "$Root\UI\Theme.Dark.xaml" $c[0]) $(& $value "$Root\UI\Theme.Light.xaml" $c[0])" | Should Be "$($c[0]) $($c[1]) $($c[2])"
        }
    }

    It 'leave no Glow, AccC or accent glow in the UI' {
        $hits = Select-String -Path "$Root\UI\*.xaml", "$Root\UI\*.ps1" -Pattern "Resource (Glow|AccC)\}|'(Glow|AccC)'"
        @($hits | ForEach-Object { "$($_.Filename):$($_.LineNumber)" }) -join ', ' | Should Be ''
    }

    # every brush a XAML file or a SetResourceReference / FindResource names, minus the styles and fonts the UI defines
    It 'define every brush the UI uses' {
        $xaml = Get-ChildItem "$Root\UI\*.xaml" | Where-Object { $_.Name -notlike 'Theme.*' }
        $defined = foreach ($f in $xaml) { ([regex]::Matches((Get-Content $f.FullName -Raw), 'x:Key="([^"{]+)"')) | ForEach-Object { $_.Groups[1].Value } }
        $used = @(
            foreach ($f in $xaml) { [regex]::Matches((Get-Content $f.FullName -Raw), '\{(?:Dynamic|Static)Resource ([A-Za-z0-9]+)\}') | ForEach-Object { $_.Groups[1].Value } }
            foreach ($f in Get-ChildItem "$Root\UI\*.ps1") { [regex]::Matches((Get-Content $f.FullName -Raw), "(?:SetResourceReference\([^,]+,\s*|FindResource\()'([A-Za-z0-9]+)'") | ForEach-Object { $_.Groups[1].Value } }
        ) | Sort-Object -Unique
        $miss = @($used | Where-Object { $_ -notin $defined -and $_ -notin $dark })
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

Describe 'Accent (Get-AkariAccentColors, decision 2)' {
    Add-Type -AssemblyName PresentationCore, PresentationFramework
    . "$Root\UI\Cards.ps1"
    # a green Windows accent: Light3, Light2, Light1, Base, Dark1, Dark2, Dark3, unused (RGBA each)
    $pal = [byte[]]@(0x9F, 0xF5, 0xB5, 0, 0x6F, 0xD3, 0x8C, 0, 0x3D, 0xB2, 0x63, 0, 0x10, 0x89, 0x3E, 0, 0x0B, 0x6A, 0x2E, 0, 0x07, 0x4C, 0x20, 0, 0x03, 0x2F, 0x13, 0, 0, 0, 0, 0)
    $fmt = { param($c) '{0:X2}{1:X2}{2:X2}{3:X2}' -f $c[0], $c[1], $c[2], $c[3] }
    It 'maps the palette for dark: Acc = Light2, AccText = Info = Light3, AccT black, the 90 / 80 / 12 % shades' {
        $c = Get-AkariAccentColors $pal 'Dark'
        (@('Acc', 'AccH', 'AccP', 'AccSoft', 'AccText', 'Info', 'AccT') | ForEach-Object { "$_=$(& $fmt $c[$_])" }) -join ' ' |
            Should Be 'Acc=FF6FD38C AccH=E66FD38C AccP=CC6FD38C AccSoft=1F6FD38C AccText=FF9FF5B5 Info=FF9FF5B5 AccT=FF000000'
    }
    It 'maps the palette for light: Acc = Dark1, AccText = Info = Dark2, AccT white, AccSoft 8 %' {
        $c = Get-AkariAccentColors $pal 'Light'
        (@('Acc', 'AccSoft', 'AccText', 'AccT') | ForEach-Object { "$_=$(& $fmt $c[$_])" }) -join ' ' | Should Be 'Acc=FF0B6A2E AccSoft=140B6A2E AccText=FF074C20 AccT=FFFFFFFF'
    }
    It 'gives nothing for an unreadable palette (crimson stays)' {
        Get-AkariAccentColors $null 'Dark' | Should BeNullOrEmpty
        Get-AkariAccentColors ([byte[]]@(1, 2, 3)) 'Dark' | Should BeNullOrEmpty
    }
}

Describe 'Motion (UI\Motion.ps1, UI\Motion.xaml)' {
    . "$Root\UI\Motion.ps1"
    $motion = Get-Content "$Root\UI\Motion.xaml" -Raw
    $xamlFiles = @(Get-ChildItem "$Root\UI\*.xaml" | Where-Object { $_.Name -notin 'Icons.xaml', 'Motion.xaml' })

    It 'has Fluent''s durations and curves, every Duration and KeyTime 0:0:0 with motion off, no Spring' {
        $on = Get-AkariMotionEntries $motion $true
        foreach ($t in @(@('Fast', '0.083'), @('Base', '0.167'), @('Slow', '0.25'), @('Page', '0.333'))) {
            $on | Should Match ('x:Key="Motion.{0}">0:0:{1}<' -f $t[0], $t[1])
            $on | Should Match ('x:Key="Motion.{0}.T">0:0:{1}<' -f $t[0], $t[1])
        }
        $on | Should Match 'x:Key="Motion.Stagger">0:0:0.03<'
        $on | Should Match 'x:Key="Motion.Ease">0,0 0,1<'
        $on | Should Match 'x:Key="Motion.Exit">0.55,0.55 0,1<'
        $on | Should Not Match 'Spring|<ResourceDictionary'
        $off = Get-AkariMotionEntries $motion $false
        [regex]::Matches($off, '<(Duration|KeyTime)\b[^>]*>0:0:0</').Count | Should Be ([regex]::Matches($on, '<(Duration|KeyTime)\b').Count)
    }
    It 'puts the entries first in a root ResourceDictionary or the first X.Resources, else leaves the XAML alone' {
        Add-AkariMotionXaml '<ResourceDictionary a="1"><S/></ResourceDictionary>' '<M/>' | Should Be '<ResourceDictionary a="1"><M/><S/></ResourceDictionary>'
        Add-AkariMotionXaml '<Window><Window.Resources><S/></Window.Resources></Window>' '<M/>' | Should Be '<Window><Window.Resources><M/><S/></Window.Resources></Window>'
        Add-AkariMotionXaml '<Border/>' '<M/>' | Should Be '<Border/>'
    }
    It 'plans each kind: Fade, Rise, Pop, Scale, Slide, Fill' {
        ((Get-AkariMotionPlan Fade) | ForEach-Object { "$($_.Property) $($_.From)>$($_.To)" }) -join ', ' | Should Be 'Opacity 0>1'
        ((Get-AkariMotionPlan Rise 28) | ForEach-Object { "$($_.Property) $($_.From)>$($_.To)" }) -join ', ' | Should Be 'Opacity 0>1, Y 28>0'
        ((Get-AkariMotionPlan Pop 0.8) | ForEach-Object { "$($_.Property) $($_.From)>$($_.To)" }) -join ', ' | Should Be 'Opacity 0>1, ScaleX 0.8>1, ScaleY 0.8>1'
        ((Get-AkariMotionPlan Slide 40 0) | ForEach-Object { "$($_.Property) $($_.From)>$($_.To)" }) -join ', ' | Should Be 'X 40>0'
        ((Get-AkariMotionPlan Fill $null 0.5) | ForEach-Object { "$($_.Property) $($_.From)>$($_.To)" }) -join ', ' | Should Be 'ScaleX >0.5'
        { Get-AkariMotionPlan Wobble } | Should Throw
    }
    It 'Motion off: Windows'' animation effects, or AKARI_MOTION' {
        $old = $env:AKARI_MOTION
        try { $env:AKARI_MOTION = 'off'; Test-AkariMotionOn | Should Be $false; $env:AKARI_MOTION = 'on'; Test-AkariMotionOn | Should Be $true }
        finally { $env:AKARI_MOTION = $old }
    }
    It 'staggers a page''s children 30 ms apart, the sixth on with the fifth (the prototype''s .enter)' {
        (0..7 | ForEach-Object { Get-AkariEntranceDelay $_ }) -join ',' | Should Be '0,30,60,90,120,150,150,150'
    }
    It 'eases on cubic-bezier(0,0,0,1): fast first, exact at both ends' {
        Get-AkariEaseValue 0 | Should Be 0
        Get-AkariEaseValue 1 | Should Be 1
        [Math]::Round((Get-AkariEaseValue 0.125), 3) | Should Be 0.5
    }
    It 'stretches the nav indicator over both items, then onto the new one (down and up)' {
        $down = @(Get-AkariPillPath 0 100)
        "$($down[0].Y) $($down[0].Scale) $($down[-1].Y) $($down[-1].Scale)" | Should Be '0 1 100 1'
        $max = 0; foreach ($k in $down) { if ($k.Scale -gt $max) { $max = $k.Scale } }
        $max | Should BeGreaterThan 6.5
        @($down | Where-Object { $_.Scale -gt 6.5 })[0].Y | Should Be 0
        $up = @(Get-AkariPillPath 100 0)
        "$($up[0].Y) $($up[-1].Y)" | Should Be '100 0'
        # going up, the bottom stays on the old item while it grows: top + height = 116 at the peak
        $peak = $up[0]; foreach ($k in $up) { if ($k.Scale -gt $peak.Scale) { $peak = $k } }
        [Math]::Round($peak.Y + 16 * $peak.Scale) | Should Be 116
    }

    # a template animates with spline key frames on the tokens; only a busy loop (Forever) keeps its own time
    It 'template animations take their KeyTime and KeySpline from the Motion tokens' {
        $bad = foreach ($f in $xamlFiles) {
            $x = [xml](Get-Content $f.FullName -Raw)
            foreach ($a in $x.SelectNodes("//*[local-name()='SplineDoubleKeyFrame']")) {
                $loop = $false; $p = $a.ParentNode
                while ($p -and $p.NodeType -eq 'Element') { if ($p.LocalName -eq 'Storyboard' -and $p.GetAttribute('RepeatBehavior') -eq 'Forever') { $loop = $true }; $p = $p.ParentNode }
                if ($loop) { continue }
                if ($a.KeyTime -notlike '{StaticResource Motion.*.T}' -or $a.KeySpline -notin '{StaticResource Motion.Ease}', '{StaticResource Motion.Exit}') { "$($f.Name): $($a.KeyTime) $($a.KeySpline)" }
            }
            foreach ($a in $x.SelectNodes("//*[contains(local-name(), 'Animation') and @Duration]")) {
                if ($a.Duration -like '{StaticResource Motion.*}') { continue }
                $loop = $false; $p = $a.ParentNode
                while ($p -and $p.NodeType -eq 'Element') { if ($p.LocalName -eq 'Storyboard' -and $p.GetAttribute('RepeatBehavior') -eq 'Forever') { $loop = $true }; $p = $p.ParentNode }
                if (-not $loop) { "$($f.Name): $($a.LocalName) $($a.Duration)" }
            }
            if ((Get-Content $f.FullName -Raw) -match 'EasingFunction=') { "$($f.Name): an EasingFunction" }
        }
        @($bad) -join '; ' | Should Be ''
    }
    It 'never animates a colour (the brushes are shared DynamicResources): Opacity and transforms only' {
        @($xamlFiles | Where-Object { (Get-Content $_.FullName -Raw) -match '<ColorAnimation' } | ForEach-Object Name) -join ', ' | Should Be ''
    }
    It 'every trigger that animates in animates back out' {
        $bad = foreach ($f in $xamlFiles) {
            $x = [xml](Get-Content $f.FullName -Raw)
            foreach ($t in $x.SelectNodes("//*[substring(local-name(), string-length(local-name()) - 12) = '.EnterActions']")) {
                $exit = $t.LocalName -replace 'EnterActions$', 'ExitActions'
                if (-not @($t.ParentNode.ChildNodes | Where-Object { $_.LocalName -eq $exit }).Count) { "$($f.Name): $($t.ParentNode.LocalName)" }
            }
        }
        @($bad) -join '; ' | Should Be ''
    }
    It 'every UI XAML file is read through Get-AkariXaml, every animation started in Motion.ps1' {
        $ps = @(Get-ChildItem "$Root\UI\*.ps1" | Where-Object Name -ne 'Motion.ps1')
        @($ps | Where-Object { (Get-Content $_.FullName -Raw) -match 'XamlReader\]::Parse\(\(Get-Content' } | ForEach-Object Name) -join ', ' | Should Be ''
        @($ps | Where-Object { (Get-Content $_.FullName -Raw) -match '\.BeginAnimation\(' } | ForEach-Object Name) -join ', ' | Should Be ''
    }
    # ADR 0008: only the pane's width, an expander's body and an InfoBar animate a size, through Set-AkariSize
    It 'animates a size only through Set-AkariSize (the pane, expanders, InfoBars)' {
        $hits = foreach ($f in Get-ChildItem "$Root\UI\*.ps1" | Where-Object Name -ne 'Motion.ps1') {
            Select-String -Path $f.FullName -Pattern 'Start-AkariMotion\s+\S+\s+(Width|Height)\b' | ForEach-Object { "$($_.Filename):$($_.LineNumber)" }
        }
        @($hits) -join ', ' | Should Be ''
        $calls = foreach ($f in Get-ChildItem "$Root\UI\*.ps1") { Select-String -Path $f.FullName -Pattern 'Set-AkariSize \$(\S+) (Width|Height)' | ForEach-Object { "$($_.Matches[0].Groups[1].Value) $($_.Matches[0].Groups[2].Value)" } }
        (@($calls | Sort-Object -Unique) -join ',') | Should Be 'Bar Height,c.Head.Tag Height,Nav Width,s.Tag Height,script:NavKids Height'
    }

    It 'parses every UI XAML file with motion on and off; Start-AkariMotion animates, or sets the end values' {
        $probe = "$TestDrive\motion.ps1"
        Set-Content $probe -Value @'
param($Root)
Add-Type -AssemblyName PresentationFramework
$r = @()
foreach ($m in 'on', 'off') {
    $env:AKARI_MOTION = $m; . "$Root\UI\Motion.ps1"
    foreach ($f in Get-ChildItem "$Root\UI\*.xaml" | Where-Object Name -ne 'Motion.xaml') { try { [void](Get-AkariXaml $f.FullName) } catch { $r += "$m $($f.Name): $($_.Exception.Message)" } }
    $r += "$m fast=$($AkariMotion['Motion.Fast'].TimeSpan.TotalMilliseconds) page=$($AkariMotion['Motion.Page'].TimeSpan.TotalMilliseconds)"
    $b = [Windows.Controls.Border]::new(); Start-AkariMotion $b Rise 28 -Delay ([TimeSpan]::FromMilliseconds(30))
    $g1 = $b.RenderTransform; Start-AkariMotion $b Slide $null 40
    $r += "$m rise op=$($b.Opacity) y=$($b.RenderTransform.Children[-1].Y) x=$($b.RenderTransform.Children[-1].X) anim=$($b.HasAnimatedProperties) same=$([object]::ReferenceEquals($g1, $b.RenderTransform))"
    $s = [Windows.Controls.StackPanel]::new(); [void]$s.Children.Add([Windows.Controls.Border]@{ Height = 30 })
    Set-AkariSize $s Height 0; $h0 = $s.Height; Set-AkariSize $s Height 'Auto'
    $r += "$m size $h0 $([double]::IsNaN($s.Height))"
}
$r -join '|'
'@
        $out = @(& powershell -NoProfile -STA -ExecutionPolicy Bypass -File $probe -Root $Root 2>&1 | ForEach-Object { "$_" }) -join "`n"
        $out | Should Be 'on fast=83 page=333|on rise op=1 y=0 x=40 anim=True same=True|on size 0 True|off fast=0 page=0|off rise op=1 y=0 x=40 anim=False same=True|off size 0 True'
    }

    # the controls' storyboards run (no window: the dispatcher is pumped) and end on each state's values
    It 'Controls.xaml animates every state to its end, with motion on and off' {
        $probe = "$TestDrive\controls.ps1"
        Set-Content $probe -Value @'
param($Root, $Motion)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName PresentationFramework
$env:AKARI_MOTION = $Motion; . "$Root\UI\Motion.ps1"
$h = [Windows.Controls.StackPanel]::new()
foreach ($f in 'Theme.Dark', 'Controls', 'Icons') { $h.Resources.MergedDictionaries.Add((Get-AkariXaml "$Root\UI\$f.xaml")) }
function Wait-Ms($ms) { $fr = [Windows.Threading.DispatcherFrame]::new(); $t = [Windows.Threading.DispatcherTimer]::new(); $t.Interval = [TimeSpan]::FromMilliseconds($ms)
    $t.add_Tick({ $t.Stop(); $fr.Continue = $false }.GetNewClosure()); $t.Start(); [Windows.Threading.Dispatcher]::PushFrame($fr) }
function Add-Control($c, $style) { $c.Style = $h.Resources[$style]; [void]$h.Children.Add($c); $c }
function Part($c, $n) { $c.Template.FindName($n, $c) }
$sw = Add-Control ([Windows.Controls.Primitives.ToggleButton]::new()) 'Switch'; $sw.IsThreeState = $true
$cs = Add-Control ([Windows.Controls.Primitives.ToggleButton]::new()) 'CatSwitch'; $cs.IsChecked = $true
$ck = Add-Control ([Windows.Controls.CheckBox]::new()) 'Check'
$rd = Add-Control ([Windows.Controls.RadioButton]::new()) 'Radio'
$cb = Add-Control ([Windows.Controls.ComboBox]::new()) 'Combo'; foreach ($i in 'a', 'b') { [void]$cb.Items.Add([Windows.Controls.ComboBoxItem]@{ Content = $i; Uid = "note $i" }) }; $cb.SelectedIndex = 0
$ex = Add-Control ([Windows.Controls.Primitives.ToggleButton]@{ Content = 'Head' }) 'ExpHead'
$ac = Add-Control ([Windows.Controls.Button]::new()) 'Accent'; $ac.Content = 'Go'
$h.Measure([Windows.Size]::new(800, 2000)); $h.Arrange([Windows.Rect]::new(0, 0, 800, 2000)); $h.UpdateLayout()
Wait-Ms 50
$sw.IsChecked = $true; $ck.IsChecked = $true; $rd.IsChecked = $true; $ex.IsChecked = $true
Wait-Ms 450
$th = (Part $sw 'Thumb').RenderTransform.Children
$r = @("on $($th[2].X) $((Part $sw 'On').Opacity) $((Part $sw 'ThumbOn').Opacity) $((Part $sw 'L').Text)")
$sw.IsChecked = $null; Wait-Ms 450
$r += "null $($th[2].X) $((Part $sw 'On').Opacity) $((Part $sw 'L').Text)"
$r += "cat $((Part $cs 'Thumb').RenderTransform.Children[2].X)"
$r += "check $((Part $ck 'On').Opacity) $((Part $ck 'Tick').StrokeDashOffset)"
$r += "radio $((Part $rd 'Dot').RenderTransform.Children[0].ScaleX)"
$r += "exp $((Part $ex 'Chev').RenderTransform.Angle)"
$r += "acc $($ac.ActualHeight) $($ac.MinWidth)"
$r -join '|'
'@
        $want = 'on 20 1 1 On|null 10 0 Unchanged|cat 20|check 1 0|radio 1|exp 180|acc 32 120'
        foreach ($m in 'on', 'off') {
            $out = @(& powershell -NoProfile -STA -ExecutionPolicy Bypass -File $probe -Root $Root -Motion $m 2>&1 | ForEach-Object { "$_" }) -join "`n"
            "$m $out" | Should Be "$m $want"
        }
    }

    It 'counts eased out: fast first, exactly the value at the end' {
        Get-AkariCountValue 0 100 0 | Should Be 0
        Get-AkariCountValue 0 100 0.5 | Should Be 88
        Get-AkariCountValue 0 100 1 | Should Be 100
        Get-AkariCountValue 0 100 3 | Should Be 100
        Get-AkariCountValue 50 10 1 | Should Be 10
    }

    It 'entrances, staggers, page entrances, shown / hidden bars and counts play once built, and end visible and exact' {
        $probe = "$TestDrive\entrance.ps1"
        Set-Content $probe -Value @'
param($Root, $Motion)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName PresentationFramework
$env:AKARI_MOTION = $Motion; . "$Root\UI\Motion.ps1"
function Wait-Ms($ms) { $fr = [Windows.Threading.DispatcherFrame]::new(); $t = [Windows.Threading.DispatcherTimer]::new(); $t.Interval = [TimeSpan]::FromMilliseconds($ms)
    $t.add_Tick({ $t.Stop(); $fr.Continue = $false }.GetNewClosure()); $t.Start(); [Windows.Threading.Dispatcher]::PushFrame($fr) }
$page = [Windows.Controls.StackPanel]::new()
$cards = foreach ($i in 1..14) { $b = [Windows.Controls.Border]@{ Height = 10 }; [void]$page.Children.Add($b); $b }
Start-AkariPageEntrance $page.Children
$waiting = @($cards | Where-Object { $_.Opacity -eq 0 }).Count
$bar = [Windows.Controls.Border]@{ Visibility = 'Collapsed' }
Show-AkariElement $bar
$shown = $bar.Visibility
$tx = [Windows.Controls.TextBlock]@{ Text = '-' }
Start-AkariCount $tx 1234
Wait-Ms 900
$r = @("page $waiting>$(@($cards | Where-Object { $_.Opacity -ne 1 }).Count)", "bar $shown")
Hide-AkariElement $bar
$r += "hiding $($bar.IsHitTestVisible)"
Wait-Ms 400
$r += "hidden $($bar.Visibility) $($bar.Opacity) $($bar.IsHitTestVisible)"
$r += "count $($tx.Text)"
$r -join '|'
'@
        $out = @(& powershell -NoProfile -STA -ExecutionPolicy Bypass -File $probe -Root $Root -Motion on 2>&1 | ForEach-Object { "$_" }) -join "`n"
        $out | Should Be ('page 14>0|bar Visible|hiding False|hidden Collapsed 1 True|count ' + ('{0:N0}' -f 1234))
        $out = @(& powershell -NoProfile -STA -ExecutionPolicy Bypass -File $probe -Root $Root -Motion off 2>&1 | ForEach-Object { "$_" }) -join "`n"
        $out | Should Be ('page 0>0|bar Visible|hiding True|hidden Collapsed 1 True|count ' + ('{0:N0}' -f 1234))
    }

    It 'scrolls by Windows'' wheel lines per notch inside the page, and glides there' {
        Get-AkariScrollTarget 0 -120 1000 | Should Be 48
        Get-AkariScrollTarget 48 -240 1000 5 | Should Be 208
        Get-AkariScrollTarget 20 120 1000 | Should Be 0
        Get-AkariScrollTarget 990 -120 1000 | Should Be 1000
        $half = Get-AkariScrollStep 0 100 50
        ($half -gt 45 -and $half -lt 55) | Should Be $true
        Get-AkariScrollStep 99.8 100 16 | Should Be 100
        Get-AkariScrollStep 10 100 -5 | Should Be 10
    }

    It 'a wheel notch on a smooth ScrollViewer glides to its target; an inner scrollable part keeps the wheel' {
        $probe = "$TestDrive\scroll.ps1"
        Set-Content $probe -Value @'
param($Root, $Motion)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName PresentationFramework
$env:AKARI_MOTION = $Motion; . "$Root\UI\Motion.ps1"
function Wait-Ms($ms) { $fr = [Windows.Threading.DispatcherFrame]::new(); $t = [Windows.Threading.DispatcherTimer]::new(); $t.Interval = [TimeSpan]::FromMilliseconds($ms)
    $t.add_Tick({ $t.Stop(); $fr.Continue = $false }.GetNewClosure()); $t.Start(); [Windows.Threading.Dispatcher]::PushFrame($fr) }
function Send-Wheel($to, $delta) { $a = [Windows.Input.MouseWheelEventArgs]::new([Windows.Input.Mouse]::PrimaryDevice, 0, $delta); $a.RoutedEvent = [Windows.UIElement]::PreviewMouseWheelEvent; $to.RaiseEvent($a); $a.Handled }
$inner = [Windows.Controls.ScrollViewer]@{ Height = 50; Content = [Windows.Controls.Border]@{ Height = 300 } }
$stack = [Windows.Controls.StackPanel]::new(); [void]$stack.Children.Add($inner); [void]$stack.Children.Add([Windows.Controls.Border]@{ Height = 1000 })
$sv = [Windows.Controls.ScrollViewer]@{ Height = 100; Content = $stack }
$sv.Measure([Windows.Size]::new(100, 100)); $sv.Arrange([Windows.Rect]::new(0, 0, 100, 100)); $sv.UpdateLayout()
Enable-AkariSmoothScroll $sv
$h = Send-Wheel $sv -120
$lines = [Math]::Max(1, [Windows.SystemParameters]::WheelScrollLines)
Wait-Ms 700; $sv.UpdateLayout()
$r = @("page $h $([Math]::Round($sv.VerticalOffset) -eq [Math]::Min($sv.ScrollableHeight, $lines * 16))")
$r += "inner $(Send-Wheel $inner -120)"
$r += "touchpad $(Send-Wheel $sv -30)"
Start-AkariScrollTo $sv 200; Wait-Ms 700; $sv.UpdateLayout()
$r += "to $([Math]::Round($sv.VerticalOffset))"
Reset-AkariScroll $sv; $sv.UpdateLayout()
$r += "top $($sv.VerticalOffset)"
$r -join '|'
'@
        $out = @(& powershell -NoProfile -STA -ExecutionPolicy Bypass -File $probe -Root $Root -Motion on 2>&1 | ForEach-Object { "$_" }) -join "`n"
        $out | Should Be 'page True True|inner False|touchpad False|to 200|top 0'
    }

    It 'a debug run ($env:AKARI_UI_TIMING) logs page builds, the launch and UI-thread stalls; a normal run logs nothing' {
        $probe = "$TestDrive\timing.ps1"
        Set-Content $probe -Value @'
param($Root, $Log, $Timing)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName PresentationFramework
$AkariLogFile = $Log; . "$Root\Core\Log.ps1"
$env:AKARI_UI_TIMING = $Timing; . "$Root\UI\Motion.ps1"
function Wait-Ms($ms) { $fr = [Windows.Threading.DispatcherFrame]::new(); $t = [Windows.Threading.DispatcherTimer]::new(); $t.Interval = [TimeSpan]::FromMilliseconds($ms)
    $t.add_Tick({ $t.Stop(); $fr.Continue = $false }.GetNewClosure()); $t.Start(); [Windows.Threading.Dispatcher]::PushFrame($fr) }
$tm = Start-AkariUiTimer 'page Test'; Stop-AkariUiTimer $tm
Start-AkariStallWatch { 'Test page' }
Wait-Ms 120
Start-Sleep -Milliseconds 450
Wait-Ms 120
'@
        foreach ($m in '1', '') {
            $log = "$TestDrive\akari-$m.log"
            & powershell -NoProfile -STA -ExecutionPolicy Bypass -File $probe -Root $Root -Log $log -Timing $m 2>&1 | Out-Null
            $text = if (Test-Path $log) { Get-Content $log -Raw } else { '' }
            if ($m) {
                $text | Should Match 'UI timing: page Test \d+ ms'
                $text | Should Match 'UI timing: window loaded'
                $text | Should Match 'UI timing: stalled [\d.,]+ ms on Test page'
            } else { $text | Should BeNullOrEmpty }
        }
    }

    It 'MainWindow.xaml''s styles: 32 px buttons, the accent one at least 120, a text box underline that turns Acc on focus' {
        $probe = "$TestDrive\shellstyles.ps1"
        Set-Content $probe -Value @'
param($Root)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName PresentationFramework
$env:AKARI_MOTION = 'off'; . "$Root\UI\Motion.ps1"
$w = Get-AkariXaml "$Root\UI\MainWindow.xaml"
foreach ($f in 'Theme.Dark', 'Controls', 'Icons') { $w.Resources.MergedDictionaries.Add((Get-AkariXaml "$Root\UI\$f.xaml")) }
$h = [Windows.Controls.StackPanel]::new(); $h.Resources.MergedDictionaries.Add($w.Resources)
function Add-Control($c, $style) { if ($style) { $c.Style = $h.Resources[$style] }; [void]$h.Children.Add($c); $c }
$b = Add-Control ([Windows.Controls.Button]@{ Content = 'B' }) 'Btn'
$p = Add-Control ([Windows.Controls.Button]@{ Content = 'P' }) 'BtnP'
$tb = Add-Control ([Windows.Controls.TextBox]::new()) 'Flat'
$h.Measure([Windows.Size]::new(800, 2000)); $h.Arrange([Windows.Rect]::new(0, 0, 800, 2000)); $h.UpdateLayout()
"btn=$($b.ActualHeight)|$($p.ActualHeight)|$($p.ActualWidth -ge 120)|$($tb.ActualHeight)|$($null -ne $tb.Template.FindName('UnderOn', $tb))|$($tb.Template.FindName('Under', $tb).Height)"
'@
        $o = Invoke-Probe $probe @{ Root = $Root }
        $o.error | Should BeNullOrEmpty
        $o.btn | Should Be '32|32|True|32|True|1'
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
    # builds Guided's rows in a child STA PowerShell (no window), applies their templates, prints key=value lines
    $probe = "$TestDrive\probe.ps1"
    Set-Content $probe -Value @'
param($Root)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName PresentationFramework
foreach ($f in 'Registry', 'Loader') { . "$Root\Core\$f.ps1" }
. "$Root\UI\Motion.ps1"
. "$Root\UI\Selection.ps1"
. "$Root\UI\Cards.ps1"
$host_ = [Windows.Controls.StackPanel]::new()
$host_.Resources.MergedDictionaries.Add((Get-AkariXaml "$Root\UI\Controls.xaml"))
$host_.Resources.MergedDictionaries.Add((Get-AkariXaml "$Root\UI\Icons.xaml"))
function Show($e) { [void]$host_.Children.Add($e.Row); $host_.Measure([Windows.Size]::new(600, 2000)); [void]$e.Control.ApplyTemplate() }
$tog = ConvertTo-AkariTweak @{ Id = 'tog'; Name = 'Tog'; Description = 'D'; Risk = 'Safe'; Reboot = $true } 'x' $false
$adv = ConvertTo-AkariTweak @{ Id = 'adv'; Name = 'Adv'; Description = 'D'; Risk = 'Advanced'; SafeMode = $true } 'x' $false
$act = ConvertTo-AkariTweak @{ Id = 'act'; Name = 'Act'; Description = 'D'; Kind = 'Action'; Risk = 'Safe' } 'x' $false
$ch = ConvertTo-AkariTweak @{ Id = 'ch'; Name = 'Ch'; Description = 'D'; Kind = 'Choice'; Risk = 'Safe'; Recommended = 0x26; Default = 2; Editable = $true
    Choices = @(@{ Value = 0x26; Label = 'A' }, @{ Value = 0x28; Label = 'B' }, @{ Value = 2; Label = 'C' }) } 'x' $false
$e = New-AkariTweakRow $tog 'Default'; Show $e
"togType=$($e.Control.GetType().Name)"; "togGlyphs=$($e.Glyphs.Children.Count)"; "togTip=$($e.Row.ToolTip -replace "`n", '|')"
"togRow=$($e.Row.Style -eq $host_.FindResource('CardRow'))|$($e.Row.Padding.Left)"
"togStartState=$(Get-AkariRowStart $e $true)"
$e = New-AkariTweakRow $tog 'Optimized'; Show $e
"optStartState=$(Get-AkariRowStart $e $true)"; "optStartPlain=$(Get-AkariRowStart $e $false)"
Set-AkariRowControl $e 'Optimized'; "setOn=$($e.Control.IsChecked)"
$e = New-AkariTweakRow $tog 'Unknown'; Show $e
"unkGlyph=$($e.Glyphs.Children[1].ToolTip)"
$e = New-AkariTweakRow $adv 'Default'; Show $e
"advMarks=$(($e.Glyphs.Children | ForEach-Object { $_.ToolTip }) -join ';')"
"advBadge=$((New-AkariBadges $adv).Children[0].Tag)"
$e = New-AkariTweakRow $ch 'Custom' 0x28; Show $e
"chItems=$($e.Control.Items.Count)"; "chNone=$($e.Control.Items[0].Content)"; "chRec=$($e.Control.Items[1].Content)|$($e.Control.Items[1].Uid)"; "chDef=$($e.Control.Items[3].Content)|$($e.Control.Items[3].Uid)"
"chStart=$(Get-AkariRowStart $e $true)"; "chStartPlain=$(Get-AkariRowStart $e $false)"
Set-AkariRowControl $e 0x28; "chValue=$(Get-AkariComboValue $e)"
Set-AkariRowControl $e 'None'; "chNoChange=$(Get-AkariComboValue $e)"
$e = New-AkariTweakRow $ch 'Custom' 7; Show $e
"chUnlisted=$(Get-AkariRowStart $e $true)"
Set-AkariRowControl $e 7; "chTyped=$($e.Control.Text)"
# a short Choice: a ComboBox too (Segmented is retired)
$seg = ConvertTo-AkariTweak @{ Id = 'seg'; Name = 'Seg'; Description = 'D'; Kind = 'Choice'; Risk = 'Safe'; Recommended = 1; Default = 0
    Registry = @{ Path = 'HKCU:\x'; Name = 'S'; Type = 'DWord' }; Choices = @(@{ Value = 0; Label = 'Off' }, @{ Value = 1; Label = 'On' }, @{ Value = 2; Label = 'Max' }) } 'x' $false
$e = New-AkariTweakRow $seg 'Default' 0; Show $e
Set-AkariRowControl $e 2; $v2 = Get-AkariComboValue $e
"seg=$($e.Control.GetType().Name)|$($e.Control.Items.Count)|$v2|$($e.Control.Style -eq $host_.FindResource('Combo'))"
$e = New-AkariTweakRow $act 'Unknown'; Show $e
"actType=$($e.Control.GetType().Name)"; "actGlyphs=$($e.Glyphs.Children.Count)"
$ak = ConvertTo-AkariTweak @{ Id = 'ak'; Name = 'Ak'; Description = 'D'; Risk = 'Safe'; AkariOS = $true } 'x' $false
$e = New-AkariTweakRow $ak 'Default'; Show $e
"akBadge=$((New-AkariBadges $ak).Children[0].Tag)"
$x = New-AkariExpander 'app-window' 'Windows' '3 Tweaks'
"exp=$($x.Head.GetType().Name)|$($x.Head.IsChecked)|$($x.Body.Height)|$($x.Desc.Text)|$($null -ne $x.Count)"
$y = New-AkariExpander 'app-window' 'Open' '' $true
"expOpen=$($y.Head.IsChecked)|$([double]::IsNaN($y.Body.Height))"
$b = New-AkariBadge 'Caution'; "badge=$($b.Tag)|$($b.CornerRadius.TopLeft)|$($b.Height)"
$i = New-AkariInfoBar 'Warn' 'T' 'Text' -Close; "info=$($i.Bar.Tag)|$($i.Title.Text)|$($i.Text.Text)|$($null -ne $i.Close)|$($i.Bar.CornerRadius.TopLeft)"
$s = New-AkariSelectorBar @('A', 'B') 'B' { }; "sel=$($s.Items.Children.Count)|$(@($s.Items.Children | Where-Object { $_.IsChecked })[0].Tag)|$($s.Line.Width)x$($s.Line.Height)"
'@
    $out = Invoke-Probe $probe @{ Root = $Root }

    It 'builds without errors' { $out['error'] | Should BeNullOrEmpty }
    It 'shows a Toggle as a check box in an expander row (52 px in), with a restart mark and a tooltip' {
        $out.togType | Should Be 'CheckBox'
        $out.togGlyphs | Should Be '1'
        $out.togTip | Should Be 'D|Restart required.|Now: Default.'
        $out.togRow | Should Be 'True|52'
    }
    It 'starts checked only when the State is Optimized and Show current state is on' {
        $out.togStartState | Should Be 'None'
        $out.optStartState | Should Be 'Optimized'
        $out.optStartPlain | Should Be 'None'
        $out.setOn | Should Be 'True'
    }
    It 'marks an unread State, Safe Mode, and the Risk as a badge' {
        $out.unkGlyph | Should Be 'State unknown'
        $out.advMarks | Should Be 'Runs in Safe Mode: Akari restarts into it and back'
        $out.advBadge | Should Be 'Advanced'
    }
    It 'lists Choices after No change, with Recommended and Windows default noted beside them' {
        $out.chItems | Should Be '4'
        $out.chNone | Should Be 'No change'
        $out.chRec | Should Be 'A|Recommended'
        $out.chDef | Should Be 'C|Windows default'
        $out.chStart | Should Be '40'
        $out.chStartPlain | Should Be 'None'
        $out.chValue | Should Be '40'
        $out.chNoChange | Should Be 'None'
    }
    It 'starts an unlisted value on No change, and can show it as typed text' {
        $out.chUnlisted | Should Be 'None'
        $out.chTyped | Should Be '7'
    }
    It 'shows every Choice as a ComboBox' { $out.seg | Should Be 'ComboBox|4|2|True' }
    It 'shows an Action as a check box with no state mark' {
        $out.actType | Should Be 'CheckBox'
        $out.actGlyphs | Should Be '0'
    }
    It 'badges a Tweak of the AkariOS setup' { $out.akBadge | Should Be 'AkariOS' }
    It 'builds an expander: a ToggleButton head, a closed body of height 0, its count' {
        $out.exp | Should Be 'ToggleButton|False|0|3 Tweaks|True'
        $out.expOpen | Should Be 'True|True'
    }
    It 'builds a badge, an InfoBar and a SelectorBar to the prototype''s metrics' {
        $out.badge | Should Be 'Caution|4|20'
        $out.info | Should Be 'Warn|T|Text|True|4'
        $out.sel | Should Be '2|B|16x3'
    }
}

Describe 'Dialog (UI\Dialog.ps1, a ContentDialog)' {
    . "$Root\UI\Dialog.ps1"
    It 'turns "- " lines into a list of consequences' {
        ((Get-AkariDialogBlocks "Intro`n- one`n`n- two`nEnd") | ForEach-Object { "$($_.Kind):$($_.Text)" }) -join '|' | Should Be 'Text:Intro|Item:one|Item:two|Text:End'
    }
    It 'shows the main action first and the cancel one last' {
        (Get-AkariDialogOrder @('Cancel', 'Later', 'Restart and apply')) -join ',' | Should Be 'Restart and apply,Later,Cancel'
        (Get-AkariDialogOrder @('Cancel', 'Apply')) -join ',' | Should Be 'Apply,Cancel'
        (Get-AkariDialogOrder @('OK')) -join ',' | Should Be 'OK'
    }
}

Describe 'Pages (UI\Pages.ps1)' {
    $AkariLogFile = "$TestDrive\akari.log"
    . "$Root\UI\Pages.ps1"
    It 'says when an activity happened in words' {
        $now = [datetime]'2026-11-19 15:00'
        Get-AkariWhenText $now.AddSeconds(-20) $now | Should Be 'Just now'
        Get-AkariWhenText $now.AddMinutes(-12) $now | Should Be '12 minutes ago'
        Get-AkariWhenText ([datetime]'2026-11-19 09:05') $now | Should Be 'Today 09:05'
        Get-AkariWhenText ([datetime]'2026-11-18 22:00') $now | Should Be 'Yesterday'
        Get-AkariWhenText ([datetime]'2026-10-02 10:00') $now | Should Be '2 Oct 2026'
    }
}

Describe 'Shell navigation' {
    # builds the shell in a child STA PowerShell with fixture tweaks; the window is never shown (no ShowDialog)
    $probe = "$TestDrive\shell.ps1"
    Set-Content $probe -Value @'
param($Root, $LogFile, $Install)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName PresentationFramework
# navigation, not motion: values land at once (no dispatcher runs here to play animations)
$env:AKARI_MOTION = 'off'
$AkariLogFile = $LogFile
$AkariPresetDir = Join-Path (Split-Path $LogFile) 'presets'
foreach ($f in 'Log', 'Registry', 'Loader', 'State', 'Runner', 'Restore', 'Version', 'Update', 'Unattend', 'Presets', 'Iso', 'IsoDownload') { . "$Root\Core\$f.ps1" }
# the Install USB page reads no drive and no PC setting here
function Get-AkariSetupDrives { }
function Get-AkariUnattendDefaults { @{} }
$AkariInstallDir = $Install
function L($id, $page, $name) { ConvertTo-AkariTweak @{ Id = $id; Name = $name; Description = 'D'; Section = $page; Category = ''; Risk = 'Safe'; Kind = 'Action'; Button = 'Run'; Apply = { } } 'x' $true }
$script:Tweaks = [System.Collections.Generic.List[object]]::new()
foreach ($t in @((L 'dark' 'Windows' 'Dark theme'), (L 'bios' 'Check' 'BIOS check'), (L 'leg-adv' 'Advanced' 'Old advanced'),
    (ConvertTo-AkariTweak @{ Id = 'tuning'; Name = 'Theme tuning'; Description = 'D'; Section = 'Advanced'; Category = 'Tuning'; Risk = 'Safe'; Kind = 'Action'; Button = 'Run'; Apply = { } } 'x' $false),
    (ConvertTo-AkariTweak @{ Id = 'cat-tog'; Name = 'Cat toggle'; Description = 'D'; Section = 'Customize'; Category = 'Taskbar'; Risk = 'Safe'; Explorer = $true; Apply = { }; Revert = { } } 'x' $false),
    (ConvertTo-AkariTweak @{ Id = 'cat-tog2'; Name = 'Cat other'; Description = 'D'; Section = 'Customize'; Category = 'Start'; Risk = 'Safe'; Apply = { }; Revert = { } } 'x' $false),
    (ConvertTo-AkariTweak @{ Id = 'cat-safe'; Name = 'Cat safe'; Description = 'D'; Section = 'Advanced'; Category = 'Security'; Risk = 'Safe'; SafeMode = $true; Reboot = $true; Apply = { }; Revert = { } } 'x' $false))) { $script:Tweaks.Add($t) }
$script:Groups = @(); $script:RowCache = @{}; $script:Cat = 'Home'; $script:Busy = $false; $script:Job = $null
$script:Queue = [System.Collections.Concurrent.ConcurrentQueue[string]]::new()
$loaded = @{ Problems = @() }
function Get-AkariAppxInstalled { @() }; function Start-AkariFeatureRead { }
$AkariReadInline = $true  # the steps read the States and apps at once (no dispatcher runs here)
foreach ($f in 'Motion', 'Dialog', 'Selection', 'Catalogue', 'Cards', 'Apps', 'Steps', 'Pages', 'Shell', 'Rows', 'CataloguePage', 'ServicesPage', 'TasksPage', 'About', 'UnattendForm', 'Unattend', 'IsoBuilder', 'ImportExport') { . "$Root\UI\$f.ps1" }
$timer.Stop()
function Test-AkariSafeMode { $false }
function Get-AkariAppxPackages { @() }
$script:Jobs = @()
function Start-AkariJob($Code, $Queue, $CoreDir, $Shared) { $script:Jobs += , @{ Code = $Code; Shared = $Shared }; @{ Handle = [pscustomobject]@{ IsCompleted = $false }; Shared = $Shared } }
function Show-AkariUpdatePrompt { $script:Prompted = $true }
function Click($b) { $b.RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Primitives.ButtonBase]::ClickEvent)) }
function NavOn { ($script:NavItems.Values | Where-Object { $_.Button.IsChecked }).Page }
function Crumbs { (@($Crumbs.Children | Where-Object { $_ -is [Windows.Controls.Button] } | ForEach-Object { $_.Content }) + $Heading.Text) -join '>' }
"nav=$(@($script:NavItems.Keys) -join ',')"
"navFoot=$($NavFoot.Children[1].Tag)|$($Nav.Width)"
Show-Page; "home=$($HomePanel.Visibility)|$(NavOn)|$($PageHeader.Visibility)|$($BackBtn.IsEnabled)"
"homeStats=$($script:HomeStat.Tweaks.Text)|$(@($script:Jobs | Where-Object { $_.Code -match 'Get-AkariExportItems' }).Count)|$($script:HomeTiles.Children.Count)"
"homeHero=$($script:HeroOneClick.Style -eq $window.FindResource('Accent'))|$($script:HomeTiles.Children[0].BorderBrush -eq $window.FindResource('Acc'))"
Complete-AkariHomeStats @{ Apps = 12; Applied = 34 }; "homeStatsDone=$($script:HomeStat.Apps.Text)|$($script:HomeStat.Applied.Text)"
$script:Jobs = @()
Click $script:HeroChoose; "choose=$script:Cat|$script:Mode|$script:Step|$(NavOn)|$($StepFooter.Visibility)|$(Crumbs)|$($StepLabel.Text -replace '[^ -~]', '.')|$($StepBack.Content)|$($BackBtn.IsEnabled)"
Click $StepNext; "next=$script:Step|$($StepLabel.Text -replace '[^ -~]', '.')"
Step-AkariHistoryBack; "backStep=$script:Cat|$script:Step"
Click $StepBack; "cancel=$script:Cat|$script:Mode|$(Crumbs)|$($StepFooter.Visibility)"
# Optimize: its landing page, its sections opening under it in the nav
Invoke-AkariNav 'Optimize'; "optimize=$script:Cat|$(NavOn)|$($script:KidsOpen)|$(Crumbs)"
Invoke-AkariNav 'Optimize'; "kidsToggle=$($script:KidsOpen)"
Invoke-AkariNav 'Catalogue:Customize'
function CatRows { @($Rows.Children | Where-Object { $_ -is [Windows.Controls.Button] }) }
"section=$script:Cat|$(NavOn)|$(Crumbs)|$((CatRows | ForEach-Object { $_.Tag }) -join ',')|$(($Rows.Children | Where-Object { $_ -is [Windows.Controls.TextBlock] -and $_.FontWeight -eq 'SemiBold' } | ForEach-Object { $_.Text }) -join ',')|$($Crumbs.Visibility)"
"catRow=$((CatRows)[0].Content.Children[2].Children[1].Text)|$((CatRows)[0].Content.Children[1].Children[0].Child.Text)"
Click (CatRows)[0]
"category=$script:Cat|$(NavOn)|$(Crumbs)|$($null -ne $script:CatCards['cat-tog'].Card.Parent)|$($null -eq $script:CatCards['cat-tog2'].Card.Parent -or -not $script:CatCards['cat-tog2'].Card.IsDescendantOf($Rows))"
$tog = $script:CatCards['cat-tog']
"reading=$($tog.StateText.Text -replace '[^ -~]', '.')|$($tog.Control.IsEnabled)|$($null -ne $script:Skeletons.Parent)"
Set-AkariCatalogueStates @{ 'cat-tog' = @{ State = 'Default'; Current = $null } }
"read=$($tog.StateText.Text)|$($tog.Control.IsChecked)|$($tog.Control.IsEnabled)|$($null -eq $script:Skeletons.Parent)|$($script:SectionsRead['Catalogue:Customize/Taskbar'])"
# a change applies right away in the job; a second queues; an Explorer change goes to the restart InfoBar
function Confirm-AkariDialog { $true }
function Add-AkariRestoreFirst($Code, $Button) { $Code }
$tog.Control.IsChecked = $true; Click $tog.Control
"run=$($tog.StateText.Text -replace '[^ -~]', '.')|$($script:Job.Kind)|$($script:Jobs[-1].Shared.Mode)"
[void](Get-AkariCatalogueCard ($script:Tweaks | Where-Object { $_.Id -eq 'tuning' }))
Invoke-AkariCatalogueChange 'tuning' 'Apply' $null; "queued=$($script:CatQueue.Count)"
$j = $script:Job; $j.Shared.Outcome = [pscustomobject]@{ Outcome = 'Applied'; Message = '' }; $j.Shared.State = 'Optimized'; $script:Job = $null
Complete-AkariCatalogueJob $j; Start-AkariCatalogueNext
"done=$($tog.Control.IsChecked)|$($script:RestartBar.Bar.Visibility)|$($script:RestartBar.Explorer.Visibility)|$($script:Job.Shared.Id)"
$j = $script:Job; $j.Shared.Outcome = [pscustomobject]@{ Outcome = 'Applied'; Message = '' }; $script:Job = $null; Complete-AkariCatalogueJob $j
"action=$($script:CatCards['tuning'].Done)|$(@(Get-AkariActivity).Count)"
# a Safe Mode Toggle asks Restart and apply / Later / Cancel; Later waits in the Safe Mode InfoBar
Select-AkariPage 'Catalogue:Advanced/Security'
$safe = $script:CatCards['cat-safe']
Set-AkariCatalogueStates @{ 'cat-safe' = @{ State = 'Default'; Current = $null } }
function Show-AkariDialog { $script:Asked = @($args[2]) -join ','; 'Later' }
function Show-AkariToast { $script:Toasted = $args[0] }
$n = $script:Jobs.Count
$safe.Control.IsChecked = $true; Click $safe.Control
"safe=$script:Asked|$($script:SafePending['cat-safe'].Mode)|$($safe.StateText.Text)|$($script:SafeBar.Bar.Visibility)|$($script:SafeBar.Title.Text)|$($script:Jobs.Count - $n)|$script:Toasted"
$safe.Control.IsChecked = $false; Click $safe.Control
"safeBack=$($script:SafePending.Count)|$($safe.Control.IsChecked)"
# search: suggestions as you type, Enter = the results page grouped by Section > Category
"suggest=$((Get-AkariSuggestions 'cat' | ForEach-Object { $_.Id }) -join ',')|$(@(Get-AkariSuggestions 'zzz').Count)"
Open-AkariSearch 'Cat'
"search=$script:Cat|$(NavOn)|$($Heading.Text)|$(($Rows.Children | Where-Object { $_ -is [Windows.Controls.TextBlock] -and $_.FontWeight -eq 'SemiBold' } | ForEach-Object { $_.Text -replace '[^ -~]', '>' }) -join ',')"
"highlight=$((@($script:CatCards['cat-tog'].Name.Inlines) | Where-Object { $_.FontWeight -eq 'SemiBold' } | ForEach-Object { $_.Text }) -join ',')"
Open-AkariSearch 'zzz'; "searchNone=$($Rows.Children[0].Tag.Text)"
# the Legacy pages, from the Optimize page: legacy rows only, Optimize selected
Select-AkariPage 'Check'; "legacy=$script:Cat|$(NavOn)|$(Crumbs)|$($Rows.Children.Count)"
# Back walks the history
$h = $script:History.Count; Step-AkariHistoryBack; "back=$script:Cat|$($script:History.Count -eq $h - 1)"
# the other pages
Select-AkariPage 'Downloads'; "downloads=$script:Cat|$(NavOn)|$(Crumbs)"
Open-AkariSuggestion 'cat-tog2'; "suggestOpen=$script:Cat|$(Crumbs)|$script:FlashId"
Select-AkariPage 'Remove apps'; "remove=$script:Cat|$(NavOn)|$script:DlSection|$($script:Win.Go.IsEnabled)|$(@($script:Win.Grids.Keys) -join ',')|$(($script:DlSections.Items.Children | ForEach-Object { $_.Tag }) -join ',')"
# closing: one question naming what runs and waits (the job, installs waiting, Optimize's queue)
$hold = @{ Job = $script:Job; Q = @($script:InstallQueue); C = @($script:CatQueue) }
$script:Job = @{ Kind = 'Install'; Label = 'Installing Steam' }; $script:Installing = 'steam'
$script:InstallQueue.Clear(); foreach ($x in 'steam', 'discord', 'brave') { $script:InstallQueue.Add($x) }
$script:CatQueue.Clear(); $script:CatQueue.Add(@{ Id = 'x' })
"closing=$((Get-AkariRunningLines) -join '|')"
"closingText=$((Get-AkariClosingText @('Installing Steam', '2 apps waiting to install')) -replace "`n", '/')"
$script:Job = $hold.Job; $script:Installing = $null; $script:InstallQueue.Clear(); $script:CatQueue.Clear()
"closingNone=$(@(Get-AkariRunningLines).Count)"
Select-AkariPage 'Install USB'; "usb=$script:Cat|$(NavOn)|$($script:UaSections.Count -eq $script:UnattendSpec.Sections.Count)|$($script:UaSections[0].Desc.Text)|$($script:UnattendParts.Usb.IsEnabled)|$($script:UnattendParts.DriveName.Text)"
Select-AkariPage 'Unattend Generator'; "usbOld=$script:Cat"
# the Catalogue's job above never ends here: free the job slot first
$script:Job = $null; Set-Busy $false
# the ISO Builder's wizard: Start (the modes), Windows image, Components, Build settings, Review, Create ISO
function Foot { "$($StepNext.Content)|$($StepNext.IsEnabled)|$($StepBack.IsEnabled)" }
Select-AkariPage 'ISO Builder'; "iso=$script:Cat|$(NavOn)|$($script:IsoState.Step)|$(Crumbs)|$($StepFooter.Visibility)|$(Foot)|$($script:IsoParts.ModeTiles.Count)|$((@($script:IsoParts.ModeTiles | Where-Object { $_.IsEnabled }) | ForEach-Object { $_.Tag } | Select-Object -Unique) -join ',')"
Click $StepNext; "isoImage=$($script:IsoState.Step)|$(Crumbs)|$(Foot)|$($StepLabel.Text -replace '[^ -~]', '.')|$($script:IsoParts.SummaryText.Text)"
Click $StepBack; Select-AkariIsoMode 'AkariOS'; "isoModeSoon=$($script:IsoState.Step)|$($script:IsoState.Mode)"
Select-AkariIsoMode 'Custom'; "isoMode=$($script:IsoState.Step)|$($script:IsoState.Mode)"
Complete-AkariIsoJob @{ Kind = 'IsoOpen'; Shared = @{ Result = @{ Image = 'X:\AkariIso\Media\sources\install.wim'; Editions = @(@{ Index = 1; Name = 'Windows 10 Pro'; Version = '10.0.19045.1'; Supported = $false }, @{ Index = 3; Name = 'Windows 11 Home'; Version = '10.0.26200.1'; Supported = $true }, @{ Index = 6; Name = 'Windows 11 Pro'; Version = '10.0.26200.1'; Supported = $true }) } } }
Show-Page
"isoOpened=$($script:IsoParts.Edition.Items.Count)|$($script:IsoParts.Edition.IsEnabled)|$($script:IsoParts.Edition.SelectedItem.Content)|$(Foot)|$($script:IsoParts.SummaryText.Text -replace '[^ -~]', '.')"
# Components reads the image the first time (Custom): the page's controls and the footer wait, the page isn't locked
$script:Jobs = @(); Click $StepNext; "isoComponents=$($script:IsoState.Step)|$($script:Job.Kind)|$(Foot)|$($script:IsoParts.Current.IsEnabled)|$($Page.IsEnabled)"
$script:Job = $null; Set-Busy $false
Complete-AkariIsoJob @{ Kind = 'IsoRead'; Shared = @{ Apps = @(@{ Name = 'Microsoft.BingNews'; Package = 'Microsoft.BingNews_1_x64__8wekyb3d8bbwe' }); Capabilities = @(@{ Name = 'App.StepsRecorder~~~~0.0.1.0' }); Features = @(); Packages = @() } }
Show-Page; "isoRead=$($script:IsoParts.Current.IsEnabled)|$(Foot)|$($script:IsoParts.Lists.Apps.Tag.Head.Text)"
$script:IsoParts.Lists.Apps.Children[0].IsChecked = $true
Click $StepNext; Click $StepNext; "isoReview=$($script:IsoState.Step)|$(Crumbs)|$(Foot)"
$script:Jobs = @(); Click $StepNext
$c = $script:Jobs[-1].Shared.Choices
"isoBuild=$($script:Job.Kind)|$($c.Index)|$($c.Edition)|$(@($c.Options).Count)|$($c.Apps -join ',')|$($c.AkariDir -eq $Root)|$([Text.Encoding]::ASCII.GetString($c.Unattend) -match '<Name>Admin</Name>')|$($script:IsoState.Step)|$(Foot)"
$n = @($script:IsoState.Stages).Count
Update-AkariIsoStages @{ Done = 2; Total = $n }; "isoStages=$($n -gt 5)|$((@($script:IsoState.Stages)[0..3] | ForEach-Object { $_.State }) -join ',')"
$script:Job = $null; Set-Busy $false
Complete-AkariIsoJob @{ Kind = 'IsoBuild'; Shared = @{ Done = 3; Total = $n; Result = @{ Ok = $true; Path = 'D:\Win11-Akari.iso' } } }
Show-Page; "isoDone=$($script:IsoState.ResultPath)|$(@($script:IsoState.Stages | Where-Object { $_.State -ne 'Done' }).Count)|$(Foot)|$($script:IsoParts.Edition.IsEnabled)"
Click $StepNext; "isoAgain=$($script:IsoState.Step)|$(@($script:IsoState.Stages).Count)|$($script:IsoState.Mode)"
Complete-AkariIsoJob @{ Kind = 'IsoUup'; Shared = @{ Result = @{ Ok = $true; Path = 'D:\Windows11_25H2_Pro_en-us.iso' } } }
"isoUupDone=$($script:IsoParts.IsoPath.Text)|$($script:IsoParts.SrcFile.IsChecked)"
# Settings: theme, accent, animations, files, recovery, about
Select-AkariPage 'Settings'; "settings=$script:Cat|$(NavOn)|$(($StepBody.Children | Where-Object { $_ -is [Windows.Controls.TextBlock] } | ForEach-Object { $_.Text }) -join ',')"
"themeRadios=$(($script:AboutParts.Theme.Children | ForEach-Object { "$($_.Content)$(if ($_.IsChecked) { '*' })" }) -join ',')|$(($script:AboutParts.Accent.Items | ForEach-Object { $_.Content }) -join ',')|$($script:AboutParts.Animations.IsChecked)"
"aboutLinks=$(($script:AboutParts.Links.Children | Where-Object { $_.Visibility -eq 'Visible' } | ForEach-Object { $_.Content }) -join ',')|$($script:AboutParts.Credits.Count)|$($script:AboutParts.Version.Text)|$($script:AboutParts.License.Text -replace '[^ -~]', '?')"
Select-AkariPage 'About'; "about=$script:Cat"
# themes: one dictionary swapped, saved, the logo with it; the Windows accent replaces crimson
"themeStart=$script:ThemeSetting,$(@($window.Resources.MergedDictionaries | Where-Object { $_.Contains('Acc') }).Count)"
Set-AkariTheme 'Light' -Save; "themeLight=$($window.FindResource('Bg').Color)|$(@($window.Resources.MergedDictionaries | Where-Object { $_.Contains('Acc') }).Count)|$(Get-AkariThemeSetting)|$($Body.Background.Color)|$($window.FindResource('Acc').Color)"
$lightLogo = Split-Path $Logo.Source.UriSource.LocalPath -Leaf
Set-AkariTheme 'Dark'; "themeDark=$($window.FindResource('Bg').Color)|$(Get-AkariThemeSetting)|$($window.FindResource('Acc').Color)"
"logo=$lightLogo|$(Split-Path $Logo.Source.UriSource.LocalPath -Leaf)"
Set-AkariTheme 'Nonsense'; "themeBad=$script:ThemeSetting"
function Get-AkariRegValue { [byte[]]@(0x9F, 0xF5, 0xB5, 0, 0x6F, 0xD3, 0x8C, 0, 0x3D, 0xB2, 0x63, 0, 0x10, 0x89, 0x3E, 0, 0x0B, 0x6A, 0x2E, 0, 0x07, 0x4C, 0x20, 0, 0x03, 0x2F, 0x13, 0, 0, 0, 0, 0) }
Save-AkariSetting 'Accent' 'Windows'; Set-AkariTheme 'Dark'; "accentWindows=$($window.FindResource('Acc').Color)|$($window.FindResource('AccText').Color)"
Save-AkariSetting 'Accent' 'Akari'; Set-AkariTheme 'Dark'; "accentAkari=$($window.FindResource('Acc').Color)"
"title=$($TitleText.Text)|$AppVersionText.Text"
"version=$($AppVersionText.Text -eq $AkariVersion)"
"winIcon=$($window.Icon.Decoder.GetType().Name)|$(Split-Path ([string]$window.Icon) -Leaf)|$($window.Icon.Decoder.Frames.Count)"
# the pane collapses to 48 px under 1000 px, and with the pane toggle
Update-AkariWidth 900; "narrow=$($script:Compact)|$($Nav.Width)|$($script:NavItems['Home'].Button.ToolTip)"
Update-AkariWidth 1200; "wide=$($script:Compact)|$($Nav.Width)"
Click $PaneBtn; "toggled=$($script:Compact)|$($script:UserCompact)"; Click $PaneBtn
# Import settings: a settings file opens Guided on its Tweaks step, a copy kept in the presets
$importFile = Join-Path (Split-Path $LogFile) 'import.json'
Set-Content $importFile '{ "Name": "Imported", "Tweaks": [ "cat-tog" ] }'
function Select-AkariSettingsFile($Save) { $importFile }
Start-AkariImport
"import=$script:Cat|$script:Mode|$script:Step|$(@($script:Sel.Keys) -join ',')|$(Test-Path (Join-Path $AkariPresetDir 'import.json'))"
Reset-AkariSteps
# the update check: an update found on Home asks and shows its InfoBar; away from Home it doesn't ask
$rel = @{ Ok = $true; Version = [version]'9.0.0'; Notes = "## New`n- **fast**"; PageUrl = 'https://example.test/r'; AssetUrl = 'https://example.test/a.zip'; Digest = 'sha256:x' }
$script:Prompted = $false; Complete-AkariUpdateCheck $rel $false
"launch=$script:Prompted|$(@($HomePanel.Children | Where-Object { $_.Tag -eq 'Info' }).Count)|$(@($HomePanel.Children | Where-Object { $_.Tag -eq 'Info' })[0].Child.Children[2].Inlines.FirstInline.Text)"
Select-AkariPage 'Optimize'; $script:Prompted = $false; Complete-AkariUpdateCheck $rel $false; "launchAway=$script:Prompted"
Select-AkariPage 'Settings'; "aboutAvail=$($script:AboutParts.Update.Visibility)|$($script:AboutParts.NotesRow.Visibility)"
Complete-AkariUpdateCheck @{ Ok = $false; Message = 'No releases yet.' } $true; "aboutError=$($script:AboutParts.Status.Children[0].Text)|$($script:AboutParts.Update.Visibility)"
# dialogs: built, never shown (ShowDialog would wait for a click)
$d = New-AkariDialog "Body text`n- a consequence" 'Restart now?' @('Cancel', 'Restart') 'Warning'
$bs = @($d.FindName('DlgButtons').Children)
"dlg=$($d.FindName('DlgTitle').Text)|$($d.FindName('DlgText').Children.Count)|$(($bs | ForEach-Object { $_.Content }) -join ',')|$($bs[0].Style -eq $window.FindResource('BtnP')),$($bs[0].IsDefault),$($d.FindName('DlgCard').Width)|$($d.FindName('DlgInput').Visibility)"
$bs[0].RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Primitives.ButtonBase]::ClickEvent)); "dlgClick=$($d.Tag.Result)"
${function:Show-AkariDialog} = $null
. "$Root\UI\Dialog.ps1"
function Invoke-AkariDialog($Dialog) { $script:Shown = $Dialog; 'Update now' }
"confirm=$(Confirm-AkariDialog 'q' 'Update now' 'Later'),$(Confirm-AkariDialog 'q' 'Start One-click'),$($script:Shown.FindName('DlgTitle').Text)"
function Invoke-AkariDialog($Dialog) { $Dialog.FindName('DlgInput').Text = '  My preset  '; 'Save' }
"readText=$(Read-AkariText 'A name:' 'Save')|$($null -eq (Read-AkariText 'A name:' 'Keep'))"
'@

    $out = Invoke-Probe $probe @{ Root = $Root; LogFile = "$TestDrive\a.log"; Install = "$TestDrive\inst" }

    It 'builds without errors' { $out['error'] | Should BeNullOrEmpty }
    It 'the nav pane: the pages, Optimize''s five sections, Settings at the bottom, 280 px' {
        $out.nav | Should Be 'Home,Install AkariOS,Optimize,Catalogue:Optimize,Catalogue:Customize,Catalogue:Hardware,Catalogue:Advanced,Catalogue:Tools,Downloads,Install USB,ISO Builder,Settings'
        $out.navFoot | Should Be 'Settings|280'
    }
    It 'Home: no header, its nav item selected, no history yet' { $out.home | Should Be 'Visible|Home|Collapsed|False' }
    It 'Home: Tweaks counted at once, the other facts in one background read, three tiles, One-click the accent and recommended one' {
        $out.homeStats | Should Be '4|1|3'
        $out.homeHero | Should Be 'True|True'
        $out.homeStatsDone | Should Be '12|34'
    }
    It 'Choose changes opens Guided on its first step, with the footer and a breadcrumb' {
        $out.choose | Should Be 'Install AkariOS|Guided|0|Install AkariOS|Visible|Install AkariOS>Apps|Step 1 of 3 . Apps|Cancel|True'
        $out.next | Should Be '1|Step 2 of 3 . Tweaks'
    }
    It 'Back walks the steps of a flow, Cancel goes back to the chooser' {
        $out.backStep | Should Be 'Install AkariOS|0'
        $out.cancel | Should Be 'Install AkariOS|Choose|Install AkariOS|Collapsed'
    }
    It 'Optimize opens its landing page with its sections under it; clicked again there, they close' {
        $out.optimize | Should Be 'Optimize|Optimize|True|Optimize'
        $out.kidsToggle | Should Be 'False'
    }
    It 'a section page: its kid selected, a crumb line over the heading, its categories as rows in their groups (Categories.psd1)' {
        $out.section | Should Be 'Catalogue:Customize|Catalogue:Customize|Optimize>Customize|Catalogue:Customize/Taskbar,Catalogue:Customize/Start|Desktop|Visible'
        $out.catRow | Should Be 'Alignment, the Search, Widgets and Copilot buttons, tray icons, Quick Settings|1'
    }
    It 'a category row opens its own page: its cards only, Optimize > Section > Category' {
        $out.category | Should Be 'Catalogue:Customize/Taskbar|Catalogue:Customize|Optimize>Customize>Taskbar|True|True'
    }
    It 'reads States in the background: skeletons and a waiting switch until they arrive' {
        $out.reading | Should Be 'Reading.|False|True'
        $out.read | Should Be '|False|True|True|True'
    }
    It 'a switch applies right away in the job; a second change queues; Explorer changes show the restart InfoBar' {
        $out.run | Should Be 'Applying.|Catalogue|Apply'
        $out.queued | Should Be '1'
        $out.done | Should Be 'True|Visible|Visible|tuning'
        $out.action | Should Be 'True|2'
    }
    It 'a Safe Mode Tweak asks first; Later waits in the Safe Mode InfoBar; switched back, it leaves it' {
        $out.safe | Should Be 'Cancel,Later,Restart and apply|Apply|Waiting for Safe Mode|Visible|1 change waits for Safe Mode|0|Waiting for Safe Mode'
        $out.safeBack | Should Be '0|False'
    }
    It 'search: suggestions as you type, the results grouped by Section > Category with the match highlighted' {
        $out.suggest | Should Be 'cat-tog,cat-tog2,cat-safe|0'
        $out.suggestOpen | Should Be 'Catalogue:Customize/Start|Optimize>Customize>Start|cat-tog2'
        $out.search | Should Be 'Search|Optimize|Results for "Cat"|Customize > Start,Customize > Taskbar,Advanced > Security'
        $out.highlight | Should Be 'Cat'
        $out.searchNone | Should Be 'No Tweaks match "zzz"'
    }
    It 'the Legacy pages open from Optimize, legacy rows only' { $out.legacy | Should Be 'Check|Optimize|Optimize>Check|1' }
    It 'Back returns to the page before' { $out.back | Should Be 'Search|True' }
    It 'Downloads (Remove apps = its Windows apps), Install USB and the ISO Builder are pages of their own' {
        $out.downloads | Should Be 'Downloads|Downloads|Downloads'
        $out.remove | Should Be 'Downloads|Downloads|Windows|False|Store apps,Optional features,Windows features,Legacy apps|Windows apps,External apps'
    }
    It 'closing asks once, naming the job, the installs waiting and Optimize''s changes waiting' {
        $out.closing | Should Be 'Installing Steam|2 apps waiting to install|1 change from Optimize waiting'
        $out.closingText | Should Be "These are still running:/- Installing Steam/- 2 apps waiting to install//Close AkariOS anyway? What is running may be left half done, and what waits won't run."
        $out.closingNone | Should Be '0'
        $out.usb | Should Be 'Install USB|Install USB|True|Default|False|No Windows setup USB found'
        $out.usbOld | Should Be 'Install USB'
    }
    It 'the ISO Builder is a wizard: modes, the image (Pro picked), Components reading the image, Review, the stages, Build another' {
        $out.iso | Should Be 'ISO Builder|ISO Builder|0|ISO Builder|Visible|Start|True|False|8|Custom'
        $out.isoImage | Should Be '1|ISO Builder>Windows image|Next|False|True|Step 2 of 6 . Windows image.Open an ISO and pick an edition first.|No image yet'
        $out.isoModeSoon | Should Be '0|Custom'
        $out.isoMode | Should Be '1|Custom'
        $out.isoOpened | Should Be '2|True|Windows 11 Pro (10.0.26200.1)|Next|True|True|Windows 11 Pro . 10.0.26200.1'
        $out.isoComponents | Should Be '2|IsoRead|Next|False|False|False|True'
        $out.isoRead | Should Be 'True|Next|True|True|Store apps (1)'
        $out.isoReview | Should Be '4|ISO Builder>Review|Build ISO|True|True'
        $out.isoBuild | Should Be 'IsoBuild|6|Windows 11 Pro|0|Microsoft.BingNews_1_x64__8wekyb3d8bbwe|True|True|5|Build another|False|False'
        $out.isoStages | Should Be 'True|Done,Done,Running,Waiting'
        $out.isoDone | Should Be 'D:\Win11-Akari.iso|0|Build another|True|False|False'
        $out.isoAgain | Should Be '0|0|Custom'
        $out.isoUupDone | Should Be 'D:\Windows11_25H2_Pro_en-us.iso|True'
    }
    It 'Settings: Appearance, Settings files, Recovery, About, in place of the options menu and the About page' {
        $out.settings | Should Be 'Settings|Settings|Appearance,Settings files,Recovery,About'
        $out.themeRadios | Should Be 'Light,Dark,Use system setting*|Akari crimson,Windows accent|True'
        $out.aboutLinks | Should Match '^GitHub,Report a bug,Discord,View license,Full credits\|10\|AkariOS \d+\.\d+\.\d+\|MIT License'
        $out.about | Should Be 'Settings'
    }
    It 'swaps one theme dictionary, saves the choice and the logo; Akari crimson unless Windows'' accent is picked' {
        $out.themeStart | Should Be 'System,1'
        $out.themeLight | Should Be '#FFF3F3F3|1|Light|#FFF3F3F3|#FFC8102E'
        $out.themeDark | Should Be '#FF202020|Light|#FFFF6B7D'
        $out.logo | Should Be 'AkariLogo-light.png|AkariLogo-dark.png'
        $out.themeBad | Should Be 'System'
        $out.accentWindows | Should Be '#FF6FD38C|#FF9FF5B5'
        $out.accentAkari | Should Be '#FFFF6B7D'
    }
    It 'the title bar: AkariOS and the version; the window icon is AkariLogo.ico' {
        $out.version | Should Be 'True'
        $out.winIcon | Should Be 'IconBitmapDecoder|AkariLogo.ico|9'
    }
    It 'collapses the pane to 48 px under 1000 px (tooltips on its items), and with the pane toggle' {
        $out.narrow | Should Be 'True|48|Home'
        $out.wide | Should Be 'False|280'
        $out.toggled | Should Be 'True|True'
    }
    It 'Import settings opens the file in Guided on the Tweaks step, and keeps a copy in the presets' {
        $out.import | Should Be 'Install AkariOS|Guided|1|cat-tog|True'
    }
    It 'a launch check that finds an update asks on Home and shows its InfoBar; not once the user left Home' {
        $out.launch | Should Be 'True|1|AkariOS 9.0.0 is available'
        $out.launchAway | Should Be 'False'
        $out.aboutAvail | Should Be 'Visible|Visible'
        $out.aboutError | Should Be 'No releases yet.|Collapsed'
    }
    It 'a dialog: the title, the text and its consequences, the accent action first (Enter), 448 px' {
        $out.dlg | Should Be 'Restart now?|2|Restart,Cancel|True,True,448|Collapsed'
        $out.dlgClick | Should Be 'Restart'
    }
    It 'Confirm-AkariDialog is $true only for its main action; Read-AkariText trims, and is $null when cancelled' {
        $out.confirm | Should Be 'True,False,AkariOS'
        $out.readText | Should Be 'My preset|True'
    }
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
