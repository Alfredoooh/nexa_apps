import 'package:flutter/material.dart';

// Paleta do Looply. Mantém superfícies neutras e um único tom de destaque.
const Color looplyPrimary = Color(0xFF2596BE);

const Color looplyBgLight = Color(0xFFF8F9FA);
const Color looplySoftLight = Color(0xFFF0F2F4);
const Color looplyPanelLight = Color(0xFFFFFFFF);

const Color looplyBgDark = Color(0xFF101214);
const Color looplySoftDark = Color(0xFF181B1E);
const Color looplyPanelDark = Color(0xFF1D2125);
const Color looplyPanel2Dark = Color(0xFF252A2F);

class LooplyThemeController extends ValueNotifier<ThemeMode> {
  LooplyThemeController() : super(ThemeMode.system);

  void setMode(ThemeMode mode) {
    if (value == mode) return;
    value = mode;
  }
}

final LooplyThemeController themeController = LooplyThemeController();

ThemeData buildLooplyTheme(Brightness brightness) {
  final isDark = brightness == Brightness.dark;
  final background = isDark ? looplyBgDark : looplyBgLight;
  final surface = isDark ? looplyPanelDark : looplyPanelLight;
  final foreground = isDark ? const Color(0xFFF4F5F6) : const Color(0xFF1C1C1E);
  final muted = isDark ? const Color(0xFFA1A7AD) : const Color(0xFF6E6E73);
  final outline = isDark ? const Color(0xFF30363B) : const Color(0xFFE4E7E9);

  final scheme = ColorScheme.fromSeed(
    seedColor: looplyPrimary,
    brightness: brightness,
    surface: surface,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme.copyWith(
      primary: looplyPrimary,
      onPrimary: Colors.white,
      surface: surface,
      onSurface: foreground,
      outline: outline,
    ),
    scaffoldBackgroundColor: background,
    canvasColor: background,
    dividerColor: outline,
    splashColor: looplyPrimary.withOpacity(.08),
    highlightColor: looplyPrimary.withOpacity(.04),
    appBarTheme: AppBarTheme(
      backgroundColor: background,
      foregroundColor: foreground,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: foreground,
        fontSize: 20,
        fontWeight: FontWeight.w700,
      ),
      iconTheme: IconThemeData(color: foreground),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: surface,
      surfaceTintColor: Colors.transparent,
      indicatorColor: looplyPrimary.withOpacity(isDark ? .22 : .14),
      elevation: 0,
      labelTextStyle: WidgetStateProperty.resolveWith<TextStyle?>((states) {
        return TextStyle(
          color: states.contains(WidgetState.selected) ? looplyPrimary : muted,
          fontSize: 11,
          fontWeight: states.contains(WidgetState.selected)
              ? FontWeight.w700
              : FontWeight.w500,
        );
      }),
      iconTheme: WidgetStateProperty.resolveWith<IconThemeData?>((states) {
        return IconThemeData(
          color: states.contains(WidgetState.selected) ? looplyPrimary : muted,
        );
      }),
    ),
    listTileTheme: ListTileThemeData(
      iconColor: muted,
      textColor: foreground,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14),
    ),
    textSelectionTheme: const TextSelectionThemeData(
      cursorColor: looplyPrimary,
      selectionColor: Color(0x552596BE),
      selectionHandleColor: looplyPrimary,
    ),
  );
}

bool _isDark(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark;

Color mainText(BuildContext context) => _isDark(context)
    ? const Color(0xFFF4F5F6)
    : const Color(0xFF1C1C1E);

Color mutedText(BuildContext context) => _isDark(context)
    ? const Color(0xFFA1A7AD)
    : const Color(0xFF6E6E73);

Color pageBg(BuildContext context) =>
    _isDark(context) ? looplyBgDark : looplyBgLight;

Color panelColor(BuildContext context) =>
    _isDark(context) ? looplyPanelDark : looplyPanelLight;

Color pillColor(BuildContext context) =>
    _isDark(context) ? looplySoftDark : looplySoftLight;

Color softColor(BuildContext context) =>
    _isDark(context) ? looplyPanel2Dark : const Color(0xFFE9EDF0);

Color lineColor(BuildContext context) => _isDark(context)
    ? const Color(0xFF30363B)
    : const Color(0xFFE4E7E9);

Color accentColor(BuildContext context) => looplyPrimary;

Color settingsCardColor(BuildContext context) => _isDark(context)
    ? looplyPanel2Dark
    : const Color(0xFFF1F3F5);

Color browserBottomBarColor(BuildContext context) =>
    _isDark(context) ? looplyPanelDark : Colors.white;

Color panelForMode(BuildContext context, ThemeMode mode) =>
    _colorForMode(context, mode, looplyPanelLight, looplyPanelDark);

Color textForMode(BuildContext context, ThemeMode mode) => _colorForMode(
      context,
      mode,
      const Color(0xFF1C1C1E),
      const Color(0xFFF4F5F6),
    );

Color mutedForMode(BuildContext context, ThemeMode mode) => _colorForMode(
      context,
      mode,
      const Color(0xFF6E6E73),
      const Color(0xFFA1A7AD),
    );

Color accentForMode(BuildContext context, ThemeMode mode) => looplyPrimary;

Color pillForMode(BuildContext context, ThemeMode mode) => _colorForMode(
      context,
      mode,
      looplySoftLight,
      looplySoftDark,
    );

Color _colorForMode(
  BuildContext context,
  ThemeMode mode,
  Color light,
  Color dark,
) {
  final useDark = switch (mode) {
    ThemeMode.dark => true,
    ThemeMode.light => false,
    ThemeMode.system => MediaQuery.platformBrightnessOf(context) == Brightness.dark,
  };
  return useDark ? dark : light;
}
