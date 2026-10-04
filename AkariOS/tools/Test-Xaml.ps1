# Static XAML validation. Parses the assembled UI with XamlReader in-process and
# never creates or shows a window (Parse only builds the logical tree).
param([string]$Root = "C:/Users/isleap/Documents/GitHub/AkariOS/AkariOS")

Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase | Out-Null

$nl = "`r`n"
$xaml = Get-Content -Path (Join-Path $Root "xaml\MainWindow.xaml") -Raw -Encoding UTF8

$panelsDir = Join-Path $Root "xaml\panels"
$panels = Get-ChildItem -Path $panelsDir -File -Filter "*.xaml" | Sort-Object Name |
    ForEach-Object { (Get-Content -Path $_.FullName -Raw -Encoding UTF8).TrimEnd() }
$panelsXaml = ($panels -join ($nl + $nl))
$assembled = [regex]::Replace($xaml, '[^\r\n]*<!-- @PANELS@[^\r\n]*-->',
    [System.Text.RegularExpressions.MatchEvaluator]{ param($m) $panelsXaml })

# 1. XML well-formedness
try { [void][xml]$assembled; Write-Host "XML: OK" } catch { Write-Host "XML: FAIL - $($_.Exception.Message)"; exit 1 }

# 2. XamlReader.Parse (returns a tree; no window is created)
try {
    $obj = [Windows.Markup.XamlReader]::Parse($assembled)
    Write-Host ("XAML: OK - root type = " + $obj.GetType().Name + ", Title = '" + $obj.Title + "'")
} catch {
    Write-Host ("XAML: FAIL - " + $_.Exception.Message)
    exit 1
}

# 3. Panel sanity: every panel root must carry a Name so scripts/main.ps1 can register it
$doc = [xml]$assembled
foreach ($p in $panels) { Write-Host ("  panel {0} chars" -f $p.Length) }
$panelNames = ($panels | ForEach-Object { ([xml]$_).DocumentElement.GetAttribute("Name") })
Write-Host ("Panels: " + ($panelNames -join ", "))

# 4. Named-control registration count, matching the //*[@Name] walk in main.ps1
$nodes = $doc.SelectNodes("//*[@Name]")
Write-Host ("Named controls registered into `$sync: " + $nodes.Count)

# 5. Duplicate Name detection (XamlReader throws on a duplicate registered name)
$dupes = $nodes | Group-Object { $_.GetAttribute("Name") } | Where-Object { $_.Count -gt 1 }
if ($dupes) {
    Write-Host ("DUPLICATE NAMES: " + (($dupes | ForEach-Object { "$($_.Name) x$($_.Count)" }) -join ", "))
    exit 1
} else {
    Write-Host "Duplicate names: none"
}
Write-Host "ALL XAML CHECKS PASSED"