# Modelo de jogo

Copia esta pasta para `games/<slug>/`. Coloca o `index.html` e todos os recursos usados pelo jogo dentro desta pasta. Os CSS, JavaScript, imagens, fontes, áudio e restantes assets devem permanecer exclusivos desta pasta. As capturas ficam em `screenshots/`; o ícone e a capa ficam na raiz.

No `catalog.json`, cria o objeto do jogo com `base_path: "games/<slug>/"`, `offline_entry: "index.html"` e enumera todos os ficheiros de runtime em `offline_files`. Inclui sempre `index.html`. Caminhos em `offline_files` são relativos a `base_path`.
