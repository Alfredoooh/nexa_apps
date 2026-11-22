import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Paleta escura neutra (sem o azulado anterior) — cinzas verdadeiros,
// não totalmente pretos, mantendo contraste confortável.
const Color looplyPrimary = Color(0xFF1A73E8);
const Color looplyBgDark = Color(0xFF0F0F0F);
const Color looplyBgLight = Color(0xFFFFFFFF);
const Color looplyPanelDark = Color(0xFF1C1D1E);
const Color looplyPanel2Dark = Color(0xFF262728);
const Color looplySoftDark = Color(0xFF141516);
const Color looplyPanelLight = Color(0xFFFFFFFF);
const Color looplyPanel2Light = Color(0xFFF0F1F3);
const Color looplySoftLight = Color(0xFFF8F9FA);
const Color looplyTextDark = Color(0xFFF5F5F5);
const Color looplyMutedDark = Color(0xFFA8A8A8);
const Color looplyTextLight = Color(0xFF202124);
const Color looplyMutedLight = Color(0xFF5F6368);
const Color looplyLineDark = Color(0xFF343536);
const Color looplyLineLight = Color(0xFFE8EAED);
const Color looplyBlueDark = Color(0xFF0095F6);
const Color looplyBgAmoled = Color(0xFF000000);
const Color looplyPanelAmoled = Color(0xFF121212);
const Color looplyPanel2Amoled = Color(0xFF262626);
const Color looplySoftAmoled = Color(0xFF0B0B0B);
const Color looplyLineAmoled = Color(0xFF363636);

// Cor do input bar (usada também nos cards de Settings e no bottom bar,
// só no tema escuro) e a cor "cinza-branco" usada nesses mesmos lugares
// no tema claro.
const Color looplyInputBarDark = looplyPanelDark;
const Color looplyInputBarLight = Color(0xFFF0F1F3);
const Color looplySettingsCardLight = Color(0xFFF0F1F3);

bool isPureBlackTheme(BuildContext context) => Theme.of(context).brightness == Brightness.dark && Theme.of(context).scaffoldBackgroundColor == looplyBgAmoled;
Color pageBg(BuildContext context) => Theme.of(context).brightness == Brightness.dark ? (isPureBlackTheme(context) ? looplyBgAmoled : looplyBgDark) : looplyBgLight;
Color panelColor(BuildContext context) => Theme.of(context).brightness == Brightness.dark ? (isPureBlackTheme(context) ? looplyPanelAmoled : looplyPanelDark) : looplyPanelLight;
// Popup surface is intentionally identical to Orbit Browser's native menu:
// white in light mode, charcoal in dark mode and AMOLED black in pure-black.
Color popupSurfaceColor(BuildContext context) => Theme.of(context).brightness == Brightness.dark
    ? (isPureBlackTheme(context) ? looplyPanelAmoled : looplyPanelDark)
    : Colors.white;
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
    Theme.of(context).brightness == Brightness.dark ? (isPureBlackTheme(context) ? looplyPanel2Amoled : looplyPanelDark) : looplySettingsCardLight;

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
  final scheme = ColorScheme.fromSeed(
    seedColor: looplyPrimary,
    brightness: brightness,
    surface: panel,
  ).copyWith(
    primary: accent,
    onPrimary: isDark ? const Color(0xFF071A31) : Colors.white,
    secondary: accent,
    onSecondary: isDark ? const Color(0xFF071A31) : Colors.white,
    tertiary: accent,
    onTertiary: isDark ? const Color(0xFF071A31) : Colors.white,
    primaryContainer: accent.withOpacity(isDark ? .24 : .12),
    secondaryContainer: accent.withOpacity(isDark ? .24 : .12),
    tertiaryContainer: accent.withOpacity(isDark ? .24 : .12),
  );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    iconTheme: const IconThemeData(size: 24, weight: 400, opticalSize: 24),
    colorScheme: scheme,
    scaffoldBackgroundColor: bg,
    canvasColor: panel,
    splashFactory: NoSplash.splashFactory,
    splashColor: Colors.transparent,
    highlightColor: Colors.transparent,
    focusColor: Colors.transparent,
    hoverColor: Colors.transparent,
    dividerColor: isDark ? (pureBlack ? looplyLineAmoled : looplyLineDark) : looplyLineLight,
    dialogTheme: DialogThemeData(
      backgroundColor: isDark ? panel : Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      titleTextStyle: TextStyle(color: text, fontSize: 19, fontWeight: FontWeight.w600),
      contentTextStyle: TextStyle(color: text, fontSize: 14, height: 1.4),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: isDark ? (pureBlack ? looplyPanelAmoled : looplyPanelDark) : Colors.white,
      elevation: 20,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
    ),
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
          ? SystemUiOverlayStyle.light.copyWith(statusBarColor: Colors.transparent, statusBarIconBrightness: Brightness.light, statusBarBrightness: Brightness.dark, systemNavigationBarColor: bg, systemNavigationBarIconBrightness: Brightness.light, systemNavigationBarDividerColor: bg, systemNavigationBarContrastEnforced: false)
          : SystemUiOverlayStyle.dark.copyWith(statusBarColor: Colors.transparent, statusBarIconBrightness: Brightness.dark, statusBarBrightness: Brightness.light, systemNavigationBarColor: bg, systemNavigationBarIconBrightness: Brightness.dark, systemNavigationBarDividerColor: bg, systemNavigationBarContrastEnforced: false),
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
      iconTheme: WidgetStateProperty.resolveWith((states) => IconThemeData(
        color: states.contains(WidgetState.selected) ? text : muted,
        size: 24,
        weight: 400,
        opticalSize: 24,
      )),
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
      isDense: false,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      hintStyle: TextStyle(color: muted, height: 1.25),
      labelStyle: TextStyle(color: muted, height: 1.2),
      floatingLabelStyle: TextStyle(color: accent, height: 1.2, fontWeight: FontWeight.w600),
      helperMaxLines: 3,
      errorMaxLines: 3,
      prefixIconConstraints: const BoxConstraints(minWidth: 48, minHeight: 48),
      suffixIconConstraints: const BoxConstraints(minWidth: 48, minHeight: 48),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(28), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(28), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(28), borderSide: BorderSide.none),
      errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(28), borderSide: BorderSide.none),
      focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(28), borderSide: BorderSide.none),
    ),
  );
}
