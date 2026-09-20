Vou criar os dois ficheiros pedidos: um `.md` explicando como o web app deve usar o servidor local (todos os endpoints), e as alterações ao `index.html` para integrar as novas funcionalidades (preferências nativas, músicas locais, shorties, letras).

## `VIBELY_SERVER_API.md`

```markdown
# Vibely — Guia de Integração do Servidor Local (LocalServer)

Este documento explica como o web app (`index.html`, rodando dentro do WebView)
deve comunicar com o servidor Android embutido (`LocalServer.kt`, NanoHTTPD na
porta 8080) e com a ponte nativa (`AndroidBridge.kt`, objeto `Android` injetado
no JavaScript).

Existem duas formas de comunicação:

1. **HTTP local** — `fetch('http://localhost:8080/...')` para dados de música
   (busca, stream, letras, shorties).
2. **Ponte JavaScript nativa** — `Android.nomeDaFuncao(...)` para capacidades
   do sistema Android (Bluetooth, downloads persistentes, partilha nativa,
   preferências, músicas locais, notificação).

O app deve sempre verificar `isApp` antes de usar qualquer uma das duas:

```js
const isApp = typeof Android !== 'undefined' && Android.isInsideApp();
```

Se `isApp` for `false`, o site está a correr fora do WebView (ex: preview no
browser do PC) e nenhuma destas chamadas vai funcionar — o app deve degradar
graciosamente (mostrar aviso, desativar player).

---

## 1. Endpoints HTTP (`http://localhost:8080`)

### `GET /search?q=<query>&limit=<n>`

Pesquisa músicas no YouTube via NewPipeExtractor. `limit` é opcional,
por omissão `100`, e o servidor pagina automaticamente várias páginas do
NewPipe até atingir esse número ou esgotar resultados.

```js
const res = await fetch(`http://localhost:8080/search?q=${encodeURIComponent(query)}&limit=100`);
const tracks = await res.json();
// [{ id, title, artist, duration, thumbnail, url, views, uploadDate }, ...]
```

### `GET /stream?id=<videoId>&quality=<auto|low|normal|high>`

Não devolve o áudio diretamente — devolve a URL local para tocar:

```js
const res = await fetch(`http://localhost:8080/stream?id=${videoId}`);
const { streamUrl } = await res.json();
// streamUrl = "http://localhost:8080/audio?id=<videoId>"
audioElement.src = streamUrl;
```

`quality` é aceite no endpoint mas atualmente o servidor já limita o
bitrate no lado do yt-dlp (≤96kbps) para poupar dados — o parâmetro fica
reservado para futura diferenciação de qualidade.

### `GET /audio?id=<videoId>`

O proxy real do áudio. Chamado automaticamente pelo elemento `<audio>` ao
usar o `streamUrl` de `/stream`. Suporta `Range` requests (seek funciona).
Nunca chamar diretamente para tocar — usar sempre via `/stream`.

### `GET /related?id=<videoId>`

Devolve até 20 faixas relacionadas com o vídeo, usadas para a fila
"tocar a seguir" automática e para montar o "álbum" de uma faixa.

```js
const res = await fetch(`http://localhost:8080/related?id=${videoId}`);
const related = await res.json();
```

### `GET /shorts?q=<query>`

Devolve até 30 candidatos a "Shorties" (metadados leves — sem stream
ainda). O preview em si é extraído sob demanda pelo player quando o
usuário chega àquele short, usando o mesmo `/stream?id=`.

```js
const res = await fetch(`http://localhost:8080/shorts?q=${encodeURIComponent(query)}`);
const shorts = await res.json();
// [{ id, title, artist, duration, thumbnail }, ...]
```

Fluxo recomendado: buscar metadados com `/shorts`, e só chamar
`/stream?id=` quando o short entrar em vista (scroll), exatamente como o
`index.html` já faz para as faixas normais — isto evita extrair 30
streams de uma vez (lento e gasta dados à toa).

### `GET /lyrics?title=<título>&artist=<artista>`

Busca letras via [lrclib.net](https://lrclib.net) (API pública gratuita,
sem necessidade de chave).

```js
const res = await fetch(`http://localhost:8080/lyrics?title=${encodeURIComponent(title)}&artist=${encodeURIComponent(artist)}`);
const data = await res.json();
// { found: true, plainLyrics: "...", syncedLyrics: "[00:12.34]..." }
// { found: false } se não encontrar
```

`syncedLyrics` vem no formato LRC (`[mm:ss.xx]texto por linha`) quando
disponível — útil para destacar a linha atual em sincronia com
`audio.currentTime`. Quando vazio, usar `plainLyrics`.

### `GET /debug?id=<videoId>`

Diagnóstico: força uma nova extração para o ID dado e devolve texto
simples com o histórico dos últimos eventos do extrator (útil para
depurar sem Logcat, basta abrir a URL no navegador).

---

## 2. Ponte nativa (`window.Android`)

Todas as funções abaixo só existem quando `isApp === true`. Verificar
`typeof Android.nomeFuncao === 'function'` antes de chamar, como o
`index.html` já faz para chamadas opcionais.

### Preferências persistentes

Substituem (ou complementam) o `localStorage` para as preferências
sobreviverem a limpezas de cache do WebView.

```js
// Ler todas as preferências guardadas nativamente (tema, idioma, qualidade, etc)
const prefsJson = Android.getPreferences();
const nativePrefs = JSON.parse(prefsJson);
// { theme, lang, quality, dlQuality, wifiOnly, saveData }

// Gravar uma preferência
Android.setPreference('theme', 'dark');
Android.setPreference('lang', 'pt');
```

`lang` já vem pré-preenchido com o idioma do sistema Android detectado
automaticamente na primeira leitura, se o usuário nunca tiver escolhido
um manualmente.

```js
// Saber se o sistema está em modo escuro (para tema "automático")
const isDark = Android.isSystemDarkMode();
```

### Rede

```js
const onWifi = Android.isOnWifi(); // true/false
```

### Downloads persistentes

Diferente do `localStorage` (que só guarda metadados), isto descarrega e
guarda o ficheiro de áudio de verdade na pasta privada da app.

```js
// Iniciar download (assíncrono — ouvir o resultado via evento broadcast, ver abaixo)
Android.downloadTrack(videoId, title, quality);

// Remover um download
Android.removeDownload(videoId);

// Verificar se já está descarregado
const done = Android.isDownloaded(videoId);

// Obter o caminho local do ficheiro (para tocar offline)
const fileUrl = Android.downloadedFileUrl(videoId); // "file:///data/.../videoId.audio" ou ""

// Partilhar o ficheiro descarregado com outra app (WhatsApp, etc)
Android.shareDownloadedFile(videoId, title);
```

Para tocar offline: se `Android.isDownloaded(id)` for `true`, usar
`Android.downloadedFileUrl(id)` como `src` do `<audio>` em vez de pedir
`/stream` — evita gastar dados para algo já local.

### Bluetooth

Lista dispositivos já **emparelhados** no telemóvel (não faz descoberta
de novos dispositivos — isso é feito pelas Definições do sistema, via
`openBluetoothSettings()`).

```js
const devicesJson = Android.scanDevices();
const devices = JSON.parse(devicesJson);
// [{ id, name, type: "speaker"|"headset"|"tv" }, ...]

Android.connectDevice(deviceId); // true/false
Android.disconnectDevice(deviceId);
Android.openBluetoothSettings(); // abre as definições nativas do Android
```

A ligação de áudio (perfil A2DP) em si é sempre gerida pelo sistema
Android assim que o dispositivo está emparelhado e selecionado como
saída de áudio — a app não reproduz áudio "para" o Bluetooth
diretamente, só confirma e orienta o usuário.

### Partilha nativa

```js
// Partilhar para uma rede específica (abre o app dela diretamente, se instalado)
Android.shareTo('whatsapp', title, artist, url);
// apps suportados: whatsapp, telegram, instagram, facebook, x
// qualquer outro valor (ou app não instalado) cai no menu de partilha genérico do Android

// Abrir qualquer URL no navegador/app padrão
Android.openUrl('https://...');
```

### Músicas locais do aparelho

```js
// Pede a permissão de leitura de músicas (chamar antes de getLocalTracks, se ainda não concedida)
Android.requestLocalMusicPermission();

// Lista as músicas guardadas no armazenamento do telemóvel
const localJson = Android.getLocalTracks();
const localTracks = JSON.parse(localJson);
// [{ id: "local_123", title, artist, duration, localUri, isLocal: true }, ...]
```

Se a permissão ainda não foi concedida, `getLocalTracks()` devolve uma
lista vazia (não lança erro) — o app deve tratar isso como "sem músicas
locais disponíveis" e, opcionalmente, oferecer um botão que chama
`requestLocalMusicPermission()` de novo.

Para tocar uma música local, usar `localUri` diretamente como `src` do
`<audio>` — não passa pelo `/stream` nem pelo `/audio`, já que não vem do
YouTube.

### Notificação nativa / MediaSession

Chamar sempre que a faixa ou o estado de reprodução mudar, para manter a
notificação do sistema e os controlos de hardware (fones, carro)
sincronizados com o player do WebView:

```js
Android.updateNowPlaying(
  track.title,
  track.artist,
  track.thumbnail,
  !audio.paused,           // isPlaying
  Math.floor(audio.currentTime * 1000),  // posição em ms
  Math.floor(audio.duration * 1000)      // duração em ms
);
```

Recomenda-se chamar isto:
- ao trocar de faixa (`play()`)
- ao pausar/retomar (`togglePlay()`)
- periodicamente durante `timeupdate` (ex: a cada 5s, não a cada frame,
  para não sobrecarregar a ponte JS↔nativo)

### Receber comandos vindos da notificação/fones

Quando o usuário usa os botões da notificação nativa ou os controlos de
um fone Bluetooth/fio, o Android envia um broadcast interno. Isto **não
é uma função Android.***, é um evento que o WebView deve escutar via um
canal que a app deve expor (ex: um pequeno polling ou um
`addJavascriptInterface` adicional que dispare `window.dispatchEvent`).
Na versão atual, o `PlaybackService` já recebe `onPlay`, `onPause`,
`onSkipToNext`, `onSkipToPrevious`, `onSeekTo` da `MediaSessionCompat` —
a app web deve garantir que essas ações cheguem ao `audio` HTML através
da mesma ponte (trabalho de integração ainda a fazer no
`AndroidBridge`/`MainActivity`, expondo um listener JS).

---

## 3. Resumo de fluxo — tocar uma música do YouTube

```js
async function play(track) {
  // 1. Pede a URL de stream (o servidor já extrai/valida por trás)
  const res = await fetch(`http://localhost:8080/stream?id=${track.id}`);
  const { streamUrl } = await res.json();

  // 2. Toca
  audio.src = streamUrl;
  await audio.play();

  // 3. Atualiza a notificação nativa
  Android.updateNowPlaying(track.title, track.artist, track.thumbnail, true, 0, track.duration * 1000);
}
```

## 4. Resumo de fluxo — tocar uma música local

```js
async function playLocal(track) {
  audio.src = track.localUri;  // já é file://..., não passa pelo servidor
  await audio.play();
  Android.updateNowPlaying(track.title, track.artist, '', true, 0, track.duration * 1000);
}
```

## 5. Resumo de fluxo — download para ouvir offline

```js
function downloadTrack(track) {
  Android.downloadTrack(track.id, track.title, 'normal');
  // o download corre em background; verificar mais tarde com:
  // Android.isDownloaded(track.id)
}

function playMaybeOffline(track) {
  if (Android.isDownloaded(track.id)) {
    audio.src = Android.downloadedFileUrl(track.id);
  } else {
    play(track); // fluxo normal via /stream
  }
}
```
```

Agora as alterações ao `index.html` para integrar tudo isto:

Aqui estão os blocos de JavaScript para adicionar/substituir no `index.html`, integrando preferências nativas, músicas locais, shorties reais e letras.

**Substituir o bloco de preferências** (procura `let settings = Object.assign` no `index.html`):

```js
// ═══════════════════════════════════════════════════════════
//  PREFERÊNCIAS: nativas (DataStore) quando disponível, senão localStorage
// ═══════════════════════════════════════════════════════════
const DEFAULTS = {
  theme:'system', lang:'pt', dominant:false, quality:'auto', crossfade:0, autoplay:true, normalize:false,
  gapless:true, wifiOnly:false, dlQuality:'normal', saveData:false, shareCast:true,
};

function loadNativePrefs() {
  if (isApp && typeof Android.getPreferences === 'function') {
    try {
      const native = JSON.parse(Android.getPreferences());
      return {
        theme: native.theme || DEFAULTS.theme,
        lang: native.lang || DEFAULTS.lang,
        quality: native.quality || DEFAULTS.quality,
        dlQuality: native.dlQuality || DEFAULTS.dlQuality,
        wifiOnly: native.wifiOnly === 'true',
        saveData: native.saveData === 'true',
      };
    } catch (e) { return {}; }
  }
  return {};
}

let settings = Object.assign({}, DEFAULTS, load('settings', {}), loadNativePrefs());

function setSetting(k, v) {
  settings[k] = v;
  save('settings', settings);
  // Espelha as preferências que importa manter entre reinstalações/limpezas de cache
  if (isApp && typeof Android.setPreference === 'function') {
    const nativeKeys = ['theme', 'lang', 'quality', 'dlQuality', 'wifiOnly', 'saveData'];
    if (nativeKeys.includes(k)) Android.setPreference(k, String(v));
  }
}
```

**Adicionar depois do bloco `resolveDark()`** (detecção de tema automático via sistema nativo):

```js
// Prioriza a deteção nativa do Android sobre a media query do WebView, quando disponível
function resolveDark() {
  if (settings.theme === 'dark') return true;
  if (settings.theme === 'light') return false;
  if (isApp && typeof Android.isSystemDarkMode === 'function') {
    try { return Android.isSystemDarkMode(); } catch (e) {}
  }
  return mq ? mq.matches : false;
}
```

**Adicionar nova secção — Músicas locais** (colar antes do bloco `// PLAYLISTS`):

```js
// ═══════════════════════════════════════════════════════════
//  MÚSICAS LOCAIS DO APARELHO
// ═══════════════════════════════════════════════════════════
async function loadLocalTracks() {
  if (!isApp || typeof Android.getLocalTracks !== 'function') return [];
  try {
    if (typeof Android.requestLocalMusicPermission === 'function') {
      Android.requestLocalMusicPermission();
    }
    const raw = Android.getLocalTracks();
    const parsed = JSON.parse(raw);
    return Array.isArray(parsed) ? parsed : [];
  } catch (e) { return []; }
}

function playLocal(track) {
  if (!isApp) { toast('Player só disponível no app Vibely'); return; }
  pauseShort();
  currentTrack = track;
  $('mini-title').textContent = track.title || '—'; $('mini-artist').textContent = track.artist || '—';
  $('np-title').textContent = track.title || '—'; $('np-artist').textContent = track.artist || '—';
  $('mini-img').src = ''; $('np-img').src = '';
  miniPlayer.classList.add('active');
  audio.pause(); audio.src = track.localUri; audio.load();
  audio.play().catch(() => toast('Não foi possível tocar este ficheiro local'));
  addRecent(track); renderRecents(); markPlaying();
  if (typeof Android.updateNowPlaying === 'function') {
    Android.updateNowPlaying(track.title || '', track.artist || '', '', true, 0, (track.duration || 0) * 1000);
  }
}
```

**Adicionar nova secção — Shorties reais e letras** (colar antes do bloco `// UTILS`):

```js
// ═══════════════════════════════════════════════════════════
//  SHORTIES: metadados via /shorts, stream sob demanda via /stream
// ═══════════════════════════════════════════════════════════
async function fetchShorts(query) {
  if (!isApp) return [];
  try {
    const res = await fetch(BASE + '/shorts?q=' + encodeURIComponent(query || 'trending'));
    const data = await res.json();
    return Array.isArray(data) ? data : [];
  } catch (e) { return []; }
}

// ═══════════════════════════════════════════════════════════
//  LETRAS
// ═══════════════════════════════════════════════════════════
const lyricsCache = {};
async function fetchLyrics(title, artist) {
  const key = title + '|' + artist;
  if (lyricsCache[key]) return lyricsCache[key];
  if (!isApp) return { found: false };
  try {
    const res = await fetch(BASE + '/lyrics?title=' + encodeURIComponent(title) + '&artist=' + encodeURIComponent(artist));
    const data = await res.json();
    lyricsCache[key] = data;
    return data;
  } catch (e) { return { found: false }; }
}

function openLyrics(track) {
  openSheet(`<div id="sheet-title">Letra</div><div id="sheet-content-lyrics" style="padding:0 20px 20px;white-space:pre-line;font-size:15px;line-height:1.6;color:var(--text)">${LOADER_HTML}</div>`);
  fetchLyrics(track.title, track.artist).then(data => {
    const el = document.querySelector('#sheet-content-lyrics');
    if (!el) return;
    if (data.found && (data.plainLyrics || data.syncedLyrics)) {
      const text = data.plainLyrics || data.syncedLyrics.replace(/\[\d{2}:\d{2}\.\d{2}\]/g, '');
      el.textContent = text;
    } else {
      el.innerHTML = '<div style="text-align:center;color:var(--text2);padding:30px 0">Letra não encontrada</div>';
    }
  });
}
```

**Adicionar a opção de letra no menu de ações da faixa** — dentro de `openTrackSheet`, no template de `html`, adicionar uma linha antes de `${sheetItem('artist', ...)}`:

```js
    ${sheetItem('lyrics', 'document-text-outline', 'Ver letra')}
```

E no handler de clique da mesma função, adicionar mais um `else if`:

```js
      else if (act === 'lyrics') { closeSheet(); setTimeout(() => openLyrics(track), 250); }
```

Isto integra: preferências que sobrevivem à limpeza de cache, deteção automática de tema/idioma do sistema, reprodução de músicas locais do aparelho, shorties reais via `/shorts`, e letras via `/lyrics` acessíveis pelo menu de cada faixa. O `VIBELY_SERVER_API.md` acima documenta todos os endpoints e funções da ponte nativa para referência futura.