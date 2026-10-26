'use strict';
// Quest Farm mobile : pilote l'outil PC sur le reseau local.
// L'etat vient de GET /api/state (toutes les 2 s), les actions partent en POST /api/cmd.
// Les textes affiches (noms de jeux...) passent toujours par textContent, jamais par innerHTML.

// ---------- Textes (la langue suit celle de l'outil PC) ----------
const TEXT = {
  fr: {
    tagline: '// tu ne joues qu’avec moi ♡',
    pairText: 'Entre le code affiché dans Quest Farm sur ton PC (Réglages → Téléphone).',
    connect: 'Connecter', badPin: 'Code incorrect.', locked: 'Trop d’essais. Réessaie dans une minute.',
    netErr: 'Impossible de joindre le PC.',
    offline: 'Impossible de joindre le PC. Vérifie que Quest Farm est ouvert et que tu es sur le même Wi-Fi.',
    discordOn: 'Discord actif', discordOff: 'Discord fermé',
    tabHome: 'Accueil', tabGames: 'Jeux', tabQuest: 'Quête', tabStats: 'Stats',
    running: 'En cours', noSession: 'Aucune session', noSessionHint: 'Lance un jeu depuis l’onglet Jeux.',
    kindManual: 'Lancement manuel', kindRot: 'Rotation', kindQuest: 'Quête',
    rotation: 'Rotation automatique', gameOf: 'Jeu {0}/{1} · {2}', paused: 'En pause', pausedDiscord: 'En pause (Discord fermé)',
    queued: '{0} jeu(x) en file · {1} min chacun', queueEmpty: 'Ajoute des jeux depuis l’onglet Jeux.',
    start: 'Démarrer', stop: 'Arrêter', perGame: 'min / jeu',
    timer: 'Minuterie', stopsIn: 'Tout s’arrête dans {0}', atRotEnd: 'Tout s’arrête à la fin de la rotation', timerOff: 'Désactivée',
    cancel: 'Annuler', stopAll: 'Tout arrêter', confirmStopAll: 'Arrêter toutes les sessions ?',
    search: 'Rechercher un jeu', searchHint: 'Tape le nom d’un jeu pour le lancer, l’ajouter à la rotation ou en faire une quête.',
    noResult: 'Aucun jeu trouvé.', catalogLoading: 'Le catalogue se charge sur le PC…',
    launched: 'Lancé : {0}', added: 'Ajouté à la rotation : {0}', sent: 'Envoyé',
    questMode: 'Mode quête', questDesc: 'Le jeu tourne le temps demandé, puis tout s’arrête tout seul.',
    questPick: 'Choisis un jeu dans l’onglet Jeux (bouton drapeau).', minutes: 'min', margin: '2 min de marge',
    startQuest: 'Lancer la quête', stopQuest: 'Arrêter la quête', questRunning: 'Quête en cours', questPaused: 'En pause : Discord est fermé',
    variety: 'Game Variety', nextTier: 'prochain : {0}', reached: '{0} atteint', today: 'Aujourd’hui', simulated: 'temps simulé',
    sessions: 'Sessions', fakeGames: 'faux jeux en cours', catalog: 'Catalogue', games: 'jeux détectables',
    device: 'Ce téléphone', deviceDesc: 'Connecté à Quest Farm sur ton réseau Wi-Fi.', logout: 'Se déconnecter',
    pcNote: 'Le PC doit rester allumé avec Quest Farm et Discord ouverts. La langue et la couleur suivent l’outil PC.',
  },
  en: {
    tagline: '// you only play with me ♡',
    pairText: 'Enter the code shown in Quest Farm on your PC (Settings → Phone).',
    connect: 'Connect', badPin: 'Wrong code.', locked: 'Too many attempts. Try again in a minute.',
    netErr: 'Could not reach the PC.',
    offline: 'Could not reach the PC. Make sure Quest Farm is open and you are on the same Wi-Fi.',
    discordOn: 'Discord active', discordOff: 'Discord closed',
    tabHome: 'Home', tabGames: 'Games', tabQuest: 'Quest', tabStats: 'Stats',
    running: 'Running', noSession: 'No session', noSessionHint: 'Start a game from the Games tab.',
    kindManual: 'Manual launch', kindRot: 'Rotation', kindQuest: 'Quest',
    rotation: 'Auto rotation', gameOf: 'Game {0}/{1} · {2}', paused: 'Paused', pausedDiscord: 'Paused (Discord closed)',
    queued: '{0} game(s) queued · {1} min each', queueEmpty: 'Add games from the Games tab.',
    start: 'Start', stop: 'Stop', perGame: 'min / game',
    timer: 'Timer', stopsIn: 'Everything stops in {0}', atRotEnd: 'Everything stops when the rotation ends', timerOff: 'Off',
    cancel: 'Cancel', stopAll: 'Stop all', confirmStopAll: 'Stop all sessions?',
    search: 'Search a game', searchHint: 'Type a game name to launch it, add it to the rotation or make it a quest.',
    noResult: 'No game found.', catalogLoading: 'The catalog is loading on the PC…',
    launched: 'Launched: {0}', added: 'Added to rotation: {0}', sent: 'Sent',
    questMode: 'Quest mode', questDesc: 'The game runs for the required time, then everything stops on its own.',
    questPick: 'Pick a game in the Games tab (flag button).', minutes: 'min', margin: '2 min margin',
    startQuest: 'Start quest', stopQuest: 'Stop quest', questRunning: 'Quest running', questPaused: 'Paused: Discord is closed',
    variety: 'Game Variety', nextTier: 'next: {0}', reached: '{0} reached', today: 'Today', simulated: 'simulated time',
    sessions: 'Sessions', fakeGames: 'fake games running', catalog: 'Catalog', games: 'detectable games',
    device: 'This phone', deviceDesc: 'Connected to Quest Farm on your Wi-Fi network.', logout: 'Log out',
    pcNote: 'The PC must stay on with Quest Farm and Discord open. Language and color follow the PC app.',
  },
};
let lang = (navigator.language || 'fr').toLowerCase().startsWith('fr') ? 'fr' : 'en';
const t = (key, ...args) => (TEXT[lang][key] ?? TEXT.fr[key] ?? key).replace(/\{(\d)\}/g, (_, i) => args[i]);

// ---------- Icones (SVG statiques) ----------
const ICON = {
  home: '<path d="M3 11.5 12 4l9 7.5"/><path d="M5 10v10h14V10"/>',
  games: '<rect x="2.5" y="7" width="19" height="11" rx="5.5"/><path d="M7.5 10.5v4M5.5 12.5h4"/><circle cx="15.5" cy="11.5" r=".6"/><circle cx="17.5" cy="13.5" r=".6"/>',
  quest: '<path d="M5 21V4"/><path d="M5 4h11l-2 4 2 4H5"/>',
  stats: '<path d="M4 20V10M10 20V4M16 20v-7M22 20H2"/>',
  play: '<path d="M7 4.5v15l12-7.5z"/>',
  stop: '<rect x="6" y="6" width="12" height="12" rx="2"/>',
  pause: '<path d="M8 5v14M16 5v14"/>',
  next: '<path d="M6 5l9 7-9 7z"/><path d="M18 5v14"/>',
  plus: '<path d="M12 5v14M5 12h14"/>',
  x: '<path d="M6 6l12 12M18 6 6 18"/>',
  trash: '<path d="M4 7h16M9 7V4h6v3M6 7l1 13h10l1-13"/>',
  shuffle: '<path d="M16 4h4v4M4 20 20 4M20 16v4h-4M15 15l5 5M4 4l5 5"/>',
  repeat: '<path d="M17 2l4 4-4 4"/><path d="M3 11V9a3 3 0 0 1 3-3h15"/><path d="M7 22l-4-4 4-4"/><path d="M21 13v2a3 3 0 0 1-3 3H3"/>',
  timer: '<circle cx="12" cy="13" r="8"/><path d="M12 9v4l2 2M10 2h4"/>',
  minus: '<path d="M5 12h14"/>',
  phone: '<rect x="7" y="2.5" width="10" height="19" rx="2.5"/><path d="M11 18.5h2"/>',
};
const svg = name => `<svg viewBox="0 0 24 24" aria-hidden="true">${ICON[name]}</svg>`;

// ---------- Petits outils DOM ----------
const $ = id => document.getElementById(id);
function el(tag, cls, text) {
  const e = document.createElement(tag);
  if (cls) e.className = cls;
  if (text !== undefined && text !== null) e.textContent = text;
  return e;
}
function iconBtn(name, cls, onClick, label) {
  const b = el('button', 'ibtn' + (cls ? ' ' + cls : ''));
  b.innerHTML = svg(name);
  if (label) b.setAttribute('aria-label', label);
  b.addEventListener('click', onClick);
  return b;
}
function btn(text, cls, onClick, icon) {
  const b = el('button', 'btn' + (cls ? ' ' + cls : ''));
  if (icon) b.innerHTML = svg(icon);
  b.appendChild(document.createTextNode(text));
  b.addEventListener('click', onClick);
  return b;
}
function gameIcon(g, live) {
  const box = el('div', 'gicon' + (live ? ' live' : ''), g.ini || '?');
  if (g.icon) {
    const img = el('img');
    img.src = g.icon; img.alt = ''; img.loading = 'lazy';
    img.onerror = () => img.remove();
    box.appendChild(img);
  }
  return box;
}
function cardHead(icon, color, title, sub) {
  const head = el('div', 'card-head');
  const chip = el('div', 'chip-icon' + (color ? ' ' + color : ''));
  chip.innerHTML = svg(icon);
  const txt = el('div', 'grow');
  txt.append(el('div', 'card-title', title));
  if (sub !== undefined) txt.append(el('div', 'card-sub', sub));
  head.append(chip, txt);
  return head;
}
let toastTimer;
function toast(msg) {
  const box = $('toast');
  box.textContent = msg;
  box.hidden = false;
  clearTimeout(toastTimer);
  toastTimer = setTimeout(() => { box.hidden = true; }, 2200);
}

// "04:32" ou "1:04:32"
function fmtClock(sec) {
  sec = Math.max(0, Math.round(sec));
  const h = Math.floor(sec / 3600), m = Math.floor(sec % 3600 / 60), s = sec % 60;
  const p = n => String(n).padStart(2, '0');
  return h ? `${h}:${p(m)}:${p(s)}` : `${p(m)}:${p(s)}`;
}
// "12 min" ou "1 h 05"
function fmtDur(sec) {
  const m = Math.floor(sec / 60);
  return m >= 60 ? `${Math.floor(m / 60)} h ${String(m % 60).padStart(2, '0')}` : `${m} min`;
}
function parseHms(str) {
  const p = String(str || '0').split(':').map(Number);
  return p.reduce((a, n) => a * 60 + (n || 0), 0);
}

// ---------- Communication avec le PC ----------
let token = localStorage.getItem('qs_token');
let state = null;
let fetchedAt = 0;

async function api(path, opts = {}) {
  const r = await fetch(path, {
    ...opts,
    cache: 'no-store',
    headers: { 'Content-Type': 'application/json', 'X-Token': token || '' },
  });
  if (r.status === 401 && path !== '/api/pair') { logout(); throw new Error('auth'); }
  return r;
}

async function cmd(action, extra = {}, message) {
  try {
    await api('/api/cmd', { method: 'POST', body: JSON.stringify({ action, ...extra }) });
    toast(message || t('sent'));
    setTimeout(refresh, 350);
    setTimeout(refresh, 1200);
  } catch (e) {
    if (e.message !== 'auth') toast(t('netErr'));
  }
}

async function refresh() {
  if (!token) return;
  try {
    const r = await api('/api/state');
    state = await r.json();
    fetchedAt = Date.now();
    $('offline').hidden = true;
    applyPcSettings();
    render();
  } catch (e) {
    if (e.message !== 'auth') { $('offline').textContent = t('offline'); $('offline').hidden = false; }
  }
}

// Langue et couleur d'accent de l'outil PC
function applyPcSettings() {
  if (state.accent) {
    const hex = state.accent.replace('#', '');
    const [r, g, b] = [0, 2, 4].map(i => parseInt(hex.substr(i, 2), 16));
    document.documentElement.style.setProperty('--accent', '#' + hex);
    document.documentElement.style.setProperty('--accent-soft', `rgba(${r}, ${g}, ${b}, .14)`);
  }
  if (state.lang && state.lang !== lang) {
    lang = state.lang;
    document.documentElement.lang = lang;
    labelStatic();
    if (lastQuery) search(lastQuery);
  }
}

// ---------- Appairage ----------
function showPair() {
  $('app').hidden = true;
  $('pair').hidden = false;
  $('tagline').textContent = t('tagline');
  $('pair-text').textContent = t('pairText');
  $('pair-btn').textContent = t('connect');
  setTimeout(() => $('pin').focus(), 100);
}

async function pair() {
  const pin = $('pin').value.replace(/\D/g, '');
  if (pin.length !== 6) return;
  const err = $('pair-error');
  err.hidden = true;
  try {
    const r = await api('/api/pair', { method: 'POST', body: JSON.stringify({ pin }) });
    if (r.status === 200) {
      token = (await r.json()).token;
      localStorage.setItem('qs_token', token);
      $('pin').value = '';
      startApp();
      return;
    }
    err.textContent = r.status === 429 ? t('locked') : t('badPin');
  } catch (e) {
    err.textContent = t('netErr');
  }
  err.hidden = false;
  $('pin').select();
}

function logout() {
  token = null;
  localStorage.removeItem('qs_token');
  showPair();
}

// ---------- Onglets ----------
let tab = 'home';
const TABS = { home: ['home', 'tabHome'], games: ['games', 'tabGames'], quest: ['quest', 'tabQuest'], stats: ['stats', 'tabStats'] };

function labelStatic() {
  document.querySelectorAll('.tabs button').forEach(b => {
    const [icon, key] = TABS[b.dataset.tab];
    b.innerHTML = svg(icon);
    b.appendChild(el('span', null, t(key)));
  });
  $('q').placeholder = t('search');
}

function setTab(name) {
  tab = name;
  document.querySelectorAll('.tabs button').forEach(b => b.classList.toggle('active', b.dataset.tab === name));
  for (const v of Object.keys(TABS)) $('view-' + v).hidden = v !== name;
  if (name === 'games' && !lastQuery) renderResults(null);
  render();
  window.scrollTo(0, 0);
}

// ---------- Rendu ----------
function render() {
  if (!state) return;
  const badge = $('discord');
  badge.className = 'badge ' + (state.discord ? 'on' : 'off');
  $('discord-text').textContent = state.discord ? t('discordOn') : t('discordOff');
  if (tab === 'home') renderHome();
  if (tab === 'quest') renderQuest();
  if (tab === 'stats') renderStats();
}

const kindLabel = k => (k === 'Rotation' ? t('kindRot') : k === 'Quête' ? t('kindQuest') : t('kindManual'));
const kindClass = k => (k === 'Rotation' ? 'rotation' : k === 'Quête' ? 'quest' : '');

function renderHome() {
  const view = $('view-home');
  const keepScroll = view.querySelector('.queue') ? view.querySelector('.queue').scrollLeft : 0;
  const parts = [];

  // Sessions en cours
  parts.push(el('div', 'label', t('running')));
  if (state.sessions.length) {
    const list = el('div', 'list');
    for (const s of state.sessions) {
      const row = el('div', 'row');
      const text = el('div', 'gtext');
      text.append(el('div', 'gname', s.name), el('div', 'gsub', kindLabel(s.kind)));
      const time = el('div', 'time cd-up', s.elapsed);
      time.dataset.base = parseHms(s.elapsed);
      row.append(el('div', 'stripe ' + kindClass(s.kind)), gameIcon(s, true), text, time,
        iconBtn('x', 'stop', () => cmd('stop', { pid: s.pid }), t('stop')));
      list.append(row);
    }
    parts.push(list);
  } else {
    const empty = el('div', 'card empty');
    empty.innerHTML = svg('games');
    empty.append(el('div', null, t('noSession')), el('div', 'hint', t('noSessionHint')));
    parts.push(empty);
  }

  // Rotation
  const r = state.rotation;
  const cur = r.on && r.queue[r.index];
  const sub = r.on
    ? (r.paused ? (r.userPaused ? t('paused') : t('pausedDiscord')) + ' · ' : '') + t('gameOf', r.index + 1, r.count, cur ? cur.name : '')
    : (r.count ? t('queued', r.count, r.minutes) : t('queueEmpty'));
  const rot = el('div', 'card');
  rot.append(cardHead('repeat', '', t('rotation'), sub));
  if (r.on) {
    const big = el('div', 'big cd', fmtClock(r.remaining));
    big.dataset.left = r.remaining;
    big.dataset.paused = r.paused ? '1' : '';
    const bar = el('div', 'bar');
    const fill = el('div');
    fill.style.width = (r.total ? (1 - r.remaining / r.total) * 100 : 0) + '%';
    bar.append(fill);
    rot.append(big, bar);
  }
  if (r.queue.length) {
    const q = el('div', 'queue');
    q.style.marginTop = r.on ? '0' : '12px';
    r.queue.forEach((g, i) => {
      const chip = el('div', 'qchip' + (r.on && i === r.index ? ' current' : ''));
      const rm = el('button');
      rm.innerHTML = svg('x');
      rm.addEventListener('click', () => cmd('queueRemove', { id: g.id }));
      chip.append(gameIcon(g), el('span', null, g.name), rm);
      q.append(chip);
    });
    rot.append(q);
  }
  const ctl = el('div', 'btns');
  ctl.style.marginTop = '12px';
  if (r.on) {
    ctl.append(btn(t('stop'), '', () => cmd('rotStop'), 'stop'),
      iconBtn(r.userPaused ? 'play' : 'pause', 'accent', () => cmd('rotPause')),
      iconBtn('next', '', () => cmd('rotNext')));
  } else {
    const go = btn(t('start'), 'primary', () => cmd('rotStart'), 'play');
    go.disabled = !r.count;
    ctl.append(go);
  }
  rot.append(ctl);
  const tools = el('div', 'btns');
  tools.style.marginTop = '8px';
  const step = el('div', 'stepper');
  const minus = el('button'); minus.innerHTML = svg('minus');
  const plus = el('button'); plus.innerHTML = svg('plus');
  minus.addEventListener('click', () => cmd('minutes', { value: Math.max(1, r.minutes - 5) }));
  plus.addEventListener('click', () => cmd('minutes', { value: Math.min(600, r.minutes + 5) }));
  step.append(minus, el('span', null, `${r.minutes} ${t('perGame')}`), plus);
  step.style.flex = '1';
  tools.append(step, iconBtn('shuffle', '', () => cmd('random')), iconBtn('trash', '', () => cmd('queueClear')));
  rot.append(tools);
  parts.push(rot);

  // Minuterie
  const tm = state.timer;
  const tsub = tm.left != null ? t('stopsIn', fmtClock(tm.left)) : tm.onRotationEnd ? t('atRotEnd') : t('timerOff');
  const timer = el('div', 'card');
  const head = cardHead('timer', 'amber', t('timer'), tsub);
  if (tm.left != null) {
    const subEl = head.querySelector('.card-sub');
    subEl.classList.add('cd-timer');
    subEl.dataset.left = tm.left;
  }
  timer.append(head);
  const pills = el('div', 'pills');
  pills.style.marginTop = '12px';
  for (const [min, label] of [[30, '30 min'], [60, '1 h'], [120, '2 h'], [240, '4 h'], [480, '8 h']]) {
    const p = el('button', 'pill', label);
    p.addEventListener('click', () => cmd('timer', { minutes: min }));
    pills.append(p);
  }
  if (tm.left != null || tm.onRotationEnd) {
    const c = el('button', 'pill active', t('cancel'));
    c.addEventListener('click', () => cmd('timerClear'));
    pills.append(c);
  }
  timer.append(pills);
  parts.push(timer);

  if (state.sessions.length) {
    parts.push(btn(t('stopAll'), 'danger wide', () => { if (confirm(t('confirmStopAll'))) cmd('stopAll'); }, 'stop'));
  }

  view.replaceChildren(...parts);
  const q = view.querySelector('.queue');
  if (q) q.scrollLeft = keepScroll;
}

// Recherche de jeux (le PC filtre son catalogue)
let lastQuery = '';
let searchTimer;
let searchSeq = 0;

async function search(q) {
  lastQuery = q;
  if (!q.trim()) { renderResults(null); return; }
  const seq = ++searchSeq;
  try {
    const r = await api('/api/search?q=' + encodeURIComponent(q));
    const list = await r.json();
    if (seq === searchSeq) renderResults(list);
  } catch (e) {
    if (e.message !== 'auth') toast(t('netErr'));
  }
}

function renderResults(list) {
  const box = $('results');
  if (!list) {
    box.replaceChildren(el('div', 'empty hint', state && !state.catalog ? t('catalogLoading') : t('searchHint')));
    return;
  }
  if (!list.length) { box.replaceChildren(el('div', 'empty hint', t('noResult'))); return; }
  box.replaceChildren(...list.map(g => {
    const row = el('div', 'row');
    const text = el('div', 'gtext');
    text.append(el('div', 'gname', g.name));
    row.append(gameIcon(g), text);
    if (g.played) row.append(el('span', 'played' + (g.isPlayed ? ' ok' : ''), g.played));
    row.append(
      iconBtn('play', 'accent', () => cmd('launch', { id: g.id }, t('launched', g.name))),
      iconBtn('plus', '', () => cmd('queueAdd', { id: g.id }, t('added', g.name))),
      iconBtn('quest', '', () => { questPick = g; setTab('quest'); }));
    return row;
  }));
}

// Mode quete
let questPick = null;
let questMin = 15;
let questMargin = true;

function renderQuest() {
  const view = $('view-quest');
  const qs = state.quest;
  if (qs.on) {
    const card = el('div', 'card');
    card.append(cardHead('quest', 'amber', t('questRunning'), qs.paused ? t('questPaused') : undefined));
    const game = el('div', 'game');
    game.style.marginTop = '14px';
    const text = el('div', 'gtext');
    text.append(el('div', 'gname', qs.name));
    game.append(gameIcon(qs, true), text);
    const big = el('div', 'big cd', fmtClock(qs.remaining));
    big.dataset.left = qs.remaining;
    big.dataset.paused = qs.paused ? '1' : '';
    const bar = el('div', 'bar');
    const fill = el('div');
    fill.style.width = (qs.total ? (1 - qs.remaining / qs.total) * 100 : 0) + '%';
    bar.append(fill);
    card.append(game, big, bar, btn(t('stopQuest'), 'danger wide', () => cmd('questStop'), 'stop'));
    view.replaceChildren(card);
    return;
  }
  const card = el('div', 'card');
  card.append(cardHead('quest', 'amber', t('questMode'), t('questDesc')));
  const pick = el('div', 'row');
  pick.style.marginTop = '14px';
  if (questPick) {
    const text = el('div', 'gtext');
    text.append(el('div', 'gname', questPick.name));
    pick.append(gameIcon(questPick), text);
  } else {
    pick.append(el('div', 'hint', t('questPick')));
  }
  const opts = el('div', 'btns');
  opts.style.marginTop = '12px';
  opts.style.alignItems = 'center';
  const step = el('div', 'stepper');
  const minus = el('button'); minus.innerHTML = svg('minus');
  const plus = el('button'); plus.innerHTML = svg('plus');
  const val = el('span', null, `${questMin} ${t('minutes')}`);
  minus.addEventListener('click', () => { questMin = Math.max(1, questMin - 1); val.textContent = `${questMin} ${t('minutes')}`; });
  plus.addEventListener('click', () => { questMin = Math.min(600, questMin + 1); val.textContent = `${questMin} ${t('minutes')}`; });
  step.append(minus, val, plus);
  const toggle = el('button', 'toggle');
  const sw = el('span', 'switch' + (questMargin ? ' on' : ''));
  toggle.append(sw, el('span', null, t('margin')));
  toggle.addEventListener('click', () => { questMargin = !questMargin; sw.classList.toggle('on', questMargin); });
  opts.append(step, toggle);
  const go = btn(t('startQuest'), 'primary wide', () => cmd('questStart', { id: questPick.id, minutes: questMin, margin: questMargin }), 'play');
  go.style.marginTop = '14px';
  go.disabled = !questPick;
  card.append(pick, opts, go);
  view.replaceChildren(card);
}

// Statistiques
function renderStats() {
  const s = state.stats;
  const tiles = el('div', 'tiles');
  const tile = (cls, label, value, small, sub) => {
    const d = el('div', 'tile' + (cls ? ' ' + cls : ''));
    const v = el('div', 'v', value);
    if (small) v.append(el('small', null, small));
    d.append(el('div', 's', label), v, el('div', 's', sub));
    return d;
  };
  const tierSub = s.goal ? (s.tier ? t('reached', s.tier) + ' · ' : '') + t('nextTier', s.nextTier) : t('reached', s.tier);
  tiles.append(
    tile('accent', t('variety'), String(s.unique), s.goal ? ` / ${s.goal}` : '', tierSub),
    tile('', t('today'), fmtDur(s.today), '', t('simulated')),
    tile('', t('sessions'), String(state.sessions.length), '', t('fakeGames')),
    tile('', t('catalog'), state.catalog.toLocaleString(lang), '', t('games')));
  const dev = el('div', 'card');
  dev.append(cardHead('phone', 'blue', t('device'), t('deviceDesc')));
  const out = btn(t('logout'), 'wide', logout);
  out.style.marginTop = '12px';
  dev.append(out);
  $('view-stats').replaceChildren(tiles, dev, el('div', 'hint', t('pcNote')));
}

// Comptes a rebours et chronos entre deux mises a jour
function tick() {
  if (!state) return;
  const since = (Date.now() - fetchedAt) / 1000;
  document.querySelectorAll('.cd').forEach(e => {
    if (!e.dataset.paused) e.textContent = fmtClock(Number(e.dataset.left) - since);
  });
  document.querySelectorAll('.cd-up').forEach(e => { e.textContent = fmtClock(Number(e.dataset.base) + since); });
  document.querySelectorAll('.cd-timer').forEach(e => { e.textContent = t('stopsIn', fmtClock(Number(e.dataset.left) - since)); });
}

// ---------- Demarrage ----------
function startApp() {
  $('pair').hidden = true;
  $('app').hidden = false;
  labelStatic();
  refresh();
}

document.querySelectorAll('.tabs button').forEach(b => b.addEventListener('click', () => setTab(b.dataset.tab)));
$('q').addEventListener('input', e => {
  clearTimeout(searchTimer);
  searchTimer = setTimeout(() => search(e.target.value), 250);
});
$('pin').addEventListener('input', e => {
  e.target.value = e.target.value.replace(/\D/g, '').slice(0, 6);
  if (e.target.value.length === 6) pair();
});
$('pair-btn').addEventListener('click', pair);
document.addEventListener('visibilitychange', () => { if (!document.hidden) refresh(); });
setInterval(() => { if (!document.hidden) refresh(); }, 2000);
setInterval(tick, 1000);

if (token) startApp(); else showPair();
