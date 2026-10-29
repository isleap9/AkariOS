# Install USB (UI\Unattend.ps1): the form, section by section in the order of Schneegans' generator
# (https://schneegans.de/windows/unattend-generator/), with his field names. UI\UnattendForm.ps1 builds it.
# Item kinds: Radio (Options: Value, Label, Items shown while it is picked), Check (Label, Items shown while ticked),
# Input (Label, Kind Text | Number | Multi), Select (Label, List = a Core\Unattend\Data file, or Options: Id, Name),
# Checks (several values of one field), Accounts (the account table), Note (a grey line).
# Defaults: the form's starting values (this PC's language, keyboard, region and time zone are put over them).
@{
    Sections = @(
        @{ Title = 'Region and language'; Items = @(
            @{ Radio = 'LanguageMode'; Options = @(
                @{ Value = 'Unattended'; Label = 'Install Windows using these language settings'; Items = @(
                    @{ Select = 'UILanguage'; Label = 'Windows display language (must be a language your ISO has)'; List = 'ImageLanguage' }
                    @{ Note = 'Language preferences and keyboard layouts' }
                    @{ Select = 'Locale'; Label = 'First language'; List = 'UserLocale' }
                    @{ Select = 'Keyboard'; Label = 'Keyboard layout or IME'; List = 'KeyboardIdentifier' }
                    @{ Check = 'UseKeyboard2'; Label = 'Add a second language'; Items = @(
                        @{ Select = 'Locale2'; Label = 'Second language'; List = 'UserLocale' }
                        @{ Select = 'Keyboard2'; Label = 'Keyboard layout or IME'; List = 'KeyboardIdentifier' }
                    ) }
                    @{ Check = 'UseKeyboard3'; Label = 'Add a third language'; Items = @(
                        @{ Select = 'Locale3'; Label = 'Third language'; List = 'UserLocale' }
                        @{ Select = 'Keyboard3'; Label = 'Keyboard layout or IME'; List = 'KeyboardIdentifier' }
                    ) }
                    @{ Select = 'GeoLocation'; Label = 'Home location and device setup region'; List = 'GeoId' }
                ) }
                @{ Value = 'Interactive'; Label = 'Select language settings interactively during Windows Setup' }
            ) }
        ) }
        @{ Title = 'Processor architectures'; Items = @(
            @{ Checks = 'ProcessorArchitecture'; Label = 'Windows is installed for every architecture ticked (the file then fits several kinds of PC)'; Options = @(
                @{ Id = 'x86'; Name = 'Intel/AMD 32-bit' }, @{ Id = 'amd64'; Name = 'Intel/AMD 64-bit' }, @{ Id = 'arm64'; Name = 'Windows on Arm64' }
            ) }
        ) }
        @{ Title = 'Setup settings'; Items = @(
            @{ Check = 'BypassRequirementsCheck'; Label = 'Bypass Windows 11 requirements check (TPM, Secure Boot, RAM)' }
            @{ Check = 'BypassNetworkCheck'; Label = 'Allow Windows 11 to install without internet connection' }
            @{ Check = 'HidePowerShellWindows'; Label = 'Hide PowerShell windows during Windows Setup' }
            @{ Check = 'KeepSensitiveFiles'; Label = 'Keep sensitive files (unattend.xml and the Wi-Fi profile stay on the PC)' }
            @{ Check = 'UseNarrator'; Label = 'Start Narrator automatically during Windows Setup' }
        ) }
        @{ Title = 'Windows PE stage'; Items = @(
            @{ Radio = 'PEMode'; Options = @(
                @{ Value = 'Default'; Label = 'Run the Windows PE stage interactively (you pick the disk)'; Items = @(
                    @{ Radio = 'WindowsEditionMode'; Options = @(
                        @{ Value = 'Interactive'; Label = 'Enter product key interactively' }
                        @{ Value = 'Generic'; Label = 'Use a generic product key (picks the edition, does not activate)'; Items = @(
                            @{ Select = 'WindowsEdition'; Label = 'Edition'; List = 'WindowsEdition' }
                        ) }
                        @{ Value = 'Custom'; Label = 'Enter another product key'; Items = @(
                            @{ Input = 'ProductKey'; Label = 'Product key (XXXXX-XXXXX-XXXXX-XXXXX-XXXXX)' }
                        ) }
                        @{ Value = 'Firmware'; Label = 'Use the product key stored in the BIOS / UEFI firmware' }
                    ) }
                ) }
                @{ Value = 'Generated'; Label = 'Generate a .cmd script to handle the Windows PE stage (can wipe a disk)'; Items = @(
                    @{ Note = 'Partitioning and formatting' }
                    @{ Radio = 'PartitionMode'; Options = @(
                        @{ Value = 'Unattended'; Label = 'Let Windows Setup wipe, partition and format the disk'; Items = @(
                            @{ Radio = 'TargetDiskMode'; Options = @(
                                @{ Value = 'Generated'; Label = 'Install on the disk that meets all of these'; Items = @(
                                    @{ Check = 'TargetDiskNoPartitions'; Label = 'Has no partitions yet' }
                                    @{ Check = 'TargetDiskInterfaceType'; Label = 'Is connected through SATA, SCSI, SAS or NVMe' }
                                    @{ Check = 'TargetDiskMediaType'; Label = 'Reports itself as a fixed hard disk' }
                                    @{ Check = 'TargetDiskSize'; Label = 'Has a capacity in this range'; Items = @(
                                        @{ Input = 'TargetDiskMinSize'; Label = 'At least (GiB)'; Kind = 'Number' }
                                        @{ Input = 'TargetDiskMaxSize'; Label = 'At most (GiB)'; Kind = 'Number' }
                                    ) }
                                    @{ Check = 'TargetDiskIndex'; Label = 'Has this index number'; Items = @(
                                        @{ Input = 'TargetDisk'; Label = 'Disk index (0 = the first disk)'; Kind = 'Number' }
                                    ) }
                                ) }
                                @{ Value = 'Script'; Label = 'Determine the disk with my own VBScript'; Items = @(
                                    @{ Input = 'TargetDiskScript'; Label = 'VBScript (writes the disk index)'; Kind = 'Multi' }
                                ) }
                                @{ Value = 'Interactive'; Label = 'Type the disk index during setup' }
                            ) }
                            @{ Radio = 'PartitionLayout'; Options = @(
                                @{ Value = 'Automatic'; Label = 'Partition layout: automatic (GPT for UEFI, MBR for BIOS)' }
                                @{ Value = 'GPT'; Label = 'GPT' }
                                @{ Value = 'MBR'; Label = 'MBR' }
                            ) }
                            @{ Input = 'SystemSize'; Label = 'System partition size (MB)'; Kind = 'Number' }
                            @{ Radio = 'RecoveryMode'; Options = @(
                                @{ Value = 'Partition'; Label = 'Install Windows RE on a recovery partition'; Items = @(
                                    @{ Input = 'RecoverySize'; Label = 'Recovery partition size (MB)'; Kind = 'Number' }
                                ) }
                                @{ Value = 'None'; Label = 'Remove Windows RE' }
                            ) }
                        ) }
                        @{ Value = 'Custom'; Label = 'Use my own diskpart script'; Items = @(
                            @{ Input = 'DiskpartScript'; Label = 'diskpart script (must assign W: to Windows and S: to the system partition)'; Kind = 'Multi' }
                        ) }
                        @{ Value = 'Interactive'; Label = 'Partition the disk myself during setup (Shift+F10, diskpart)' }
                    ) }
                    @{ Note = 'Windows image to install' }
                    @{ Radio = 'InstallFromMode'; Options = @(
                        @{ Value = 'Edition'; Label = 'Select the image by edition'; Items = @( @{ Select = 'InstallFromEdition'; Label = 'Edition'; List = 'WindowsEdition' } ) }
                        @{ Value = 'Name'; Label = 'Select the image by name'; Items = @( @{ Input = 'InstallFromName'; Label = 'Image name' } ) }
                        @{ Value = 'Index'; Label = 'Select the image by index'; Items = @( @{ Input = 'InstallFromIndex'; Label = 'Image index'; Kind = 'Number' } ) }
                        @{ Value = 'Interactive'; Label = 'Select the image during setup' }
                    ) }
                    @{ Note = 'Paging file' }
                    @{ Radio = 'PagingFileMode'; Options = @(
                        @{ Value = 'Automatic'; Label = 'Let Windows manage the paging file' }
                        @{ Value = 'Custom'; Label = 'Custom size'; Items = @(
                            @{ Input = 'InitPagingFileSize'; Label = 'Initial size (MB)'; Kind = 'Number' }
                            @{ Input = 'MaxPagingFileSize'; Label = 'Maximum size (MB)'; Kind = 'Number' }
                        ) }
                        @{ Value = 'None'; Label = 'No paging file' }
                    ) }
                    @{ Check = 'DisableDefender'; Label = 'Disable Windows Defender' }
                    @{ Check = 'Disable8Dot3Names'; Label = 'Disable 8.3 file names' }
                    @{ Check = 'CompactOs'; Label = 'Apply the Windows image in compact mode' }
                    @{ Check = 'SkipIntegrityCheck'; Label = 'Skip the integrity check when applying the image' }
                    @{ Check = 'PauseBeforeFormatting'; Label = 'Pause before the disk is partitioned and formatted' }
                    @{ Check = 'PauseBeforeReboot'; Label = 'Pause before Windows Setup reboots at the end of the PE stage' }
                ) }
                @{ Value = 'Script'; Label = 'Provide my own .cmd script for the whole Windows PE stage'; Items = @(
                    @{ Input = 'PEScript'; Label = '.cmd script'; Kind = 'Multi' }
                ) }
            ) }
        ) }
        @{ Title = 'Activation'; Items = @(
            @{ Check = 'UseActivationKey'; Label = 'Use this product key to activate Windows'; Items = @( @{ Input = 'ActivationKey'; Label = 'Product key' } ) }
        ) }
        @{ Title = 'Computer name'; Items = @(
            @{ Radio = 'ComputerNameMode'; Options = @(
                @{ Value = 'Random'; Label = 'Let Windows pick a random name' }
                @{ Value = 'Custom'; Label = 'Choose a name'; Items = @( @{ Input = 'ComputerName'; Label = 'Computer name (up to 15 characters)' } ) }
                @{ Value = 'Prompt'; Label = 'Enter the name during setup' }
                @{ Value = 'Script'; Label = 'Get the name from a PowerShell script'; Items = @( @{ Input = 'ComputerNameScript'; Label = 'PowerShell (returns the name)'; Kind = 'Multi' } ) }
            ) }
        ) }
        @{ Title = 'Time zone'; Items = @(
            @{ Radio = 'TimeZoneMode'; Options = @(
                @{ Value = 'Implicit'; Label = 'Determine the time zone from the language and region' }
                @{ Value = 'Explicit'; Label = 'Set the time zone'; Items = @( @{ Select = 'TimeZone'; Label = 'Time zone'; List = 'TimeOffset' } ) }
            ) }
        ) }
        @{ Title = 'User accounts'; Items = @(
            @{ Radio = 'UserAccountMode'; Options = @(
                @{ Value = 'Unattended'; Label = 'Let Windows Setup create these local accounts'; Items = @(
                    @{ Accounts = 'Account' }
                    @{ Radio = 'AutoLogonMode'; Options = @(
                        @{ Value = 'Own'; Label = 'First logon: sign in to the first administrator account' }
                        @{ Value = 'Builtin'; Label = 'First logon: activate the built-in Administrator and sign in to it'; Items = @(
                            @{ Input = 'BuiltinAdministratorPassword'; Label = 'Administrator password' }
                        ) }
                        @{ Value = 'None'; Label = 'Do not sign in' }
                    ) }
                    @{ Check = 'ObscurePasswords'; Label = 'Obscure the passwords with Base64 (not encryption: anyone with the file can read them)' }
                ) }
                @{ Value = 'Interactive'; Label = 'Add a Microsoft (online) account during setup' }
                @{ Value = 'InteractiveLocal'; Label = 'Add a local (offline) account during setup' }
            ) }
        ) }
        @{ Title = 'Password expiration'; Items = @(
            @{ Radio = 'PasswordExpirationMode'; Options = @(
                @{ Value = 'Unlimited'; Label = 'Passwords do not expire' }
                @{ Value = 'Default'; Label = 'Use the Windows default (42 days)' }
                @{ Value = 'Custom'; Label = 'Passwords expire after'; Items = @( @{ Input = 'PasswordMaxAge'; Label = 'Days'; Kind = 'Number' } ) }
            ) }
        ) }
        @{ Title = 'Account lockout policy'; Items = @(
            @{ Radio = 'LockoutMode'; Options = @(
                @{ Value = 'Default'; Label = 'Use the Windows default' }
                @{ Value = 'Disabled'; Label = 'Disable the account lockout policy' }
                @{ Value = 'Custom'; Label = 'Custom policy'; Items = @(
                    @{ Input = 'LockoutThreshold'; Label = 'Lock after this many failed attempts'; Kind = 'Number' }
                    @{ Input = 'LockoutWindow'; Label = 'Reset the count after (minutes)'; Kind = 'Number' }
                    @{ Input = 'LockoutDuration'; Label = 'Unlock after (minutes)'; Kind = 'Number' }
                ) }
            ) }
        ) }
        @{ Title = 'Wi-Fi setup'; Items = @(
            @{ Radio = 'WifiMode'; Options = @(
                @{ Value = 'Interactive'; Label = 'Configure Wi-Fi interactively during setup' }
                @{ Value = 'Skip'; Label = 'Skip Wi-Fi configuration' }
                @{ Value = 'Unattended'; Label = 'Connect to this network'; Items = @(
                    @{ Input = 'WifiName'; Label = 'Network name (SSID)' }
                    @{ Check = 'WifiNonBroadcast'; Label = 'Connect even if the network is not broadcasting its name' }
                    @{ Select = 'WifiAuthentication'; Label = 'Authentication'; Options = @( @{ Id = 'Open'; Name = 'Open' }, @{ Id = 'WPA2PSK'; Name = 'WPA2-Personal AES' }, @{ Id = 'WPA3SAE'; Name = 'WPA3-Personal AES' } ) }
                    @{ Input = 'WifiPassword'; Label = 'Password (stored in the file as plain text)' }
                ) }
                @{ Value = 'FromProfile'; Label = 'Use this Wi-Fi profile XML'; Items = @( @{ Input = 'WifiProfileXml'; Label = 'WLAN profile XML'; Kind = 'Multi' } ) }
            ) }
        ) }
        @{ Title = 'Express settings'; Items = @(
            @{ Radio = 'ExpressSettings'; Options = @(
                @{ Value = 'DisableAll'; Label = 'Turn all express (privacy) settings off' }
                @{ Value = 'EnableAll'; Label = 'Turn all express settings on' }
                @{ Value = 'Interactive'; Label = 'Choose them during setup' }
            ) }
        ) }
    )
    Defaults = @{
        LanguageMode = 'Unattended'; UILanguage = 'en-US'; Locale = 'en-US'; Keyboard = '00000409'; Locale2 = 'en-US'; Keyboard2 = '00000409'
        Locale3 = 'en-US'; Keyboard3 = '00000409'; GeoLocation = '244'; ProcessorArchitecture = 'amd64'
        BypassRequirementsCheck = 'true'; BypassNetworkCheck = 'true'
        PEMode = 'Default'; WindowsEditionMode = 'Interactive'; WindowsEdition = 'pro'; ProductKey = ''
        PartitionMode = 'Unattended'; TargetDiskMode = 'Generated'; TargetDiskNoPartitions = 'true'; TargetDiskSize = 'true'; TargetDiskMinSize = '100'
        TargetDiskMaxSize = '4000'; TargetDisk = '0'; PartitionLayout = 'Automatic'; SystemSize = '300'; RecoveryMode = 'Partition'; RecoverySize = '1000'
        InstallFromMode = 'Edition'; InstallFromEdition = 'pro'; InstallFromName = 'Windows 11 Pro'; InstallFromIndex = '1'
        PagingFileMode = 'Automatic'; InitPagingFileSize = '2000'; MaxPagingFileSize = '4000'
        ComputerNameMode = 'Random'; TimeZoneMode = 'Explicit'; TimeZone = 'UTC'
        UserAccountMode = 'Unattended'; AccountName0 = 'Admin'; AccountGroup0 = 'Administrators'; AutoLogonMode = 'Own'; ObscurePasswords = 'true'
        PasswordExpirationMode = 'Unlimited'; PasswordMaxAge = '42'; LockoutMode = 'Default'; LockoutThreshold = '10'; LockoutWindow = '10'; LockoutDuration = '10'
        WifiMode = 'Interactive'; WifiAuthentication = 'WPA2PSK'; ExpressSettings = 'DisableAll'
    }
}
