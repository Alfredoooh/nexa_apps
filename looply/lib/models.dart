import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:material_symbols_icons/symbols.dart';

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

class AdBlockStats extends ChangeNotifier {
  AdBlockStats._();
  static final AdBlockStats instance = AdBlockStats._();
  int _totalBlocked = 0;
  final List<int> _dailyBuckets = List.filled(7, 0);
  int get totalBlocked => _totalBlocked;
  List<int> get dailyBuckets => List.unmodifiable(_dailyBuckets);

  void registerBlock() {
    _totalBlocked++;
    _dailyBuckets[6]++;
    notifyListeners();
  }
}

bool isAdBlockedUrl(String url) {
  if (!adBlockEnabled.value) return false;
  try {
    final host = Uri.parse(url).host.toLowerCase();
    if (host.isEmpty) return false;
    final blocked = adBlockDomains.any((domain) => host == domain || host.endsWith('.$domain'));
    if (blocked) AdBlockStats.instance.registerBlock();
    return blocked;
  } catch (_) {
    return false;
  }
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
}

final SearchEngineController activeSearchEngine = SearchEngineController();

enum SiteCategory { destaque, produtividade, social, entretenimento, desenvolvimento, ia, apostas, compras }

String siteCategoryLabel(SiteCategory category) => switch (category) {
  SiteCategory.destaque => 'Em destaque',
  SiteCategory.produtividade => 'Produtividade',
  SiteCategory.social => 'Redes sociais',
  SiteCategory.entretenimento => 'Entretenimento',
  SiteCategory.desenvolvimento => 'Desenvolvimento',
  SiteCategory.ia => 'Inteligência artificial',
  SiteCategory.apostas => 'Apostas desportivas',
  SiteCategory.compras => 'Compras',
};

class QuickSite {
  const QuickSite({required this.name, required this.assetPath, required this.url, this.category = SiteCategory.destaque});
  final String name;
  final String assetPath;
  final String url;
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
  QuickSite(name: 'Mais', assetPath: '$_qs/logo_geometrico_g.webp', url: 'https://www.google.com'),
];

const List<QuickSite> allSites = [
  QuickSite(name: 'Google', assetPath: '$_qs/google.webp', url: 'https://www.google.com', category: SiteCategory.destaque),
  QuickSite(name: 'YouTube', assetPath: '$_qs/youtube.webp', url: 'https://www.youtube.com', category: SiteCategory.destaque),
  QuickSite(name: 'Wikipedia', assetPath: '$_qs/wikipedia.webp', url: 'https://www.wikipedia.org', category: SiteCategory.destaque),
  QuickSite(name: 'Reddit', assetPath: '$_qs/reddit.webp', url: 'https://www.reddit.com', category: SiteCategory.destaque),
  QuickSite(name: 'Instagram', assetPath: '$_qs/instagram.webp', url: 'https://www.instagram.com', category: SiteCategory.social),
  QuickSite(name: 'X', assetPath: '$_qs/x.webp', url: 'https://x.com', category: SiteCategory.social),
  QuickSite(name: 'TikTok', assetPath: '$_qs/tiktok.webp', url: 'https://www.tiktok.com', category: SiteCategory.social),
  QuickSite(name: 'Gmail', assetPath: '$_qs/gmail.webp', url: 'https://mail.google.com', category: SiteCategory.social),
  QuickSite(name: 'Netflix', assetPath: '$_qs/netflix.webp', url: 'https://www.netflix.com', category: SiteCategory.entretenimento),
  QuickSite(name: 'Spotify', assetPath: '$_qs/spotify.webp', url: 'https://open.spotify.com', category: SiteCategory.entretenimento),
  QuickSite(name: 'Roblox', assetPath: '$_qs/roblox.webp', url: 'https://www.roblox.com', category: SiteCategory.entretenimento),
  QuickSite(name: 'Poki', assetPath: '$_qs/poki.webp', url: 'https://poki.com', category: SiteCategory.entretenimento),
  QuickSite(name: 'BBC', assetPath: '$_qs/bbc.webp', url: 'https://www.bbc.com', category: SiteCategory.entretenimento),
  QuickSite(name: 'Notion', assetPath: '$_qs/notion.webp', url: 'https://www.notion.so', category: SiteCategory.produtividade),
  QuickSite(name: 'Dropbox', assetPath: '$_qs/dropbox.webp', url: 'https://www.dropbox.com', category: SiteCategory.produtividade),
  QuickSite(name: 'Zoom', assetPath: '$_qs/zoom.webp', url: 'https://zoom.us', category: SiteCategory.produtividade),
  QuickSite(name: 'Canva', assetPath: '$_qs/canva.webp', url: 'https://www.canva.com', category: SiteCategory.produtividade),
  QuickSite(name: 'Airtable', assetPath: '$_qs/airtable.webp', url: 'https://www.airtable.com', category: SiteCategory.produtividade),
  QuickSite(name: 'Jotform', assetPath: '$_qs/jotform.webp', url: 'https://www.jotform.com', category: SiteCategory.produtividade),
  QuickSite(name: 'Loom', assetPath: '$_qs/loom.webp', url: 'https://www.loom.com', category: SiteCategory.produtividade),
  QuickSite(name: 'Miro', assetPath: '$_qs/miro.webp', url: 'https://miro.com', category: SiteCategory.produtividade),
  QuickSite(name: 'Lucidspark', assetPath: '$_qs/lucidspark.webp', url: 'https://lucidspark.com', category: SiteCategory.produtividade),
  QuickSite(name: 'GitHub', assetPath: '$_qs/github.webp', url: 'https://github.com', category: SiteCategory.desenvolvimento),
  QuickSite(name: 'GitLab', assetPath: '$_qs/gitlab.webp', url: 'https://gitlab.com', category: SiteCategory.desenvolvimento),
  QuickSite(name: 'Replit', assetPath: '$_qs/replit.webp', url: 'https://replit.com', category: SiteCategory.desenvolvimento),
  QuickSite(name: 'Figma', assetPath: '$_qs/figma.webp', url: 'https://www.figma.com', category: SiteCategory.desenvolvimento),
  QuickSite(name: 'Framer', assetPath: '$_qs/framer.webp', url: 'https://www.framer.com', category: SiteCategory.desenvolvimento),
  QuickSite(name: 'Cloudflare', assetPath: '$_qs/cloudflare.webp', url: 'https://www.cloudflare.com', category: SiteCategory.desenvolvimento),
  QuickSite(name: 'Atlassian', assetPath: '$_qs/atlassian.webp', url: 'https://www.atlassian.com', category: SiteCategory.desenvolvimento),
  QuickSite(name: 'Zapier', assetPath: '$_qs/zapier.webp', url: 'https://zapier.com', category: SiteCategory.desenvolvimento),
  QuickSite(name: 'ChatGPT', assetPath: '$_qs/openai_chatgpt.webp', url: 'https://chat.openai.com', category: SiteCategory.ia),
  QuickSite(name: 'DeepMind', assetPath: '$_qs/deepmind.webp', url: 'https://deepmind.google', category: SiteCategory.ia),
  QuickSite(name: 'Mistral', assetPath: '$_qs/mistral.webp', url: 'https://mistral.ai', category: SiteCategory.ia),
  QuickSite(name: 'xAI', assetPath: '$_qs/xai.webp', url: 'https://x.ai', category: SiteCategory.ia),
  QuickSite(name: 'Stability AI', assetPath: '$_qs/stabilityai.webp', url: 'https://stability.ai', category: SiteCategory.ia),
  QuickSite(name: 'Deepgram', assetPath: '$_qs/deepgram.webp', url: 'https://deepgram.com', category: SiteCategory.ia),
  QuickSite(name: 'Sider', assetPath: '$_qs/sider.webp', url: 'https://sider.ai', category: SiteCategory.ia),
  QuickSite(name: 'BantuBet', assetPath: '$_qs/bantubet.webp', url: 'https://www.bantubet.com', category: SiteCategory.apostas),
  QuickSite(name: 'PremierBet', assetPath: '$_qs/premierbet.webp', url: 'https://www.premierbet.co.ao', category: SiteCategory.apostas),
  QuickSite(name: 'WeScore', assetPath: '$_qs/wescore.webp', url: 'https://www.wescore.com', category: SiteCategory.apostas),
  QuickSite(name: 'BeSoccer Pro', assetPath: '$_qs/besoccer_pro.webp', url: 'https://www.besoccer.com', category: SiteCategory.apostas),
  QuickSite(name: 'Amazon', assetPath: '$_qs/amazon.webp', url: 'https://www.amazon.com', category: SiteCategory.compras),
  QuickSite(name: 'Alibaba', assetPath: '$_qs/alibaba.webp', url: 'https://www.alibaba.com', category: SiteCategory.compras),
  QuickSite(name: 'Flipkart', assetPath: '$_qs/flipkart.webp', url: 'https://www.flipkart.com', category: SiteCategory.compras),
  QuickSite(name: 'Airbnb', assetPath: '$_qs/airbnb.webp', url: 'https://www.airbnb.com', category: SiteCategory.compras),
];

class NavAccelerator {
  NavAccelerator._();
  static final NavAccelerator instance = NavAccelerator._();
  final Set<String> _preconnected = {};
  final Map<String, String> _pageCache = {};
  final List<String> _cacheOrder = [];
  static const int _maxCacheEntries = 25;

  Future<void> preconnect(String url) async {
    if (!navigationAcceleratorEnabled.value) return;
    try {
      final uri = Uri.parse(url);
      if (uri.host.isEmpty) return;
      final origin = '${uri.scheme}://${uri.host}';
      if (!_preconnected.add(origin)) return;
      unawaited(http.head(Uri.parse(origin)).timeout(const Duration(seconds: 3)).catchError((_) => http.Response('', 0)));
    } catch (_) {}
  }

  void cachePage(String url, String html) {
    if (!navigationAcceleratorEnabled.value) return;
    if (_pageCache.containsKey(url)) {
      _cacheOrder.remove(url);
    } else if (_cacheOrder.length >= _maxCacheEntries) {
      _pageCache.remove(_cacheOrder.removeAt(0));
    }
    _pageCache[url] = html;
    _cacheOrder.add(url);
  }

  String? getCachedPage(String url) => navigationAcceleratorEnabled.value ? _pageCache[url] : null;
}

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
  final List<ActivityEntry> _entries = [];
  List<ActivityEntry> get entries => List.unmodifiable(_entries.reversed);
  void log(ActivityKind kind, String title, String url) {
    _entries.add(ActivityEntry(kind: kind, title: title, url: url));
    if (_entries.length > 200) _entries.removeAt(0);
    notifyListeners();
  }
  void clear() {
    _entries.clear();
    notifyListeners();
  }
}

final ActivityController activityController = ActivityController();

enum TabKind { browser, appScreen }

class BrowserTab {
  BrowserTab({
    required this.id,
    required this.kind,
    this.url = '',
    this.title,
    this.appScreenLabel,
    this.appScreenIcon,
    this.thumbnail,
    DateTime? lastActivity,
  }) : lastActivity = lastActivity ?? DateTime.now();

  final String id;
  final TabKind kind;
  String url;
  String? title;
  String? appScreenLabel;
  IconData? appScreenIcon;
  Uint8List? thumbnail;
  bool canGoBack = false;
  bool canGoForward = false;
  DateTime lastActivity;
  void touch() => lastActivity = DateTime.now();
}

class TabsController extends ChangeNotifier {
  final List<BrowserTab> _tabs = [];
  int _counter = 0;
  String? _activeTabId;
  List<BrowserTab> get tabs => List.unmodifiable(_tabs);
  int get count => _tabs.length;
  String? get activeTabId => _activeTabId;

  void activate(String id) {
    if (!_tabs.any((tab) => tab.id == id)) return;
    _activeTabId = id;
    final tab = _tabs.firstWhere((tab) => tab.id == id);
    tab.touch();
    notifyListeners();
  }

  BrowserTab createBrowserTab(String url) {
    final tab = BrowserTab(id: 'tab_${_counter++}', kind: TabKind.browser, url: url);
    _tabs.insert(0, tab);
    _activeTabId = tab.id;
    notifyListeners();
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

  // Agora também persiste a URL/título atuais via SessionStore sempre que
  // uma aba de browser é atualizada — é isto que permite restaurar a
  // última página ao reabrir o app dentro da janela de 1h.
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
    if (thumbnail != null) tab.thumbnail = thumbnail;
    tab.touch();
    notifyListeners();

    if (tab.kind == TabKind.browser && tab.url.isNotEmpty) {
      unawaited(SessionStore.instance.saveLastPage(
        url: tab.url,
        title: (tab.title?.trim().isNotEmpty ?? false) ? tab.title! : tab.url,
      ));
    }
  }

  void closeTab(String id) {
    _tabs.removeWhere((tab) => tab.id == id);
    if (_activeTabId == id) {
      _activeTabId = _tabs.where((tab) => tab.kind == TabKind.browser).isNotEmpty
          ? _tabs.firstWhere((tab) => tab.kind == TabKind.browser).id
          : null;
    }
    notifyListeners();
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