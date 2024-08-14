// ignore_for_file: file_names
import 'dart:convert';
import '../Platform/ExtractData.dart'
if (dart.library.html) '../Platform/ExtractDataWeb.dart'; // 조건부 import

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserInfo {
  static bool isDebug = true;
  static Map<String, bool> debugMode = {
    "Answer_showCycle" : false,
  };

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
    "appbar_mode" : "fixed", //fixed | toggle
    "button_alignment" : "right"
  };
  static List<String> language = ["english", "korean"];
  static bool updateContinueWidget = false;

  ///load data from firestore
  static Future<void> init() async {
    FirebaseFirestore db = FirebaseFirestore.instance;
    User? user = FirebaseAuth.instance.currentUser;

    if(user != null) {
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
        }
        else {
          // Return default values if the document doesn't exist or the progress data is not found
          progress = {
            "square_small": 0,
            "triangle_small": 0,
          };
        }
      }
      else {
        // Return default values if the document doesn't exist or the progress data is not found
        progress = {
          "square_small": 0,
          "triangle_small": 0,
        };
      }
    }

    //remember setting
    loadSetting();
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
    StringBuffer buffer = StringBuffer();
    progress.forEach((key, value) {
      buffer.write('$key : $value\n');
    });
    return buffer.toString().trim();
  }

  static void clearPuzzle(String key) {
    // ignore: avoid_print
    print("in clearPuzzle : $key");
    continuePuzzle.remove(key);
    updateContinueWidget = true;
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

  static Future<void> setSettingAll(Map<String, String> value) async {
    Iterable<String> keys = setting.keys;
    for(String key in keys) {
      if(value.containsKey(key)) {
        setting[key] = value[key]!;
      }
    }

    String settingJson = jsonEncode(setting);
    await ExtractData().saveDataToLocal("setting", settingJson);
  }

  static Future<void> loadSetting() async {
    String? settingJson = await ExtractData().getDataFromLocal("setting");

    if (settingJson != null) {
      Map<String, dynamic> loadedSettings = jsonDecode(settingJson);
      setting = loadedSettings.map((key, value) => MapEntry(key, value.toString()));
    }
    // ignore: avoid_print
    print("setting : $setting");
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

  static String getAppbarMode() {
    return setting["appbar_mode"]!;
  }
}