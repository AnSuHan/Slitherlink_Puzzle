import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppLocalizations {
  AppLocalizations(this.locale);

  final Locale locale;
  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  static Future<AppLocalizations> load(Locale locale) async {
    final String jsonString = await rootBundle.loadString('lib/l10n/${locale.languageCode}/strings_${locale.languageCode}.arb');
    final Map<String, dynamic> jsonMap = json.decode(jsonString);
    return AppLocalizations(locale).._localizedStrings = jsonMap;
  }

  late Map<String, dynamic> _localizedStrings;

  String translate(String key) {
    return _localizedStrings[key] ?? '$key not found';
  }

  String translateComplex(String key1, String key2) {
    if(_localizedStrings.containsKey(key1) && _localizedStrings.containsKey(key2)) {
      if (locale.languageCode == 'ko') {
        return '${_localizedStrings[key2]} ${_localizedStrings[key1]}';
      } else { // en
        return '${_localizedStrings[key1]} ${_localizedStrings[key2]}';
      }
    }
    else {
      return '$key1 or $key2 not found';
    }
  }
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    return ['en', 'ko'].contains(locale.languageCode);
  }

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return AppLocalizations.load(locale);
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
