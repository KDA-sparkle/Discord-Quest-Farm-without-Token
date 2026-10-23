<p align="center">
  <img src="assets/logo.png" width="96" alt="Quest Spoofer">
</p>

<h1 align="center">Quest Spoofer</h1>

<p align="center">
  Simulateur de présence Discord pour Windows · <i>Discord presence simulator for Windows</i><br>
  <a href="#français">Français</a> · <a href="#english">English</a>
</p>

<p align="center">
  <img src="assets/screenshot-en.png" width="820" alt="Quest Spoofer">
</p>

---

## Français

Quest Spoofer lance de **faux processus** qui portent le nom d'exécutables de jeux reconnus par Discord.
Discord croit alors que tu joues : pratique pour les quêtes « joue à X pendant N minutes ».

- **Aucun token, aucun mot de passe** : l'outil ne lit ni ne modifie rien dans Discord.
- **100 % local** : la seule connexion sert à télécharger la liste publique des jeux détectables (`discord.com/api/v10/applications/detectable`) et leurs icônes.
- **Aucun binaire tiers** : le faux exe est compilé sur ta machine à partir de [`app/Stub.cs`](app/Stub.cs).

> ⚠️ **Avertissement** — Projet non affilié à Discord. Simuler une activité de jeu peut enfreindre les
> conditions d'utilisation de Discord (perte des récompenses, suspension du compte). Tu l'utilises à tes risques.
> Les badges comme « Game Variety » sont calculés par Discord : rien ne garantit qu'ils progressent.

### Fonctionnalités

| | |
|---|---|
| 🎮 **Catalogue** | Plus de 10 000 jeux détectables, recherche (sans accents), favoris, récents, jeux déjà joués avec leur temps |
| 🔁 **Rotation** | File de jeux lancés un par un (N minutes chacun), pause / reprise (`Ctrl+Alt+S`), jeu suivant, listes enregistrées, export / import |
| 🚩 **Mode quête** | Un jeu + la durée demandée : compte à rebours, son et notification, arrêt automatique |
| ⏱️ **Minuterie** | Tout arrêter après 30 min à 8 h ou en fin de rotation, puis rien / veille / arrêt du PC |
| 📊 **Stats** | Temps simulé sur 14 jours, jeux les plus joués, compteur « Game Variety » |
| 🪟 **Faux jeux** | Petite carte avec l'icône du jeu et un chrono ; couleur, taille et coin de l'écran réglables |
| 🧩 **Confort** | Mini-widget toujours visible, zone de notification, lancement avec Windows (option), raccourci bureau, diagnostic, français / anglais, 6 couleurs d'accent |
| 🪶 **Léger** | ~2 à 6 % d'un cœur et 60 à 130 Mo ; les faux jeux s'arrêtent avec l'outil, même en cas de plantage |

<p align="center">
  <img src="assets/quest.png" width="400" alt="Mode quête">
  <img src="assets/stats.png" width="400" alt="Statistiques">
</p>

### Installation

1. **Prérequis** : Windows 10 ou 11, Windows PowerShell 5.1 et .NET Framework 4.x (présents par défaut), Discord pour PC.
2. Télécharge le projet (**Code → Download ZIP**) et extrais-le dans un dossier.
3. Double-clique sur **`Lancer.bat`**. Au premier lancement, l'outil compile le faux exe et télécharge le catalogue.
4. Dans **Réglages → Raccourci sur le bureau**, crée un raccourci avec la vraie icône pour les fois suivantes.

### Utilisation

- **Un jeu** : cherche-le, sélectionne-le, puis **Lancer le spoof** (ou `Entrée`).
- **Plusieurs jeux à la suite** : ajoute-les avec **Rotation** (`Ctrl+Entrée`) puis **Démarrer** dans l'onglet *Sessions*.
- **Une quête** : onglet *Quête*, choisis le jeu et la durée, puis **Lancer la quête**.
- Vérifie dans **Discord → Paramètres → Jeux enregistrés** que le jeu apparaît bien « en cours ».
- Discord doit rester ouvert : rotation et quête se mettent en pause s'il est fermé.

| Raccourci | Action |
|---|---|
| `Ctrl+Alt+S` | Pause / reprise de la rotation, même outil caché |
| `Ctrl+F` | Chercher un jeu |
| `Entrée` / `Ctrl+Entrée` | Lancer / ajouter à la rotation |
| `Ctrl+D` | Favori |
| `Suppr` | Arrêter la dernière session |

### Structure

```
Lancer.bat            lance l'outil sans console
QuestSpoofer.ps1      logique (PowerShell + WPF)
app/MainWindow.xaml   interface
app/Widget.xaml       mini-widget
app/Types.cs          types C# (catalogue, sessions, job Windows, raccourci global, icône)
app/Stub.cs           source du faux exe
app/i18n.ps1          traductions anglaises
data/                 (créé à l'exécution) réglages, historique, cache du catalogue
games/                (créé à l'exécution) faux exe
```

---

## English

Quest Spoofer starts **fake processes** named after game executables that Discord can detect.
Discord then thinks you are playing: handy for "play X for N minutes" quests.

- **No token, no password**: the app never reads or changes anything inside Discord.
- **100% local**: the only network access downloads Discord's public list of detectable games (`discord.com/api/v10/applications/detectable`) and their icons.
- **No third-party binary**: the fake exe is compiled on your machine from [`app/Stub.cs`](app/Stub.cs).

> ⚠️ **Disclaimer** — Not affiliated with Discord. Simulating game activity may break Discord's Terms of
> Service (lost rewards, account suspension). Use at your own risk. Badges such as "Game Variety" are computed
> by Discord: there is no guarantee they will progress.

### Features

| | |
|---|---|
| 🎮 **Catalog** | 10,000+ detectable games, accent-insensitive search, favorites, recent, played games with their time |
| 🔁 **Rotation** | Queue of games run one at a time (N minutes each), pause / resume (`Ctrl+Alt+S`), skip, saved lists, export / import |
| 🚩 **Quest mode** | One game + the required duration: countdown, sound and notification, automatic stop |
| ⏱️ **Timer** | Stop everything after 30 min to 8 h or when the rotation ends, then nothing / sleep / shut down |
| 📊 **Stats** | Simulated time over 14 days, most played games, "Game Variety" counter |
| 🪟 **Fake games** | Small card with the game icon and a timer; color, size and screen corner are configurable |
| 🧩 **Comfort** | Always-on-top mini widget, notification area, launch with Windows (optional), desktop shortcut, diagnostics, French / English, 6 accent colors |
| 🪶 **Lightweight** | ~2–6% of one core and 60–130 MB; fake games stop with the app, even if it crashes |

<p align="center">
  <img src="assets/fake-game-cards.png" width="400" alt="Fake game cards">
  <img src="assets/settings.png" width="400" alt="Settings">
</p>

### Installation

1. **Requirements**: Windows 10 or 11, Windows PowerShell 5.1 and .NET Framework 4.x (installed by default), Discord desktop app.
2. Download the project (**Code → Download ZIP**) and extract it.
3. Double-click **`Lancer.bat`**. On first run the app compiles the fake exe and downloads the catalog.
4. Switch to English in **Settings → Language**, and create a desktop shortcut with the real icon in **Settings → Desktop shortcut**.

### Usage

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
