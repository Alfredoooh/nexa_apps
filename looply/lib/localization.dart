import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'l10n/translations.dart';

class AppLanguage {
  const AppLanguage({required this.code, required this.name, required this.nativeName});

  final String code;
  final String name;
  final String nativeName;

  Locale get locale => Locale(code);
}

const List<AppLanguage> supportedAppLanguages = <AppLanguage>[
  AppLanguage(code: 'pt', name: 'Portuguese', nativeName: 'Português'),
  AppLanguage(code: 'en', name: 'English', nativeName: 'English'),
  AppLanguage(code: 'es', name: 'Spanish', nativeName: 'Español'),
  AppLanguage(code: 'fr', name: 'French', nativeName: 'Français'),
  AppLanguage(code: 'de', name: 'German', nativeName: 'Deutsch'),
  AppLanguage(code: 'it', name: 'Italian', nativeName: 'Italiano'),
  AppLanguage(code: 'ar', name: 'Arabic', nativeName: 'العربية'),
  AppLanguage(code: 'zh', name: 'Chinese', nativeName: '简体中文'),
  AppLanguage(code: 'ja', name: 'Japanese', nativeName: '日本語'),
  AppLanguage(code: 'ru', name: 'Russian', nativeName: 'Русский'),
  AppLanguage(code: 'hi', name: 'Hindi', nativeName: 'हिन्दी'),
  AppLanguage(code: 'tr', name: 'Turkish', nativeName: 'Türkçe'),
];

class AppLanguageController extends ValueNotifier<AppLanguage> {
  AppLanguageController() : super(supportedAppLanguages.first);

  Future<void> restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString('browseit_language') ?? 'pt';
      value = supportedAppLanguages.firstWhere(
        (language) => language.code == saved,
        orElse: () => supportedAppLanguages.first,
      );
    } catch (_) {}
  }

  void select(AppLanguage language) {
    if (value.code == language.code) return;
    value = language;
    unawaited(_persist());
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('browseit_language', value.code);
    } catch (_) {}
  }
}

final AppLanguageController appLanguageController = AppLanguageController();

String appText(String key) {
  final languageCode = appLanguageController.value.code;
  final language = appTranslations[languageCode] ?? appTranslations['pt']!;
  return language[key] ?? appTranslations['en']?[key] ?? key;
}
