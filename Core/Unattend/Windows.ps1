# Install USB: his Windows settings, ported from Schneegans' modifier\Optimizations.cs and Personalization.cs (MIT;
# see Engine.ps1), in his order: taskbar icons, Explorer, system tweaks, VM tools, lock keys, Edge, search, Start pins
# and tiles, visual effects, desktop icons, Start folders, sticky keys, core isolation; colors, wallpaper, lock screen.

$AkariUaEffects = 'ControlAnimations', 'AnimateMinMax', 'TaskbarAnimations', 'DWMAeroPeekEnabled', 'MenuAnimation', 'TooltipAnimation', 'SelectionFade',
    'DWMSaveThumbnailEnabled', 'CursorShadow', 'ListviewShadow', 'ThumbnailsOrIcon', 'ListviewAlphaSelect', 'DragFullWindows', 'ComboBoxAnimation',
    'FontSmoothing', 'ListBoxSmoothScrolling', 'DropShadow'
$AkariUaStickyFlags = [ordered]@{ HotKeyActive = 0x4; Indicator = 0x20; TriState = 0x80; TwoKeysOff = 0x100; AudibleFeedback = 0x40; HotKeySound = 0x10 }
$AkariUaSearchModes = @{ Hide = 0; Icon = 1; Box = 2; Label = 3 }

function Test-AkariUaDefenderOff($C) { $C.PEMode -eq 'Generated' -and (Test-AkariUaOn $C 'DisableDefender') }

# ColorTranslator.ToHtml for a #RRGGBB color
function ConvertTo-AkariUaHtmlColor([string]$Color) {
    if ($Color -notmatch '^#?([0-9A-Fa-f]{6})$') { throw "'$Color' is not a color." }
    "#$($Matches[1].ToUpperInvariant())"
}

function Invoke-AkariUaOptimizations($C) {
    $sp = $C.Specialize; $du = $C.DefaultUser; $uo = $C.UserOnce; $fl = $C.FirstLogon
    $adv = 'reg.exe add "HKU\DefaultUser\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"'

    # taskbar icons: a locked layout file, unlocked again at each user's first sign-in
    $taskbar = switch (Get-AkariUaField $C 'TaskbarIconsMode' 'Default') {
        'Empty' {
            '<LayoutModificationTemplate xmlns="http://schemas.microsoft.com/Start/2014/LayoutModification" xmlns:defaultlayout="http://schemas.microsoft.com/Start/2014/FullDefaultLayout" xmlns:start="http://schemas.microsoft.com/Start/2014/StartLayout" xmlns:taskbar="http://schemas.microsoft.com/Start/2014/TaskbarLayout" Version="1"><CustomTaskbarLayoutCollection PinListPlacement="Replace"><defaultlayout:TaskbarLayout><taskbar:TaskbarPinList><taskbar:DesktopApp DesktopApplicationLinkPath="#leaveempty" /></taskbar:TaskbarPinList></defaultlayout:TaskbarLayout></CustomTaskbarLayoutCollection></LayoutModificationTemplate>'
        }
        'Custom' { Get-AkariUaField $C 'TaskbarIconsXml' }
    }
    if ($taskbar) {
        $doc = [xml]::new()
        try { $doc.LoadXml($taskbar) } catch { throw "Taskbar XML is not well-formed: $($_.Exception.InnerException.Message)" }
        $path = Add-AkariUaXmlFile $C 'TaskbarLayoutModification.xml' $doc
        $sp.Commands.Add("reg.exe add `"HKLM\Software\Policies\Microsoft\Windows\CloudContent`" /v `"DisableCloudOptimizedContent`" /t REG_DWORD /d 1 /f;`r`n[System.Diagnostics.EventLog]::CreateEventSource( 'UnattendGenerator', 'Application' );")
        $du.Commands.Add("reg.exe add `"HKU\DefaultUser\Software\Policies\Microsoft\Windows\Explorer`" /v `"StartLayoutFile`" /t REG_SZ /d `"$path`" /f;`r`nreg.exe add `"HKU\DefaultUser\Software\Policies\Microsoft\Windows\Explorer`" /v `"LockedStartLayout`" /t REG_DWORD /d 1 /f;")
        [void](Add-AkariUaResourceFile $C 'UnlockStartLayout.vbs')
        $sp.Commands.Add("Register-ScheduledTask -TaskName 'UnlockStartLayout' -Xml `$( Get-Content -LiteralPath '$(Add-AkariUaResourceXml $C 'UnlockStartLayout.xml')' -Raw );")
        $uo.Commands.Add('[System.Diagnostics.EventLog]::WriteEntry( ''UnattendGenerator'', "User ''$env:USERNAME'' has requested to unlock the Start menu layout.", [System.Diagnostics.EventLogEntryType]::Information, 1 );')
    }
    if (Test-AkariUaOn $C 'ShowFileExtensions') { $du.Commands.Add("$adv /v `"HideFileExt`" /t REG_DWORD /d 0 /f;") }
    switch (Get-AkariUaField $C 'HideFiles' 'Hidden') {
        'None' { $du.Commands.Add("$adv /v `"Hidden`" /t REG_DWORD /d 1 /f;"); $du.Commands.Add("$adv /v `"ShowSuperHidden`" /t REG_DWORD /d 1 /f;") }
        'HiddenSystem' { $du.Commands.Add("$adv /v `"Hidden`" /t REG_DWORD /d 1 /f;") }
    }
    if (Test-AkariUaOn $C 'DisableWindowsUpdate') { $sp.Commands.Add("Register-ScheduledTask -TaskName 'PauseWindowsUpdate' -Xml `$( Get-Content -LiteralPath '$(Add-AkariUaResourceXml $C 'PauseWindowsUpdate.xml')' -Raw );") }
    if (Test-AkariUaOn $C 'ShowAllTrayIcons') { $du.Commands.Add((Get-AkariUaResource 'ShowAllTrayIcons.ps1')); [void](Add-AkariUaResourceXml $C 'ShowAllTrayIcons.xml') }
    if (Test-AkariUaOn $C 'HideTaskViewButton') { $du.Commands.Add("$adv /v ShowTaskViewButton /t REG_DWORD /d 0 /f;") }
    if (Test-AkariUaDefenderOff $C) { $sp.Commands.Add('reg.exe add "HKLM\SOFTWARE\Policies\Microsoft\Windows Defender Security Center\Notifications" /v DisableNotifications /t REG_DWORD /d 1 /f;') }
    if (Test-AkariUaOn $C 'DisableSac') { $sp.Commands.Add('reg.exe add "HKLM\SYSTEM\CurrentControlSet\Control\CI\Policy" /v VerifiedAndReputablePolicyState /t REG_DWORD /d 0 /f;') }
    if (Test-AkariUaOn $C 'DisableSmartScreen') {
        $sp.Commands.Add(@'
reg.exe add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer" /v SmartScreenEnabled /t REG_SZ /d "Off" /f;
reg.exe add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\WTDS\Components" /v ServiceEnabled /t REG_DWORD /d 0 /f;
reg.exe add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\WTDS\Components" /v NotifyMalicious /t REG_DWORD /d 0 /f;
reg.exe add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\WTDS\Components" /v NotifyPasswordReuse /t REG_DWORD /d 0 /f;
reg.exe add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\WTDS\Components" /v NotifyUnsafeApp /t REG_DWORD /d 0 /f;
reg.exe add "HKLM\SOFTWARE\Policies\Microsoft\Windows Defender Security Center\Systray" /v HideSystray /t REG_DWORD /d 1 /f;
'@)
        $du.Commands.Add(@'
reg.exe add "HKU\DefaultUser\Software\Microsoft\Edge\SmartScreenEnabled" /ve /t REG_DWORD /d 0 /f;
reg.exe add "HKU\DefaultUser\Software\Microsoft\Edge\SmartScreenPuaEnabled" /ve /t REG_DWORD /d 0 /f;
reg.exe add "HKU\DefaultUser\Software\Microsoft\Windows\CurrentVersion\AppHost" /v EnableWebContentEvaluation /t REG_DWORD /d 0 /f;
reg.exe add "HKU\DefaultUser\Software\Microsoft\Windows\CurrentVersion\AppHost" /v PreventOverride /t REG_DWORD /d 0 /f;
'@)
    }
    if (Test-AkariUaOn $C 'DisableUac') { $sp.Commands.Add('reg.exe add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" /v EnableLUA /t REG_DWORD /d 0 /f') }
    if (Test-AkariUaOn $C 'EnableLongPaths') { $sp.Commands.Add('reg.exe add "HKLM\SYSTEM\CurrentControlSet\Control\FileSystem" /v LongPathsEnabled /t REG_DWORD /d 1 /f') }
    if (Test-AkariUaOn $C 'EnableRemoteDesktop') { $sp.Commands.Add("netsh.exe advfirewall firewall set rule group=`"@FirewallAPI.dll,-28752`" new enable=Yes;`r`nreg.exe add `"HKLM\SYSTEM\CurrentControlSet\Control\Terminal Server`" /v fDenyTSConnections /t REG_DWORD /d 0 /f;") }
    if (Test-AkariUaOn $C 'HardenSystemDriveAcl') { $sp.Commands.Add('icacls.exe C:\ /remove:g "*S-1-5-11"') }
    if (Test-AkariUaOn $C 'DeleteJunctions') {
        $fl.Commands.Add("@(`r`n`tGet-ChildItem -LiteralPath 'C:\' -Force;`r`n`tGet-ChildItem -LiteralPath 'C:\Users' -Force;`r`n`tGet-ChildItem -LiteralPath 'C:\Users\Default' -Force -Recurse -Depth 2;`r`n`tGet-ChildItem -LiteralPath 'C:\Users\Public' -Force -Recurse -Depth 2;`r`n`tGet-ChildItem -LiteralPath 'C:\ProgramData' -Force;`r`n) | Where-Object -FilterScript {`r`n`t`$_.Attributes.HasFlag( [System.IO.FileAttributes]::ReparsePoint );`r`n} | Remove-Item -Force -Recurse -Verbose;")
        $uo.Commands.Add("@(`r`n  Get-ChildItem -LiteralPath `$env:USERPROFILE -Force -Recurse -Depth 2;`r`n) | Where-Object -FilterScript {`r`n`t`$_.Attributes.HasFlag( [System.IO.FileAttributes]::ReparsePoint );`r`n} | Remove-Item -Force -Recurse -Verbose;")
    }
    if (Test-AkariUaOn $C 'DeleteEdgeDesktopIcon') {
        $sp.Commands.Add("Remove-Item -LiteralPath 'C:\Users\Public\Desktop\Microsoft Edge.lnk' -ErrorAction 'SilentlyContinue' -Verbose;")
        $uo.Commands.Add('Remove-Item -LiteralPath "${env:USERPROFILE}\Desktop\Microsoft Edge.lnk" -ErrorAction ''SilentlyContinue'' -Verbose;')
    }
    if (Test-AkariUaOn $C 'ProcessAudit') {
        $sp.Commands.Add('auditpol.exe /set /subcategory:"{0CCE922B-69AE-11D9-BED3-505054503030}" /success:enable /failure:enable;')
        if (Test-AkariUaOn $C 'ProcessAuditCommandLine') { $sp.Commands.Add('reg.exe add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System\Audit" /v ProcessCreationIncludeCmdLine_Enabled /t REG_DWORD /d 1 /f;') }
    }
    if (Test-AkariUaOn $C 'AllowPowerShellScripts') { $sp.Commands.Add("Set-ExecutionPolicy -Scope 'LocalMachine' -ExecutionPolicy 'RemoteSigned' -Force;") }
    if (Test-AkariUaOn $C 'DisableLastAccess') { $sp.Commands.Add('fsutil.exe behavior set disableLastAccess 1;') }
    if (Test-AkariUaOn $C 'PreventAutomaticReboot') {
        $sp.Commands.Add("reg.exe add `"HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU`" /v AUOptions /t REG_DWORD /d 4 /f;`r`nreg.exe add `"HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU`" /v NoAutoRebootWithLoggedOnUsers /t REG_DWORD /d 1 /f;")
        $sp.Commands.Add("Register-ScheduledTask -TaskName 'MoveActiveHours' -Xml `$( Get-Content -LiteralPath '$(Add-AkariUaResourceXml $C 'MoveActiveHours.xml')' -Raw );")
    }
    if (Test-AkariUaOn $C 'DisableFastStartup') { $sp.Commands.Add('reg.exe add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Power" /v HiberbootEnabled /t REG_DWORD /d 0 /f;') }
    if (Test-AkariUaOn $C 'DisableSystemRestore') { $fl.Commands.Add("Disable-ComputerRestore -Drive 'C:\';") }
    if (Test-AkariUaOn $C 'DisableWidgets') { $sp.Commands.Add('reg.exe add "HKLM\SOFTWARE\Policies\Microsoft\Dsh" /v AllowNewsAndInterests /t REG_DWORD /d 0 /f;') }
    if (Test-AkariUaOn $C 'TurnOffSystemSounds') {
        Add-AkariUaInvoke $du (Add-AkariUaResourceFile $C 'TurnOffSystemSounds.ps1')
        $uo.Commands.Add("Set-ItemProperty -LiteralPath 'Registry::HKCU\AppEvents\Schemes' -Name '(Default)' -Type 'String' -Value '.None';")
        $sp.Commands.Add("reg.exe add `"HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Authentication\LogonUI\BootAnimation`" /v DisableStartupSound /t REG_DWORD /d 1 /f;`r`nreg.exe add `"HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\EditionOverrides`" /v UserSetting_DisableStartupSound /t REG_DWORD /d 1 /f;")
    }
    if (Test-AkariUaOn $C 'DisableAppSuggestions') {
        $du.Commands.Add(@'
$names = @(
  'ContentDeliveryAllowed';
  'FeatureManagementEnabled';
  'OEMPreInstalledAppsEnabled';
  'PreInstalledAppsEnabled';
  'PreInstalledAppsEverEnabled';
  'SilentInstalledAppsEnabled';
  'SoftLandingEnabled';
  'SubscribedContentEnabled';
  'SubscribedContent-310093Enabled';
  'SubscribedContent-338387Enabled';
  'SubscribedContent-338388Enabled';
  'SubscribedContent-338389Enabled';
  'SubscribedContent-338393Enabled';
  'SubscribedContent-353694Enabled';
  'SubscribedContent-353696Enabled';
  'SubscribedContent-353698Enabled';
  'SystemPaneSuggestionsEnabled';
);

foreach( $name in $names ) {
  reg.exe add "HKU\DefaultUser\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v $name /t REG_DWORD /d 0 /f;
}
'@)
        $sp.Commands.Add('reg.exe add "HKLM\Software\Policies\Microsoft\Windows\CloudContent" /v "DisableWindowsConsumerFeatures" /t REG_DWORD /d 1 /f;')
    }
    # VM guest tools: at the first sign-in, or in specialize when Defender is off (VirtIO always at the first sign-in)
    foreach ($vm in @(@('VBoxGuestAdditions', $false), @('VMwareTools', $false), @('VirtIoGuestTools', $true), @('ParallelsTools', $false))) {
        if (-not (Test-AkariUaOn $C $vm[0])) { continue }
        $target = if ($vm[1]) { $fl } elseif (Test-AkariUaDefenderOff $C) { $sp } else { $fl }
        Add-AkariUaInvoke $target (Add-AkariUaResourceFile $C "$($vm[0]).ps1")
    }
    if (Test-AkariUaOn $C 'PreventDeviceEncryption') { $sp.Commands.Add('reg.exe add "HKLM\SYSTEM\CurrentControlSet\Control\BitLocker" /v "PreventDeviceEncryption" /t REG_DWORD /d 1 /f;') }
    if (Test-AkariUaOn $C 'ClassicContextMenu') { $uo.Commands.Add('reg.exe add "HKCU\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32" /ve /f;'); $uo.Restart = $true }
    if (Test-AkariUaOn $C 'LeftTaskbar') { $du.Commands.Add("$adv /v TaskbarAl /t REG_DWORD /d 0 /f;") }
    if (Test-AkariUaOn $C 'HideEdgeFre') { $sp.Commands.Add('reg.exe add "HKLM\Software\Policies\Microsoft\Edge" /v HideFirstRunExperience /t REG_DWORD /d 1 /f;') }
    if (Test-AkariUaOn $C 'DisableEdgeStartupBoost') {
        $sp.Commands.Add("reg.exe add `"HKLM\Software\Policies\Microsoft\Edge\Recommended`" /v BackgroundModeEnabled /t REG_DWORD /d 0 /f;`r`nreg.exe add `"HKLM\Software\Policies\Microsoft\Edge\Recommended`" /v StartupBoostEnabled /t REG_DWORD /d 0 /f;")
    }
    if ((Get-AkariUaField $C 'LockKeysMode' 'Skip') -eq 'Configure') {
        $keys = @(@('CapsLock', 1, 0x3A), @('NumLock', 2, 0x45), @('ScrollLock', 4, 0x46))
        $indicators = 0
        foreach ($k in $keys) { if ((Get-AkariUaField $C "$($k[0])Initial" 'Off') -eq 'On') { $indicators = $indicators -bor $k[1] } }
        $du.Commands.Add("foreach( `$root in 'Registry::HKU\.DEFAULT', 'Registry::HKU\DefaultUser' ) {`r`n  Set-ItemProperty -LiteralPath `"`$root\Control Panel\Keyboard`" -Name 'InitialKeyboardIndicators' -Type 'String' -Value $indicators -Force;`r`n}")
        $ignored = @($keys | Where-Object { (Get-AkariUaField $C "$($_[0])Behavior" 'Toggle') -eq 'Ignore' })
        if ($ignored.Count) {
            # a Scancode Map: version, flags, count (entries + 1), the keys mapped to nothing, a zero footer
            $bytes = [Collections.Generic.List[byte]]::new()
            $bytes.AddRange([byte[]]::new(8))
            $bytes.AddRange([BitConverter]::GetBytes([uint32]($ignored.Count + 1)))
            foreach ($k in $ignored) { $bytes.AddRange([byte[]]@(0, 0, $k[2], 0)) }
            $bytes.AddRange([byte[]]::new(4))
            $sp.Commands.Add("Set-ItemProperty -LiteralPath 'Registry::HKLM\SYSTEM\CurrentControlSet\Control\Keyboard Layout' -Name 'Scancode Map' -Type 'Binary' -Value([convert]::FromBase64String('$([Convert]::ToBase64String($bytes.ToArray()))'));")
        }
    }
    if (Test-AkariUaOn $C 'MakeEdgeUninstallable') { Add-AkariUaInvoke $sp (Add-AkariUaResourceFile $C 'MakeEdgeUninstallable.ps1') }
    if (Test-AkariUaOn $C 'LaunchToThisPC') { $uo.Commands.Add("Set-ItemProperty -LiteralPath 'Registry::HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' -Name 'LaunchTo' -Type 'DWord' -Value 1;") }
    $search = Get-AkariUaField $C 'TaskbarSearch' 'Box'
    if ($search -ne 'Box') {
        $uo.Commands.Add("Set-ItemProperty -LiteralPath 'Registry::HKCU\Software\Microsoft\Windows\CurrentVersion\Search' -Name 'SearchboxTaskbarMode' -Type 'DWord' -Value $($AkariUaSearchModes[$search]);")
        $uo.Restart = $true
    }
    $pins = switch (Get-AkariUaField $C 'StartPinsMode' 'Default') {
        'Empty' { '{"pinnedList":[]}' }
        'Custom' {
            $j = Get-AkariUaField $C 'StartPinsJson'
            try { [void](ConvertFrom-Json $j) } catch { throw "The string '$j' is not valid JSON." }
            $j.Trim()
        }
    }
    if ($pins) { Add-AkariUaInvoke $sp (Add-AkariUaResourceFile $C 'SetStartPins.ps1' "`$json = '$($pins.Replace("'", "''"))';`r`n") }
    $tiles = switch (Get-AkariUaField $C 'StartTilesMode' 'Default') {
        'Empty' { "<LayoutModificationTemplate Version='1' xmlns='http://schemas.microsoft.com/Start/2014/LayoutModification'><LayoutOptions StartTileGroupCellWidth='6' /><DefaultLayoutOverride><StartLayoutCollection><StartLayout GroupCellWidth='6' xmlns='http://schemas.microsoft.com/Start/2014/FullDefaultLayout' /></StartLayoutCollection></DefaultLayoutOverride></LayoutModificationTemplate>" }
        'Custom' { Get-AkariUaField $C 'StartTilesXml' }
    }
    if ($tiles) {
        $doc = [xml]::new()
        try { $doc.LoadXml($tiles) } catch { throw "Start menu XML is not well-formed: $($_.Exception.InnerException.Message)" }
        [void](Add-AkariUaXmlFile $C 'C:\Users\Default\AppData\Local\Microsoft\Windows\Shell\LayoutModification.xml' $doc)
    }
    if (Test-AkariUaOn $C 'DeleteWindowsOld') { $fl.Commands.Add((Get-AkariUaShell 'rmdir C:\Windows.old') + ';') }
    if (Test-AkariUaOn $C 'DisablePointerPrecision') {
        $du.Commands.Add(@'
$params = @{
  LiteralPath = 'Registry::HKU\DefaultUser\Control Panel\Mouse';
  Type = 'String';
  Value = 0;
  Force = $true;
};
Set-ItemProperty @params -Name 'MouseSpeed';
Set-ItemProperty @params -Name 'MouseThreshold1';
Set-ItemProperty @params -Name 'MouseThreshold2';
'@)
    }
    if (Test-AkariUaOn $C 'DisableBingResults') { $du.Commands.Add('reg.exe add "HKU\DefaultUser\Software\Policies\Microsoft\Windows\Explorer" /v DisableSearchBoxSuggestions /t REG_DWORD /d 1 /f;') }
    # visual effects: every effect's default for new users, then the user's setting (1 appearance, 2 performance, 3 custom)
    $mode = Get-AkariUaField $C 'EffectsMode' 'Default'
    if ($mode -ne 'Default') {
        $setting = switch ($mode) { 'Appearance' { 1 } 'Performance' { 2 } default { 3 } }
        $lines = foreach ($e in $AkariUaEffects) {
            $on = switch ($mode) { 'Appearance' { $true } 'Performance' { $false } default { Test-AkariUaOn $C $e } }
            "Set-ItemProperty -LiteralPath `"Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects\$e`" -Name 'DefaultValue' -Value $(if ($on) { 1 } else { 0 }) -Type 'DWord' -Force;`r`n"
        }
        $sp.Commands.Add(-join $lines)
        $uo.Commands.Add("Set-ItemProperty -LiteralPath 'Registry::HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects' -Name 'VisualFXSetting' -Type 'DWord' -Value $setting -Force;")
    }
    if ((Get-AkariUaField $C 'DesktopIconsMode' 'Default') -eq 'Custom') {
        $icons = @(Get-AkariUaList 'DesktopIcon' | Sort-Object Id)
        $text = foreach ($key in 'ClassicStartMenu', 'NewStartPanel') {
            $path = "Registry::HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\HideDesktopIcons\$key"
            "New-Item -Path '$path' -Force;`r`n"
            foreach ($i in $icons) { "Set-ItemProperty -Path '$path' -Name '$($i.Guid)' -Value $(if (Test-AkariUaOn $C "Icon$($i.Id)") { 0 } else { 1 }) -Type 'DWord';`r`n" }
        }
        $uo.Commands.Add(-join $text)
        $uo.Restart = $true
    }
    if ((Get-AkariUaField $C 'StartFoldersMode' 'Default') -eq 'Custom') {
        $bytes = [Collections.Generic.List[byte]]::new()
        foreach ($sf in @(Get-AkariUaList 'StartFolder' | Sort-Object { $_.DisplayName.Replace(' ', '') })) {
            if (Test-AkariUaOn $C "StartFolder$($sf.DisplayName.Replace(' ', ''))") { $bytes.AddRange([Convert]::FromBase64String($sf.Bytes)) }
        }
        $uo.Commands.Add("Set-ItemProperty -Path 'Registry::HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Start' -Name 'VisiblePlaces' -Value `$( [convert]::FromBase64String('$([Convert]::ToBase64String($bytes.ToArray()))') ) -Type 'Binary';")
    }
    if (Test-AkariUaOn $C 'ShowEndTask') { $du.Commands.Add('reg.exe add "HKU\DefaultUser\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced\TaskbarDeveloperSettings" /v TaskbarEndTask /t REG_DWORD /d 1 /f;') }
    $sticky = Get-AkariUaField $C 'StickyKeysMode' 'Default'
    if ($sticky -ne 'Default') {
        # SKF_AVAILABLE | SKF_CONFIRMHOTKEY, plus the picked flags
        $flags = 0x2 -bor 0x8
        if ($sticky -eq 'Custom') { foreach ($k in $AkariUaStickyFlags.Keys) { if (Test-AkariUaOn $C "StickyKeys$k") { $flags = $flags -bor $AkariUaStickyFlags[$k] } } }
        $du.Commands.Add("reg.exe add `"HKU\DefaultUser\Control Panel\Accessibility\StickyKeys`" /v Flags /t REG_SZ /d $flags /f;")
        $sp.Commands.Add("reg.exe add `"HKU\.DEFAULT\Control Panel\Accessibility\StickyKeys`" /v Flags /t REG_SZ /d $flags /f;")
    }
    if ((Get-AkariUaField $C 'CoreIsolationMode' 'Enabled') -eq 'Disabled') {
        $sp.Commands.Add(@'
  reg.exe add "HKLM\System\CurrentControlSet\Control\DeviceGuard" /v "EnableVirtualizationBasedSecurity" /t REG_DWORD /d 0 /f;
  reg.exe add "HKLM\System\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity" /v "Enabled" /t REG_DWORD /d 0 /f;
  reg.exe add "HKLM\System\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity" /v "EnabledBootId" /t REG_DWORD /d 0 /f;
  reg.exe add "HKLM\System\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity" /v "WasEnabledBy" /t REG_DWORD /d 0 /f;
'@)
    }
    if (Test-AkariUaOn $C 'DisableAutomaticRestartSignOn') { $sp.Commands.Add('  reg.exe add "HKLM\Software\Microsoft\Windows\CurrentVersion\Policies\System" /v "DisableAutomaticRestartSignOn" /t REG_DWORD /d 1 /f;') }
    if (Test-AkariUaOn $C 'HideInfoTip') { $du.Commands.Add('reg.exe add "HKU\DefaultUser\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v "ShowInfoTip" /d 0 /t REG_DWORD /f;') }
    if (Test-AkariUaOn $C 'DisableWpbt') { $sp.Commands.Add('reg.exe add "HKLM\System\CurrentControlSet\Control\Session Manager" /v "DisableWpbtExecution" /t REG_DWORD /d 1 /f;') }
    if (Test-AkariUaOn $C 'PreventDeviceApps') {
        $sp.Commands.Add("reg.exe add `"HKLM\Software\Microsoft\Windows\CurrentVersion\Device Metadata`" /v `"PreventDeviceMetadataFromNetwork`" /t REG_DWORD /d 1 /f;`r`nreg.exe add `"HKLM\Software\Microsoft\Windows\CurrentVersion\Device Installer`" /v `"DisableCoInstallers`" /t REG_DWORD /d 1 /f;")
    }
}

function Invoke-AkariUaPersonalization($C) {
    if ((Get-AkariUaField $C 'ColorMode' 'Default') -eq 'Custom') {
        $theme = { param($f) if ((Get-AkariUaField $C $f 'Light') -eq 'Dark') { 0 } else { 1 } }
        $bit = { param($f) if (Test-AkariUaOn $C $f) { 1 } else { 0 } }
        $before = "`$lightThemeSystem = $(& $theme 'SystemColorTheme');`r`n`$lightThemeApps = $(& $theme 'AppsColorTheme');`r`n`$accentColorOnStart = $(& $bit 'AccentColorOnStart');`r`n`$enableTransparency = $(& $bit 'EnableTransparency');`r`n`$htmlAccentColor = '$(ConvertTo-AkariUaHtmlColor (Get-AkariUaField $C 'AccentColor' '#0078D4'))';`r`n"
        $file = Add-AkariUaResourceFile $C 'SetColorTheme.ps1' $before
        $C.DefaultUser.Commands.Add("reg.exe add `"HKU\DefaultUser\Software\Microsoft\Windows\DWM`" /v ColorPrevalence /t REG_DWORD /d $(& $bit 'AccentColorOnBorders') /f;")
        Add-AkariUaInvoke $C.UserOnce $file
        $C.UserOnce.Restart = $true
    }
    switch (Get-AkariUaField $C 'WallpaperMode' 'Default') {
        'Script' {
            $getter = Add-AkariUaTextFile $C 'GetWallpaper.ps1' (Get-AkariUaField $C 'WallpaperScript')
            $C.Specialize.Commands.Add("try {`r`n  `$bytes = & '$getter';`r`n  [System.IO.File]::WriteAllBytes( 'C:\Windows\Setup\Scripts\Wallpaper', `$bytes );`r`n} catch {`r`n  `$_;`r`n}")
            Add-AkariUaInvoke $C.UserOnce (Add-AkariUaResourceFile $C 'SetWallpaper.ps1' '' "Set-WallpaperImage -LiteralPath 'C:\Windows\Setup\Scripts\Wallpaper';`r`n")
        }
        'Solid' { Add-AkariUaInvoke $C.UserOnce (Add-AkariUaResourceFile $C 'SetWallpaper.ps1' '' "Set-WallpaperColor -HtmlColor '$(ConvertTo-AkariUaHtmlColor (Get-AkariUaField $C 'WallpaperColor' '#008080'))';`r`n") }
    }
    if ((Get-AkariUaField $C 'LockScreenMode' 'Default') -eq 'Script') {
        $getter = Add-AkariUaTextFile $C 'GetLockScreenImage.ps1' (Get-AkariUaField $C 'LockScreenScript')
        $C.Specialize.Commands.Add("try {`r`n  `$bytes = & '$getter';`r`n  [System.IO.File]::WriteAllBytes( 'C:\Windows\Setup\Scripts\LockScreenImage', `$bytes );`r`n  reg.exe add `"HKLM\Software\Microsoft\Windows\CurrentVersion\PersonalizationCSP`" /v LockScreenImagePath /t REG_SZ /d `"C:\Windows\Setup\Scripts\LockScreenImage`" /f;`r`n} catch {`r`n  `$_;`r`n}")
    }
}
