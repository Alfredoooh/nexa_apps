import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';

import 'session_store.dart';

const Set<String> adBlockDomains = {
  'doubleclick.net', 'googlesyndication.com', 'googleadservices.com',
  'google-analytics.com', 'googletagmanager.com', 'googletagservices.com',
  'adservice.google.com', 'adsystem.com', 'amazon-adsystem.com', 'facebook.net',
  'connect.facebook.net', 'fbcdn.net', 'ads.facebook.com', 'taboola.com',
  'outbrain.com', 'criteo.com', 'criteo.net', 'adroll.com', 'adnxs.com',
  'rubiconproject.com', 'pubmatic.com', 'openx.net', 'casalemedia.com',
  'smartadserver.com', 'advertising.com', 'adform.net', 'adtech.com', 'media.net',
  'yieldmo.com', 'bidswitch.net', 'contextweb.com', 'exoclick.com', 'popads.net',
  'propellerads.com', 'revcontent.com', 'mgid.com', 'zedo.com', 'adblade.com',
  'adcolony.com', 'applovin.com', 'chartboost.com', 'unityads.unity3d.com',
  'vungle.com', 'inmobi.com', 'mopub.com', 'scorecardresearch.com',
  'quantserve.com', 'hotjar.com', 'mixpanel.com', 'segment.io', 'segment.com',
  'amplitude.com', 'crazyegg.com', 'optimizely.com', 'newrelic.com', 'nr-data.net',
  'bugsnag.com', 'sentry.io', 'intercom.io', 'drift.com', 'onesignal.com',
  'pushwoosh.com', 'branch.io', 'adjust.com', 'appsflyer.com', 'kochava.com',
  'tapjoy.com', 'ironsrc.com', 'smaato.net', 'sharethrough.com', 'teads.tv',
  'triplelift.com', 'spotxchange.com', 'adsrvr.org', 'turn.com', 'mathtag.com',
  'bluekai.com', 'krxd.net', 'demdex.net', 'everesttech.net', 'serving-sys.com',
  'atdmt.com', 'adbrite.com', 'adtechus.com', 'burstnet.com', 'chitika.com',
  'clicksor.com', 'infolinks.com', 'kontera.com', 'lijit.com', 'media6degrees.com',
  'pointroll.com', 'quantcast.com', 'rlcdn.com', 'simpli.fi', 'tribalfusion.com',
  'tremorhub.com', 'undertone.com', 'yieldlab.net', 'zergnet.com', 'popcash.net',
  'adsterra.com', 'propellerclick.com', 'clickadu.com', 'galaksion.com',
  'adspyglass.com', 'hilltopads.net', 'juicyads.com', 'trafficjunky.com',
  'exosrv.com', 'moatads.com', 'adsafeprotected.com', 'doubleverify.com',
  'ensighten.com', 'tynt.com', 'addthis.com', 'sharethis.com', 'disqus.com',
  'gemius.pl', 'histats.com', 'statcounter.com', 'clicky.com', 'getclicky.com',
  'woopra.com', 'kissmetrics.com', 'heap.io', 'fullstory.com', 'luckyorange.com',
  'mouseflow.com', 'smartlook.com', 'clarity.ms',
};

// Settings-backed runtime switches.
final ValueNotifier<bool> adBlockEnabled = ValueNotifier<bool>(true);
final ValueNotifier<bool> navigationAcceleratorEnabled = ValueNotifier<bool>(true);

bool _runtimePreferenceListenersAttached = false;

Future<void> restoreRuntimeSettings() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    adBlockEnabled.value = prefs.getBool('looply_ad_block_enabled') ?? true;
    navigationAcceleratorEnabled.value = prefs.getBool('looply_navigation_accelerator_enabled') ?? true;
    if (_runtimePreferenceListenersAttached) return;
    _runtimePreferenceListenersAttached = true;
    adBlockEnabled.addListener(() => unawaited(prefs.setBool('looply_ad_block_enabled', adBlockEnabled.value)));
    navigationAcceleratorEnabled.addListener(() => unawaited(prefs.setBool('looply_navigation_accelerator_enabled', navigationAcceleratorEnabled.value)));
  } catch (_) {}
}


class AdBlockStats extends ChangeNotifier {
  AdBlockStats._();
  static final AdBlockStats instance = AdBlockStats._();

  static const String _storageKey = 'looply_adblock_daily_history_v2';
  final Map<String, int> _dailyCounts = <String, int>{};
  Timer? _notifyTimer;
  Timer? _persistTimer;
  bool _restored = false;

  bool get isRestored => _restored;
  int get totalBlocked => _dailyCounts.values.fold<int>(0, (sum, value) => sum + value);
  Map<String, int> get dailyHistory => Map.unmodifiable(_dailyCounts);

  List<int> get dailyBuckets => List<int>.generate(7, (index) {
    final date = DateTime.now().subtract(Duration(days: 6 - index));
    return countForDate(date);
  }, growable: false);

  static String dateKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  int countForDate(DateTime date) => _dailyCounts[dateKey(date)] ?? 0;

  Future<void> restore() async {
    _dailyCounts.clear();
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          _dailyCounts
            ..clear()
            ..addEntries(decoded.entries.where((entry) =>
              entry.key is String && entry.value is num && (entry.value as num) >= 0
            ).map((entry) => MapEntry(entry.key as String, (entry.value as num).toInt())));
        }
      }
    } catch (_) {
      // Dados antigos/corrompidos não impedem o arranque do navegador.
    } finally {
      _restored = true;
      notifyListeners();
    }
  }

  void registerBlock({DateTime? at}) {
    final key = dateKey(at ?? DateTime.now());
    _dailyCounts[key] = (_dailyCounts[key] ?? 0) + 1;

    // Mantém no máximo dois anos de histórico, evitando crescimento ilimitado
    // do SharedPreferences em sessões de navegação longas.
    if (_dailyCounts.length > 730) {
      final keys = _dailyCounts.keys.toList()..sort();
      for (final oldKey in keys.take(_dailyCounts.length - 730)) {
        _dailyCounts.remove(oldKey);
      }
    }

    _notifyTimer?.cancel();
    _notifyTimer = Timer(const Duration(milliseconds: 180), notifyListeners);
    _persistTimer?.cancel();
    _persistTimer = Timer(const Duration(milliseconds: 650), () {
      unawaited(_persist());
    });
  }

  void clear() {
    _dailyCounts.clear();
    _notifyTimer?.cancel();
    _persistTimer?.cancel();
    notifyListeners();
    unawaited(_persist());
  }

  Future<void> flushPersistence() => _persist();

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_storageKey, jsonEncode(_dailyCounts));
    } catch (_) {}
  }

  @override
  void dispose() {
    _notifyTimer?.cancel();
    _persistTimer?.cancel();
    super.dispose();
  }
}

bool isAdBlockedUrl(String url) {
  if (!adBlockEnabled.value) return false;
  final uri = Uri.tryParse(url);
  final host = uri?.host.toLowerCase().replaceFirst(RegExp(r'\.$'), '');
  if (host == null || host.isEmpty) return false;
  return adBlockDomains.any((domain) => host == domain || host.endsWith('.$domain'));
}

class SearchEngine {
  const SearchEngine({required this.name, required this.domain, required this.urlTemplate, this.assetPath});
  final String name;
  final String domain;
  final String urlTemplate;
  final String? assetPath;
  String buildUrl(String query) => urlTemplate.replaceAll('{q}', Uri.encodeQueryComponent(query));
  String get faviconUrl => 'https://www.google.com/s2/favicons?domain=$domain&sz=64';
}

const List<SearchEngine> searchEngines = [
  SearchEngine(name: 'Google', domain: 'google.com', assetPath: 'assets/images/quick_sites/google.webp', urlTemplate: 'https://www.google.com/search?q={q}'),
  SearchEngine(name: 'Bing', domain: 'bing.com', assetPath: 'assets/images/quick_sites/bing.webp', urlTemplate: 'https://www.bing.com/search?q={q}'),
  SearchEngine(name: 'DuckDuckGo', domain: 'duckduckgo.com', assetPath: 'assets/images/quick_sites/duckduckgo.webp', urlTemplate: 'https://duckduckgo.com/?q={q}'),
  SearchEngine(name: 'Yahoo', domain: 'yahoo.com', assetPath: 'assets/images/quick_sites/yahoo.webp', urlTemplate: 'https://search.yahoo.com/search?p={q}'),
  SearchEngine(name: 'Brave', domain: 'search.brave.com', assetPath: 'assets/images/quick_sites/brave.webp', urlTemplate: 'https://search.brave.com/search?q={q}'),
  SearchEngine(name: 'Ecosia', domain: 'ecosia.org', urlTemplate: 'https://www.ecosia.org/search?q={q}'),
];

class SearchEngineController extends ValueNotifier<SearchEngine> {
  SearchEngineController() : super(searchEngines.first);

  Future<void> restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final name = prefs.getString('looply_search_engine') ?? searchEngines.first.name;
      value = searchEngines.first;
      SearchEngine? engine;
      for (final item in searchEngines) {
        if (item.name == name) { engine = item; break; }
      }
      if (engine != null) value = engine;
    } catch (_) {}
  }

  void select(SearchEngine engine) {
    value = engine;
    unawaited(_persist());
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('looply_search_engine', value.name);
    } catch (_) {}
  }
}



final SearchEngineController activeSearchEngine = SearchEngineController();

/// Pesquisas recentes persistentes, independentes do histórico de navegação.
class SearchHistoryController extends ChangeNotifier {
  static const String _storageKey = 'looply_search_history_v1';
  final List<String> _queries = <String>[];
  List<String> get queries => List.unmodifiable(_queries);

  Future<void> restore() async {
    _queries.clear();
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          _queries.addAll(decoded.whereType<String>().map((value) => value.trim())
              .where((value) => value.isNotEmpty).take(30));
        }
      }
    } catch (_) {}
    notifyListeners();
  }

  void add(String query) {
    final value = query.trim();
    if (value.isEmpty) return;
    _queries.removeWhere((item) => item.toLowerCase() == value.toLowerCase());
    _queries.insert(0, value);
    if (_queries.length > 30) _queries.removeRange(30, _queries.length);
    notifyListeners();
    unawaited(_persist());
  }

  void remove(String query) {
    _queries.remove(query);
    notifyListeners();
    unawaited(_persist());
  }

  Future<void> flushPersistence() => _persist();

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_storageKey, jsonEncode(_queries));
    } catch (_) {}
  }
}

final SearchHistoryController searchHistoryController = SearchHistoryController();

enum SiteCategory { destaque, produtividade, social, entretenimento, desenvolvimento, ia, apostas, compras, noticias, viagens, financas, personalizados }

String siteCategoryLabel(SiteCategory category) => switch (category) {
  SiteCategory.destaque => 'Em destaque',
  SiteCategory.produtividade => 'Produtividade',
  SiteCategory.social => 'Redes sociais',
  SiteCategory.entretenimento => 'Entretenimento',
  SiteCategory.desenvolvimento => 'Desenvolvimento',
  SiteCategory.ia => 'Inteligência artificial',
  SiteCategory.apostas => 'Apostas desportivas',
  SiteCategory.compras => 'Compras',
  SiteCategory.noticias => 'Notícias e informação',
  SiteCategory.viagens => 'Viagens',
  SiteCategory.financas => 'Finanças e serviços',
  SiteCategory.personalizados => 'Os meus sites',
};

class QuickSite {
  const QuickSite({
    required this.name,
    required this.url,
    this.assetPath,
    this.iconBase64,
    this.faviconUrl,
    this.category = SiteCategory.destaque,
  });
  final String name;
  final String? assetPath;
  final String url;
  final String? iconBase64;
  final String? faviconUrl;
  final SiteCategory category;
}


const String _qs = 'assets/images/quick_sites';

const List<QuickSite> quickSites = [
  QuickSite(name: 'Google', assetPath: '$_qs/google.webp', url: 'https://www.google.com'),
  QuickSite(name: 'YouTube', assetPath: '$_qs/youtube.webp', url: 'https://www.youtube.com'),
  QuickSite(name: 'Instagram', assetPath: '$_qs/instagram.webp', url: 'https://www.instagram.com'),
  QuickSite(name: 'WeScore', assetPath: '$_qs/wescore.webp', url: 'https://www.wescore.com'),
  QuickSite(name: 'X', assetPath: '$_qs/x.webp', url: 'https://x.com'),
  QuickSite(name: 'Ao vivo', assetPath: '$_qs/besoccer_pro.webp', url: 'https://www.flashscore.com'),
  QuickSite(name: 'BantuBet', assetPath: '$_qs/bantubet.webp', url: 'https://www.bantubet.com'),
  QuickSite(name: 'PremierBet', assetPath: '$_qs/premierbet.webp', url: 'https://www.premierbet.co.ao'),
  QuickSite(name: 'Wikipedia', assetPath: '$_qs/wikipedia.webp', url: 'https://www.wikipedia.org'),
];

const List<QuickSite> allSites = [
  // Destaques e pesquisa
  QuickSite(name: 'Google', assetPath: '$_qs/google.webp', url: 'https://www.google.com', category: SiteCategory.destaque),
  QuickSite(name: 'Bing', assetPath: '$_qs/bing.webp', url: 'https://www.bing.com', category: SiteCategory.destaque),
  QuickSite(name: 'Brave', assetPath: '$_qs/brave.webp', url: 'https://search.brave.com', category: SiteCategory.destaque),
  QuickSite(name: 'DuckDuckGo', assetPath: '$_qs/duckduckgo.webp', url: 'https://duckduckgo.com', category: SiteCategory.destaque),
  QuickSite(name: 'Yahoo', assetPath: '$_qs/yahoo.webp', url: 'https://www.yahoo.com', category: SiteCategory.destaque),
  QuickSite(name: 'Wikipedia', assetPath: '$_qs/wikipedia.webp', url: 'https://www.wikipedia.org', category: SiteCategory.destaque),
  QuickSite(name: 'Reddit', assetPath: '$_qs/reddit.webp', url: 'https://www.reddit.com', category: SiteCategory.destaque),
  QuickSite(name: 'Medium', assetPath: '$_qs/medium.webp', url: 'https://medium.com', category: SiteCategory.destaque),
  QuickSite(name: 'YouTube', assetPath: '$_qs/youtube.webp', url: 'https://www.youtube.com', category: SiteCategory.destaque),
  // Produtividade e criação
  QuickSite(name: 'Adobe', assetPath: '$_qs/adobe.webp', url: 'https://www.adobe.com', category: SiteCategory.produtividade),
  QuickSite(name: 'Airtable', assetPath: '$_qs/airtable.webp', url: 'https://www.airtable.com', category: SiteCategory.produtividade),
  QuickSite(name: 'Apple', assetPath: '$_qs/apple.webp', url: 'https://www.apple.com', category: SiteCategory.produtividade),
  QuickSite(name: 'Canva', assetPath: '$_qs/canva.webp', url: 'https://www.canva.com', category: SiteCategory.produtividade),
  QuickSite(name: 'Dropbox', assetPath: '$_qs/dropbox.webp', url: 'https://www.dropbox.com', category: SiteCategory.produtividade),
  QuickSite(name: 'Figma', assetPath: '$_qs/figma.webp', url: 'https://www.figma.com', category: SiteCategory.produtividade),
  QuickSite(name: 'Jotform', assetPath: '$_qs/jotform.webp', url: 'https://www.jotform.com', category: SiteCategory.produtividade),
  QuickSite(name: 'Loom', assetPath: '$_qs/loom.webp', url: 'https://www.loom.com', category: SiteCategory.produtividade),
  QuickSite(name: 'Lucidspark', assetPath: '$_qs/lucidspark.webp', url: 'https://lucidspark.com', category: SiteCategory.produtividade),
  QuickSite(name: 'Microsoft', assetPath: '$_qs/microsoft.webp', url: 'https://www.microsoft.com', category: SiteCategory.produtividade),
  QuickSite(name: 'Miro', assetPath: '$_qs/miro.webp', url: 'https://miro.com', category: SiteCategory.produtividade),
  QuickSite(name: 'Notion', assetPath: '$_qs/notion.webp', url: 'https://www.notion.so', category: SiteCategory.produtividade),
  QuickSite(name: 'Zoom', assetPath: '$_qs/zoom.webp', url: 'https://zoom.us', category: SiteCategory.produtividade),
  QuickSite(name: 'Oracle', assetPath: '$_qs/oracle.webp', url: 'https://www.oracle.com', category: SiteCategory.produtividade),
  QuickSite(name: 'Recurly', assetPath: '$_qs/recurly.webp', url: 'https://recurly.com', category: SiteCategory.financas),
  // Redes sociais e comunicação
  QuickSite(name: 'Instagram', assetPath: '$_qs/instagram.webp', url: 'https://www.instagram.com', category: SiteCategory.social),
  QuickSite(name: 'X', assetPath: '$_qs/x.webp', url: 'https://x.com', category: SiteCategory.social),
  QuickSite(name: 'TikTok', assetPath: '$_qs/tiktok.webp', url: 'https://www.tiktok.com', category: SiteCategory.social),
  QuickSite(name: 'Gmail', assetPath: '$_qs/gmail.webp', url: 'https://mail.google.com', category: SiteCategory.social),
  QuickSite(name: 'Revolt', assetPath: '$_qs/revolt.webp', url: 'https://revolt.chat', category: SiteCategory.social),
  // Entretenimento e jogos
  QuickSite(name: 'Netflix', assetPath: '$_qs/netflix.webp', url: 'https://www.netflix.com', category: SiteCategory.entretenimento),
  QuickSite(name: 'Spotify', assetPath: '$_qs/spotify.webp', url: 'https://open.spotify.com', category: SiteCategory.entretenimento),
  QuickSite(name: 'Roblox', assetPath: '$_qs/roblox.webp', url: 'https://www.roblox.com', category: SiteCategory.entretenimento),
  QuickSite(name: 'Poki', assetPath: '$_qs/poki.webp', url: 'https://poki.com', category: SiteCategory.entretenimento),
  // Notícias e desporto
  QuickSite(name: 'BBC', assetPath: '$_qs/bbc.webp', url: 'https://www.bbc.com', category: SiteCategory.noticias),
  QuickSite(name: 'BeSoccer Pro', assetPath: '$_qs/besoccer_pro.webp', url: 'https://www.besoccer.com', category: SiteCategory.noticias),
  // Desenvolvimento e ferramentas
  QuickSite(name: 'Atlassian', assetPath: '$_qs/atlassian.webp', url: 'https://www.atlassian.com', category: SiteCategory.desenvolvimento),
  QuickSite(name: 'Cloudflare', assetPath: '$_qs/cloudflare.webp', url: 'https://www.cloudflare.com', category: SiteCategory.desenvolvimento),
  QuickSite(name: 'Framer', assetPath: '$_qs/framer.webp', url: 'https://www.framer.com', category: SiteCategory.desenvolvimento),
  QuickSite(name: 'GitHub', assetPath: '$_qs/github.webp', url: 'https://github.com', category: SiteCategory.desenvolvimento),
  QuickSite(name: 'GitLab', assetPath: '$_qs/gitlab.webp', url: 'https://gitlab.com', category: SiteCategory.desenvolvimento),
  QuickSite(name: 'Replit', assetPath: '$_qs/replit.webp', url: 'https://replit.com', category: SiteCategory.desenvolvimento),
  QuickSite(name: 'Semrush', assetPath: '$_qs/semrush.webp', url: 'https://www.semrush.com', category: SiteCategory.desenvolvimento),
  QuickSite(name: 'Zapier', assetPath: '$_qs/zapier.webp', url: 'https://zapier.com', category: SiteCategory.desenvolvimento),
  QuickSite(name: 'Deepgram', assetPath: '$_qs/deepgram.webp', url: 'https://deepgram.com', category: SiteCategory.desenvolvimento),
  // Inteligência artificial
  QuickSite(name: 'ChatGPT', assetPath: '$_qs/openai_chatgpt.webp', url: 'https://chatgpt.com', category: SiteCategory.ia),
  QuickSite(name: 'DeepMind', assetPath: '$_qs/deepmind.webp', url: 'https://deepmind.google', category: SiteCategory.ia),
  QuickSite(name: 'Mistral', assetPath: '$_qs/mistral.webp', url: 'https://mistral.ai', category: SiteCategory.ia),
  QuickSite(name: 'xAI', assetPath: '$_qs/xai.webp', url: 'https://x.ai', category: SiteCategory.ia),
  QuickSite(name: 'Stability AI', assetPath: '$_qs/stabilityai.webp', url: 'https://stability.ai', category: SiteCategory.ia),
  QuickSite(name: 'DreamStudio', assetPath: '$_qs/stability_ai.webp', url: 'https://dreamstudio.ai', category: SiteCategory.ia),
  QuickSite(name: 'Sider', assetPath: '$_qs/sider.webp', url: 'https://sider.ai', category: SiteCategory.ia),
  // Apostas, compras e viagens
  QuickSite(name: 'BantuBet', assetPath: '$_qs/bantubet.webp', url: 'https://www.bantubet.com', category: SiteCategory.apostas),
  QuickSite(name: 'PremierBet', assetPath: '$_qs/premierbet.webp', url: 'https://www.premierbet.co.ao', category: SiteCategory.apostas),
  QuickSite(name: 'WeScore', assetPath: '$_qs/wescore.webp', url: 'https://www.wescore.com', category: SiteCategory.apostas),
  QuickSite(name: 'Amazon', assetPath: '$_qs/amazon.webp', url: 'https://www.amazon.com', category: SiteCategory.compras),
  QuickSite(name: 'Alibaba', assetPath: '$_qs/alibaba.webp', url: 'https://www.alibaba.com', category: SiteCategory.compras),
  QuickSite(name: 'Flipkart', assetPath: '$_qs/flipkart.webp', url: 'https://www.flipkart.com', category: SiteCategory.compras),
  QuickSite(name: 'Airbnb', assetPath: '$_qs/airbnb.webp', url: 'https://www.airbnb.com', category: SiteCategory.viagens),
  QuickSite(name: 'Aside', assetPath: '$_qs/aside.webp', url: 'https://aside.com', category: SiteCategory.produtividade),
];


/// Sites adicionados pelo utilizador. A lista e os ícones enviados são
/// guardados localmente e reaparecem automaticamente na próxima abertura.
class CustomSitesController extends ChangeNotifier {
  static const String _storageKey = 'looply_custom_sites_v1';
  final List<QuickSite> _sites = [];
  List<QuickSite> get sites => List.unmodifiable(_sites);

  Future<void> restore() async {
    _sites.clear();
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is List) _sites.addAll(decoded.whereType<Map>().map((item) {
          final name = item['name'];
          final url = item['url'];
          if (name is! String || url is! String) return null;
          return QuickSite(
            name: name,
            url: url,
            iconBase64: item['iconBase64'] is String ? item['iconBase64'] as String : null,
            faviconUrl: item['faviconUrl'] is String ? item['faviconUrl'] as String : null,
            category: SiteCategory.personalizados,
          );
        }).whereType<QuickSite>());
      }
    } catch (_) {
      // Dados de sites inválidos não impedem a abertura do Looply.
    }
    notifyListeners();
  }

  bool containsUrl(String url) => _sites.any((site) => site.url == url);

  Future<void> add(QuickSite site) async {
    _sites.removeWhere((item) => item.url == site.url);
    _sites.add(site);
    notifyListeners();
    await _persist();
  }

  Future<void> remove(String url) async {
    _sites.removeWhere((site) => site.url == url);
    notifyListeners();
    await _persist();
  }

  Future<void> flushPersistence() => _persist();

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final payload = _sites.map((site) => <String, Object?>{
        'name': site.name,
        'url': site.url,
        'iconBase64': site.iconBase64,
        'faviconUrl': site.faviconUrl,
      }).toList();
      await prefs.setString(_storageKey, jsonEncode(payload));
    } catch (_) {
      // Não interrompe a interface se o armazenamento estiver indisponível.
    }
  }
}

final CustomSitesController customSitesController = CustomSitesController();


enum ActivityKind { site, game }

class ActivityEntry {
  ActivityEntry({required this.kind, required this.title, required this.url, DateTime? timestamp})
      : timestamp = timestamp ?? DateTime.now();
  final ActivityKind kind;
  final String title;
  final String url;
  final DateTime timestamp;
}

class ActivityController extends ChangeNotifier {
  static const String _storageKey = 'looply_browsing_history_v1';
  final List<ActivityEntry> _entries = [];
  List<ActivityEntry> get entries => List.unmodifiable(_entries.reversed);

  Future<void> restore() async {
    _entries.clear();
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is List) _entries.addAll(decoded.whereType<Map>().map((item) {
          final kindName = item['kind'];
          final title = item['title'];
          final url = item['url'];
          final timestamp = item['timestamp'];
          if (kindName is! String || title is! String || url is! String) return null;
          ActivityKind? kind;
          for (final candidate in ActivityKind.values) {
            if (candidate.name == kindName) { kind = candidate; break; }
          }
          if (kind == null) return null;
          return ActivityEntry(
            kind: kind,
            title: title,
            url: url,
            timestamp: timestamp is String ? DateTime.tryParse(timestamp) : null,
          );
        }).whereType<ActivityEntry>().toList().take(200));
      }
    } catch (_) {}
    notifyListeners();
  }

  void log(ActivityKind kind, String title, String url) {
    if (url.trim().isEmpty) return;
    final now = DateTime.now();
    if (_entries.isNotEmpty) {
      final latest = _entries.last;
      if (latest.url == url && now.difference(latest.timestamp).inSeconds < 3) return;
    }
    _entries.add(ActivityEntry(kind: kind, title: title, url: url, timestamp: now));
    if (_entries.length > 200) _entries.removeAt(0);
    notifyListeners();
    unawaited(_persist());
  }

  void clear() {
    _entries.clear();
    notifyListeners();
    unawaited(_persist());
  }

  Future<void> flushPersistence() => _persist();

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final payload = _entries.map((entry) => <String, Object?>{
        'kind': entry.kind.name,
        'title': entry.title,
        'url': entry.url,
        'timestamp': entry.timestamp.toIso8601String(),
      }).toList();
      await prefs.setString(_storageKey, jsonEncode(payload));
    } catch (_) {}
  }
}

final ActivityController activityController = ActivityController();

// A aba especial do Orbit Browser mantém uma única instância persistente,
// usando a mesma OrbitBrowserScreen e os mesmos controlos de navegação
// das restantes abas de browser.
enum TabKind { browser, appScreen, orbitBrowser }

class BrowserTab {
  BrowserTab({
    required this.id,
    required this.kind,
    this.url = '',
    this.title,
    this.appScreenLabel,
    this.appScreenIcon,
    this.thumbnail,
    this.isIncognito = false,
    DateTime? lastActivity,
  }) : lastActivity = lastActivity ?? DateTime.now();

  final String id;
  final TabKind kind;
  String url;
  String? title;
  String? appScreenLabel;
  IconData? appScreenIcon;
  Uint8List? thumbnail;
  final bool isIncognito;
  bool canGoBack = false;
  bool canGoForward = false;
  DateTime lastActivity;
  void touch() => lastActivity = DateTime.now();
}


Future<Directory> _tabSnapshotDirectory() async {
  final support = await getApplicationSupportDirectory();
  final directory = Directory('${support.path}${Platform.pathSeparator}tab_snapshots');
  if (!await directory.exists()) await directory.create(recursive: true);
  return directory;
}

String _safeTabSnapshotName(String id) =>
    '${id.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_')}.png';

class TabsController extends ChangeNotifier {
  static const String _storageKey = 'looply_browser_tabs_v2';
  static const String _activeStorageKey = 'looply_active_browser_tab_v2';
  final List<BrowserTab> _tabs = [];
  final Set<Future<void>> _pendingSnapshotWrites = <Future<void>>{};
  int _counter = 0;
  String? _activeTabId;
  Timer? _persistTimer;
  List<BrowserTab> get tabs => List.unmodifiable(_tabs);
  int get count => _tabs.length;
  String? get activeTabId => _activeTabId;

  Future<void> restore() async {
    _tabs.clear();
    _activeTabId = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      final decoded = raw == null || raw.isEmpty ? const <dynamic>[] : jsonDecode(raw);
      if (decoded is! List) {
        notifyListeners();
        return;
      }
      var greatestId = -1;
      for (final value in decoded) {
        if (value is! Map) continue;
        final id = value['id'];
        final kindName = value['kind'];
        final url = value['url'];
        if (id is! String || url is! String || url.trim().isEmpty) continue;
        TabKind? kind;
        for (final candidate in TabKind.values) {
          if (candidate.name == kindName) { kind = candidate; break; }
        }
        if (kind == null || kind == TabKind.appScreen) continue;
        final uri = Uri.tryParse(url);
        if (uri == null || uri.host.isEmpty || (uri.scheme != 'http' && uri.scheme != 'https')) continue;
        final suffix = int.tryParse(id.startsWith('tab_') ? id.substring(4) : '');
        if (suffix != null && suffix > greatestId) greatestId = suffix;
        Uint8List? thumbnail;
        try {
          final snapshotDirectory = await _tabSnapshotDirectory();
          final snapshotFile = File('${snapshotDirectory.path}${Platform.pathSeparator}${_safeTabSnapshotName(id)}');
          if (await snapshotFile.exists()) thumbnail = await snapshotFile.readAsBytes();
        } catch (_) {}
        if (thumbnail == null) {
          final encodedThumbnail = value['thumbnailBase64'];
          if (encodedThumbnail is String && encodedThumbnail.isNotEmpty && encodedThumbnail.length <= 95000) {
            try { thumbnail = base64Decode(encodedThumbnail); } catch (_) {}
          }
        }
        _tabs.add(BrowserTab(
          id: id,
          kind: kind,
          url: url,
          title: value['title'] is String ? value['title'] as String : null,
          thumbnail: thumbnail,
          lastActivity: value['lastActivity'] is String
              ? DateTime.tryParse(value['lastActivity'] as String)
              : null,
        ));
      }
      _counter = greatestId + 1;
      final savedActive = prefs.getString(_activeStorageKey);
      _activeTabId = _tabs.any((tab) => tab.id == savedActive)
          ? savedActive
          : (_tabs.isNotEmpty ? _tabs.first.id : null);
      notifyListeners();
    } catch (_) {
      // Se a sessão estiver corrompida, o Looply abre normalmente sem abas restauradas.
    }
  }

  void activate(String id) {
    if (!_tabs.any((tab) => tab.id == id)) return;
    _activeTabId = id;
    final tab = _tabs.firstWhere((tab) => tab.id == id);
    tab.touch();
    notifyListeners();
    _schedulePersist();
  }

  BrowserTab createBrowserTab(String url, {bool isIncognito = false}) {
    final tab = BrowserTab(id: 'tab_${_counter++}', kind: TabKind.browser, url: url, isIncognito: isIncognito);
    _tabs.insert(0, tab);
    _activeTabId = tab.id;
    notifyListeners();
    _schedulePersist();
    return tab;
  }

  BrowserTab upsertAppScreenTab(String screenKey, String label, IconData icon, Uint8List? thumbnail) {
    final index = _tabs.indexWhere((tab) => tab.kind == TabKind.appScreen && tab.url == screenKey);
    if (index >= 0) {
      final tab = _tabs.removeAt(index);
      tab.thumbnail = thumbnail;
      tab.touch();
      _tabs.insert(0, tab);
      notifyListeners();
      return tab;
    }
    final tab = BrowserTab(
      id: 'tab_${_counter++}', kind: TabKind.appScreen, url: screenKey,
      appScreenLabel: label, appScreenIcon: icon, thumbnail: thumbnail,
    );
    _tabs.insert(0, tab);
    notifyListeners();
    return tab;
  }

  BrowserTab upsertOrbitBrowserTab(Uint8List? thumbnail) {
    final index = _tabs.indexWhere((tab) => tab.kind == TabKind.orbitBrowser);
    if (index >= 0) {
      final tab = _tabs.removeAt(index);
      if (thumbnail != null) {
        tab.thumbnail = thumbnail;
        if (!tab.isIncognito) _trackSnapshotWrite(tab.id, thumbnail);
      }
      tab.touch();
      _tabs.insert(0, tab);
      notifyListeners();
      _schedulePersist();
      return tab;
    }
    final tab = BrowserTab(
      id: 'tab_${_counter++}', kind: TabKind.orbitBrowser, url: 'https://www.wikipedia.org',
      appScreenLabel: 'Orbit Browser', appScreenIcon: Symbols.language_rounded, thumbnail: thumbnail,
    );
    _tabs.insert(0, tab);
    _activeTabId = tab.id;
    notifyListeners();
    _schedulePersist();
    return tab;
  }

  void updateTab(
    String id, {
    String? url,
    String? title,
    bool? canGoBack,
    bool? canGoForward,
    Uint8List? thumbnail,
  }) {
    final index = _tabs.indexWhere((tab) => tab.id == id);
    if (index < 0) return;
    final tab = _tabs[index];
    if (url != null) tab.url = url;
    if (title != null) tab.title = title;
    if (canGoBack != null) tab.canGoBack = canGoBack;
    if (canGoForward != null) tab.canGoForward = canGoForward;
    if (thumbnail != null) {
      tab.thumbnail = thumbnail;
      if (!tab.isIncognito) {
        _trackSnapshotWrite(id, thumbnail);
      }
    }
    tab.touch();
    notifyListeners();

    if (tab.kind != TabKind.appScreen && !tab.isIncognito && tab.url.isNotEmpty) {
      unawaited(SessionStore.instance.saveLastPage(
        url: tab.url,
        title: (tab.title?.trim().isNotEmpty ?? false) ? tab.title! : tab.url,
      ));
      _schedulePersist();
    }
  }

  void _trackSnapshotWrite(String id, Uint8List bytes) {
    final pending = _saveTabSnapshot(id, bytes);
    _pendingSnapshotWrites.add(pending);
    unawaited(pending.whenComplete(() => _pendingSnapshotWrites.remove(pending)));
  }

  Future<void> _saveTabSnapshot(String id, Uint8List bytes) async {
    try {
      final directory = await _tabSnapshotDirectory();
      final file = File('${directory.path}${Platform.pathSeparator}${_safeTabSnapshotName(id)}');
      await file.writeAsBytes(bytes, flush: true);
    } catch (_) {
      // A grelha continua a funcionar com a miniatura em memória se o disco falhar.
    }
  }

  Future<void> _deleteTabSnapshot(String id) async {
    try {
      if (_pendingSnapshotWrites.isNotEmpty) {
        await Future.wait<void>(_pendingSnapshotWrites.toList(growable: false));
      }
      final directory = await _tabSnapshotDirectory();
      final file = File('${directory.path}${Platform.pathSeparator}${_safeTabSnapshotName(id)}');
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }

  Future<void> clearStoredSnapshots() async {
    try {
      if (_pendingSnapshotWrites.isNotEmpty) {
        await Future.wait<void>(_pendingSnapshotWrites.toList(growable: false));
      }
      final directory = await _tabSnapshotDirectory();
      if (await directory.exists()) {
        await for (final entity in directory.list(followLinks: false)) {
          if (entity is File && entity.path.toLowerCase().endsWith('.png')) {
            await entity.delete();
          }
        }
      }
    } catch (_) {}
  }

  void closeTab(String id) {
    _tabs.removeWhere((tab) => tab.id == id);
    unawaited(_deleteTabSnapshot(id));
    if (_activeTabId == id) {
      _activeTabId = _tabs.where((tab) => tab.kind != TabKind.appScreen).isNotEmpty
          ? _tabs.firstWhere((tab) => tab.kind != TabKind.appScreen).id
          : null;
    }
    notifyListeners();
    _schedulePersist();
  }

  void reorderById(String movingId, String targetId) {
    final from = _tabs.indexWhere((tab) => tab.id == movingId);
    final target = _tabs.indexWhere((tab) => tab.id == targetId);
    if (from < 0 || target < 0 || from == target) return;

    final moving = _tabs.removeAt(from);
    // Depois da remoção, o índice do alvo desloca-se quando o cartão veio
    // de uma posição anterior. Inserir imediatamente antes do alvo deixa
    // os restantes cartões preencherem o espaço com AnimatedPositioned.
    final destination = from < target ? target - 1 : target;
    final safeDestination = destination.clamp(0, _tabs.length).toInt();
    _tabs.insert(safeDestination, moving);
    notifyListeners();
    _schedulePersist();
  }

  void closeTabs(Iterable<String> ids) {
    final removed = ids.toSet();
    if (removed.isEmpty) return;
    _tabs.removeWhere((tab) => removed.contains(tab.id));
    for (final id in removed) { unawaited(_deleteTabSnapshot(id)); }
    if (_activeTabId != null && removed.contains(_activeTabId)) {
      final remaining = _tabs.where((tab) => tab.kind != TabKind.appScreen).toList(growable: false);
      _activeTabId = remaining.isEmpty ? null : remaining.first.id;
    }
    notifyListeners();
    _schedulePersist();
  }

  void closeAllTabs() {
    for (final tab in _tabs) { unawaited(_deleteTabSnapshot(tab.id)); }
    _tabs.clear();
    _activeTabId = null;
    notifyListeners();
    _schedulePersist();
  }

  BrowserTab? getTab(String id) {
    for (final tab in _tabs) {
      if (tab.id == id) return tab;
    }
    return null;
  }

  BrowserTab? getAppScreen(String screenKey) {
    for (final tab in _tabs) {
      if (tab.kind == TabKind.appScreen && tab.url == screenKey) return tab;
    }
    return null;
  }

  BrowserTab? getOrbitBrowserTab() {
    for (final tab in _tabs) {
      if (tab.kind == TabKind.orbitBrowser) return tab;
    }
    return null;
  }

  Future<void> flushPersistence() {
    _persistTimer?.cancel();
    return _persistNow();
  }

  void _schedulePersist() {
    _persistTimer?.cancel();
    _persistTimer = Timer(const Duration(milliseconds: 280), _persistNow);
  }

  Future<void> _persistNow() async {
    try {
      if (_pendingSnapshotWrites.isNotEmpty) {
        await Future.wait<void>(_pendingSnapshotWrites.toList(growable: false));
      }
      final prefs = await SharedPreferences.getInstance();
      final payload = _tabs
          .where((tab) => tab.kind != TabKind.appScreen && !tab.isIncognito)
          .map((tab) {
            final thumbnail = tab.thumbnail;
            return <String, Object?>{
              'id': tab.id,
              'kind': tab.kind.name,
              'url': tab.url,
              'title': tab.title,
              'thumbnailFile': thumbnail != null ? _safeTabSnapshotName(tab.id) : null,
              'thumbnailBase64': thumbnail != null && thumbnail.length <= 70000
                  ? base64Encode(thumbnail)
                  : null,
              'lastActivity': tab.lastActivity.toIso8601String(),
            };
          })
          .toList();
      await prefs.setString(_storageKey, jsonEncode(payload));
      if (_activeTabId == null || !_tabs.any((tab) => tab.id == _activeTabId && tab.kind != TabKind.appScreen && !tab.isIncognito)) {
        await prefs.remove(_activeStorageKey);
      } else {
        await prefs.setString(_activeStorageKey, _activeTabId!);
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _persistTimer?.cancel();
    unawaited(_persistNow());
    super.dispose();
  }
}

final TabsController tabsController = TabsController();

class LooplyGame {
  const LooplyGame({required this.title, required this.category, required this.players, required this.artColor, required this.index, required this.description, this.url});
  final String title;
  final String category;
  final String players;
  final Color artColor;
  final int index;
  final String description;
  final String? url;
}

const List<LooplyGame> looplyGames = [
  LooplyGame(
    title: 'Zombie Rush', category: 'Ação', players: '—', artColor: Color(0xFF1D76D2), index: 0,
    description: 'Sobrevive à horda de zombies nesta experiência jogável diretamente na app.',
    url: 'https://raw.githubusercontent.com/CoolDude2349/Offline-HTML-Games-Pack/refs/heads/master/offline/zombie-rush.html',
  ),
];