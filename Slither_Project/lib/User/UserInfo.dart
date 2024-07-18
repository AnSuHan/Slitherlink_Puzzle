// ignore_for_file: file_names
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart%20';
import 'package:flutter/widgets.dart';
import 'package:slitherlink_project/l10n/app_localizations.dart';

class UserInfo {
  static bool authState = false;
  static Map<String, int> progress = {
    "square_small" : 0,
    "triangle_small" : 0
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

  ///load data from firestore
  static Future<void> init() async {
    print("get progress from server");

    FirebaseFirestore db = FirebaseFirestore.instance;
    User user = FirebaseAuth.instance.currentUser!;

    // Fetch the document for the current user
    DocumentSnapshot snapshot = await db.collection("users").doc(user.email).get();

    // Check if the document exists
    if (snapshot.exists) {
      // Extract the progress data
      Map<String, dynamic>? data = snapshot.data() as Map<String, dynamic>?;
      if (data != null && data.containsKey('progress')) {
        Map<String, dynamic> instProgress = data['progress'];
        int squareSmall = instProgress['square_small'];
        int triangleSmall = instProgress['triangle_small'];

        // Return the extracted values
        progress["square_small"] = squareSmall;
        progress["triangle_small"] = triangleSmall;
        print("squareSmall : $squareSmall, triangleSmall : $triangleSmall");
        print("in init :\tsquareSmall : ${progress["square_small"]}, triangleSmall : ${progress["triangle_small"]}");
      }
      else {
        print("in else1");
        // Return default values if the document doesn't exist or the progress data is not found
        progress = {
          "square_small": 0,
          "triangle_small": 0,
        };
      }
    }
    else {
      print("in else2");
      // Return default values if the document doesn't exist or the progress data is not found
      progress = {
        "square_small": 0,
        "triangle_small": 0,
      };
    }
  }

  ///shape`_`size
  static int getProgress(String puzzleType) {
    if(progress.containsKey(puzzleType)) {
      return progress[puzzleType]!;
    }
    else {
      return -1;
    }
  }

  static String getAllProgress() {
    print("in getAll :\tsquareSmall : ${progress["square_small"]}, triangleSmall : ${progress["triangle_small"]}");
    StringBuffer buffer = StringBuffer();
    progress.forEach((key, value) {
      buffer.write('$key : $value\n');
    });
    return buffer.toString().trim();
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

  ///true : left, false : right
  static bool getButtonAlignment() {
    return setting["button_alignment"]!.compareTo("left") == 0 ? true : false;
  }
}