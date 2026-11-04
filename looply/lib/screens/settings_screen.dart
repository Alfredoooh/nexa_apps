import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../models.dart';
import '../browser_library.dart';
import 'bookmarks_screen.dart';
import 'downloads_screen.dart';
import 'history_screen.dart';
import '../theme.dart';
import '../widgets/drawer_menu.dart';
import '../widgets/m3_switch.dart';
import '../widgets/search_engine_picker.dart';
import '../data_transfer.dart';
import '../auth_service.dart';
import 'auth_screen.dart';
import 'profile_screen.dart';

// Cards de Settings usam o tom do inputbar no tema escuro e um
// cinza-branco no tema claro (settingsCardColor), em vez de
// panelColor, para se destacarem mais do fundo.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: Theme.of(context).brightness == Brightness.dark
          ? SystemUiOverlayStyle.light.copyWith(statusBarColor: Colors.transparent, statusBarIconBrightness: Brightness.light)
          : SystemUiOverlayStyle.dark.copyWith(statusBarColor: Colors.transparent, statusBarIconBrightness: Brightness.dark),
      child: Scaffold(
        backgroundColor: pageBg(context),
        appBar: AppBar(
            toolbarHeight: 64,
            title: const Text('Configurações'),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: ValueListenableBuilder<LooplyUser?>(
                  valueListenable: authController,
                  builder: (context, user, _) => Material(
                    color: pillColor(context),
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () {
                        final page = user == null ? const AuthScreen() : const ProfileScreen();
                        Navigator.of(context).push<void>(_AccountSlideRoute(page));
                      },
                      child: SizedBox(
                        width: 42,
                        height: 42,
                        child: ClipOval(
                          child: user?.photoUrl != null
                              ? Image.network(user!.photoUrl!, fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Icon(Symbols.person_rounded, color: mainText(context), size: 22))
                              : Icon(Symbols.person_rounded, color: mainText(context), size: 22),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            ValueListenableBuilder<LooplyUser?>(
              valueListenable: authController,
              builder: (context, user, _) => _AccountSummaryHeader(user: user),
            ),
            const SizedBox(height: 22),
            _SettingsSection(
              title: 'Aparência e idioma',
              children: [
                _SettingsTile(
                  icon: Symbols.dark_mode_rounded,
                  label: 'Tema',
                  trailing: ValueListenableBuilder<ThemeMode>(
                    valueListenable: themeController,
                    builder: (_, mode, __) => ValueListenableBuilder<bool>(
                      valueListenable: themeController.pureDark,
                      builder: (_, pureBlack, __) => _SettingsValue(_themeLabel(mode, pureBlack)),
                    ),
                  ),
                  onTap: () => showThemeSheet(context),
                ),
                _SettingsTile(
                  icon: Symbols.language_rounded,
                  label: 'Idioma',
                  trailing: const _SettingsValue('Português'),
                  onTap: () => _showLanguageInfo(context),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _SettingsSection(
              title: 'Navegação',
              children: [
                ValueListenableBuilder<SearchEngine>(
                  valueListenable: activeSearchEngine,
                  builder: (context, engine, _) => _SettingsTile(
                    icon: Symbols.travel_explore_rounded,
                    label: 'Máquina de pesquisa',
                    trailing: _SettingsValue(engine.name),
                    onTap: () => showSearchEnginePicker(context),
                  ),
                ),
                const _DefaultBrowserSettingsTile(),
                ValueListenableBuilder<bool>(
                  valueListenable: adBlockEnabled,
                  builder: (context, enabled, _) => _SettingsTile(
                    icon: Symbols.shield_rounded,
                    label: 'Bloqueador de anúncios',
                    subtitle: enabled ? 'Ativado' : 'Desativado',
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
                    icon: Symbols.speed_rounded,
                    label: 'Acelerador de navegação',
                    subtitle: enabled
                        ? 'Pré-ligação e cache ativos'
                        : 'Pré-ligação e cache desativados',
                    trailing: M3ExpressiveSwitch(
                      value: enabled,
                      onChanged: (value) => navigationAcceleratorEnabled.value = value,
                    ),
                    showChevron: false,
                    onTap: () => navigationAcceleratorEnabled.value = !navigationAcceleratorEnabled.value,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _SettingsSection(
              title: 'Biblioteca',
              children: [
                AnimatedBuilder(
                  animation: activityController,
                  builder: (context, _) => _SettingsTile(
                    icon: Symbols.history_rounded,
                    label: 'Histórico de navegação',
                    subtitle: '${activityController.entries.length} registos guardados',
                    onTap: () => _openLibraryPage(context, const HistoryScreen()),
                  ),
                ),
                AnimatedBuilder(
                  animation: downloadsController,
                  builder: (context, _) => _SettingsTile(
                    icon: Symbols.download_rounded,
                    label: 'Downloads',
                    subtitle: '${downloadsController.entries.length} pedidos registados',
                    onTap: () => _openLibraryPage(context, const DownloadsScreen()),
                  ),
                ),
                AnimatedBuilder(
                  animation: bookmarksController,
                  builder: (context, _) => _SettingsTile(
                    icon: Symbols.bookmarks_rounded,
                    label: 'Marcadores',
                    subtitle: '${bookmarksController.entries.length} páginas guardadas',
                    onTap: () => _openLibraryPage(context, const BookmarksScreen()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _SettingsSection(
              title: 'Dados',
              children: [
                _SettingsTile(
                  icon: Symbols.upload_rounded,
                  label: 'Exportar dados',
                  subtitle: 'Guardar histórico e definições num ficheiro JSON',
                  onTap: () => _exportData(context),
                ),
                _SettingsTile(
                  icon: Symbols.download_rounded,
                  label: 'Importar dados',
                  subtitle: 'Restaurar um backup JSON do BrowseIt',
                  onTap: () => _importData(context),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _exportData(BuildContext context) async {
    try {
      final path = await LooplyDataTransfer.exportToFile();
      if (!context.mounted) return;
      final message = path == null ? 'Exportação cancelada.' : 'Backup exportado com sucesso.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Não foi possível exportar: $error')));
    }
  }

  Future<void> _importData(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Importar dados'),
        content: const Text('Os dados atuais do BrowseIt serão substituídos pelos dados do backup. A sessão de autenticação será mantida.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: const Text('Continuar')),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      final imported = await LooplyDataTransfer.importFromFile();
      if (!context.mounted) return;
      if (imported) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Dados importados com sucesso.')));
      }
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Não foi possível importar: $error')));
    }
  }

  void _openLibraryPage(BuildContext context, Widget page) {
    Navigator.of(context).push(CupertinoPageRoute<void>(builder: (_) => page));
  }

  String _themeLabel(ThemeMode mode, bool pureBlack) => switch (mode) { ThemeMode.light => 'Claro', ThemeMode.dark => pureBlack ? 'Escuro profundo' : 'Escuro', _ => 'Automático' };


  void _showLanguageInfo(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      elevation: 0,
      showDragHandle: false,
      builder: (sheetContext) => ValueListenableBuilder<ThemeMode>(
        valueListenable: themeController,
        builder: (context, mode, _) => Material(
          color: panelForMode(context, mode),
          surfaceTintColor: Colors.transparent,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            child: Text('O idioma disponível nesta versão é Português.', style: TextStyle(color: textForMode(context, mode), fontSize: 14)),
          ),
          ),
        ),
    );
  }
}

class _AccountSummaryHeader extends StatelessWidget {
  const _AccountSummaryHeader({required this.user});

  final LooplyUser? user;

  @override
  Widget build(BuildContext context) {
    final text = mainText(context);
    final muted = mutedText(context);
    final name = user?.displayName?.trim().isNotEmpty == true ? user!.displayName! : 'Utilizador BrowseIt';
    final subtitle = user?.email ?? 'Sem sessão iniciada';

    return Material(
      color: settingsCardColor(context),
      borderRadius: BorderRadius.circular(22),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          final page = user == null ? const AuthScreen() : const ProfileScreen();
          Navigator.of(context).push<void>(_AccountSlideRoute(page));
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: pillColor(context),
                foregroundImage: user?.photoUrl == null ? null : NetworkImage(user!.photoUrl!),
                child: user?.photoUrl == null
                    ? Icon(Symbols.person_rounded, size: 24, color: muted)
                    : null,
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
              Icon(Symbols.chevron_right_rounded, color: muted, size: 20),
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
        SizedBox(
          width: double.infinity,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var index = 0; index < children.length; index++) ...[
                Material(
                  color: settingsCardColor(context),
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(index == 0 ? 22 : 8),
                    bottom: Radius.circular(index == children.length - 1 ? 22 : 8),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: children[index],
                ),
                if (index != children.length - 1) const SizedBox(height: 2),
              ],
            ],
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
    final iconColor = accentColor(context);
    final iconBadge = pillColor(context);

    return SizedBox(
      width: double.infinity,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: subtitle == null ? 58 : 68),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: iconBadge,
                  ),
                  alignment: Alignment.center,
                  child: Icon(icon, color: iconColor, size: 19),
                ),
                const SizedBox(width: 12),
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
                  Icon(Symbols.chevron_right_rounded, color: muted, size: 18),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}


class _AccountSlideRoute extends PageRouteBuilder<void> {
  _AccountSlideRoute(Widget page)
      : super(
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionDuration: const Duration(milliseconds: 420),
          reverseTransitionDuration: const Duration(milliseconds: 390),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final slide = Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
                .animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic));
            return SlideTransition(position: slide, child: child);
          },
        );
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
        icon: Symbols.public_rounded,
        label: 'Navegador padrão',
        subtitle: snapshot.data == true ? 'BrowseIt é o navegador padrão' : 'Definir BrowseIt como navegador padrão',
        trailing: snapshot.data == true
            ? Icon(Symbols.check_circle_rounded, color: accentColor(context), size: 21)
            : null,
        showChevron: true,
        onTap: _requestDefaultBrowser,
      ),
    );
  }
}