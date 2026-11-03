# BrowseIt Auth Worker (Cloudflare Workers + D1)

Este Worker não usa Firebase, Supabase nem outro fornecedor de autenticação. O Google apenas emite o ID token; o Worker verifica o token e cria uma sessão BrowseIt própria. Os perfis, sessões e backups ficam guardados na base D1.

## Antes de publicar: criar o OAuth Client ID Web

O Client ID Android fornecido para `com.looply.browser.app` identifica a instalação através do package name + SHA-1. **Não deve ser usado em `GetGoogleIdOption.setServerClientId()` nem como `aud` do Worker.** A documentação Android/Google exige o Client ID OAuth do tipo **Web application** como `serverClientId`/audience do ID token enviado ao backend.

No Google Cloud Console, no mesmo projeto `browseit-513614`, cria um OAuth Client ID do tipo **Web application**. Não é necessário criar um client secret para este fluxo nativo que apenas pede ID tokens. Copia o novo Client ID (terminado em `apps.googleusercontent.com`) para `GOOGLE_WEB_CLIENT_ID` no `wrangler.jsonc` e para `BROWSEIT_GOOGLE_WEB_CLIENT_ID` em `android/gradle.properties`.

Mantém também o OAuth Client Android registado com:
- Package name: `com.looply.browser.app`
- SHA-1: certificado que assina a build instalada (debug, release ou Play App Signing, conforme a build testada).

O ficheiro JSON enviado contém um registo OAuth do tipo `installed`; não contém um Client ID Web nem `client_secret`. Não se deve inserir um client secret no APK. O `serverClientId` é o Client ID Web, conforme a documentação do Credential Manager.

## Criar e publicar a base D1

Na pasta `cloudflare/worker`:

```bash
npm install --save-dev wrangler
npx wrangler login
npx wrangler d1 create browseit-users
```

Copia o `database_id` devolvido pelo comando para `d1_databases[0].database_id` em `wrangler.jsonc`. Depois executa:

```bash
npx wrangler d1 migrations apply browseit-users --remote
npx wrangler deploy
```

O endereço ficará parecido com `https://browseit-auth.<subdominio>.workers.dev`. Testa `GET /health`.

## Ligar o Android/Flutter ao Worker

Compila o Flutter com o endereço real do Worker:

```bash
flutter build apk --release --split-per-abi \
  --dart-define=BROWSEIT_WORKER_URL=https://browseit-auth.<subdominio>.workers.dev
```

O login Google também precisa de `BROWSEIT_GOOGLE_WEB_CLIENT_ID` no `android/gradle.properties`.

Para assinar uma build release com o keystore fornecido, configura as variáveis de ambiente/Gradle properties `BROWSEIT_KEYSTORE_PATH`, `BROWSEIT_STORE_PASSWORD`, `BROWSEIT_KEY_PASSWORD` e `BROWSEIT_KEY_ALIAS=browseit`. O keystore e as passwords não são copiados para este projeto nem para o ZIP. Sem essas variáveis, a configuração atual usa assinatura debug e não deve ser usada para publicar uma release.

As permissões de câmara, microfone e localização são pedidas apenas quando um site seguro solicita a função correspondente; não são concedidas automaticamente. O picker Android trata a seleção de ficheiros sem pedir acesso amplo ao armazenamento. O app não pede notificações, contactos, SMS ou Bluetooth sem uma função concreta que os exija.

## Endpoints

- `POST /api/v1/auth/challenge`: emite nonce de utilização única (5 minutos).
- `POST /api/v1/auth/google`: valida assinatura RS256, `aud`, `iss`, `exp`, `iat`, `sub`, email verificado e nonce; cria/atualiza o utilizador e emite sessão BrowseIt (30 dias).
- `GET /api/v1/me`: perfil da sessão.
- `POST /api/v1/auth/logout`: revoga a sessão atual.
- `GET /api/v1/me/data/:namespace`: lê dados JSON do utilizador.
- `PUT /api/v1/me/data/:namespace`: guarda/substitui dados JSON do utilizador.
- `DELETE /api/v1/me/data/:namespace`: elimina um namespace.
- `GET /api/v1/me/export`: exporta o perfil e todos os namespaces.
- `POST /api/v1/me/import`: importa vários namespaces.
- `DELETE /api/v1/me`: elimina conta e dados associados.

O app envia automaticamente um snapshot `app-backup` (o mesmo JSON estruturado usado pelo recurso local de exportação) após alterações nos dados guardados, com debounce de 2 segundos, após login e quando a aplicação vai para segundo plano/retoma, desde que o Worker esteja configurado. O token de sessão fica no armazenamento seguro Android do plugin `flutter_secure_storage`; o Google ID token não é persistido.

## Notas de segurança

- Nunca coloques o ficheiro `.keystore`, passwords, client secrets ou tokens no repositório/ZIP.
- O Worker só guarda o hash SHA-256 do token de sessão; o token original é mostrado uma única vez ao app.
- Os nonces são guardados como hash D1 e consumidos uma única vez.
- O ID token só é aceite quando o `aud` coincide com o Client ID Web configurado.
- O backup é armazenado como JSON até 5 MB por namespace. Considera adicionar política de retenção/quotas para uma instalação pública em escala.
