using AkariOS.Core;
using Microsoft.Win32;

namespace AkariOS.App.Shell;

/// <summary>The file dialogs (Select-AkariSettingsFile): the path picked, or null. Tests use a fake.</summary>
public interface IFilePicker
{
    /// <summary>Where to save a settings file, starting on a suggested name.</summary>
    string? Save(string suggested);

    /// <summary>A settings file (or any preset) to read.</summary>
    string? Open();
}

/// <summary>The real dialogs, AkariOS settings (*.json) first (guarded: never shown in a test).</summary>
public sealed class FilePicker : IFilePicker
{
    private const string Filter = "AkariOS settings (*.json)|*.json|All files (*.*)|*.*";

    public FilePicker() => SystemGuard.Check("File dialogs");

    public string? Save(string suggested)
    {
        var d = new SaveFileDialog { Filter = Filter, FileName = suggested };
        return d.ShowDialog() == true ? d.FileName : null;
    }

    public string? Open()
    {
        var d = new OpenFileDialog { Filter = Filter };
        return d.ShowDialog() == true ? d.FileName : null;
    }
}
