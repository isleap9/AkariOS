$Core = Join-Path (Join-Path (Split-Path $PSScriptRoot) 'src') 'Core'

# the support file (X1): the names taken out, the zip's entries; files under TestDrive: only
Describe 'ConvertTo-AkariSupportText' {
    foreach ($f in 'Log', 'Support') { . "$Core\$f.ps1" }

    It 'takes the user folder out of profile paths, one or two backslashes and slashes' {
        ConvertTo-AkariSupportText 'C:\Users\Bob\AppData and "C:\\Users\\Bob\\x" and c:/users/Bob/y' @() '' |
            Should Be 'C:\Users\<user>\AppData and "C:\\Users\\<user>\\x" and c:/users/<user>/y'
    }

    It 'leaves Windows'' own profile folders alone' {
        ConvertTo-AkariSupportText 'C:\Users\Public\Desktop C:\Users\Default\x C:\Users\Publicity\y' @() '' |
            Should Be 'C:\Users\Public\Desktop C:\Users\Default\x C:\Users\<user>\y'
    }

    It 'replaces user and computer names as whole words, ignoring case' {
        ConvertTo-AkariSupportText 'bob ran on DESKTOP-1 as BOB; bobby stays; desktop-1x stays' @('Bob') 'desktop-1' |
            Should Be '<user> ran on <pc> as <user>; bobby stays; desktop-1x stays'
    }

    It 'replaces the longest name first' {
        ConvertTo-AkariSupportText 'Ann Lee and Ann' @('Ann', 'Ann Lee') '' | Should Be '<user> and <user>'
    }

    It 'leaves names shorter than 2 characters and empty text alone' {
        ConvertTo-AkariSupportText 'a b' @('a', ' ', '') 'b' | Should Be 'a b'
        ConvertTo-AkariSupportText '' @('Bob') 'PC' | Should Be ''
    }

    It 'escapes regex characters in names' {
        ConvertTo-AkariSupportText 'j.d+ and jxd' @('j.d+') '' | Should Be '<user> and jxd'
    }
}

Describe 'New-AkariSupportFile' {
    foreach ($f in 'Log', 'Support') { . "$Core\$f.ps1" }
    Add-Type -AssemblyName System.IO.Compression
    $AkariLogFile = 'TestDrive:\unused.log'

    function Read-Zip([string]$Path) {
        $z = [IO.Compression.ZipArchive]::new([IO.File]::OpenRead($Path), 'Read')
        try {
            $o = [ordered]@{}
            foreach ($e in $z.Entries) { $r = [IO.StreamReader]::new($e.Open()); try { $o[$e.FullName] = $r.ReadToEnd() } finally { $r.Dispose() } }
            $o
        } finally { $z.Dispose() }
    }

    It 'adds the files that exist, scrubbed, and system.txt' {
        $dir = (New-Item 'TestDrive:\in' -ItemType Directory -Force).FullName
        $log = Join-Path $dir 'akari.log'
        Set-Content $log 'Bob saved C:\Users\Bob\x on PC1'
        Set-Content (Join-Path $dir 'state.json') '{"a": true}'
        $zip = Join-Path (Resolve-Path 'TestDrive:\').ProviderPath 'out.zip'
        $r = New-AkariSupportFile $zip @($log, (Join-Path $dir 'state.json'), (Join-Path $dir 'missing.json'), '') @('AkariOS 1', 'PC: PC1') @('Bob') 'PC1'
        $r.Count | Should Be 2
        $e = Read-Zip $zip
        @($e.Keys) -join ',' | Should Be 'akari.log,state.json,system.txt'
        $e['akari.log'].Trim() | Should Be '<user> saved C:\Users\<user>\x on <pc>'
        $e['system.txt'] | Should Be "AkariOS 1`r`nPC: <pc>`r`n"
    }

    It 'replaces a zip already there and reads a file another program holds open' {
        $dir = (New-Item 'TestDrive:\held' -ItemType Directory -Force).FullName
        $log = Join-Path $dir 'akari.log'
        Set-Content $log 'line'
        $zip = Join-Path $dir 'out.zip'
        Set-Content $zip 'old'
        $held = [IO.File]::Open($log, 'Open', 'ReadWrite', 'ReadWrite')
        try { (New-AkariSupportFile $zip @($log) @() @() '').Count | Should Be 1 } finally { $held.Dispose() }
        (Read-Zip $zip)['akari.log'].Trim() | Should Be 'line'
    }
}
