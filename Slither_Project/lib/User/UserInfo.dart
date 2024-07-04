// ignore_for_file: file_names
import 'package:flutter/widgets.dart';
import 'package:slitherlink_project/l10n/app_localizations.dart';

class UserInfo {
  static Map<String, int> progress = {
    "square_small" : 0,
  };   //finish progress
  //set value when pushing start button & reset when complete puzzle
  static Set<String> continuePuzzle = {};
  static Map<String, String> setting = {
    "theme" : "default",
    "language" : "english",
    "button_alignment" : "right"
  };
  static List<String> language = ["english", "korean"];
  static List<String> _language = ["english", "korean"];

  ///shape`_`size
  static int getProgress(String puzzleType) {
    if(progress.containsKey(puzzleType)) {
      return progress[puzzleType]!;
    }
    else {
      return -1;
    }
  }

  /// save at start in EnterScene.dart & pop at GameSceneStateSquare.dart when complete
  /// input should be "puzzleShape`_`puzzleSize`_`puzzleLevel
  static void addContinuePuzzle(String input) {
    continuePuzzle.add(input);
    var token = input.split("_");
    String mapKey = "${token[0]}_${token[1]}";
    progress[mapKey] = progress[mapKey]! + 1;
  }

  static Set<String> getContinuePuzzle() {
    return continuePuzzle;
  }

  static Map<String, String> getSettingAll() {
    return setting;
  }

  static String? getSetting(String key) {
    if(setting.containsKey(key)) {
      return setting[key];
    }
    return null;
  }

  static void setSettingAll(Map<String, String> value) {
    Iterable<String> keys = setting.keys;
    for(String key in keys) {
      if(value.containsKey(key)) {
        setting[key] = value[key]!;
      }
    }
  }

  static void setSetting(String key, String value) {
    if(setting.containsKey(key)) {
      setting[key] = value;
    }
  }

  static List<String> getSupportLanguage(BuildContext context) {
    _language = [
      AppLocalizations.of(context)!.translate("language_english_en"),
      AppLocalizations.of(context)!.translate("language_english_kr")
    ];

    return language;
  }

  static String getLanguage() {
    return setting["language"]!;
  }

  static void setLanguage(String lang) {
    if(language.contains(lang)) {
      setting["language"] = lang;
    }
  }
}