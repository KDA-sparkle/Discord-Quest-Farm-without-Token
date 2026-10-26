// Faux executable : une petite carte au nom du jeu (icone, chrono, couleur).
// Arguments : --title "<nom>" --slot N --mode show|min --color #RRGGBB --size s|m|l --corner br|bl|tr|tl
//             --icon <url> --lang fr|en --config <fichier>
// --config : fichier de reglages relu chaque seconde (color=, size=, corner=, lang=, mode=) ;
//            un changement dans l'outil s'applique donc en direct, sans relancer le faux jeu.
// (ancien format accepte aussi : "<titre>" [emplacement] [show|min])
// Compile avec le csc du .NET Framework : C# 5, pas d'interpolation de chaines.
using System;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Text;
using System.IO;
using System.Net;
using System.Runtime.InteropServices;
using System.Threading;
using System.Windows.Forms;

class StubForm : Form {
    [DllImport("dwmapi.dll")] static extern int DwmSetWindowAttribute(IntPtr h, int attr, ref int value, int size);
    [DllImport("user32.dll")] static extern bool ReleaseCapture();
    [DllImport("user32.dll")] static extern IntPtr SendMessage(IntPtr h, int msg, IntPtr w, IntPtr l);

    readonly string title;
    readonly DateTime start = DateTime.Now;
    readonly float dpi;
    readonly int slot;
    readonly string cfgPath;
    DateTime cfgStamp = DateTime.MinValue;

    // Reglages modifiables en direct
    Color accent;
    string size, corner, lang, mode;
    float k;                   // echelle = taille choisie x DPI
    string running;            // "En cours" / "Running"

    Image icon;
    bool hoverClose;
    Rectangle closeRect;

    static readonly Color Bg = Color.FromArgb(28, 13, 24);
    static readonly Color TextC = Color.FromArgb(247, 236, 241);
    static readonly Color MutedC = Color.FromArgb(199, 169, 182);
    static readonly Color DimC = Color.FromArgb(138, 107, 118);
    static readonly Color SakuraC = Color.FromArgb(255, 157, 198);

    public StubForm(string title, Color accent, string size, float dpi, string iconUrl, string lang,
                    string corner, int slot, string mode, string cfgPath) {
        this.title = title;
        this.accent = accent;
        this.size = size;
        this.dpi = dpi;
        this.lang = lang;
        this.corner = corner;
        this.slot = slot;
        this.mode = mode;
        this.cfgPath = cfgPath;
        Text = title;                          // titre de la fenetre (barre des taches)
        FormBorderStyle = FormBorderStyle.None;
        ShowInTaskbar = true;
        StartPosition = FormStartPosition.Manual;
        BackColor = Bg;
        DoubleBuffered = true;
        ReadConfig();
        ApplyLang();
        ApplyLayout();
        Icon = MakeIcon(null);
        if (mode == "min") WindowState = FormWindowState.Minimized;

        var timer = new System.Windows.Forms.Timer();
        timer.Interval = 1000;
        timer.Tick += delegate { if (ReadConfig()) ApplyChanges(); Invalidate(); };
        timer.Start();

        if (!string.IsNullOrEmpty(iconUrl)) LoadIcon(iconUrl);
    }

    static float Factor(string s) { return s == "s" ? 0.85f : s == "l" ? 1.25f : 1f; }

    void ApplyLang() { running = lang == "en" ? "Running" : "En cours"; }

    // Taille et position : empilees dans le coin choisi
    void ApplyLayout() {
        k = Factor(size) * dpi;
        ClientSize = new Size((int)(330 * k), (int)(82 * k));
        Rectangle wa = Screen.PrimaryScreen.WorkingArea;
        int m = (int)(16 * dpi), off = (slot % 6) * (Height + (int)(10 * dpi));
        int x = corner.EndsWith("l") ? wa.Left + m : wa.Right - Width - m;
        int y = corner.StartsWith("t") ? wa.Top + m + off : wa.Bottom - Height - m - off;
        Location = new Point(x, y);
    }

    // Relit le fichier de reglages s'il a change ; renvoie true si quelque chose a change
    bool ReadConfig() {
        if (string.IsNullOrEmpty(cfgPath)) return false;
        try {
            if (!File.Exists(cfgPath)) return false;
            DateTime stamp = File.GetLastWriteTimeUtc(cfgPath);
            if (stamp == cfgStamp) return false;
            cfgStamp = stamp;
            bool changed = false;
            foreach (string line in File.ReadAllLines(cfgPath)) {
                int i = line.IndexOf('=');
                if (i <= 0) continue;
                string key = line.Substring(0, i).Trim(), v = line.Substring(i + 1).Trim();
                switch (key) {
                    case "color":
                        try { Color c = ColorTranslator.FromHtml(v); if (c.ToArgb() != accent.ToArgb()) { accent = c; changed = true; } } catch { }
                        break;
                    case "size": if (v != size && (v == "s" || v == "m" || v == "l")) { size = v; changed = true; } break;
                    case "corner": if (v != corner && v.Length == 2) { corner = v; changed = true; } break;
                    case "lang": if (v != lang) { lang = v; changed = true; } break;
                    case "mode": if (v != mode && (v == "show" || v == "min")) { mode = v; changed = true; } break;
                }
            }
            return changed;
        } catch { return false; }
    }

    void ApplyChanges() {
        ApplyLang();
        if (WindowState != FormWindowState.Minimized) ApplyLayout(); else k = Factor(size) * dpi;
        if (icon == null) Icon = MakeIcon(null);
        if (mode == "min" && WindowState != FormWindowState.Minimized) WindowState = FormWindowState.Minimized;
        else if (mode == "show" && WindowState == FormWindowState.Minimized) { WindowState = FormWindowState.Normal; ApplyLayout(); }
        Invalidate();
    }

    string Initial() {
        foreach (char c in title) if (char.IsLetterOrDigit(c)) return char.ToUpperInvariant(c).ToString();
        return "?";
    }

    // Icone de la barre des taches : l'image du jeu, ou un carre de couleur avec l'initiale
    Icon MakeIcon(Image img) {
        var bmp = new Bitmap(32, 32);
        using (var g = Graphics.FromImage(bmp)) {
            g.SmoothingMode = SmoothingMode.AntiAlias;
            g.TextRenderingHint = TextRenderingHint.AntiAliasGridFit;
            using (var path = Round(new RectangleF(0, 0, 31, 31), 7)) {
                if (img != null) { g.SetClip(path); g.DrawImage(img, 0, 0, 32, 32); g.ResetClip(); }
                else {
                    using (var b = new SolidBrush(accent)) g.FillPath(b, path);
                    using (var f = new Font("Segoe UI Semibold", 17, GraphicsUnit.Pixel))
                    using (var sf = new StringFormat { Alignment = StringAlignment.Center, LineAlignment = StringAlignment.Center })
                        g.DrawString(Initial(), f, Brushes.White, new RectangleF(0, 1, 32, 32), sf);
                }
            }
        }
        return Icon.FromHandle(bmp.GetHicon());
    }

    // Telecharge l'icone du jeu (CDN Discord) sans bloquer la fenetre
    void LoadIcon(string url) {
        ThreadPool.QueueUserWorkItem(delegate {
            try {
                ServicePointManager.SecurityProtocol |= (SecurityProtocolType)3072; // TLS 1.2
                byte[] data;
                using (var wc = new WebClient()) data = wc.DownloadData(url);
                var img = Image.FromStream(new MemoryStream(data));
                BeginInvoke((MethodInvoker)delegate { icon = img; Icon = MakeIcon(img); Invalidate(); });
            } catch { }
        });
    }

    protected override void OnHandleCreated(EventArgs e) {
        base.OnHandleCreated(e);
        int round = 2, border = 0x003F2846;   // coins arrondis Windows 11, bordure #46283F
        DwmSetWindowAttribute(Handle, 33, ref round, 4);
        DwmSetWindowAttribute(Handle, 34, ref border, 4);
    }

    // Coeur dans un carre (x, y, cote)
    static GraphicsPath Heart(float x, float y, float s) {
        var p = new GraphicsPath();
        p.AddBezier(x + s / 2, y + s, x - s * 0.1f, y + s * 0.55f, x, y - s * 0.05f, x + s / 2, y + s * 0.28f);
        p.AddBezier(x + s / 2, y + s * 0.28f, x + s, y - s * 0.05f, x + s * 1.1f, y + s * 0.55f, x + s / 2, y + s);
        p.CloseFigure();
        return p;
    }

    static GraphicsPath Round(RectangleF r, float rad) {
        var p = new GraphicsPath();
        float d = rad * 2;
        p.AddArc(r.X, r.Y, d, d, 180, 90);
        p.AddArc(r.Right - d, r.Y, d, d, 270, 90);
        p.AddArc(r.Right - d, r.Bottom - d, d, d, 0, 90);
        p.AddArc(r.X, r.Bottom - d, d, d, 90, 90);
        p.CloseFigure();
        return p;
    }

    protected override void OnPaint(PaintEventArgs e) {
        var g = e.Graphics;
        g.SmoothingMode = SmoothingMode.AntiAlias;
        g.TextRenderingHint = TextRenderingHint.ClearTypeGridFit;
        int w = ClientSize.Width, h = ClientSize.Height;
        float pad = 14 * k;
        float sz = h - 2 * pad - 3 * k;

        // Halo de la couleur d'accent a gauche (fond aubergine teinte de sang)
        using (var glow = new LinearGradientBrush(new RectangleF(0, 0, w * 0.75f, h), Color.FromArgb(46, accent), Color.FromArgb(0, accent), 0f))
            g.FillRectangle(glow, 0, 0, w * 0.75f, h);

        // Icone du jeu (ou initiale sur fond teinte)
        var ic = new RectangleF(pad, pad, sz, sz);
        using (var path = Round(ic, 10 * k)) {
            if (icon != null) {
                g.SetClip(path);
                g.InterpolationMode = InterpolationMode.HighQualityBicubic;
                g.DrawImage(icon, ic);
                g.ResetClip();
            } else {
                using (var b = new SolidBrush(Color.FromArgb(50, accent))) g.FillPath(b, path);
                using (var f = new Font("Segoe UI Semibold", 20 * k, GraphicsUnit.Pixel))
                using (var b = new SolidBrush(accent))
                using (var sf = new StringFormat { Alignment = StringAlignment.Center, LineAlignment = StringAlignment.Center })
                    g.DrawString(Initial(), f, b, ic, sf);
            }
        }

        // Nom du jeu
        float x = ic.Right + 13 * k;
        using (var f = new Font("Segoe UI Semibold", 15 * k, GraphicsUnit.Pixel))
        using (var b = new SolidBrush(TextC))
        using (var sf = new StringFormat { Trimming = StringTrimming.EllipsisCharacter, FormatFlags = StringFormatFlags.NoWrap })
            g.DrawString(title, f, b, new RectangleF(x, pad - 1 * k, w - x - 36 * k, 22 * k), sf);

        // Etat + chrono
        float y = pad + 25 * k;
        float dot = 7 * k;
        using (var b = new SolidBrush(SakuraC)) using (var hp = Heart(x - 0.5f * k, y + 4 * k, dot + 1 * k)) g.FillPath(b, hp);
        TimeSpan t = DateTime.Now - start;
        string s = string.Format("{0}  ·  {1:00}:{2:00}:{3:00}", running, (int)t.TotalHours, t.Minutes, t.Seconds);
        using (var f = new Font("Segoe UI", 12.5f * k, GraphicsUnit.Pixel))
        using (var b = new SolidBrush(MutedC))
            g.DrawString(s, f, b, x + dot + 7 * k, y);

        // Ligne de couleur en bas
        using (var b = new LinearGradientBrush(new RectangleF(0, 0, w, 3 * k), accent, Color.FromArgb(40, accent), 0f))
            g.FillRectangle(b, 0, h - 3 * k, w, 3 * k);

        // Petite croix (fermer = arreter ce spoof)
        closeRect = new Rectangle((int)(w - 30 * k), (int)(9 * k), (int)(21 * k), (int)(21 * k));
        if (hoverClose)
            using (var b = new SolidBrush(Color.FromArgb(59, 34, 55)))
            using (var p = Round(closeRect, 5 * k)) g.FillPath(b, p);
        using (var pen = new Pen(hoverClose ? TextC : DimC, 1.4f * k)) {
            float c = 4.5f * k, cx = closeRect.X + closeRect.Width / 2f, cy = closeRect.Y + closeRect.Height / 2f;
            g.DrawLine(pen, cx - c, cy - c, cx + c, cy + c);
            g.DrawLine(pen, cx - c, cy + c, cx + c, cy - c);
        }
    }

    protected override void OnMouseMove(MouseEventArgs e) {
        bool over = closeRect.Contains(e.Location);
        if (over != hoverClose) { hoverClose = over; Cursor = over ? Cursors.Hand : Cursors.SizeAll; Invalidate(); }
        base.OnMouseMove(e);
    }

    protected override void OnMouseLeave(EventArgs e) {
        if (hoverClose) { hoverClose = false; Invalidate(); }
        base.OnMouseLeave(e);
    }

    protected override void OnMouseDown(MouseEventArgs e) {
        if (e.Button != MouseButtons.Left) return;
        if (closeRect.Contains(e.Location)) { Close(); return; }
        ReleaseCapture();                                        // deplacer la carte
        SendMessage(Handle, 0xA1, (IntPtr)2, IntPtr.Zero);      // WM_NCLBUTTONDOWN, HTCAPTION
    }
}

static class P {
    [DllImport("user32.dll")] static extern bool SetProcessDPIAware();

    [STAThread]
    static void Main(string[] a) {
        string title = "Game", mode = "show", size = "m", corner = "br", icon = null, lang = "fr", cfg = null;
        int slot = 0;
        Color color = Color.FromArgb(232, 51, 90);

        if (a.Length > 0 && !a[0].StartsWith("--")) {
            title = a[0];
            if (a.Length > 1) int.TryParse(a[1], out slot);
            if (a.Length > 2) mode = a[2];
        } else {
            for (int i = 0; i + 1 < a.Length; i += 2) {
                string v = a[i + 1];
                switch (a[i]) {
                    case "--title": title = v; break;
                    case "--slot": int.TryParse(v, out slot); break;
                    case "--mode": mode = v; break;
                    case "--size": size = v; break;
                    case "--corner": corner = v; break;
                    case "--icon": icon = v; break;
                    case "--lang": lang = v; break;
                    case "--config": cfg = v; break;
                    case "--color": try { color = ColorTranslator.FromHtml(v); } catch { } break;
                }
            }
        }

        SetProcessDPIAware();
        Application.EnableVisualStyles();
        float dpi;
        using (var g = Graphics.FromHwnd(IntPtr.Zero)) dpi = g.DpiX / 96f;
        Application.Run(new StubForm(title, color, size, dpi, icon, lang, corner, slot, mode, cfg));
    }
}
