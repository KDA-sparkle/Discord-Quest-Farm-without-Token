# ============================================================
#  Quest Farm - UI (PowerShell + WPF)
#  Lance des faux processus (noms des jeux detectables Discord)
#  pour que Discord te voie "en train de jouer". Aucun token,
#  aucune donnee de compte, aucun binaire tiers telecharge.
#
#  app\MainWindow.xaml  interface principale
#  app\Widget.xaml      mini-widget toujours visible
#  app\Types.cs         types C# (catalogue, sessions, job, veille, raccourci...)
#  app\Stub.cs          source du faux exe (petite fenetre)
#  data\                cache du catalogue, etat, historique, stats par jour
#  games\               faux exe generes
#
#  -StartHidden : demarre cache dans la zone de notification (lancement avec Windows)
# ============================================================
param([switch]$StartHidden)   # (pas "$Tray" : PowerShell ignore la casse et $script:tray est l'icone)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase, System.Windows.Forms, System.Drawing

trap {
    [void][System.Windows.MessageBox]::Show("Erreur fatale / Fatal error :`n$($_.Exception.Message)", 'Quest Farm')
    break
}

$root = $PSScriptRoot
if (-not $root) { $root = (Get-Location).Path }
$appDir   = Join-Path $root 'app'
$dataDir  = Join-Path $root 'data'
$gamesDir = Join-Path $root 'games'
foreach ($d in $dataDir, $gamesDir) { [void][IO.Directory]::CreateDirectory($d) }
$paths = @{
    Catalog = Join-Path $dataDir 'catalog.tsv'
    State   = Join-Path $dataDir 'state.json'
    History = Join-Path $dataDir 'history.json'
    Daily   = Join-Path $dataDir 'daily.json'
    StubCfg = Join-Path $dataDir 'stub.cfg'     # reglages lus en direct par les faux jeux
}

# Un jeu compte pour "Game Variety" apres ce temps cumule (Discord ouvert).
# Le vrai seuil de Discord n'est pas public : 15 min est une estimation prudente.
$PlayedMinutes = 15
$Tiers = @( @(2, 'Sampler'), @(5, 'Dabbler'), @(10, 'Enthusiast'), @(100, 'Universalist') )

# Couleurs d'accent : couleur unie, nom affiche
$Accents = [ordered]@{
    blood   = @('#D61F45', 'Sang')
    sakura  = @('#FF7EB6', 'Sakura')
    cherry  = @('#FF4D8D', 'Cerise')
    lilac   = @('#B98CFF', 'Lilas')
    mint    = @('#7FD8C9', 'Menthe')
    rosegold = @('#E7A07F', 'Or rose')
}

# Lancement sans console (raccourci du bureau, demarrage avec Windows)
$Conhost = Join-Path $env:WINDIR 'System32\conhost.exe'
$LaunchArgs = '--headless "{0}" -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "{1}"' -f (Join-Path $PSHOME 'powershell.exe'), (Join-Path $root 'QuestSpoofer.ps1')
$RunKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
$ShortcutPath = Join-Path ([Environment]::GetFolderPath('Desktop')) 'Quest Farm.lnk'
$IcoPath = Join-Path $appDir 'QuestSpoofer.ico'

# --- Langue (lue tot : l'interface est traduite avant d'etre chargee) ---
$script:lang = 'fr'
try { $l = ([IO.File]::ReadAllText($paths.State) | ConvertFrom-Json).lang; if ($l -in 'fr', 'en') { $script:lang = $l } } catch {}
. (Join-Path $appDir 'i18n.ps1')

# --- Une seule instance : la 2e reveille la 1re puis quitte ---
$created = $false
$script:mutex = [Threading.Mutex]::new($true, 'Local\QuestSpoofer.Single', [ref]$created)
$script:showEvt = [Threading.EventWaitHandle]::new($false, [Threading.EventResetMode]::AutoReset, 'Local\QuestSpoofer.Show')
if (-not $created) { [void]$script:showEvt.Set(); return }

if (-not ('QsSession' -as [type])) {
    Add-Type -Path (Join-Path $appDir 'Types.cs'), (Join-Path $appDir 'Remote.cs') -ReferencedAssemblies System.Drawing, System.Web.Extensions, System.Xaml,
        ([Windows.Interop.HwndSource].Assembly.Location), ([Windows.Threading.Dispatcher].Assembly.Location)
}

# Identite propre dans la barre des taches (avant toute fenetre), sinon icone de PowerShell
[void][QsWin]::SetAppId('KDA-sparkle.QuestSpoofer')

# --- Compiler une fois le faux exe ---
$blank = Join-Path $gamesDir '_stub_v7.exe'
if (-not (Test-Path -LiteralPath $blank)) {
    $csc = Join-Path ([Runtime.InteropServices.RuntimeEnvironment]::GetRuntimeDirectory()) 'csc.exe'
    if (-not (Test-Path $csc)) { [void][Windows.MessageBox]::Show("csc.exe introuvable (.NET Framework requis)."); return }
    & $csc /nologo /target:winexe /r:System.Windows.Forms.dll /r:System.Drawing.dll /out:"$blank" (Join-Path $appDir 'Stub.cs') | Out-Null
    if (-not (Test-Path -LiteralPath $blank)) { [void][Windows.MessageBox]::Show("La compilation du faux exe a échoué."); return }
}
$stubBytes = [IO.File]::ReadAllBytes($blank)

# --- Interface : chaque element nomme devient une variable du meme nom ---
$xamlPath = Join-Path $appDir 'MainWindow.xaml'
$win = [Windows.Markup.XamlReader]::Parse((Convert-XamlLang ([IO.File]::ReadAllText($xamlPath))))
Set-StrResources $win.Resources
foreach ($m in [regex]::Matches([IO.File]::ReadAllText($xamlPath), 'x:Name="(\w+)"')) {
    $el = $win.FindName($m.Groups[1].Value)
    if ($el) { Set-Variable -Name $m.Groups[1].Value -Value $el }
}

# Coins arrondis Windows 11 + raccourci global Ctrl+Alt+S (pause de la rotation)
$script:hotkey = New-Object QsHotkey
$script:hotkeyOk = $false
$win.Add_SourceInitialized({
    $h = (New-Object Windows.Interop.WindowInteropHelper $win).Handle
    [QsWin]::Style($h)
    $script:hotkeyOk = $script:hotkey.Register($h, 3, 0x53)   # 3 = Ctrl + Alt, 0x53 = S
})
$script:hotkey.Add_Pressed({ Switch-RotationPause })

# Spinner de chargement : anime depuis le code pour pouvoir l'arreter vraiment
# (une animation cachee continuerait sinon a forcer le rendu)
$spin = New-Object Windows.Media.Animation.DoubleAnimation 0, 360, ([Windows.Duration][TimeSpan]::FromSeconds(0.9))
$spin.RepeatBehavior = [Windows.Media.Animation.RepeatBehavior]::Forever
[Windows.Media.Animation.Timeline]::SetDesiredFrameRate($spin, 30)
$SpinRot.BeginAnimation([Windows.Media.RotateTransform]::AngleProperty, $spin)
function Stop-Spinner {
    $SpinRot.BeginAnimation([Windows.Media.RotateTransform]::AngleProperty, $null)
    $Loader.Visibility = 'Collapsed'
}

$brushes = New-Object Windows.Media.BrushConverter
function Brush([string]$hex) { $brushes.ConvertFromString($hex) }
function ColorOf([string]$hex) { [Windows.Media.Color][Windows.Media.ColorConverter]::ConvertFromString($hex) }

# Le message est garde en francais (texte source) pour pouvoir le retraduire si la langue change
function Set-Status([string]$msg, [string]$kind = 'info') {
    $script:lastStatus = @($msg, $kind, (Get-Date))
    Write-StatusLine
}

function Write-StatusLine {
    $msg, $kind, $at = $script:lastStatus
    $color = @{ ok = '#7FD8C9'; err = '#FF4D6D'; warn = '#F5B971'; info = '#C7A9B6' }[$kind]
    $Status.Text = '{0:HH:mm}   {1}' -f $at, (L $msg)
    $Status.Foreground = Brush $color
}

# Fait apparaitre un element en fondu (opacite 0 -> 1, decelere)
function Start-Fade($el, [int]$ms) {
    $anim = New-Object Windows.Media.Animation.DoubleAnimation 0, 1, ([Windows.Duration][TimeSpan]::FromMilliseconds($ms))
    $ease = New-Object Windows.Media.Animation.CubicEase
    $ease.EasingMode = 'EaseOut'
    $anim.EasingFunction = $ease
    $el.BeginAnimation([Windows.UIElement]::OpacityProperty, $anim)
}

# "12 min", "1 h 05"
function Format-Duration([double]$sec) {
    $min = [int][Math]::Floor($sec / 60)
    if ($min -ge 60) { '{0} h {1:00}' -f [int][Math]::Floor($min / 60), ($min % 60) } else { "$min min" }
}

# "04:32" ou "1:04:32"
function Format-Clock([TimeSpan]$t) {
    if ($t -lt [TimeSpan]::Zero) { $t = [TimeSpan]::Zero }
    if ($t.TotalHours -ge 1) { '{0}:{1:00}:{2:00}' -f [int][Math]::Floor($t.TotalHours), $t.Minutes, $t.Seconds }
    else { '{0:00}:{1:00}' -f $t.Minutes, $t.Seconds }
}

# ============================================================
#  Zone de notification
# ============================================================
$appIcon = [QsIcon]::Create()
# Icone multi-tailles (16 a 256 px) : Windows choisit la bonne taille pour la barre des taches
try {
    [QsIcon]::SaveIco($IcoPath)
    $icoDecoder = New-Object Windows.Media.Imaging.IconBitmapDecoder ([Uri]$IcoPath),
        ([Windows.Media.Imaging.BitmapCreateOptions]::None), ([Windows.Media.Imaging.BitmapCacheOption]::OnLoad)
    $win.Icon = $icoDecoder.Frames[0]
} catch {
    $win.Icon = [Windows.Interop.Imaging]::CreateBitmapSourceFromHIcon($appIcon.Handle, [Windows.Int32Rect]::Empty,
        [Windows.Media.Imaging.BitmapSizeOptions]::FromEmptyOptions())
}

$script:tray = New-Object Windows.Forms.NotifyIcon
$script:tray.Icon = $appIcon
$script:tray.Text = 'Quest Farm'
$trayMenu = New-Object Windows.Forms.ContextMenuStrip
[void]$trayMenu.Items.Add((L 'Ouvrir Quest Farm'), $null, { Show-Main })
[void]$trayMenu.Items.Add((L 'Mini-widget'), $null, { if ($script:widgetOn) { Hide-Widget } else { Show-Widget } })
[void]$trayMenu.Items.Add((L 'Pause / reprise de la rotation'), $null, { Switch-RotationPause })
[void]$trayMenu.Items.Add('-')
[void]$trayMenu.Items.Add((L 'Quitter (arrête tout)'), $null, { $win.Close() })
$script:tray.ContextMenuStrip = $trayMenu
$script:tray.Add_DoubleClick({ Show-Main })
$script:tray.Add_BalloonTipClicked({ Show-Main })
$script:tray.Visible = $true
$script:trayHintShown = $false

function Show-Main {
    $win.Show()
    $win.WindowState = 'Normal'
    [void]$win.Activate()
}

function Hide-ToTray {
    $win.Hide()
    [QsMem]::Trim()
    if (-not $script:trayHintShown) {
        $script:trayHintShown = $true
        $script:tray.ShowBalloonTip(4000, 'Quest Farm', (L 'Toujours là… double-clic pour me retrouver ♡'), [Windows.Forms.ToolTipIcon]::Info)
    }
}

# Notification seulement si la fenetre n'est pas au premier plan
function Notify([string]$title, [string]$text) {
    if ($win.IsVisible -and $win.IsActive -and $win.WindowState -ne 'Minimized') { return }
    $script:tray.ShowBalloonTip(4000, (L $title), (L $text), [Windows.Forms.ToolTipIcon]::Info)
}

# Reduite, la fenetre n'est plus dessinee : on en profite pour rendre la memoire
$win.Add_StateChanged({ if ($win.WindowState -eq 'Minimized') { [QsMem]::Trim() } })

# ============================================================
#  Etat sauvegarde, historique, stats par jour
# ============================================================
function Read-Json([string]$path) {
    if (Test-Path -LiteralPath $path) {
        try { return ([IO.File]::ReadAllText($path) | ConvertFrom-Json) } catch {}
    }
    $null
}

function Write-Json($obj, [string]$path) {
    $tmp = "$path.tmp"
    [IO.File]::WriteAllText($tmp, ($obj | ConvertTo-Json -Depth 6), (New-Object Text.UTF8Encoding $false))
    if ([IO.File]::Exists($path)) { [IO.File]::Delete($path) }
    [IO.File]::Move($tmp, $path)
}

$script:favs = @{}
$script:recents = New-Object 'System.Collections.Generic.List[string]'
$script:lists = [ordered]@{}
$script:winMode = 'show'
$script:stubColor = 'accent'   # 'accent' ou une cle de $Accents
$script:stubSize = 'm'          # s, m, l
$script:stubCorner = 'br'       # br, bl, tr, tl
$script:tab = 'all'
$script:page = 'sessions'
$script:accent = 'blood'
$script:accentHex = '#D61F45'
$script:widgetWanted = $false
$script:widgetPos = $null
$script:endT = @{ At = $null; OnRotationEnd = $false; Action = 'none' }
$script:stateReady = $false   # pas de sauvegarde avant d'avoir restaure l'etat

$script:savedState = Read-Json $paths.State
if ($script:savedState) {
    $st = $script:savedState
    foreach ($id in @($st.favorites)) { if ($id) { $script:favs[[string]$id] = $true } }
    foreach ($id in @($st.recents)) { if ($id) { $script:recents.Add([string]$id) } }
    if ($st.lists) { foreach ($p in $st.lists.psobject.Properties) { $script:lists[$p.Name] = @($p.Value | ForEach-Object { [string]$_ }) } }
    if ($st.minutes) { $RotMinutes.Text = [string]$st.minutes }
    if ($st.questMinutes) { $QuestMinutes.Text = [string]$st.questMinutes }
    if ($null -ne $st.questMargin) { $ChkQuestMargin.IsChecked = [bool]$st.questMargin }
    if ($st.windowMode -eq 'min') { $script:winMode = 'min' }
    if ($st.stubColor -and ($st.stubColor -eq 'accent' -or $Accents.Contains([string]$st.stubColor))) { $script:stubColor = [string]$st.stubColor }
    if ($st.stubSize -in 's', 'm', 'l') { $script:stubSize = [string]$st.stubSize }
    if ($st.stubCorner -in 'br', 'bl', 'tr', 'tl') { $script:stubCorner = [string]$st.stubCorner }
    if ($st.tab) { $script:tab = [string]$st.tab }
    if ($st.page) { $script:page = [string]$st.page }
    if ($st.accent -and $Accents.Contains([string]$st.accent)) { $script:accent = [string]$st.accent }
    if ($st.widget) {
        $script:widgetWanted = [bool]$st.widget.on
        $wl = 0.0; $wt = 0.0   # position ignoree si elle n'est pas numerique
        if ([double]::TryParse([string]$st.widget.left, [ref]$wl) -and [double]::TryParse([string]$st.widget.top, [ref]$wt)) { $script:widgetPos = @($wl, $wt) }
    }
    if ($st.endAction) { $script:endT.Action = [string]$st.endAction }
    $script:remoteOn = [bool]$st.remoteOn
    if ($st.remotePin -match '^\d{6}$') { $script:remotePin = [string]$st.remotePin }
    $script:remoteTokens = @($st.remoteTokens | Where-Object { $_ -match '^[0-9a-f]{32}$' })
}

function Save-State {
    if (-not $script:stateReady) { return }
    $lists = [ordered]@{}
    foreach ($k in $script:lists.Keys) { $lists[$k] = @($script:lists[$k]) }
    $obj = [ordered]@{
        minutes      = Get-RotMinutes
        questMinutes = Get-QuestMinutes
        questMargin  = [bool]$ChkQuestMargin.IsChecked
        windowMode   = $script:winMode
        stubColor    = $script:stubColor
        stubSize     = $script:stubSize
        stubCorner   = $script:stubCorner
        tab          = $script:tab
        page         = $script:page
        accent       = $script:accent
        endAction    = $script:endT.Action
        # (un $(if ...) sans resultat deviendrait "{}" dans le JSON : on ecrit $null explicitement)
        widget       = [ordered]@{ on = $script:widgetOn; left = $(if ($script:widgetPos) { $script:widgetPos[0] } else { $null }); top = $(if ($script:widgetPos) { $script:widgetPos[1] } else { $null }) }
        queue        = @($script:rotItems | ForEach-Object { $_.Id })
        rotOn        = $script:rot.On
        rotIndex     = $script:rot.Index
        rotRemaining = if ($script:rot.On) { [int](Get-RotRemaining).TotalSeconds } else { 0 }
        favorites    = @($script:favs.Keys)
        recents      = @($script:recents)
        lists        = $lists
        lang         = $script:lang
        remoteOn     = [bool]$script:remoteOn
        remotePin    = $script:remotePin
        remoteTokens = @($script:remoteTokens)
    }
    try { Write-Json $obj $paths.State } catch {}
}

$script:history = @{}
$hist = Read-Json $paths.History
if ($hist) {
    foreach ($p in $hist.psobject.Properties) {
        $script:history[$p.Name] = @{ name = [string]$p.Value.name; sec = [double]$p.Value.sec; last = [string]$p.Value.last }
    }
}

# Temps simule par jour (graphique des stats), on garde 60 jours
$script:daily = @{}
$dj = Read-Json $paths.Daily
if ($dj) {
    $limit = (Get-Date).Date.AddDays(-60).ToString('yyyy-MM-dd')
    foreach ($p in $dj.psobject.Properties) { if ($p.Name -ge $limit) { $script:daily[$p.Name] = [double]$p.Value } }
}

function Save-History {
    try { Write-Json $script:history $paths.History } catch {}
    try { Write-Json $script:daily $paths.Daily } catch {}
}

function Test-Played([string]$id) {
    $e = $script:history[$id]
    [bool]($e -and $e.sec -ge $PlayedMinutes * 60)
}

function Get-PlayedCount {
    @($script:history.Values | Where-Object { $_.sec -ge $PlayedMinutes * 60 }).Count
}

function Update-Stats {
    $n = Get-PlayedCount
    $next = $Tiers | Where-Object { $_[0] -gt $n } | Select-Object -First 1
    $cur  = $Tiers | Where-Object { $_[0] -le $n } | Select-Object -Last 1
    $StatUnique.Text = $n
    $StatUniqueGoal.Text = if ($next) { " / $($next[0])" } else { '' }
    if ($cur -and $next) { $StatUniqueSub.Text = L "$($cur[1]) atteint · prochain : $($next[1])" }
    elseif ($next)       { $StatUniqueSub.Text = L "prochain palier : $($next[1])" }
    else                 { $StatUniqueSub.Text = L "$($cur[1]) atteint" }
}

# Pastille "temps joue" affichee sur la ligne du jeu dans le catalogue
function Update-PlayedLabel([string]$id) {
    $g = $script:byId[$id]
    $e = $script:history[$id]
    if (-not $g -or -not $e) { return }
    if ($e.sec -lt 60) { return }
    $g.IsPlayed = $e.sec -ge $PlayedMinutes * 60
    $label = Format-Duration $e.sec
    $g.Played = if ($g.IsPlayed) { "✓ $label" } else { $label }
}

function Add-Playtime([QsSession]$s, [double]$sec) {
    $day = (Get-Date).ToString('yyyy-MM-dd')
    $script:daily[$day] = [double]$script:daily[$day] + $sec
    if (-not $s.GameId) { return }
    $e = $script:history[$s.GameId]
    if (-not $e) { $e = @{ name = $s.Name; sec = 0.0; last = '' }; $script:history[$s.GameId] = $e }
    $th = $PlayedMinutes * 60
    $before = $e.sec
    $e.sec += $sec
    $e.last = (Get-Date).ToString('s')
    Update-PlayedLabel $s.GameId
    if ($before -lt $th -and $e.sec -ge $th) {
        $n = Get-PlayedCount
        Update-Stats
        Save-History
        Set-Status "✓ $($s.Name) compte comme joué · $n jeu(x) unique(s)" 'ok'
        Notify 'Jeu validé' "$($s.Name) · $n jeu(x) unique(s)"
    }
}

# ============================================================
#  Discord + pastille d'etat
# ============================================================
$script:discordUp = [QsDiscord]::IsRunning()

function Update-Pill {
    if (-not $script:allGames) { $s = @('Synchronisation', '#C7A9B6', 'Chargement du catalogue des jeux') }
    elseif ($script:discordUp) { $s = @('Discord actif', '#7FD8C9', 'Discord est ouvert : les spoofs sont pris en compte') }
    else { $s = @('Discord fermé', '#F5B971', 'Discord est fermé : rien ne compte tant qu''il n''est pas ouvert') }
    # Rectangle teinte de la couleur de l'etat (fond 13 %, bordure 33 %)
    $hex = $s[1].Substring(1)
    $PillText.Text = L $s[0]
    $PillText.Foreground = Brush $s[1]
    $PillDot.Fill = Brush $s[1]
    $Pill.Background = Brush ('#22' + $hex)
    $Pill.BorderBrush = Brush ('#55' + $hex)
    $Pill.ToolTip = L $s[2]
}

# Onglet actif (couleur d'accent) ou inactif
function Set-SegStyle($btn, [bool]$on) {
    $btn.Background  = Brush $(if ($on) { '#26' + $script:accentHex.Substring(1) } else { '#00000000' })
    $btn.BorderBrush = Brush '#00000000'
    $btn.Foreground  = Brush $(if ($on) { $script:accentHex } else { '#C7A9B6' })
}

# ============================================================
#  Catalogue (cache disque puis mise a jour reseau)
# ============================================================
$script:sessions = New-Object System.Collections.ObjectModel.ObservableCollection[QsSession]
$Active.ItemsSource = $script:sessions
$script:allGames = $null
$script:byId = @{}
$script:catalogOk = $false
$script:lastFetch = [DateTime]::MinValue

function Get-TabSource {
    switch ($script:tab) {
        'fav' {
            $l = New-Object 'System.Collections.Generic.List[QsGame]'
            foreach ($id in $script:favs.Keys) { $g = $script:byId[$id]; if ($g) { $l.Add($g) } }
            [QsCatalog]::Sort($l)
            return , $l
        }
        'recent' {
            $l = New-Object 'System.Collections.Generic.List[QsGame]'
            foreach ($id in $script:recents) { $g = $script:byId[$id]; if ($g) { $l.Add($g) } }
            return , $l
        }
        'played' {
            # Les plus recemment joues d'abord
            $l = New-Object 'System.Collections.Generic.List[QsGame]'
            $ids = $script:history.Keys | Sort-Object { $script:history[$_].last } -Descending
            foreach ($id in $ids) { $g = $script:byId[$id]; if ($g -and $g.Played) { $l.Add($g) } }
            return , $l
        }
        default { return , $script:allGames }
    }
}

function Apply-Filter {
    if (-not $script:allGames) { return }
    $src = Get-TabSource
    $q = $Search.Text.Trim()
    $r = [QsCatalog]::Filter($src, $q)
    $Games.ItemsSource = $r
    $ResultCount.Text = if ($q) { '{0:N0} / {1:N0}' -f $r.Count, $src.Count } else { '{0:N0}' -f $r.Count }
    if ($r.Count) { $ListEmpty.Visibility = 'Collapsed'; return }
    if ($q) { $ListEmpty.Text = L "Aucun jeu ne correspond à « $q »." }
    elseif ($script:tab -eq 'fav') { $ListEmpty.Text = L "Aucun favori.`nSurvole un jeu et clique sur l'étoile (ou Ctrl+D)." }
    elseif ($script:tab -eq 'played') { $ListEmpty.Text = L "Aucun jeu joué pour l'instant.`nLe temps compte quand Discord est ouvert." }
    else { $ListEmpty.Text = L 'Aucun jeu lancé récemment.' }
    $ListEmpty.Visibility = 'Visible'
}

function Update-TabLabels {
    $TabFav.Content = L $(if ($script:favs.Count) { "Favoris · $($script:favs.Count)" } else { 'Favoris' })
}

function Update-TabStyles {
    foreach ($pair in @(@($TabAll, 'all'), @($TabFav, 'fav'), @($TabRecent, 'recent'), @($TabPlayed, 'played'))) {
        Set-SegStyle $pair[0] ($pair[1] -eq $script:tab)
    }
}

function Set-Tab([string]$t) {
    $script:tab = $t
    Update-TabStyles
    Update-TabLabels
    Apply-Filter
    Save-State
}

function Set-Catalog($list) {
    $script:allGames = $list
    $script:byId = @{}
    foreach ($g in $list) {
        $script:byId[$g.Id] = $g
        if ($script:favs.ContainsKey($g.Id)) { $g.IsFav = $true }
    }
    # La file de rotation et la quete pointent vers les nouveaux objets
    for ($i = 0; $i -lt $script:rotItems.Count; $i++) {
        $n = $script:byId[$script:rotItems[$i].Id]
        if ($n) { $script:rotItems[$i] = $n }
    }
    if ($script:questGame -and -not $script:qst.On) { $n = $script:byId[$script:questGame.Id]; if ($n) { $script:questGame = $n } }
    foreach ($id in @($script:history.Keys)) { Update-PlayedLabel $id }
    $script:remote.Catalog = $list
    $StatGames.Text = '{0:N0}' -f $list.Count
    Stop-Spinner
    Update-Pill
    Apply-Filter
    if (-not $script:stateReady) { Restore-State }
}

# Telechargement en C# sur un thread du pool (cf. QsCatalog.FetchAsync) :
# bien plus leger qu'un second PowerShell, et rien ne retient la fermeture.
function Start-CatalogFetch {
    if ($script:loadTask) { return }
    $script:lastFetch = Get-Date
    $script:loadTask = [QsCatalog]::FetchAsync('https://discord.com/api/v10/applications/detectable', $paths.Catalog)
}

function Complete-Load {
    $task = $script:loadTask
    $script:loadTask = $null
    try {
        if ($task.IsFaulted) { throw $task.Exception.GetBaseException() }
        $list = $task.Result
        $sel = $Games.SelectedItem
        Set-Catalog $list
        if ($sel) { $Games.SelectedItem = $script:byId[$sel.Id] }
        $script:catalogOk = $true
        $script:catalogSub = 'jeux détectables · à jour'
        $StatGamesSub.Text = L $script:catalogSub
        Set-Status ('Catalogue synchronisé · {0:N0} jeux Windows' -f $list.Count) 'ok'
    } catch {
        Stop-Spinner
        if ($script:allGames) {
            Set-Status "Hors ligne : catalogue en cache utilisé ($($_.Exception.Message))" 'warn'
        } else {
            $ListEmpty.Text = L "Impossible de charger le catalogue.`nVérifie ta connexion puis réessaie (Réglages → Actualiser)."
            $ListEmpty.Visibility = 'Visible'
            Set-Status "Impossible de récupérer la liste des jeux : $($_.Exception.Message)" 'err'
        }
    } finally {
        $task.Dispose()
        [QsMem]::Trim()   # le JSON brut (plusieurs Mo) n'est plus utile
    }
}

# ============================================================
#  Lancement / arret
# ============================================================
function Update-Ui {
    $n = $script:sessions.Count
    $StatActive.Text = $n
    $Empty.Visibility = if ($n) { 'Collapsed' } else { 'Visible' }
    $BtnStopAll.IsEnabled = $n -gt 0
}

function Add-Recent([string]$id) {
    if (-not $id) { return }
    [void]$script:recents.Remove($id)
    $script:recents.Insert(0, $id)
    while ($script:recents.Count -gt 30) { $script:recents.RemoveAt($script:recents.Count - 1) }
    if ($script:tab -eq 'recent') { Apply-Filter }
    Save-State
}

function Get-StubColor { if ($script:stubColor -eq 'accent') { $script:accentHex } else { $Accents[$script:stubColor][0] } }

# Arguments du faux exe : apparence choisie dans les reglages (couleur, taille, coin, langue).
# --config : le faux jeu relit ensuite data\stub.cfg chaque seconde (changements en direct).
function Get-StubArgs([string]$title, [int]$slot, [string]$iconUrl, [switch]$NoConfig) {
    $a = '--title "{0}" --slot {1} --mode {2} --color {3} --size {4} --corner {5} --lang {6}' -f $title, $slot, $script:winMode, (Get-StubColor), $script:stubSize, $script:stubCorner, $script:lang
    if ($iconUrl) { $a += ' --icon "{0}"' -f $iconUrl }
    if (-not $NoConfig) { $a += ' --config "{0}"' -f $paths.StubCfg }
    $a
}

# Ecrit les reglages lus en direct par les faux jeux deja ouverts
function Write-StubConfig {
    $txt = "color=$(Get-StubColor)`nsize=$($script:stubSize)`ncorner=$($script:stubCorner)`nlang=$($script:lang)`nmode=$($script:winMode)`n"
    try {
        if ([IO.File]::Exists($paths.StubCfg) -and [IO.File]::ReadAllText($paths.StubCfg) -eq $txt) { return }
        [IO.File]::WriteAllText($paths.StubCfg, $txt)
    } catch {}
}

# -Kind : "Rotation", "Quête" ou rien (lancement manuel)
function Start-Spoof([QsGame]$game, [string]$Kind = '') {
    foreach ($s in $script:sessions) {
        if ($s.ExePath -eq $game.ExePath) { Set-Status "$($game.Name) tourne déjà" 'warn'; return }
    }

    # Le faux exe doit rester dans games\
    $rootFull = [IO.Path]::GetFullPath($gamesDir).TrimEnd('\') + '\'
    $target = [IO.Path]::GetFullPath((Join-Path $gamesDir $game.ExePath))
    if (-not $target.StartsWith($rootFull, [StringComparison]::OrdinalIgnoreCase)) {
        Set-Status "Chemin refusé : $($game.ExePath)" 'err'; return
    }

    try {
        [void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($target))
        # Recopie si absent ou ancienne version
        $same = [IO.File]::Exists($target) -and
                [Linq.Enumerable]::SequenceEqual([byte[]][IO.File]::ReadAllBytes($target), [byte[]]$stubBytes)
        if (-not $same) { [IO.File]::Copy($blank, $target, $true) }
        $title = $game.Name.Replace('"', "'").TrimEnd('\')
        $psi = New-Object Diagnostics.ProcessStartInfo $target
        $psi.Arguments = Get-StubArgs $title $script:sessions.Count $game.IconUrl
        $psi.UseShellExecute = $false
        $psi.WorkingDirectory = [IO.Path]::GetDirectoryName($target)
        $p = [Diagnostics.Process]::Start($psi)
    } catch {
        Set-Status "Échec du lancement de $($game.Name) : $($_.Exception.Message)" 'err'; return
    }
    [void][QsJob]::Attach($p)

    $s = New-Object QsSession
    $s.Name = $game.Name
    $s.ExePath = $game.ExePath
    $s.GameId = $game.Id
    $s.IconUrl = $game.IconUrl
    $s.Initial = $game.Initial
    $s.Proc = $p
    $s.Start = Get-Date
    $s.LastCount = $s.Start
    $s.Kind = $Kind
    $s.KindLabel = L $Kind
    $script:sessions.Insert(0, $s)
    Update-Ui
    Add-Recent $game.Id
    Set-Status "Spoof actif · $($game.Name)" 'ok'
    $s
}

function Stop-Session([QsSession]$s) {
    try { if (-not $s.Proc.HasExited) { $s.Proc.Kill() } } catch {}
    [void]$script:sessions.Remove($s)
}

function Toggle-Fav([QsGame]$g) {
    $g.IsFav = -not $g.IsFav
    if ($g.IsFav) { $script:favs[$g.Id] = $true; Set-Status "Ajouté aux favoris · $($g.Name)" 'ok' }
    else { $script:favs.Remove($g.Id); Set-Status "Retiré des favoris · $($g.Name)" }
    Update-TabLabels
    if ($script:tab -eq 'fav') { Apply-Filter }
    Save-State
}

# ============================================================
#  Rotation automatique : un jeu a la fois, N minutes chacun
# ============================================================
$script:rotItems = New-Object System.Collections.ObjectModel.ObservableCollection[QsGame]
$QueueList.ItemsSource = $script:rotItems
$script:rot = @{ On = $false; Index = 0; Started = [DateTime]::MinValue; Next = [DateTime]::MinValue
                 Session = $null; Paused = $false; UserPaused = $false; PausedAt = [DateTime]::MinValue }
$rotScale = New-Object Windows.Media.ScaleTransform 0, 1
$RotBar.RenderTransform = $rotScale

function Get-RotMinutes {
    $m = 0
    if ([int]::TryParse($RotMinutes.Text, [ref]$m) -and $m -ge 1) { $m } else { 30 }
}

function Get-RotNow { if ($script:rot.Paused) { $script:rot.PausedAt } else { Get-Date } }

function Get-RotRemaining {
    $left = $script:rot.Next - (Get-RotNow)
    if ($left -lt [TimeSpan]::Zero) { [TimeSpan]::Zero } else { $left }
}

function Update-Rot {
    $n = $script:rotItems.Count
    if ($script:rot.On) {
        $cur = 'Jeu {0}/{1} · {2}' -f ($script:rot.Index + 1), $n, $script:rotItems[$script:rot.Index].Name
        if ($script:rot.UserPaused) {
            $RotInfo.Text = L "En pause · $cur"
            $RotInfo.Foreground = Brush '#F5B971'
        } elseif ($script:rot.Paused) {
            $RotInfo.Text = L "En pause (Discord fermé) · $cur"
            $RotInfo.Foreground = Brush '#F5B971'
        } else {
            $RotInfo.Text = L $cur
            $RotInfo.Foreground = Brush '#F7ECF1'
        }
        $BtnRotate.Content = L 'Arrêter'
        $RotCountdown.Text = Format-Clock (Get-RotRemaining)
    } else {
        $RotInfo.Text = L $(if ($n) { "$n jeu(x) en file · $(Get-RotMinutes) min chacun" } else { 'Ajoute des jeux à la file, puis démarre.' })
        $RotInfo.Foreground = Brush '#C7A9B6'
        $BtnRotate.Content = L 'Démarrer'
        $RotCountdown.Text = '--:--'
        $rotScale.ScaleX = 0
    }
    $BtnRotate.IsEnabled = ($n -gt 0) -or $script:rot.On
    $BtnClearQueue.IsEnabled = $n -gt 0
    $BtnPause.Visibility = if ($script:rot.On) { 'Visible' } else { 'Collapsed' }
    $BtnPause.Content = if ($script:rot.UserPaused) { [string][char]0xE768 } else { [string][char]0xE769 }
    $BtnNext.Visibility = if ($script:rot.On -and $script:rot.Index + 1 -lt $n) { 'Visible' } else { 'Collapsed' }
}

function Update-RotClock {
    if (-not $script:rot.Session) { return }
    $RotCountdown.Text = Format-Clock (Get-RotRemaining)
    $span = ($script:rot.Next - $script:rot.Started).TotalSeconds
    $rotScale.ScaleX = [Math]::Min([double]1, [double](((Get-RotNow) - $script:rot.Started).TotalSeconds / $span))
}

function Add-ToQueue([QsGame]$g) {
    if ($script:rotItems.Contains($g)) { Set-Status "$($g.Name) est déjà dans la file" 'warn'; return }
    $script:rotItems.Add($g)
    Update-Rot
    Save-State
    Set-Status "Ajouté à la rotation · $($g.Name)" 'ok'
}

function Stop-RotationSession {
    if ($script:rot.Session) {
        Stop-Session $script:rot.Session
        $script:rot.Session = $null
        Update-Ui
    }
}

function Stop-Rotation([string]$msg = 'Rotation arrêtée') {
    Stop-RotationSession
    $script:rot.On = $false
    $script:rot.Paused = $false
    $script:rot.UserPaused = $false
    Update-Rot
    Save-State
    Set-Status $msg
}

# Lance le jeu courant de la file (saute ceux qui echouent) ou termine.
# -RemainingSec : reprise (redemarrage, fin de pause) avec le temps restant.
function Step-Rotation([int]$RemainingSec = 0) {
    Stop-RotationSession
    $script:rot.UserPaused = $false
    while ($script:rot.Index -lt $script:rotItems.Count) {
        $g = $script:rotItems[$script:rot.Index]
        $s = Start-Spoof $g -Kind 'Rotation'
        if ($s) {
            $total = [TimeSpan]::FromMinutes((Get-RotMinutes))
            $left = $total
            if ($RemainingSec -gt 0 -and $RemainingSec -lt $total.TotalSeconds) { $left = [TimeSpan]::FromSeconds($RemainingSec) }
            $script:rot.Session = $s
            $script:rot.Next = (Get-Date) + $left
            $script:rot.Started = $script:rot.Next - $total
            $script:rot.Paused = $false
            Update-Rot
            Update-RotClock
            Save-State
            Notify 'Rotation' ('Jeu {0}/{1} · {2}' -f ($script:rot.Index + 1), $script:rotItems.Count, $g.Name)
            return
        }
        $script:rot.Index++
        $RemainingSec = 0
    }
    $n = $script:rotItems.Count
    Stop-Rotation ('Rotation terminée · {0} jeu(x) joué(s)' -f $n)
    Notify 'Rotation terminée' "$n jeu(x) joué(s)"
    if ($script:endT.OnRotationEnd) { Invoke-EndAction 'Rotation terminée' }
}

# Pause manuelle (bouton, Ctrl+Alt+S, zone de notification) : le faux jeu est
# arrete et le temps restant garde ; la reprise relance le meme jeu.
function Switch-RotationPause {
    if (-not $script:rot.On) {
        Set-Status 'Aucune rotation en cours' 'warn'
        Notify 'Quest Farm' 'Aucune rotation en cours.'
        return
    }
    if ($script:rot.UserPaused) {
        $rem = [int](Get-RotRemaining).TotalSeconds
        Step-Rotation -RemainingSec ([Math]::Max(1, $rem))
        Set-Status 'Rotation reprise' 'ok'
        Notify 'Rotation reprise' $script:rotItems[$script:rot.Index].Name
    } else {
        if (-not $script:rot.Paused) { $script:rot.PausedAt = Get-Date }
        $script:rot.Paused = $true
        $script:rot.UserPaused = $true
        Stop-RotationSession
        Update-Rot
        Save-State
        Set-Status 'Rotation en pause (Ctrl+Alt+S pour reprendre)' 'warn'
        Notify 'Rotation en pause' 'Ctrl+Alt+S pour reprendre.'
    }
}

function Remove-FromQueue([QsGame]$g) {
    $i = $script:rotItems.IndexOf($g)
    if ($i -lt 0) { return }
    $script:rotItems.RemoveAt($i)
    if ($script:rot.On) {
        if ($i -lt $script:rot.Index) { $script:rot.Index-- }
        elseif ($i -eq $script:rot.Index) { Step-Rotation; return }
    }
    Update-Rot
    Save-State
}

# Reprend la file (et la rotation en cours) de la derniere fois
function Restore-State {
    $script:stateReady = $true
    $st = $script:savedState
    if (-not $st) { return }
    foreach ($id in @($st.queue)) {
        $g = $script:byId[[string]$id]
        if ($g -and -not $script:rotItems.Contains($g)) { $script:rotItems.Add($g) }
    }
    Update-Rot
    if ($st.rotOn -and $script:rotItems.Count) {
        $idx = [int]$st.rotIndex
        if ($idx -ge $script:rotItems.Count) { $idx = 0 }
        $script:rot.On = $true
        $script:rot.Index = $idx
        Step-Rotation -RemainingSec ([int]$st.rotRemaining)
        Set-Status ('Rotation reprise · jeu {0}/{1}' -f ($idx + 1), $script:rotItems.Count) 'ok'
    }
}

# ============================================================
#  Mode quete : un jeu, une duree, arret automatique
# ============================================================
$script:qst = @{ On = $false; Game = $null; Session = $null; Started = [DateTime]::MinValue; Next = [DateTime]::MinValue
                 Paused = $false; PausedAt = [DateTime]::MinValue }
$script:questGame = $null
$questScale = New-Object Windows.Media.ScaleTransform 0, 1
$QuestBar.RenderTransform = $questScale

function Get-QuestMinutes {
    $m = 0
    if ([int]::TryParse($QuestMinutes.Text, [ref]$m) -and $m -ge 1) { $m } else { 15 }
}

function Get-QuestNow { if ($script:qst.Paused) { $script:qst.PausedAt } else { Get-Date } }

function Set-QuestGame($g) {
    if ($script:qst.On) { return }
    $script:questGame = $g
    if ($g) {
        $QuestName.Text = $g.Name
        $QuestExe.Text = $g.ExePath
        $QuestInitial.Text = $g.Initial
        $QuestIcon.Source = if ($g.IconUrl) { New-Object Windows.Media.Imaging.BitmapImage ([Uri]$g.IconUrl) } else { $null }
    } else {
        $QuestName.Text = L 'Aucun jeu sélectionné'
        $QuestExe.Text = L 'Sélectionne un jeu dans le catalogue à gauche'
        $QuestInitial.Text = '?'
        $QuestIcon.Source = $null
    }
    Update-Quest
}

function Update-Quest {
    $on = $script:qst.On
    $QuestRun.Visibility = if ($on) { 'Visible' } else { 'Collapsed' }
    $BtnQuest.IsEnabled = (-not $on) -and [bool]$script:questGame
    $QuestMinutes.IsEnabled = -not $on
    Update-QuestClock
}

function Update-QuestClock {
    if (-not $script:qst.On) { return }
    $now = Get-QuestNow
    $total = ($script:qst.Next - $script:qst.Started).TotalSeconds
    $done = [Math]::Min([double]1, [double](($now - $script:qst.Started).TotalSeconds / $total))
    $QuestCountdown.Text = Format-Clock ($script:qst.Next - $now)
    $questScale.ScaleX = $done
    $QuestPct.Text = '{0:N0} %' -f ($done * 100)
    if ($script:qst.Paused) {
        $QuestInfo.Text = L "En pause (Discord fermé) · $($script:qst.Game.Name)"
        $QuestInfo.Foreground = Brush '#F5B971'
    } else {
        $QuestInfo.Text = L "En cours · $($script:qst.Game.Name)"
        $QuestInfo.Foreground = Brush '#C7A9B6'
    }
}

function Start-Quest {
    $g = $script:questGame
    if (-not $g) { Set-Status "Choisis d'abord un jeu dans le catalogue" 'warn'; return }
    if ($script:qst.On) { return }
    $min = (Get-QuestMinutes) + $(if ($ChkQuestMargin.IsChecked) { 2 } else { 0 })
    $s = Start-Spoof $g -Kind 'Quête'
    if (-not $s) { return }
    $now = Get-Date
    $script:qst.On = $true
    $script:qst.Game = $g
    $script:qst.Session = $s
    $script:qst.Started = $now
    $script:qst.Next = $now.AddMinutes($min)
    $script:qst.Paused = $false
    Update-Quest
    Save-State
    Set-Status "Quête lancée · $($g.Name) · $min min" 'ok'
}

function Stop-Quest([string]$msg = 'Quête arrêtée', [switch]$Done) {
    if (-not $script:qst.On) { return }
    $name = $script:qst.Game.Name
    if ($script:qst.Session) { Stop-Session $script:qst.Session; Update-Ui }
    $script:qst.On = $false
    $script:qst.Session = $null
    $script:qst.Paused = $false
    Update-Quest
    if ($Done) {
        [System.Media.SystemSounds]::Asterisk.Play()
        Set-Status "✓ Quête terminée · $name : le temps demandé est atteint" 'ok'
        Notify 'Quête terminée' "$name : le temps demandé est atteint."
    } else {
        Set-Status $msg
    }
}

# ============================================================
#  Minuterie de fin
# ============================================================
function Update-TimerUi {
    if ($script:endT.At) {
        $TimerText.Text = Format-Clock ($script:endT.At - (Get-Date))
        $BtnTimer.Foreground = Brush $script:accentHex
    } elseif ($script:endT.OnRotationEnd) {
        $TimerText.Text = L 'Fin de rotation'
        $BtnTimer.Foreground = Brush $script:accentHex
    } else {
        $TimerText.Text = L 'Minuterie'
        $BtnTimer.ClearValue([Windows.Controls.Control]::ForegroundProperty)
    }
}

function Set-EndTimer([int]$minutes) {
    $script:endT.At = (Get-Date).AddMinutes($minutes)
    Update-TimerUi
    $then = @{ none = ''; sleep = ', puis mise en veille'; shutdown = ', puis arrêt du PC' }[$script:endT.Action]
    Set-Status ("Minuterie : tout s'arrête à {0:HH:mm}{1}" -f $script:endT.At, $then) 'ok'
}

function Clear-EndTimer {
    $script:endT.At = $null
    $script:endT.OnRotationEnd = $false
    Update-TimerUi
    Set-Status 'Minuterie annulée'
}

function Invoke-EndAction([string]$reason) {
    $script:endT.At = $null
    $script:endT.OnRotationEnd = $false
    if ($script:rot.On) { Stop-Rotation }
    if ($script:qst.On) { Stop-Quest }
    foreach ($s in @($script:sessions)) { Stop-Session $s }
    Update-Ui
    Update-TimerUi
    Save-State
    Save-History
    switch ($script:endT.Action) {
        'sleep' {
            Set-Status "$reason : tout est arrêté, mise en veille du PC" 'ok'
            [void][Windows.Forms.Application]::SetSuspendState([Windows.Forms.PowerState]::Suspend, $false, $false)
        }
        'shutdown' {
            Set-Status "$reason : arrêt du PC dans 60 s (Win+R puis « shutdown /a » pour annuler)" 'warn'
            Notify 'Arrêt du PC dans 60 s' 'Pour annuler : Win+R puis « shutdown /a ».'
            Start-Process -FilePath (Join-Path $env:WINDIR 'System32\shutdown.exe') -WindowStyle Hidden `
                -ArgumentList '/s /t 60 /c "Quest Farm : arret programme. Win+R puis shutdown /a pour annuler."'
        }
        default {
            Set-Status "$reason : tout est arrêté" 'ok'
            Notify 'Minuterie' 'Tout est arrêté.'
        }
    }
}

# ============================================================
#  Menus sombres (minuterie, listes)
# ============================================================
function New-DarkMenu {
    $m = New-Object Windows.Controls.ContextMenu
    $m.Style = $win.Resources[[Windows.Controls.ContextMenu]]
    $m
}

# Le handler recoit le MenuItem en $args[0] : la donnee utile passe par Tag
function Add-MenuItem($menu, [string]$header, $tag, [scriptblock]$onClick, [bool]$checked = $false, [bool]$enabled = $true) {
    $mi = New-Object Windows.Controls.MenuItem
    $mi.Style = $win.Resources[[Windows.Controls.MenuItem]]
    $mi.Header = L $header
    $mi.Tag = $tag
    $mi.IsChecked = $checked
    $mi.IsEnabled = $enabled
    $mi.Add_Click($onClick)
    [void]$menu.Items.Add($mi)
}

function Add-MenuSeparator($menu) {
    $s = New-Object Windows.Controls.Separator
    $s.Style = $win.Resources[[Windows.Controls.Separator]]
    [void]$menu.Items.Add($s)
}

function Open-Menu($menu, $target) {
    $menu.PlacementTarget = $target
    $menu.Placement = 'Bottom'
    $menu.IsOpen = $true
}

function Show-TimerMenu {
    $m = New-DarkMenu
    foreach ($p in @(@(30, '30 min'), @(60, '1 h'), @(120, '2 h'), @(240, '4 h'), @(480, '8 h'))) {
        Add-MenuItem $m "Tout arrêter dans $($p[1])" $p[0] { param($src) Set-EndTimer ([int]$src.Tag) }
    }
    Add-MenuSeparator $m
    Add-MenuItem $m 'Tout arrêter à la fin de la rotation' $null {
        $script:endT.OnRotationEnd = -not $script:endT.OnRotationEnd
        Update-TimerUi
        Set-Status $(if ($script:endT.OnRotationEnd) { 'Tout s''arrêtera à la fin de la rotation' } else { 'Arrêt en fin de rotation désactivé' })
    } $script:endT.OnRotationEnd
    Add-MenuSeparator $m
    foreach ($a in @(@('none', 'Ensuite : ne rien faire'), @('sleep', 'Ensuite : mettre le PC en veille'), @('shutdown', 'Ensuite : éteindre le PC'))) {
        Add-MenuItem $m $a[1] $a[0] { param($src) $script:endT.Action = $src.Tag; Save-State; Set-Status "Action de fin : $($src.Header.ToLower())" } ($script:endT.Action -eq $a[0])
    }
    Add-MenuSeparator $m
    Add-MenuItem $m 'Annuler la minuterie' $null { Clear-EndTimer } $false ([bool]$script:endT.At -or $script:endT.OnRotationEnd)
    Open-Menu $m $BtnTimer
}

# ============================================================
#  Listes enregistrees, export / import de la file
# ============================================================
function Read-Text([string]$title, [string]$prompt, [string]$default) {
    $x = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Width="400" SizeToContent="Height" WindowStyle="None" AllowsTransparency="True" Background="Transparent" ResizeMode="NoResize"
        WindowStartupLocation="CenterOwner" ShowInTaskbar="False" FontFamily="Segoe UI Variable Text, Segoe UI">
  <Border Margin="12" CornerRadius="14" Background="#1C0D18" BorderBrush="#3B2237" BorderThickness="1" Padding="20,18">
    <Border.Effect><DropShadowEffect BlurRadius="22" ShadowDepth="0" Opacity="0.6" Color="Black"/></Border.Effect>
    <StackPanel>
      <TextBlock x:Name="T" Foreground="#F7ECF1" FontSize="15" FontWeight="SemiBold"/>
      <TextBlock x:Name="P" Foreground="#C7A9B6" FontSize="12" Margin="0,4,0,12" TextWrapping="Wrap"/>
      <Border Background="#241323" BorderBrush="#46283F" BorderThickness="1" CornerRadius="8" Height="38">
        <TextBox x:Name="I" Background="Transparent" BorderThickness="0" Foreground="#F7ECF1" CaretBrush="#F7ECF1" FontSize="13.5"
                 VerticalContentAlignment="Center" Padding="10,0"/>
      </Border>
      <StackPanel Orientation="Horizontal" HorizontalAlignment="Right" Margin="0,16,0,0">
        <Button x:Name="C" Content="Annuler" IsCancel="True" Margin="0,0,8,0"/>
        <Button x:Name="O" Content="Enregistrer" IsDefault="True" Width="120" Height="32" FontSize="12.5"/>
      </StackPanel>
    </StackPanel>
  </Border>
</Window>
'@
    $dlg = [Windows.Markup.XamlReader]::Parse((Convert-XamlLang $x))
    Set-StrResources $dlg.Resources
    $dlg.Resources['Accent'] = $win.Resources['Accent']
    $dlg.Resources['Cyan'] = $win.Resources['Cyan']
    $dlg.FindName('C').Style = $win.Resources['Chip']
    $dlg.FindName('O').Style = $win.Resources['Primary']
    $dlg.FindName('T').Text = L $title
    $dlg.FindName('P').Text = L $prompt
    $box = $dlg.FindName('I')
    $box.Text = L $default
    # $this = l'element qui declenche l'evenement (pas de dependance aux variables locales)
    $dlg.FindName('O').Add_Click({ [Windows.Window]::GetWindow($this).DialogResult = $true })
    if ($win.IsVisible) { $dlg.Owner = $win } else { $dlg.WindowStartupLocation = 'CenterScreen' }
    $dlg.Add_ContentRendered({ $i = $this.FindName('I'); [void]$i.Focus(); $i.SelectAll() })
    if ($dlg.ShowDialog()) { $box.Text.Trim() } else { $null }
}

function Save-QueueAs {
    if (-not $script:rotItems.Count) { return }
    $name = Read-Text 'Enregistrer la file' 'Donne un nom à cette liste de jeux.' ("Liste {0}" -f ($script:lists.Count + 1))
    if (-not $name) { return }
    $script:lists[$name] = @($script:rotItems | ForEach-Object { $_.Id })
    Save-State
    Set-Status "Liste enregistrée · $name ($($script:rotItems.Count) jeux)" 'ok'
}

function Import-SavedList([string]$name) {
    if ($script:rot.On) { Set-Status 'Arrête la rotation avant de charger une autre liste' 'warn'; return }
    $script:rotItems.Clear()
    foreach ($id in @($script:lists[$name])) { $g = $script:byId[$id]; if ($g) { $script:rotItems.Add($g) } }
    Update-Rot
    Save-State
    Set-Status "Liste chargée · $name ($($script:rotItems.Count) jeux)" 'ok'
}

function Export-Queue {
    if (-not $script:rotItems.Count) { return }
    $dlg = New-Object Microsoft.Win32.SaveFileDialog
    $dlg.Title = L 'Exporter la file de rotation'
    $dlg.Filter = 'File Quest Farm (*.json)|*.json'
    $dlg.FileName = 'rotation-quest-spoofer.json'
    if (-not $dlg.ShowDialog($win)) { return }
    $obj = [ordered]@{ app = 'QuestSpoofer'; version = 1; games = @($script:rotItems | ForEach-Object { [ordered]@{ id = $_.Id; name = $_.Name } }) }
    try { Write-Json $obj $dlg.FileName; Set-Status "File exportée · $($dlg.FileName)" 'ok' }
    catch { Set-Status "Échec de l'export : $($_.Exception.Message)" 'err' }
}

function Import-QueueFile {
    $dlg = New-Object Microsoft.Win32.OpenFileDialog
    $dlg.Title = L 'Importer une file de rotation'
    $dlg.Filter = 'File Quest Farm (*.json)|*.json|Tous les fichiers (*.*)|*.*'
    if (-not $dlg.ShowDialog($win)) { return }
    $obj = Read-Json $dlg.FileName
    if (-not $obj -or -not $obj.games) { Set-Status 'Fichier invalide : aucune liste de jeux trouvée' 'err'; return }
    $added = 0; $missing = 0
    foreach ($e in @($obj.games)) {
        $g = $script:byId[[string]$e.id]
        if (-not $g) { $missing++; continue }
        if (-not $script:rotItems.Contains($g)) { $script:rotItems.Add($g); $added++ }
    }
    Update-Rot
    Save-State
    $msg = "$added jeu(x) importé(s)"
    if ($missing) { $msg += ", $missing introuvable(s) dans le catalogue" }
    Set-Status $msg $(if ($missing) { 'warn' } else { 'ok' })
}

function Show-ListsMenu {
    $m = New-DarkMenu
    Add-MenuItem $m 'Enregistrer la file sous…' $null { Save-QueueAs } $false ($script:rotItems.Count -gt 0)
    if ($script:lists.Count) {
        Add-MenuSeparator $m
        foreach ($n in @($script:lists.Keys)) {
            Add-MenuItem $m ('Charger « {0} » · {1} jeux' -f $n, @($script:lists[$n]).Count) $n { param($src) Import-SavedList $src.Tag } $false (-not $script:rot.On)
        }
        Add-MenuSeparator $m
        foreach ($n in @($script:lists.Keys)) {
            Add-MenuItem $m "Supprimer « $n »" $n { param($src) $script:lists.Remove($src.Tag); Save-State; Set-Status "Liste supprimée · $($src.Tag)" }
        }
    }
    Add-MenuSeparator $m
    Add-MenuItem $m 'Exporter la file vers un fichier…' $null { Export-Queue } $false ($script:rotItems.Count -gt 0)
    Add-MenuItem $m 'Importer une file depuis un fichier…' $null { Import-QueueFile }
    Open-Menu $m $BtnLists
}

# ============================================================
#  Pages du panneau de droite + statistiques
# ============================================================
function Update-PageTitle {
    $PageTitle.Text = L @{ sessions = 'Sessions'; quest = 'Quête'; stats = 'Statistiques' }[$script:page]
}

function Set-Page([string]$p) {
    $script:page = $p
    $PageSessions.Visibility = if ($p -eq 'sessions') { 'Visible' } else { 'Collapsed' }
    $PageQuest.Visibility    = if ($p -eq 'quest') { 'Visible' } else { 'Collapsed' }
    $PageStats.Visibility    = if ($p -eq 'stats') { 'Visible' } else { 'Collapsed' }
    Update-PageTitle
    Update-PageStyles
    # Transition douce : la page affichee apparait en fondu
    $shown = @{ sessions = $PageSessions; quest = $PageQuest; stats = $PageStats }[$p]
    Start-Fade $shown 180
    if ($p -eq 'stats') { Update-StatsPage }
    if ($p -eq 'quest' -and -not $script:qst.On -and $Games.SelectedItem) { Set-QuestGame $Games.SelectedItem }
    Save-State
}

function Update-PageStyles {
    foreach ($pair in @(@($PageTabSessions, 'sessions'), @($PageTabQuest, 'quest'), @($PageTabStats, 'stats'))) {
        Set-SegStyle $pair[0] ($pair[1] -eq $script:page)
    }
}

function New-Text([string]$text, [double]$size, [string]$color, [switch]$Mono) {
    $t = New-Object Windows.Controls.TextBlock
    $t.Text = $text
    $t.FontSize = $size
    $t.Foreground = Brush $color
    $t.TextTrimming = 'CharacterEllipsis'
    if ($Mono) { $t.FontFamily = $win.Resources['Mono'] }
    $t
}

function Update-StatsPage {
    $total = 0.0; $games = 0; $valid = 0
    foreach ($e in $script:history.Values) {
        $total += $e.sec
        if ($e.sec -ge 60) { $games++ }
        if ($e.sec -ge $PlayedMinutes * 60) { $valid++ }
    }
    $StatsTotal.Text = Format-Duration $total
    $StatsGames.Text = $games
    $StatsValid.Text = $valid

    # Graphique : 14 derniers jours
    $Chart.Children.Clear()
    $Chart.ColumnDefinitions.Clear()
    $days = 13..0 | ForEach-Object { (Get-Date).Date.AddDays(-$_) }
    $max = 60.0
    foreach ($d in $days) { $v = [double]$script:daily[$d.ToString('yyyy-MM-dd')]; if ($v -gt $max) { $max = $v } }
    $ChartMax.Text = 'max ' + (Format-Duration $max)
    $accentBrush = $win.Resources['Accent']
    for ($i = 0; $i -lt $days.Count; $i++) {
        $d = $days[$i]
        $v = [double]$script:daily[$d.ToString('yyyy-MM-dd')]
        $isToday = $i -eq $days.Count - 1
        [void]$Chart.ColumnDefinitions.Add((New-Object Windows.Controls.ColumnDefinition))
        $cell = New-Object Windows.Controls.Grid
        [void]$cell.RowDefinitions.Add((New-Object Windows.Controls.RowDefinition))
        $lr = New-Object Windows.Controls.RowDefinition; $lr.Height = [Windows.GridLength]::Auto
        [void]$cell.RowDefinitions.Add($lr)
        $bar = New-Object Windows.Controls.Border
        $bar.VerticalAlignment = 'Bottom'
        $bar.Margin = New-Object Windows.Thickness 3, 0, 3, 0
        $bar.CornerRadius = New-Object Windows.CornerRadius 4, 4, 1, 1
        $bar.Height = [Math]::Max(3, $v / $max * 100)
        if ($v -gt 0) { $bar.Background = $accentBrush; $bar.Opacity = $(if ($isToday) { 1 } else { 0.6 }) }
        else { $bar.Background = Brush '#3B2237' }
        $bar.ToolTip = '{0:ddd dd/MM} · {1}' -f $d, (Format-Duration $v)
        [void]$cell.Children.Add($bar)
        $lab = New-Text $d.ToString('dd') 10.5 $(if ($isToday) { $script:accentHex } else { '#8A6B76' })
        $lab.HorizontalAlignment = 'Center'
        $lab.Margin = New-Object Windows.Thickness 0, 5, 0, 0
        [Windows.Controls.Grid]::SetRow($lab, 1)
        [void]$cell.Children.Add($lab)
        [Windows.Controls.Grid]::SetColumn($cell, $i)
        [void]$Chart.Children.Add($cell)
    }

    # Top des jeux
    $TopGames.Children.Clear()
    $top = @($script:history.GetEnumerator() | Where-Object { $_.Value.sec -ge 60 } | Sort-Object { $_.Value.sec } -Descending | Select-Object -First 8)
    if (-not $top.Count) {
        [void]$TopGames.Children.Add((New-Text (L "Aucune donnée pour l'instant : lance un jeu avec Discord ouvert.") 12 '#8A6B76'))
        return
    }
    $maxTop = $top[0].Value.sec
    foreach ($kv in $top) {
        $e = $kv.Value
        $row = New-Object Windows.Controls.StackPanel
        $row.Margin = New-Object Windows.Thickness 0, 0, 0, 10
        $head = New-Object Windows.Controls.Grid
        $name = New-Text $e.name 13 '#F7ECF1'
        $name.Margin = New-Object Windows.Thickness 0, 0, 90, 0
        [void]$head.Children.Add($name)
        $ok = $e.sec -ge $PlayedMinutes * 60
        $dur = New-Text $(if ($ok) { '✓ ' + (Format-Duration $e.sec) } else { Format-Duration $e.sec }) 12 $(if ($ok) { '#7FD8C9' } else { '#C7A9B6' })
        $dur.HorizontalAlignment = 'Right'
        [void]$head.Children.Add($dur)
        [void]$row.Children.Add($head)
        $track = New-Object Windows.Controls.Grid
        $track.Height = 4
        $track.Margin = New-Object Windows.Thickness 0, 5, 0, 0
        $c1 = New-Object Windows.Controls.ColumnDefinition; $c1.Width = New-Object Windows.GridLength ([Math]::Max(0.01, $e.sec)), ([Windows.GridUnitType]::Star)
        $c2 = New-Object Windows.Controls.ColumnDefinition; $c2.Width = New-Object Windows.GridLength ([Math]::Max(0.01, $maxTop - $e.sec)), ([Windows.GridUnitType]::Star)
        [void]$track.ColumnDefinitions.Add($c1); [void]$track.ColumnDefinitions.Add($c2)
        $bg = New-Object Windows.Controls.Border; $bg.Background = Brush '#3B2237'; $bg.CornerRadius = New-Object Windows.CornerRadius 2
        [Windows.Controls.Grid]::SetColumnSpan($bg, 2)
        $fg = New-Object Windows.Controls.Border; $fg.Background = $accentBrush; $fg.CornerRadius = New-Object Windows.CornerRadius 2
        [void]$track.Children.Add($bg); [void]$track.Children.Add($fg)
        [void]$row.Children.Add($track)
        [void]$TopGames.Children.Add($row)
    }
}

# ============================================================
#  Mini-widget toujours visible
# ============================================================
$script:widget = $null
$script:widgetOn = $false
$script:wg = @{}
$script:widgetIcon = $null

function Show-Widget {
    if (-not $script:widget) {
            $script:widget = [Windows.Markup.XamlReader]::Parse((Convert-XamlLang ([IO.File]::ReadAllText((Join-Path $appDir 'Widget.xaml')))))
            Set-StrResources $script:widget.Resources
        foreach ($n in 'WRoot', 'WIcon', 'WInitial', 'WName', 'WSub', 'WTime', 'WBtnOpen', 'WBtnClose') { $script:wg[$n] = $script:widget.FindName($n) }
        $script:wg.WInitial.Foreground = $win.Resources['Accent']
        $script:widget.Icon = $win.Icon
        $script:wg.WRoot.Add_MouseLeftButtonDown({ try { $script:widget.DragMove() } catch {} })
        $script:wg.WBtnOpen.Add_Click({ Show-Main })
        $script:wg.WBtnClose.Add_Click({ Hide-Widget })
        $script:widget.Add_LocationChanged({ $script:widgetPos = @($script:widget.Left, $script:widget.Top) })
        $script:widget.Add_MouseLeftButtonUp({ Save-State })
        # Position memorisee si elle est encore sur un ecran, sinon en bas a droite
        $vs = @([Windows.SystemParameters]::VirtualScreenLeft, [Windows.SystemParameters]::VirtualScreenTop,
                [Windows.SystemParameters]::VirtualScreenWidth, [Windows.SystemParameters]::VirtualScreenHeight)
        $p = $script:widgetPos
        if ($p -and $p[0] -ge $vs[0] -and $p[1] -ge $vs[1] -and $p[0] -lt $vs[0] + $vs[2] - 100 -and $p[1] -lt $vs[1] + $vs[3] - 60) {
            $script:widget.Left = $p[0]; $script:widget.Top = $p[1]
        } else {
            $wa = [Windows.SystemParameters]::WorkArea
            $script:widget.Left = $wa.Right - $script:widget.Width - 16
            $script:widget.Top = $wa.Bottom - $script:widget.Height - 16
        }
    }
    $script:widget.Show()
    $script:widgetOn = $true
    $BtnWidget.Foreground = Brush $script:accentHex
    Update-Widget
    Save-State
}

function Hide-Widget {
    if ($script:widget) { $script:widget.Hide() }
    $script:widgetOn = $false
    $BtnWidget.ClearValue([Windows.Controls.Control]::ForegroundProperty)
    Save-State
}

function Update-Widget {
    if (-not $script:widgetOn -or -not $script:widget) { return }
    $icon = $null; $ini = 'Q'
    if ($script:qst.On) {
        $g = $script:qst.Game
        $name = $g.Name; $icon = $g.IconUrl; $ini = $g.Initial
        $sub = if ($script:qst.Paused) { 'Quête · en pause' } else { 'Quête · temps restant' }
        $time = Format-Clock ($script:qst.Next - (Get-QuestNow))
    } elseif ($script:rot.On -and $script:rot.Index -lt $script:rotItems.Count) {
        $g = $script:rotItems[$script:rot.Index]
        $name = $g.Name; $icon = $g.IconUrl; $ini = $g.Initial
        $sub = 'Rotation · {0}/{1}' -f ($script:rot.Index + 1), $script:rotItems.Count
        if ($script:rot.Paused) { $sub += ' · pause' }
        $time = Format-Clock (Get-RotRemaining)
    } elseif ($script:sessions.Count) {
        $s = $script:sessions[0]
        $name = $s.Name; $icon = $s.IconUrl; $ini = $s.Initial
        $sub = if ($script:sessions.Count -gt 1) { "Session · +$($script:sessions.Count - 1) autre(s)" } else { 'Session en cours' }
        $time = $s.Elapsed
    } else {
        $name = 'Aucune session'; $sub = 'Quest Farm'; $time = '--:--'
    }
    $script:wg.WName.Text = L $name
    $script:wg.WSub.Text = L $sub
    $script:wg.WTime.Text = $time
    $script:wg.WInitial.Text = $ini
    if ($icon -ne $script:widgetIcon) {
        $script:widgetIcon = $icon
        $script:wg.WIcon.Source = if ($icon) { New-Object Windows.Media.Imaging.BitmapImage ([Uri]$icon) } else { $null }
    }
}

# ============================================================
#  Reglages
# ============================================================
function Show-Settings {
    Update-SettingsUi
    $SettingsOverlay.Visibility = 'Visible'
    Start-Fade $SettingsOverlay 160
}
function Hide-Settings { $SettingsOverlay.Visibility = 'Collapsed' }

function Test-Autostart { [bool](Get-ItemProperty -Path $RunKey -Name 'QuestSpoofer' -ErrorAction SilentlyContinue) }

function Set-Autostart([bool]$on) {
    try {
        if ($on) {
            Set-ItemProperty -Path $RunKey -Name 'QuestSpoofer' -Value ('"{0}" {1} -StartHidden' -f $Conhost, $LaunchArgs)
            # Au cas ou il aurait ete desactive dans le Gestionnaire des taches
            Remove-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run' -Name 'QuestSpoofer' -ErrorAction SilentlyContinue
            Set-Status "Quest Farm démarrera avec Windows, dans la zone de notification" 'ok'
        } else {
            Remove-ItemProperty -Path $RunKey -Name 'QuestSpoofer' -ErrorAction SilentlyContinue
            Set-Status 'Lancement avec Windows désactivé'
        }
    } catch { Set-Status "Impossible de modifier le démarrage : $($_.Exception.Message)" 'err' }
}

function New-DesktopShortcut {
    try {
        [QsIcon]::SaveIco($IcoPath)
        $sh = New-Object -ComObject WScript.Shell
        $lnk = $sh.CreateShortcut($ShortcutPath)
        $lnk.TargetPath = $Conhost
        $lnk.Arguments = $LaunchArgs
        $lnk.WorkingDirectory = $root
        $lnk.IconLocation = "$IcoPath,0"
        $lnk.Description = 'Quest Farm'
        $lnk.WindowStyle = 7
        $lnk.Save()
        [void][Runtime.InteropServices.Marshal]::ReleaseComObject($sh)
        Set-Status "Raccourci créé sur le bureau : $ShortcutPath" 'ok'
    } catch { Set-Status "Impossible de créer le raccourci : $($_.Exception.Message)" 'err' }
    Update-SettingsUi
}

function Update-WinMode {
    $BtnWinMode.Content = L $(if ($script:winMode -eq 'min') { 'Réduites' } else { 'Visibles' })
    Update-StubUi
}

# --- Apparence des faux jeux : couleur, taille, coin ---
$StubCorners = [ordered]@{ tl = @($StubPosTL, "En haut à gauche de l'écran"); tr = @($StubPosTR, "En haut à droite de l'écran")
                           bl = @($StubPosBL, "En bas à gauche de l'écran");  br = @($StubPosBR, "En bas à droite de l'écran") }
$StubSizes = [ordered]@{ s = $StubSizeS; m = $StubSizeM; l = $StubSizeL }

# Pastilles : "auto" (suit la couleur d'accent) puis les couleurs fixes
foreach ($k in @('accent') + @($Accents.Keys)) {
    $sw = New-Object Windows.Controls.Border
    $sw.Width = 22; $sw.Height = 22
    $sw.CornerRadius = New-Object Windows.CornerRadius 11
    $sw.Margin = New-Object Windows.Thickness 7, 0, 0, 0
    $sw.BorderThickness = New-Object Windows.Thickness 2
    $sw.Cursor = [Windows.Input.Cursors]::Hand
    $sw.Tag = $k
    if ($k -eq 'accent') {
        $sw.ToolTip = L "Comme l'accent"
        $sw.Background = Brush '#3B2237'
        $t = New-Object Windows.Controls.TextBlock
        $t.Text = 'A'; $t.FontSize = 11; $t.FontWeight = 'SemiBold'
        $t.Foreground = Brush '#F7ECF1'
        $t.HorizontalAlignment = 'Center'; $t.VerticalAlignment = 'Center'
        $sw.Child = $t
    } else {
        $sw.ToolTip = L $Accents[$k][1]
        $sw.Background = Brush $Accents[$k][0]
    }
    $sw.Add_MouseLeftButtonUp({ param($src) $script:stubColor = $src.Tag; Update-StubUi; Save-State })
    [void]$StubColorList.Children.Add($sw)
}

function Update-StubUi {
    foreach ($sw in $StubColorList.Children) { $sw.BorderBrush = Brush $(if ($sw.Tag -eq $script:stubColor) { '#F7ECF1' } else { '#00000000' }) }
    $StubColorName.Text = L $(if ($script:stubColor -eq 'accent') { "Comme l'accent ($($Accents[$script:accent][1]))" } else { $Accents[$script:stubColor][1] })
    foreach ($k in $StubSizes.Keys) { Set-SegStyle $StubSizes[$k] ($k -eq $script:stubSize) }
    foreach ($k in $StubCorners.Keys) { Set-SegStyle $StubCorners[$k][0] ($k -eq $script:stubCorner) }
    $StubCornerName.Text = L $StubCorners[$script:stubCorner][1]
    Write-StubConfig
}

foreach ($k in $StubSizes.Keys) {
    $StubSizes[$k].Tag = $k
    $StubSizes[$k].Add_Click({ param($src) $script:stubSize = $src.Tag; Update-StubUi; Save-State })
}
foreach ($k in $StubCorners.Keys) {
    $StubCorners[$k][0].Tag = $k
    $StubCorners[$k][0].Add_Click({ param($src) $script:stubCorner = $src.Tag; Update-StubUi; Save-State })
}

# Apercu : un faux jeu d'exemple pendant 6 s avec les reglages actuels
$script:previewProc = $null
$previewTimer = New-Object Windows.Threading.DispatcherTimer
$previewTimer.Interval = [TimeSpan]::FromSeconds(6)
$previewTimer.Add_Tick({ $previewTimer.Stop(); Stop-StubPreview })

function Stop-StubPreview {
    if ($script:previewProc) { try { if (-not $script:previewProc.HasExited) { $script:previewProc.Kill() } } catch {} }
    $script:previewProc = $null
}

function Show-StubPreview {
    Stop-StubPreview
    try {
        $dir = Join-Path $gamesDir 'qs_preview'
        [void][IO.Directory]::CreateDirectory($dir)
        $exe = Join-Path $dir 'apercu.exe'
        if (-not [IO.File]::Exists($exe)) { [IO.File]::Copy($blank, $exe, $true) }
        $g = $Games.SelectedItem
        $name = if ($g) { $g.Name } else { L 'Aperçu · Quest Farm' }
        $icon = if ($g) { $g.IconUrl } else { $null }
        $psi = New-Object Diagnostics.ProcessStartInfo $exe
        # Toujours visible pour l'apercu, meme si les faux jeux sont regles en "reduites"
        $psi.Arguments = (Get-StubArgs $name.Replace('"', "'") 0 $icon -NoConfig) -replace '--mode min', '--mode show'
        $psi.UseShellExecute = $false
        $script:previewProc = [Diagnostics.Process]::Start($psi)
        [void][QsJob]::Attach($script:previewProc)
        $previewTimer.Stop(); $previewTimer.Start()
        Set-Status 'Aperçu affiché pendant 6 secondes' 'ok'
    } catch { Set-Status "Impossible d'afficher l'aperçu : $($_.Exception.Message)" 'err' }
}

# Pastilles de couleur d'accent
foreach ($k in $Accents.Keys) {
    $a = $Accents[$k]
    $sw = New-Object Windows.Controls.Border
    $sw.Width = 26; $sw.Height = 26
    $sw.CornerRadius = New-Object Windows.CornerRadius 13
    $sw.Margin = New-Object Windows.Thickness 8, 0, 0, 0
    $sw.BorderThickness = New-Object Windows.Thickness 2
    $sw.Cursor = [Windows.Input.Cursors]::Hand
    $sw.Tag = $k
    $sw.ToolTip = L $a[1]
    $sw.Background = Brush $a[0]
    $sw.Add_MouseLeftButtonUp({ param($src) Set-Accent $src.Tag })
    [void]$AccentList.Children.Add($sw)
}

function Set-Accent([string]$key) {
    if (-not $Accents.Contains($key)) { $key = 'blood' }
    $a = $Accents[$key]
    $script:accent = $key
    $script:accentHex = $a[0]
    # Ressources dynamiques : tout ce qui utilise Accent / Cyan / AccentSoft se met a jour
    # (.psobject.BaseObject : sinon PowerShell range l'objet dans un PSObject que WPF refuse)
    $solid = New-Object Windows.Media.SolidColorBrush (ColorOf $a[0])
    $soft = New-Object Windows.Media.SolidColorBrush (ColorOf ('#22' + $a[0].Substring(1)))
    $win.Resources['Accent'] = $solid.psobject.BaseObject
    $win.Resources['Cyan'] = $solid.psobject.BaseObject
    $win.Resources['AccentSoft'] = $soft.psobject.BaseObject
    if ($script:widget) { $script:wg.WInitial.Foreground = $win.Resources['Accent'] }
    $AccentName.Text = L $a[1]
    foreach ($sw in $AccentList.Children) { $sw.BorderBrush = Brush $(if ($sw.Tag -eq $key) { '#F7ECF1' } else { '#00000000' }) }
    Update-Pill
    Update-TabStyles
    Update-PageStyles
    Update-StubUi
    Update-TimerUi
    if ($script:widgetOn) { $BtnWidget.Foreground = Brush $script:accentHex }
    if ($script:page -eq 'stats') { Update-StatsPage }
    Save-State
}

function Update-SettingsUi {
    $script:updatingSettings = $true
    $ChkAutostart.IsChecked = Test-Autostart
    $script:updatingSettings = $false
    if (Test-Path -LiteralPath $ShortcutPath) {
        $ShortcutDesc.Text = L 'Raccourci présent sur le bureau.'
        $BtnShortcut.Content = L 'Recréer'
    } else {
        $ShortcutDesc.Text = L "Ouvre l'outil avec sa vraie icône, sans console."
        $BtnShortcut.Content = L 'Créer'
    }
    Update-WinMode
    Update-RemoteUi
    Set-SegStyle $LangFr ($script:lang -eq 'fr')
    Set-SegStyle $LangEn ($script:lang -eq 'en')
    $when = if (Test-Path -LiteralPath $paths.Catalog) { '{0:dd/MM HH:mm}' -f (Get-Item -LiteralPath $paths.Catalog).LastWriteTime } else { 'jamais' }
    $count = if ($script:allGames) { '{0:N0} jeux' -f $script:allGames.Count } else { 'non chargé' }
    $CatalogDesc.Text = L "$count · mis à jour le $when · auto toutes les 24 h"
}

# Verifie tout ce qui peut empecher un spoof de fonctionner
function Invoke-Diagnostic {
    $DiagList.Children.Clear()
    Set-Status 'Diagnostic en cours…'
    $res = New-Object System.Collections.ArrayList
    $add = { param($kind, $text) [void]$res.Add(@($kind, $text)) }

    if ([QsDiscord]::IsRunning()) { & $add 'ok' 'Discord est ouvert.' }
    else { & $add 'err' "Discord est fermé : aucun spoof n'est pris en compte tant qu'il n'est pas lancé." }

    if ($script:allGames) {
        if ($script:catalogOk) { & $add 'ok' ('Catalogue à jour : {0:N0} jeux Windows.' -f $script:allGames.Count) }
        else { & $add 'warn' 'Catalogue chargé depuis le cache : la mise à jour en ligne a échoué ou est en cours.' }
    } else { & $add 'err' "Catalogue non chargé : vérifie ta connexion puis clique sur Actualiser." }

    if (Test-Path -LiteralPath $blank) { & $add 'ok' 'Faux exe de base présent.' } else { & $add 'err' 'Faux exe de base introuvable : relance l''outil pour le recompiler.' }

    # Lancement reel d'un faux exe de test (fenetre reduite), puis arret
    $diagDir = Join-Path $gamesDir 'qs_diag'
    try {
        [void][IO.Directory]::CreateDirectory($diagDir)
        $exe = Join-Path $diagDir 'diag_test.exe'
        [IO.File]::Copy($blank, $exe, $true)
        $psi = New-Object Diagnostics.ProcessStartInfo $exe
        $psi.Arguments = '"Diagnostic Quest Farm" 0 min'
        $psi.UseShellExecute = $false
        $sw = [Diagnostics.Stopwatch]::StartNew()
        $p = [Diagnostics.Process]::Start($psi)
        $attached = [QsJob]::Attach($p)
        do { Start-Sleep -Milliseconds 100; $p.Refresh() } while ($p.MainWindowHandle -eq [IntPtr]::Zero -and $sw.ElapsedMilliseconds -lt 4000)
        $hasWin = $p.MainWindowHandle -ne [IntPtr]::Zero
        try { $p.Kill(); [void]$p.WaitForExit(2000) } catch {}
        if ($hasWin) { & $add 'ok' ("Un faux jeu se lance et ouvre sa fenêtre ({0} ms)." -f $sw.ElapsedMilliseconds) }
        else { & $add 'err' "Le faux exe se lance mais n'ouvre pas de fenêtre : un antivirus le bloque peut-être." }
        if ($attached) { & $add 'ok' "Les faux jeux s'arrêtent bien avec l'outil, même en cas de plantage." }
        else { & $add 'warn' "Impossible de lier les faux jeux à l'outil : ils pourraient survivre à un plantage." }
    } catch {
        & $add 'err' "Impossible de lancer un faux exe : $($_.Exception.Message)"
    } finally {
        try { [IO.Directory]::Delete($diagDir, $true) } catch {}
    }

    if ($script:hotkeyOk) { & $add 'ok' 'Raccourci global Ctrl+Alt+S actif.' }
    else { & $add 'warn' 'Ctrl+Alt+S est déjà utilisé par un autre programme : utilise le bouton pause.' }

    $rot = if ($script:rot.On) { 'rotation active' } else { 'pas de rotation' }
    $qs = if ($script:qst.On) { 'quête active' } else { 'pas de quête' }
    & $add 'ok' ("{0} session(s) en cours · {1} · {2} · anti-veille {3}." -f $script:sessions.Count, $rot, $qs, $(if ($script:awake) { 'actif' } else { 'inactif (aucune session)' }))

    $mem = [Math]::Round((Get-Process -Id $PID).WorkingSet64 / 1MB)
    & $add 'ok' "Mémoire utilisée par l'outil : $mem Mo."

    $glyph = @{ ok = [char]0xE73E; warn = [char]0xE7BA; err = [char]0xE711 }
    $color = @{ ok = '#7FD8C9'; warn = '#F5B971'; err = '#FF4D6D' }
    foreach ($r in $res) {
        $g = New-Object Windows.Controls.Grid
        $g.Margin = New-Object Windows.Thickness 0, 3, 0, 3
        $c0 = New-Object Windows.Controls.ColumnDefinition; $c0.Width = New-Object Windows.GridLength 24
        [void]$g.ColumnDefinitions.Add($c0); [void]$g.ColumnDefinitions.Add((New-Object Windows.Controls.ColumnDefinition))
        $i = New-Text ([string]$glyph[$r[0]]) 11 $color[$r[0]]
        $i.FontFamily = $win.Resources['Icons']
        $i.Margin = New-Object Windows.Thickness 0, 2, 0, 0
        $t = New-Text (L $r[1]) 12 '#E3CBD6'
        $t.TextWrapping = 'Wrap'
        [Windows.Controls.Grid]::SetColumn($t, 1)
        [void]$g.Children.Add($i); [void]$g.Children.Add($t)
        [void]$DiagList.Children.Add($g)
    }
    $nOk = @($res | Where-Object { $_[0] -eq 'ok' }).Count
    $nWarn = @($res | Where-Object { $_[0] -eq 'warn' }).Count
    $nErr = @($res | Where-Object { $_[0] -eq 'err' }).Count
    Set-Status "Diagnostic terminé : $nOk OK, $nWarn avertissement(s), $nErr problème(s)" $(if ($nErr) { 'err' } elseif ($nWarn) { 'warn' } else { 'ok' })
}

# ============================================================
#  Nettoyage du dossier games\
# ============================================================
function Clear-GamesDir {
    $keep = @{}
    $keep[[IO.Path]::GetFullPath($blank).ToLowerInvariant()] = $true
    foreach ($s in $script:sessions) {
        $keep[[IO.Path]::GetFullPath((Join-Path $gamesDir $s.ExePath)).ToLowerInvariant()] = $true
    }
    $removed = 0; $failed = 0
    foreach ($f in [IO.Directory]::GetFiles($gamesDir, '*', 'AllDirectories')) {
        if ($keep.ContainsKey($f.ToLowerInvariant())) { continue }
        try { [IO.File]::Delete($f); $removed++ } catch { $failed++ }
    }
    # Dossiers vides, du plus profond au moins profond
    $dirs = [IO.Directory]::GetDirectories($gamesDir, '*', 'AllDirectories') | Sort-Object Length -Descending
    foreach ($d in $dirs) {
        try { if (-not [IO.Directory]::EnumerateFileSystemEntries($d).GetEnumerator().MoveNext()) { [IO.Directory]::Delete($d) } } catch {}
    }
    $msg = "Nettoyage : $removed fichier(s) supprimé(s)"
    if ($failed) { $msg += ", $failed verrouillé(s)" }
    if ($script:sessions.Count) { $msg += " · sessions actives conservées" }
    Set-Status $msg $(if ($failed) { 'warn' } else { 'ok' })
}

# ============================================================
#  Evenements
# ============================================================
function Find-Parent($el, [type]$t) {
    while ($el) {
        if ($el -is $t) { return $el }
        if ($el -is [Windows.Media.Visual]) { $el = [Windows.Media.VisualTreeHelper]::GetParent($el) } else { $el = $el.Parent }
    }
    $null
}

function Focus-GameItem([int]$i) {
    $Games.SelectedIndex = $i
    $Games.ScrollIntoView($Games.SelectedItem)
    $Games.UpdateLayout()
    $c = $Games.ItemContainerGenerator.ContainerFromIndex($i)
    if ($c) { [void]$c.Focus() }
}

$debounce = New-Object Windows.Threading.DispatcherTimer
$debounce.Interval = [TimeSpan]::FromMilliseconds(150)
$debounce.Add_Tick({ $debounce.Stop(); Apply-Filter })

$Search.Add_TextChanged({
    $SearchHint.Visibility = if ($Search.Text) { 'Collapsed' } else { 'Visible' }
    $debounce.Stop(); $debounce.Start()
})

$TabAll.Add_Click({ Set-Tab 'all' })
$TabFav.Add_Click({ Set-Tab 'fav' })
$TabRecent.Add_Click({ Set-Tab 'recent' })
$TabPlayed.Add_Click({ Set-Tab 'played' })
$PageTabSessions.Add_Click({ Set-Page 'sessions' })
$PageTabQuest.Add_Click({ Set-Page 'quest' })
$PageTabStats.Add_Click({ Set-Page 'stats' })

$Games.Add_SelectionChanged({
    $BtnLaunch.IsEnabled = $null -ne $Games.SelectedItem
    $BtnQueue.IsEnabled = $null -ne $Games.SelectedItem
    if ($Games.SelectedItem -and -not $script:qst.On) { Set-QuestGame $Games.SelectedItem }
})
$BtnLaunch.Add_Click({ if ($Games.SelectedItem) { [void](Start-Spoof $Games.SelectedItem) } })
$BtnQueue.Add_Click({ if ($Games.SelectedItem) { Add-ToQueue $Games.SelectedItem } })
$Games.Add_MouseDoubleClick({
    param($src, $e)
    # Double-clic sur une ligne (pas sur l'etoile ni la barre de defilement)
    if ((Find-Parent $e.OriginalSource ([Windows.Controls.ListBoxItem])) -and
        -not (Find-Parent $e.OriginalSource ([Windows.Controls.Button])) -and $Games.SelectedItem) {
        [void](Start-Spoof $Games.SelectedItem)
    }
})
$Games.AddHandler([Windows.Controls.Primitives.ButtonBase]::ClickEvent, [Windows.RoutedEventHandler]{
    param($src, $e)
    $g = $e.OriginalSource.Tag
    if ($g -is [QsGame]) { Toggle-Fav $g; $e.Handled = $true }
})

$Active.AddHandler([Windows.Controls.Primitives.ButtonBase]::ClickEvent, [Windows.RoutedEventHandler]{
    param($src, $e)
    $s = $e.OriginalSource.Tag
    if ($s -is [QsSession]) { Stop-Session $s; Update-Ui; Set-Status "Arrêté · $($s.Name)" }
})

# Actions partagees entre les boutons du PC et l'appli mobile
function Stop-All {
    $n = $script:sessions.Count
    if ($script:rot.On) { Stop-Rotation }
    if ($script:qst.On) { Stop-Quest }
    foreach ($s in @($script:sessions)) { Stop-Session $s }
    Update-Ui
    Set-Status "$n session(s) arrêtée(s)"
}

function Start-Rotation {
    if ($script:rot.On) { return }
    if ($script:rotItems.Count -eq 0) { Set-Status 'La file de rotation est vide' 'warn'; return }
    $script:rot.On = $true
    $script:rot.Index = 0
    Step-Rotation
}

function Skip-RotationGame {
    if (-not $script:rot.On) { return }
    $script:rot.Index++
    Step-Rotation
}

# 10 jeux "connus" (avec image de couverture), jamais joues, pas deja dans la file
function Add-RandomGames {
    if (-not $script:allGames) { return }
    $pool = @($script:allGames.Where({ $_.HasCover -and -not $script:rotItems.Contains($_) -and -not (Test-Played $_.Id) }))
    if ($pool.Count -lt 10) { $pool = @($script:allGames.Where({ -not $script:rotItems.Contains($_) })) }
    $picked = @($pool | Get-Random -Count ([Math]::Min(10, $pool.Count)))
    foreach ($g in $picked) { $script:rotItems.Add($g) }
    Update-Rot
    Save-State
    Set-Status "$($picked.Count) jeux ajoutés à la rotation" 'ok'
}

function Clear-Queue {
    if ($script:rot.On) { Stop-Rotation }
    $script:rotItems.Clear()
    Update-Rot
    Save-State
    Set-Status 'File de rotation vidée'
}

# ============================================================
#  Telephone : appli mobile sur le reseau local (app\mobile, servie par app\Remote.cs)
#  Le serveur tourne sur son propre thread ; l'etat de l'outil n'est lu et modifie
#  qu'ici, sur le thread de l'interface (etat publie + commandes en file).
# ============================================================
$RemotePort = 47820
$script:remote = New-Object QsRemote
$script:remote.WebRoot = Join-Path $appDir 'mobile'
if (-not $script:remotePin) { $script:remotePin = [QsRemote]::NewPin() }
if (-not $script:remoteTokens) { $script:remoteTokens = @() }

function ConvertTo-RemoteGame($g) { [ordered]@{ id = $g.Id; name = $g.Name; icon = $g.IconUrl; ini = $g.Initial } }

# Etat lu par le telephone (GET /api/state)
function Publish-RemoteState {
    if (-not $script:remote.IsRunning) { return }
    $n = Get-PlayedCount
    $next = $Tiers | Where-Object { $_[0] -gt $n } | Select-Object -First 1
    $cur  = $Tiers | Where-Object { $_[0] -le $n } | Select-Object -Last 1
    $rotOn = [bool]$script:rot.On
    $q = $script:qst
    $st = [ordered]@{
        v        = 1
        lang     = $script:lang
        accent   = $script:accentHex
        discord  = [bool]$script:discordUp
        catalog  = $(if ($script:allGames) { $script:allGames.Count } else { 0 })
        sessions = @(foreach ($s in $script:sessions) { [ordered]@{ pid = $s.Proc.Id; name = $s.Name; icon = $s.IconUrl; ini = $s.Initial; elapsed = $s.Elapsed; kind = [string]$s.Kind } })
        rotation = [ordered]@{
            on = $rotOn; paused = [bool]$script:rot.Paused; userPaused = [bool]$script:rot.UserPaused
            index = [int]$script:rot.Index; count = $script:rotItems.Count; minutes = Get-RotMinutes
            remaining = $(if ($rotOn) { [int](Get-RotRemaining).TotalSeconds } else { 0 })
            total = $(if ($rotOn) { [int]($script:rot.Next - $script:rot.Started).TotalSeconds } else { 0 })
            queue = @(foreach ($g in $script:rotItems) { ConvertTo-RemoteGame $g })
        }
        quest    = [ordered]@{
            on = [bool]$q.On; paused = [bool]$q.Paused
            name = $(if ($q.On) { $q.Game.Name } else { '' }); icon = $(if ($q.On) { $q.Game.IconUrl } else { $null }); ini = $(if ($q.On) { $q.Game.Initial } else { '' })
            remaining = $(if ($q.On) { [int][Math]::Max(0, ($q.Next - (Get-QuestNow)).TotalSeconds) } else { 0 })
            total = $(if ($q.On) { [int]($q.Next - $q.Started).TotalSeconds } else { 0 })
        }
        timer    = [ordered]@{
            left = $(if ($script:endT.At) { [int][Math]::Max(0, ($script:endT.At - (Get-Date)).TotalSeconds) } else { $null })
            onRotationEnd = [bool]$script:endT.OnRotationEnd; action = $script:endT.Action
        }
        stats    = [ordered]@{
            unique = $n; goal = $(if ($next) { $next[0] } else { 0 })
            tier = $(if ($cur) { $cur[1] } else { '' }); nextTier = $(if ($next) { $next[1] } else { '' })
            today = [int]$script:daily[(Get-Date).ToString('yyyy-MM-dd')]
        }
    }
    $script:remote.StateJson = $st | ConvertTo-Json -Depth 6 -Compress
}

# Commandes envoyees par le telephone (POST /api/cmd) : memes actions que les boutons du PC
function Invoke-RemoteCommand([string]$json) {
    try { $c = $json | ConvertFrom-Json } catch { return }
    $g = $null
    if ($c.id) { $g = $script:byId[[string]$c.id] }
    switch ([string]$c.action) {
        'launch'      { if ($g) { [void](Start-Spoof $g) } }
        'stop'        { $s = @($script:sessions | Where-Object { $_.Proc.Id -eq [int]$c.pid })[0]; if ($s) { Stop-Session $s; Update-Ui; Set-Status "Arrêté · $($s.Name)" } }
        'stopAll'     { Stop-All }
        'rotStart'    { Start-Rotation }
        'rotStop'     { if ($script:rot.On) { Stop-Rotation } }
        'rotPause'    { Switch-RotationPause }
        'rotNext'     { Skip-RotationGame }
        'queueAdd'    { if ($g) { Add-ToQueue $g } }
        'queueRemove' { $item = @($script:rotItems | Where-Object { $_.Id -eq [string]$c.id })[0]; if ($item) { Remove-FromQueue $item } }
        'queueClear'  { Clear-Queue }
        'random'      { Add-RandomGames }
        'minutes'     { $m = [int]$c.value; if ($m -ge 1 -and $m -le 600) { $RotMinutes.Text = [string]$m } }
        'questStart'  {
            if ($g -and -not $script:qst.On) {
                $m = [int]$c.minutes
                if ($m -ge 1 -and $m -le 600) { $QuestMinutes.Text = [string]$m }
                $ChkQuestMargin.IsChecked = [bool]$c.margin
                Set-QuestGame $g
                Start-Quest
            }
        }
        'questStop'   { Stop-Quest }
        'timer'       { $m = [int]$c.minutes; if ($m -ge 1 -and $m -le 1440) { Set-EndTimer $m } }
        'timerClear'  { Clear-EndTimer }
    }
}

# Commandes et nouveaux appairages, traites 4 fois par seconde quand le serveur tourne
$remoteTimer = New-Object Windows.Threading.DispatcherTimer
$remoteTimer.Interval = [TimeSpan]::FromMilliseconds(250)
$remoteTimer.Add_Tick({
    $changed = $false
    $text = $null
    while ($script:remote.Commands.TryDequeue([ref]$text)) { Invoke-RemoteCommand $text; $changed = $true }
    $tok = $null
    while ($script:remote.NewTokens.TryDequeue([ref]$tok)) {
        $script:remoteTokens = @(@($script:remoteTokens) + $tok | Select-Object -Last 10)
        Save-State
        Set-Status 'Téléphone connecté' 'ok'
        $changed = $true
    }
    if ($changed) { Publish-RemoteState; Update-RemoteUi }
})

function Start-Remote {
    $script:remote.Pin = $script:remotePin
    $script:remote.SetTokens([string[]]@($script:remoteTokens))
    if ($script:allGames) { $script:remote.Catalog = $script:allGames }
    if (-not $script:remote.Start($RemotePort)) {
        Set-Status "Impossible d'ouvrir le port $RemotePort : il est peut-être déjà utilisé" 'err'
        return $false
    }
    Publish-RemoteState
    $remoteTimer.Start()
    $true
}

function Stop-Remote {
    $remoteTimer.Stop()
    $script:remote.Stop()
}

function Set-RemoteEnabled([bool]$on) {
    if ($on) {
        $script:remoteOn = [bool](Start-Remote)
        if ($script:remoteOn) { Set-Status 'Contrôle depuis le téléphone activé' 'ok' }
    } else {
        Stop-Remote
        $script:remoteOn = $false
        Set-Status 'Contrôle depuis le téléphone désactivé'
    }
    Update-RemoteUi
    Save-State
}

# Nouveau code : les telephones deja appaires sont deconnectes
function Reset-RemotePin {
    $script:remotePin = [QsRemote]::NewPin()
    $script:remoteTokens = @()
    $script:remote.Pin = $script:remotePin
    $script:remote.ClearTokens()
    Update-RemoteUi
    Save-State
    Set-Status 'Nouveau code : les téléphones connectés doivent se reconnecter' 'ok'
}

function Format-Ago([TimeSpan]$t) {
    if ($t.TotalSeconds -lt 60) { "$([int]$t.TotalSeconds) s" }
    elseif ($t.TotalMinutes -lt 60) { "$([int]$t.TotalMinutes) min" }
    elseif ($t.TotalHours -lt 48) { "$([int]$t.TotalHours) h" }
    else { "$([int]$t.TotalDays) j" }
}

function Update-RemoteUi {
    $script:updatingSettings = $true
    $ChkRemote.IsChecked = [bool]$script:remoteOn
    $script:updatingSettings = $false
    $running = $script:remoteOn -and $script:remote.IsRunning
    $RemotePanel.Visibility = if ($running) { 'Visible' } else { 'Collapsed' }
    if (-not $running) { return }
    $ips = @([QsRemote]::LocalAddresses())
    $RemoteUrl.Text = if ($ips.Count) { "http://$($ips[0]):$RemotePort" } else { "http://<IP>:$RemotePort" }
    $RemoteAlt.Text = if ($ips.Count -gt 1) { L ("Autres adresses : " + (($ips | Select-Object -Skip 1 | ForEach-Object { "http://$($_):$RemotePort" }) -join '  ·  ')) } else { '' }
    $RemoteAlt.Visibility = if ($ips.Count -gt 1) { 'Visible' } else { 'Collapsed' }
    $RemotePin.Text = $script:remotePin.Insert(3, ' ')
    $count = $script:remote.TokenCount
    $last = $script:remote.LastSeen
    if ($last -gt (Get-Date).AddSeconds(-10)) {
        $RemoteStatus.Text = L 'Téléphone connecté · en direct'
        $RemoteStatus.Foreground = Brush '#7FD8C9'
    } elseif ($count -gt 0) {
        $ago = if ($last -gt [DateTime]::MinValue) { Format-Ago ((Get-Date) - $last) } else { '—' }
        $RemoteStatus.Text = L "$count téléphone(s) appairé(s) · dernière visite il y a $ago"
        $RemoteStatus.Foreground = Brush '#C7A9B6'
    } else {
        $RemoteStatus.Text = L "Aucun téléphone appairé pour l'instant"
        $RemoteStatus.Foreground = Brush '#C7A9B6'
    }
}

$ChkRemote.Add_Click({ if (-not $script:updatingSettings) { Set-RemoteEnabled ([bool]$ChkRemote.IsChecked) } })
$BtnRemoteReset.Add_Click({ Reset-RemotePin })

$BtnStopAll.Add_Click({ Stop-All })

$QueueList.AddHandler([Windows.Controls.Primitives.ButtonBase]::ClickEvent, [Windows.RoutedEventHandler]{
    param($src, $e)
    $g = $e.OriginalSource.Tag
    if ($g -is [QsGame]) { Remove-FromQueue $g }
})

$BtnRotate.Add_Click({ if ($script:rot.On) { Stop-Rotation } else { Start-Rotation } })
$BtnPause.Add_Click({ Switch-RotationPause })
$BtnNext.Add_Click({ Skip-RotationGame })
$BtnLists.Add_Click({ Show-ListsMenu })
$BtnRandom.Add_Click({ Add-RandomGames })
$BtnClearQueue.Add_Click({ Clear-Queue })

$RotMinutes.Add_PreviewTextInput({ param($src, $e) $e.Handled = $e.Text -notmatch '^\d+$' })
$RotMinutes.Add_TextChanged({ if (-not $script:rot.On) { Update-Rot }; Save-State })
$QuestMinutes.Add_PreviewTextInput({ param($src, $e) $e.Handled = $e.Text -notmatch '^\d+$' })
$QuestMinutes.Add_TextChanged({ Save-State })
$ChkQuestMargin.Add_Click({ Save-State })
$BtnQuest.Add_Click({ Start-Quest })
$BtnQuestStop.Add_Click({ Stop-Quest })

$BtnTimer.Add_Click({ Show-TimerMenu })
$BtnWidget.Add_Click({ if ($script:widgetOn) { Hide-Widget } else { Show-Widget } })
$BtnSettings.Add_Click({ Show-Settings })
$BtnSettingsClose.Add_Click({ Hide-Settings })
$SettingsBackdrop.Add_MouseLeftButtonDown({ Hide-Settings })
$ChkAutostart.Add_Click({ if (-not $script:updatingSettings) { Set-Autostart ([bool]$ChkAutostart.IsChecked); Update-SettingsUi } })
$BtnShortcut.Add_Click({ New-DesktopShortcut })
$BtnWinMode.Add_Click({
    $script:winMode = if ($script:winMode -eq 'show') { 'min' } else { 'show' }
    Update-WinMode
    Save-State
})
$BtnRefresh.Add_Click({
    if ($script:loadTask) { Set-Status 'Mise à jour du catalogue déjà en cours…'; return }
    Start-CatalogFetch
    Set-Status 'Mise à jour du catalogue…'
})
$BtnClean.Add_Click({ Clear-GamesDir })
$BtnDiag.Add_Click({ Invoke-Diagnostic })
$BtnStubPreview.Add_Click({ Show-StubPreview })

# Changer de langue a chaud : textes fixes (ressources dynamiques) + textes calcules par le code
function Set-Lang([string]$l) {
    if ($l -eq $script:lang) { return }
    $script:lang = $l
    Set-StrResources $win.Resources
    if ($script:widget) { Set-StrResources $script:widget.Resources }
    Update-AllTexts
    Save-State
    Set-Status $(if ($l -eq 'en') { 'Langue : anglais' } else { 'Langue : français' }) 'ok'
}

# Reaffiche tous les textes calcules par le code dans la langue courante
function Update-AllTexts {
    Update-Ui
    $LogLine.Text = L $LogLines[$script:logIdx]
    Update-Rot
    Update-RotClock
    Update-Stats
    Set-QuestGame $script:questGame
    Update-Quest
    Update-TimerUi
    Update-Pill
    Update-TabLabels
    Apply-Filter
    Update-PageTitle
    Update-SettingsUi
    if ($script:catalogSub) { $StatGamesSub.Text = L $script:catalogSub }
    $AccentName.Text = L $Accents[$script:accent][1]
    foreach ($sw in $AccentList.Children) { $sw.ToolTip = L $Accents[$sw.Tag][1] }
    foreach ($sw in $StubColorList.Children) { $sw.ToolTip = if ($sw.Tag -eq 'accent') { L "Comme l'accent" } else { L $Accents[$sw.Tag][1] } }
    foreach ($s in $script:sessions) { $s.KindLabel = L $s.Kind }
    $Active.Items.Refresh()
    $trayLabels = @('Ouvrir Quest Farm', 'Mini-widget', 'Pause / reprise de la rotation', '-', 'Quitter (arrête tout)')
    for ($i = 0; $i -lt $trayLabels.Count; $i++) { if ($trayLabels[$i] -ne '-') { $trayMenu.Items[$i].Text = L $trayLabels[$i] } }
    $DiagList.Children.Clear()
    if ($script:page -eq 'stats') { Update-StatsPage }
    Update-Widget
    if ($script:lastStatus) { Write-StatusLine }
}
$LangFr.Add_Click({ Set-Lang 'fr' })
$LangEn.Add_Click({ Set-Lang 'en' })

$BtnTray.Add_Click({ Hide-ToTray })
$BtnMin.Add_Click({ $win.WindowState = 'Minimized' })
$BtnClose.Add_Click({ $win.Close() })

# Raccourcis clavier
$win.Add_PreviewKeyDown({
    param($src, $e)
    $ctrl = ([Windows.Input.Keyboard]::Modifiers -band [Windows.Input.ModifierKeys]::Control) -ne 0
    $inSearch = $e.OriginalSource -eq $Search
    $inText = $e.OriginalSource -is [Windows.Controls.TextBox]
    switch ($e.Key) {
        'F' { if ($ctrl) { Hide-Settings; [void]$Search.Focus(); $Search.SelectAll(); $e.Handled = $true } }
        'D' { if ($ctrl -and $Games.SelectedItem) { Toggle-Fav $Games.SelectedItem; $e.Handled = $true } }
        'Escape' {
            if ($SettingsOverlay.Visibility -eq 'Visible') { Hide-Settings; $e.Handled = $true }
            elseif ($Search.Text) { $Search.Text = ''; $e.Handled = $true }
        }
        'Down' { if ($inSearch -and $Games.Items.Count) { Focus-GameItem ([Math]::Max(0, $Games.SelectedIndex)); $e.Handled = $true } }
        'Return' {
            if ($inSearch -or (Find-Parent $e.OriginalSource ([Windows.Controls.ListBox]))) {
                if (-not $Games.SelectedItem -and $Games.Items.Count) { $Games.SelectedIndex = 0 }
                if ($Games.SelectedItem) {
                    if ($ctrl) { Add-ToQueue $Games.SelectedItem } else { [void](Start-Spoof $Games.SelectedItem) }
                }
                $e.Handled = $true
            }
        }
        'Delete' {
            if (-not $inText -and $script:sessions.Count) {
                $s = $script:sessions[0]
                Stop-Session $s; Update-Ui; Set-Status "Arrêté · $($s.Name)"
                $e.Handled = $true
            }
        }
    }
})

# ============================================================
#  Faux terminal de la barre d'etat (ambiance yandere, comme yandere.eu)
# ============================================================
$LogLines = @(
    'surveillance de Discord : active ♡'
    'ping Discord… latence : ∞'
    'localisation de tes jeux : trouvés (comme toujours)'
    'tentative de fuite détectée… verrouillage du cœur'
    'rival.exe a cessé de fonctionner'
    'oubli_de_toi.exe : introuvable'
    'sauvegarde de tes quêtes… (x47)'
    'compte à rebours : chaque seconde t''appartient'
    'firewall : quiconque s''approche est bloqué 🔪'
    'badge Game Variety : je le veux pour toi'
    'batterie de patience : 0 % (comme d''habitude)'
)
$script:logIdx = Get-Random -Maximum $LogLines.Count
function Step-LogLine {
    $script:logIdx = ($script:logIdx + 1) % $LogLines.Count
    $LogLine.Text = L $LogLines[$script:logIdx]
}
$logTimer = New-Object Windows.Threading.DispatcherTimer
$logTimer.Interval = [TimeSpan]::FromSeconds(4.5)
$logTimer.Add_Tick({ Step-LogLine })

# ============================================================
#  Minuteur principal (1 fois par seconde)
# ============================================================
$script:lastDiscordCheck = Get-Date
$script:lastSave = Get-Date
$script:lastStats = Get-Date
$script:awake = $false

$timer = New-Object Windows.Threading.DispatcherTimer
$timer.Interval = [TimeSpan]::FromSeconds(1)
$timer.Add_Tick({
    $now = Get-Date
    if ($script:showEvt.WaitOne(0)) { Show-Main }
    if ($script:loadTask -and $script:loadTask.IsCompleted) { Complete-Load }
    if (-not $script:loadTask -and ($now - $script:lastFetch).TotalHours -ge 24) { Start-CatalogFetch }

    if (($now - $script:lastDiscordCheck).TotalSeconds -ge 2) {
        $script:lastDiscordCheck = $now
        $up = [QsDiscord]::IsRunning()
        if ($up -ne $script:discordUp) {
            $script:discordUp = $up
            Update-Pill
            if (-not $up -and $script:sessions.Count) { Notify 'Discord fermé' 'Les spoofs ne comptent plus tant que Discord est fermé.' }
        }
    }

    # Sessions : temps, historique, processus morts
    $total = [TimeSpan]::Zero
    foreach ($s in @($script:sessions)) {
        if ($s.Proc.HasExited) {
            [void]$script:sessions.Remove($s)
            Update-Ui
            Set-Status "$($s.Name) s'est arrêté" 'warn'
            continue
        }
        $d = ($now - $s.LastCount).TotalSeconds
        if ($script:discordUp -and $d -gt 0 -and $d -lt 5) { Add-Playtime $s $d }
        $s.LastCount = $now
        $s.Tick()
        $total += $s.Age
    }
    $StatTime.Text = [QsSession]::Format($total)

    # Rotation : pause si Discord est ferme, jeu suivant quand le temps est ecoule
    if ($script:rot.On) {
        if (-not $script:discordUp) {
            if (-not $script:rot.Paused) {
                $script:rot.Paused = $true
                $script:rot.PausedAt = $now
                Update-Rot
                Set-Status 'Rotation en pause : Discord est fermé' 'warn'
                Notify 'Rotation en pause' 'Discord est fermé, le temps ne compte plus.'
            }
        } elseif ($script:rot.Paused -and -not $script:rot.UserPaused) {
            $shift = $now - $script:rot.PausedAt
            $script:rot.Started += $shift
            $script:rot.Next += $shift
            $script:rot.Paused = $false
            Update-Rot
            Set-Status 'Discord est revenu : rotation reprise' 'ok'
        }
        if (-not $script:rot.Paused) {
            $rs = $script:rot.Session
            if (-not $rs -or $rs.Proc.HasExited -or $now -ge $script:rot.Next) {
                $script:rot.Index++
                Step-Rotation
            }
        }
        Update-RotClock
    }

    # Quete : meme logique de pause, arret automatique a la fin
    if ($script:qst.On) {
        $qs = $script:qst.Session
        if (-not $qs -or $qs.Proc.HasExited) {
            Stop-Quest 'Quête interrompue : le faux jeu a été fermé'
        } else {
            if (-not $script:discordUp) {
                if (-not $script:qst.Paused) { $script:qst.Paused = $true; $script:qst.PausedAt = $now }
            } elseif ($script:qst.Paused) {
                $shift = $now - $script:qst.PausedAt
                $script:qst.Started += $shift
                $script:qst.Next += $shift
                $script:qst.Paused = $false
            }
            if (-not $script:qst.Paused -and $now -ge $script:qst.Next) { Stop-Quest -Done }
            else { Update-QuestClock }
        }
    }

    # Minuterie de fin
    if ($script:endT.At) {
        if ($now -ge $script:endT.At) { Invoke-EndAction 'Minuterie écoulée' } else { Update-TimerUi }
    }

    Update-Widget

    # Anti-veille tant qu'un spoof tourne
    $want = ($script:sessions.Count -gt 0) -or $script:rot.On -or $script:qst.On
    if ($want -ne $script:awake) { [QsPower]::KeepAwake($want); $script:awake = $want }

    # Telephone : etat a jour chaque seconde, statut de connexion dans les reglages
    if ($script:remote.IsRunning) {
        Publish-RemoteState
        if ($SettingsOverlay.Visibility -eq 'Visible') { Update-RemoteUi }
    }

    if (($now - $script:lastSave).TotalSeconds -ge 30) {
        $script:lastSave = $now
        Save-History
        if ($script:rot.On) { Save-State }
        if ($script:page -eq 'stats' -and $win.IsVisible) { Update-StatsPage }
    }
})

# A la fermeture : sauvegarder puis tout arreter, widget et icone compris
$win.Add_Closing({
    $timer.Stop(); $logTimer.Stop()
    Save-State
    Save-History
    foreach ($s in @($script:sessions)) { Stop-Session $s }
    [QsPower]::KeepAwake($false)
    Stop-Remote
    $script:hotkey.Dispose()
    if ($script:widget) { $script:widget.Close() }
    $script:tray.Visible = $false
    $script:tray.Dispose()
    $script:mutex.ReleaseMutex()
})
$win.Add_Closed({
    [Windows.Threading.Dispatcher]::CurrentDispatcher.InvokeShutdown()
})

# ============================================================
#  Demarrage
# ============================================================
Update-Ui
Update-Rot
Update-Stats
Update-Quest
Update-WinMode
Set-Accent $script:accent
Update-TabStyles
Update-TabLabels
Set-Page $script:page
Update-Pill
Update-TimerUi

# Cache disque d'abord (ouverture instantanee), puis mise a jour reseau
Set-Status 'Synchronisation du catalogue Discord…'
if (Test-Path -LiteralPath $paths.Catalog) {
    try {
        $cached = [QsCatalog]::Load($paths.Catalog)
        if ($cached.Count) {
            Set-Catalog $cached
            $script:catalogSub = 'cache du {0:dd/MM HH:mm} · mise à jour…' -f (Get-Item -LiteralPath $paths.Catalog).LastWriteTime
            $StatGamesSub.Text = L $script:catalogSub
        }
    } catch {}
}
Start-CatalogFetch

$timer.Start()
Step-LogLine; $logTimer.Start()
[void](New-Object Windows.Interop.WindowInteropHelper $win).EnsureHandle()
if (-not $StartHidden) { $win.Show(); [void]$win.Activate() }
if ($script:widgetWanted) { Show-Widget }
if ($script:remoteOn) { $script:remoteOn = [bool](Start-Remote) }
[Windows.Threading.Dispatcher]::Run()

# Fenetre fermee : on quitte tout de suite (aucun thread ne doit garder le processus en vie)
[Environment]::Exit(0)
