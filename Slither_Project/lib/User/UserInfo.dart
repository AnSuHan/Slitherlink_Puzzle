class UserInfo {
  Map<String, int> progress = {
    "square" : 0,
  };   //finish progress

  int getProgress(String puzzleType) {
    if(progress.containsKey(puzzleType)) {
      return progress[puzzleType]!;
    }
    else {
      return -1;
    }
  }
}