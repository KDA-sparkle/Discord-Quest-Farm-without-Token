# ============================================================
#  Traductions (francais -> anglais)
#  - $XamlEn  : textes fixes des fichiers XAML, cle = attribut complet tel qu'ecrit dans le XAML
#  - $MsgEn   : messages dynamiques identiques a chaque fois
#  - $MsgEnRx : messages dynamiques avec des parties variables (regex -> modele)
#               {1}, {2}... = groupe recopie tel quel ; {t1}, {t2}... = groupe lui-meme traduit
#  Le francais reste la langue de reference : toute chaine absente de ces tables reste en francais.
# ============================================================

$XamlEn = [ordered]@{
    'Content="Actualiser"' = 'Content="Refresh"'
    'Content="Créer"' = 'Content="Create"'
    'Content="Démarrer"' = 'Content="Start"'
    'Content="Favoris"' = 'Content="Favorites"'
    'Content="Grande"' = 'Content="Large"'
    'Content="Joués"' = 'Content="Played"'
    'Content="Lancer"' = 'Content="Run"'
    'Content="Moyenne"' = 'Content="Medium"'
    'Content="Nettoyer"' = 'Content="Clean up"'
    'Content="Petite"' = 'Content="Small"'
    'Content="Récents"' = 'Content="Recent"'
    'Content="Tous"' = 'Content="All"'
    'Content="Visibles"' = 'Content="Visible"'
    'Content="Voir l''aperçu"' = 'Content="Show preview"'
    'Content="Quête"' = 'Content="Quest"'
    'Content="Annuler"' = 'Content="Cancel"'
    'Content="Enregistrer"' = 'Content="Save"'
    'Text="Catalogue"' = 'Text="Catalog"'
    'Text="2 min de marge"' = 'Text="2 min margin"'
    'Text="Affiche un faux jeu d''exemple pendant 6 secondes avec ces réglages."' = 'Text="Shows a sample fake game for 6 seconds with these settings."'
    'Text="Aperçu"' = 'Text="Preview"'
    'Text="Apparence"' = 'Text="Appearance"'
    'Text="Arrêter la quête"' = 'Text="Stop quest"'
    'Text="Aucun jeu sélectionné"' = 'Text="No game selected"'
    'Text="Aucune session"' = 'Text="No session"'
    'Text="Catalogue des jeux"' = 'Text="Game catalog"'
    'Text="Chargement du catalogue…"' = 'Text="Loading catalog…"'
    'Text="Choisis le jeu de la quête dans le catalogue et indique la durée demandée. L''outil le lance, compte, te prévient et s''arrête tout seul."' = 'Text="Pick the quest''s game in the catalog and enter the required duration. The app launches it, counts, notifies you and stops on its own."'
    'Text="Choisis un jeu à gauche puis lance le spoof."' = 'Text="Pick a game on the left, then start the spoof."'
    'Text="Comme l''accent"' = 'Text="Same as accent"'
    'Text="Couleur d''accent"' = 'Text="Accent color"'
    'Text="Couleur"' = 'Text="Color"'
    'Text="Ctrl+Alt+S&#x0a;Ctrl+F&#x0a;Entrée&#x0a;Ctrl+Entrée&#x0a;Ctrl+D&#x0a;Suppr&#x0a;Échap"' = 'Text="Ctrl+Alt+S&#x0a;Ctrl+F&#x0a;Enter&#x0a;Ctrl+Enter&#x0a;Ctrl+D&#x0a;Delete&#x0a;Esc"'
    'Text="Ctrl+F chercher · Entrée lancer · Ctrl+Entrée rotation · Ctrl+D favori · Suppr arrêter · Ctrl+Alt+S pause"' = 'Text="Ctrl+F search · Enter launch · Ctrl+Enter rotation · Ctrl+D favorite · Delete stop · Ctrl+Alt+S pause"'
    'Text="Diagnostic"' = 'Text="Diagnostics"'
    'Text="Discord doit rester ouvert : le compte à rebours se met en pause s''il est fermé. La quête tourne à part de la rotation, les deux peuvent fonctionner en même temps."' = 'Text="Discord must stay open: the countdown pauses while it is closed. The quest runs separately from the rotation, both can work at the same time."'
    'Text="Démarrage"' = 'Text="Startup"'
    'Text="Démarre discrètement dans la zone de notification à l''ouverture de session."' = 'Text="Starts quietly in the notification area when you sign in."'
    'Text="En bas à droite de l''écran"' = 'Text="Bottom right of the screen"'
    'Text="Faux jeux"' = 'Text="Fake games"'
    'Text="Fenêtres des faux jeux"' = 'Text="Fake game windows"'
    'Text="Game Variety · jeux uniques"' = 'Text="Game Variety · unique games"'
    'Text="Initialisation"' = 'Text="Starting"'
    'Text="Jeux lancés"' = 'Text="Games launched"'
    'Text="Jeux les plus joués"' = 'Text="Most played games"'
    'Text="Lancer avec Windows"' = 'Text="Launch with Windows"'
    'Text="Lancer la quête"' = 'Text="Start quest"'
    'Text="Lancer le spoof"' = 'Text="Start spoof"'
    'Text="Langue"' = 'Text="Language"'
    'Text="Toute l''interface change de langue, tout de suite."' = 'Text="The whole interface switches language right away."'
    'Text="Minuterie"' = 'Text="Timer"'
    'Text="Mis à jour automatiquement toutes les 24 h."' = 'Text="Updated automatically every 24 h."'
    'Text="Mode quête"' = 'Text="Quest mode"'
    'Text="Nettoyer le dossier games"' = 'Text="Clean up the games folder"'
    'Text="Ouvre l''outil avec sa vraie icône, sans console."' = 'Text="Opens the app with its real icon, no console."'
    'Text="Raccourci sur le bureau"' = 'Text="Desktop shortcut"'
    'Text="Raccourcis clavier"' = 'Text="Keyboard shortcuts"'
    'Text="Rechercher un jeu"' = 'Text="Search a game"'
    'Text="Rotation automatique"' = 'Text="Auto rotation"'
    'Text="Réglages"' = 'Text="Settings"'
    'Text="Simulateur de présence Discord"' = 'Text="Discord presence simulator"'
    'Text="Supprime les faux exe inutilisés (les sessions en cours sont conservées)."' = 'Text="Deletes unused fake exes (running sessions are kept)."'
    'Text="Synchronisation"' = 'Text="Syncing"'
    'Text="Sélectionne un jeu dans le catalogue à gauche"' = 'Text="Select a game in the catalog on the left"'
    'Text="Taille de la carte du faux jeu."' = 'Text="Size of the fake game card."'
    'Text="Taille"' = 'Text="Size"'
    'Text="Temps en cours"' = 'Text="Current time"'
    'Text="Temps simulé · 14 derniers jours"' = 'Text="Simulated time · last 14 days"'
    'Text="Temps simulé"' = 'Text="Simulated time"'
    'Text="Tout arrêter"' = 'Text="Stop all"'
    'Text="Validés (15 min)"' = 'Text="Validated (15 min)"'
    'Text="Visibles, ou réduites dans la barre des tâches."' = 'Text="Visible, or minimized to the taskbar."'
    'Text="Vérifie Discord, le faux exe, le catalogue et le reste en un clic."' = 'Text="Checks Discord, the fake exe, the catalog and more in one click."'
    'Text="faux jeux en cours"' = 'Text="fake games running"'
    'Text="jeux détectables par Discord"' = 'Text="games detectable by Discord"'
    'Text="pause / reprise de la rotation, même outil caché&#x0a;chercher un jeu&#x0a;lancer le jeu sélectionné&#x0a;ajouter à la rotation&#x0a;favori&#x0a;arrêter la dernière session&#x0a;effacer la recherche, fermer les réglages"' = 'Text="pause / resume the rotation, even when hidden&#x0a;search a game&#x0a;launch the selected game&#x0a;add to rotation&#x0a;favorite&#x0a;stop the latest session&#x0a;clear search, close settings"'
    'Text="prochain palier : Sampler"' = 'Text="next tier: Sampler"'
    'Text="toutes sessions confondues"' = 'Text="across all sessions"'
    'ToolTip="Ajoute 2 minutes au cas où Discord valide la quête un peu en retard"' = 'ToolTip="Adds 2 minutes in case Discord validates the quest a bit late"'
    'ToolTip="Ajouter 10 jeux connus, jamais joués"' = 'ToolTip="Add 10 well-known games you never played"'
    'ToolTip="Ajouter à la rotation (Ctrl+Entrée)"' = 'ToolTip="Add to rotation (Ctrl+Enter)"'
    'ToolTip="Arrêter cette session (Suppr)"' = 'ToolTip="Stop this session (Delete)"'
    'ToolTip="Durée demandée par la quête"' = 'ToolTip="Duration required by the quest"'
    'ToolTip="Durée par jeu"' = 'ToolTip="Duration per game"'
    'ToolTip="En bas à droite"' = 'ToolTip="Bottom right"'
    'ToolTip="En bas à gauche"' = 'ToolTip="Bottom left"'
    'ToolTip="En haut à droite"' = 'ToolTip="Top right"'
    'ToolTip="En haut à gauche"' = 'ToolTip="Top left"'
    'ToolTip="Entrée"' = 'ToolTip="Enter"'
    'ToolTip="Envoyer dans la zone de notification (à côté de l''horloge)"' = 'ToolTip="Send to the notification area (next to the clock)"'
    'ToolTip="Fermer (arrête tout)"' = 'ToolTip="Close (stops everything)"'
    'ToolTip="Fermer (Échap)"' = 'ToolTip="Close (Esc)"'
    'ToolTip="Jeux différents lancés avec l''outil pendant au moins 15 min, Discord ouvert"' = 'ToolTip="Different games run with the app for at least 15 min, with Discord open"'
    'ToolTip="Jeux déjà lancés avec l''outil, et leur temps cumulé"' = 'ToolTip="Games already run with the app, and their total time"'
    'ToolTip="Listes enregistrées · exporter / importer une file"' = 'ToolTip="Saved lists · export / import a queue"'
    'ToolTip="Masquer le mini-widget"' = 'ToolTip="Hide the mini widget"'
    'ToolTip="Mini-widget toujours visible"' = 'ToolTip="Always-on-top mini widget"'
    'ToolTip="Minuterie : tout arrêter après un délai, puis mettre en veille ou éteindre le PC"' = 'ToolTip="Timer: stop everything after a delay, then sleep or shut down the PC"'
    'ToolTip="Ouvrir Quest Spoofer"' = 'ToolTip="Open Quest Spoofer"'
    'ToolTip="Passer au jeu suivant"' = 'ToolTip="Skip to the next game"'
    'ToolTip="Pause / reprise (Ctrl+Alt+S, même quand l''outil est caché)"' = 'ToolTip="Pause / resume (Ctrl+Alt+S, even when the app is hidden)"'
    'ToolTip="Retirer de la file"' = 'ToolTip="Remove from queue"'
    'ToolTip="Réduire"' = 'ToolTip="Minimize"'
    'ToolTip="Réglages"' = 'ToolTip="Settings"'
    'ToolTip="Vider la file"' = 'ToolTip="Clear queue"'
    'Value="Favori (Ctrl+D)"' = 'Value="Favorite (Ctrl+D)"'
    'Text="Téléphone"' = 'Text="Phone"'
    'Text="Contrôler depuis le téléphone"' = 'Text="Control from your phone"'
    'Text="Une appli sur ton téléphone, connecté au même Wi-Fi. Le PC doit rester allumé."' = 'Text="An app on your phone, on the same Wi-Fi. The PC must stay on."'
    'Text="Sur ton téléphone, ouvre cette adresse :"' = 'Text="On your phone, open this address:"'
    'Text="puis entre ce code :"' = 'Text="then enter this code:"'
    'Content="Nouveau code"' = 'Content="New code"'
    'ToolTip="Change le code et déconnecte tous les téléphones"' = 'ToolTip="Changes the code and disconnects all phones"'
    'Text="Astuce : sur le téléphone, « Ajouter à l''écran d''accueil » installe l''appli avec son icône. Si Windows demande l''accès au réseau pour PowerShell, autorise les réseaux privés."' = 'Text="Tip: on the phone, &quot;Add to Home screen&quot; installs the app with its icon. If Windows asks for network access for PowerShell, allow private networks."'
}

$MsgEn = @{
    'Ouvrir Quest Spoofer' = 'Open Quest Spoofer'
    'Mini-widget' = 'Mini widget'
    'Pause / reprise de la rotation' = 'Pause / resume rotation'
    'Quitter (arrête tout)' = 'Quit (stops everything)'
    'Toujours actif ici. Double-clic pour rouvrir.' = 'Still running here. Double-click to reopen.'
    'Jeu validé' = 'Game validated'
    'Synchronisation' = 'Syncing'
    'Chargement du catalogue des jeux' = 'Loading the game catalog'
    'Discord actif' = 'Discord active'
    'Discord est ouvert : les spoofs sont pris en compte' = 'Discord is open: spoofs are counted'
    'Discord fermé' = 'Discord closed'
    "Discord est fermé : rien ne compte tant qu'il n'est pas ouvert" = 'Discord is closed: nothing counts until it is open'
    "Aucun favori.`nSurvole un jeu et clique sur l'étoile (ou Ctrl+D)." = "No favorites yet.`nHover a game and click the star (or Ctrl+D)."
    "Aucun jeu joué pour l'instant.`nLe temps compte quand Discord est ouvert." = "No game played yet.`nTime counts while Discord is open."
    'Aucun jeu lancé récemment.' = 'No recently launched game.'
    'Favoris' = 'Favorites'
    'jeux détectables · à jour' = 'detectable games · up to date'
    "Impossible de charger le catalogue.`nVérifie ta connexion puis réessaie (Réglages → Actualiser)." = "Could not load the catalog.`nCheck your connection and try again (Settings → Refresh)."
    'Arrêter' = 'Stop'
    'Démarrer' = 'Start'
    'Ajoute des jeux à la file, puis démarre.' = 'Add games to the queue, then start.'
    'Rotation arrêtée' = 'Rotation stopped'
    'Rotation terminée' = 'Rotation finished'
    'Aucune rotation en cours' = 'No rotation running'
    'Aucune rotation en cours.' = 'No rotation running.'
    'Rotation reprise' = 'Rotation resumed'
    'Rotation en pause (Ctrl+Alt+S pour reprendre)' = 'Rotation paused (Ctrl+Alt+S to resume)'
    'Rotation en pause' = 'Rotation paused'
    'Ctrl+Alt+S pour reprendre.' = 'Ctrl+Alt+S to resume.'
    'Aucun jeu sélectionné' = 'No game selected'
    'Sélectionne un jeu dans le catalogue à gauche' = 'Select a game in the catalog on the left'
    "Choisis d'abord un jeu dans le catalogue" = 'Pick a game in the catalog first'
    'Quête arrêtée' = 'Quest stopped'
    'Quête terminée' = 'Quest finished'
    'Quête interrompue : le faux jeu a été fermé' = 'Quest interrupted: the fake game was closed'
    'Fin de rotation' = 'End of rotation'
    'Minuterie' = 'Timer'
    'Minuterie annulée' = 'Timer cancelled'
    'Minuterie écoulée' = 'Timer elapsed'
    'Arrêt du PC dans 60 s' = 'PC shutdown in 60 s'
    'Pour annuler : Win+R puis « shutdown /a ».' = 'To cancel: Win+R then "shutdown /a".'
    'Tout est arrêté.' = 'Everything is stopped.'
    ', puis mise en veille' = ', then sleep'
    ', puis arrêt du PC' = ', then PC shutdown'
    'Tout arrêter à la fin de la rotation' = 'Stop everything when the rotation ends'
    "Tout s'arrêtera à la fin de la rotation" = 'Everything will stop when the rotation ends'
    'Arrêt en fin de rotation désactivé' = 'Stop at end of rotation disabled'
    'Ensuite : ne rien faire' = 'Then: do nothing'
    'Ensuite : mettre le PC en veille' = 'Then: put the PC to sleep'
    'Ensuite : éteindre le PC' = 'Then: shut down the PC'
    'Annuler la minuterie' = 'Cancel timer'
    '30 min' = '30 min'
    'Enregistrer la file' = 'Save queue'
    'Donne un nom à cette liste de jeux.' = 'Give this game list a name.'
    'Arrête la rotation avant de charger une autre liste' = 'Stop the rotation before loading another list'
    'Fichier invalide : aucune liste de jeux trouvée' = 'Invalid file: no game list found'
    'Enregistrer la file sous…' = 'Save queue as…'
    'Exporter la file vers un fichier…' = 'Export queue to a file…'
    'Importer une file depuis un fichier…' = 'Import a queue from a file…'
    'Exporter la file de rotation' = 'Export the rotation queue'
    'Importer une file de rotation' = 'Import a rotation queue'
    'Quête' = 'Quest'
    'Statistiques' = 'Statistics'
    'Quête · en pause' = 'Quest · paused'
    'Quête · temps restant' = 'Quest · time left'
    'Session en cours' = 'Session running'
    'Aucune session' = 'No session'
    'Lancement avec Windows désactivé' = 'Launch with Windows disabled'
    'Quest Spoofer démarrera avec Windows, dans la zone de notification' = 'Quest Spoofer will start with Windows, in the notification area'
    'Réduites' = 'Minimized'
    'Visibles' = 'Visible'
    "Comme l'accent" = 'Same as accent'
    'Aperçu affiché pendant 6 secondes' = 'Preview shown for 6 seconds'
    'Aperçu · Quest Spoofer' = 'Preview · Quest Spoofer'
    'Raccourci présent sur le bureau.' = 'Shortcut is on the desktop.'
    'Recréer' = 'Recreate'
    "Ouvre l'outil avec sa vraie icône, sans console." = 'Opens the app with its real icon, no console.'
    'Créer' = 'Create'
    'Diagnostic en cours…' = 'Running diagnostics…'
    'Discord est ouvert.' = 'Discord is open.'
    "Discord est fermé : aucun spoof n'est pris en compte tant qu'il n'est pas lancé." = 'Discord is closed: no spoof counts until it is running.'
    'Catalogue chargé depuis le cache : la mise à jour en ligne a échoué ou est en cours.' = 'Catalog loaded from cache: the online update failed or is still running.'
    'Catalogue non chargé : vérifie ta connexion puis clique sur Actualiser.' = 'Catalog not loaded: check your connection, then click Refresh.'
    'Faux exe de base présent.' = 'Base fake exe present.'
    "Faux exe de base introuvable : relance l'outil pour le recompiler." = 'Base fake exe missing: restart the app to rebuild it.'
    "Le faux exe se lance mais n'ouvre pas de fenêtre : un antivirus le bloque peut-être." = 'The fake exe starts but opens no window: an antivirus may be blocking it.'
    "Les faux jeux s'arrêtent bien avec l'outil, même en cas de plantage." = 'Fake games stop with the app, even if it crashes.'
    "Impossible de lier les faux jeux à l'outil : ils pourraient survivre à un plantage." = 'Could not tie fake games to the app: they could survive a crash.'
    'Raccourci global Ctrl+Alt+S actif.' = 'Global shortcut Ctrl+Alt+S active.'
    'Ctrl+Alt+S est déjà utilisé par un autre programme : utilise le bouton pause.' = 'Ctrl+Alt+S is already used by another program: use the pause button.'
    'rotation active' = 'rotation active'
    'pas de rotation' = 'no rotation'
    'quête active' = 'quest active'
    'pas de quête' = 'no quest'
    'actif' = 'on'
    'inactif (aucune session)' = 'off (no session)'
    'La file de rotation est vide' = 'The rotation queue is empty'
    'File de rotation vidée' = 'Rotation queue cleared'
    'Mise à jour du catalogue déjà en cours…' = 'Catalog update already running…'
    'Mise à jour du catalogue…' = 'Updating catalog…'
    'Les spoofs ne comptent plus tant que Discord est fermé.' = 'Spoofs do not count while Discord is closed.'
    'Rotation en pause : Discord est fermé' = 'Rotation paused: Discord is closed'
    'Discord est fermé, le temps ne compte plus.' = 'Discord is closed, time no longer counts.'
    'Discord est revenu : rotation reprise' = 'Discord is back: rotation resumed'
    'Synchronisation du catalogue Discord…' = 'Syncing the Discord catalog…'
    "Aucune donnée pour l'instant : lance un jeu avec Discord ouvert." = 'No data yet: launch a game with Discord open.'
    ' · sessions actives conservées' = ' · running sessions kept'
    'non chargé' = 'not loaded'
    'jamais' = 'never'
    'Émeraude' = 'Emerald'
    'Rose' = 'Pink'
    'Ambre' = 'Amber'
    'Bleu ciel' = 'Sky blue'
    "En haut à gauche de l'écran" = 'Top left of the screen'
    "En haut à droite de l'écran" = 'Top right of the screen'
    "En bas à gauche de l'écran" = 'Bottom left of the screen'
    "En bas à droite de l'écran" = 'Bottom right of the screen'
    'Rotation · pause' = 'Rotation · paused'
    'Contrôle depuis le téléphone activé' = 'Phone control enabled'
    'Contrôle depuis le téléphone désactivé' = 'Phone control disabled'
    'Nouveau code : les téléphones connectés doivent se reconnecter' = 'New code: connected phones must reconnect'
    'Téléphone connecté' = 'Phone connected'
    'Téléphone connecté · en direct' = 'Phone connected · live'
    "Aucun téléphone appairé pour l'instant" = 'No phone paired yet'
    'Langue : français' = 'Language: French'
    'Langue : anglais' = 'Language: English'
}

$MsgEnRx = @(
    @('^(.+) atteint · prochain : (.+)$', '{1} reached · next: {2}'),
    @('^prochain palier : (.+)$', 'next tier: {1}'),
    @('^(.+) atteint$', '{1} reached'),
    @('^✓ (.+) compte comme joué · (\d+) jeu\(x\) unique\(s\)$', '✓ {1} counts as played · {2} unique game(s)'),
    @('^(.+) · (\d+) jeu\(x\) unique\(s\)$', '{1} · {2} unique game(s)'),
    @('^Aucun jeu ne correspond à « (.*) »\.$', 'No game matches "{1}".'),
    @('^Favoris · (\d+)$', 'Favorites · {1}'),
    @('^Catalogue synchronisé · (.+) jeux Windows$', 'Catalog synced · {1} Windows games'),
    @('^Hors ligne : catalogue en cache utilisé \((.*)\)$', 'Offline: using the cached catalog ({1})'),
    @('^Impossible de récupérer la liste des jeux : (.*)$', 'Could not fetch the game list: {1}'),
    @('^(.+) tourne déjà$', '{1} is already running'),
    @('^Chemin refusé : (.+)$', 'Path refused: {1}'),
    @('^Échec du lancement de (.+) : (.*)$', 'Failed to launch {1}: {2}'),
    @('^Spoof actif · (.+)$', 'Spoof running · {1}'),
    @('^Ajouté aux favoris · (.+)$', 'Added to favorites · {1}'),
    @('^Retiré des favoris · (.+)$', 'Removed from favorites · {1}'),
    @('^Jeu (\d+)/(\d+) · (.+)$', 'Game {1}/{2} · {3}'),
    @('^En pause \(Discord fermé\) · (.+)$', 'Paused (Discord closed) · {t1}'),
    @('^En pause · (.+)$', 'Paused · {t1}'),
    @('^(\d+) jeu\(x\) en file · (\d+) min chacun$', '{1} game(s) queued · {2} min each'),
    @('^(.+) est déjà dans la file$', '{1} is already in the queue'),
    @('^Ajouté à la rotation · (.+)$', 'Added to rotation · {1}'),
    @('^Rotation terminée · (\d+) jeu\(x\) joué\(s\)$', 'Rotation finished · {1} game(s) played'),
    @('^(\d+) jeu\(x\) joué\(s\)$', '{1} game(s) played'),
    @('^Rotation reprise · jeu (\d+)/(\d+)$', 'Rotation resumed · game {1}/{2}'),
    @('^Rotation · (\d+)/(\d+) · pause$', 'Rotation · {1}/{2} · paused'),
    @('^En cours · (.+)$', 'Running · {1}'),
    @('^Quête lancée · (.+) · (\d+) min$', 'Quest started · {1} · {2} min'),
    @('^✓ Quête terminée · (.+) : le temps demandé est atteint$', '✓ Quest finished · {1}: the required time is reached'),
    @('^(.+) : le temps demandé est atteint\.$', '{1}: the required time is reached.'),
    @("^Minuterie : tout s'arrête à (\d\d:\d\d)(.*)$", 'Timer: everything stops at {1}{t2}'),
    @('^(.+) : tout est arrêté, mise en veille du PC$', '{t1}: everything stopped, putting the PC to sleep'),
    @('^(.+) : arrêt du PC dans 60 s \(Win\+R puis « shutdown /a » pour annuler\)$', '{t1}: PC shutdown in 60 s (Win+R then "shutdown /a" to cancel)'),
    @('^(.+) : tout est arrêté$', '{t1}: everything stopped'),
    @('^Tout arrêter dans (.+)$', 'Stop everything in {1}'),
    @('^Action de fin : (.+)$', 'End action: {1}'),
    @('^Liste (\d+)$', 'List {1}'),
    @('^Liste enregistrée · (.+) \((\d+) jeux\)$', 'List saved · {1} ({2} games)'),
    @('^Liste chargée · (.+) \((\d+) jeux\)$', 'List loaded · {1} ({2} games)'),
    @('^File exportée · (.+)$', 'Queue exported · {1}'),
    @("^Échec de l'export : (.*)$", 'Export failed: {1}'),
    @('^(\d+) jeu\(x\) importé\(s\), (\d+) introuvable\(s\) dans le catalogue$', '{1} game(s) imported, {2} not found in the catalog'),
    @('^(\d+) jeu\(x\) importé\(s\)$', '{1} game(s) imported'),
    @('^Charger « (.+) » · (\d+) jeux$', 'Load "{1}" · {2} games'),
    @('^Supprimer « (.+) »$', 'Delete "{1}"'),
    @('^Liste supprimée · (.+)$', 'List deleted · {1}'),
    @('^Session · \+(\d+) autre\(s\)$', 'Session · +{1} more'),
    @('^Impossible de modifier le démarrage : (.*)$', 'Could not change startup: {1}'),
    @('^Raccourci créé sur le bureau : (.+)$', 'Desktop shortcut created: {1}'),
    @('^Impossible de créer le raccourci : (.*)$', 'Could not create the shortcut: {1}'),
    @("^Comme l'accent \((.+)\)$", 'Same as accent ({t1})'),
    @("^Impossible d'afficher l'aperçu : (.*)$", 'Could not show the preview: {1}'),
    @('^(.+) jeux · mis à jour le (.+) · auto toutes les 24 h$', '{1} games · updated {t2} · auto every 24 h'),
    @('^(.+) · mis à jour le (.+) · auto toutes les 24 h$', '{t1} · updated {t2} · auto every 24 h'),
    @('^Catalogue à jour : (.+) jeux Windows\.$', 'Catalog up to date: {1} Windows games.'),
    @('^Un faux jeu se lance et ouvre sa fenêtre \((\d+) ms\)\.$', 'A fake game starts and opens its window ({1} ms).'),
    @('^Impossible de lancer un faux exe : (.*)$', 'Could not launch a fake exe: {1}'),
    @('^(\d+) session\(s\) en cours · (.+) · (.+) · anti-veille (.+)\.$', '{1} session(s) running · {t2} · {t3} · keep-awake {t4}.'),
    @("^Mémoire utilisée par l'outil : (\d+) Mo\.$", 'Memory used by the app: {1} MB.'),
    @('^Diagnostic terminé : (\d+) OK, (\d+) avertissement\(s\), (\d+) problème\(s\)$', 'Diagnostics done: {1} OK, {2} warning(s), {3} problem(s)'),
    @('^Nettoyage : (\d+) fichier\(s\) supprimé\(s\)(.*)$', 'Cleanup: {1} file(s) deleted{t2}'),
    @('^, (\d+) verrouillé\(s\)(.*)$', ', {1} locked{t2}'),
    @('^Arrêté · (.+)$', 'Stopped · {1}'),
    @('^(\d+) session\(s\) arrêtée\(s\)$', '{1} session(s) stopped'),
    @('^(\d+) jeux ajoutés à la rotation$', '{1} games added to rotation'),
    @("^(.+) s'est arrêté$", '{1} has stopped'),
    @('^cache du (.+) · mise à jour…$', 'cache from {1} · updating…'),
    @("^Impossible d'ouvrir le port (\d+) : il est peut-être déjà utilisé$", 'Could not open port {1}: it may already be in use'),
    @('^(\d+) téléphone\(s\) appairé\(s\) · dernière visite il y a (.+) j$', '{1} phone(s) paired · last seen {2} d ago'),
    @('^(\d+) téléphone\(s\) appairé\(s\) · dernière visite il y a (.+)$', '{1} phone(s) paired · last seen {2} ago'),
    @('^Autres adresses : (.+)$', 'Other addresses: {1}')
)

# Traduit un texte affiche (francais -> anglais si la langue choisie est l'anglais)
function L([string]$s) {
    if ($script:lang -ne 'en' -or -not $s) { return $s }
    if ($MsgEn.ContainsKey($s)) { return $MsgEn[$s] }
    foreach ($rx in $MsgEnRx) {
        $m = [regex]::Match($s, $rx[0])
        if (-not $m.Success) { continue }
        $out = $rx[1]
        for ($i = $m.Groups.Count - 1; $i -ge 1; $i--) {
            $v = $m.Groups[$i].Value
            $out = $out.Replace("{t$i}", (L $v)).Replace("{$i}", $v)
        }
        return $out
    }
    $s
}

# Valeur d'un attribut XAML ('Text="a &#x0a; b"' -> "a`nb")
function Get-XamlAttrValue([string]$kv) {
    $v = $kv.Substring($kv.IndexOf('="') + 2)
    [Net.WebUtility]::HtmlDecode($v.Substring(0, $v.Length - 1))
}

# Avant le chargement d'un XAML : chaque texte traduisible devient {DynamicResource L_n}.
# La langue peut ensuite changer a chaud (Set-StrResources), sans recharger l'interface.
$script:StrRes = @{}   # L_n -> @(francais, anglais)
function Convert-XamlLang([string]$xaml) {
    $i = 0
    foreach ($k in $XamlEn.Keys) {
        $i++
        if (-not $xaml.Contains($k)) { continue }
        $id = "L_$i"
        $script:StrRes[$id] = @((Get-XamlAttrValue $k), (Get-XamlAttrValue $XamlEn[$k]))
        $xaml = $xaml.Replace($k, ('{0}="{{DynamicResource {1}}}"' -f $k.Substring(0, $k.IndexOf('=')), $id))
    }
    $xaml
}

# Remplit les textes d'un dictionnaire de ressources dans la langue courante
function Set-StrResources($res) {
    $n = if ($script:lang -eq 'en') { 1 } else { 0 }
    foreach ($id in $script:StrRes.Keys) { $res[$id] = $script:StrRes[$id][$n] }
}
