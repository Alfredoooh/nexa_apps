# Looply — Flutter

Projeto inicial de uma plataforma de jogos sociais chamada **Looply**, desenvolvido em Flutter/Dart. A interface está em português e usa um tema escuro com cores planas inspiradas no ícone fornecido.

## Incluído

- Página inicial com destaque, categorias e jogos de demonstração.
- Pesquisa e filtragem por categoria.
- Página de detalhes de cada jogo.
- Ecrãs iniciais de Explorar, Criar e Perfil.
- Ícone Looply preparado para Android, iOS e Web.
- Estrutura de plataforma Android, iOS e Web.

## Executar

É necessário ter o Flutter SDK instalado. Na raiz do projeto, execute:

```bash
flutter pub get
flutter run
```

Para compilar um APK de teste:

```bash
flutter build apk --debug
```

O APK, quando compilado, fica em `build/app/outputs/flutter-apk/app-debug.apk`.

## Nota sobre o estado do projeto

Este ZIP contém a base visual e navegável. Os jogos apresentados são exemplos de interface, não jogos online funcionais. Autenticação, editor 3D, matchmaking, multiplayer, catálogo remoto, armazenamento e serviços de segurança ainda têm de ser implementados. A compilação não foi executada neste ambiente porque o Flutter SDK não está instalado aqui.

## Ícone

`assets/images/looply_original_icon.png` preserva a imagem enviada. `assets/images/looply_icon.png` e os ícones de plataforma são versões preparadas a partir do mesmo desenho, removendo apenas o espaço preto vazio à volta para o símbolo ficar legível no launcher.
