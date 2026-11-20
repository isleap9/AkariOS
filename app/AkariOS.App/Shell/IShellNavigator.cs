namespace AkariOS.App.Shell;

/// <summary>Opens a page by its key (NavTable): the window does it; view models get this, tests a recorder.</summary>
public interface IShellNavigator
{
    void Open(string key);
}

/// <summary>
/// The app's navigator: forwards to the window once it exists. Never the window itself through DI: the window's
/// constructor opens Home, whose view model needs a navigator, so resolving the window there made a second window,
/// which opened Home again, until the stack overflowed (the app closed before showing anything).
/// </summary>
public sealed class WindowNavigator(Func<IShellNavigator?> window) : IShellNavigator
{
    public void Open(string key) => window()?.Open(key);
}
