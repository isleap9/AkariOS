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

    /// <summary>A folder (the Unattend Generator's "Save to a folder…").</summary>
    string? Folder(string description);

    /// <summary>An answer file to read (the Unattend Generator's "Open file…").</summary>
    string? OpenXml();

    /// <summary>A Windows ISO to open (the ISO Builder's "Browse…").</summary>
    string? OpenIso();
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

    public string? Folder(string description)
    {
        var d = new OpenFolderDialog { Title = description };
        return d.ShowDialog() == true ? d.FolderName : null;
    }

    public string? OpenXml()
    {
        var d = new OpenFileDialog { Filter = "Answer files (*.xml)|*.xml|All files (*.*)|*.*" };
        return d.ShowDialog() == true ? d.FileName : null;
    }

    public string? OpenIso()
    {
        var d = new OpenFileDialog { Filter = "Windows ISO (*.iso)|*.iso|All files (*.*)|*.*" };
        return d.ShowDialog() == true ? d.FileName : null;
    }
}
