import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;

import 'session_store.dart';
import 'widgets/svg_icon.dart';

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
  'trafficstars.com', 'plugrush.com', 'tsyndicate.com', 'adcash.com',
  'adnium.com', 'ero-advertising.com', 'adxpansion.com', 'onclickads.net',
  'onclickalgo.com', 'onclckmn.com', 'adk2x.com', 'adtrafico.com', 'bebi.com',
  'a-ads.com', 'trafficfactory.biz',
  'mouseflow.com', 'smartlook.com', 'clarity.ms',
};

// Preferências persistentes do motor do navegador e da aparência dos sites.
final ValueNotifier<bool> adBlockEnabled = ValueNotifier<bool>(true);
final ValueNotifier<bool> navigationAcceleratorEnabled = ValueNotifier<bool>(true);
final ValueNotifier<bool> forceDarkWebsitesEnabled = ValueNotifier<bool>(false);
final ValueNotifier<bool> siteThemeFollowsAppEnabled = ValueNotifier<bool>(true);
final ValueNotifier<bool> adaptiveToolbarColorEnabled = ValueNotifier<bool>(false);
final ValueNotifier<bool> aiSearchModeEnabled = ValueNotifier<bool>(false);

bool _runtimePreferenceListenersAttached = false;

Future<void> restoreRuntimeSettings() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    adBlockEnabled.value = prefs.getBool('looply_ad_block_enabled') ?? true;
    navigationAcceleratorEnabled.value = prefs.getBool('looply_navigation_accelerator_enabled') ?? true;
    forceDarkWebsitesEnabled.value = prefs.getBool('looply_force_dark_websites') ?? false;
    siteThemeFollowsAppEnabled.value = prefs.getBool('looply_site_theme_follows_app') ?? true;
    adaptiveToolbarColorEnabled.value = prefs.getBool('looply_adaptive_toolbar_color') ?? false;
    aiSearchModeEnabled.value = prefs.getBool('looply_ai_search_mode') ?? false;
    if (_runtimePreferenceListenersAttached) return;
    _runtimePreferenceListenersAttached = true;
    void persist(String key, ValueNotifier<bool> notifier) {
      notifier.addListener(() => unawaited(prefs.setBool(key, notifier.value)));
    }
    persist('looply_ad_block_enabled', adBlockEnabled);
    persist('looply_navigation_accelerator_enabled', navigationAcceleratorEnabled);
    persist('looply_force_dark_websites', forceDarkWebsitesEnabled);
    persist('looply_site_theme_follows_app', siteThemeFollowsAppEnabled);
    persist('looply_adaptive_toolbar_color', adaptiveToolbarColorEnabled);
    persist('looply_ai_search_mode', aiSearchModeEnabled);
  } catch (_) {}
}


class AdBlockStats extends ChangeNotifier {
  AdBlockStats._();
  static final AdBlockStats instance = AdBlockStats._();

  static const String _storageKey = 'looply_adblock_daily_history_v2';
  static const String _usageStorageKey = 'looply_app_usage_days_v1';
  static const MethodChannel _nativeStatsChannel = MethodChannel('looply/native_adblock');
  final Map<String, int> _dailyCounts = <String, int>{};
  final Set<String> _usageDays = <String>{};
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
  bool wasUsedOn(DateTime date) =>
      _usageDays.contains(dateKey(date)) || countForDate(date) > 0;

  /// Rótulos e totais de anúncios bloqueados para os 7 dias mais recentes
  /// (usado na vista "Day" do gráfico de barras da tela de Atividade).
  List<MapEntry<String, int>> get dayView {
    const labels = ['Dom', 'Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb'];
    return List<MapEntry<String, int>>.generate(7, (index) {
      final date = DateTime.now().subtract(Duration(days: 6 - index));
      return MapEntry(labels[date.weekday % 7], countForDate(date));
    }, growable: false);
  }

  /// Totais por semana (segunda a domingo) das últimas 7 semanas, incluindo
  /// a semana atual (usado na vista "Week").
  List<MapEntry<String, int>> get weekView {
    final now = DateTime.now();
    final currentMonday = now.subtract(Duration(days: now.weekday - 1));
    return List<MapEntry<String, int>>.generate(7, (index) {
      final mondayOfWeek = currentMonday.subtract(Duration(days: 7 * (6 - index)));
      var total = 0;
      for (var dayOffset = 0; dayOffset < 7; dayOffset++) {
        total += countForDate(mondayOfWeek.add(Duration(days: dayOffset)));
      }
      return MapEntry('S${index + 1}', total);
    }, growable: false);
  }

  /// Totais por mês dos últimos 7 meses, incluindo o mês atual
  /// (usado na vista "Month").
  List<MapEntry<String, int>> get monthView {
    const labels = ['Jan', 'Fev', 'Mar', 'Abr', 'Mai', 'Jun', 'Jul', 'Ago', 'Set', 'Out', 'Nov', 'Dez'];
    final now = DateTime.now();
    return List<MapEntry<String, int>>.generate(7, (index) {
      final monthsAgo = 6 - index;
      final targetMonthIndex = now.month - 1 - monthsAgo;
      final year = now.year + (targetMonthIndex < 0 ? ((targetMonthIndex + 1) ~/ 12) - 1 : targetMonthIndex ~/ 12);
      final month = ((targetMonthIndex % 12) + 12) % 12 + 1;
      var total = 0;
      for (final key in _dailyCounts.keys) {
        final parts = key.split('-');
        if (parts.length != 3) continue;
        final keyYear = int.tryParse(parts[0]);
        final keyMonth = int.tryParse(parts[1]);
        if (keyYear == year && keyMonth == month) total += _dailyCounts[key] ?? 0;
      }
      return MapEntry(labels[month - 1], total);
    }, growable: false);
  }

  /// Totais por ano dos últimos 5 anos (usado na vista "Year").
  List<MapEntry<String, int>> get yearView {
    final now = DateTime.now();
    return List<MapEntry<String, int>>.generate(5, (index) {
      final year = now.year - (4 - index);
      var total = 0;
      for (final key in _dailyCounts.keys) {
        final parts = key.split('-');
        if (parts.length != 3) continue;
        if (int.tryParse(parts[0]) == year) total += _dailyCounts[key] ?? 0;
      }
      return MapEntry(year.toString(), total);
    }, growable: false);
  }

  /// Uso (verdadeiro/falso) de cada dia da semana atual (segunda a domingo),
  /// usado para marcar os "checks" do Day Streak. Dias futuros são sempre
  /// falsos, mesmo que a semana ainda não tenha terminado.
  List<bool> get currentWeekUsage {
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    return List<bool>.generate(7, (index) {
      final day = monday.add(Duration(days: index));
      final todayAtMidnight = DateTime(now.year, now.month, now.day);
      final dayAtMidnight = DateTime(day.year, day.month, day.day);
      if (dayAtMidnight.isAfter(todayAtMidnight)) return false;
      return wasUsedOn(day);
    }, growable: false);
  }

  /// Sequência atual de dias consecutivos de uso, terminando hoje ou ontem
  /// (se hoje ainda não tiver uso registado, a sequência de ontem continua
  /// a contar como "em curso" até à meia-noite).
  int get currentStreak {
    final now = DateTime.now();
    var cursor = DateTime(now.year, now.month, now.day);
    if (!wasUsedOn(cursor)) {
      cursor = cursor.subtract(const Duration(days: 1));
    }
    var streak = 0;
    while (wasUsedOn(cursor)) {
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return streak;
  }

  bool _nativeListenerAttached = false;

  void _attachNativeStatsListener() {
    if (_nativeListenerAttached || defaultTargetPlatform != TargetPlatform.android) return;
    _nativeListenerAttached = true;
    _nativeStatsChannel.setMethodCallHandler((call) async {
      if (call.method == 'statsChanged') await restore();
    });
  }

  Future<void> restore() async {
    _attachNativeStatsListener();
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
      _usageDays.clear();
      final rawUsage = prefs.getString(_usageStorageKey);
      if (rawUsage != null && rawUsage.isNotEmpty) {
        final decodedUsage = jsonDecode(rawUsage);
        if (decodedUsage is List) {
          _usageDays.addAll(decodedUsage.whereType<String>().where(
            (key) => RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(key),
          ));
        }
      }
    } catch (_) {
      // Dados antigos/corrompidos não impedem o arranque do navegador.
    } finally {
      // Datas antigas com histórico de navegação são reconhecidas como dias
      // de utilização. O dia atual também é registado ao abrir a aplicação.
      for (final entry in activityController.entries) {
        _usageDays.add(dateKey(entry.timestamp));
      }
      _usageDays.add(dateKey(DateTime.now()));
      if (_usageDays.length > 730) {
        final ordered = _usageDays.toList()..sort();
        _usageDays.removeAll(ordered.take(_usageDays.length - 730));
      }
      _restored = true;
      unawaited(_persistUsageDays());
      notifyListeners();
    }
  }

  Future<void> _persistUsageDays() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final ordered = _usageDays.toList()..sort();
      await prefs.setString(_usageStorageKey, jsonEncode(ordered));
    } catch (_) {}
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
  if (adBlockDomains.any((domain) => host == domain || host.endsWith('.$domain'))) {
    return true;
  }

  // Heurísticas conservadoras usadas também para rejeitar popups publicitários
  // de subdomínios/hosts novos que ainda não constam na lista de domínios.
  const adHostLabels = <String>{
    'ad', 'ads', 'adserver', 'adservice', 'advert', 'advertising', 'banner',
    'popunder', 'popads', 'clickunder', 'tracker', 'tracking', 'pixel',
    'beacon', 'affiliate', 'sponsored', 'impression', 'prebid', 'adunit',
  };
  final labels = host.split('.').expand((part) => part.split('-'));
  if (labels.any(adHostLabels.contains)) return true;

  final path = uri?.path.toLowerCase() ?? '';
  if (RegExp(r'(?:^|/)(?:ads?|adserver|adservice|advert(?:ising)?|banners?|popunder|clickunder|trackers?|tracking|pixels?|beacons?|impressions?|vast)(?:[/._-]|$)')
      .hasMatch(path)) {
    return true;
  }
  return false;
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

enum SiteCategory {
  destaque,
  produtividade,
  social,
  entretenimento,
  desenvolvimento,
  ia,
  apostas,
  compras,
  noticias,
  viagens,
  financas,
  personalizados,
}

const Map<SiteCategory, String> siteCategoryLabels = {
  SiteCategory.destaque: 'Destaques',
  SiteCategory.produtividade: 'Produtividade',
  SiteCategory.social: 'Redes sociais',
  SiteCategory.entretenimento: 'Entretenimento',
  SiteCategory.desenvolvimento: 'Desenvolvimento',
  SiteCategory.ia: 'Inteligência artificial',
  SiteCategory.apostas: 'Apostas desportivas',
  SiteCategory.compras: 'Compras',
  SiteCategory.noticias: 'Notícias e informação',
  SiteCategory.viagens: 'Viagens',
  SiteCategory.financas: 'Finanças e serviços',
  SiteCategory.personalizados: 'Os meus sites',
};

String siteCategoryLabel(SiteCategory category) =>
    siteCategoryLabels[category] ?? category.name;

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

  Future<void> add(QuickSite site) async {
    _sites.removeWhere((item) => item.url == site.url);
    _sites.insert(0, site);
    notifyListeners();
    await _persist();
  }

  Future<void> remove(String url) async {
    _sites.removeWhere((item) => item.url == url);
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
    } catch (_) {}
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

String _activityEntryKey(ActivityEntry entry) =>
    '${entry.kind.name}|${entry.url}|${entry.timestamp.microsecondsSinceEpoch}';

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

  void removeEntries(Iterable<ActivityEntry> entries) {
    final keys = entries.map(_activityEntryKey).toSet();
    if (keys.isEmpty) return;
    _entries.removeWhere((entry) => keys.contains(_activityEntryKey(entry)));
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
// reutilizada em toda a navegação da aplicação (como um separador fixo).
enum TabKind { orbitBrowser, browser, appScreen }

class BrowserTab {
  BrowserTab({
    required this.id,
    required this.kind,
    required this.url,
    this.title,
    this.thumbnail,
    this.isIncognito = false,
    this.canGoBack = false,
    this.canGoForward = false,
    this.appScreenLabel,
    this.appScreenIcon,
    DateTime? lastActivity,
  }) : lastActivity = lastActivity ?? DateTime.now();

  final String id;
  final TabKind kind;
  String url;
  String? title;
  Uint8List? thumbnail;
  final bool isIncognito;
  bool canGoBack;
  bool canGoForward;
  String? appScreenLabel;
  IconData? appScreenIcon;
  DateTime lastActivity;

  void touch() {
    lastActivity = DateTime.now();
  }
}

class TabsController extends ChangeNotifier {
  static const String _storageKey = 'looply_open_tabs_v1';
  static const String _activeStorageKey = 'looply_active_tab_v1';
  final List<BrowserTab> _tabs = [];
  String? _activeTabId;
  final List<Future<void>> _pendingSnapshotWrites = [];
  Timer? _persistTimer;

  List<BrowserTab> get tabs => List.unmodifiable(_tabs);
  int get count => _tabs.length;
  String? get activeTabId => _activeTabId;
  BrowserTab? get activeTab {
    if (_activeTabId == null) return null;
    for (final tab in _tabs) {
      if (tab.id == _activeTabId) return tab;
    }
    return null;
  }

  Future<Directory> _tabSnapshotDirectory() async {
    final support = await getApplicationSupportDirectory();
    final directory = Directory('${support.path}${Platform.pathSeparator}tab_snapshots');
    if (!await directory.exists()) await directory.create(recursive: true);
    return directory;
  }

  String _safeTabSnapshotName(String id) =>
      '${id.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_')}.png';

  Future<void> restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          final directory = await _tabSnapshotDirectory();
          for (final item in decoded) {
            if (item is! Map) continue;
            final id = item['id'];
            final kindName = item['kind'];
            final url = item['url'];
            if (id is! String || kindName is! String || url is! String) continue;
            TabKind? kind;
            for (final candidate in TabKind.values) {
              if (candidate.name == kindName) { kind = candidate; break; }
            }
            if (kind == null || kind == TabKind.appScreen) continue;
            Uint8List? thumbnail;
            final thumbnailFile = item['thumbnailFile'];
            if (thumbnailFile is String) {
              try {
                final file = File('${directory.path}${Platform.pathSeparator}$thumbnailFile');
                if (await file.exists()) thumbnail = await file.readAsBytes();
              } catch (_) {}
            }
            if (thumbnail == null) {
              final thumbnailBase64 = item['thumbnailBase64'];
              if (thumbnailBase64 is String) {
                try { thumbnail = base64Decode(thumbnailBase64); } catch (_) {}
              }
            }
            final lastActivity = item['lastActivity'];
            _tabs.add(BrowserTab(
              id: id,
              kind: kind,
              url: url,
              title: item['title'] is String ? item['title'] as String : null,
              thumbnail: thumbnail,
              lastActivity: lastActivity is String ? DateTime.tryParse(lastActivity) : null,
            ));
          }
        }
      }
      final activeId = prefs.getString(_activeStorageKey);
      if (activeId != null && _tabs.any((tab) => tab.id == activeId)) {
        _activeTabId = activeId;
      }
    } catch (_) {
      // Sessões corrompidas não impedem o arranque com abas vazias.
    }
    notifyListeners();
  }

  String _generateTabId() =>
      '${DateTime.now().microsecondsSinceEpoch}_${_tabs.length}_${identityHashCode(this)}';

  BrowserTab createBrowserTab(String url, {String? title, bool isIncognito = false}) {
    final tab = BrowserTab(
      id: _generateTabId(),
      kind: TabKind.browser,
      url: url,
      title: title,
      isIncognito: isIncognito,
    );
    _tabs.add(tab);
    notifyListeners();
    if (!isIncognito) _schedulePersist();
    return tab;
  }

  void activate(String id) {
    if (_activeTabId == id) return;
    _activeTabId = id;
    final tab = getTab(id);
    tab?.touch();
    notifyListeners();
    if (tab != null && !tab.isIncognito) _schedulePersist();
  }

  void updateTab(
    String id, {
    String? url,
    String? title,
    Uint8List? thumbnail,
    bool? canGoBack,
    bool? canGoForward,
  }) {
    final tab = getTab(id);
    if (tab == null) return;
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

  // Reaproveita a aba fixa do Orbit Browser se já existir; caso contrário,
  // cria-a. Só deve existir uma instância de TabKind.orbitBrowser de cada vez.
  BrowserTab upsertOrbitBrowserTab(String? url) {
    final existing = getOrbitBrowserTab();
    if (existing != null) {
      if (url != null && url.isNotEmpty) {
        existing.url = url;
      }
      existing.touch();
      notifyListeners();
      return existing;
    }
    final tab = BrowserTab(
      id: _generateTabId(),
      kind: TabKind.orbitBrowser,
      url: url ?? '',
    );
    _tabs.add(tab);
    notifyListeners();
    _schedulePersist();
    return tab;
  }

  // Reaproveita a aba fixa de um ecrã da app (identificada por screenKey) se
  // já existir, atualizando o seu rótulo/ícone/miniatura; caso contrário, cria-a.
  BrowserTab upsertAppScreenTab(
    String screenKey,
    String label,
    IconData icon,
    Uint8List? thumbnail,
  ) {
    final existing = getAppScreen(screenKey);
    if (existing != null) {
      existing.appScreenLabel = label;
      existing.appScreenIcon = icon;
      if (thumbnail != null) existing.thumbnail = thumbnail;
      existing.touch();
      notifyListeners();
      return existing;
    }
    final tab = BrowserTab(
      id: _generateTabId(),
      kind: TabKind.appScreen,
      url: screenKey,
      title: label,
      thumbnail: thumbnail,
      appScreenLabel: label,
      appScreenIcon: icon,
    );
    _tabs.add(tab);
    notifyListeners();
    return tab;
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

enum DownloadStatus { pending, downloading, completed, failed }

class DownloadEntry {
  DownloadEntry({
    required this.id,
    required this.url,
    required this.filename,
    this.mimeType,
    this.localPath,
    this.status = DownloadStatus.pending,
    this.progress = 0,
    this.errorMessage,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  final String id;
  final String url;
  String filename;
  String? mimeType;
  String? localPath;
  DownloadStatus status;
  double progress;
  String? errorMessage;
  final DateTime createdAt;

  static const Map<String, List<String>> _extensionGroups = {
    'image': ['.png', '.jpg', '.jpeg', '.gif', '.webp', '.bmp', '.svg'],
    'video': ['.mp4', '.mov', '.mkv', '.webm', '.avi', '.m4v'],
    'audio': ['.mp3', '.wav', '.m4a', '.ogg', '.flac', '.aac'],
    'archive': ['.zip', '.rar', '.7z', '.tar', '.gz'],
    'code': ['.dart', '.js', '.ts', '.py', '.java', '.kt', '.html', '.css',
             '.json', '.xml', '.yaml', '.yml', '.c', '.cpp', '.h', '.swift'],
    'pdf': ['.pdf'],
    'doc': ['.doc', '.docx', '.txt', '.rtf'],
  };

  String get _extension {
    final lower = filename.toLowerCase();
    final dot = lower.lastIndexOf('.');
    return dot < 0 ? '' : lower.substring(dot);
  }

  bool _isGroup(String group) => _extensionGroups[group]!.contains(_extension);

  bool get isImage => _isGroup('image');
  bool get isVideo => _isGroup('video');
  bool get isAudio => _isGroup('audio');
  bool get isArchive => _isGroup('archive');
  bool get isCode => _isGroup('code');
  bool get isPdf => _isGroup('pdf');
  bool get isDocument => _isGroup('doc');

  IconData get icon {
    if (isImage) return AppIcons.image;
    if (isVideo) return AppIcons.browser;
    if (isAudio) return AppIcons.microphone;
    if (isArchive) return AppIcons.downloadSimple;
    if (isCode) return AppIcons.list;
    if (isPdf) return AppIcons.fileArrowUp;
    if (isDocument) return AppIcons.fileArrowUp;
    return AppIcons.fileArrowUp;
  }

  bool get canOpenLocally =>
      status == DownloadStatus.completed && localPath != null && localPath!.isNotEmpty;
}

/// Controla downloads reais: faz a requisição HTTP, grava os bytes em disco
/// na pasta de documentos da app, e acompanha o progresso em tempo real.
/// Antes desta classe, o app só registava que uma URL de download tinha sido
/// detectada pelo WebView — nenhum byte era de facto transferido nem gravado.
class DownloadsController extends ChangeNotifier {
  static const String _storageKey = 'looply_downloads_v1';
  final List<DownloadEntry> _entries = [];
  final Map<String, http.Client> _activeClients = {};
  Timer? _persistTimer;

  List<DownloadEntry> get entries => List.unmodifiable(_entries.reversed);

  Future<Directory> _downloadsDirectory() async {
    final support = await getApplicationDocumentsDirectory();
    final directory = Directory('${support.path}${Platform.pathSeparator}downloads');
    if (!await directory.exists()) await directory.create(recursive: true);
    return directory;
  }

  String _generateId() => '${DateTime.now().microsecondsSinceEpoch}_${_entries.length}';

  String _safeFileName(String filename, String id) {
    final cleaned = filename.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    return cleaned.isEmpty ? id : '${id}_$cleaned';
  }

  Future<void> restore() async {
    _entries.clear();
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          for (final item in decoded) {
            if (item is! Map) continue;
            final id = item['id'];
            final url = item['url'];
            final filename = item['filename'];
            if (id is! String || url is! String || filename is! String) continue;
            final localPath = item['localPath'] is String ? item['localPath'] as String : null;
            // Um download marcado como concluído cujo ficheiro já não existe
            // no disco (ex: app reinstalada, cache limpa) é reclassificado
            // como falhado, para não oferecer abrir um ficheiro inexistente.
            var status = DownloadStatus.values.firstWhere(
              (value) => value.name == item['status'],
              orElse: () => DownloadStatus.failed,
            );
            if (status == DownloadStatus.completed) {
              final exists = localPath != null && await File(localPath).exists();
              if (!exists) status = DownloadStatus.failed;
            }
            _entries.add(DownloadEntry(
              id: id,
              url: url,
              filename: filename,
              mimeType: item['mimeType'] is String ? item['mimeType'] as String : null,
              localPath: localPath,
              status: status,
              progress: status == DownloadStatus.completed ? 1 : 0,
              createdAt: item['createdAt'] is String ? DateTime.tryParse(item['createdAt'] as String) : null,
            ));
          }
        }
      }
    } catch (_) {
      // Downloads corrompidos não impedem a abertura do navegador.
    }
    notifyListeners();
  }

  /// Ponto de entrada chamado pelo onDownloadStartRequest do WebView.
  /// Cria a entrada, dispara o download real em segundo plano e devolve
  /// imediatamente — a UI acompanha o progresso através dos listeners.
  String register({required String url, String? filename, String? mimeType}) {
    final id = _generateId();
    final resolvedName = (filename?.trim().isNotEmpty ?? false)
        ? filename!.trim()
        : _filenameFromUrl(url);
    final entry = DownloadEntry(
      id: id,
      url: url,
      filename: resolvedName,
      mimeType: mimeType,
      status: DownloadStatus.pending,
    );
    _entries.add(entry);
    notifyListeners();
    unawaited(_download(entry));
    _schedulePersist();
    return id;
  }

  String _filenameFromUrl(String url) {
    try {
      final uri = Uri.parse(url);
      final last = uri.pathSegments.isNotEmpty ? uri.pathSegments.last : '';
      if (last.trim().isNotEmpty) return last;
    } catch (_) {}
    return 'ficheiro_${DateTime.now().millisecondsSinceEpoch}';
  }

  Future<void> _download(DownloadEntry entry) async {
    final client = http.Client();
    _activeClients[entry.id] = client;
    entry.status = DownloadStatus.downloading;
    notifyListeners();

    try {
      final request = http.Request('GET', Uri.parse(entry.url));
      final response = await client.send(request);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException('HTTP ${response.statusCode}');
      }

      final directory = await _downloadsDirectory();
      final safeName = _safeFileName(entry.filename, entry.id);
      final file = File('${directory.path}${Platform.pathSeparator}$safeName');
      final sink = file.openWrite();

      final total = response.contentLength ?? 0;
      var received = 0;
      var lastNotify = DateTime.now();

      await response.stream.listen(
        (chunk) {
          sink.add(chunk);
          received += chunk.length;
          if (total > 0) {
            entry.progress = (received / total).clamp(0.0, 1.0);
            // Limita a frequência de notifyListeners para não sobrecarregar
            // a UI em downloads rápidos de ficheiros pequenos.
            final now = DateTime.now();
            if (now.difference(lastNotify).inMilliseconds > 120) {
              lastNotify = now;
              notifyListeners();
            }
          }
        },
        onError: (Object error) => throw error,
        cancelOnError: true,
      ).asFuture<void>();

      await sink.flush();
      await sink.close();

      entry.localPath = file.path;
      entry.progress = 1;
      entry.status = DownloadStatus.completed;
      entry.mimeType ??= _guessMimeType(entry.filename);
    } catch (error) {
      entry.status = DownloadStatus.failed;
      entry.errorMessage = error.toString();
    } finally {
      _activeClients.remove(entry.id);
      client.close();
      notifyListeners();
      _schedulePersist();
    }
  }

  String? _guessMimeType(String filename) {
    final lower = filename.toLowerCase();
    const map = {
      '.png': 'image/png', '.jpg': 'image/jpeg', '.jpeg': 'image/jpeg',
      '.gif': 'image/gif', '.webp': 'image/webp', '.mp4': 'video/mp4',
      '.pdf': 'application/pdf', '.zip': 'application/zip',
      '.mp3': 'audio/mpeg', '.txt': 'text/plain', '.json': 'application/json',
      '.html': 'text/html', '.css': 'text/css', '.js': 'text/javascript',
    };
    for (final entry in map.entries) {
      if (lower.endsWith(entry.key)) return entry.value;
    }
    return null;
  }

  void cancel(String id) {
    _activeClients[id]?.close();
    _activeClients.remove(id);
    for (final entry in _entries) {
      if (entry.id == id && entry.status == DownloadStatus.downloading) {
        entry.status = DownloadStatus.failed;
        entry.errorMessage = 'Cancelado';
      }
    }
    notifyListeners();
    _schedulePersist();
  }

  Future<void> remove(String id) async {
    final index = _entries.indexWhere((entry) => entry.id == id);
    if (index < 0) return;
    final entry = _entries[index];
    _activeClients[id]?.close();
    _activeClients.remove(id);
    if (entry.localPath != null) {
      try {
        final file = File(entry.localPath!);
        if (await file.exists()) await file.delete();
      } catch (_) {}
    }
    _entries.removeAt(index);
    notifyListeners();
    _schedulePersist();
  }

  Future<void> clear() async {
    for (final entry in _entries) {
      _activeClients[entry.id]?.close();
      if (entry.localPath != null) {
        try {
          final file = File(entry.localPath!);
          if (await file.exists()) await file.delete();
        } catch (_) {}
      }
    }
    _activeClients.clear();
    _entries.clear();
    notifyListeners();
    _schedulePersist();
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
      final prefs = await SharedPreferences.getInstance();
      final payload = _entries.map((entry) => <String, Object?>{
        'id': entry.id,
        'url': entry.url,
        'filename': entry.filename,
        'mimeType': entry.mimeType,
        'localPath': entry.localPath,
        'status': entry.status.name,
        'createdAt': entry.createdAt.toIso8601String(),
      }).toList();
      await prefs.setString(_storageKey, jsonEncode(payload));
    } catch (_) {}
  }

  @override
  void dispose() {
    _persistTimer?.cancel();
    for (final client in _activeClients.values) {
      client.close();
    }
    unawaited(_persistNow());
    super.dispose();
  }
}

final DownloadsController downloadsController = DownloadsController();