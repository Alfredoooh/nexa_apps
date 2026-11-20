# BrowseIt — catálogo estático no Render

Este repositório é composto apenas por ficheiros estáticos. **Não tem Python, Flask, endpoints dinâmicos nem geração automática de JSON.** O aplicativo lê diretamente o ficheiro `/catalog.json` publicado pelo Render Static Site.

## Estrutura

```text
/
├── catalog.json
├── index.html
├── render.yaml
├── games/
│   ├── _template/
│   └── <slug-do-jogo>/
│       ├── manifest.json
│       ├── index.html
│       ├── icon.png
│       ├── cover.jpg
│       ├── screenshots/
│       └── assets/
└── sites/
    ├── _template/
    └── <slug-do-site>/
        ├── manifest.json
        └── logo.png
```

`catalog.json` começa vazio. As pastas `_template` não são listadas no app enquanto não adicionares manualmente entradas ao JSON.

## Publicar no Render

1. Cria um repositório GitHub e copia para a raiz o conteúdo desta pasta.
2. No Render, cria um serviço **Static Site** a partir desse repositório ou usa o `render.yaml` como Blueprint.
3. Publica a raiz (`.`) sem servidor de aplicação.
4. O URL usado pelo aplicativo será `https://TEU-SERVICO.onrender.com/catalog.json`.

## Adicionar um jogo

1. Copia `games/_template/` para `games/<slug>/`. Usa um slug simples em minúsculas.
2. Coloca o `index.html`, todos os CSS, JS, fontes, imagens, sons e outros recursos exclusivos do jogo dentro desta pasta. Coloca o ícone em `icon.png`, a capa em `cover.jpg` e capturas em `screenshots/`.
3. Atualiza `games/<slug>/manifest.json` com os metadados reais e o campo `offline_files`.
4. Acrescenta um objeto ao array `games` de `/catalog.json`, por exemplo:

```json
{
  "id": "slug",
  "name": "Nome do jogo",
  "developer": "Criador",
  "description": "Descrição curta.",
  "long_description": "Descrição completa.",
  "category": "arcade",
  "icon": "games/slug/icon.png",
  "cover": "games/slug/cover.jpg",
  "screenshots": ["games/slug/screenshots/01.jpg"],
  "rating": 4.5,
  "ratings_count": 0,
  "age_rating": "Livre",
  "size_bytes": 0,
  "featured": false,
  "premium": false,
  "online_url": "https://example.com/play/",
  "base_path": "games/slug/",
  "offline_entry": "index.html",
  "offline_files": ["index.html", "assets/css/game.css", "assets/js/game.js"],
  "orientation": "auto",
  "features": []
}
```

`offline_files` tem de enumerar **todos** os ficheiros usados durante a execução offline. O app descarrega cada ficheiro de `/games/slug/<caminho>` e preserva a estrutura no armazenamento local. `offline_entry` é normalmente `index.html`. Não uses caminhos `../`, caminhos absolutos, ficheiros de outra pasta de jogo, APIs/CDNs ou recursos remotos se o jogo tiver de funcionar offline. O valor `size_bytes` deve ser o tamanho aproximado do conteúdo runtime.

## Adicionar um site

1. Copia `sites/_template/` para `sites/<slug>/` e coloca o logótipo em `logo.png`.
2. Acrescenta ao array `sites` de `/catalog.json`:

```json
{
  "id": "slug",
  "name": "Nome do site",
  "url": "https://example.com/",
  "logo": "sites/slug/logo.png",
  "description": "Descrição curta."
}
```

## Configurar a aplicação

Compila o app apontando diretamente para o JSON estático:

```bash
flutter build apk --release \
  --dart-define=BROWSEIT_CATALOG_URL=https://TEU-SERVICO.onrender.com/catalog.json
```

O mesmo URL serve Games e Sites. O aplicativo resolve `icon`, `cover`, `screenshots`, `logo` e `offline_files` relativamente à raiz do catálogo. Não é preciso rebuild quando atualizas o JSON ou adicionas conteúdo estático; basta fazer commit/push no repositório.
