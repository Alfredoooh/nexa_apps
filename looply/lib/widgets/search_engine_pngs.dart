/// Caminhos para as imagens PNG reais dos motores de pesquisa.
/// Os logótipos são assets do projeto, não bytes Base64 embutidos no código.
const Map<String, String> _searchEnginePaths = <String, String>{
  'AI Search': 'assets/search_engines/ai_search.png',
  'Google': 'assets/search_engines/google.png',
  'Bing': 'assets/search_engines/bing.png',
  'Brave': 'assets/search_engines/brave.png',
  'DuckDuckGo': 'assets/search_engines/duckduckgo.png',
  'Ecosia': 'assets/search_engines/ecosia.png',
  'Yahoo': 'assets/search_engines/yahoo.png',
};

String searchEngineAsset(String name) =>
    _searchEnginePaths[name] ?? _searchEnginePaths['Google']!;
