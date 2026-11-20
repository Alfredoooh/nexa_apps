# Games

Cada jogo tem uma pasta própria: `/games/<slug>/`. O `index.html`, `assets/`, `screenshots/`, ícone, capa e manifesto ficam dentro dessa pasta. O catálogo é atualizado manualmente em `/catalog.json`.

Para que o app guarde um jogo para uso offline, o campo `offline_files` deve enumerar todos os ficheiros runtime necessários, com caminhos relativos à pasta do jogo; `offline_entry` indica o HTML inicial. Não uses CDN ou recursos externos no caminho offline.
