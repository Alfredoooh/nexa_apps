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
        appBar: AppBar(toolbarHeight: 64, title: const Text('Configurações')),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            _SettingsSection(
              title: 'Geral',
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
                ValueListenableBuilder<SearchEngine>(
                  valueListenable: activeSearchEngine,
                  builder: (context, engine, _) => _SettingsTile(
                    icon: Symbols.travel_explore_rounded,
                    label: 'Máquina de pesquisa',
                    trailing: _SettingsValue(engine.name),
                    onTap: () => showSearchEnginePicker(context),
                  ),
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
              title: 'Navegação e segurança',
              children: [
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
                  subtitle: 'Restaurar um backup JSON do Looply',
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
        content: const Text('Os dados atuais do Looply serão substituídos pelos dados do backup. A sessão de autenticação será mantida.'),
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
          child: Material(
            color: settingsCardColor(context),
            borderRadius: BorderRadius.circular(20),
            clipBehavior: Clip.antiAlias,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var index = 0; index < children.length; index++) ...[
                  children[index],
                  if (index != children.length - 1)
                    Padding(
                      padding: const EdgeInsets.only(left: 67, right: 14),
                      child: Divider(
                        height: 1,
                        thickness: .7,
                        color: lineColor(context).withOpacity(.65),
                      ),
                    ),
                ],
              ],
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final iconColor = isDark
        ? Color.lerp(looplyTextDark, looplyBlueDark, .12)!
        : const Color(0xFF444A50);
    final iconBadge = isDark
        ? const Color(0xFF383B40)
        : const Color(0xFFE7E9EC);

    return SizedBox(
      width: double.infinity,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: subtitle == null ? 62 : 72),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: iconBadge,
                  ),
                  alignment: Alignment.center,
                  child: Icon(icon, color: iconColor, size: 20),
                ),
                const SizedBox(width: 13),
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
