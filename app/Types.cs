#pragma warning disable 0649, 0169
using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Diagnostics;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Globalization;
using System.IO;
using System.Net;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading.Tasks;
using System.Web.Script.Serialization;

// Un jeu detectable du catalogue Discord
public class QsGame : INotifyPropertyChanged {
    public event PropertyChangedEventHandler PropertyChanged;
    void Notify(string p) { if (PropertyChanged != null) PropertyChanged(this, new PropertyChangedEventArgs(p)); }

    public string Id { get; private set; }
    public string Name { get; private set; }
    public string ExePath { get; private set; }
    public string IconHash { get; private set; }
    public bool HasCover { get; private set; }
    public string Initial { get; private set; }
    internal string Key;

    public string IconUrl {
        get { return string.IsNullOrEmpty(IconHash) ? null : "https://cdn.discordapp.com/app-icons/" + Id + "/" + IconHash + ".png?size=64"; }
    }

    bool _fav;
    public bool IsFav { get { return _fav; } set { if (_fav == value) return; _fav = value; Notify("IsFav"); } }

    // Temps deja joue avec l'outil ("12 MIN", "1 H 05"), vide si jamais joue
    string _played;
    public string Played { get { return _played; } set { if (_played == value) return; _played = value; Notify("Played"); } }
    bool _isPlayed;
    public bool IsPlayed { get { return _isPlayed; } set { if (_isPlayed == value) return; _isPlayed = value; Notify("IsPlayed"); } }

    public QsGame(string id, string name, string exePath, string iconHash, bool hasCover) {
        Id = id ?? ""; Name = name ?? ""; ExePath = exePath ?? ""; IconHash = iconHash ?? ""; HasCover = hasCover;
        Key = QsCatalog.Normalize(Name + " " + ExePath);
        Initial = "?";
        foreach (char c in Name) if (char.IsLetterOrDigit(c)) { Initial = char.ToUpperInvariant(c).ToString(); break; }
    }
}

public static class QsCatalog {
    public static void Sort(List<QsGame> l) {
        l.Sort((a, b) => string.Compare(a.Name, b.Name, StringComparison.OrdinalIgnoreCase));
    }

    // Minuscules sans accents : "Pokémon" se trouve en tapant "pokemon"
    public static string Normalize(string s) {
        var sb = new StringBuilder(s.Length);
        foreach (char c in s.Normalize(NormalizationForm.FormD))
            if (CharUnicodeInfo.GetUnicodeCategory(c) != UnicodeCategory.NonSpacingMark) sb.Append(char.ToLowerInvariant(c));
        return sb.ToString();
    }

    public static List<QsGame> Filter(IList<QsGame> src, string q) {
        var r = new List<QsGame>();
        if (string.IsNullOrWhiteSpace(q)) { r.AddRange(src); return r; }
        q = Normalize(q.Trim());
        foreach (var g in src) if (g.Key.Contains(q)) r.Add(g);
        return r;
    }

    // Telecharge la liste publique des jeux detectables, choisit l'exe Windows
    // de chaque jeu et met le cache disque a jour. Tourne hors du thread UI.
    public static Task<List<QsGame>> FetchAsync(string url, string cachePath) {
        return Task.Run(() => Fetch(url, cachePath));
    }

    static List<QsGame> Fetch(string url, string cachePath) {
        ServicePointManager.SecurityProtocol |= SecurityProtocolType.Tls12;
        var req = (HttpWebRequest)WebRequest.Create(url);
        req.UserAgent = "Mozilla/5.0";
        req.AutomaticDecompression = DecompressionMethods.GZip | DecompressionMethods.Deflate;
        req.Timeout = 30000;
        string json;
        using (var resp = req.GetResponse())
        using (var sr = new StreamReader(resp.GetResponseStream(), Encoding.UTF8)) json = sr.ReadToEnd();

        var ser = new JavaScriptSerializer { MaxJsonLength = int.MaxValue };
        var arr = ser.DeserializeObject(json) as object[];
        json = null;
        var list = new List<QsGame>();
        if (arr == null) return list;
        foreach (var o in arr) {
            var g = o as Dictionary<string, object>;
            if (g == null) continue;
            string name = Str(g, "name");
            var exes = Get(g, "executables") as object[];
            if (string.IsNullOrEmpty(name) || exes == null) continue;
            string exe = PickExe(exes);
            if (exe == null) continue;
            list.Add(new QsGame(Str(g, "id"), name, exe, Str(g, "icon_hash"), !string.IsNullOrEmpty(Str(g, "cover_image_hash"))));
        }
        Sort(list);
        Save(list, cachePath);
        return list;
    }

    // Exe Windows (hors launcher) le plus simple : le moins de sous-dossiers.
    // Discord compare la fin du chemin complet, donc on garde les sous-dossiers.
    static string PickExe(object[] exes) {
        string best = null; int bestDepth = int.MaxValue;
        foreach (var o in exes) {
            var e = o as Dictionary<string, object>;
            if (e == null || Str(e, "os") != "win32" || Get(e, "is_launcher") as bool? == true) continue;
            string p = (Str(e, "name") ?? "").Replace('\\', '/').Trim('/');
            if (p.Length == 0 || p.IndexOfAny("<>:\"|?*~".ToCharArray()) >= 0) continue;
            var parts = p.Split('/');
            bool bad = false;
            foreach (var s in parts) if (s == "." || s == "..") bad = true;
            if (bad || parts.Length >= bestDepth) continue;
            best = p; bestDepth = parts.Length;
        }
        if (best == null) return null;
        best = best.Replace('/', '\\');
        if (!best.EndsWith(".exe", StringComparison.OrdinalIgnoreCase)) best += ".exe";
        return best;
    }

    static object Get(Dictionary<string, object> d, string k) { object v; return d.TryGetValue(k, out v) ? v : null; }
    static string Str(Dictionary<string, object> d, string k) { var v = Get(d, k); return v == null ? null : Convert.ToString(v, CultureInfo.InvariantCulture); }

    static string Clean(string s) { return (s ?? "").Replace('\t', ' ').Replace('\r', ' ').Replace('\n', ' '); }

    // Cache disque : une ligne par jeu, champs separes par des tabulations
    public static void Save(List<QsGame> l, string path) {
        var sb = new StringBuilder();
        foreach (var g in l)
            sb.Append(Clean(g.Id)).Append('\t').Append(Clean(g.Name)).Append('\t').Append(Clean(g.ExePath)).Append('\t')
              .Append(Clean(g.IconHash)).Append('\t').Append(g.HasCover ? "1" : "0").Append('\n');
        string tmp = path + ".tmp";
        File.WriteAllText(tmp, sb.ToString(), new UTF8Encoding(false));
        if (File.Exists(path)) File.Delete(path);
        File.Move(tmp, path);
    }

    public static List<QsGame> Load(string path) {
        var l = new List<QsGame>();
        foreach (var line in File.ReadAllLines(path, Encoding.UTF8)) {
            var p = line.Split('\t');
            if (p.Length < 5) continue;
            l.Add(new QsGame(p[0], p[1], p[2], p[3], p[4] == "1"));
        }
        return l;
    }
}

// Une session de spoof en cours
public class QsSession : INotifyPropertyChanged {
    public event PropertyChangedEventHandler PropertyChanged;
    public string Name { get; set; }
    public string ExePath { get; set; }
    public string GameId { get; set; }
    public string IconUrl { get; set; }
    public string Initial { get; set; }
    public Process Proc { get; set; }
    public DateTime Start { get; set; }
    public DateTime LastCount { get; set; }
    public string Kind { get; set; }        // "Rotation", "Quête" ou vide (lancement manuel) : sert a la logique
    public string KindLabel { get; set; }   // meme chose, traduit pour l'affichage
    public string PidLabel {
        get {
            string k = string.IsNullOrEmpty(KindLabel) ? Kind : KindLabel;
            return (Proc == null ? "" : "PID " + Proc.Id) + (string.IsNullOrEmpty(k) ? "" : " · " + k);
        }
    }
    public TimeSpan Age { get { return DateTime.Now - Start; } }
    string _e = "00:00:00";
    public string Elapsed {
        get { return _e; }
        set { if (_e == value) return; _e = value; if (PropertyChanged != null) PropertyChanged(this, new PropertyChangedEventArgs("Elapsed")); }
    }
    public void Tick() { Elapsed = Format(Age); }
    public static string Format(TimeSpan t) {
        return string.Format("{0:00}:{1:00}:{2:00}", (int)t.TotalHours, t.Minutes, t.Seconds);
    }
}

// Rattache les faux processus a un job Windows : ils meurent avec ce script,
// meme si PowerShell est tue brutalement.
public static class QsJob {
    [StructLayout(LayoutKind.Sequential)]
    struct Basic { public long a, b; public uint LimitFlags; public UIntPtr c, d; public uint e; public UIntPtr f; public uint g, h; }
    [StructLayout(LayoutKind.Sequential)]
    struct Io { public ulong a, b, c, d, e, f; }
    [StructLayout(LayoutKind.Sequential)]
    struct Ext { public Basic Basic; public Io Io; public UIntPtr a, b, c, d; }

    [DllImport("kernel32.dll", CharSet = CharSet.Unicode)] static extern IntPtr CreateJobObject(IntPtr attr, string name);
    [DllImport("kernel32.dll")] static extern bool SetInformationJobObject(IntPtr job, int cls, ref Ext info, int len);
    [DllImport("kernel32.dll")] static extern bool AssignProcessToJobObject(IntPtr job, IntPtr proc);

    static IntPtr _job = IntPtr.Zero;
    public static bool Attach(Process p) {
        if (_job == IntPtr.Zero) {
            IntPtr j = CreateJobObject(IntPtr.Zero, null);
            if (j == IntPtr.Zero) return false;
            Ext info = new Ext();
            info.Basic.LimitFlags = 0x2000; // JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE
            if (!SetInformationJobObject(j, 9, ref info, Marshal.SizeOf(typeof(Ext)))) return false;
            _job = j;
        }
        return AssignProcessToJobObject(_job, p.Handle);
    }
}

// Empeche la mise en veille tant qu'un spoof tourne (a appeler depuis le thread UI)
public static class QsPower {
    [DllImport("kernel32.dll")] static extern uint SetThreadExecutionState(uint flags);
    public static void KeepAwake(bool on) {
        SetThreadExecutionState(on ? 0x80000001u : 0x80000000u); // ES_CONTINUOUS | ES_SYSTEM_REQUIRED
    }
}

public static class QsDiscord {
    static readonly string[] Names = { "Discord", "DiscordPTB", "DiscordCanary" };
    public static bool IsRunning() {
        foreach (var n in Names) {
            var ps = Process.GetProcessesByName(n);
            bool any = ps.Length > 0;
            foreach (var p in ps) p.Dispose();
            if (any) return true;
        }
        return false;
    }
}

// Libere la memoire inutilisee (apres le chargement, ou quand la fenetre est reduite)
public static class QsMem {
    [DllImport("psapi.dll")] static extern bool EmptyWorkingSet(IntPtr proc);
    public static void Trim() {
        GC.Collect();
        GC.WaitForPendingFinalizers();
        GC.Collect();
        using (var p = Process.GetCurrentProcess()) EmptyWorkingSet(p.Handle);
    }
}

// Fenetre : coins arrondis natifs de Windows 11, barre sombre, bordure discrete
public static class QsWin {
    [DllImport("dwmapi.dll")] static extern int DwmSetWindowAttribute(IntPtr hwnd, int attr, ref int value, int size);
    public static void Style(IntPtr hwnd) {
        int dark = 1, round = 2, border = 0x00302A1A; // COLORREF = 0x00BBGGRR (#1A2A30)
        DwmSetWindowAttribute(hwnd, 20, ref dark, 4);   // DWMWA_USE_IMMERSIVE_DARK_MODE
        DwmSetWindowAttribute(hwnd, 33, ref round, 4);  // DWMWA_WINDOW_CORNER_PREFERENCE = ROUND
        DwmSetWindowAttribute(hwnd, 34, ref border, 4); // DWMWA_BORDER_COLOR
    }
}

// Icone de l'appli (barre des taches, zone de notification, raccourci), dessinee a la volee
public static class QsIcon {
    static GraphicsPath RoundRect(RectangleF r, float rad) {
        var p = new GraphicsPath();
        float d = rad * 2;
        p.AddArc(r.X, r.Y, d, d, 180, 90);
        p.AddArc(r.Right - d, r.Y, d, d, 270, 90);
        p.AddArc(r.Right - d, r.Bottom - d, d, d, 0, 90);
        p.AddArc(r.X, r.Bottom - d, d, d, 90, 90);
        p.CloseFigure();
        return p;
    }

    // Etoile a 4 branches (l'idee de "quete")
    static GraphicsPath Sparkle(float cx, float cy, float r) {
        var p = new GraphicsPath();
        float i = r * 0.32f;
        p.AddPolygon(new[] {
            new PointF(cx, cy - r), new PointF(cx + i, cy - i), new PointF(cx + r, cy), new PointF(cx + i, cy + i),
            new PointF(cx, cy + r), new PointF(cx - i, cy + i), new PointF(cx - r, cy), new PointF(cx - i, cy - i) });
        return p;
    }

    // Logo : carre arrondi indigo -> violet, manette blanche, petite etoile doree
    static Bitmap Draw(int size) {
        var bmp = new Bitmap(size, size, System.Drawing.Imaging.PixelFormat.Format32bppArgb);
        float s = size;
        using (var g = Graphics.FromImage(bmp)) {
            g.SmoothingMode = SmoothingMode.AntiAlias;
            g.TextRenderingHint = System.Drawing.Text.TextRenderingHint.AntiAlias;
            g.PixelOffsetMode = PixelOffsetMode.HighQuality;
            var box = new RectangleF(0, 0, s - 1, s - 1);
            using (var path = RoundRect(box, s * 0.23f)) {
                using (var br = new LinearGradientBrush(box, Color.FromArgb(139, 147, 255), Color.FromArgb(108, 76, 245), 50f))
                    g.FillPath(br, path);
                // Reflet doux sur la moitie haute
                g.SetClip(path);
                using (var hl = new LinearGradientBrush(new RectangleF(0, 0, s, s * 0.55f), Color.FromArgb(46, 255, 255, 255), Color.FromArgb(0, 255, 255, 255), 90f))
                    g.FillRectangle(hl, 0, 0, s, s * 0.55f);
                g.ResetClip();
            }
            // Manette (glyphe Segoe Fluent Icons / MDL2), legerement ombree
            string glyph = "";
            string fam = "Segoe Fluent Icons";
            using (var test = new Font(fam, 10)) if (test.Name != fam) fam = "Segoe MDL2 Assets";
            using (var f = new Font(fam, s * 0.50f, GraphicsUnit.Pixel))
            using (var sf = new StringFormat { Alignment = StringAlignment.Center, LineAlignment = StringAlignment.Center }) {
                var r = new RectangleF(0, s * 0.04f, s, s);
                using (var sh = new SolidBrush(Color.FromArgb(60, 30, 20, 90)))
                    g.DrawString(glyph, f, sh, new RectangleF(r.X, r.Y + s * 0.025f, r.Width, r.Height), sf);
                g.DrawString(glyph, f, Brushes.White, r, sf);
            }
            // Etoile doree en haut a droite
            if (size >= 24)
                using (var star = Sparkle(s * 0.775f, s * 0.225f, s * 0.13f))
                using (var gold = new SolidBrush(Color.FromArgb(255, 205, 86))) g.FillPath(gold, star);
        }
        return bmp;
    }

    public static Icon Create() { return Icon.FromHandle(Draw(64).GetHicon()); }

    // PNG du logo (README, captures)
    public static void SavePng(string path, int size) {
        using (var b = Draw(size)) b.Save(path, System.Drawing.Imaging.ImageFormat.Png);
    }

    // Fichier .ico multi-tailles (images PNG), pour le raccourci du bureau
    public static void SaveIco(string path) {
        int[] sizes = { 256, 48, 32, 16 };
        var pngs = new List<byte[]>();
        foreach (int s in sizes)
            using (var b = Draw(s)) using (var ms = new MemoryStream()) { b.Save(ms, System.Drawing.Imaging.ImageFormat.Png); pngs.Add(ms.ToArray()); }
        using (var w = new BinaryWriter(File.Create(path))) {
            w.Write((short)0); w.Write((short)1); w.Write((short)sizes.Length);
            int offset = 6 + 16 * sizes.Length;
            for (int i = 0; i < sizes.Length; i++) {
                byte dim = (byte)(sizes[i] >= 256 ? 0 : sizes[i]);
                w.Write(dim); w.Write(dim); w.Write((byte)0); w.Write((byte)0);
                w.Write((short)1); w.Write((short)32); w.Write(pngs[i].Length); w.Write(offset);
                offset += pngs[i].Length;
            }
            foreach (var p in pngs) w.Write(p);
        }
    }
}

// Raccourci clavier global (fonctionne meme quand l'outil est cache)
public class QsHotkey : IDisposable {
    [DllImport("user32.dll")] static extern bool RegisterHotKey(IntPtr hwnd, int id, uint mods, uint vk);
    [DllImport("user32.dll")] static extern bool UnregisterHotKey(IntPtr hwnd, int id);
    const int Id = 0x5153;
    public event EventHandler Pressed;
    System.Windows.Interop.HwndSource _src;
    IntPtr _hwnd;

    // mods : 1 = Alt, 2 = Ctrl, 4 = Maj
    public bool Register(IntPtr hwnd, uint mods, uint vk) {
        _hwnd = hwnd;
        _src = System.Windows.Interop.HwndSource.FromHwnd(hwnd);
        if (_src != null) _src.AddHook(Hook);
        return RegisterHotKey(hwnd, Id, mods | 0x4000, vk); // 0x4000 = MOD_NOREPEAT
    }

    IntPtr Hook(IntPtr hwnd, int msg, IntPtr w, IntPtr l, ref bool handled) {
        if (msg == 0x0312 && w.ToInt32() == Id) { handled = true; if (Pressed != null) Pressed(this, EventArgs.Empty); }
        return IntPtr.Zero;
    }

    public void Dispose() {
        UnregisterHotKey(_hwnd, Id);
        if (_src != null) _src.RemoveHook(Hook);
    }
}
