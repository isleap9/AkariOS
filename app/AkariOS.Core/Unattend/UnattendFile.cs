using System.Xml;
using Schneegans.Unattend;

namespace AkariOS.Core.Unattend;

/// <summary>A choice his generator refuses, with his message (a bad name, key, script…): the page shows it.</summary>
public sealed class UnattendException(string message, Exception inner) : Exception(message, inner);

/// <summary>
/// The answer file (src\Core\Unattend.ps1: New-AkariUnattend): Schneegans' vendored generator
/// (app/ThirdParty/UnattendGenerator) on the fields mapped by <see cref="UnattendConfig"/>, the choices written as the
/// first comment (his bookmark URL without passwords), serialized as he does it (ASCII, tabs, CRLF).
/// </summary>
public static class UnattendFile
{
    /// <summary>His generator, made once: it reads his data files.</summary>
    private static readonly Lazy<UnattendGenerator> Generator = new(() => new UnattendGenerator());

    public static UnattendGenerator His => Generator.Value;

    /// <summary>The file's bytes; a choice he refuses throws <see cref="UnattendException"/> with his message.</summary>
    public static byte[] Make(IReadOnlyDictionary<string, string[]> fields)
    {
        XmlDocument doc;
        try { doc = His.GenerateXml(UnattendConfig.From(fields, His)); }
        catch (Exception e) when (e is ConfigurationException or ArgumentException or XmlException or FormatException)
        {
            throw new UnattendException(e.Message, e);
        }
        doc.DocumentElement!.PrependChild(doc.CreateComment(UnattendQuery.To(fields)));
        return UnattendGenerator.Serialize(doc);
    }
}
