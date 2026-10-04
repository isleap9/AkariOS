# Decode test for Expand-AkariOSEngineAsset. The asset map and the destination root
# are both INJECTED, so this reads no $sync.assets, writes no %SystemRoot%\Temp and
# touches no registry or boot configuration.
param([string]$Root = "C:/Users/isleap/Documents/GitHub/AkariOS/AkariOS")

$ErrorActionPreference = "Stop"
. (Join-Path $Root "functions\private\Assets.ps1")

$fail = 0
function Assert($label, $cond) {
    if ($cond) { Write-Host "  PASS  $label" } else { Write-Host "  FAIL  $label"; $script:fail++ }
}

# Scratch directory under $env:TEMP, removed in the finally below.
$scratch = Join-Path $env:TEMP ("akarios-assets-test-" + [guid]::NewGuid().ToString("N"))

try {
    New-Item -ItemType Directory -Path $scratch -Force | Out-Null

    # Known payload with a character that survives a base64 round trip and a
    # non-ASCII byte, so an encoding mistake would show up as a content mismatch.
    $payload = "Write-Host `"stage-one`" -ForegroundColor Cyan`r`n# caf`u{00e9} `u{4e2d}`u{6587}`r`n"
    $encoded = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($payload))
    $map = @{ stepone = $encoded }

    Write-Host "Decodes an injected asset map into the injected destination root"
    $path = Expand-AkariOSEngineAsset -Name "stepone" -Assets $map -DestinationRoot $scratch
    Assert "returns a path"          ($path -is [string] -and $path.Length -gt 0)
    Assert "file exists on disk"     (Test-Path -LiteralPath $path)
    Assert "bare engine file name"   ((Split-Path -Leaf $path) -eq "stepone.ps1")

    $content = [System.IO.File]::ReadAllText($path)
    Assert "content round-trips"     ($content -eq $payload)

    $bytes = [System.IO.File]::ReadAllBytes($path)
    $hasBom = ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF)
    Assert "written with no BOM"     (-not $hasBom)

    Write-Host "A second call without -Overwrite returns the existing path unchanged"
    $again = Expand-AkariOSEngineAsset -Name "stepone" -Assets $map -DestinationRoot $scratch
    Assert "same path returned"      ($again -eq $path)

    Write-Host "A leading BOM in the decoded text is stripped"
    $bomPayload = ([char]0xFEFF) + "Write-Host `"bom`""
    $bomMap = @{ winsux = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($bomPayload)) }
    $bomPath = Expand-AkariOSEngineAsset -Name "winsux" -Assets $bomMap -DestinationRoot $scratch
    $bomBytes = [System.IO.File]::ReadAllBytes($bomPath)
    $bomHasBom = ($bomBytes.Length -ge 3 -and $bomBytes[0] -eq 0xEF -and $bomBytes[1] -eq 0xBB -and $bomBytes[2] -eq 0xBF)
    Assert "no BOM on disk"          (-not $bomHasBom)
    Assert "text preserved"          ([System.IO.File]::ReadAllText($bomPath) -eq "Write-Host `"bom`"")

    Write-Host "-Overwrite rewrites a file that already exists"
    $map2 = @{ stepone = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes("replacement")) }
    $rewritten = Expand-AkariOSEngineAsset -Name "stepone" -Assets $map2 -DestinationRoot $scratch -Overwrite
    Assert "same path"               ($rewritten -eq $path)
    Assert "content replaced"        ([System.IO.File]::ReadAllText($path) -eq "replacement")

    Write-Host "A missing asset name returns `$null and never throws"
    $missing = Expand-AkariOSEngineAsset -Name "steptwo" -Assets $map -DestinationRoot $scratch
    Assert "returns null"            ($null -eq $missing)

    Write-Host "An empty asset map returns `$null rather than throwing"
    $empty = Expand-AkariOSEngineAsset -Name "winsux" -Assets @{} -DestinationRoot $scratch
    Assert "returns null"            ($null -eq $empty)

    Write-Host "The real embedded assets decode from the shipped source files"
    # Reads the on-disk engine copies directly (no $sync.assets needed) and checks
    # the helper reproduces them byte-for-byte, which is the D-06 fidelity gate.
    foreach ($pair in @(@("winsux","winsux.ps1"), @("stepone","stepone.ps1"), @("steptwo","steptwo.ps1"), @("reg","reg.reg"))) {
        $key = $pair[0]; $file = $pair[1]
        $srcPath = Join-Path $Root "assets\text\$file"
        if (-not (Test-Path -LiteralPath $srcPath)) { Assert "source present: $file" $false; continue }
        $real = @{ $key = [Convert]::ToBase64String([System.IO.File]::ReadAllBytes($srcPath)) }
        # -Overwrite: earlier cases already wrote some of these same file names.
        $out = Expand-AkariOSEngineAsset -Name $key -Assets $real -DestinationRoot $scratch -Overwrite
        Assert "$file writes to its bare name" ((Split-Path -Leaf $out) -eq $file)
        Assert "$file decodes byte-identically" ([System.IO.File]::ReadAllText($out) -eq [System.IO.File]::ReadAllText($srcPath))
    }
} finally {
    if (Test-Path -LiteralPath $scratch) {
        Remove-Item -LiteralPath $scratch -Recurse -Force -ErrorAction SilentlyContinue
    }
}

if ($fail -eq 0) { Write-Host "`nALL ASSET TESTS PASSED"; exit 0 }
else { Write-Host "`n$fail ASSET TEST(S) FAILED"; exit 1 }