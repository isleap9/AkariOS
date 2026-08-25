using Microsoft.UI.Xaml.Controls;
using AkariOS.App.ViewModels;

namespace AkariOS.App.Views;

/// <summary>Shared base for playbook wizard step pages.</summary>
public abstract class WizardStepPage : Page
{
    public abstract WizardStepKind Kind { get; }
}

public enum WizardStepKind
{
    License,
    SystemCheck,
    Configuration,
    Optimization,
    Finished,
}
