const http = require('http');
const fs = require('fs');
const os = require('os');
const path = require('path');
const crypto = require('crypto');
const { execFile } = require('child_process');

const PORT = process.env.PORT || 10000;

// ─── Cache só de URLs (NUNCA de cookies) ─────────────────
// A chave inclui um hash do cookie, para um usuário não receber
// a URL gerada com a sessão de outro. O hash não permite recuperar o cookie.
const cache = new Map();
const CACHE_TTL = 90 * 60 * 1000;

setInterval(() => {
  const now = Date.now();
  for (const [k, v] of cache) if (now - v.time > CACHE_TTL) cache.delete(k);
}, 10 * 60 * 1000).unref();

// ─── Limite de pedidos por IP (protege o plano grátis contra abuso) ─
const hits = new Map(); // ip -> { count, resetAt }
const LIMIT = 40;            // pedidos
const WINDOW = 60 * 1000;    // por minuto

function rateLimited(ip) {
  const now = Date.now();
  let h = hits.get(ip);
  if (!h || now > h.resetAt) { h = { count: 0, resetAt: now + WINDOW }; hits.set(ip, h); }
  h.count++;
  return h.count > LIMIT;
}
setInterval(() => {
  const now = Date.now();
  for (const [ip, h] of hits) if (now > h.resetAt) hits.delete(ip);
}, WINDOW).unref();

const ATTEMPTS = [
  ['--extractor-args', 'youtube:player_client=android_vr'],
  ['--extractor-args', 'youtube:player_client=tv_embedded'],
  ['--extractor-args', 'youtube:player_client=ios'],
  ['--extractor-args', 'youtube:player_client=mweb'],
  []
];

function cacheKey(videoId, cookies) {
  const h = cookies ? crypto.createHash('sha256').update(cookies).digest('hex').slice(0, 12) : 'anon';
  return videoId + ':' + h;
}

// Escreve os cookies num arquivo temporário SÓ durante a execução e apaga logo depois,
// mesmo se o yt-dlp falhar.
async function withCookieFile(cookies, fn) {
  if (!cookies) return fn(null);
  const file = path.join(os.tmpdir(), 'ck_' + crypto.randomBytes(8).toString('hex') + '.txt');
  fs.writeFileSync(file, cookies, { mode: 0o600 });
  try {
    return await fn(file);
  } finally {
    try { fs.unlinkSync(file); } catch (_) {}
  }
}

function runYtDlp(videoId, extra, cookieFile) {
  return new Promise((resolve, reject) => {
    const args = [
      `https://www.youtube.com/watch?v=${videoId}`,
      '-f', 'bestaudio[ext=m4a]/bestaudio',
      '--no-playlist',
      '--no-warnings',
      '--socket-timeout', '15',
      '--no-cache-dir',   // o yt-dlp não guarda nada de sessão em disco
      '-J',
      ...extra
    ];
    if (cookieFile) args.push('--cookies', cookieFile);

    execFile('yt-dlp', args, { timeout: 40000, maxBuffer: 20 * 1024 * 1024 }, (err, stdout, stderr) => {
      if (err) {
        // Nunca devolve/loga nada que possa conter cookie: só o começo da mensagem de erro
        const msg = (stderr || err.message).toString().replace(/\s+/g, ' ').slice(0, 250);
        return reject(new Error(msg));
      }
      try { resolve(JSON.parse(stdout)); }
      catch (e) { reject(new Error('JSON inválido do yt-dlp')); }
    });
  });
}

async function extract(videoId, cookies) {
  const key = cacheKey(videoId, cookies);
  const hit = cache.get(key);
  if (hit && Date.now() - hit.time < CACHE_TTL) return hit.data;

  const errors = [];
  const data = await withCookieFile(cookies, async cookieFile => {
    for (const extra of ATTEMPTS) {
      try {
        const info = await runYtDlp(videoId, extra, cookieFile);
        const url = info.url || (info.requested_formats && info.requested_formats[0] && info.requested_formats[0].url);
        if (!url) { errors.push('sem url'); continue; }
        return {
          url,
          ext: info.ext || 'm4a',
          mime: (info.ext === 'webm') ? 'audio/webm' : 'audio/mp4',
          headers: info.http_headers || {},
          title: info.title || '',
          duration: info.duration || 0
        };
      } catch (e) {
        errors.push(e.message);
      }
    }
    const err = new Error('todas as tentativas falharam');
    err.details = errors;
    throw err;
  });

  cache.set(key, { data, time: Date.now() });
  return data;
}

function send(res, status, obj) {
  res.writeHead(status, { 'Content-Type': 'application/json; charset=utf-8', 'Access-Control-Allow-Origin': '*' });
  res.end(JSON.stringify(obj));
}

function readBody(req, limit = 200 * 1024) {
  return new Promise((resolve, reject) => {
    let size = 0;
    const chunks = [];
    req.on('data', c => {
      size += c.length;
      if (size > limit) { reject(new Error('corpo grande demais')); req.destroy(); return; }
      chunks.push(c);
    });
    req.on('end', () => resolve(Buffer.concat(chunks).toString('utf8')));
    req.on('error', reject);
  });
}

http.createServer(async (req, res) => {
  const u = new URL(req.url, `http://${req.headers.host}`);
  const ip = (req.headers['x-forwarded-for'] || req.socket.remoteAddress || '').toString().split(',')[0].trim();

  if (req.method === 'OPTIONS') {
    res.writeHead(204, {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Headers': 'Content-Type',
      'Access-Control-Allow-Methods': 'GET, POST, OPTIONS'
    });
    return res.end();
  }

  if (u.pathname === '/') return send(res, 200, { ok: true, service: 'vibely-extractor' });
  if (u.pathname === '/health') return send(res, 200, { ok: true });

  if (rateLimited(ip)) return send(res, 429, { error: 'muitos pedidos, tente em 1 minuto' });

  // POST /extract  { "id": "...", "cookies": "formato Netscape (opcional)" }
  // Os cookies chegam por pedido, vivem só num arquivo temporário durante a extração
  // e são apagados em seguida. Nada é guardado, nada é registrado em log.
  if (u.pathname === '/extract') {
    try {
      let id = u.searchParams.get('id');
      let cookies = '';

      if (req.method === 'POST') {
        const raw = await readBody(req);
        const body = raw ? JSON.parse(raw) : {};
        id = body.id || id;
        cookies = typeof body.cookies === 'string' ? body.cookies : '';
      }

      if (!id || !/^[\w-]{6,20}$/.test(id)) return send(res, 400, { error: 'id inválido' });

      const data = await extract(id, cookies);
      return send(res, 200, data);
    } catch (e) {
      return send(res, 502, { error: e.message, details: e.details || [] });
    }
  }

  send(res, 404, { error: 'não encontrado' });
}).listen(PORT, () => console.log('vibely-extractor na porta ' + PORT));