import 'package:flutter/cupertino.dart' show CupertinoPageRoute;
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:m3e_segmented_list/m3e_segmented_list.dart';

import '../models.dart';
import '../browser_library.dart';
import 'bookmarks_screen.dart';
import 'downloads_screen.dart';
import 'history_screen.dart';
import '../theme.dart';
import '../localization.dart';
import 'language_screen.dart';
import '../widgets/looply_dialog.dart';
import '../widgets/drawer_menu.dart' as drawer_menu;
import '../widgets/m3_switch.dart';
import '../widgets/search_engine_picker.dart';
import '../data_transfer.dart';
import '../auth_service.dart';
import 'app_info_screen.dart';
import 'auth_screen.dart';
import 'profile_screen.dart';
import 'security_screen.dart';
import '../widgets/material_symbols.dart';

// Cards de Settings usam o tom do inputbar no tema escuro e um
// cinza-branco no tema claro (settingsCardColor), em vez de
// panelColor, para se destacarem mais do fundo.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final bg = pageBg(context);
    final text = mainText(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: (isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark)
          .copyWith(
        statusBarColor: bg,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        systemNavigationBarColor: bg,
        systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        systemNavigationBarDividerColor: bg,
        systemNavigationBarContrastEnforced: false,
              ),
      child: Scaffold(
        backgroundColor: bg,
        appBar: AppBar(
          toolbarHeight: 64,
          automaticallyImplyLeading: false,
          leadingWidth: 56,
          backgroundColor: bg,
          foregroundColor: text,
          surfaceTintColor: Colors.transparent,
          shadowColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          leading: AppBackButton(
            tooltip: appText('back'),
            color: text,
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          title: Text(
            appText('settings'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: text, fontSize: 22, fontWeight: FontWeight.w600),
          ),
        ),
        body: SafeArea(
          top: false,
          bottom: true,
          child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          children: [
            ValueListenableBuilder<LooplyUser?>(
              valueListenable: authController,
              builder: (context, user, _) => _AccountSummaryCard(user: user),
            ),
            const SizedBox(height: 20),
            _SettingsSection(
              title: appText('general'),
              children: [
                _SettingsTile(
                  icon: AppIcons.moon,
                  label: appText('theme'),
                  trailing: ValueListenableBuilder<ThemeMode>(
                    valueListenable: themeController,
                    builder: (_, mode, __) => ValueListenableBuilder<bool>(
                      valueListenable: themeController.pureDark,
                      builder: (_, pureBlack, __) => _SettingsValue(_themeLabel(mode, pureBlack)),
                    ),
                  ),
                  onTap: () => drawer_menu.showThemeSheet(context),
                ),
                ValueListenableBuilder<SearchEngine>(
                  valueListenable: activeSearchEngine,
                  builder: (context, engine, _) => _SettingsTile(
                    icon: AppIcons.compass,
                    label: appText('search_engine'),
                    trailing: _SettingsValue(engine.name),
                    onTap: () => showSearchEnginePicker(context),
                  ),
                ),
                _SettingsTile(
                  icon: AppIcons.globe,
                  label: appText('language'),
                  trailing: ValueListenableBuilder<AppLanguage>(
                    valueListenable: appLanguageController,
                    builder: (_, language, __) => _SettingsValue(language.nativeName),
                  ),
                  onTap: () => Navigator.of(context).push(
                    CupertinoPageRoute<void>(builder: (_) => const LanguageScreen()),
                  ),
                ),
                const _DefaultBrowserSettingsTile(),
              ],
            ),
            const SizedBox(height: 20),
            _SettingsSection(
              title: appText('navigation_security'),
              children: [
                ValueListenableBuilder<bool>(
                  valueListenable: adBlockEnabled,
                  builder: (context, enabled, _) => _SettingsTile(
                    icon: AppIcons.shield,
                    label: appText('ad_blocker'),
                    subtitle: enabled ? appText('enabled') : appText('disabled'),
                    trailing: M3ExpressiveSwitch(
                      value: enabled,
                      onChanged: (value) => adBlockEnabled.value = value,
                    ),
                    showChevron: false,
                    onTap: () => adBlockEnabled.value = !adBlockEnabled.value,
                  ),
                ),
                ValueListenableBuilder<bool>(
                  valueListenable: navigationAcceleratorEnabled,
                  builder: (context, enabled, _) => _SettingsTile(
                    icon: AppIcons.gauge,
                    label: appText('navigation_accelerator'),
                    subtitle: enabled ? appText('acceleration_on') : appText('acceleration_off'),
                    trailing: M3ExpressiveSwitch(
                      value: enabled,
                      onChanged: (value) => navigationAcceleratorEnabled.value = value,
                    ),
                    showChevron: false,
                    onTap: () => navigationAcceleratorEnabled.value = !navigationAcceleratorEnabled.value,
                  ),
                ),
                ValueListenableBuilder<bool>(
                  valueListenable: forceDarkWebsitesEnabled,
                  builder: (context, enabled, _) => _SettingsTile(
                    icon: AppIcons.moon,
                    label: appText('force_dark'),
                    subtitle: appText('force_dark_subtitle'),
                    trailing: M3ExpressiveSwitch(
                      value: enabled,
                      onChanged: (value) => forceDarkWebsitesEnabled.value = value,
                    ),
                    showChevron: false,
                    onTap: () => forceDarkWebsitesEnabled.value = !forceDarkWebsitesEnabled.value,
                  ),
                ),
                ValueListenableBuilder<bool>(
                  valueListenable: adaptiveToolbarColorEnabled,
                  builder: (context, enabled, _) => _SettingsTile(
                    icon: AppIcons.palette,
                    label: appText('adaptive_toolbar'),
                    subtitle: appText('adaptive_toolbar_subtitle'),
                    trailing: M3ExpressiveSwitch(
                      value: enabled,
                      onChanged: (value) => adaptiveToolbarColorEnabled.value = value,
                    ),
                    showChevron: false,
                    onTap: () => adaptiveToolbarColorEnabled.value = !adaptiveToolbarColorEnabled.value,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _SettingsSection(
              title: 'Acessibilidade',
              children: [
                ValueListenableBuilder<bool>(
                  valueListenable: assistiveTouchEnabled,
                  builder: (context, enabled, _) => _SettingsTile(
                    icon: AppIcons.menu,
                    label: 'Assistive Touch',
                    subtitle: enabled ? 'Ativo em todas as telas' : 'Desativado',
                    trailing: M3ExpressiveSwitch(
                      value: enabled,
                      onChanged: (value) => assistiveTouchEnabled.value = value,
                    ),
                    showChevron: false,
                    onTap: () => assistiveTouchEnabled.value = !assistiveTouchEnabled.value,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _SettingsSection(
              title: 'Segurança',
              children: [
                _SettingsTile(
                  icon: AppIcons.shieldCheck,
                  label: 'Segurança e privacidade',
                  subtitle: 'Sites bloqueados, PIN e palavras-passe',
                  onTap: () => Navigator.of(context).push(
                    CupertinoPageRoute<void>(builder: (_) => const SecurityScreen()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _SettingsSection(
              title: appText('library'),
              children: [
                AnimatedBuilder(
                  animation: activityController,
                  builder: (context, _) => _SettingsTile(
                    icon: AppIcons.clockCounterClockwise,
                    label: appText('history'),
                    subtitle: appText('history_entries_count').replaceAll('{count}', activityController.entries.length.toString()),
                    onTap: () => _openLibraryPage(context, const HistoryScreen()),
                  ),
                ),
                AnimatedBuilder(
                  animation: downloadsController,
                  builder: (context, _) => _SettingsTile(
                    icon: AppIcons.downloadSimple,
                    label: appText('downloads'),
                    subtitle: appText('downloads_count').replaceAll('{count}', downloadsController.entries.length.toString()),
                    onTap: () => _openLibraryPage(context, const DownloadsScreen()),
                  ),
                ),
                AnimatedBuilder(
                  animation: bookmarksController,
                  builder: (context, _) => _SettingsTile(
                    icon: AppIcons.bookmarksSimple,
                    label: appText('bookmarks'),
                    subtitle: appText('bookmarks_count').replaceAll('{count}', bookmarksController.entries.length.toString()),
                    onTap: () => _openLibraryPage(context, const BookmarksScreen()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _SettingsSection(
              title: appText('data'),
              children: [
                _SettingsTile(
                  icon: AppIcons.uploadSimple,
                  label: appText('export_data'),
                  subtitle: appText('export_description'),
                  onTap: () => _exportData(context),
                ),
                _SettingsTile(
                  icon: AppIcons.downloadSimple,
                  label: appText('import_data'),
                  subtitle: appText('import_description'),
                  onTap: () => _importData(context),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _SettingsSection(
              title: appText('app_info'),
              children: [
                _SettingsTile(
                  icon: AppIcons.info,
                  label: appText('app_info'),
                  subtitle: 'BrowseIt',
                  onTap: () => Navigator.of(context).push(
                    CupertinoPageRoute<void>(builder: (_) => const AppInfoScreen()),
                  ),
                ),
              ],
            ),
          ],
        ),
        ),
      ),
    );
  }

  Future<void> _exportData(BuildContext context) async {
    try {
      final path = await LooplyDataTransfer.exportToFile();
      if (!context.mounted) return;
      final message = path == null ? appText('export_cancelled') : appText('export_success');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(appText('export_failed').replaceAll('{error}', error.toString()))));
    }
  }

  Future<void> _importData(BuildContext context) async {
    final confirmed = await showLooplyDialog<bool>(
      context: context,
      title: appText('import_data'),
      icon: AppIcons.fileArrowUp,
      content: Text(appText('import_confirmation')),
      actions: <LooplyDialogAction<bool>>[
        LooplyDialogAction<bool>(label: appText('cancel'), value: false),
        LooplyDialogAction<bool>(label: appText('continue'), value: true, isPrimary: true),
      ],
    );
    if (confirmed != true || !context.mounted) return;
    try {
      final imported = await LooplyDataTransfer.importFromFile();
      if (!context.mounted) return;
      if (imported) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(appText('import_success'))));
      }
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(appText('import_failed').replaceAll('{error}', error.toString()))));
    }
  }

  void _openLibraryPage(BuildContext context, Widget page) {
    Navigator.of(context).push(CupertinoPageRoute<void>(builder: (_) => page));
  }

  String _themeLabel(ThemeMode mode, bool pureBlack) => switch (mode) { ThemeMode.light => appText('light'), ThemeMode.dark => pureBlack ? appText('deep_dark') : appText('dark'), _ => appText('automatic') };


}

// Card de conta no topo da Settings — é o único caminho para o ecrã
// de Perfil (sem sessão, vai para o ecrã de autenticação).
class _AccountSummaryCard extends StatelessWidget {
  const _AccountSummaryCard({required this.user});

  final LooplyUser? user;

  @override
  Widget build(BuildContext context) {
    final text = mainText(context);
    final muted = mutedText(context);
    final name = user?.displayName?.trim().isNotEmpty == true ? user!.displayName! : 'Utilizador BrowseIt';
    final subtitle = user?.email ?? 'Toca para iniciar sessão';

    return Material(
      color: settingsCardColor(context),
      borderRadius: BorderRadius.circular(22),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          final page = user == null ? const AuthScreen() : const ProfileScreen();
          Navigator.of(context).push<void>(
            CupertinoPageRoute<void>(builder: (_) => page),
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: pillColor(context),
                foregroundImage: user?.photoUrl != null
                    ? NetworkImage(user!.photoUrl!)
                    : const AssetImage('images/avatar.png') as ImageProvider,
                child: null,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: text, fontSize: 15.5, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: muted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              AppMaterialIcon(AppIcons.caretRight, color: muted, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 9),
          child: Text(
            title,
            style: TextStyle(
              color: mutedText(context),
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              letterSpacing: .15,
            ),
          ),
        ),
        ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: SizedBox(
            width: double.infinity,
            // Os itens continuam a ser os cards segmentados M3 Expressive.
            // Só se desativa o foco de teclado nesta lista táctil para impedir
            // que o switch deixe um contorno azul persistente no card inteiro.
            child: ExcludeFocus(
              child: M3ESegmentedColumn(
                children: children,
                color: settingsCardColor(context),
                outerRadius: 22,
                innerRadius: 8,
                gap: 2,
                padding: EdgeInsets.zero,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SettingsValue extends StatelessWidget {
  const _SettingsValue(this.value);
  final String value;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 112),
      child: Text(
        value,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.end,
        style: TextStyle(
          color: mutedText(context),
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.label,
    this.onTap,
    this.trailing,
    this.subtitle,
    this.showChevron = true,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final Widget? trailing;
  final String? subtitle;
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    final text = mainText(context);
    final muted = mutedText(context);
    final iconColor = text;
    final iconBadge = pillColor(context);

    return SizedBox(
      width: double.infinity,
      child: InkWell(
        onTap: onTap,
        canRequestFocus: false,
        focusColor: Colors.transparent,
        hoverColor: Colors.transparent,
        overlayColor: WidgetStateProperty.resolveWith<Color?>((states) {
          if (states.contains(WidgetState.focused)) return Colors.transparent;
          return null;
        }),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: subtitle == null ? 52 : 64),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: iconBadge,
                  ),
                  alignment: Alignment.center,
                  child: AppMaterialIcon(icon, color: iconColor, size: 19),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: text,
                          fontSize: 14,
                          height: 1.15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          subtitle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: muted,
                            fontSize: 11.5,
                            height: 1.1,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (trailing != null) ...[
                  const SizedBox(width: 8),
                  Flexible(
                    fit: FlexFit.loose,
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: trailing!,
                    ),
                  ),
                ],
                if (showChevron) ...[
                  const SizedBox(width: 6),
                  AppMaterialIcon(AppIcons.caretRight, color: muted, size: 18),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DefaultBrowserSettingsTile extends StatefulWidget {
  const _DefaultBrowserSettingsTile();

  @override
  State<_DefaultBrowserSettingsTile> createState() => _DefaultBrowserSettingsTileState();
}

class _DefaultBrowserSettingsTileState extends State<_DefaultBrowserSettingsTile> with WidgetsBindingObserver {
  static const MethodChannel _channel = MethodChannel('looply/native_ui');
  Future<bool> _status = Future<bool>.value(false);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _status = _queryStatus();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<bool> _queryStatus() => _channel
      .invokeMethod<bool>('isDefaultBrowser')
      .then((value) => value ?? false)
      .catchError((_) => false);

  void _refresh() {
    if (!mounted) return;
    setState(() => _status = _queryStatus());
  }

  Future<void> _requestDefaultBrowser() async {
    try {
      final launched = await _channel.invokeMethod<bool>('requestDefaultBrowser') ?? false;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(launched
            ? 'Escolhe BrowseIt no ecrã do Android para o tornar o navegador padrão.'
            : 'Este dispositivo não disponibiliza a seleção de navegador padrão por esta API.'),
      ));
      _refresh();
    } on PlatformException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message ?? 'Não foi possível abrir as definições do Android.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _status,
      builder: (context, snapshot) => _SettingsTile(
        icon: AppIcons.globe,
        label: appText('default_browser'),
        subtitle: snapshot.data == true ? appText('browser_default_yes') : appText('browser_default_no'),
        trailing: snapshot.data == true
            ? AppMaterialIcon(AppIcons.checkCircle, color: mainText(context), size: 21)
            : null,
        showChevron: true,
        onTap: _requestDefaultBrowser,
      ),
    );
  }
}
