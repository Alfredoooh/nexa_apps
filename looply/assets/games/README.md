# BrowseIt Games Catalog

Edit `games_catalog.json` to add or update games. The app first loads the bundled JSON, then tries `repository.catalogUrl` when it is configured as a real HTTPS URL. If the remote request fails, the bundled catalog remains available.

Upload this folder to your repository and replace `SEU_USUARIO/SEU_REPOSITORIO` in the three `repository` URL fields. The catalog can use paths relative to `repository.gamesBaseUrl` for game source files and paths relative to the raw JSON URL for cover images.

Supported launch modes:

- `url`: open a hosted HTTPS game page.
- `source_url`: fetch a remote HTML document and render it in the native Android WebView.
- `html`: render HTML embedded directly in the JSON. Set `launch.baseUrl` to an HTTPS origin when the HTML references external/relative resources.

Each entry should include `id`, `name`, `description`, `category`, `icon`, `cover`, `fallbackAsset`, `featured`, `orientation`, and `launch`. Categories must match an item in the top-level `categories` array.
