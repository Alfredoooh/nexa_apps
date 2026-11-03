const GOOGLE_CERTS_URL = 'https://www.googleapis.com/oauth2/v3/certs';
const SESSION_SECONDS = 60 * 60 * 24 * 30;
const CHALLENGE_SECONDS = 5 * 60;
const MAX_JSON_BYTES = 5 * 1024 * 1024;

let cachedGoogleKeys = null;
let cachedGoogleKeysUntil = 0;

export default {
  async fetch(request, env) {
    const cors = corsHeaders(request, env);
    if (request.method === 'OPTIONS') {
      return new Response(null, { status: 204, headers: cors });
    }

    try {
      const url = new URL(request.url);
      const path = url.pathname.replace(/\/+$/, '') || '/';

      if (request.method === 'GET' && path === '/health') {
        return json({ ok: true, service: 'BrowseIt Auth Worker' }, 200, cors);
      }

      if (request.method === 'POST' && path === '/api/v1/auth/challenge') {
        const nonce = randomToken(32);
        const now = Math.floor(Date.now() / 1000);
        await env.DB.prepare('DELETE FROM auth_challenges WHERE expires_at <= ?').bind(now).run();
        await env.DB.prepare(
          'INSERT INTO auth_challenges (nonce_hash, expires_at, created_at) VALUES (?, ?, ?)',
        ).bind(await sha256Hex(nonce), now + CHALLENGE_SECONDS, now).run();
        return json({ nonce, expiresIn: CHALLENGE_SECONDS }, 200, cors);
      }

      if (request.method === 'POST' && path === '/api/v1/auth/google') {
        const body = await readJson(request);
        const idToken = stringValue(body.idToken);
        const nonce = stringValue(body.nonce);
        if (!idToken || !nonce) return json({ error: 'idToken e nonce são obrigatórios.' }, 400, cors);

        const claims = await verifyGoogleIdToken(idToken, env.GOOGLE_WEB_CLIENT_ID);
        if (claims.nonce !== nonce) return json({ error: 'O nonce do ID token não corresponde ao pedido.' }, 401, cors);

        const nonceHash = await sha256Hex(nonce);
        const consumedChallenge = await env.DB.prepare(
          'DELETE FROM auth_challenges WHERE nonce_hash = ? AND expires_at > ?',
        ).bind(nonceHash, Math.floor(Date.now() / 1000)).run();
        if ((consumedChallenge.meta?.changes ?? 0) !== 1) {
          return json({ error: 'Desafio de autenticação expirado ou já utilizado. Tenta novamente.' }, 401, cors);
        }

        const subject = stringValue(claims.sub);
        const email = stringValue(claims.email);
        if (!subject || !email || claims.email_verified !== true) {
          return json({ error: 'A conta Google não possui um endereço de email verificado.' }, 403, cors);
        }

        const now = Math.floor(Date.now() / 1000);
        await env.DB.prepare(`
          INSERT INTO users (google_sub, email, display_name, picture_url, locale, created_at, updated_at)
          VALUES (?, ?, ?, ?, ?, ?, ?)
          ON CONFLICT(google_sub) DO UPDATE SET
            email = excluded.email,
            display_name = excluded.display_name,
            picture_url = excluded.picture_url,
            locale = excluded.locale,
            updated_at = excluded.updated_at
        `).bind(
          subject,
          email,
          stringValue(claims.name),
          stringValue(claims.picture),
          stringValue(claims.locale),
          now,
          now,
        ).run();

        const sessionToken = randomToken(48);
        const sessionHash = await sha256Hex(sessionToken);
        await env.DB.prepare(
          'INSERT INTO sessions (token_hash, google_sub, created_at, expires_at) VALUES (?, ?, ?, ?)',
        ).bind(sessionHash, subject, now, now + SESSION_SECONDS).run();

        return json({
          sessionToken,
          expiresIn: SESSION_SECONDS,
          user: {
            id: subject,
            email,
            displayName: stringValue(claims.name),
            photoUrl: stringValue(claims.picture),
            locale: stringValue(claims.locale),
          },
        }, 200, cors);
      }

      if (request.method === 'GET' && path === '/api/v1/me') {
        const auth = await requireUser(request, env);
        if (!auth.ok) return json({ error: auth.error }, 401, cors);
        return json({ user: publicUser(auth.user) }, 200, cors);
      }

      if (request.method === 'POST' && path === '/api/v1/auth/logout') {
        const token = bearerToken(request);
        if (token) await env.DB.prepare('DELETE FROM sessions WHERE token_hash = ?').bind(await sha256Hex(token)).run();
        return json({ ok: true }, 200, cors);
      }

      if (request.method === 'GET' && path === '/api/v1/me/export') {
        const auth = await requireUser(request, env);
        if (!auth.ok) return json({ error: auth.error }, 401, cors);
        const rows = await env.DB.prepare(
          'SELECT namespace, data_json, updated_at FROM user_data WHERE google_sub = ? ORDER BY namespace',
        ).bind(auth.user.google_sub).all();
        const data = {};
        for (const row of rows.results || []) {
          try { data[row.namespace] = JSON.parse(row.data_json); } catch { data[row.namespace] = null; }
        }
        return json({
          exportedAt: new Date().toISOString(),
          user: publicUser(auth.user),
          data,
        }, 200, cors);
      }

      if (request.method === 'POST' && path === '/api/v1/me/import') {
        const auth = await requireUser(request, env);
        if (!auth.ok) return json({ error: auth.error }, 401, cors);
        const body = await readJson(request);
        const data = body.data;
        if (!data || typeof data !== 'object' || Array.isArray(data)) {
          return json({ error: 'O campo data deve ser um objeto JSON.' }, 400, cors);
        }
        const now = Math.floor(Date.now() / 1000);
        const statements = [];
        for (const [namespace, value] of Object.entries(data)) {
          if (!validNamespace(namespace)) continue;
          statements.push(env.DB.prepare(`
            INSERT INTO user_data (google_sub, namespace, data_json, updated_at)
            VALUES (?, ?, ?, ?)
            ON CONFLICT(google_sub, namespace) DO UPDATE SET
              data_json = excluded.data_json,
              updated_at = excluded.updated_at
          `).bind(auth.user.google_sub, namespace, JSON.stringify(value), now));
        }
        if (statements.length) await env.DB.batch(statements);
        return json({ ok: true, namespacesStored: statements.length }, 200, cors);
      }

      const dataMatch = path.match(/^\/api\/v1\/me\/data\/([A-Za-z0-9._-]{1,64})$/);
      if (dataMatch) {
        const auth = await requireUser(request, env);
        if (!auth.ok) return json({ error: auth.error }, 401, cors);
        const namespace = dataMatch[1];

        if (request.method === 'GET') {
          const row = await env.DB.prepare(
            'SELECT data_json, updated_at FROM user_data WHERE google_sub = ? AND namespace = ?',
          ).bind(auth.user.google_sub, namespace).first();
          if (!row) return json({ namespace, data: null, updatedAt: null }, 200, cors);
          let data;
          try { data = JSON.parse(row.data_json); } catch { data = null; }
          return json({ namespace, data, updatedAt: row.updated_at }, 200, cors);
        }

        if (request.method === 'PUT') {
          const body = await readJson(request);
          if (!Object.prototype.hasOwnProperty.call(body, 'data')) {
            return json({ error: 'O campo data é obrigatório.' }, 400, cors);
          }
          const serialized = JSON.stringify(body.data);
          if (serialized.length > MAX_JSON_BYTES) return json({ error: 'O conjunto de dados excede o limite de 5 MB.' }, 413, cors);
          const now = Math.floor(Date.now() / 1000);
          await env.DB.prepare(`
            INSERT INTO user_data (google_sub, namespace, data_json, updated_at)
            VALUES (?, ?, ?, ?)
            ON CONFLICT(google_sub, namespace) DO UPDATE SET
              data_json = excluded.data_json,
              updated_at = excluded.updated_at
          `).bind(auth.user.google_sub, namespace, serialized, now).run();
          return json({ ok: true, namespace, updatedAt: now }, 200, cors);
        }

        if (request.method === 'DELETE') {
          await env.DB.prepare('DELETE FROM user_data WHERE google_sub = ? AND namespace = ?')
            .bind(auth.user.google_sub, namespace).run();
          return json({ ok: true }, 200, cors);
        }
      }

      if (request.method === 'DELETE' && path === '/api/v1/me') {
        const auth = await requireUser(request, env);
        if (!auth.ok) return json({ error: auth.error }, 401, cors);
        await env.DB.prepare('DELETE FROM users WHERE google_sub = ?').bind(auth.user.google_sub).run();
        return json({ ok: true, deleted: true }, 200, cors);
      }

      return json({ error: 'Endpoint não encontrado.' }, 404, cors);
    } catch (error) {
      const message = error instanceof SyntaxError ? 'JSON inválido.' : (error?.message || 'Erro interno.');
      const status = error?.statusCode || 500;
      return json({ error: message }, status, cors);
    }
  },
};

async function verifyGoogleIdToken(token, expectedAudience) {
  if (!expectedAudience || expectedAudience.includes('PASTE_WEB_CLIENT_ID_HERE')) {
    throw Object.assign(new Error('Configure GOOGLE_WEB_CLIENT_ID no Worker.'), { statusCode: 503 });
  }
  const parts = token.split('.');
  if (parts.length !== 3) throw Object.assign(new Error('ID token malformado.'), { statusCode: 401 });

  const header = decodeJson(parts[0]);
  const claims = decodeJson(parts[1]);
  if (header.alg !== 'RS256' || !header.kid) {
    throw Object.assign(new Error('Algoritmo ou chave do ID token não aceite.'), { statusCode: 401 });
  }

  let jwk = await getGoogleKey(header.kid);
  if (!jwk) {
    await refreshGoogleKeys();
    jwk = cachedGoogleKeys.find(key => key.kid === header.kid && key.kty === 'RSA' && (!key.use || key.use === 'sig')) || null;
  }
  if (!jwk) throw Object.assign(new Error('A chave pública do Google não foi encontrada.'), { statusCode: 401 });
  const publicKey = await crypto.subtle.importKey(
    'jwk',
    jwk,
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['verify'],
  );
  const validSignature = await crypto.subtle.verify(
    'RSASSA-PKCS1-v1_5',
    publicKey,
    base64UrlToBytes(parts[2]),
    new TextEncoder().encode(`${parts[0]}.${parts[1]}`),
  );
  if (!validSignature) throw Object.assign(new Error('Assinatura do ID token inválida.'), { statusCode: 401 });

  const now = Math.floor(Date.now() / 1000);
  const audienceValid = claims.aud === expectedAudience ||
    (Array.isArray(claims.aud) && claims.aud.includes(expectedAudience));
  if (!audienceValid) throw Object.assign(new Error('Audience do ID token inválida.'), { statusCode: 401 });
  if (claims.azp && claims.azp !== expectedAudience) {
    throw Object.assign(new Error('Authorized party do ID token inválida.'), { statusCode: 401 });
  }
  if (claims.iss !== 'https://accounts.google.com' && claims.iss !== 'accounts.google.com') {
    throw Object.assign(new Error('Issuer do ID token inválido.'), { statusCode: 401 });
  }
  if (typeof claims.exp !== 'number' || claims.exp <= now) {
    throw Object.assign(new Error('ID token expirado.'), { statusCode: 401 });
  }
  if (typeof claims.iat !== 'number' || claims.iat > now + 120 || claims.iat < now - 3600) {
    throw Object.assign(new Error('Data de emissão do ID token inválida.'), { statusCode: 401 });
  }
  if (typeof claims.sub !== 'string' || claims.sub.length < 5) {
    throw Object.assign(new Error('Identificador Google ausente.'), { statusCode: 401 });
  }
  return claims;
}

async function getGoogleKey(kid) {
  if (!cachedGoogleKeys || cachedGoogleKeysUntil <= Date.now()) await refreshGoogleKeys();
  return cachedGoogleKeys.find(key => key.kid === kid && key.kty === 'RSA' && (!key.use || key.use === 'sig')) || null;
}

async function refreshGoogleKeys() {
  const response = await fetch(GOOGLE_CERTS_URL, { cf: { cacheTtl: 1800, cacheEverything: true } });
  if (!response.ok) throw Object.assign(new Error('Não foi possível obter as chaves públicas do Google.'), { statusCode: 503 });
  const body = await response.json();
  cachedGoogleKeys = Array.isArray(body.keys) ? body.keys : [];
  const cacheControl = response.headers.get('Cache-Control') || '';
  const maxAge = Number(cacheControl.match(/max-age=(\d+)/i)?.[1] || 1800);
  cachedGoogleKeysUntil = Date.now() + Math.max(60, Math.min(maxAge, 86400)) * 1000;
}

async function requireUser(request, env) {
  const token = bearerToken(request);
  if (!token) return { ok: false, error: 'Sessão em falta.' };
  const tokenHash = await sha256Hex(token);
  const now = Math.floor(Date.now() / 1000);
  const row = await env.DB.prepare(`
    SELECT users.google_sub, users.email, users.display_name, users.picture_url, users.locale,
           sessions.expires_at
    FROM sessions
    INNER JOIN users ON users.google_sub = sessions.google_sub
    WHERE sessions.token_hash = ? AND sessions.expires_at > ?
  `).bind(tokenHash, now).first();
  if (!row) {
    await env.DB.prepare('DELETE FROM sessions WHERE token_hash = ?').bind(tokenHash).run();
    return { ok: false, error: 'Sessão inválida ou expirada.' };
  }
  return { ok: true, user: row };
}

function publicUser(user) {
  return {
    id: user.google_sub,
    email: user.email,
    displayName: user.display_name,
    photoUrl: user.picture_url,
    locale: user.locale,
  };
}

async function readJson(request) {
  const declaredLength = Number(request.headers.get('Content-Length') || 0);
  if (declaredLength > MAX_JSON_BYTES) throw Object.assign(new Error('Pedido excede o limite de 5 MB.'), { statusCode: 413 });
  const text = await request.text();
  if (text.length > MAX_JSON_BYTES) throw Object.assign(new Error('Pedido excede o limite de 5 MB.'), { statusCode: 413 });
  const body = JSON.parse(text || '{}');
  if (!body || typeof body !== 'object' || Array.isArray(body)) throw Object.assign(new Error('O corpo deve ser um objeto JSON.'), { statusCode: 400 });
  return body;
}

function corsHeaders(request, env) {
  const origin = request.headers.get('Origin');
  const configured = env.ALLOWED_ORIGIN || '*';
  const allowOrigin = configured === '*' ? '*' : (origin === configured ? origin : 'null');
  return {
    'Access-Control-Allow-Origin': allowOrigin,
    'Access-Control-Allow-Methods': 'GET,POST,PUT,DELETE,OPTIONS',
    'Access-Control-Allow-Headers': 'Authorization,Content-Type',
    'Access-Control-Max-Age': '86400',
    'Vary': 'Origin',
    'Cache-Control': 'no-store',
    'X-Content-Type-Options': 'nosniff',
  };
}

function json(value, status, headers) {
  return new Response(JSON.stringify(value), {
    status,
    headers: { ...headers, 'Content-Type': 'application/json; charset=utf-8' },
  });
}

function stringValue(value) {
  return typeof value === 'string' && value.trim() ? value.trim() : null;
}

function validNamespace(value) {
  return /^[A-Za-z0-9._-]{1,64}$/.test(value);
}

function bearerToken(request) {
  const header = request.headers.get('Authorization') || '';
  const match = header.match(/^Bearer\s+(.+)$/i);
  return match ? match[1].trim() : null;
}

function randomToken(byteLength) {
  const bytes = new Uint8Array(byteLength);
  crypto.getRandomValues(bytes);
  return bytesToBase64Url(bytes);
}

async function sha256Hex(value) {
  const bytes = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(value));
  return [...new Uint8Array(bytes)].map(byte => byte.toString(16).padStart(2, '0')).join('');
}

function decodeJson(value) {
  try {
    return JSON.parse(new TextDecoder().decode(base64UrlToBytes(value)));
  } catch {
    throw Object.assign(new Error('Conteúdo JWT inválido.'), { statusCode: 401 });
  }
}

function base64UrlToBytes(value) {
  const base64 = value.replace(/-/g, '+').replace(/_/g, '/') + '='.repeat((4 - value.length % 4) % 4);
  const binary = atob(base64);
  const bytes = new Uint8Array(binary.length);
  for (let index = 0; index < binary.length; index++) bytes[index] = binary.charCodeAt(index);
  return bytes;
}

function bytesToBase64Url(bytes) {
  let binary = '';
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/g, '');
}
