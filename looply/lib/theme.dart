import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Paleta escura neutra (sem o azulado anterior) — cinzas verdadeiros,
// não totalmente pretos, mantendo contraste confortável.
const Color looplyPrimary = Color(0xFF1A73E8);
const Color looplyBgDark = Color(0xFF141517);
const Color looplyBgLight = Color(0xFFFFFFFF);
const Color looplyPanelDark = Color(0xFF212325);
const Color looplyPanel2Dark = Color(0xFF2B2D30);
const Color looplySoftDark = Color(0xFF1D1F21);
const Color looplyPanelLight = Color(0xFFFFFFFF);
const Color looplyPanel2Light = Color(0xFFF0F1F3);
const Color looplySoftLight = Color(0xFFF8F9FA);
const Color looplyTextDark = Color(0xFFE6E6E8);
const Color looplyMutedDark = Color(0xFFB2B4B8);
const Color looplyTextLight = Color(0xFF202124);
const Color looplyMutedLight = Color(0xFF5F6368);
const Color looplyLineDark = Color(0xFF34363A);
const Color looplyLineLight = Color(0xFFE8EAED);
const Color looplyBlueDark = Color(0xFF8AB4F8);
const Color looplyBgAmoled = Color(0xFF000000);
const Color looplyPanelAmoled = Color(0xFF101010);
const Color looplyPanel2Amoled = Color(0xFF191919);
const Color looplySoftAmoled = Color(0xFF050505);
const Color looplyLineAmoled = Color(0xFF292929);

// Cor do input bar (usada também nos cards de Settings e no bottom bar,
// só no tema escuro) e a cor "cinza-branco" usada nesses mesmos lugares
// no tema claro.
const Color looplyInputBarDark = looplyPanel2Dark;
const Color looplyInputBarLight = Color(0xFFF0F1F3);
const Color looplySettingsCardLight = Color(0xFFF0F1F3);

bool isPureBlackTheme(BuildContext context) => Theme.of(context).brightness == Brightness.dark && Theme.of(context).scaffoldBackgroundColor == looplyBgAmoled;
Color pageBg(BuildContext context) => Theme.of(context).brightness == Brightness.dark ? (isPureBlackTheme(context) ? looplyBgAmoled : looplyBgDark) : looplyBgLight;
Color panelColor(BuildContext context) => Theme.of(context).brightness == Brightness.dark ? (isPureBlackTheme(context) ? looplyPanelAmoled : looplyPanelDark) : looplyPanelLight;
Color pillColor(BuildContext context) => Theme.of(context).brightness == Brightness.dark ? (isPureBlackTheme(context) ? looplyPanel2Amoled : looplyPanel2Dark) : looplyPanel2Light;
Color softColor(BuildContext context) => Theme.of(context).brightness == Brightness.dark ? (isPureBlackTheme(context) ? looplySoftAmoled : looplySoftDark) : looplySoftLight;
Color mainText(BuildContext context) => Theme.of(context).brightness == Brightness.dark ? looplyTextDark : looplyTextLight;
Color mutedText(BuildContext context) => Theme.of(context).brightness == Brightness.dark ? looplyMutedDark : looplyMutedLight;
Color accentColor(BuildContext context) => Theme.of(context).brightness == Brightness.dark ? looplyBlueDark : looplyPrimary;
Color lineColor(BuildContext context) => Theme.of(context).brightness == Brightness.dark ? (isPureBlackTheme(context) ? looplyLineAmoled : looplyLineDark) : looplyLineLight;

// Tom do inputbar: usado nos cards de Settings e no bottom bar do browser,
// SOMENTE no tema escuro. No tema claro, Settings usa cinza-branco e o
// bottom bar mantém a cor de página normal (sem alteração).
Color inputBarTone(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark ? (isPureBlackTheme(context) ? looplyPanel2Amoled : looplyInputBarDark) : looplyInputBarLight;

Color settingsCardColor(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark ? (isPureBlackTheme(context) ? looplyPanel2Amoled : looplyInputBarDark) : looplySettingsCardLight;

// O fundo da barra inferior acompanha exatamente o fundo da página em ambos os temas.
Color browserBottomBarColor(BuildContext context) => pageBg(context);

Brightness brightnessForMode(BuildContext context, ThemeMode mode) {
  if (mode == ThemeMode.dark) return Brightness.dark;
  if (mode == ThemeMode.light) return Brightness.light;
  return MediaQuery.platformBrightnessOf(context);
}

Color panelForMode(BuildContext context, ThemeMode mode) =>
    brightnessForMode(context, mode) == Brightness.dark ? (themeController.pureDark.value ? looplyPanelAmoled : looplyPanelDark) : looplyPanelLight;
Color textForMode(BuildContext context, ThemeMode mode) =>
    brightnessForMode(context, mode) == Brightness.dark ? looplyTextDark : looplyTextLight;
Color mutedForMode(BuildContext context, ThemeMode mode) =>
    brightnessForMode(context, mode) == Brightness.dark ? looplyMutedDark : looplyMutedLight;
Color accentForMode(BuildContext context, ThemeMode mode) =>
    brightnessForMode(context, mode) == Brightness.dark ? looplyBlueDark : looplyPrimary;
Color pillForMode(BuildContext context, ThemeMode mode) =>
    brightnessForMode(context, mode) == Brightness.dark ? (themeController.pureDark.value ? looplyPanel2Amoled : looplyPanel2Dark) : looplyPanel2Light;

class ThemeController extends ValueNotifier<ThemeMode> {
  ThemeController() : super(ThemeMode.system);

  static const MethodChannel _nativeUi = MethodChannel('looply/native_ui');

  Future<void> _syncNativeTheme(ThemeMode mode, {bool pureBlack = false}) async {
    final nativeMode = switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      _ => 'system',
    };
    try {
      await _nativeUi.invokeMethod<void>('setAppThemeMode', <String, Object>{
        'mode': nativeMode,
        'pureBlack': pureBlack,
      });
    } catch (_) {
      // Plataformas sem o canal Android continuam a usar o tema Flutter.
    }
  }

  final ValueNotifier<bool> pureDark = ValueNotifier<bool>(false);

  Future<void> restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString('looply_theme_mode');
      value = switch (saved) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };
      pureDark.value = value == ThemeMode.dark && (prefs.getBool('looply_theme_pure_dark') ?? false);
      unawaited(_syncNativeTheme(value, pureBlack: pureDark.value));
    } catch (_) {}
  }

  void setMode(ThemeMode mode) {
    value = mode;
    // Selecionar "Escuro" volta sempre ao tema escuro normal; o preto puro
    // só fica ativo quando o utilizador escolhe explicitamente a opção AMOLED.
    pureDark.value = false;
    unawaited(_persist(mode));
    unawaited(_syncNativeTheme(mode));
  }

  void setPureDark(bool enabled) {
    pureDark.value = enabled;
    value = ThemeMode.dark;
    unawaited(_persist(ThemeMode.dark));
    unawaited(_syncNativeTheme(ThemeMode.dark, pureBlack: enabled));
  }

  Future<void> _persist(ThemeMode mode) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('looply_theme_mode', switch (mode) {
        ThemeMode.light => 'light',
        ThemeMode.dark => 'dark',
        _ => 'system',
      });
      await prefs.setBool('looply_theme_pure_dark', pureDark.value);
    } catch (_) {}
  }
}


final ThemeController themeController = ThemeController();

ThemeData buildLooplyTheme(Brightness brightness, {bool pureBlack = false}) {
  final isDark = brightness == Brightness.dark;
  final bg = isDark ? (pureBlack ? looplyBgAmoled : looplyBgDark) : looplyBgLight;
  final panel = isDark ? (pureBlack ? looplyPanelAmoled : looplyPanelDark) : looplyPanelLight;
  final pill = isDark ? (pureBlack ? looplyPanel2Amoled : looplyPanel2Dark) : looplyPanel2Light;
  final text = isDark ? looplyTextDark : looplyTextLight;
  final muted = isDark ? looplyMutedDark : looplyMutedLight;
  final accent = isDark ? looplyBlueDark : looplyPrimary;
  final scheme = ColorScheme.fromSeed(seedColor: looplyPrimary, brightness: brightness, surface: panel).copyWith(primary: accent);

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: bg,
    canvasColor: panel,
    splashFactory: NoSplash.splashFactory,
    splashColor: Colors.transparent,
    highlightColor: Colors.transparent,
    dividerColor: isDark ? (pureBlack ? looplyLineAmoled : looplyLineDark) : looplyLineLight,
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: isDark
          ? (pureBlack ? const Color(0xFF292929) : const Color(0xFF3A3C40))
          : const Color(0xFFF1F3F4),
      contentTextStyle: TextStyle(
        color: isDark ? const Color(0xFFFFFFFF) : const Color(0xFF202124),
        fontSize: 13.5,
        fontWeight: FontWeight.w500,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
      insetPadding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
      elevation: 6,
      showCloseIcon: false,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: bg,
      foregroundColor: text,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      systemOverlayStyle: isDark
          ? SystemUiOverlayStyle.light.copyWith(statusBarColor: Colors.transparent, statusBarIconBrightness: Brightness.light, statusBarBrightness: Brightness.dark, systemNavigationBarColor: bg, systemNavigationBarIconBrightness: Brightness.light)
          : SystemUiOverlayStyle.dark.copyWith(statusBarColor: Colors.transparent, statusBarIconBrightness: Brightness.dark, statusBarBrightness: Brightness.light, systemNavigationBarColor: bg, systemNavigationBarIconBrightness: Brightness.dark),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: bg,
      indicatorColor: accent.withOpacity(0.15),
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      height: 68,
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return TextStyle(fontSize: 12, fontWeight: selected ? FontWeight.w600 : FontWeight.w400, color: selected ? text : muted);
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) => IconThemeData(color: states.contains(WidgetState.selected) ? text : muted)),
    ),
    textTheme: TextTheme(
      headlineSmall: TextStyle(color: text, fontWeight: FontWeight.w800),
      titleLarge: TextStyle(color: text, fontWeight: FontWeight.w800),
      titleMedium: TextStyle(color: text, fontWeight: FontWeight.w700),
      bodyLarge: TextStyle(color: text),
      bodyMedium: TextStyle(color: text),
      bodySmall: TextStyle(color: muted),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: pill,
      hintStyle: TextStyle(color: muted),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(28), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(28), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(28), borderSide: BorderSide.none),
    ),
  );
}
