class UserInfo {
  static Map<String, int> progress = {
    "square_small" : 0,
  };   //finish progress
  //set value when pushing start button & reset when complete puzzle
  static Set<String> continuePuzzle = {};

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
}