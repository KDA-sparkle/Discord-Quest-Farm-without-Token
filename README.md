<p align="center">
  <img src="assets/logo.png" width="96" alt="Quest Farm">
</p>

<h1 align="center">Quest Farm</h1>

<p align="center">
  Discord presence simulator for Windows<br>
  <sub><code>// you only play with me ♡</code></sub><br>
  <b>English</b> · <a href="README.fr.md">Français</a>
</p>

<p align="center">
  <img src="assets/screenshot-en.png" width="820" alt="Quest Farm">
</p>

Quest Farm starts **fake processes** named after game executables that Discord can detect.
Discord then thinks you are playing: handy for "play X for N minutes" quests.

- **No token, no password**: the app never reads or changes anything inside Discord.
- **100% local**: the only network access downloads Discord's public list of detectable games (`discord.com/api/v10/applications/detectable`) and their icons.
- **No third-party binary**: the fake exe is compiled on your machine from [`app/Stub.cs`](app/Stub.cs).

> ⚠️ **Disclaimer** — Not affiliated with Discord. Simulating game activity may break Discord's Terms of
> Service (lost rewards, account suspension). Use at your own risk. Badges such as "Game Variety" are computed
> by Discord: there is no guarantee they will progress.

## Features

| | |
|---|---|
| 🎮 **Catalog** | 10,000+ detectable games, accent-insensitive search, favorites, recent, played games with their time |
| 🔁 **Rotation** | Queue of games run one at a time (N minutes each), pause / resume (`Ctrl+Alt+S`), skip, saved lists, export / import |
| 🚩 **Quest mode** | One game + the required duration: countdown, sound and notification, automatic stop |
| ⏱️ **Timer** | Stop everything after 30 min to 8 h or when the rotation ends, then nothing / sleep / shut down |
| 📊 **Stats** | Simulated time over 14 days, most played games, "Game Variety" counter |
| 🪟 **Fake games** | Small card with the game icon and a timer; color, size and screen corner are configurable |
| ⚡ **Live settings** | Language, colors and fake game appearance apply instantly, even to fake games already running |
| 📱 **Phone app** | Control the PC app from your phone on the same Wi-Fi: sessions, rotation, game search, quests, timer, stats |
| 🩸 **Yandere theme** | Deep aubergine, blood red and sakura, serif titles; 6 accent colors (blood, sakura, cherry, lilac, mint, rose gold) applied everywhere, phone and fake games included |
| 🧩 **Comfort** | Always-on-top mini widget, notification area, launch with Windows (optional), desktop shortcut, diagnostics, English / French |
| 🪶 **Lightweight** | ~2–6% of one core and 60–130 MB; fake games stop with the app, even if it crashes |

<p align="center">
  <img src="assets/quest-en.png" width="400" alt="Quest mode">
  <img src="assets/stats-en.png" width="400" alt="Stats">
</p>
<p align="center">
  <img src="assets/fake-game-cards-en.png" width="400" alt="Fake game cards">
  <img src="assets/settings-en.png" width="400" alt="Settings">
</p>

## Installation

1. **Requirements**: Windows 10 or 11, Windows PowerShell 5.1 and .NET Framework 4.x (installed by default), Discord desktop app.
2. Download the project (**Code → Download ZIP**) and extract it.
3. Double-click **`Lancer.bat`**. On first run the app compiles the fake exe and downloads the catalog.
4. Switch to English in **Settings → Language**, and create a desktop shortcut with the real icon in **Settings → Desktop shortcut**.

## Usage

- **One game**: search it, select it, then **Start spoof** (or `Enter`).
- **Several games in a row**: add them with **Rotation** (`Ctrl+Enter`), then **Start** in the *Sessions* tab.
- **A quest**: *Quest* tab, pick the game and the duration, then **Start quest**.
- Check in **Discord → Settings → Registered Games** that the game shows as running.
- Discord must stay open: rotation and quest pause while it is closed.

| Shortcut | Action |
|---|---|
| `Ctrl+Alt+S` | Pause / resume the rotation, even when hidden |
| `Ctrl+F` | Search a game |
| `Enter` / `Ctrl+Enter` | Launch / add to rotation |
| `Ctrl+D` | Favorite |
| `Delete` | Stop the latest session |
| `Esc` | Clear search, close settings |

## Phone app

Control the PC app from your phone: start / stop games, manage the rotation, start a quest,
set the timer and check your stats, without getting up.

<p align="center">
  <img src="assets/mobile-home-en.png" width="200" alt="Home">
  <img src="assets/mobile-games-en.png" width="200" alt="Games">
  <img src="assets/mobile-quest-en.png" width="200" alt="Quest">
  <img src="assets/mobile-stats-en.png" width="200" alt="Stats">
</p>

> **There is nothing to download** (no APK, no store). It is a web app served **by your PC** on your local
> network: you open it in your phone's browser and can add it to your home screen.
> It only works while Quest Farm is running on the PC.

### Connecting

1. On the PC: **Settings → Phone**, tick **Control from your phone**.
   The app shows an address (e.g. `http://192.168.1.20:47820`) and a **6-digit code**.
2. On the phone, connected to the **same Wi-Fi as the PC**: type that address in the browser.
3. Enter the code. The phone stays signed in afterwards, no need to type it again.

### Installing it like a real app

- **Android (Chrome)**: **⋮** menu → **Install app** (or **Add to Home screen**).
- **iPhone (Safari)**: **Share** button → **Add to Home Screen**.

It then opens full screen with its own icon, like a regular app.

### Tabs

| Tab | What you can do |
|---|---|
| **Home** | Running games (✕ to stop them), rotation: pause, skip, shuffle, minutes per game, timer |
| **Games** | Search the whole catalog: ▶ start, ＋ add to rotation, 🚩 start as a quest |
| **Quest** | Countdown and progress of the current quest, button to stop it |
| **Stats** | "Game Variety" progress, simulated time today, sessions, log out this phone |

Language and accent color follow the PC app.

### Security

- **Nothing goes through the Internet**: the phone talks to the PC directly on your network (port `47820`).
- Without the code, nobody else on the Wi-Fi can control the app (5 wrong codes = locked for one minute).
- **New code** in the settings disconnects every phone. Unticking the option stops the server.

### Can't connect?

- Make sure the phone is on **the same Wi-Fi** as the PC (not mobile data, not a "guest" Wi-Fi).
- If Windows showed a firewall prompt for PowerShell, **private networks** must be allowed.
  Your network must also use the **Private** profile (Windows Settings → Network → Wi-Fi/Ethernet → Network profile type).
- Turn off any **VPN** on the phone or the PC.
- If the PC has several network adapters, try the other address shown under the main one.
- The PC must stay on with Quest Farm and Discord open (the app can be minimized to the notification area).

## Project structure

```
Lancer.bat            starts the app without a console
QuestSpoofer.ps1      logic (PowerShell + WPF)
app/MainWindow.xaml   main window
app/Widget.xaml       mini widget
app/Types.cs          C# types (catalog, sessions, Windows job, global hotkey, icon)
app/Stub.cs           fake exe source
app/Remote.cs         local server for the phone app
app/mobile/           phone app (HTML, CSS, JavaScript, icons)
app/i18n.ps1          English translations
data/                 (created at runtime) settings, history, catalog cache
games/                (created at runtime) fake exes
```
