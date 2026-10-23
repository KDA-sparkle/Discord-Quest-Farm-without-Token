#pragma warning disable 0649, 0169
using System;
using System.Collections.Concurrent;
using System.Collections.Generic;
using System.IO;
using System.Net;
using System.Net.NetworkInformation;
using System.Net.Sockets;
using System.Security.Cryptography;
using System.Text;
using System.Threading;
using System.Web.Script.Serialization;

// Serveur HTTP minimal, sur le reseau local, pour l'appli mobile (app/mobile).
// Il ne touche jamais directement a l'etat de l'outil :
//  - il renvoie le dernier etat publie par PowerShell (StateJson) ;
//  - il met les commandes recues en file (Commands), traitees ensuite par le thread de l'interface.
// Acces : appairage avec un code a 6 chiffres (Pin) qui donne un jeton, a envoyer dans l'en-tete X-Token.
public class QsRemote {
    TcpListener listener;
    Thread thread;
    volatile bool running;
    readonly object gate = new object();
    readonly Dictionary<string, DateTime> tokens = new Dictionary<string, DateTime>(); // jeton -> derniere requete
    int failures;
    DateTime lockedUntil = DateTime.MinValue;

    public string WebRoot;                      // dossier des fichiers de l'appli mobile
    public string Pin = "";                     // code d'appairage affiche sur le PC
    public volatile string StateJson = "{}";    // etat publie par PowerShell
    public volatile List<QsGame> Catalog;       // catalogue, pour la recherche depuis le telephone
    public readonly ConcurrentQueue<string> Commands = new ConcurrentQueue<string>();
    public readonly ConcurrentQueue<string> NewTokens = new ConcurrentQueue<string>();
    public int Port { get; private set; }
    public bool IsRunning { get { return running; } }

    public bool Start(int port) {
        if (running) return true;
        try {
            listener = new TcpListener(IPAddress.Any, port);
            listener.Start();
        } catch { listener = null; return false; }
        Port = port;
        running = true;
        thread = new Thread(Loop) { IsBackground = true, Name = "QsRemote" };
        thread.Start();
        return true;
    }

    public void Stop() {
        running = false;
        try { if (listener != null) listener.Stop(); } catch { }
        listener = null;
    }

    public void SetTokens(IEnumerable<string> list) {
        lock (gate) { tokens.Clear(); foreach (var t in list) if (!string.IsNullOrEmpty(t)) tokens[t] = DateTime.MinValue; }
    }

    public void ClearTokens() { lock (gate) tokens.Clear(); }

    public int TokenCount { get { lock (gate) return tokens.Count; } }

    public DateTime LastSeen {
        get { lock (gate) { var m = DateTime.MinValue; foreach (var v in tokens.Values) if (v > m) m = v; return m; } }
    }

    // Adresses IPv4 du PC sur le reseau local (cartes actives avec passerelle d'abord, cartes virtuelles ignorees)
    public static string[] LocalAddresses() {
        var withGw = new List<string>();
        var other = new List<string>();
        foreach (var ni in NetworkInterface.GetAllNetworkInterfaces()) {
            if (ni.OperationalStatus != OperationalStatus.Up) continue;
            if (ni.NetworkInterfaceType == NetworkInterfaceType.Loopback || ni.NetworkInterfaceType == NetworkInterfaceType.Tunnel) continue;
            string n = (ni.Name + " " + ni.Description).ToLowerInvariant();
            if (n.Contains("vethernet") || n.Contains("virtual") || n.Contains("vmware") || n.Contains("hyper-v") || n.Contains("wsl") || n.Contains("vpn")) continue;
            var props = ni.GetIPProperties();
            bool gw = false;
            foreach (var g in props.GatewayAddresses) if (g.Address.AddressFamily == AddressFamily.InterNetwork && !g.Address.Equals(IPAddress.Any)) gw = true;
            foreach (var ua in props.UnicastAddresses) {
                if (ua.Address.AddressFamily != AddressFamily.InterNetwork) continue;
                string ip = ua.Address.ToString();
                if (ip.StartsWith("169.254.")) continue;
                (gw ? withGw : other).Add(ip);
            }
        }
        withGw.AddRange(other);
        return withGw.ToArray();
    }

    void Loop() {
        while (running) {
            TcpClient client;
            try { client = listener.AcceptTcpClient(); } catch { break; }
            ThreadPool.QueueUserWorkItem(delegate { Handle(client); });
        }
    }

    void Handle(TcpClient client) {
        try {
            using (client) {
                client.ReceiveTimeout = 5000;
                client.SendTimeout = 5000;
                var ns = client.GetStream();
                string method, path, query;
                Dictionary<string, string> headers;
                byte[] body;
                if (!ReadRequest(ns, out method, out path, out query, out headers, out body)) return;
                if (path.StartsWith("/api/")) Api(ns, method, path, query, headers, body);
                else Static(ns, method, path);
            }
        } catch { }
    }

    static bool ReadRequest(NetworkStream ns, out string method, out string path, out string query,
                            out Dictionary<string, string> headers, out byte[] body) {
        method = path = query = null; headers = null; body = new byte[0];
        var buf = new MemoryStream();
        var chunk = new byte[4096];
        int headerEnd = -1;
        while (headerEnd < 0) {
            int n = ns.Read(chunk, 0, chunk.Length);
            if (n <= 0) return false;
            buf.Write(chunk, 0, n);
            if (buf.Length > 16384) return false;
            headerEnd = IndexOf(buf.GetBuffer(), (int)buf.Length, new byte[] { 13, 10, 13, 10 });
        }
        byte[] all = buf.ToArray();
        string head = Encoding.ASCII.GetString(all, 0, headerEnd);
        string[] lines = head.Split(new[] { "\r\n" }, StringSplitOptions.None);
        string[] first = lines[0].Split(' ');
        if (first.Length < 2) return false;
        method = first[0].ToUpperInvariant();
        string target = first[1];
        int q = target.IndexOf('?');
        path = q >= 0 ? target.Substring(0, q) : target;
        query = q >= 0 ? target.Substring(q + 1) : "";
        headers = new Dictionary<string, string>();
        for (int i = 1; i < lines.Length; i++) {
            int c = lines[i].IndexOf(':');
            if (c > 0) headers[lines[i].Substring(0, c).Trim().ToLowerInvariant()] = lines[i].Substring(c + 1).Trim();
        }
        int len = 0;
        string cl;
        if (headers.TryGetValue("content-length", out cl)) int.TryParse(cl, out len);
        if (len < 0 || len > 65536) return false;
        var body2 = new MemoryStream();
        int already = all.Length - (headerEnd + 4);
        if (already > 0) body2.Write(all, headerEnd + 4, Math.Min(already, len));
        while (body2.Length < len) {
            int n = ns.Read(chunk, 0, (int)Math.Min(chunk.Length, len - body2.Length));
            if (n <= 0) break;
            body2.Write(chunk, 0, n);
        }
        body = body2.ToArray();
        return true;
    }

    static int IndexOf(byte[] data, int length, byte[] pattern) {
        for (int i = 0; i + pattern.Length <= length; i++) {
            bool ok = true;
            for (int j = 0; j < pattern.Length; j++) if (data[i + j] != pattern[j]) { ok = false; break; }
            if (ok) return i;
        }
        return -1;
    }

    static readonly Dictionary<string, string> Files = new Dictionary<string, string> {
        { "/", "index.html" }, { "/index.html", "index.html" }, { "/app.js", "app.js" }, { "/style.css", "style.css" },
        { "/manifest.webmanifest", "manifest.webmanifest" }, { "/icon-192.png", "icon-192.png" }, { "/icon-512.png", "icon-512.png" }
    };

    void Static(NetworkStream ns, string method, string path) {
        string file;
        if (method != "GET" || !Files.TryGetValue(path, out file)) { Send(ns, 404, "text/plain; charset=utf-8", Encoding.UTF8.GetBytes("Not found")); return; }
        string full = Path.Combine(WebRoot ?? "", file);
        if (!File.Exists(full)) { Send(ns, 404, "text/plain; charset=utf-8", Encoding.UTF8.GetBytes("Not found")); return; }
        string ext = Path.GetExtension(file);
        string type = ext == ".html" ? "text/html; charset=utf-8"
                    : ext == ".js" ? "application/javascript; charset=utf-8"
                    : ext == ".css" ? "text/css; charset=utf-8"
                    : ext == ".webmanifest" ? "application/manifest+json; charset=utf-8"
                    : "image/png";
        Send(ns, 200, type, File.ReadAllBytes(full));
    }

    void Api(NetworkStream ns, string method, string path, string query, Dictionary<string, string> headers, byte[] body) {
        var json = new JavaScriptSerializer();

        // Appairage : code a 6 chiffres -> jeton (5 erreurs = blocage 1 minute)
        if (path == "/api/pair" && method == "POST") {
            lock (gate) {
                if (DateTime.UtcNow < lockedUntil) { SendJson(ns, 429, "{\"error\":\"locked\"}"); return; }
                string pin = null;
                try {
                    var o = json.DeserializeObject(Encoding.UTF8.GetString(body)) as Dictionary<string, object>;
                    if (o != null && o.ContainsKey("pin")) pin = Convert.ToString(o["pin"]);
                } catch { }
                if (string.IsNullOrEmpty(Pin) || pin != Pin) {
                    if (++failures >= 5) { failures = 0; lockedUntil = DateTime.UtcNow.AddMinutes(1); }
                    SendJson(ns, 401, "{\"error\":\"pin\"}");
                    return;
                }
                failures = 0;
                string token = NewToken();
                tokens[token] = DateTime.Now;
                NewTokens.Enqueue(token);
                SendJson(ns, 200, json.Serialize(new { token = token }));
                return;
            }
        }

        string tk;
        headers.TryGetValue("x-token", out tk);
        lock (gate) {
            if (string.IsNullOrEmpty(tk) || !tokens.ContainsKey(tk)) { SendJson(ns, 401, "{\"error\":\"token\"}"); return; }
            tokens[tk] = DateTime.Now;
        }

        if (path == "/api/state" && method == "GET") { SendJson(ns, 200, StateJson); return; }

        if (path == "/api/search" && method == "GET") {
            string q = "";
            foreach (var part in query.Split('&'))
                if (part.StartsWith("q=")) q = Uri.UnescapeDataString(part.Substring(2).Replace('+', ' '));
            var cat = Catalog;
            var res = new List<object>();
            if (cat != null && q.Trim().Length > 0) {
                // Les noms qui commencent par la recherche d'abord, puis les autres
                var found = QsCatalog.Filter(cat, q);
                string nq = QsCatalog.Normalize(q.Trim());
                var first = found.FindAll(g => QsCatalog.Normalize(g.Name).StartsWith(nq));
                first.AddRange(found.FindAll(g => !QsCatalog.Normalize(g.Name).StartsWith(nq)));
                foreach (var g in first) {
                    res.Add(new { id = g.Id, name = g.Name, icon = g.IconUrl, ini = g.Initial, played = g.Played, isPlayed = g.IsPlayed });
                    if (res.Count >= 40) break;
                }
            }
            SendJson(ns, 200, json.Serialize(res));
            return;
        }

        if (path == "/api/cmd" && method == "POST") {
            if (body.Length == 0 || body.Length > 4096) { SendJson(ns, 400, "{\"error\":\"body\"}"); return; }
            Commands.Enqueue(Encoding.UTF8.GetString(body));
            SendJson(ns, 202, "{\"ok\":true}");
            return;
        }

        SendJson(ns, 404, "{\"error\":\"route\"}");
    }

    static string NewToken() {
        var b = new byte[16];
        using (var rng = new RNGCryptoServiceProvider()) rng.GetBytes(b);
        return BitConverter.ToString(b).Replace("-", "").ToLowerInvariant();
    }

    static void SendJson(NetworkStream ns, int code, string json) {
        Send(ns, code, "application/json; charset=utf-8", Encoding.UTF8.GetBytes(json));
    }

    static void Send(NetworkStream ns, int code, string type, byte[] data) {
        string reason = code == 200 ? "OK" : code == 202 ? "Accepted" : code == 400 ? "Bad Request" : code == 401 ? "Unauthorized"
                      : code == 404 ? "Not Found" : code == 429 ? "Too Many Requests" : "Error";
        string head = "HTTP/1.1 " + code + " " + reason + "\r\nContent-Type: " + type + "\r\nContent-Length: " + data.Length +
                      "\r\nCache-Control: no-store\r\nX-Content-Type-Options: nosniff\r\nConnection: close\r\n\r\n";
        byte[] h = Encoding.ASCII.GetBytes(head);
        ns.Write(h, 0, h.Length);
        ns.Write(data, 0, data.Length);
        ns.Flush();
    }

    // Code d'appairage a 6 chiffres
    public static string NewPin() {
        var b = new byte[4];
        using (var rng = new RNGCryptoServiceProvider()) rng.GetBytes(b);
        return (BitConverter.ToUInt32(b, 0) % 1000000).ToString("000000");
    }
}
