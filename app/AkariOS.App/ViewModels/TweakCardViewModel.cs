using AkariOS.Core.Registry;
using AkariOS.Core.Runs;
using AkariOS.Core.Tweaks;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;

namespace AkariOS.App.ViewModels;

/// <summary>A Choice's value in a card's dropdown, its label noting Recommended / Windows default.</summary>
public sealed record ChoiceItem(string Label, object? Value)
{
    public override string ToString() => Label;
}

/// <summary>
/// One settings card (New-AkariCatalogueCard): name, id, badges, description, marks, the State line, and its control:
/// a switch (Toggle), a dropdown (Choice) or a button (Action). One per Tweak, kept by <see cref="CatalogueViewModel"/>.
/// A change from the control goes to <c>changed</c> (Apply or Revert, a Choice value other than Recommended); the
/// control is set back from the State with no change coming of it.
/// </summary>
public sealed partial class TweakCardViewModel : ObservableObject
{
    private readonly Action<TweakCardViewModel, TweakMode, object?> _changed;
    private bool _muted;
    private bool _isOn;
    private object? _selectedChoice;

    public TweakCardViewModel(Tweak t, object? windowsDefault, Action<TweakCardViewModel, TweakMode, object?> changed)
    {
        Tweak = t;
        WindowsDefault = windowsDefault;
        _changed = changed;
        NotNative = Runner.NotNative(t);
        Choices = t.Choices.Select(c =>
        {
            var label = c.Label.Length > 0 ? c.Label : $"{c.Value}";
            if (RegistryEngine.Matches(c.Value, t.Recommended)) label += " (Recommended)";
            else if (RegistryEngine.Matches(c.Value, windowsDefault)) label += " (Windows default)";
            return new ChoiceItem(label, c.Value);
        }).ToList();
        Update();
    }

    public Tweak Tweak { get; }

    /// <summary>A Choice's Windows default on this PC.</summary>
    public object? WindowsDefault { get; }

    /// <summary>Why the native app can't change it yet (its control is off), or null.</summary>
    public string? NotNative { get; }

    public TweakState State { get; set; } = TweakState.Unknown;
    public object? Current { get; set; }
    public CatalogueBusy Busy { get; set; }
    public string Error { get; set; } = "";

    public string Name => Tweak.Name;
    public string Id => Tweak.Id;
    public string Description => Tweak.Description ?? "";
    public bool HasDescription => Description.Length > 0;
    public bool IsToggle => Tweak.Kind == TweakKind.Toggle;
    public bool IsChoice => Tweak.Kind == TweakKind.Choice;
    public bool IsAction => Tweak.Kind == TweakKind.Action;
    public string ButtonText => Tweak.Button;
    public bool IsAkariOS => Tweak.AkariOS;
    public string RiskBadge => Tweak.Risk is Risk.Caution or Risk.Advanced ? Tweak.Risk.ToString() : "";
    public bool HasRiskBadge => RiskBadge.Length > 0;
    public bool Reboots => Tweak.Reboot;
    public bool InSafeMode => Tweak.SafeMode;
    public bool IsNotNative => NotNative is not null;
    public string NotNativeText => NotNative is null ? "" : $"Not in the native app yet ({NotNative}): the PowerShell app can change it today.";
    public IReadOnlyList<ChoiceItem> Choices { get; }

    [ObservableProperty]
    public partial string StateLine { get; private set; } = "";

    /// <summary>The State line's tone: a failure, a change waiting for Safe Mode, or plain.</summary>
    [ObservableProperty]
    [NotifyPropertyChangedFor(nameof(ShowPlainLine), nameof(ShowWarnLine), nameof(ShowErrorLine))]
    public partial LineTone Tone { get; private set; }

    public bool ShowPlainLine => Tone == LineTone.Plain && StateLine.Length > 0;
    public bool ShowWarnLine => Tone == LineTone.Warn;
    public bool ShowErrorLine => Tone == LineTone.Error;

    [ObservableProperty]
    public partial bool IsEnabled { get; private set; } = true;

    /// <summary>A Toggle's switch: on = Optimized (Custom and Unknown show off; the State line says which).</summary>
    public bool IsOn
    {
        get => _isOn;
        set
        {
            if (!SetProperty(ref _isOn, value) || _muted) return;
            _changed(this, value ? TweakMode.Apply : TweakMode.Revert, null);
        }
    }

    /// <summary>A Choice's dropdown: a <see cref="ChoiceItem"/>, or null for a value none of them is.</summary>
    public object? SelectedChoice
    {
        get => _selectedChoice;
        set
        {
            if (!SetProperty(ref _selectedChoice, value) || _muted || value is not ChoiceItem { Value: var v }) return;
            if (RegistryEngine.Matches(v, WindowsDefault)) _changed(this, TweakMode.Revert, null);
            else if (RegistryEngine.Matches(v, Tweak.Recommended)) _changed(this, TweakMode.Apply, null);
            else _changed(this, TweakMode.Apply, v);
        }
    }

    /// <summary>An Action's button.</summary>
    [RelayCommand]
    private void Run() => _changed(this, TweakMode.Apply, null);

    /// <summary>The State line and the control after a change of State, Busy, Error or the Safe Mode waiting list
    /// (Set-AkariCatalogueCard): a change waiting for Safe Mode shows what it will be.</summary>
    public void Update(SafeChange? pending = null)
    {
        if (Error.Length > 0)
        {
            StateLine = $"Failed: {Error}";
            Tone = LineTone.Error;
        }
        else
        {
            StateLine = Catalogue.StateText(Tweak, State, Busy, pending is not null);
            Tone = pending is not null ? LineTone.Warn : LineTone.Plain;
        }
        OnPropertyChanged(nameof(ShowPlainLine));
        IsEnabled = Busy == CatalogueBusy.None && NotNative is null;
        _muted = true;
        try
        {
            if (IsToggle)
            {
                // set through the property: a switch the user just moved goes back when the change didn't happen
                _isOn = !(pending is not null ? pending.Mode == TweakMode.Apply : State == TweakState.Optimized);
                IsOn = !_isOn;
            }
            else if (IsChoice)
            {
                var show = pending is null ? Current : pending.Value ?? (pending.Mode == TweakMode.Apply ? Tweak.Recommended : WindowsDefault);
                _selectedChoice = this;
                SelectedChoice = show is null ? null : Choices.FirstOrDefault(i => RegistryEngine.Matches(show, i.Value));
            }
        }
        finally { _muted = false; }
    }
}

public enum LineTone { Plain, Warn, Error }
