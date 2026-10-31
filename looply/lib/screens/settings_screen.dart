import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../models.dart';
import '../theme.dart';
import '../widgets/drawer_menu.dart';
import '../widgets/m3_switch.dart';

// Cards de Settings usam o tom do inputbar no tema escuro e um
// cinza-branco no tema claro (settingsCardColor), em vez de
// panelColor, para se destacarem mais do fundo.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final muted = mutedText(context);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: Theme.of(context).brightness == Brightness.dark
          ? SystemUiOverlayStyle.light.copyWith(statusBarColor: pageBg(context), statusBarIconBrightness: Brightness.light)
          : SystemUiOverlayStyle.dark.copyWith(statusBarColor: pageBg(context), statusBarIconBrightness: Brightness.dark),
      child: Scaffold(
        backgroundColor: pageBg(context),
        appBar: AppBar(toolbarHeight: 64, title: const Text('Configurações')),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            Padding(padding: const EdgeInsets.fromLTRB(4, 4, 4, 10), child: Text('Geral', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: muted))),
            _SettingsTile(
              icon: Symbols.dark_mode_rounded,
              label: 'Tema',
              trailing: ValueListenableBuilder<ThemeMode>(valueListenable: themeController, builder: (_, mode, __) => Text(_themeLabel(mode), style: TextStyle(color: mutedText(context), fontSize: 12))),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24), bottom: Radius.circular(8)),
              onTap: () => showThemeSheet(context),
            ),
            const SizedBox(height: 2),
            ValueListenableBuilder<SearchEngine>(
              valueListenable: activeSearchEngine,
              builder: (context, engine, _) => _SettingsTile(
                icon: Symbols.travel_explore_rounded,
                label: 'Motor de pesquisa',
                trailing: Text(engine.name, style: TextStyle(color: mutedText(context), fontSize: 12)),
                borderRadius: BorderRadius.circular(8),
                onTap: () => _showEnginePicker(context),
              ),
            ),
            const SizedBox(height: 2),
            _SettingsTile(
              icon: Symbols.language_rounded,
              label: 'Idioma',
              trailing: Text('Português', style: TextStyle(color: muted, fontSize: 12)),
              borderRadius: BorderRadius.circular(8),
              onTap: () => _showLanguageInfo(context),
            ),
            const SizedBox(height: 2),
            ValueListenableBuilder<bool>(
              valueListenable: adBlockEnabled,
              builder: (context, enabled, _) => _SettingsTile(
                icon: Symbols.shield_rounded,
                label: 'Bloqueador de anúncios',
                subtitle: enabled ? 'Ativado' : 'Desativado',
                trailing: M3ExpressiveSwitch(value: enabled, onChanged: (value) => adBlockEnabled.value = value),
                showChevron: false,
                borderRadius: BorderRadius.circular(8),
                onTap: () => adBlockEnabled.value = !adBlockEnabled.value,
              ),
            ),
            const SizedBox(height: 2),
            ValueListenableBuilder<bool>(
              valueListenable: navigationAcceleratorEnabled,
              builder: (context, enabled, _) => _SettingsTile(
                icon: Symbols.speed_rounded,
                label: 'Acelerador de navegação',
                subtitle: enabled ? 'Pré-ligação e cache ativos' : 'Pré-ligação e cache desativados',
                trailing: M3ExpressiveSwitch(value: enabled, onChanged: (value) => navigationAcceleratorEnabled.value = value),
                showChevron: false,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(8), bottom: Radius.circular(24)),
                onTap: () => navigationAcceleratorEnabled.value = !navigationAcceleratorEnabled.value,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _themeLabel(ThemeMode mode) => switch (mode) { ThemeMode.light => 'Claro', ThemeMode.dark => 'Escuro', _ => 'Automático' };

  void _showEnginePicker(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      elevation: 0,
      showDragHandle: false,
      useSafeArea: true,
      builder: (sheetContext) => ValueListenableBuilder<ThemeMode>(
        valueListenable: themeController,
        builder: (context, mode, _) => Material(
          color: panelForMode(context, mode),
          surfaceTintColor: Colors.transparent,
          clipBehavior: Clip.antiAlias,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
          child: SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
            const SizedBox(height: 12),
            Container(width: 32, height: 4, decoration: BoxDecoration(color: mutedForMode(context, mode).withOpacity(.45), borderRadius: BorderRadius.circular(99))),
            Padding(padding: const EdgeInsets.fromLTRB(20, 12, 20, 8), child: Align(alignment: Alignment.centerLeft, child: Text('Motor de pesquisa', style: TextStyle(color: textForMode(context, mode), fontSize: 17, fontWeight: FontWeight.w800)))),
            ...searchEngines.map((engine) => ListTile(
              leading: Container(
                width: 34,
                height: 34,
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(shape: BoxShape.circle, color: pillForMode(context, mode)),
                child: engine.assetPath != null
                    ? Image.asset(
                        engine.assetPath!,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => Icon(Symbols.public_rounded, color: mutedForMode(context, mode), size: 18),
                      )
                    : Icon(Icons.eco_rounded, color: const Color(0xFF4CAF50), size: 20),
              ),
              title: Text(engine.name, style: TextStyle(color: textForMode(context, mode))),
              trailing: ValueListenableBuilder<SearchEngine>(valueListenable: activeSearchEngine, builder: (_, active, __) => active.name == engine.name ? Icon(Symbols.check_circle_rounded, color: accentForMode(context, mode), fill: 1) : const SizedBox.shrink()),
              onTap: () { activeSearchEngine.select(engine); Navigator.of(sheetContext).pop(); },
            )),
          ])),
        ),
      ),
    );
  }

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

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({required this.icon, required this.label, this.onTap, this.trailing, this.subtitle, this.borderRadius, this.showChevron = true});
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final Widget? trailing;
  final String? subtitle;
  final BorderRadius? borderRadius;
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    final text = mainText(context);
    final muted = mutedText(context);
    final radius = borderRadius ?? BorderRadius.circular(10);
    return Material(
      color: settingsCardColor(context),
      borderRadius: radius,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        borderRadius: radius,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(children: [
            Container(width: 38, height: 38, decoration: BoxDecoration(shape: BoxShape.circle, color: pillColor(context)), child: Icon(icon, color: accentColor(context), size: 19)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text(label, style: TextStyle(color: text, fontSize: 14, fontWeight: FontWeight.w600)),
              if (subtitle != null) ...[const SizedBox(height: 3), Text(subtitle!, style: TextStyle(color: muted, fontSize: 11))],
            ])),
            if (trailing != null) trailing!,
            if (showChevron) Icon(Symbols.chevron_right_rounded, color: muted, size: 18),
          ]),
        ),
      ),
    );
  }
}