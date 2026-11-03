# BrowseIt

Navegador Android desenvolvido com Flutter para a interface e Kotlin para integrações nativas do Android, incluindo a plataforma WebView nativa usada pelo Orbit Browser.

## Requisitos

- Flutter SDK compatível com o projeto (Dart >= 3.8.1).
- Android SDK e JDK 17.
- Para login Google: um OAuth Client ID do tipo **Web application**.
- Para autenticação e backup remoto: uma conta Cloudflare com Workers e D1.

## Executar localmente

```bash
flutter pub get
flutter run
```

## Identidade Android

- Nome apresentado: `BrowseIt`
- `applicationId`: `com.looply.browser.app`
- `namespace`: `com.looply.browser.app`

A alteração de `applicationId` faz o Android e a Google Play tratarem o pacote como uma aplicação distinta. Se uma versão anterior já foi publicada com outro application ID, este pacote não atualiza aquela ficha da Play Store.

## Login Google nativo

O app usa Android Credential Manager (`GetGoogleIdOption`) através de Kotlin. **O Client ID Android não pode ser usado como `serverClientId`: é obrigatório criar um OAuth Client ID do tipo Web application.** O Credential Manager usa esse Client ID como audience do ID token enviado ao backend.

1. No Google Cloud Console, no projeto `browseit-513614`, crie um OAuth Client ID do tipo **Web application**.
2. Defina o valor em `android/gradle.properties`:

```properties
BROWSEIT_GOOGLE_WEB_CLIENT_ID=SEU_WEB_CLIENT_ID.apps.googleusercontent.com
```

3. Defina o mesmo valor em `cloudflare/worker/wrangler.jsonc`, em `vars.GOOGLE_WEB_CLIENT_ID`.
4. Confirme que o OAuth Client Android está registado com o package `com.looply.browser.app` e com a SHA-1 do certificado que assina a versão instalada.

O JSON OAuth fornecido com o projeto é do tipo `installed` e não contém um Client ID Web. Não foi copiado para o projeto. Não coloque client secrets no APK.

Sem o Web Client ID, a opção Google apresenta um erro de configuração claro e não conclui o login. O login por email também não está implementado; exige um endpoint de autenticação próprio.

## Cloudflare Worker e D1

O código do Worker está em `cloudflare/worker/` e inclui:

- Validação de ID tokens Google com as chaves públicas (JWKS), assinatura RS256, `aud`, `iss`, `exp`, `iat`, `sub`, email verificado e nonce de utilização única.
- Sessões BrowseIt próprias, com apenas o hash do token guardado na D1.
- Perfil do utilizador e namespaces JSON para dados da aplicação.
- Endpoints para ler, gravar, importar, exportar e apagar os dados.
- Migração SQL inicial para as tabelas de utilizadores, sessões, dados e desafios de autenticação.

Para publicar, siga `cloudflare/worker/README.md`. Antes do deploy, crie a D1, substitua `database_id` no `wrangler.jsonc` e configure o Web Client ID. Depois compile o app com o endereço real do Worker:

```bash
flutter build apk --release \
  --split-per-abi \
  --dart-define=BROWSEIT_WORKER_URL=https://SEU-WORKER.workers.dev
```

Sem `BROWSEIT_WORKER_URL`, o Google pode devolver um perfil local após configurar o Web Client ID, mas a sessão remota, validação do Worker e backup Cloudflare ficam desativados.

O app agenda a cópia do backup JSON da aplicação para o namespace `app-backup` quando os dados locais monitorizados mudam, após login e ao pausar/retomar a aplicação, desde que o Worker esteja configurado. A sincronização é de envio; a restauração do backup remoto para um dispositivo novo deve ser iniciada através dos endpoints de importação/exportação do Worker e ainda não é automática.

## Assinatura Android

O keystore não é incluído neste ZIP por ser uma credencial privada. Configure estas propriedades/variáveis antes de assinar uma release:

- `BROWSEIT_KEYSTORE_PATH`
- `BROWSEIT_STORE_PASSWORD`
- `BROWSEIT_KEY_PASSWORD`
- `BROWSEIT_KEY_ALIAS=browseit`

A configuração de release usa a assinatura debug apenas como fallback de desenvolvimento quando não existe caminho para o keystore. Uma build assim não deve ser publicada. Para o OAuth Android funcionar na versão release, a SHA-1 registada no Google Cloud deve corresponder ao certificado que efetivamente assina o APK/AAB instalado.

## Permissões web

Câmara, microfone e localização são declarados no manifest e pedidos em tempo de execução apenas quando um site seguro solicita a função. O app valida a origem e exige consentimento do utilizador. A seleção de ficheiros usa o picker do Android, sem pedir acesso amplo ao armazenamento. Não são pedidas permissões sem uma função implementada (por exemplo, contactos ou SMS).

## Observação sobre compilação

O código foi preparado e passou por verificações estáticas descritas na resposta de entrega. A compilação Flutter/Android não foi executada neste ambiente, pelo que deve ser validada com `flutter build apk` no ambiente Android/CI do projeto.
