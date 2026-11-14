// ══════════════════════════════════════════════════════════════
// FILE: lib/core/theme/colors.dart
// ══════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
// TODO: depende de api_service.dart (split futuro); manter este import para a etapa futura de split.
import '../../services/api_service.dart';


// ══════════════════════════════════════════════════════════════
// PALETA DE CORES PRIMÁRIAS (Pares Claro/Escuro)
// ══════════════════════════════════════════════════════════════

const Color kMicrosoftBlueLight = Color(0xFF0F6CBD);
const Color kMicrosoftBlueDark  = Color(0xFF479EF5);
const Color kDefaultPrimaryColor = kMicrosoftBlueLight;

class FluentColorPair {
  final Color light;
  final Color dark;
  const FluentColorPair(this.light, this.dark);
}

const List<FluentColorPair> kPrimaryColorPairs = [
  FluentColorPair(Color(0xFF1A73E8), Color(0xFF8AB4F8)),
  FluentColorPair(Color(0xFF8764B8), Color(0xFFB4A0FF)),
  FluentColorPair(Color(0xFFC239B3), Color(0xFFE68AD8)),
  FluentColorPair(Color(0xFFD13438), Color(0xFFF1707B)),
  FluentColorPair(Color(0xFFCA5010), Color(0xFFFF8C5A)),
  FluentColorPair(Color(0xFF986F0B), Color(0xFFFFCC66)),
  FluentColorPair(Color(0xFF0B6A0B), Color(0xFF6BCB6B)),
  FluentColorPair(Color(0xFF00767A), Color(0xFF4DD0D6)),
  FluentColorPair(Color(0xFF038387), Color(0xFF3FD9DE)),
  FluentColorPair(Color(0xFF515C6B), Color(0xFF9BA7B4)),
];

// ══════════════════════════════════════════════════════════════
// MODO DE TEMA
// ══════════════════════════════════════════════════════════════

enum AppThemeMode { light, dark, system }

extension AppThemeModeX on AppThemeMode {
  String get storageValue => const {
        AppThemeMode.light:  'light',
        AppThemeMode.dark:   'dark',
        AppThemeMode.system: 'system',
      }[this]!;

  static AppThemeMode fromStorage(String? raw) {
    switch (raw) {
      case 'light':  return AppThemeMode.light;
      case 'dark':   return AppThemeMode.dark;
      case 'system':
      default:       return AppThemeMode.system;
    }
  }
}

class AppColorScheme {
  final bool isDark;
  final int primaryPairIndex;
  const AppColorScheme(this.isDark, [this.primaryPairIndex = 0]);

  FluentColorPair get _pair =>
      kPrimaryColorPairs[primaryPairIndex.clamp(0, kPrimaryColorPairs.length - 1)];

  Color get primary => isDark ? _pair.dark : _pair.light;

  /// Cor primária atual em formato "#RRGGBB", pronta para injetar
  /// no HTML do editor via editorApi.setPrimaryColor(hex). Usa
  /// sempre a variante correta (light/dark) porque lê de `primary`.
  String get primaryColorHex =>
      '#${primary.value.toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';

  Color get onPrimary          => isDark ? _darken(primary, 0.75) : Colors.white;
  Color get primaryContainer   => isDark ? _darken(primary, 0.55) : _lighten(primary, 0.85);
  Color get onPrimaryContainer => isDark ? _lighten(primary, 0.55) : _darken(primary, 0.60);

  // ═══ Cores da bolha do utilizador ═══
  // Tema claro: primária com 16% de opacidade (quase branco tingido
  // com a cor escolhida), texto onSurface para contraste. Tema escuro
  // inalterado.
  Color get userBubbleBg   => isDark ? cardBackground : primary.withOpacity(0.16);
  Color get userBubbleText => onSurface;

  static Color _lighten(Color c, double amount) {
    final hsl = HSLColor.fromColor(c);
    return hsl.withLightness((hsl.lightness + amount).clamp(0.0, 1.0)).toColor();
  }

  static Color _darken(Color c, double amount) {
    final hsl = HSLColor.fromColor(c);
    return hsl.withLightness((hsl.lightness - amount).clamp(0.0, 1.0)).toColor();
  }

  // Superfícies neutras
  Color get surface            => isDark ? const Color(0xFF212325) : const Color(0xFFFFFFFF);
  Color get onSurface          => isDark ? const Color(0xFFE6E6E8) : const Color(0xFF202124);
  Color get onSurfaceVariant   => isDark ? const Color(0xFFB2B4B8) : const Color(0xFF5F6368);
  Color get pageBackground     => isDark ? const Color(0xFF141517) : const Color(0xFFFFFFFF);

  Color get cardBackground     => isDark ? const Color(0xFF2B2D30) : const Color(0xFFF0F1F3);
  Color get floatingSurface    => isDark ? const Color(0xFF212325) : const Color(0xFFFFFFFF);

  Color get outline            => isDark ? const Color(0xFF34363A) : const Color(0xFFE8EAED);
  Color get outlineVariant     => isDark ? const Color(0xFF2B2D30) : const Color(0xFFE8EAED);

  // Cores de estado
  Color get error              => isDark ? const Color(0xFFFF453A) : const Color(0xFFFF3B30);
  Color get onError            => isDark ? const Color(0xFF330705) : const Color(0xFFFFFFFF);
  Color get errorContainer     => isDark ? const Color(0xFF5C1A16) : const Color(0xFFFFD8D5);
  Color get onErrorContainer   => isDark ? const Color(0xFFFFD8D5) : const Color(0xFF5C1A16);

  Color get success            => isDark ? const Color(0xFF30D158) : const Color(0xFF34C759);
  Color get warning            => isDark ? const Color(0xFFFF9F0A) : const Color(0xFFFF9500);

  Color get barrier            => const Color(0x80000000);
  Color get hover              => isDark ? const Color(0x16FFFFFF) : const Color(0x08000000);
  Color get pressed            => isDark ? const Color(0x22FFFFFF) : const Color(0x10000000);

  // Navegação e tabs
  Color get navBarBg           => isDark ? const Color(0xFF212325) : const Color(0xFFFFFFFF);
  Color get navIconInactive    => isDark ? const Color(0xFF8E8E93) : const Color(0xFF8E8E93);
  Color get navIconActive      => isDark ? Colors.white : primary;
  Color get navLabelActive     => onPrimaryContainer;
  Color get navIndicatorBg     => primaryContainer;

  Color get projectsTabBg      => primary;
  Color get projectsTabFg      => onPrimary;

  Color get previewBackdrop    => isDark ? const Color(0xFF2B2D30) : const Color(0xFFF0F1F3);
  Color get downloadButtonBg   => isDark ? const Color(0xFF34363A) : const Color(0xFFF0F1F3);

  List<BoxShadow> get cardShadow => isDark
      ? [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5, offset: const Offset(0, 1))]
      : [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 3, offset: const Offset(0, 1))];

  List<BoxShadow> get floatingShadow => isDark
      ? [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 14, offset: const Offset(0, 5))]
      : [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2))];

  List<BoxShadow> get cardShadowSoft => isDark
      ? [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 3, offset: const Offset(0, 1))]
      : [BoxShadow(color: Colors.black.withOpacity(0.015), blurRadius: 3, offset: const Offset(0, 1))];

  List<BoxShadow> get navBarShadow => isDark
      ? [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, 3))]
      : [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 6, offset: const Offset(0, 2))];

  Color get incognitoBackground => const Color(0xFF141517);
  Color get incognitoSurface    => const Color(0xFF212325);
  Color get incognitoOnSurface  => const Color(0xFFFFFFFF);
  Color get sheetBackdrop => const Color(0xFF0B0B0D);

  SystemUiOverlayStyle get statusBarStyle => SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
        systemNavigationBarColor: pageBackground,
        systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        systemNavigationBarDividerColor: pageBackground,
      );
}

/// Tema Material 3 partilhado por todas as telas, alinhado com o BrowseIt.
ThemeData buildBrowseItTheme(AppColorScheme s) {
  final brightness = s.isDark ? Brightness.dark : Brightness.light;
  final colorScheme = ColorScheme.fromSeed(
    seedColor: s.primary,
    brightness: brightness,
    surface: s.surface,
  ).copyWith(
    primary: s.primary,
    onPrimary: s.onPrimary,
    primaryContainer: s.primaryContainer,
    onPrimaryContainer: s.onPrimaryContainer,
    secondary: s.primary,
    onSecondary: s.onPrimary,
    surface: s.surface,
    onSurface: s.onSurface,
    surfaceContainerHighest: s.cardBackground,
    onSurfaceVariant: s.onSurfaceVariant,
    outline: s.outline,
    outlineVariant: s.outlineVariant,
    error: s.error,
    onError: s.onError,
  );
  final baseText = Typography.material2021().black;
  final textTheme = baseText.apply(
    bodyColor: s.onSurface,
    displayColor: s.onSurface,
    fontFamily: 'Inter',
  );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: s.pageBackground,
    canvasColor: s.surface,
    cardColor: s.cardBackground,
    cardTheme: CardThemeData(
      color: s.cardBackground,
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.black.withOpacity(s.isDark ? .08 : .025),
      elevation: 0,
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
    dividerColor: s.outlineVariant,
    fontFamily: 'Inter',
    textTheme: textTheme,
    splashFactory: NoSplash.splashFactory,
    splashColor: Colors.transparent,
    highlightColor: Colors.transparent,
    hoverColor: s.hover,
    focusColor: s.hover,
    iconTheme: IconThemeData(color: s.onSurface, size: 22),
    appBarTheme: AppBarTheme(
      backgroundColor: s.pageBackground,
      foregroundColor: s.onSurface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: s.onSurface,
        fontSize: 18,
        fontWeight: FontWeight.w600,
        fontFamily: 'Inter',
      ),
      systemOverlayStyle: s.statusBarStyle,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: s.cardBackground,
      hintStyle: TextStyle(color: s.onSurfaceVariant, fontSize: 14),
      labelStyle: TextStyle(color: s.onSurfaceVariant),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: s.outlineVariant),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: s.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: s.primary, width: 1.35),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: s.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: s.error, width: 1.35),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: s.primary,
        foregroundColor: s.onPrimary,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        minimumSize: const Size(48, 48),
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: s.onSurface,
        side: BorderSide(color: s.outline),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        minimumSize: const Size(48, 46),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: s.primary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: s.cardBackground,
      contentTextStyle: TextStyle(color: s.onSurface, fontSize: 13.5, fontWeight: FontWeight.w500),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      insetPadding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
      elevation: 4,
      showCloseIcon: false,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: s.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      titleTextStyle: TextStyle(color: s.onSurface, fontSize: 19, fontWeight: FontWeight.w600, fontFamily: 'Inter'),
      contentTextStyle: TextStyle(color: s.onSurface, fontSize: 14, height: 1.4, fontFamily: 'Inter'),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: s.surface,
      modalBackgroundColor: s.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 8,
      showDragHandle: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      modalBarrierColor: Colors.black54,
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: s.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      textStyle: TextStyle(color: s.onSurface, fontSize: 14, fontFamily: 'Inter'),
    ),
    listTileTheme: ListTileThemeData(
      iconColor: s.onSurfaceVariant,
      textColor: s.onSurface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      minLeadingWidth: 32,
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: s.primary,
      linearTrackColor: s.outlineVariant,
      circularTrackColor: s.outlineVariant,
    ),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: s.primary,
      selectionColor: s.primary.withOpacity(.22),
      selectionHandleColor: s.primary,
    ),
  );
}

// ══════════════════════════════════════════════════════════════
// THEME NOTIFIER
// ══════════════════════════════════════════════════════════════

class AppThemeNotifier extends ChangeNotifier {
  static const _kModeKey = 'app_theme_mode';
  static const _kPrimaryPairKey = 'app_primary_pair_index';

  AppThemeMode mode = AppThemeMode.system;
  bool isIncognito = false;
  int primaryPairIndex = 0;

  bool get _systemIsDark =>
      SchedulerBinding.instance.platformDispatcher.platformBrightness == Brightness.dark;

  bool get isDark {
    switch (mode) {
      case AppThemeMode.light:  return false;
      case AppThemeMode.dark:   return true;
      case AppThemeMode.system: return _systemIsDark;
    }
  }

  AppThemeNotifier() {
    SchedulerBinding.instance.platformDispatcher.onPlatformBrightnessChanged = () {
      if (mode == AppThemeMode.system) notifyListeners();
    };
  }

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kModeKey);
      if (raw != null) {
        mode = AppThemeModeX.fromStorage(raw);
      } else {
        final legacyDark = prefs.getBool('app_theme_is_dark');
        if (legacyDark != null) {
          mode = legacyDark ? AppThemeMode.dark : AppThemeMode.light;
        }
      }
      final pairIdx = prefs.getInt(_kPrimaryPairKey);
      if (pairIdx != null && pairIdx >= 0 && pairIdx < kPrimaryColorPairs.length) {
        primaryPairIndex = pairIdx;
      }
      notifyListeners();
    } catch (_) {}
  }

  void setMode(AppThemeMode value) {
    if (mode == value) return;
    mode = value;
    notifyListeners();
    _persistMode();
  }

  void toggleDark() {
    setMode(isDark ? AppThemeMode.light : AppThemeMode.dark);
  }

  void setDark(bool value) {
    setMode(value ? AppThemeMode.dark : AppThemeMode.light);
  }

  void setPrimaryPairIndex(int index) {
    if (primaryPairIndex == index) return;
    primaryPairIndex = index;
    notifyListeners();
    _persistPrimaryPair();
  }

  Future<void> _persistMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kModeKey, mode.storageValue);
    } catch (_) {}
  }

  Future<void> _persistPrimaryPair() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_kPrimaryPairKey, primaryPairIndex);
    } catch (_) {}
  }

  void toggleIncognito() { isIncognito = !isIncognito; notifyListeners(); }
}

final AppThemeNotifier appTheme = AppThemeNotifier();

// ══════════════════════════════════════════════════════════════
// PREFERÊNCIAS GLOBAIS
// ══════════════════════════════════════════════════════════════

enum EmojiFrequency { never, rare, medium, often }

extension EmojiFrequencyX on EmojiFrequency {
  String get storageValue => const {
        EmojiFrequency.never:  'never',
        EmojiFrequency.rare:   'rare',
        EmojiFrequency.medium: 'medium',
        EmojiFrequency.often:  'often',
      }[this]!;

  String get displayName => const {
        EmojiFrequency.never:  'Nunca',
        EmojiFrequency.rare:   'Raramente',
        EmojiFrequency.medium: 'Médio',
        EmojiFrequency.often:  'Muito',
      }[this]!;

  static EmojiFrequency fromStorage(String? raw) {
    switch (raw) {
      case 'rare':   return EmojiFrequency.rare;
      case 'medium': return EmojiFrequency.medium;
      case 'often':  return EmojiFrequency.often;
      case 'never':
      default:       return EmojiFrequency.never;
    }
  }
}

enum AppIconStyle { outline, filled }

extension AppIconStyleX on AppIconStyle {
  String get storageValue => const {
        AppIconStyle.outline: 'outline',
        AppIconStyle.filled:  'filled',
      }[this]!;

  static AppIconStyle fromStorage(String? raw) {
    switch (raw) {
      case 'filled': return AppIconStyle.filled;
      case 'outline':
      default:       return AppIconStyle.outline;
    }
  }
}

enum ChatBubbleStyle { bubble, flat }

extension ChatBubbleStyleX on ChatBubbleStyle {
  String get storageValue => const {
        ChatBubbleStyle.bubble: 'bubble',
        ChatBubbleStyle.flat:   'flat',
      }[this]!;

  static ChatBubbleStyle fromStorage(String? raw) {
    switch (raw) {
      case 'flat': return ChatBubbleStyle.flat;
      case 'bubble':
      default:     return ChatBubbleStyle.bubble;
    }
  }
}

enum ResponseStyle { concise, balanced, detailed }

extension ResponseStyleX on ResponseStyle {
  String get storageValue => const {
        ResponseStyle.concise:  'concise',
        ResponseStyle.balanced: 'balanced',
        ResponseStyle.detailed: 'detailed',
      }[this]!;

  static ResponseStyle fromStorage(String? raw) {
    switch (raw) {
      case 'concise':  return ResponseStyle.concise;
      case 'detailed': return ResponseStyle.detailed;
      case 'balanced':
      default:         return ResponseStyle.balanced;
    }
  }
}

class AppPreferencesNotifier extends ChangeNotifier {
  static const _kPromptKey = 'app_preferences_prompt';
  static const _kEmojiKey = 'app_preferences_emoji';
  static const _kFontScaleKey = 'app_preferences_font_scale';
  static const _kFontFamilyKey = 'app_preferences_font_family';
  static const _kIconStyleKey = 'app_preferences_icon_style';
  static const _kChatBubbleStyleKey = 'app_preferences_chat_bubble_style';
  static const _kReduceMotionKey = 'app_preferences_reduce_motion';
  static const _kCustomInstructionsKey = 'app_preferences_custom_instructions';
  static const _kAiTraitsKey = 'app_preferences_ai_traits';
  static const _kKnownInfoKey = 'app_preferences_known_info';
  static const _kResponseStyleKey = 'app_preferences_response_style';
  static const _kAlwaysSearchWebKey = 'app_preferences_always_search_web';
  static const _kRememberAcrossChatsKey = 'app_preferences_remember_across_chats';

  String prompt = '';
  EmojiFrequency emojiFrequency = EmojiFrequency.never;
  double fontScale = 0.35;
  String fontFamily = 'Inter';
  AppIconStyle iconStyle = AppIconStyle.outline;
  ChatBubbleStyle chatBubbleStyle = ChatBubbleStyle.bubble;
  bool reduceMotion = false;
  String customInstructions = '';
  String aiTraits = '';
  String knownInfo = '';
  ResponseStyle responseStyle = ResponseStyle.balanced;
  bool alwaysSearchWeb = false;
  bool rememberAcrossChats = true;

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      prompt = prefs.getString(_kPromptKey) ?? '';
      final emojiRaw = prefs.getString(_kEmojiKey);
      if (emojiRaw != null) {
        emojiFrequency = EmojiFrequencyX.fromStorage(emojiRaw);
      }
      fontScale = prefs.getDouble(_kFontScaleKey) ?? 0.35;
      fontFamily = prefs.getString(_kFontFamilyKey) ?? 'Inter';
      iconStyle = AppIconStyleX.fromStorage(prefs.getString(_kIconStyleKey));
      chatBubbleStyle =
          ChatBubbleStyleX.fromStorage(prefs.getString(_kChatBubbleStyleKey));
      reduceMotion = prefs.getBool(_kReduceMotionKey) ?? false;
      customInstructions = prefs.getString(_kCustomInstructionsKey) ?? '';
      aiTraits = prefs.getString(_kAiTraitsKey) ?? '';
      knownInfo = prefs.getString(_kKnownInfoKey) ?? '';
      responseStyle =
          ResponseStyleX.fromStorage(prefs.getString(_kResponseStyleKey));
      alwaysSearchWeb = prefs.getBool(_kAlwaysSearchWebKey) ?? false;
      rememberAcrossChats = prefs.getBool(_kRememberAcrossChatsKey) ?? true;
      notifyListeners();
    } catch (_) {}
  }

  void setPrompt(String value) {
    if (prompt == value) return;
    prompt = value;
    notifyListeners();
    _persistPrompt();
  }

  void setEmojiFrequency(EmojiFrequency freq) {
    if (emojiFrequency == freq) return;
    emojiFrequency = freq;
    notifyListeners();
    _persistEmoji();
  }

  void setFontScale(double value) {
    if ((fontScale - value).abs() < 0.001) return;
    fontScale = value;
    notifyListeners();
    _persistFontScale();
  }

  void setFontFamily(String value) {
    if (fontFamily == value) return;
    fontFamily = value;
    notifyListeners();
    _persistFontFamily();
  }

  void setIconStyle(AppIconStyle value) {
    if (iconStyle == value) return;
    iconStyle = value;
    notifyListeners();
    _persistIconStyle();
  }

  void setChatBubbleStyle(ChatBubbleStyle value) {
    if (chatBubbleStyle == value) return;
    chatBubbleStyle = value;
    notifyListeners();
    _persistChatBubbleStyle();
  }

  void setReduceMotion(bool value) {
    if (reduceMotion == value) return;
    reduceMotion = value;
    notifyListeners();
    _persistReduceMotion();
  }

  void setResponseStyle(ResponseStyle value) {
    if (responseStyle == value) return;
    responseStyle = value;
    notifyListeners();
    _persistResponseStyle();
  }

  void setAlwaysSearchWeb(bool value) {
    if (alwaysSearchWeb == value) return;
    alwaysSearchWeb = value;
    notifyListeners();
    _persistAlwaysSearchWeb();
  }

  void setRememberAcrossChats(bool value) {
    if (rememberAcrossChats == value) return;
    rememberAcrossChats = value;
    notifyListeners();
    _persistRememberAcrossChats();
  }

  /// Multiplicador real aplicado ao tamanho de fonte base — mapeia o
  /// slider (0.0–1.0) para um intervalo de escala visualmente útil
  /// (85% a 135% do tamanho base), espelhando o cálculo que já
  /// existia isolado dentro de _FontSizeCard.
  double get textScaleFactor => 0.85 + (fontScale * 0.5);

  Future<void> setEmojiFrequencyRemote(EmojiFrequency freq, String? token) async {
    setEmojiFrequency(freq);
    if (token == null) return;
    try {
      await ProfileApiService.updateAccount(token, preferences: {
        'emojiFrequency': freq.storageValue,
      });
    } catch (_) {}
  }

  Future<void> setPromptRemote(String value, String? token) async {
    setPrompt(value);
    if (token == null) return;
    try {
      await ProfileApiService.updateAccount(token, preferences: {
        'customPrompt': value,
      });
    } catch (_) {}
  }

  Future<void> setCustomInstructionsRemote(String value, String? token) async {
    if (customInstructions == value) return;
    customInstructions = value;
    notifyListeners();
    _persistCustomInstructions();
    if (token == null) return;
    try {
      await ProfileApiService.updateAccount(token, preferences: {
        'customInstructions': value,
      });
    } catch (_) {}
  }

  Future<void> setAiTraitsRemote(String value, String? token) async {
    if (aiTraits == value) return;
    aiTraits = value;
    notifyListeners();
    _persistAiTraits();
    if (token == null) return;
    try {
      await ProfileApiService.updateAccount(token, preferences: {
        'aiTraits': value,
      });
    } catch (_) {}
  }

  Future<void> setKnownInfoRemote(String value, String? token) async {
    if (knownInfo == value) return;
    knownInfo = value;
    notifyListeners();
    _persistKnownInfo();
    if (token == null) return;
    try {
      await ProfileApiService.updateAccount(token, preferences: {
        'knownInfo': value,
      });
    } catch (_) {}
  }

  Future<void> _persistPrompt() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kPromptKey, prompt);
    } catch (_) {}
  }

  Future<void> _persistEmoji() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kEmojiKey, emojiFrequency.storageValue);
    } catch (_) {}
  }

  Future<void> _persistFontScale() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_kFontScaleKey, fontScale);
    } catch (_) {}
  }

  Future<void> _persistFontFamily() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kFontFamilyKey, fontFamily);
    } catch (_) {}
  }

  Future<void> _persistIconStyle() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kIconStyleKey, iconStyle.storageValue);
    } catch (_) {}
  }

  Future<void> _persistChatBubbleStyle() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kChatBubbleStyleKey, chatBubbleStyle.storageValue);
    } catch (_) {}
  }

  Future<void> _persistReduceMotion() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kReduceMotionKey, reduceMotion);
    } catch (_) {}
  }

  Future<void> _persistCustomInstructions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kCustomInstructionsKey, customInstructions);
    } catch (_) {}
  }

  Future<void> _persistAiTraits() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kAiTraitsKey, aiTraits);
    } catch (_) {}
  }

  Future<void> _persistKnownInfo() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kKnownInfoKey, knownInfo);
    } catch (_) {}
  }

  Future<void> _persistResponseStyle() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kResponseStyleKey, responseStyle.storageValue);
    } catch (_) {}
  }

  Future<void> _persistAlwaysSearchWeb() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kAlwaysSearchWebKey, alwaysSearchWeb);
    } catch (_) {}
  }

  Future<void> _persistRememberAcrossChats() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kRememberAcrossChatsKey, rememberAcrossChats);
    } catch (_) {}
  }
}

final AppPreferencesNotifier appPreferences = AppPreferencesNotifier();

// ══════════════════════════════════════════════════════════════
// AppTheme — wrapper estático
// ══════════════════════════════════════════════════════════════

class AppTheme extends StatelessWidget {
  final Widget child;
  const AppTheme({super.key, required this.child});

  static AppColorScheme of(BuildContext context) =>
      AppColorScheme(appTheme.isDark, appTheme.primaryPairIndex);

  static bool isIncognito(BuildContext context) => appTheme.isIncognito;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([appTheme, appPreferences]),
      builder: (_, __) => child,
    );
  }
}

mixin ThemeReactive<T extends StatefulWidget> on State<T> {
  @override
  void initState() {
    super.initState();
    appTheme.addListener(_onThemeChanged);
    appPreferences.addListener(_onThemeChanged);
  }

  void _onThemeChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    appTheme.removeListener(_onThemeChanged);
    appPreferences.removeListener(_onThemeChanged);
    super.dispose();
  }
}