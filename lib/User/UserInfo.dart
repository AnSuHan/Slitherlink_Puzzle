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
    "use_KeyInput" : true,
    "enable_extract" : false,
    "debug_snackBar" : true,
    "loadTestAnswer" : true,      //class Answer - getTestSquare()
    "howToPlay_followSteps" : true,
    "print_isUpdating" : false,
    "print_methodName" : false,
  };

  static bool authState = false;
  static Map<String, int> progress = {
    "square_small" : 0,
    "triangle_small" : 0
  };   //finish progress
  static Map<String, int> completed = {};  //completed puzzle count by type
  //set value when pushing start button & reset when complete puzzle
  static Set<String> continuePuzzle = {};
  static Map<String, String> continuePuzzleDate = {};
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
      authState = true;
      // Fetch the document for the current user
      DocumentSnapshot snapshot = await db.collection("users").doc(user.email).get();

      // Check if the document exists
      if (snapshot.exists) {
        Map<String, dynamic>? data = snapshot.data() as Map<String, dynamic>?;
        if (data != null && data.containsKey('progress')) {
          Map<String, dynamic> instProgress = data['progress'];
          int squareSmall = instProgress['square_small'] ?? 0;
          int triangleSmall = instProgress['triangle_small'] ?? 0;
          progress["square_small"] = squareSmall;
          progress["triangle_small"] = triangleSmall;
        } else {
          progress = {"square_small": 0, "triangle_small": 0};
        }
        if (data != null && data.containsKey('completed') && data['completed'] is Map) {
          Map<String, dynamic> instCompleted = Map<String, dynamic>.from(data['completed']);
          completed = instCompleted.map((k, v) => MapEntry(k, (v as num).toInt()));
        } else {
          completed = {};
        }
      } else {
        progress = {"square_small": 0, "triangle_small": 0};
        completed = {};
      }
    } else {
      // 로그아웃 상태: 로컬에서만 완료 이력 로드
      await loadCompleted();
    }

    //remember setting
    loadSetting();
    loadContinuePuzzle();
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
    continuePuzzleDate.remove(key);
    saveContinuePuzzle();
    updateContinueWidget = true;
  }

  /// save at start in EnterScene.dart & pop at GameSceneStateSquare.dart when complete
  /// input should be "puzzleShape`_`puzzleSize`_`puzzleLevel
  static void addContinuePuzzle(String input) {
    continuePuzzle.add(input);
    saveContinuePuzzle();
  }

  /// increment completed count when puzzle is solved
  static void incrementCompleted(String loadKey) {
    var token = loadKey.split("_");
    String category;
    if (token.length >= 3 && token[1] == "generate") {
      category = "${token[0]}_${token[2]}"; // e.g. "square_10x10"
    } else {
      category = "${token[0]}_${token[1]}"; // e.g. "square_small"
    }
    completed[category] = (completed[category] ?? 0) + 1;
    saveCompleted();
  }

  static Future<void> saveCompleted() async {
    if (authState) {
      // 로그인 상태: Firestore 에 저장 (기기 변경 시에도 유지)
      User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        try {
          await FirebaseFirestore.instance
              .collection("users")
              .doc(user.email)
              .set({"completed": completed}, SetOptions(merge: true));
        } catch (e) {
          // ignore: avoid_print
          print('saveCompleted remote failed: $e');
        }
      }
    } else {
      // 비로그인 상태: 로컬에만 저장
      await ExtractData().saveDataToLocal("completed", jsonEncode(completed));
    }
  }

  static Future<void> loadCompleted() async {
    String? data = await ExtractData().getDataFromLocal("completed");
    if (data != null) {
      Map<String, dynamic> map = jsonDecode(data);
      completed = map.map((k, v) => MapEntry(k, (v as num).toInt()));
    } else {
      completed = {};
    }
  }

  /// 로컬 SharedPreferences 의 completed 키를 제거
  static Future<void> clearLocalCompleted() async {
    final prefs = ExtractData();
    if (await prefs.containsKey("completed")) {
      await prefs.removeKey("completed");
    }
  }

  static String getCompletedSummary() {
    if (completed.isEmpty) return "0";
    StringBuffer buffer = StringBuffer();
    completed.forEach((key, value) {
      buffer.write('$key : $value\n');
    });
    return buffer.toString().trim();
  }

  static int getTotalCompleted() {
    int total = 0;
    completed.forEach((_, value) { total += value; });
    return total;
  }

  static Set<String> getContinuePuzzle() {
    return continuePuzzle;
  }

  static Future<void> saveContinuePuzzle() async {
    final prefs = ExtractData();
    await prefs.saveDataToLocal(
      "continuePuzzle", jsonEncode(continuePuzzle.toList()),
    );
    await prefs.saveDataToLocal(
      "continuePuzzleDate", jsonEncode(continuePuzzleDate),
    );
  }

  static Future<void> loadContinuePuzzle() async {
    final prefs = ExtractData();
    String? data = await prefs.getDataFromLocal("continuePuzzle");
    if (data != null) {
      List<dynamic> list = jsonDecode(data);
      continuePuzzle = list.map((e) => e.toString()).toSet();
    }
    String? dateData = await prefs.getDataFromLocal("continuePuzzleDate");
    if (dateData != null) {
      Map<String, dynamic> map = jsonDecode(dateData);
      continuePuzzleDate = map.map((k, v) => MapEntry(k, v.toString()));
    }
  }

  static String getPuzzleCreatedDate(String key) {
    return continuePuzzleDate[key] ?? "";
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