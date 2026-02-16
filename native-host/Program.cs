using System;
using System.Diagnostics;
using System.IO;
using System.Text;
using System.Text.Json;

namespace YtVlcHost;

internal static class Program
{
    private static string HostLog = @"D:\Projects\open_source\ytvlc\nm-host.log";
    private static string YtDlp   = @"E:\YTVideos\yt-dlp.exe";
    private static string Vlc     = @"C:\Program Files (x86)\VideoLAN\VLC\vlc.exe";

    private static void Log(string msg)
    {
        try { File.AppendAllText(HostLog, DateTime.UtcNow.ToString("O") + " " + msg + Environment.NewLine); } catch { }
    }

    private static byte[] ReadExact(Stream s, int n)
    {
        var buf = new byte[n];
        int off = 0;
        while (off < n)
        {
            int r = s.Read(buf, off, n - off);
            if (r <= 0) throw new EndOfStreamException();
            off += r;
        }
        return buf;
    }

    private static void Send(Stream stdout, object obj)
    {
        var json = JsonSerializer.Serialize(obj);
        var payload = Encoding.UTF8.GetBytes(json);
        var len = BitConverter.GetBytes(payload.Length);
        stdout.Write(len, 0, 4);
        stdout.Write(payload, 0, payload.Length);
        stdout.Flush();
    }

    private static string RunAndCapture(string exe, string args)
    {
        var psi = new ProcessStartInfo
        {
            FileName = exe,
            Arguments = args,
            UseShellExecute = false,
            RedirectStandardOutput = true,
            RedirectStandardError = true,
            CreateNoWindow = true
        };

        using var p = Process.Start(psi)!;
        string stdout = p.StandardOutput.ReadToEnd();
        string stderr = p.StandardError.ReadToEnd();
        p.WaitForExit();

        if (!string.IsNullOrWhiteSpace(stderr)) Log(exe + " stderr: " + stderr.Trim());
        Log(exe + " exit=" + p.ExitCode);

        return stdout;
    }

    private static void LaunchDetached(string exe, string arg)
    {
        var psi = new ProcessStartInfo
        {
            FileName = exe,
            Arguments = $"\"{arg}\"",
            UseShellExecute = false,
            CreateNoWindow = true
        };
        Process.Start(psi);
    }

    public static int Main(string[] args)
    {
        Log("host.exe started");
        Log("ytdlp=" + YtDlp);
        Log("vlc=" + Vlc);

        using var stdin = Console.OpenStandardInput();
        using var stdout = Console.OpenStandardOutput();

        while (true)
        {
            byte[] hdr;
            try { hdr = ReadExact(stdin, 4); }
            catch { break; }

            int len = BitConverter.ToInt32(hdr, 0);
            if (len <= 0 || len > 1024 * 1024) { Log("bad len=" + len); break; }

            var payload = ReadExact(stdin, len);
            var msgJson = Encoding.UTF8.GetString(payload);
            Log("msg: " + msgJson);

            // Always reply a framed response
            Send(stdout, new { status = "ok" });

            try
            {
                using var doc = JsonDocument.Parse(msgJson);
                if (!doc.RootElement.TryGetProperty("url", out var urlEl)) continue;

                var url = urlEl.GetString() ?? "";
                if (!url.Contains("youtube.com/watch", StringComparison.OrdinalIgnoreCase)) continue;

                // Equivalent to: vlc "$(yt-dlp --js-runtimes node -f best -g URL)"
                var outText = RunAndCapture(YtDlp, $"--js-runtimes node -f best -g \"{url}\"").Trim();
                if (string.IsNullOrWhiteSpace(outText)) { Log("empty yt-dlp output"); continue; }

                var lines = outText.Split(new[] { "\r\n", "\n" }, StringSplitOptions.RemoveEmptyEntries);
                var streamUrl = lines[^1].Trim();

                Log("streamUrl: " + streamUrl);

                LaunchDetached(Vlc, streamUrl);
                Log("vlc launched");
            }
            catch (Exception ex)
            {
                Log("handler error: " + ex.GetType().Name + " " + ex.Message);
            }
        }

        return 0;
    }
}