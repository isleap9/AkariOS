# Ported from AkariOS-Ultimate (FR33THY Ultimate) 6 Windows\29 Power Plan (One-click does the same): the Ultimate
# Performance plan as 99999999-..., active, every other plan deleted, its settings tuned. Hibernate, fast boot, power
# throttling and the power menu are their own Tweaks. Revert = Windows' default plans (Balanced active).
# powercfg only through Invoke-AkariPowerCfg (Core\System.ps1).
$plan = '99999999-9999-9999-9999-999999999999'
@{
    Id          = 'power-ultimate-plan'
    Name        = 'Ultimate Performance power plan'
    Section     = 'Optimize'
    Category    = 'Power'
    Risk        = 'Caution'
    AkariOS     = $true
    Description = 'No sleep, no USB or PCIe power saving, CPU always at 100%, display off after 10 minutes; battery warnings off on laptops. Your other power plans are deleted.'
    Detect      = {
        $a = (Invoke-AkariPowerCfg '/getactivescheme') -join ' '
        if ($a -match '99999999-9999-9999-9999-999999999999') { 'Optimized' }
        elseif ($a -match '381b4222-f694-41f0-9685-ff5bb260df2e') { 'Default' }
        else { 'Custom' }
    }
    Apply       = {
        $p = '99999999-9999-9999-9999-999999999999'
        [void](Invoke-AkariPowerCfg '/duplicatescheme' 'e9a42b02-d5df-448d-aa00-03f14749eb61' $p)
        [void](Invoke-AkariPowerCfg '/setactive' $p)
        # every other plan goes (the GUID before the name on each line of /list, whatever the language)
        foreach ($g in @(Invoke-AkariPowerCfg '/list' | ForEach-Object { if ($_ -match '([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})') { $Matches[1] } })) {
            if ($g -ne $p) { [void](Invoke-AkariPowerCfg '/delete' $g) }
        }
        # hidden settings shown in Power Options so they can be set
        foreach ($k in '2a737441-1930-4402-8d77-b2bebba308a3\0853a681-27c8-4100-a2fd-82013e970683', '2a737441-1930-4402-8d77-b2bebba308a3\d4e98f31-5ffe-4ce1-be31-1b38b384c009',
                       '54533251-82be-4824-96c1-47b60b740d00\0cc5b647-c1df-4637-891a-dec35c318583', '54533251-82be-4824-96c1-47b60b740d00\ea062031-0e34-4ff1-9b6d-eb1059334028') {
            Set-Reg "HKLM:\SYSTEM\ControlSet001\Control\Power\PowerSettings\$k" 'Attributes' 0
        }
        # subgroup, setting, value (AC and DC)
        $set = @(
            ,@('0012ee47-9041-4b5d-9b77-535fba8b1442', '6738e2c4-e8a5-4a42-b16a-e040e769756e', 0)      # turn off hard disk: never
            ,@('0d7dbae2-4294-402a-ba8e-26777e8488cd', '309dce9b-bef4-4119-9921-a851fb12f0f4', 1)      # desktop slide show paused
            ,@('19cbb8fa-5279-450e-9fac-8a3d5fedd0c1', '12bbebe6-58d6-4636-95bb-3217ef867c1a', 0)      # wireless adapter: maximum performance
            ,@('238c9fa8-0aad-41ed-83f4-97be242c8f20', '29f6c1db-86da-48c5-9fdb-f2b67b1f44da', 0)      # sleep after: never
            ,@('238c9fa8-0aad-41ed-83f4-97be242c8f20', '94ac6d29-73ce-41a6-809f-6363ba21b47e', 0)      # hybrid sleep off
            ,@('238c9fa8-0aad-41ed-83f4-97be242c8f20', '9d7815a6-7ee4-497e-8888-515a05f02364', 0)      # hibernate after: never
            ,@('238c9fa8-0aad-41ed-83f4-97be242c8f20', 'bd3b718a-0680-4d9d-8ab2-e1d2b4ac806d', 0)      # wake timers off
            ,@('2a737441-1930-4402-8d77-b2bebba308a3', '0853a681-27c8-4100-a2fd-82013e970683', 0)      # USB hub selective suspend timeout 0
            ,@('2a737441-1930-4402-8d77-b2bebba308a3', '48e6b7a6-50f5-4782-a5d4-53bb8f07e226', 0)      # USB selective suspend off
            ,@('2a737441-1930-4402-8d77-b2bebba308a3', 'd4e98f31-5ffe-4ce1-be31-1b38b384c009', 0)      # USB 3 link power management off
            ,@('4f971e89-eebd-4455-a8de-9e59040e7347', 'a7066653-8d6c-40a8-910e-a1f54b84c7e5', 2)      # Start menu power button: shut down
            ,@('501a4d13-42af-4429-9fd1-a8218c268e20', 'ee12f906-d277-404b-b6da-e5fa1a576df5', 0)      # PCIe link state power management off
            ,@('54533251-82be-4824-96c1-47b60b740d00', '893dee8e-2bef-41e0-89c6-b55d0929964c', 100)    # minimum processor state 100%
            ,@('54533251-82be-4824-96c1-47b60b740d00', '94d3a615-a899-4ac5-ae2b-e4d8f634367f', 1)      # cooling policy active
            ,@('54533251-82be-4824-96c1-47b60b740d00', 'bc5038f7-23e0-4960-96da-33abaf5935ec', 100)    # maximum processor state 100%
            ,@('54533251-82be-4824-96c1-47b60b740d00', '0cc5b647-c1df-4637-891a-dec35c318583', 100)    # core parking min cores 100% (unparked)
            ,@('54533251-82be-4824-96c1-47b60b740d00', 'ea062031-0e34-4ff1-9b6d-eb1059334028', 100)    # core parking max cores 100%
            ,@('7516b95f-f776-4464-8c53-06167f40cc99', '3c0bc021-c8a8-4e07-a973-6b14cbcb2b7e', 600)    # display off after 10 minutes (OLED)
            ,@('7516b95f-f776-4464-8c53-06167f40cc99', 'aded5e82-b909-4619-9949-f5d71dac0bcb', 100)    # display brightness 100%
            ,@('7516b95f-f776-4464-8c53-06167f40cc99', 'f1fbfde2-a960-4165-9f88-50667911ce96', 100)    # dimmed brightness 100%
            ,@('7516b95f-f776-4464-8c53-06167f40cc99', 'fbd9aa66-9553-4097-ba44-ed6e9d65eab8', 0)      # adaptive brightness off
            ,@('9596fb26-9850-41fd-ac3e-f7c3c00afd4b', '10778347-1370-4ee0-8bbd-33bdacaade49', 1)      # video playback: performance bias
            ,@('9596fb26-9850-41fd-ac3e-f7c3c00afd4b', '34c7b99f-9a6d-4b3c-8dc7-b6693b78cef4', 0)      # when playing video: optimize quality
            ,@('44f3beca-a7c0-460e-9df2-bb8b99e0cba6', '3619c3f2-afb2-4afc-b0e9-e7fef372de36', 2)      # Intel graphics: maximum performance
            ,@('c763b4ec-0e50-4b6b-9bed-2b92a6ee884e', '7ec1751b-60ed-4588-afb5-9819d3d77d90', 3)      # AMD power slider: best performance
            ,@('f693fb01-e858-4f00-b20f-f30e12ac06d6', '191f65b5-d45c-4a4f-8aae-1ab8bfd980e6', 1)      # ATI PowerPlay: maximize performance
            ,@('e276e160-7cb0-43c6-b20b-73f5dce39954', 'a1662ab2-9d34-4e53-ba8b-2639b9e20857', 3)      # switchable graphics: maximize performance
            ,@('e73a048d-bf27-4f12-9731-8b2076e8891f', '5dbb7c9f-38e9-40d2-9749-4f8a0e9f640f', 0)      # critical battery notification off
            ,@('e73a048d-bf27-4f12-9731-8b2076e8891f', '637ea02f-bbcb-4015-8e2c-a1c7b9c0b546', 0)      # critical battery action: do nothing
            ,@('e73a048d-bf27-4f12-9731-8b2076e8891f', '8183ba9a-e910-48da-8769-14ae6dc1170a', 0)      # low battery level 0%
            ,@('e73a048d-bf27-4f12-9731-8b2076e8891f', '9a66d8d7-4ff7-4ef9-b5a2-5a326ca2a469', 0)      # critical battery level 0%
            ,@('e73a048d-bf27-4f12-9731-8b2076e8891f', 'bcded951-187b-4d05-bccc-f7e51960c258', 0)      # low battery notification off
            ,@('e73a048d-bf27-4f12-9731-8b2076e8891f', 'd8742dcb-3e6a-4b3c-b3fe-374623cdcf06', 0)      # low battery action: do nothing
            ,@('e73a048d-bf27-4f12-9731-8b2076e8891f', 'f3c5027d-cd16-4930-aa6b-90db844a8f00', 0)      # reserve battery level 0%
            ,@('de830923-a562-41af-a086-e3a2c6bad2da', '13d09884-f74e-474a-a852-b6bde8ad03a8', 100)    # battery saver: no dimming
            ,@('de830923-a562-41af-a086-e3a2c6bad2da', 'e69653ca-cf7f-4f05-aa73-cb833fa90ad4', 0)      # battery saver: never automatic
        )
        foreach ($s in $set) {
            [void](Invoke-AkariPowerCfg '/setacvalueindex' $p $s[0] $s[1] $s[2])
            [void](Invoke-AkariPowerCfg '/setdcvalueindex' $p $s[0] $s[1] $s[2])
        }
        # Chrome and Discord can't keep the screen on (the 10 minute display timeout still applies)
        foreach ($x in 'chrome.exe', 'Discord.exe') { [void](Invoke-AkariPowerCfg '/requestsoverride' 'PROCESS' $x 'DISPLAY' 'SYSTEM' 'AWAYMODE') }
        [void](Invoke-AkariPowerCfg '/setactive' $p)
    }
    Revert      = {
        [void](Invoke-AkariPowerCfg '/restoredefaultschemes')
        foreach ($x in 'chrome.exe', 'Discord.exe') { [void](Invoke-AkariPowerCfg '/requestsoverride' 'PROCESS' $x) }
        foreach ($k in '2a737441-1930-4402-8d77-b2bebba308a3\0853a681-27c8-4100-a2fd-82013e970683', '2a737441-1930-4402-8d77-b2bebba308a3\d4e98f31-5ffe-4ce1-be31-1b38b384c009',
                       '54533251-82be-4824-96c1-47b60b740d00\0cc5b647-c1df-4637-891a-dec35c318583', '54533251-82be-4824-96c1-47b60b740d00\ea062031-0e34-4ff1-9b6d-eb1059334028') {
            Set-Reg "HKLM:\SYSTEM\ControlSet001\Control\Power\PowerSettings\$k" 'Attributes' 1
        }
    }
}
