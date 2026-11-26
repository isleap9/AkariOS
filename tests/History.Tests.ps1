$Root = Join-Path (Split-Path $PSScriptRoot) 'src'
$Core = Join-Path $Root 'Core'

# Run history and Undo (X4): which Tweaks Undo puts back exactly, a record written by a Run, the values put back as they
# were (every kind, missing ones removed), the plan's three lists. Rows under a test key, files under TestDrive:
Describe 'Run history and Undo' {
    $AkariStatePath = "$TestDrive\state.json"
    foreach ($f in 'Log', 'Registry', 'Loader', 'State', 'Runner', 'System', 'History') { . "$Core\$f.ps1" }
    $LogQueue = [Collections.Concurrent.ConcurrentQueue[string]]::new()
    $AkariTestKey = "HKCU:\Software\AkariTest\$([guid]::NewGuid())"
    $AkariExpectedPath = "$TestDrive\expected.json"
    function Restart-AkariExplorer { $script:ExplorerRestarts++ }
    $rows = @(
        @{ Path = $AkariTestKey; Name = 'Dw'; Type = 'DWord'; Value = 0; Default = 1 }
        @{ Path = $AkariTestKey; Name = 'Str'; Type = 'String'; Value = 'on'; Default = $null }
        @{ Path = $AkariTestKey; Name = 'Exp'; Type = 'ExpandString'; Value = '%TEMP%\on'; Default = $null }
        @{ Path = $AkariTestKey; Name = 'Bin'; Type = 'Binary'; Value = '01,02'; Default = $null }
        @{ Path = $AkariTestKey; Name = 'Multi'; Type = 'MultiString'; Value = @('x'); Default = $null }
        @{ Path = "$AkariTestKey\Sub"; Name = 'Missing'; Type = 'DWord'; Value = 1; Default = $null }
    )
    $tog = ConvertTo-AkariTweak @{ Id = 'undo-tog'; Name = 'Rows'; Explorer = $true; Registry = $rows } 'x' $false
    $code = ConvertTo-AkariTweak @{ Id = 'undo-code'; Name = 'Code'; Apply = { }; Revert = { $script:CodeReverts++ } } 'x' $false
    $act = ConvertTo-AkariTweak @{ Id = 'undo-act'; Name = 'Act'; Kind = 'Action'; Apply = { } } 'x' $false
    $keyRow = ConvertTo-AkariTweak @{ Id = 'undo-key'; Name = 'Key'; Registry = @(@{ Path = "$AkariTestKey\K"; Value = $null; Default = 'Key' }) } 'x' $false
    $all = @($tog, $code, $act, $keyRow)

    try {
        It 'puts back exactly only Toggles and Choices of value rows, with no code' {
            Test-AkariUndoable $tog | Should Be $true
            Test-AkariUndoable $code | Should Be $false
            Test-AkariUndoable $act | Should Be $false
            Test-AkariUndoable $keyRow | Should Be $false
            Test-AkariUndoable (ConvertTo-AkariTweak @{ Id = 'a'; Name = 'A'; SafeMode = $true; Registry = $rows } 'x' $false) | Should Be $false
            Test-AkariUndoable (ConvertTo-AkariTweak @{ Id = 'b'; Name = 'B'; Registry = $rows; After = { } } 'x' $false) | Should Be $false
        }

        It 'keeps no history without a folder' {
            $AkariHistoryDir = $null
            New-AkariHistory 'x' | Should Be ''
            Get-AkariLastHistory | Should Be $null
        }

        $AkariHistoryDir = "$TestDrive\history"

        It 'keeps the newest 10 records' {
            $AkariHistoryKeep = 3
            foreach ($m in 1..5) { [void](New-AkariHistory "Run $m" ([datetime]::new(2026, 1, $m))) }
            @([IO.Directory]::GetFiles($AkariHistoryDir)).Count | Should Be 3
            (Get-AkariLastHistory).Name | Should Be 'Run 5'
            Remove-Item $AkariHistoryDir -Recurse -Force
        }

        It 'records the values before a Run and puts them back as they were' {
            Set-Reg $AkariTestKey 'Dw' ([uint32]4000000000) 'DWord'
            Set-Reg $AkariTestKey 'Str' 'mine' 'String'
            Set-Reg $AkariTestKey 'Exp' '%USERPROFILE%\mine' 'ExpandString'
            Set-Reg $AkariTestKey 'Bin' ([byte[]](255, 0)) 'Binary'
            Set-Reg $AkariTestKey 'Multi' ([string[]]('a', 'b')) 'MultiString'
            $AkariHistoryFile = New-AkariHistory 'Guided run'
            $out = @(Invoke-AkariPlan @(@{ Id = 'undo-tog'; Mode = 'Apply' }, @{ Id = 'undo-code'; Mode = 'Apply' }, @{ Id = 'undo-act'; Mode = 'Apply' }) $all)
            Add-AkariHistoryOutcomes $AkariHistoryFile $out
            ($out | ForEach-Object { $_.Outcome }) -join ',' | Should Be 'Applied,Applied,Applied'
            Get-AkariRegValue $AkariTestKey 'Str' | Should Be 'on'
            (Get-AkariExpected).ContainsKey('undo-tog') | Should Be $true

            $r = Get-AkariLastHistory
            $r.Name | Should Be 'Guided run'
            @($r.Before.Keys) -join ',' | Should Be 'undo-tog'
            ($r.Outcomes | ForEach-Object { "$($_.Id):$($_.Outcome)" }) -join ',' | Should Be 'undo-tog:Applied,undo-code:Applied,undo-act:Applied'
            $p = Get-AkariUndoPlan $r $all
            "$(@($p.Exact) -join ',')|$(@($p.Default) -join ',')|$(@($p.Never) -join ',')" | Should Be 'undo-tog|undo-code|undo-act'

            $script:CodeReverts = 0; $script:ExplorerRestarts = 0
            $u = @(Invoke-AkariUndo $r $all)
            ($u | ForEach-Object { "$($_.Id):$($_.Outcome)" }) -join ',' | Should Be 'undo-code:Reverted,undo-tog:Reverted'
            $script:CodeReverts | Should Be 1
            $script:ExplorerRestarts | Should Be 1
            Get-AkariRegValue $AkariTestKey 'Dw' | Should Be 4000000000
            Get-AkariRegValue $AkariTestKey 'Str' | Should Be 'mine'
            $k = Get-Item -LiteralPath (Resolve-AkariRegPath $AkariTestKey)
            $k.GetValue('Exp', $null, 'DoNotExpandEnvironmentNames') | Should Be '%USERPROFILE%\mine'
            "$($k.GetValueKind('Exp'))" | Should Be 'ExpandString'
            (Get-AkariRegValue $AkariTestKey 'Bin') -join ',' | Should Be '255,0'
            (Get-AkariRegValue $AkariTestKey 'Multi') -join ',' | Should Be 'a,b'
            Get-AkariRegValue "$AkariTestKey\Sub" 'Missing' | Should Be $null
            # the user's own value now: the drift check leaves it alone
            (Get-AkariExpected).ContainsKey('undo-tog') | Should Be $false
        }

        It 'reads a Tweak''s rows once per record (its first step)' {
            $h = New-AkariHistory 'Twice'
            Set-Reg $AkariTestKey 'Str' 'first' 'String'
            Add-AkariHistoryBefore $h $tog
            Set-Reg $AkariTestKey 'Str' 'second' 'String'
            Add-AkariHistoryBefore $h $tog
            Add-AkariHistoryBefore $h $code
            $r = Read-AkariHistory $h
            @($r.Before.Keys) -join ',' | Should Be 'undo-tog'
            (@($r.Before['undo-tog']) | Where-Object { $_.Name -eq 'Str' }).Data | Should Be 'first'
        }

        It 'plans by each id''s last change: a Revert of code can''t be undone, unknown ids neither' {
            $rec = @{ Before = @{ 'undo-tog' = @() }; Outcomes = @(
                @{ Id = 'undo-tog'; Mode = 'Apply'; Outcome = 'Already' }
                @{ Id = 'undo-code'; Mode = 'Revert'; Outcome = 'Reverted' }
                @{ Id = 'gone'; Mode = 'Apply'; Outcome = 'Applied' }
                @{ Id = 'undo-act'; Mode = 'Apply'; Outcome = 'Failed' }
            ) }
            $p = Get-AkariUndoPlan $rec $all
            "$(@($p.Exact) -join ',')|$(@($p.Default) -join ',')|$(@($p.Never) -join ',')" | Should Be '||undo-code,gone'
        }
    } finally {
        Remove-Item -LiteralPath (Resolve-AkariRegPath $AkariTestKey) -Recurse -Force -ErrorAction SilentlyContinue
    }
}
