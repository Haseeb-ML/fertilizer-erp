import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

class LanguageNotifier extends StateNotifier<String> {
  LanguageNotifier() : super('en') {
    _loadLanguagePreference();
  }

  static const String _prefFileName = 'app_language_pref.txt';

  Future<void> _loadLanguagePreference() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$_prefFileName');
      if (await file.exists()) {
        final savedLang = (await file.readAsString()).trim();
        if (savedLang == 'ur' || savedLang == 'en') {
          state = savedLang;
        }
      }
    } catch (_) {
      // Fallback silently to default 'en'
    }
  }

  Future<void> setLanguage(String langCode) async {
    if (langCode != 'en' && langCode != 'ur') return;
    if (state == langCode) return;
    state = langCode;
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$_prefFileName');
      await file.writeAsString(langCode);
    } catch (_) {
      // Ignore disk persistence errors in tests or restricted envs
    }
  }

  Future<void> toggleLanguage() async {
    final next = state == 'en' ? 'ur' : 'en';
    await setLanguage(next);
  }
}

final languageProvider = StateNotifierProvider<LanguageNotifier, String>((ref) {
  return LanguageNotifier();
});
