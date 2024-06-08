class UserInfo {
  static Map<String, int> progress = {
    "square_small" : 0,
  };   //finish progress
  //set value when pushing start button & reset when complete puzzle
  static Set<String> continuePuzzle = {};
  static Map<String, String> setting = {
    "theme" : "warm"
  };

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
    print("user ${setting["theme"]}");
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
}