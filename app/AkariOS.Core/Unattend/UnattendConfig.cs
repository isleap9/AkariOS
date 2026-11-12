using System.Collections.Immutable;
using System.Drawing;
using System.Globalization;
using Schneegans.Unattend;
using SProcessorArchitecture = Schneegans.Unattend.ProcessorArchitecture;

namespace AkariOS.Core.Unattend;

/// <summary>
/// His form's fields as his library's <see cref="Configuration"/>: what his site does with the form before it calls
/// the library (not in his repo). The rules are the PowerShell port's, which reads the same fields inside its modifiers
/// (src\Core\Unattend\*.ps1): a missing field takes the same default, a checkbox is on when "true" / "on", a branch
/// counts only when its mode picks it.
/// </summary>
public static class UnattendConfig
{
    public static Configuration From(IReadOnlyDictionary<string, string[]> f, UnattendGenerator g)
    {
        var pe = PEMode(f);
        return Configuration.Default with
        {
            LanguageSettings = Language(f, g),
            AccountSettings = Accounts(f),
            LockoutSettings = f.Get("LockoutMode", "Default") switch
            {
                "Disabled" => new DisableLockoutSettings(),
                "Custom" => new CustomLockoutSettings(Int(f, "LockoutThreshold"), Int(f, "LockoutDuration"), Int(f, "LockoutWindow")),
                _ => new DefaultLockoutSettings(),
            },
            PasswordExpirationSettings = f.Get("PasswordExpirationMode", "Default") switch
            {
                "Unlimited" => new UnlimitedPasswordExpirationSettings(),
                "Custom" => new CustomPasswordExpirationSettings(Int(f, "PasswordMaxAge")),
                _ => new DefaultPasswordExpirationSettings(),
            },
            ProcessAuditSettings = f.On("ProcessAudit")
                ? new EnabledProcessAuditSettings(IncludeCommandLine: f.On("ProcessAuditCommandLine"))
                : new DisabledProcessAuditSettings(),
            ComputerNameSettings = f.Get("ComputerNameMode", "Random") switch
            {
                "Custom" => new CustomComputerNameSettings(f.Get("ComputerName")),
                "Script" => new ScriptComputerNameSettings(f.Get("ComputerNameScript")),
                "Prompt" => new PromptComputerNameSettings(),
                _ => new RandomComputerNameSettings(),
            },
            TimeZoneSettings = f.Get("TimeZoneMode", "Implicit") == "Explicit"
                ? g.CreateExplicitTimeZoneSettings(f.Get("TimeZone"))
                : new ImplicitTimeZoneSettings(),
            WifiSettings = f.Get("WifiMode", "Interactive") switch
            {
                "Interactive" => new InteractiveWifiSettings(),
                "Skip" => new SkipWifiSettings(),
                "FromProfile" => new XmlWifiSettings(f.Get("WifiProfileXml")),
                _ => new ParameterizedWifiSettings(
                    Name: f.Get("WifiName"),
                    Password: f.Get("WifiPassword"),
                    ConnectAutomatically: true,
                    Authentication: Parse<WifiAuthentications>(f.Get("WifiAuthentication", "WPA2PSK")),
                    NonBroadcast: f.On("WifiNonBroadcast")),
            },
            AppLockerSettings = f.Get("AppLockerMode", "Skip") == "Configure"
                ? new ConfigureAppLockerSettings(f.Get("AppLockerPolicyXml"))
                : new SkipAppLockerSettings(),
            ProcessorArchitectures = [.. (f.TryGetValue("ProcessorArchitecture", out var a) ? a : [])
                .Where(v => v.Length > 0).Select(Parse<SProcessorArchitecture>)],
            Components = Components(f),
            Bloatwares = [.. g.Bloatwares.Values.Where(b => f.On(b.Id))],
            ExpressSettings = f.Get("ExpressSettings", "DisableAll") switch
            {
                "Interactive" => ExpressSettingsMode.Interactive,
                "EnableAll" => ExpressSettingsMode.EnableAll,
                _ => ExpressSettingsMode.DisableAll,
            },
            ScriptSettings = new ScriptSettings(Scripts: Scripts(f), RestartExplorer: f.On("RestartExplorer")),
            LockKeySettings = f.Get("LockKeysMode", "Skip") == "Configure"
                ? new ConfigureLockKeySettings(LockKey(f, "CapsLock"), LockKey(f, "NumLock"), LockKey(f, "ScrollLock"))
                : new SkipLockKeySettings(),
            WallpaperSettings = f.Get("WallpaperMode", "Default") switch
            {
                "Script" => new ScriptWallpaperSettings(f.Get("WallpaperScript")),
                "Solid" => new SolidWallpaperSettings(Html(f.Get("WallpaperColor", "#008080"))),
                _ => new DefaultWallpaperSettings(),
            },
            LockScreenSettings = f.Get("LockScreenMode", "Default") == "Script"
                ? new ScriptLockScreenSettings(f.Get("LockScreenScript"))
                : new DefaultLockScreenSettings(),
            ColorSettings = f.Get("ColorMode", "Default") == "Custom"
                ? new CustomColorSettings(
                    SystemTheme: Theme(f, "SystemColorTheme"),
                    AppsTheme: Theme(f, "AppsColorTheme"),
                    EnableTransparency: f.On("EnableTransparency"),
                    AccentColorOnStart: f.On("AccentColorOnStart"),
                    AccentColorOnBorders: f.On("AccentColorOnBorders"),
                    AccentColor: Html(f.Get("AccentColor", "#0078D4")))
                : new DefaultColorSettings(),
            PESettings = pe switch
            {
                "Generated" => Generated(f, g),
                "Script" => new ScriptPESetttings(f.Get("PEScript")),
                _ => new DefaultPESettings(Edition(f, g), BypassRequirementsCheck: f.On("BypassRequirementsCheck")),
            },
            ActivationKey = f.On("UseActivationKey") && f.Get("ActivationKey").Length > 0 ? new ProductKey(f.Get("ActivationKey")) : null,
            BypassNetworkCheck = f.On("BypassNetworkCheck"),
            EnableLongPaths = f.On("EnableLongPaths"),
            EnableRemoteDesktop = f.On("EnableRemoteDesktop"),
            HardenSystemDriveAcl = f.On("HardenSystemDriveAcl"),
            DeleteJunctions = f.On("DeleteJunctions"),
            AllowPowerShellScripts = f.On("AllowPowerShellScripts"),
            DisableLastAccess = f.On("DisableLastAccess"),
            PreventAutomaticReboot = f.On("PreventAutomaticReboot"),
            DisableSac = f.On("DisableSac"),
            DisableUac = f.On("DisableUac"),
            DisableSmartScreen = f.On("DisableSmartScreen"),
            DisableSystemRestore = f.On("DisableSystemRestore"),
            DisableFastStartup = f.On("DisableFastStartup"),
            TurnOffSystemSounds = f.On("TurnOffSystemSounds"),
            DisableAppSuggestions = f.On("DisableAppSuggestions"),
            DisableWidgets = f.On("DisableWidgets"),
            VBoxGuestAdditions = f.On("VBoxGuestAdditions"),
            VMwareTools = f.On("VMwareTools"),
            VirtIoGuestTools = f.On("VirtIoGuestTools"),
            ParallelsTools = f.On("ParallelsTools"),
            PreventDeviceEncryption = f.On("PreventDeviceEncryption"),
            ClassicContextMenu = f.On("ClassicContextMenu"),
            LeftTaskbar = f.On("LeftTaskbar"),
            HideTaskViewButton = f.On("HideTaskViewButton"),
            ShowFileExtensions = f.On("ShowFileExtensions"),
            ShowAllTrayIcons = f.On("ShowAllTrayIcons"),
            HideFiles = Parse<HideModes>(f.Get("HideFiles", "Hidden")),
            HideEdgeFre = f.On("HideEdgeFre"),
            DisableEdgeStartupBoost = f.On("DisableEdgeStartupBoost"),
            MakeEdgeUninstallable = f.On("MakeEdgeUninstallable"),
            DeleteEdgeDesktopIcon = f.On("DeleteEdgeDesktopIcon"),
            LaunchToThisPC = f.On("LaunchToThisPC"),
            DisableWindowsUpdate = f.On("DisableWindowsUpdate"),
            DisablePointerPrecision = f.On("DisablePointerPrecision"),
            DeleteWindowsOld = f.On("DeleteWindowsOld"),
            DisableBingResults = f.On("DisableBingResults"),
            HidePowerShellWindows = f.On("HidePowerShellWindows"),
            ShowEndTask = f.On("ShowEndTask"),
            KeepSensitiveFiles = f.On("KeepSensitiveFiles"),
            UseNarrator = f.On("UseNarrator"),
            DisableCoreIsolation = f.Get("CoreIsolationMode", "Enabled") == "Disabled",
            DisableAutomaticRestartSignOn = f.On("DisableAutomaticRestartSignOn"),
            HideInfoTip = f.On("HideInfoTip"),
            DisableWpbt = f.On("DisableWpbt"),
            PreventDeviceApps = f.On("PreventDeviceApps"),
            TaskbarSearch = Parse<TaskbarSearchMode>(f.Get("TaskbarSearch", "Box")),
            StartPinsSettings = f.Get("StartPinsMode", "Default") switch
            {
                "Empty" => new EmptyStartPinsSettings(),
                "Custom" => new CustomStartPinsSettings(f.Get("StartPinsJson")),
                _ => new DefaultStartPinsSettings(),
            },
            StartTilesSettings = f.Get("StartTilesMode", "Default") switch
            {
                "Empty" => new EmptyStartTilesSettings(),
                "Custom" => new CustomStartTilesSettings(f.Get("StartTilesXml")),
                _ => new DefaultStartTilesSettings(),
            },
            TaskbarIcons = f.Get("TaskbarIconsMode", "Default") switch
            {
                "Empty" => new EmptyTaskbarIcons(),
                "Custom" => new CustomTaskbarIcons(f.Get("TaskbarIconsXml")),
                _ => new DefaultTaskbarIcons(),
            },
            Effects = f.Get("EffectsMode", "Default") switch
            {
                "Default" => new DefaultEffects(),
                "Appearance" => new BestAppearanceEffects(),
                "Performance" => new BestPerformanceEffects(),
                _ => new CustomEffects(Enum.GetValues<Effect>().ToImmutableDictionary(e => e, e => f.On(e.ToString()))),
            },
            DesktopIcons = f.Get("DesktopIconsMode", "Default") == "Custom"
                ? new CustomDesktopIconSettings(g.DesktopIcons.Values.ToDictionary(i => i, i => f.On("Icon" + i.Id)))
                : new DefaultDesktopIconSettings(),
            StickyKeysSettings = f.Get("StickyKeysMode", "Default") switch
            {
                "Default" => new DefaultStickyKeysSettings(),
                "Custom" => new CustomStickyKeysSettings(Enum.GetValues<StickyKeys>().Where(k => f.On("StickyKeys" + k)).ToHashSet()),
                _ => new DisabledStickyKeysSettings(),
            },
            StartFolderSettings = f.Get("StartFoldersMode", "Default") == "Custom"
                ? new CustomStartFolderSettings(g.StartFolders.Values.ToDictionary(s => s, s => f.On("StartFolder" + s.Id)))
                : new DefaultStartFolderSettings(),
        };
    }

    /// <summary>The PE stage his site uses: Default turns Generated when the partitioning isn't left to setup.</summary>
    public static string PEMode(IReadOnlyDictionary<string, string[]> f)
    {
        var m = f.Get("PEMode", "Default");
        return m == "Default" && f.Get("PartitionMode", "Interactive") != "Interactive" ? "Generated" : m;
    }

    private static ILanguageSettings Language(IReadOnlyDictionary<string, string[]> f, UnattendGenerator g)
    {
        if (f.Get("LanguageMode", "Interactive") != "Unattended") return new InteractiveLanguageSettings();
        LocaleAndKeyboard Pair(string n) => new(g.Lookup<UserLocale>(f.Get("Locale" + n)), g.Lookup<KeyboardIdentifier>(f.Get("Keyboard" + n)));
        return new UnattendedLanguageSettings(
            ImageLanguage: g.Lookup<ImageLanguage>(f.Get("UILanguage")),
            LocaleAndKeyboard: Pair(""),
            LocaleAndKeyboard2: f.On("UseKeyboard2") ? Pair("2") : null,
            LocaleAndKeyboard3: f.On("UseKeyboard3") ? Pair("3") : null,
            GeoLocation: g.Lookup<GeoLocation>(f.Get("GeoLocation")));
    }

    private static IAccountSettings Accounts(IReadOnlyDictionary<string, string[]> f)
    {
        switch (f.Get("UserAccountMode", "Interactive"))
        {
            case "Unattended":
                var accounts = Enumerable.Range(0, 15)
                    .Where(i => f.Get($"AccountName{i}").Length > 0)
                    .Select(i => new Account(f.Get($"AccountName{i}"), f.Get($"AccountDisplayName{i}"), f.Get($"AccountPassword{i}"),
                        f.Get($"AccountGroup{i}", Constants.UsersGroup)))
                    .ToImmutableList();
                IAutoLogonSettings logon = f.Get("AutoLogonMode", "None") switch
                {
                    "Builtin" => new BuiltinAutoLogonSettings(f.Get("BuiltinAdministratorPassword")),
                    "Own" => new OwnAutoLogonSettings(),
                    _ => new NoneAutoLogonSettings(),
                };
                return new UnattendedAccountSettings(accounts, logon, obscurePasswords: f.On("ObscurePasswords"));
            case "InteractiveLocal":
                return new InteractiveLocalAccountSettings();
            default:
                return new InteractiveMicrosoftAccountSettings();
        }
    }

    private static IEditionSettings Edition(IReadOnlyDictionary<string, string[]> f, UnattendGenerator g) =>
        f.Get("WindowsEditionMode", "Interactive") switch
        {
            "Generic" => new UnattendedEditionSettings(g.Lookup<WindowsEdition>(f.Get("WindowsEdition"))),
            "Custom" => new CustomEditionSettings(new ProductKey(f.Get("ProductKey"))),
            "Firmware" => new FirmwareEditionSettings(),
            _ => new InteractiveEditionSettings(),
        };

    private static GeneratePESettings Generated(IReadOnlyDictionary<string, string[]> f, UnattendGenerator g) => new(
        PartitionSettings: f.Get("PartitionMode", "Unattended") switch
        {
            "Custom" => new CustomPartitionSettings(f.Get("DiskpartScript")),
            "Unattended" => new UnattendedPartitionSettings(
                TargetDiskSettings: f.Get("TargetDiskMode", "Generated") switch
                {
                    "Interactive" => new InteractiveTargetDiskSettings(),
                    "Script" => new ScriptTargetDiskSettings(f.Get("TargetDiskScript")),
                    _ => new GeneratedTargetDiskSettings(
                        minSizeGiB: f.On("TargetDiskSize") ? Int(f, "TargetDiskMinSize") : null,
                        maxSizeGiB: f.On("TargetDiskSize") ? Int(f, "TargetDiskMaxSize") : null,
                        index: f.On("TargetDiskIndex") ? Int(f, "TargetDisk", "0") : null,
                        assertNoPartitions: f.On("TargetDiskNoPartitions"),
                        assertInterfaceType: f.On("TargetDiskInterfaceType"),
                        assertMediaType: f.On("TargetDiskMediaType")),
                },
                PartitionLayout: Parse<PartitionLayout>(f.Get("PartitionLayout", "GPT")),
                RecoveryMode: Parse<RecoveryMode>(f.Get("RecoveryMode", "Partition")),
                SystemSize: Int(f, "SystemSize", "300") ?? Constants.SystemPartitionSize,
                RecoverySize: Int(f, "RecoverySize", "1000") ?? Constants.RecoveryPartitionSize),
            _ => new InteractivePartitionSettings(),
        },
        InstallFromSettings: f.Get("InstallFromMode", "Edition") switch
        {
            "Index" => new IndexInstallFromSettings(Int(f, "InstallFromIndex", "1") ?? 1),
            "Name" => new NameInstallFromSettings(f.Get("InstallFromName")),
            "Interactive" => new InteractiveInstallFromSettings(),
            _ => new EditionInstallFromSettings(g.Lookup<WindowsEdition>(f.Get("InstallFromEdition"))),
        },
        PagingFileSettings: f.Get("PagingFileMode", "Automatic") switch
        {
            "None" => new NoPagingFileSettings(),
            "Custom" => new CustomPagingFileSettings(Validation.InRange(Int(f, "InitPagingFileSize")), Validation.InRange(Int(f, "MaxPagingFileSize"))),
            _ => new AutomaticPagingFileSettings(),
        },
        DisableDefender: f.On("DisableDefender"),
        Disable8Dot3Names: f.On("Disable8Dot3Names"),
        PauseBeforeFormatting: f.On("PauseBeforeFormatting"),
        PauseBeforeReboot: f.On("PauseBeforeReboot"),
        CompactOs: f.On("CompactOs"),
        SkipIntegrityCheck: f.On("SkipIntegrityCheck"));

    /// <summary>The extra components, in row order: his dictionary enumerates by hash, so the key comparer hashes a
    /// component to its row.</summary>
    private static ImmutableDictionary<ComponentAndPass, string> Components(IReadOnlyDictionary<string, string[]> f)
    {
        var rows = new List<(ComponentAndPass Key, string Xml)>();
        for (var i = 0; i < 15; i++)
        {
            var v = f.Get($"Component{i}");
            if (v.Length == 0) continue;
            var cut = v.LastIndexOf('-');
            rows.Add((new ComponentAndPass(v[..cut], Parse<Pass>(v[(cut + 1)..])), f.Get($"ComponentContent{i}")));
        }
        var comparer = new RowOrder([.. rows.Select(r => r.Key)]);
        return ImmutableDictionary.CreateRange(comparer, rows.Select(r => KeyValuePair.Create(r.Key, r.Xml)));
    }

    private sealed class RowOrder(List<ComponentAndPass> rows) : IEqualityComparer<ComponentAndPass>
    {
        public bool Equals(ComponentAndPass x, ComponentAndPass y) => x.Equals(y);
        public int GetHashCode(ComponentAndPass k) => rows.IndexOf(k);
    }

    /// <summary>The custom scripts in his phase order, rows 0-14 with text in each.</summary>
    private static List<Script> Scripts(IReadOnlyDictionary<string, string[]> f)
    {
        var scripts = new List<Script>();
        foreach (var phase in Enum.GetValues<ScriptPhase>())
            for (var i = 0; i < 15; i++)
            {
                var content = f.Get($"{phase}Script{i}");
                if (string.IsNullOrWhiteSpace(content)) continue;
                scripts.Add(new Script(content, phase, Parse<ScriptType>(f.Get($"{phase}ScriptType{i}", "Cmd"))));
            }
        return scripts;
    }

    private static LockKeySetting LockKey(IReadOnlyDictionary<string, string[]> f, string key) =>
        new(Parse<LockKeyInitial>(f.Get(key + "Initial", "Off")), Parse<LockKeyBehavior>(f.Get(key + "Behavior", "Toggle")));

    private static ColorTheme Theme(IReadOnlyDictionary<string, string[]> f, string name) =>
        f.Get(name, "Light") == "Dark" ? ColorTheme.Dark : ColorTheme.Light;

    private static Color Html(string color)
    {
        try { return ColorTranslator.FromHtml(color); }
        catch (Exception e) when (e is ArgumentException or FormatException) { throw new ConfigurationException($"'{color}' is not a color."); }
    }

    private static int? Int(IReadOnlyDictionary<string, string[]> f, string name, string fallback = "") =>
        int.TryParse(f.Get(name, fallback), NumberStyles.Integer, CultureInfo.InvariantCulture, out var v) ? v : null;

    private static T Parse<T>(string value) where T : struct, Enum =>
        System.Enum.TryParse<T>(value, ignoreCase: true, out var v) && System.Enum.IsDefined(v)
            ? v
            : throw new ConfigurationException($"'{value}' is not a valid {typeof(T).Name}.");
}
