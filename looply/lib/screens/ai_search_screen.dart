import 'package:material_ui/material_ui.dart';

import '../localization.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/material_symbols.dart';
import '../widgets/search_engine_pngs.dart';
import '../widgets/drawer_menu_button.dart';
import '../widgets/looply_dialog.dart';
import '../widgets/drawer_menu.dart' as drawer_menu;

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
    drawer_menu.LooplyDrawerBridge.showHomeAction.value = true;
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
    drawer_menu.LooplyDrawerBridge.showHomeAction.value = false;
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

  void _showAttachmentOptions() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: pageBg(context),
      showDragHandle: true,
      builder: (context) => LooplyModalSystemBar(
        child: SafeArea(
          child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const AppMaterialIcon(AppIcons.image),
                title: Text(appText('images')),
                onTap: () => Navigator.of(context).pop(),
              ),
              ListTile(
                leading: const AppMaterialIcon(AppIcons.uploadSimple),
                title: Text(appText('files')),
                onTap: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = mainText(context);
    final muted = mutedText(context);
    return Scaffold(
      backgroundColor: pageBg(context),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                height: 64,
                child: Row(
                  children: [
                    LooplyDrawerMenuButton(
                      onPressed: () => drawer_menu.showLooplyDrawer(context),
                    ),
                    const SizedBox(width: 4),
                    Image.asset(searchEngineAsset('AI Search'), width: 24, height: 24, fit: BoxFit.contain),
                    const SizedBox(width: 10),
                    Text('AI Search', style: TextStyle(color: text, fontSize: 18, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                reverseDuration: const Duration(milliseconds: 190),
                transitionBuilder: (child, animation) => FadeTransition(opacity: animation, child: child),
                child: Center(
                  key: ValueKey<String>(_submittedQuery),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(color: accentColor(context).withOpacity(.12), shape: BoxShape.circle),
                          child: Image.asset(searchEngineAsset('AI Search'), width: 40, height: 40, fit: BoxFit.contain),
                        ),
                        const SizedBox(height: 18),
                        Text('AI Search', textAlign: TextAlign.center,
                            style: TextStyle(color: text, fontSize: 22, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 8),
                        Text(
                          _submittedQuery.isEmpty
                              ? appText('ai_search_description')
                              : '${appText('search')}: $_submittedQuery',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: muted, fontSize: 14, height: 1.45),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 304),
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 56),
                      padding: const EdgeInsets.fromLTRB(6, 5, 6, 5),
                      decoration: BoxDecoration(
                        color: pillColor(context),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: lineColor(context), width: .7),
                      ),
                      child: Row(
                    children: [
                      IconButton(
                        tooltip: appText('add'),
                        onPressed: _showAttachmentOptions,
                        padding: EdgeInsets.zero,
                        visualDensity: VisualDensity.compact,
                        constraints: const BoxConstraints.tightFor(width: 40, height: 44),
                        icon: AppMaterialIcon(AppIcons.plus, color: muted, size: 22),
                      ),
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          textInputAction: TextInputAction.search,
                          textAlignVertical: TextAlignVertical.center,
                          style: TextStyle(color: text, fontSize: 15),
                          cursorColor: accentColor(context),
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
                      const SizedBox(width: 5),
                      Material(
                        color: accentColor(context),
                        shape: const CircleBorder(),
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: () => _submit(_controller.text),
                          customBorder: const CircleBorder(),
                          child: SizedBox(
                            width: 42,
                            height: 42,
                            child: Center(child: AppMaterialIcon(AppIcons.arrowUp, color: Colors.white, size: 22)),
                          ),
                        ),
                      ),
                    ],
                      ),
                    ),
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
