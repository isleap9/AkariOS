# Unattend Generator (UI\Unattend.ps1): the form, section by section in the order of Schneegans' generator
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
        @{ Title = 'File Explorer tweaks'; Items = @(
            @{ Radio = 'HideFiles'; Options = @(
                @{ Value = 'Hidden'; Label = 'Hide hidden files and protected operating system files (Windows default)' }
                @{ Value = 'HiddenSystem'; Label = 'Show hidden files, hide protected operating system files' }
                @{ Value = 'None'; Label = 'Show all files' }
            ) }
            @{ Check = 'ShowFileExtensions'; Label = 'Always show file extensions' }
            @{ Check = 'ClassicContextMenu'; Label = 'Use the classic context menu in Windows 11' }
            @{ Check = 'HideInfoTip'; Label = 'Hide the pop-up description for folder and desktop items' }
            @{ Check = 'LaunchToThisPC'; Label = 'Open File Explorer to This PC instead of Home' }
            @{ Check = 'ShowEndTask'; Label = 'Show End task in the taskbar''s context menu' }
        ) }
        @{ Title = 'Start menu and taskbar'; Items = @(
            @{ Radio = 'TaskbarSearch'; Options = @(
                @{ Value = 'Box'; Label = 'Search on the taskbar: full box (Windows default)' }
                @{ Value = 'Label'; Label = 'Search: icon and label' }
                @{ Value = 'Icon'; Label = 'Search: icon only' }
                @{ Value = 'Hide'; Label = 'Search: hide it' }
            ) }
            @{ Radio = 'TaskbarIconsMode'; Options = @(
                @{ Value = 'Default'; Label = 'Taskbar icons: Windows default' }
                @{ Value = 'Empty'; Label = 'Taskbar icons: remove all' }
                @{ Value = 'Custom'; Label = 'Taskbar icons: from this XML'; Items = @( @{ Input = 'TaskbarIconsXml'; Label = 'Taskbar layout XML'; Kind = 'Multi' } ) }
            ) }
            @{ Check = 'DisableWidgets'; Label = 'Disable widgets' }
            @{ Check = 'LeftTaskbar'; Label = 'Left-align the taskbar in Windows 11' }
            @{ Check = 'HideTaskViewButton'; Label = 'Hide the Task view button' }
            @{ Check = 'ShowAllTrayIcons'; Label = 'Always show all tray icons' }
            @{ Check = 'DisableBingResults'; Label = 'Do not show Bing results when searching' }
        ) }
        @{ Title = 'Start tiles (Windows 10)'; Items = @(
            @{ Radio = 'StartTilesMode'; Options = @(
                @{ Value = 'Default'; Label = 'Use the default tiles' }
                @{ Value = 'Empty'; Label = 'Remove all tiles' }
                @{ Value = 'Custom'; Label = 'Use this XML'; Items = @( @{ Input = 'StartTilesXml'; Label = 'Start layout XML'; Kind = 'Multi' } ) }
            ) }
        ) }
        @{ Title = 'Start pins (Windows 11)'; Items = @(
            @{ Radio = 'StartPinsMode'; Options = @(
                @{ Value = 'Default'; Label = 'Use the default pins' }
                @{ Value = 'Empty'; Label = 'Remove all pins' }
                @{ Value = 'Custom'; Label = 'Use this JSON'; Items = @( @{ Input = 'StartPinsJson'; Label = 'Start pins JSON'; Kind = 'Multi' } ) }
            ) }
        ) }
        @{ Title = 'System tweaks'; Items = @(
            @{ Check = 'DisableWindowsUpdate'; Label = 'Disable Windows Update (pauses it for as long as possible)' }
            @{ Check = 'DisableUac'; Label = 'Disable User Account Control (UAC)' }
            @{ Check = 'DisableSac'; Label = 'Disable Smart App Control' }
            @{ Check = 'DisableSmartScreen'; Label = 'Disable SmartScreen in Windows and Edge' }
            @{ Check = 'DisableFastStartup'; Label = 'Disable Fast Startup' }
            @{ Check = 'DisableSystemRestore'; Label = 'Disable System Protection / System Restore' }
            @{ Check = 'EnableLongPaths'; Label = 'Enable long paths' }
            @{ Check = 'EnableRemoteDesktop'; Label = 'Enable Remote Desktop services (RDP)' }
            @{ Check = 'HardenSystemDriveAcl'; Label = 'Harden ACLs of the system drive' }
            @{ Check = 'DeleteJunctions'; Label = 'Delete hidden junction points' }
            @{ Check = 'AllowPowerShellScripts'; Label = 'Allow execution of PowerShell script files' }
            @{ Check = 'DisableLastAccess'; Label = 'Do not update the Last Access Time stamp' }
            @{ Check = 'PreventAutomaticReboot'; Label = 'Prevent Windows Update from rebooting the computer' }
            @{ Check = 'TurnOffSystemSounds'; Label = 'Turn off system sounds' }
            @{ Check = 'DisableAppSuggestions'; Label = 'Disable app suggestions (Content Delivery Manager)' }
            @{ Check = 'PreventDeviceEncryption'; Label = 'Prevent device encryption' }
            @{ Check = 'HideEdgeFre'; Label = 'Hide Edge''s First Run Experience' }
            @{ Check = 'DisableEdgeStartupBoost'; Label = 'Disable Edge Startup Boost and background mode' }
            @{ Check = 'MakeEdgeUninstallable'; Label = 'Make Edge uninstallable' }
            @{ Check = 'DisablePointerPrecision'; Label = 'Disable "Enhance pointer precision"' }
            @{ Check = 'DeleteWindowsOld'; Label = 'Delete an empty C:\Windows.old folder' }
            @{ Check = 'DisableAutomaticRestartSignOn'; Label = 'Disable automatic sign-on of the last user after a restart' }
            @{ Check = 'DisableWpbt'; Label = 'Disable Windows Platform Binary Table (WPBT) execution' }
            @{ Check = 'PreventDeviceApps'; Label = 'Prevent the download of apps associated with certain hardware' }
            @{ Check = 'ProcessAudit'; Label = 'Audit process creation events'; Items = @(
                @{ Check = 'ProcessAuditCommandLine'; Label = 'Include the command line in the events' }
            ) }
        ) }
        @{ Title = 'Visual effects'; Items = @(
            @{ Radio = 'EffectsMode'; Options = @(
                @{ Value = 'Default'; Label = 'Let Windows choose (default)' }
                @{ Value = 'Appearance'; Label = 'Adjust for best appearance' }
                @{ Value = 'Performance'; Label = 'Adjust for best performance' }
                @{ Value = 'Custom'; Label = 'Custom'; Items = @(
                    @{ Check = 'ControlAnimations'; Label = 'Animate controls and elements inside windows' }
                    @{ Check = 'AnimateMinMax'; Label = 'Animate windows when minimizing and maximizing' }
                    @{ Check = 'TaskbarAnimations'; Label = 'Animations in the taskbar' }
                    @{ Check = 'DWMAeroPeekEnabled'; Label = 'Enable Peek' }
                    @{ Check = 'MenuAnimation'; Label = 'Fade or slide menus into view' }
                    @{ Check = 'TooltipAnimation'; Label = 'Fade or slide ToolTips into view' }
                    @{ Check = 'SelectionFade'; Label = 'Fade out menu items after clicking' }
                    @{ Check = 'DWMSaveThumbnailEnabled'; Label = 'Save taskbar thumbnail previews' }
                    @{ Check = 'CursorShadow'; Label = 'Show shadows under the mouse pointer' }
                    @{ Check = 'DropShadow'; Label = 'Show shadows under windows' }
                    @{ Check = 'ThumbnailsOrIcon'; Label = 'Show thumbnails instead of icons' }
                    @{ Check = 'ListviewAlphaSelect'; Label = 'Show translucent selection rectangle' }
                    @{ Check = 'DragFullWindows'; Label = 'Show window contents while dragging' }
                    @{ Check = 'ComboBoxAnimation'; Label = 'Slide open combo boxes' }
                    @{ Check = 'FontSmoothing'; Label = 'Smooth edges of screen fonts' }
                    @{ Check = 'ListBoxSmoothScrolling'; Label = 'Smooth-scroll list boxes' }
                    @{ Check = 'ListviewShadow'; Label = 'Use drop shadows for icon labels on the desktop' }
                ) }
            ) }
        ) }
        @{ Title = 'Desktop icons'; Items = @(
            @{ Radio = 'DesktopIconsMode'; Options = @(
                @{ Value = 'Default'; Label = 'Show the default icons' }
                @{ Value = 'Custom'; Label = 'Show these icons'; Items = @(
                    @{ Check = 'IconControlPanel'; Label = 'Control Panel' }
                    @{ Check = 'IconDesktop'; Label = 'Desktop' }
                    @{ Check = 'IconDocuments'; Label = 'Documents' }
                    @{ Check = 'IconDownloads'; Label = 'Downloads' }
                    @{ Check = 'IconGallery'; Label = 'Gallery' }
                    @{ Check = 'IconHome'; Label = 'Home' }
                    @{ Check = 'IconMusic'; Label = 'Music' }
                    @{ Check = 'IconNetwork'; Label = 'Network' }
                    @{ Check = 'IconPictures'; Label = 'Pictures' }
                    @{ Check = 'IconRecycleBin'; Label = 'Recycle bin' }
                    @{ Check = 'IconThisPC'; Label = 'This PC' }
                    @{ Check = 'IconUserFiles'; Label = 'User''s Files' }
                    @{ Check = 'IconVideos'; Label = 'Videos' }
                ) }
            ) }
            @{ Check = 'DeleteEdgeDesktopIcon'; Label = 'Delete the Edge shortcut on the desktop' }
        ) }
        @{ Title = 'Folders on Start'; Items = @(
            @{ Radio = 'StartFoldersMode'; Options = @(
                @{ Value = 'Default'; Label = 'Show the default folders' }
                @{ Value = 'Custom'; Label = 'Show these folders next to the power button'; Items = @(
                    @{ Check = 'StartFolderDocuments'; Label = 'Documents' }
                    @{ Check = 'StartFolderDownloads'; Label = 'Downloads' }
                    @{ Check = 'StartFolderFileExplorer'; Label = 'File Explorer' }
                    @{ Check = 'StartFolderMusic'; Label = 'Music' }
                    @{ Check = 'StartFolderNetwork'; Label = 'Network' }
                    @{ Check = 'StartFolderPersonalFolder'; Label = 'Personal Folder' }
                    @{ Check = 'StartFolderPictures'; Label = 'Pictures' }
                    @{ Check = 'StartFolderSettings'; Label = 'Settings' }
                    @{ Check = 'StartFolderVideos'; Label = 'Videos' }
                ) }
            ) }
        ) }
        @{ Title = 'Virtual machine host: core isolation'; Items = @(
            @{ Radio = 'CoreIsolationMode'; Options = @(
                @{ Value = 'Enabled'; Label = 'Keep core isolation (VBS, memory integrity) enabled where supported' }
                @{ Value = 'Disabled'; Label = 'Disable core isolation (for other hypervisors such as VirtualBox or VMware)' }
            ) }
        ) }
        @{ Title = 'Virtual machine guest tools'; Items = @(
            @{ Check = 'VBoxGuestAdditions'; Label = 'VirtualBox Guest Additions' }
            @{ Check = 'VMwareTools'; Label = 'VMware Tools' }
            @{ Check = 'VirtIoGuestTools'; Label = 'VirtIO drivers, VirtIO Guest Tools and QEMU Guest Agent' }
            @{ Check = 'ParallelsTools'; Label = 'Parallels Tools' }
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
        @{ Title = 'Lock key settings'; Items = @(
            @{ Radio = 'LockKeysMode'; Options = @(
                @{ Value = 'Skip'; Label = 'Use the Windows defaults' }
                @{ Value = 'Configure'; Label = 'Configure Caps Lock, Num Lock and Scroll Lock'; Items = @(
                    @{ Select = 'CapsLockInitial'; Label = 'Caps Lock at sign-in'; Options = @( @{ Id = 'Off'; Name = 'Off' }, @{ Id = 'On'; Name = 'On' } ) }
                    @{ Select = 'CapsLockBehavior'; Label = 'Caps Lock when pressed'; Options = @( @{ Id = 'Toggle'; Name = 'Toggle its state' }, @{ Id = 'Ignore'; Name = 'Ignore the keystroke' } ) }
                    @{ Select = 'NumLockInitial'; Label = 'Num Lock at sign-in'; Options = @( @{ Id = 'Off'; Name = 'Off' }, @{ Id = 'On'; Name = 'On' } ) }
                    @{ Select = 'NumLockBehavior'; Label = 'Num Lock when pressed'; Options = @( @{ Id = 'Toggle'; Name = 'Toggle its state' }, @{ Id = 'Ignore'; Name = 'Ignore the keystroke' } ) }
                    @{ Select = 'ScrollLockInitial'; Label = 'Scroll Lock at sign-in'; Options = @( @{ Id = 'Off'; Name = 'Off' }, @{ Id = 'On'; Name = 'On' } ) }
                    @{ Select = 'ScrollLockBehavior'; Label = 'Scroll Lock when pressed'; Options = @( @{ Id = 'Toggle'; Name = 'Toggle its state' }, @{ Id = 'Ignore'; Name = 'Ignore the keystroke' } ) }
                ) }
            ) }
        ) }
        @{ Title = 'Sticky keys'; Items = @(
            @{ Radio = 'StickyKeysMode'; Options = @(
                @{ Value = 'Default'; Label = 'Use the Windows default' }
                @{ Value = 'Disabled'; Label = 'Disable Sticky Keys altogether' }
                @{ Value = 'Custom'; Label = 'Configure'; Items = @(
                    @{ Check = 'StickyKeysHotKeyActive'; Label = 'Press Shift five times to turn Sticky Keys on or off' }
                    @{ Check = 'StickyKeysHotKeySound'; Label = 'Play a sound when Sticky Keys are turned on or off with the shortcut' }
                    @{ Check = 'StickyKeysIndicator'; Label = 'Show the Sticky Keys icon on the taskbar' }
                    @{ Check = 'StickyKeysAudibleFeedback'; Label = 'Play a sound when modifier keys are pressed' }
                    @{ Check = 'StickyKeysTriState'; Label = 'Lock modifier keys when pressed twice in a row' }
                    @{ Check = 'StickyKeysTwoKeysOff'; Label = 'Turn off Sticky Keys when two keys are pressed at the same time' }
                ) }
            ) }
        ) }
        @{ Title = 'Personalization'; Items = @(
            @{ Radio = 'ColorMode'; Options = @(
                @{ Value = 'Default'; Label = 'Colors: Windows default' }
                @{ Value = 'Custom'; Label = 'Colors: custom'; Items = @(
                    @{ Select = 'SystemColorTheme'; Label = 'Windows mode (taskbar and Start)'; Options = @( @{ Id = 'Dark'; Name = 'Dark' }, @{ Id = 'Light'; Name = 'Light' } ) }
                    @{ Select = 'AppsColorTheme'; Label = 'App mode'; Options = @( @{ Id = 'Dark'; Name = 'Dark' }, @{ Id = 'Light'; Name = 'Light' } ) }
                    @{ Input = 'AccentColor'; Label = 'Accent color (#RRGGBB)' }
                    @{ Check = 'AccentColorOnStart'; Label = 'Show the accent color on Start and the taskbar' }
                    @{ Check = 'AccentColorOnBorders'; Label = 'Show the accent color on title bars and window borders' }
                    @{ Check = 'EnableTransparency'; Label = 'Transparency effects' }
                ) }
            ) }
            @{ Radio = 'WallpaperMode'; Options = @(
                @{ Value = 'Default'; Label = 'Desktop wallpaper: Windows default' }
                @{ Value = 'Solid'; Label = 'Desktop wallpaper: a solid color'; Items = @( @{ Input = 'WallpaperColor'; Label = 'Color (#RRGGBB)' } ) }
                @{ Value = 'Script'; Label = 'Desktop wallpaper: an image from a PowerShell script'; Items = @( @{ Input = 'WallpaperScript'; Label = 'PowerShell (returns the image bytes)'; Kind = 'Multi' } ) }
            ) }
            @{ Radio = 'LockScreenMode'; Options = @(
                @{ Value = 'Default'; Label = 'Lock screen: Windows default' }
                @{ Value = 'Script'; Label = 'Lock screen: an image from a PowerShell script'; Items = @( @{ Input = 'LockScreenScript'; Label = 'PowerShell (returns the image bytes)'; Kind = 'Multi' } ) }
            ) }
        ) }
        @{ Title = 'Remove bloatware'; Items = @(
            @{ Note = 'Removed apps can be hard to get back: some are not in the Microsoft Store.' }
            @{ Bloatware = $true }
        ) }
        @{ Title = 'Run custom scripts'; Items = @(
            @{ Scripts = 'System'; Label = 'Scripts that run in the system context, before user accounts are created' }
            @{ Scripts = 'DefaultUser'; Label = 'Scripts that modify the default user''s registry hive (HKU\DefaultUser), for every new account' }
            @{ Scripts = 'FirstLogon'; Label = 'Scripts that run when the first user signs in' }
            @{ Scripts = 'UserOnce'; Label = 'Scripts that run once for each user, at their first sign-in' }
            @{ Check = 'RestartExplorer'; Label = 'Restart File Explorer after the scripts have run' }
        ) }
        @{ Title = 'AppLocker'; Items = @(
            @{ Radio = 'AppLockerMode'; Options = @(
                @{ Value = 'Skip'; Label = 'Do not configure an AppLocker policy' }
                @{ Value = 'Configure'; Label = 'Apply this AppLocker policy'; Items = @( @{ Input = 'AppLockerPolicyXml'; Label = 'AppLocker policy XML'; Kind = 'Multi' } ) }
            ) }
        ) }
        @{ Title = 'XML markup for more components'; Items = @(
            @{ Note = 'Each component''s XML replaces what the generator writes for it (no settings or component elements).' }
            @{ Components = $true }
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
        HideFiles = 'Hidden'; TaskbarSearch = 'Box'; TaskbarIconsMode = 'Default'; StartTilesMode = 'Default'; StartPinsMode = 'Default'
        EffectsMode = 'Default'; ControlAnimations = 'true'; AnimateMinMax = 'true'; TaskbarAnimations = 'true'; DWMAeroPeekEnabled = 'true'; MenuAnimation = 'true'
        TooltipAnimation = 'true'; SelectionFade = 'true'; DWMSaveThumbnailEnabled = 'true'; CursorShadow = 'true'; DropShadow = 'true'; ThumbnailsOrIcon = 'true'
        ListviewAlphaSelect = 'true'; DragFullWindows = 'true'; ComboBoxAnimation = 'true'; FontSmoothing = 'true'; ListBoxSmoothScrolling = 'true'; ListviewShadow = 'true'
        DesktopIconsMode = 'Default'; IconRecycleBin = 'true'; StartFoldersMode = 'Default'; StartFolderSettings = 'true'; StartFolderFileExplorer = 'true'
        CoreIsolationMode = 'Enabled'; LockKeysMode = 'Skip'; CapsLockInitial = 'Off'; CapsLockBehavior = 'Toggle'; NumLockInitial = 'Off'; NumLockBehavior = 'Toggle'
        ScrollLockInitial = 'Off'; ScrollLockBehavior = 'Toggle'; StickyKeysMode = 'Default'; StickyKeysHotKeyActive = 'true'; StickyKeysHotKeySound = 'true'
        StickyKeysIndicator = 'true'; StickyKeysAudibleFeedback = 'true'; StickyKeysTriState = 'true'; StickyKeysTwoKeysOff = 'true'
        ColorMode = 'Default'; SystemColorTheme = 'Dark'; AppsColorTheme = 'Dark'; AccentColor = '#0078D4'; EnableTransparency = 'true'
        WallpaperMode = 'Default'; WallpaperColor = '#008080'; LockScreenMode = 'Default'; AppLockerMode = 'Skip'
    }
}
