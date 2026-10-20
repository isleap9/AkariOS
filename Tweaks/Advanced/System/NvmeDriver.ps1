# Ported from AkariOS-Ultimate (FR33THY Ultimate) 8 Advanced\19 NVME Faster Driver. Revert removes only these values
# and keys (the old script deleted all of HKLM\SYSTEM\CurrentControlSet\Policies\Microsoft).
@{
    Id          = 'system-nvme-native-driver'
    Name        = 'Faster native NVMe driver'
    Section     = 'Advanced'
    Category    = 'System'
    Risk        = 'Advanced'
    Requires    = 'Win11'
    Reboot      = $true
    Description = 'Turns on the new Windows Server NVMe driver (lower latency). Some disk tools and drivers do not support it yet.'
    Registry    = @(
        @{ Path = 'HKLM:\SYSTEM\CurrentControlSet\Policies\Microsoft\FeatureManagement\Overrides'; Name = '735209102'; Type = 'DWord'; Value = 1; Default = $null }
        @{ Path = 'HKLM:\SYSTEM\CurrentControlSet\Policies\Microsoft\FeatureManagement\Overrides'; Name = '3244671118'; Type = 'DWord'; Value = 1; Default = $null }
        @{ Path = 'HKLM:\SYSTEM\CurrentControlSet\Policies\Microsoft\FeatureManagement\Overrides'; Name = '1853569164'; Type = 'DWord'; Value = 1; Default = $null }
        @{ Path = 'HKLM:\SYSTEM\CurrentControlSet\Policies\Microsoft\FeatureManagement\Overrides'; Name = '156965516'; Type = 'DWord'; Value = 1; Default = $null }
        # Safe Mode and Safe Mode with networking load the new driver too (else they cannot find the disk)
        @{ Path = 'HKLM:\SYSTEM\CurrentControlSet\Control\SafeBoot\Network\{75416E63-5912-4DFA-AE8F-3EFACCAFFB14}'; Name = '(default)'; Type = 'String'; Value = 'Storage disks'; Default = $null }
        @{ Path = 'HKLM:\SYSTEM\CurrentControlSet\Control\SafeBoot\Network\{75416E63-5912-4DFA-AE8F-3EFACCAFFB14}'; Value = 'Key'; Default = $null }
        @{ Path = 'HKLM:\SYSTEM\CurrentControlSet\Control\SafeBoot\Minimal\{75416E63-5912-4DFA-AE8F-3EFACCAFFB14}'; Name = '(default)'; Type = 'String'; Value = 'Storage disks'; Default = $null }
        @{ Path = 'HKLM:\SYSTEM\CurrentControlSet\Control\SafeBoot\Minimal\{75416E63-5912-4DFA-AE8F-3EFACCAFFB14}'; Value = 'Key'; Default = $null }
    )
}
