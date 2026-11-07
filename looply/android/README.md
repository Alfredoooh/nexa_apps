# Android module

Projeto Android nativo Kotlin/XML. Abre esta pasta no Android Studio ou executa `./gradlew assembleDebug` num ambiente com Android SDK 36 e Java 17.

O Gradle está fixado em 8.13, AGP em 8.13.2 e Kotlin em 2.3.20. O script `gradlew` deste pacote é um bootstrap shell que obtém a distribuição Gradle 8.13 oficial quando não está em cache.

Configura `BROWSEIT_GOOGLE_WEB_CLIENT_ID` e `BROWSEIT_WORKER_URL` em `gradle.properties` ou no ambiente de CI. Para assinatura release, configura também `BROWSEIT_KEYSTORE_PATH`, `BROWSEIT_STORE_PASSWORD`, `BROWSEIT_KEY_PASSWORD` e `BROWSEIT_KEY_ALIAS`.
