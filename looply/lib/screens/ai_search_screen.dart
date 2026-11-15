import 'package:material_ui/material_ui.dart';

import '../localization.dart';
import '../models.dart';
import '../shell/shell_tab_request.dart';
import '../theme.dart';
import '../widgets/material_symbols.dart';
import '../widgets/search_engine_pngs.dart';

/// Ecrã inicial da pesquisa com IA. A apresentação é nativa em Flutter e
/// mantém a consulta na própria aba interna do browser.
class AiSearchScreen extends StatefulWidget {
  const AiSearchScreen({super.key, this.initialQuery = ''});

  final String initialQuery;

  @override
  State<AiSearchScreen> createState() => _AiSearchScreenState();
}

class _AiSearchScreenState extends State<AiSearchScreen> {
  late final TextEditingController _controller;
  String _submittedQuery = '';

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialQuery);
    _submittedQuery = widget.initialQuery;
  }

  @override
  void didUpdateWidget(covariant AiSearchScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialQuery != widget.initialQuery &&
        widget.initialQuery != _controller.text) {
      _controller.text = widget.initialQuery;
      _submittedQuery = widget.initialQuery;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit(String raw) {
    final query = raw.trim();
    if (query.isEmpty) return;
    FocusScope.of(context).unfocus();
    setState(() => _submittedQuery = query);
    final activeTab = tabsController.activeTab;
    if (activeTab != null && activeTab.url.startsWith('looply://ai-search')) {
      tabsController.updateTab(
        activeTab.id,
        url: 'looply://ai-search?q=${Uri.encodeComponent(query)}',
        title: 'AI Search',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = mainText(context);
    final muted = mutedText(context);
    final accent = accentColor(context);
    return Scaffold(
      backgroundColor: pageBg(context),
      body: SafeArea(
        child: Column(
          children: [
            SizedBox(
              height: 58,
              child: Row(
                children: [
                  IconButton(
                    tooltip: appText('back'),
                    onPressed: () => ShellTabRequest.instance.request(0),
                    icon: AppMaterialIcon(AppIcons.arrowLeft, color: text, size: 22),
                  ),
                  Image.memory(searchEnginePng('AI Search')!, width: 24, height: 24, fit: BoxFit.contain),
                  const SizedBox(width: 10),
                  Text(
                    'AI Search',
                    style: TextStyle(color: text, fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
              child: Container(
                height: 52,
                padding: const EdgeInsets.only(left: 14, right: 6),
                decoration: BoxDecoration(
                  color: pillColor(context),
                  borderRadius: BorderRadius.circular(26),
                ),
                child: Row(
                  children: [
                    Image.memory(searchEnginePng('AI Search')!, width: 24, height: 24, fit: BoxFit.contain),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        textInputAction: TextInputAction.search,
                        style: TextStyle(color: text, fontSize: 15),
                        cursorColor: accent,
                        onSubmitted: _submit,
                        decoration: InputDecoration(
                          hintText: appText('search_hint'),
                          hintStyle: TextStyle(color: muted, fontSize: 14),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: appText('search'),
                      onPressed: () => _submit(_controller.text),
                      icon: AppMaterialIcon(AppIcons.arrowUp, color: accent, size: 20),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: accent.withOpacity(.12),
                          shape: BoxShape.circle,
                        ),
                        child: Image.memory(searchEnginePng('AI Search')!, width: 40, height: 40, fit: BoxFit.contain),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'AI Search',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: text, fontSize: 22, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _submittedQuery.isEmpty
                            ? 'A pesquisa com inteligência artificial será apresentada aqui.'
                            : 'Consulta: $_submittedQuery',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: muted, fontSize: 14, height: 1.45),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Esta tela está preparada para receber a experiência completa de pesquisa com IA.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: muted.withOpacity(.82), fontSize: 12.5, height: 1.4),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
