# Install USB: bloatware, AppLocker, custom scripts and extra components, ported from Schneegans' modifier\Bloatware.cs,
# AppLocker.cs, Script.cs and Components.cs (MIT; see Engine.ps1).

# a bloatware item's field: Remove + its token, else its name without spaces
function Get-AkariUaBloatwareId($Item) { if ($Item.Token) { "Remove$($Item.Token)" } else { 'Remove' + $Item.DisplayName.Replace(' ', '') } }

# the three removers: what lists the installed items, picks one by selector, removes it
$AkariUaRemovers = [ordered]@{
    Package    = @{ Step = 'PackageBloatwareStep'
        Get = "{`r`n  Get-AppxProvisionedPackage -Online;`r`n}"
        Filter = "{`r`n  `$_.DisplayName -eq `$selector;`r`n}"
        Remove = "{`r`n  [CmdletBinding()]`r`n  param(`r`n    [Parameter( Mandatory, ValueFromPipeline )]`r`n    `$InputObject`r`n  );`r`n  process {`r`n    `$InputObject | Remove-AppxProvisionedPackage -AllUsers -Online -ErrorAction 'Continue';`r`n  }`r`n}" }
    Capability = @{ Step = 'CapabilityBloatwareStep'
        Get = "{`r`n  Get-WindowsCapability -Online | Where-Object -Property 'State' -NotIn -Value @(`r`n    'NotPresent';`r`n    'Removed';`r`n  );`r`n}"
        Filter = "{`r`n  (`$_.Name -split '~')[0] -eq `$selector;`r`n}"
        Remove = "{`r`n  [CmdletBinding()]`r`n  param(`r`n    [Parameter( Mandatory, ValueFromPipeline )]`r`n    `$InputObject`r`n  );`r`n  process {`r`n    `$InputObject | Remove-WindowsCapability -Online -ErrorAction 'Continue';`r`n  }`r`n}" }
    Feature    = @{ Step = 'OptionalFeatureBloatwareStep'
        Get = "{`r`n  Get-WindowsOptionalFeature -Online | Where-Object -Property 'State' -NotIn -Value @(`r`n    'Disabled';`r`n    'DisabledWithPayloadRemoved';`r`n  );`r`n}"
        Filter = "{`r`n  `$_.FeatureName -eq `$selector;`r`n}"
        Remove = "{`r`n  [CmdletBinding()]`r`n  param(`r`n    [Parameter( Mandatory, ValueFromPipeline )]`r`n    `$InputObject`r`n  );`r`n  process {`r`n    `$InputObject | Disable-WindowsOptionalFeature -Online -Remove -NoRestart -ErrorAction 'Continue';`r`n  }`r`n}" }
}

function Invoke-AkariUaBloatware($C) {
    $selectors = @{ Package = [Collections.Generic.List[string]]::new(); Capability = [Collections.Generic.List[string]]::new(); Feature = [Collections.Generic.List[string]]::new() }
    $sp = $C.Specialize; $du = $C.DefaultUser
    $picked = @(Get-AkariUaList 'Bloatware' | Where-Object { Test-AkariUaOn $C (Get-AkariUaBloatwareId $_) } | Sort-Object { Get-AkariUaBloatwareId $_ })
    foreach ($b in $picked) {
        $id = Get-AkariUaBloatwareId $b
        foreach ($step in $b.Steps) {
            $type = [string]$step.'$type'
            $kind = @($AkariUaRemovers.Keys | Where-Object { $type -like "*.$($AkariUaRemovers[$_].Step),*" })[0]
            if ($kind) { $selectors[$kind].Add($step.Selector); continue }
            switch ($id) {
                'RemoveOneDrive' {
                    $sp.Commands.Add("@(`r`n  'C:\Users\Default\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\OneDrive.lnk';`r`n  'C:\Windows\System32\OneDriveSetup.exe';`r`n  'C:\Windows\SysWOW64\OneDriveSetup.exe';`r`n) | Where-Object -FilterScript { [System.IO.File]::Exists( `$_ ); } | Remove-Item -Verbose -ErrorAction 'Continue';")
                    $du.Commands.Add("Remove-ItemProperty -LiteralPath 'Registry::HKU\DefaultUser\Software\Microsoft\Windows\CurrentVersion\Run' -Name 'OneDriveSetup' -Force -ErrorAction 'Continue';")
                }
                'RemoveTeams' { $sp.Commands.Add('reg.exe add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Communications" /v ConfigureChatAutoInstall /t REG_DWORD /d 0 /f;') }
                'RemoveNotepad' {
                    $sp.Commands.Add(@'
reg.exe add "HKCR\.txt\ShellNew" /v ItemName /t REG_EXPAND_SZ /d "@C:\Windows\system32\notepad.exe,-470" /f;
reg.exe add "HKCR\.txt\ShellNew" /v NullFile /t REG_SZ /f;
reg.exe add "HKCR\txtfilelegacy" /v FriendlyTypeName /t REG_EXPAND_SZ /d "@C:\Windows\system32\notepad.exe,-469" /f;
reg.exe add "HKCR\txtfilelegacy" /ve /t REG_SZ /d "Text Document" /f;
'@)
                    $du.Commands.Add('reg.exe add "HKU\DefaultUser\Software\Microsoft\Notepad" /v ShowStoreBanner /t REG_DWORD /d 0 /f;')
                }
                'RemoveOutlook' { $sp.Commands.Add("Remove-Item -LiteralPath 'Registry::HKLM\Software\Microsoft\WindowsUpdate\Orchestrator\UScheduler_Oobe\OutlookUpdate' -Force -ErrorAction 'SilentlyContinue';") }
                'RemoveDevHome' { $sp.Commands.Add("Remove-Item -LiteralPath 'Registry::HKLM\Software\Microsoft\WindowsUpdate\Orchestrator\UScheduler_Oobe\DevHomeUpdate' -Force -ErrorAction 'SilentlyContinue';") }
                'RemoveCopilot' {
                    $C.UserOnce.Commands.Add("Get-AppxPackage -Name 'Microsoft.Windows.Ai.Copilot.Provider' | Remove-AppxPackage;")
                    $du.Commands.Add('reg.exe add "HKU\DefaultUser\Software\Policies\Microsoft\Windows\WindowsCopilot" /v TurnOffWindowsCopilot /t REG_DWORD /d 1 /f;')
                }
                'RemoveXboxApps' { $du.Commands.Add('reg.exe add "HKU\DefaultUser\Software\Microsoft\Windows\CurrentVersion\GameDVR" /v AppCaptureEnabled /t REG_DWORD /d 0 /f;') }
                'RemoveInternetExplorer' { $du.Commands.Add('reg.exe add "HKU\DefaultUser\Software\Microsoft\Internet Explorer\LowRegistry\Audio\PolicyConfig\PropertyStore" /f;') }
                default { throw "Bloatware step of '$id' is not supported." }
            }
        }
    }
    foreach ($kind in $AkariUaRemovers.Keys) {
        if (-not $selectors[$kind].Count) { continue }
        $r = $AkariUaRemovers[$kind]
        $text = "`$selectors = @(`r`n" + (-join ($selectors[$kind] | ForEach-Object { "`t'$_';`r`n" })) + ");`r`n" +
            "`$getCommand = $($r.Get);`r`n`$filterCommand = $($r.Filter);`r`n`$removeCommand = $($r.Remove);`r`n`$type = '$kind';`r`n" + (Get-AkariUaResource 'RemoveBloatware.ps1')
        Add-AkariUaInvoke $sp (Add-AkariUaTextFile $C "Remove$kind.ps1" $text)
    }
}

function Invoke-AkariUaAppLocker($C) {
    if ((Get-AkariUaField $C 'AppLockerMode' 'Skip') -ne 'Configure') { return }
    $policy = [xml]::new()
    try {
        $policy.LoadXml((Get-AkariUaField $C 'AppLockerPolicyXml'))
        $policy.Schemas.Add($null, (Join-Path $AkariUaData 'AppLocker.xsd')) | Out-Null
        $policy.Validate($null)
    } catch { throw "AppLocker policy XML is invalid: $($_.Exception.InnerException.Message)" }
    $file = Add-AkariUaXmlFile $C 'AppLockerPolicy.xml' $policy
    $C.Specialize.Commands.Add("Get-Service -Name 'AppIDSvc' | Set-Service -StartupType 'Automatic';`r`nGet-Service -Name 'AppIDSvc' | Start-Service;`r`nSet-AppLockerPolicy -XmlPolicy '$file';")
}

# the custom scripts in his order (System, FirstLogon, UserOnce, DefaultUser; rows 0-14 with text), numbered unattend-01...
function Invoke-AkariUaScript($C) {
    if (Test-AkariUaOn $C 'RestartExplorer') { $C.UserOnce.Restart = $true }
    $index = 0
    foreach ($phase in 'System', 'FirstLogon', 'UserOnce', 'DefaultUser') {
        $seq = switch ($phase) { 'System' { $C.Specialize } 'FirstLogon' { $C.FirstLogon } 'UserOnce' { $C.UserOnce } 'DefaultUser' { $C.DefaultUser } }
        foreach ($i in 0..14) {
            $content = Get-AkariUaField $C "$($phase)Script$i"
            if ([string]::IsNullOrWhiteSpace($content)) { continue }
            $type = Get-AkariUaField $C "$($phase)ScriptType$i" 'Cmd'
            if ($phase -eq 'DefaultUser' -and $type -eq 'Vbs') { throw "Scripts in phase 'DefaultUser' must not have type 'Vbs'." }
            $index++
            $name = 'unattend-{0:x2}.{1}' -f $index, $type.ToLowerInvariant()
            $path = "C:\Windows\Setup\Scripts\$name"
            if ($type -eq 'Reg' -and -not $content.StartsWith('Windows Registry Editor Version 5.00')) { $content = "Windows Registry Editor Version 5.00`r`n`r`n$content" }
            [void](Add-AkariUaTextFile $C $name $content)
            switch ($type) {
                'Ps1' { Add-AkariUaInvoke $seq $path }
                'Reg' { $seq.Commands.Add((Get-AkariUaReg "import `"$path`"") + ';') }
                'Vbs' { $seq.Commands.Add((Get-AkariUaVBScript $path) + ';') }
                default { $seq.Commands.Add("$path;") }
            }
        }
    }
}

# the extra components: Component<i> = '<component>-<pass>', ComponentContent<i> = its XML (replaces an existing one's)
function Get-AkariUaUserComponents($C) {
    @(foreach ($i in 0..14) {
        $v = Get-AkariUaField $C "Component$i"
        if (-not $v) { continue }
        $cut = $v.LastIndexOf('-')
        @{ Component = $v.Substring(0, $cut); Pass = $v.Substring($cut + 1); Xml = Get-AkariUaField $C "ComponentContent$i" }
    })
}

function Invoke-AkariUaComponents($C) {
    $C.UserComponents = [Collections.Generic.List[object]]::new()
    foreach ($item in Get-AkariUaUserComponents $C) {
        $setting = Select-AkariUaNode $C.Doc "/u:unattend/u:settings[@pass='$($item.Pass)']" $C.Ns
        $comp = $setting.SelectSingleNode("u:component[@name='$($item.Component)']", $C.Ns)
        if (-not $comp) {
            $comp = $C.Doc.CreateElement('component', $C.Ns.LookupNamespace('u'))
            $comp.SetAttribute('name', $item.Component)
            $comp.SetAttribute('processorArchitecture', 'x86')
            $comp.SetAttribute('publicKeyToken', '31bf3856ad364e35')
            $comp.SetAttribute('language', 'neutral')
            $comp.SetAttribute('versionScope', 'nonSxS')
        } else { $comp.InnerXml = '' }
        $new = [xml]::new()
        try { $new.LoadXml("<root xmlns='urn:schemas-microsoft-com:unattend' xmlns:wcm='http://schemas.microsoft.com/WMIConfig/2002/State'>$($item.Xml)</root>") }
        catch { throw "Your XML markup '$($item.Xml)' is not well-formed." }
        if ($new.DocumentElement.SelectNodes("//*[local-name()='settings' or local-name()='component']").Count) {
            throw "You must not include elements 'settings' or 'component' with your XML markup '$($item.Xml)'."
        }
        foreach ($n in @($new.DocumentElement.ChildNodes)) { [void]$comp.AppendChild($C.Doc.ImportNode($n, $true)) }
        # (appended again: an existing component moves to the end of its pass, as in his code)
        [void]$setting.AppendChild($comp)
        $C.UserComponents.Add($comp)
    }
}
