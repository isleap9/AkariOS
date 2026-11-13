using System.Net.Http.Headers;
using System.Text.Json;

namespace AkariOS.Core.Update;

/// <summary>The real GitHub API (Invoke-AkariGitHubApi; guarded): GET https://api.github.com/&lt;path&gt;, never
/// throws.</summary>
public sealed class GitHubApi : IGitHub
{
    private static readonly HttpClient Http = MakeClient(TimeSpan.FromSeconds(15));

    public GitHubApi() => SystemGuard.Check("GitHub");

    internal static HttpClient MakeClient(TimeSpan timeout)
    {
        var c = new HttpClient { Timeout = timeout };
        c.DefaultRequestHeaders.UserAgent.Add(new ProductInfoHeaderValue("AkariOS", AkariInfo.Version));
        return c;
    }

    public GitHubAnswer Get(string path)
    {
        try
        {
            using var request = new HttpRequestMessage(HttpMethod.Get, $"https://api.github.com/{path}");
            request.Headers.Accept.Add(new MediaTypeWithQualityHeaderValue("application/vnd.github+json"));
            using var response = Http.Send(request);
            if (response.IsSuccessStatusCode)
            {
                using var body = response.Content.ReadAsStream();
                return new((int)response.StatusCode, JsonDocument.Parse(body).RootElement.Clone(), null);
            }
            var remaining = response.Headers.TryGetValues("X-RateLimit-Remaining", out var r) ? r.FirstOrDefault() : null;
            var reset = response.Headers.TryGetValues("X-RateLimit-Reset", out var t) ? t.FirstOrDefault() : null;
            return new(StatusOf((int)response.StatusCode, remaining), null, ResetOf(reset));
        }
        catch (Exception e) when (e is HttpRequestException or TaskCanceledException or JsonException or IOException)
        {
            return new(0, null, null);
        }
    }

    /// <summary>GitHub's rate limit answers 403 with no requests left: that is 429 here.</summary>
    public static int StatusOf(int status, string? remaining) => status == 403 && remaining == "0" ? 429 : status;

    /// <summary>X-RateLimit-Reset (Unix seconds) as local time.</summary>
    public static DateTime? ResetOf(string? header) =>
        long.TryParse(header, out var s) ? DateTimeOffset.FromUnixTimeSeconds(s).LocalDateTime : null;
}

/// <summary>The real download (Save-AkariUpdateFile; guarded).</summary>
public sealed class HttpDownloads : IHttp
{
    private static readonly HttpClient Http = GitHubApi.MakeClient(TimeSpan.FromMinutes(10));

    public HttpDownloads() => SystemGuard.Check("Downloads");

    public void Download(string url, string file) => Download(url, file, null);

    public void Download(string url, string file, IReadOnlyDictionary<string, string>? headers)
    {
        using var response = Send(url, headers, HttpCompletionOption.ResponseHeadersRead);
        using var body = response.Content.ReadAsStream();
        using var f = File.Create(file);
        body.CopyTo(f);
    }

    public string Text(string url, IReadOnlyDictionary<string, string>? headers = null)
    {
        using var response = Send(url, headers, HttpCompletionOption.ResponseContentRead);
        return response.Content.ReadAsStringAsync().GetAwaiter().GetResult();
    }

    public void Post(string url, IReadOnlyDictionary<string, string> form, string file)
    {
        using var request = new HttpRequestMessage(HttpMethod.Post, url) { Content = new FormUrlEncodedContent(form) };
        using var response = Http.SendAsync(request, HttpCompletionOption.ResponseHeadersRead).GetAwaiter().GetResult();
        response.EnsureSuccessStatusCode();
        using var body = response.Content.ReadAsStream();
        using var f = File.Create(file);
        body.CopyTo(f);
    }

    // a header given here replaces the client's own (a browser's User-Agent for AMD's site)
    private static HttpResponseMessage Send(string url, IReadOnlyDictionary<string, string>? headers, HttpCompletionOption completion)
    {
        using var request = new HttpRequestMessage(HttpMethod.Get, url);
        foreach (var (k, v) in headers ?? new Dictionary<string, string>()) request.Headers.TryAddWithoutValidation(k, v);
        var response = Http.SendAsync(request, completion).GetAwaiter().GetResult();
        try { response.EnsureSuccessStatusCode(); }
        catch { response.Dispose(); throw; }
        return response;
    }
}
