import 'dart:async';
import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:material_symbols_icons/symbols.dart';

import '../shell/browser_navigation.dart';
import '../theme.dart';

/// Notícias internacionais obtidas diretamente da GDELT DOC 2.0 API.
/// A pesquisa é restringida a meios de comunicação reconhecidos para evitar
/// que a página Descobrir se transforme numa listagem de fontes desconhecidas.
class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key});

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  static const List<String> _trustedDomains = <String>[
    'reuters.com',
    'apnews.com',
    'bbc.com',
    'bbc.co.uk',
    'theguardian.com',
    'aljazeera.com',
    'cnn.com',
    'dw.com',
    'france24.com',
    'africanews.com',
    'npr.org',
    'bloomberg.com',
    'euronews.com',
  ];

  List<NewsArticle> _articles = <NewsArticle>[];
  bool _loading = true;
  String? _error;
  DateTime? _lastUpdated;
  int _requestToken = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_loadNews());
  }

  Future<void> _loadNews({bool quiet = false}) async {
    final token = ++_requestToken;
    if (mounted) {
      setState(() {
        if (!quiet || _articles.isEmpty) _loading = true;
        _error = null;
      });
    }

    try {
      final sourceFilter =
          '(${_trustedDomains.map((domain) => 'domainis:$domain').join(' OR ')})';
      final query = '$sourceFilter sourcelang:english';
      final uri = Uri.https(
        'api.gdeltproject.org',
        '/api/v2/doc/doc',
        <String, String>{
          'query': query,
          'mode': 'ArtList',
          'format': 'json',
          'maxrecords': '75',
          'sort': 'DateDesc',
          'timespan': '7d',
        },
      );

      final response = await http.get(
        uri,
        headers: const <String, String>{
          'Accept': 'application/json',
          'User-Agent': 'Looply/1.0 (Discover News)',
        },
      ).timeout(const Duration(seconds: 18));

      if (response.statusCode != 200) {
        throw Exception('O serviço de notícias respondeu com ${response.statusCode}.');
      }

      final body = utf8.decode(response.bodyBytes, allowMalformed: true);
      final decoded = jsonDecode(body);
      if (decoded is! Map) {
        throw const FormatException('Resposta de notícias inválida.');
      }

      final rawArticles = decoded['articles'];
      final articles = <NewsArticle>[];
      if (rawArticles is List) {
        final seenUrls = <String>{};
        for (final value in rawArticles) {
          if (value is! Map) continue;
          final article = NewsArticle.fromJson(Map<String, dynamic>.from(value));
          if (article.url.isEmpty || article.title.isEmpty) continue;
          if (!seenUrls.add(article.url)) continue;
          articles.add(article);
        }
      }

      if (!mounted || token != _requestToken) return;
      setState(() {
        _articles = articles;
        _loading = false;
        _lastUpdated = DateTime.now();
        _error = articles.isEmpty
            ? 'Não foram encontradas notícias destas fontes neste momento.'
            : null;
      });
    } catch (error) {
      if (!mounted || token != _requestToken) return;
      setState(() {
        _loading = false;
        if (_articles.isEmpty) {
          _error = 'Não foi possível carregar as notícias. Verifica a ligação e tenta novamente.';
        }
      });
    }
  }

  void _openArticle(NewsArticle article) {
    Navigator.of(context).push<void>(
      CupertinoPageRoute<void>(
        builder: (_) => NewsDetailScreen(article: article),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = mainText(context);
    final muted = mutedText(context);

    return Scaffold(
      backgroundColor: pageBg(context),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        flexibleSpace: appBarSoftFade(context),
        toolbarHeight: 60,
        title: const Text('Descobrir'),
        actions: [
          IconButton(
            tooltip: 'Atualizar notícias',
            onPressed: _loading ? null : () => unawaited(_loadNews()),
            icon: Icon(Symbols.refresh_rounded, color: text),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: RefreshIndicator(
        color: accentColor(context),
        onRefresh: _loadNews,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                child: Row(
                  children: [
                    Icon(Symbols.public_rounded, size: 17, color: accentColor(context)),
                    const SizedBox(width: 7),
                    Text(
                      'Notícias internacionais',
                      style: TextStyle(
                        color: text,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      _lastUpdated == null ? 'Últimos 7 dias' : 'Atualizado agora',
                      style: TextStyle(color: muted, fontSize: 10.5),
                    ),
                  ],
                ),
              ),
            ),
            if (_loading && _articles.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 25,
                        height: 25,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          color: accentColor(context),
                        ),
                      ),
                      const SizedBox(height: 13),
                      Text('A carregar notícias…', style: TextStyle(color: muted, fontSize: 12)),
                    ],
                  ),
                ),
              )
            else if (_articles.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _error == null ? Symbols.newspaper_rounded : Symbols.wifi_off_rounded,
                          size: 44,
                          color: muted,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _error ?? 'Sem notícias disponíveis.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: muted, fontSize: 13, height: 1.4),
                        ),
                        const SizedBox(height: 14),
                        FilledButton.tonalIcon(
                          onPressed: _loading ? null : () => unawaited(_loadNews()),
                          icon: const Icon(Symbols.refresh_rounded, size: 18),
                          label: const Text('Tentar novamente'),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
                  child: _FeaturedNewsCard(
                    article: _articles.first,
                    onTap: () => _openArticle(_articles.first),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 15, 16, 10),
                  child: Text(
                    'Mais notícias',
                    style: TextStyle(color: text, fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 28),
                sliver: SliverList.separated(
                  itemCount: _articles.length - 1,
                  separatorBuilder: (_, __) => const SizedBox(height: 9),
                  itemBuilder: (context, index) {
                    final article = _articles[index + 1];
                    return _NewsListCard(
                      article: article,
                      onTap: () => _openArticle(article),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class NewsArticle {
  const NewsArticle({
    required this.title,
    required this.url,
    required this.domain,
    required this.publishedAt,
    required this.imageUrl,
    required this.language,
    required this.sourceCountry,
  });

  final String title;
  final String url;
  final String domain;
  final DateTime? publishedAt;
  final String imageUrl;
  final String language;
  final String sourceCountry;

  factory NewsArticle.fromJson(Map<String, dynamic> json) {
    return NewsArticle(
      title: (json['title'] ?? '').toString().trim(),
      url: (json['url'] ?? '').toString().trim(),
      domain: (json['domain'] ?? '').toString().trim(),
      publishedAt: _parseGdeltDate((json['seendate'] ?? '').toString()),
      imageUrl: (json['socialimage'] ?? '').toString().trim(),
      language: (json['language'] ?? '').toString().trim(),
      sourceCountry: (json['sourcecountry'] ?? '').toString().trim(),
    );
  }

  String get sourceName {
    final host = domain.toLowerCase();
    if (host.contains('reuters')) return 'Reuters';
    if (host.contains('apnews')) return 'Associated Press';
    if (host.contains('bbc')) return 'BBC';
    if (host.contains('theguardian')) return 'The Guardian';
    if (host.contains('aljazeera')) return 'Al Jazeera';
    if (host.contains('cnn')) return 'CNN';
    if (host.contains('dw.com')) return 'DW';
    if (host.contains('france24')) return 'France 24';
    if (host.contains('africanews')) return 'Africanews';
    if (host.contains('npr')) return 'NPR';
    if (host.contains('bloomberg')) return 'Bloomberg';
    if (host.contains('euronews')) return 'Euronews';
    return domain;
  }
}

DateTime? _parseGdeltDate(String value) {
  if (value.isEmpty) return null;
  final iso = DateTime.tryParse(value);
  if (iso != null) return iso.toLocal();
  final match = RegExp(r'^(\d{4})(\d{2})(\d{2})T(\d{2})(\d{2})(\d{2})Z?$').firstMatch(value);
  if (match == null) return null;
  try {
    return DateTime.utc(
      int.parse(match.group(1)!),
      int.parse(match.group(2)!),
      int.parse(match.group(3)!),
      int.parse(match.group(4)!),
      int.parse(match.group(5)!),
      int.parse(match.group(6)!),
    ).toLocal();
  } catch (_) {
    return null;
  }
}

String _formatNewsDate(DateTime? date) {
  if (date == null) return 'Data indisponível';
  final elapsed = DateTime.now().difference(date);
  if (elapsed.inMinutes < 60 && !elapsed.isNegative) return 'Há ${elapsed.inMinutes} min';
  if (elapsed.inHours < 24 && !elapsed.isNegative) return 'Há ${elapsed.inHours} h';
  return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
}

class _FeaturedNewsCard extends StatelessWidget {
  const _FeaturedNewsCard({required this.article, required this.onTap});
  final NewsArticle article;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = mainText(context);
    final muted = mutedText(context);
    return Material(
      color: pillColor(context),
      borderRadius: BorderRadius.circular(22),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 205,
              width: double.infinity,
              child: _NewsImage(url: article.imageUrl),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(15, 13, 15, 15),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _NewsSourceLine(article: article),
                  const SizedBox(height: 8),
                  Text(
                    article.title,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: text, fontSize: 17, fontWeight: FontWeight.w800, height: 1.25),
                  ),
                  const SizedBox(height: 7),
                  Text(_formatNewsDate(article.publishedAt), style: TextStyle(color: muted, fontSize: 11)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NewsListCard extends StatelessWidget {
  const _NewsListCard({required this.article, required this.onTap});
  final NewsArticle article;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = mainText(context);
    final muted = mutedText(context);
    return Material(
      color: settingsCardColor(context),
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(width: 94, height: 88, child: _NewsImage(url: article.imageUrl)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _NewsSourceLine(article: article, compact: true),
                    const SizedBox(height: 6),
                    Text(
                      article.title,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: text, fontSize: 13, fontWeight: FontWeight.w700, height: 1.25),
                    ),
                    const SizedBox(height: 5),
                    Text(_formatNewsDate(article.publishedAt), style: TextStyle(color: muted, fontSize: 10.5)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NewsSourceLine extends StatelessWidget {
  const _NewsSourceLine({required this.article, this.compact = false});
  final NewsArticle article;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final muted = mutedText(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: compact ? 6 : 7,
          height: compact ? 6 : 7,
          decoration: BoxDecoration(color: accentColor(context), shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            article.sourceName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: muted, fontSize: compact ? 10 : 11, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}

class _NewsImage extends StatelessWidget {
  const _NewsImage({required this.url});
  final String url;

  @override
  Widget build(BuildContext context) {
    if (url.isEmpty || Uri.tryParse(url)?.hasAbsolutePath != true) {
      return _placeholder(context);
    }
    return Image.network(
      url,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      errorBuilder: (_, __, ___) => _placeholder(context),
      loadingBuilder: (context, child, progress) => progress == null
          ? child
          : Container(
              color: pillColor(context),
              alignment: Alignment.center,
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 1.8,
                  color: accentColor(context).withOpacity(.7),
                ),
              ),
            ),
    );
  }

  Widget _placeholder(BuildContext context) => Container(
        color: pillColor(context),
        alignment: Alignment.center,
        child: Icon(Symbols.newspaper_rounded, color: mutedText(context), size: 28),
      );
}

class NewsDetailScreen extends StatelessWidget {
  const NewsDetailScreen({super.key, required this.article});
  final NewsArticle article;

  @override
  Widget build(BuildContext context) {
    final text = mainText(context);
    final muted = mutedText(context);
    return Scaffold(
      backgroundColor: pageBg(context),
      appBar: AppBar(backgroundColor: Colors.transparent, flexibleSpace: appBarSoftFade(context), title: const Text('Detalhes da notícia')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: SizedBox(height: 225, child: _NewsImage(url: article.imageUrl)),
          ),
          const SizedBox(height: 17),
          _NewsSourceLine(article: article),
          const SizedBox(height: 10),
          Text(
            article.title,
            style: TextStyle(color: text, fontSize: 23, fontWeight: FontWeight.w800, height: 1.22),
          ),
          const SizedBox(height: 11),
          Text(
            '${article.sourceName}  •  ${_formatNewsDate(article.publishedAt)}',
            style: TextStyle(color: muted, fontSize: 12),
          ),
          const SizedBox(height: 22),
          Text(
            'Notícia publicada por ${article.sourceName}. Abre a publicação original para consultar o texto integral, imagens adicionais e atualizações do meio de comunicação.',
            style: TextStyle(color: muted, fontSize: 14, height: 1.5),
          ),
          const SizedBox(height: 12),
          SelectableText(article.url, style: TextStyle(color: accentColor(context), fontSize: 12)),
          const SizedBox(height: 22),
          SizedBox(
            height: 50,
            child: FilledButton.icon(
              onPressed: () => openOrbitTab(context, article.url, title: article.title),
              icon: const Icon(Symbols.open_in_browser_rounded),
              label: const Text('Ler notícia completa'),
            ),
          ),
        ],
      ),
    );
  }
}
