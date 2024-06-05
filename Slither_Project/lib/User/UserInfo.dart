class UserInfo {
  Map<String, int> progress = {
    "square_small" : 0,
  };   //finish progress
  //set value when pushing start button & reset when complete puzzle
  static List<String> continuePuzzle = [];

  int getProgress(String puzzleType) {
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
    print("add ContinuePuzzle : $continuePuzzle");

  }

  static List<String> getContinuePuzzle() {
    return continuePuzzle;
  }
}