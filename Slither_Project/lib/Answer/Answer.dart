class Answer {
  List<List<List<bool>>> squareAnswer = [

  ];

  List<List<bool>> getSquare(int index) {
    if(index < squareAnswer.length) {
      return squareAnswer[index];
    }
    return [];
  }
}