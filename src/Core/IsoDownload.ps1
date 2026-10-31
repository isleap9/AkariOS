# The ISO Builder's downloads (plan docs/plans/2026-10-31-iso-builder.md):
# - UUP Dump (uupdump.net, its JSON API: https://git.uupdump.net/uup-dump/json-api): a Windows 11 ISO built from
#   Microsoft's own update files by UUP Dump's converter (abbodi1406's uup-converter), after zISO Tweaker's
#   uup-dump-get-windows-iso.ps1 (MIT). Any language, Home / Pro (+ N) or a virtual edition made from Pro.
# - Massgrave (massgrave.dev): what UUP Dump can't make (LTSC, IoT LTSC, the consumer / business media). Its links go
#   to file hosts that block scripts, so Akari only lists them (read from the site's markdown on GitHub) and finds the
#   file the browser downloaded.
# The network only through Invoke-AkariUupRequest, Save-AkariUupPackage, Invoke-AkariWebText; the converter only
# through Invoke-AkariUupScript (tests mock them).

# version -> its build number
$AkariUupVersions = [ordered]@{ '26H2' = '26300'; '25H2' = '26200'; '24H2' = '26100'; '23H2' = '22631' }
# virtual editions UUP Dump's converter makes from Pro: code -> label
$AkariUupVirtual = [ordered]@{
    Enterprise              = 'Enterprise'
    Education               = 'Education'
    IoTEnterprise           = 'IoT Enterprise'
    ProfessionalEducation   = 'Pro Education'
    ProfessionalWorkstation = 'Pro for Workstations'
}
$AkariMassgravePages = @(
    'https://raw.githubusercontent.com/massgravel/massgrave.dev/main/docs/windows_11_links.md'
    'https://raw.githubusercontent.com/massgravel/massgrave.dev/main/docs/windows_ltsc_links.md'
)
if ($null -eq $AkariUupRetryDelay) { $AkariUupRetryDelay = 5 }

# ---- wrappers (tests mock these)

# one UUP Dump API call: the parsed JSON, or throws
function Invoke-AkariUupRequest([string]$Name, [hashtable]$Query) {
    $ProgressPreference = 'SilentlyContinue'
    Invoke-RestMethod -Method Get -Uri "https://api.uupdump.net/$Name.php" -Body $Query -UseBasicParsing -TimeoutSec 60 -ErrorAction Stop
}

# the converter package (a zip) for a build, language and edition
function Save-AkariUupPackage([string]$Url, [hashtable]$Body, [string]$OutFile) {
    $ProgressPreference = 'SilentlyContinue'
    Invoke-WebRequest -Method Post -Uri $Url -Body $Body -OutFile $OutFile -UseBasicParsing -ErrorAction Stop | Out-Null
}

# runs the package's uup_download_windows.cmd in its folder (downloads the files, builds the ISO); its output goes to
# the log. Returns the exit code.
function Invoke-AkariUupScript([string]$Dir) {
    $ErrorActionPreference = 'Continue'
    Push-Location -LiteralPath $Dir
    try {
        & "$env:SystemRoot\System32\cmd.exe" /c uup_download_windows.cmd 2>&1 | ForEach-Object { Write-Log "$_" }
        $LASTEXITCODE
    }
    finally { Pop-Location }
}

# a web page as text, or throws
function Invoke-AkariWebText([string]$Url) {
    $ProgressPreference = 'SilentlyContinue'
    (Invoke-WebRequest -Uri $Url -UseBasicParsing -TimeoutSec 60 -ErrorAction Stop).Content
}

# ---- UUP Dump

# an API call with retries (UUP Dump is often busy): @{ Ok; Response; Message }. Never throws.
function Invoke-AkariUupApi([string]$Name, [hashtable]$Query) {
    $last = ''
    for ($i = 0; $i -lt 3; $i++) {
        if ($i) { Start-Sleep -Seconds $AkariUupRetryDelay }
        try {
            $r = Invoke-AkariUupRequest $Name $Query
            if ($r.response.error) { return @{ Ok = $false; Response = $null; Message = "UUP Dump: $($r.response.error)" } }
            return @{ Ok = $true; Response = $r.response; Message = '' }
        }
        catch { $last = $_.Exception.Message }
    }
    @{ Ok = $false; Response = $null; Message = "UUP Dump didn't answer: $last" }
}

# the builds of a listid answer (an object keyed by number, or an array): @{ Id; Title; Build; Arch }. Pure.
function ConvertTo-AkariUupBuilds($Builds) {
    $items = if ($Builds -is [array]) { $Builds } elseif ($Builds) { @($Builds.PSObject.Properties | ForEach-Object { $_.Value }) } else { @() }
    @(foreach ($b in $items) { @{ Id = $b.uuid; Title = $b.title; Build = "$($b.build)"; Arch = "$($b.arch)" } })
}

# the newest release (not a preview, not a lone update) of a build number. Pure.
function Select-AkariUupBuild($Builds, [string]$Number) {
    $ok = @($Builds | Where-Object {
            $_.Title -match '^Windows 11, version' -and $_.Title -notmatch 'preview' -and $_.Build -like "$Number.*" -and (-not $_.Arch -or $_.Arch -eq 'amd64')
        })
    @($ok | Sort-Object { [version]"10.0.$($_.Build)" } -Descending)[0]
}

# the newest build of a version ('25H2'): @{ Ok; Build = @{ Id; Title; Build }; Message }
function Get-AkariUupBuild([string]$Version) {
    $n = $AkariUupVersions[$Version]
    if (-not $n) { return @{ Ok = $false; Message = "Unknown Windows 11 version: $Version" } }
    $r = Invoke-AkariUupApi 'listid' @{ search = "windows 11 $n amd64"; sortByDate = '1' }
    if (-not $r.Ok) { return $r }
    $b = Select-AkariUupBuild (ConvertTo-AkariUupBuilds $r.Response.builds) $n
    if (-not $b) { return @{ Ok = $false; Message = "UUP Dump has no Windows 11 $Version release build ($n) right now." } }
    @{ Ok = $true; Build = $b; Message = '' }
}

# a build's languages: @{ Ok; Items = @(@{ Code; Name }) sorted by name; Message }
function Get-AkariUupLanguages([string]$Id) {
    $r = Invoke-AkariUupApi 'listlangs' @{ id = $Id }
    if (-not $r.Ok) { return $r }
    $items = @($r.Response.langFancyNames.PSObject.Properties | ForEach-Object { @{ Code = $_.Name; Name = "$($_.Value)" } } | Sort-Object { $_.Name })
    @{ Ok = $true; Items = $items; Message = '' }
}

# the editions a build and language can become: its own (Home, Pro, their N) and, with Pro, the virtual ones.
# $Fancy: the API's editionFancyNames (code -> name). Pure.
function Get-AkariUupTargets($Fancy) {
    $codes = @($Fancy.PSObject.Properties | ForEach-Object { $_.Name })
    if ($Fancy -is [hashtable]) { $codes = @($Fancy.Keys) }
    $out = [System.Collections.Generic.List[hashtable]]::new()
    foreach ($c in @('CORE', 'COREN', 'PROFESSIONAL', 'PROFESSIONALN') + @($codes | Sort-Object)) {
        if ($codes -notcontains $c -or @($out | Where-Object { $_.Code -eq $c -and -not $_.Virtual }).Count) { continue }
        $label = switch ($c) { 'CORE' { 'Home' } 'COREN' { 'Home N' } 'PROFESSIONAL' { 'Pro' } 'PROFESSIONALN' { 'Pro N' } default { "$($Fancy.$c)" -replace '^Windows ', '' } }
        $out.Add(@{ Label = $label; Code = $c; Virtual = '' })
    }
    if ($codes -contains 'PROFESSIONAL') {
        foreach ($v in $AkariUupVirtual.Keys) { $out.Add(@{ Label = $AkariUupVirtual[$v]; Code = 'PROFESSIONAL'; Virtual = $v }) }
    }
    , $out.ToArray()
}

# a build's editions for a language: @{ Ok; Items = Get-AkariUupTargets; Message }
function Get-AkariUupEditions([string]$Id, [string]$Lang) {
    $r = Invoke-AkariUupApi 'listeditions' @{ id = $Id; lang = $Lang }
    if (-not $r.Ok) { return $r }
    @{ Ok = $true; Items = (Get-AkariUupTargets $r.Response.editionFancyNames); Message = '' }
}

# the converter package request: an edition as it is, or a virtual one made from it (zISO's bodies). Pure.
function Get-AkariUupPackageBody([string]$Virtual) {
    if ($Virtual) { return @{ autodl = '3'; updates = '1'; cleanup = '1'; 'virtualEditions[]' = $Virtual } }
    @{ autodl = '2'; updates = '1'; cleanup = '1' }
}

# ConvertConfig.ini as zISO sets it: exit when done, reset the component base, .NET 3.5 in; a virtual edition made
# and the source edition dropped. Pure.
function Set-AkariUupConfig([string[]]$Lines, [string]$Virtual) {
    $set = [ordered]@{ AutoExit = '1'; ResetBase = '1'; NetFx3 = '1' }
    if ($Virtual) { $set.StartVirtual = '1'; $set.vDeleteSource = '1'; $set.vAutoEditions = $Virtual }
    @(foreach ($l in $Lines) {
            $k = ($l -split '=', 2)[0].Trim()
            if ($l -match '^\s*[^;\[][^=]*=' -and $set.Contains($k)) { "$k=$($set[$k])" } else { $l }
        })
}

# the ISO's name: Windows11_25H2_IoT-Enterprise_en-us.iso. Pure.
function Get-AkariUupIsoName([string]$Version, [string]$Label, [string]$Lang) {
    'Windows11_{0}_{1}_{2}.iso' -f $Version, ($Label -replace '[^A-Za-z0-9]+', '-'), $Lang
}

# downloads and builds the ISO into $OutDir: @{ Ok; Path; Message }. $Target: one of Get-AkariUupTargets. Long
# (Microsoft's files are several GB): the converter's own output goes to the log.
function Save-AkariUupIso([string]$Version, $Build, [string]$Lang, $Target, [string]$OutDir) {
    $work = Join-Path $OutDir 'AkariUup'
    $zip = "$work.zip"
    try {
        $msg = Test-AkariIsoSpace $OutDir
        if ($msg) { throw $msg }
        Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath $zip -Force -ErrorAction SilentlyContinue
        Write-Log "Getting UUP Dump's package for Windows 11 $Version $($Target.Label) ($Lang), build $($Build.Build)"
        $url = 'https://uupdump.net/get.php?id={0}&pack={1}&edition={2}' -f $Build.Id, $Lang, $Target.Code.ToLower()
        Save-AkariUupPackage $url (Get-AkariUupPackageBody $Target.Virtual) $zip
        Expand-Archive -LiteralPath $zip -DestinationPath $work -Force
        $ini = Join-Path $work 'ConvertConfig.ini'
        if (-not (Test-Path -LiteralPath $ini)) { throw 'UUP Dump''s package has no ConvertConfig.ini.' }
        Set-Content -LiteralPath $ini -Value (Set-AkariUupConfig (Get-Content -LiteralPath $ini) $Target.Virtual) -Encoding Ascii
        Write-Log 'Downloading Microsoft''s files and building the ISO (this takes a while)'
        $c = Invoke-AkariUupScript $work
        if ($c -ne 0) { throw "UUP Dump's converter failed (exit code $c)." }
        $iso = @(Get-ChildItem -LiteralPath $work -Filter *.iso -File)[0]
        if (-not $iso) { throw 'UUP Dump''s converter made no ISO.' }
        $dest = Join-Path $OutDir (Get-AkariUupIsoName $Version $Target.Label $Lang)
        Remove-Item -LiteralPath $dest -Force -ErrorAction SilentlyContinue
        Move-Item -LiteralPath $iso.FullName -Destination $dest
        Write-Log "ISO downloaded: $dest"
        @{ Ok = $true; Path = $dest; Message = '' }
    }
    catch {
        Write-ErrLog "ISO Builder (UUP Dump): $($_.Exception.Message)"
        @{ Ok = $false; Path = $null; Message = $_.Exception.Message }
    }
    finally {
        Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath $zip -Force -ErrorAction SilentlyContinue
    }
}

# ---- Massgrave

# a Massgrave download page (markdown) -> its Windows 11 x64 ISOs: @{ Product; Language; File; Url }. The product is
# the last bold line naming Windows before the table. Pure.
function Read-AkariMassgrave([string]$Markdown) {
    $product = ''
    @(foreach ($l in ($Markdown -split "`r?`n")) {
            if ($l -match '^\*\*(Windows[^*]*)\*\*') { $product = $Matches[1].Trim(); continue }
            if ($l -match '^\|\s*([^|]+?)\s*\|\s*([^|]+?)\s*\|\s*\[([^\]]+\.iso)\]\((https?://[^)\s]+)\)') {
                $lang, $arch, $file, $url = $Matches[1], $Matches[2], $Matches[3], $Matches[4]
                if ($arch -ne 'x64' -or $file -notmatch 'windows_11') { continue }
                @{ Product = $product; Language = $lang; File = $file; Url = $url }
            }
        })
}

# Massgrave's Windows 11 ISOs from both pages: @{ Ok; Items; Message }. Never throws.
function Get-AkariMassgraveCatalogue {
    try {
        $items = foreach ($u in $AkariMassgravePages) { Read-AkariMassgrave (Invoke-AkariWebText $u) }
        $items = @($items)
        if (-not $items.Count) { return @{ Ok = $false; Items = @(); Message = 'Massgrave''s pages list no Windows 11 ISO (their layout may have changed).' } }
        @{ Ok = $true; Items = $items; Message = '' }
    }
    catch { @{ Ok = $false; Items = @(); Message = "Couldn't read Massgrave's list: $($_.Exception.Message)" } }
}

# the file a browser saved in the user's Downloads (or $Folder): $File itself, or a copy it renamed ("name (1).iso"),
# the newest; $null while it isn't there (a download in progress has another extension)
function Find-AkariDownloadedIso([string]$File, [string]$Folder = '') {
    if (-not $Folder) { $Folder = Get-AkariUserFolder 'Downloads' }
    if (-not $Folder -or -not (Test-Path -LiteralPath $Folder)) { return $null }
    $base = [IO.Path]::GetFileNameWithoutExtension($File)
    $hit = @(Get-ChildItem -LiteralPath $Folder -Filter '*.iso' -File -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -eq $File -or $_.BaseName -like "$base (*)" } | Sort-Object LastWriteTime -Descending)[0]
    if ($hit) { $hit.FullName } else { $null }
}
