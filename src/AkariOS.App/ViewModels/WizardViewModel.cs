using CommunityToolkit.Mvvm.ComponentModel;

namespace AkariOS.App.ViewModels;

/// <summary>One step of the setup wizard's left-hand progress tracker.</summary>
public partial class WizardStep : ObservableObject
{
    public string Title { get; }
    public string Subtitle { get; }

    [ObservableProperty]
    public partial WizardStepState State { get; set; }

    public WizardStep(string title, string subtitle)
    {
        Title = title;
        Subtitle = subtitle;
        State = WizardStepState.Pending;
    }
}

public enum WizardStepState
{
    Pending,
    Active,
    Completed,
}

/// <summary>
/// Drives the wizard: ordered steps, current index, and Back/Next availability.
/// Pages supply per-step content; the shell only handles progression rules.
/// </summary>
public partial class WizardViewModel : ObservableObject
{
    private readonly Func<int, bool>? _canLeaveStep;

    public IReadOnlyList<WizardStep> Steps { get; }

    [ObservableProperty]
    [NotifyPropertyChangedFor(nameof(CurrentIndex))]
    [NotifyPropertyChangedFor(nameof(IsFirst))]
    [NotifyPropertyChangedFor(nameof(IsLast))]
    [NotifyPropertyChangedFor(nameof(CanGoBack))]
    public partial int CurrentIndex { get; set; }

    /// <summary>Raised after the current step changes (pages react, e.g. run checks).</summary>
    public event EventHandler<int>? StepEntered;

    public WizardStep Current => Steps[CurrentIndex];

    public int CurrentIndex1Based => CurrentIndex + 1;
    public bool IsFirst => CurrentIndex == 0;
    public bool IsLast => CurrentIndex == Steps.Count - 1;
    public bool CanGoBack => !IsFirst && CurrentIndex > LicenseIndex + 1
        || CurrentIndex == LicenseIndex + 1; // may return to license from system check

    /// <summary>The license step must be accepted before leaving it.</summary>
    public const int LicenseIndex = 0;

    [ObservableProperty]
    public partial bool LicenseAccepted { get; set; }

    /// <summary>Optional gate for leaving a given step (used by System Check).</summary>
    private readonly Dictionary<int, Func<bool>> _stepGates = new();

    public WizardViewModel(Func<int, bool>? canLeaveStep = null)
    {
        _canLeaveStep = canLeaveStep;
        Steps =
        [
            new WizardStep("License Agreement", "Terms of service review"),
            new WizardStep("System Check", "Requirements verification"),
            new WizardStep("Configuration", "Select options & features"),
            new WizardStep("Optimization", "Applying playbook changes"),
            new WizardStep("Finished", "System configuration complete"),
        ];
        Steps[0].State = WizardStepState.Active;
    }

    public void AddGate(int stepIndex, Func<bool> gate) => _stepGates[stepIndex] = gate;

    public bool CanLeave(int stepIndex) =>
        !_stepGates.TryGetValue(stepIndex, out var gate) || gate();

    /// <summary>Attempts to advance. Returns false if a gate blocks it.</summary>
    public bool TryNext()
    {
        if (IsLast) return false;
        if (!CanLeave(CurrentIndex)) return false;
        if (CurrentIndex == LicenseIndex && !LicenseAccepted) return false;

        Steps[CurrentIndex].State = WizardStepState.Completed;
        CurrentIndex++;
        Steps[CurrentIndex].State = WizardStepState.Active;
        RefreshNavigation();
        StepEntered?.Invoke(this, CurrentIndex);
        return true;
    }

    public void Back()
    {
        if (CanGoBack && !IsFirst)
        {
            // Leaving an active (not completed) step returns it to pending.
            if (Steps[CurrentIndex].State == WizardStepState.Active)
                Steps[CurrentIndex].State = WizardStepState.Pending;
            CurrentIndex--;
            Steps[CurrentIndex].State = WizardStepState.Completed;
            // Re-activate the one we came back to.
            Steps[CurrentIndex].State = WizardStepState.Active;
            RefreshNavigation();
            StepEntered?.Invoke(this, CurrentIndex);
        }
    }

    public void CompleteAll()
    {
        foreach (var s in Steps) s.State = WizardStepState.Completed;
        RefreshNavigation();
    }

    private void RefreshNavigation()
    {
        OnPropertyChanged(nameof(CurrentIndex));
        OnPropertyChanged(nameof(IsFirst));
        OnPropertyChanged(nameof(IsLast));
        OnPropertyChanged(nameof(CanGoBack));
        OnPropertyChanged(nameof(Current));
    }
}
