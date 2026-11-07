# BrowseIt / Looply — Android nativo Kotlin

Este ZIP contém a migração Android para Kotlin nativo, sem Flutter Engine ou plugin Flutter em runtime.

## Estrutura

- `android/` — projeto Android Gradle; o módulo `app` usa Kotlin, Android Views/XML, Android WebView e Material Components.
- `android/app/src/main/kotlin/com/looply/browser/app/` — Activity principal, ecrãs, estado local, sincronização, bloqueador e UI nativa.
- `android/app/src/main/kotlin/com/looply/browser/app/icons/phosphor/` — ícones Phosphor embutidos como constantes Kotlin. Os 110 SVGs originais (55 Regular + 55 Fill) foram comparados com as fontes preservadas e correspondem ao conteúdo original; existem ainda constantes `user` e `share` em ambos os estilos para uso da interface nativa.
- `android/app/src/main/res/` — recursos Android, incluindo os mipmaps originais.
- `android/app/src/main/assets/` — recursos carregados em runtime pela aplicação nativa.
- `android/app/browseit-release.keystore` — keystore original preservado byte a byte.
- `cloudflare/worker/` — código original do Worker Cloudflare.
- `migration_reference/lib/` e `migration_reference/pubspec.yaml` — Dart original mantido apenas como referência de migração; não é compilado nem incluído no APK.
- `migration_reference/source_assets/` — cópia de referência dos assets originais que não são usados pelo runtime Android. Não são empacotados no APK.
- `migration_reference/legacy_android/` — componente Android antigo que dependia de Flutter, preservado fora do source set compilado.

## Identidade e compatibilidade de dados

O `applicationId` e o `namespace` continuam `com.looply.browser.app`. O nome apresentado no Android continua `BrowseIt`, tal como no Manifest original e no `MaterialApp.title` do Flutter. A versão continua `1.0.0` / `versionCode 1`. O armazenamento local usa o ficheiro `FlutterSharedPreferences` e as chaves existentes `flutter.looply_*` para reutilizar os dados compatíveis já gravados pelo Flutter.

O keystore e todos os mipmaps originais foram preservados sem alteração. As palavras-passe/segredos de assinatura não estavam incluídos no ZIP original, pelo que não foram inventados nem embutidos neste projeto.

## Configuração

Antes de ativar login Google, define `BROWSEIT_GOOGLE_WEB_CLIENT_ID` com o OAuth Web Client ID correto. Para sincronização remota, define `BROWSEIT_WORKER_URL` com o URL HTTPS do Worker. Ambos podem ser fornecidos como propriedades Gradle ou variáveis de ambiente.

Para assinar uma build Release com o keystore preservado, define estas variáveis no ambiente de build:

- `BROWSEIT_KEYSTORE_PATH`
- `BROWSEIT_STORE_PASSWORD`
- `BROWSEIT_KEY_PASSWORD`
- `BROWSEIT_KEY_ALIAS`

O alias predefinido no Gradle é `browseit`; confirma o alias real do keystore antes de assinar. Sem as credenciais originais, a configuração de assinatura Release não pode ser validada.

## Build

Requer Android SDK com `compileSdk 36`, Java 17 e acesso às dependências Maven. Na pasta `android/`:

```bash
./gradlew clean assembleDebug
```

O script `gradlew` incluído descarrega Gradle 8.13 quando necessário. O projeto foi configurado com AGP 8.13.2 e Kotlin 2.3.20, removendo a integração Flutter do Gradle e do Manifest.

## Estado de validação e limitações conhecidas

- Todos os 17 XMLs atualmente existentes foram analisados sintaticamente sem erros.
- Os 110 SVGs Phosphor originais foram comparados com as constantes Kotlin correspondentes: 110/110 correspondências.
- Foram confirmados o `applicationId`, a preservação byte a byte do keystore e a preservação byte a byte dos 21 recursos mipmap originais.
- Não foi possível executar `./gradlew clean assembleDebug` neste ambiente: não existe Android SDK/`ANDROID_HOME` nem instalação local de Gradle, e o ambiente não conseguiu descarregar as ferramentas. Portanto, **a compilação ainda não está certificada**.
- Não foi possível executar a aplicação num emulador ou dispositivo para recolher screenshots. Assim, **não é correto declarar fidelidade pixel-perfect comprovada**. A interface foi portada para componentes Android nativos, mas a equivalência visual, as curvas de animação e todos os estados de cada ecrã ainda precisam de validação lado a lado num dispositivo.
- A camada nativa atual tem o conteúdo principal e vários fluxos do navegador, autenticação Google, histórico, favoritos, downloads, definições e temas. Algumas áreas complexas do Flutter foram reduzidas na implementação nativa, e as traduções completas de 12 idiomas ainda não foram portadas; a interface nativa está maioritariamente em português.
- A aparência avançada de páginas Web usa as capacidades do Android WebView, que não são idênticas em todos os detalhes às opções do `flutter_inappwebview`.
- O armazenamento local compatível é preservado, mas a sessão de servidor guardada pelo `flutter_secure_storage` não foi migrada automaticamente para a nova chave Android Keystore. Pode ser necessário voltar a autenticar a conta para sincronização Cloudflare.

Este projeto é uma base de migração Android nativa real, não uma build já certificada como pixel-perfect. As limitações acima são explícitas para evitar afirmar testes ou equivalências que não foram executados.
