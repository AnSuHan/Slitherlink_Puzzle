class Answer {
  List<List<List<bool>>> squareAnswer = [
    [
      //show edge test
      List.filled(20, true), List.filled(21, true), List.filled(20, true), List.filled(21, true), List.filled(20, true),
      List.filled(21, true), List.filled(20, true), List.filled(21, true), List.filled(20, true), List.filled(21, true),
      List.filled(20, true), List.filled(21, true), List.filled(20, true), List.filled(21, true), List.filled(20, true),
      List.filled(21, true), List.filled(20, true), List.filled(21, true), List.filled(20, true), List.filled(21, true),
      List.filled(20, true)
    ],
    [
      //cycle test
      [false, false, true, false, true, true, true, true, true, false, false, true, false, true, true, true, true, false, false, true],
      [false, false, true, true, true, false, false, false, false, true, false, true, true, true, false, false, false, true, false, true, true],
      [false, true, false, false, true, true, false, true, false, true, true, false, false, true, false, true, true, false, true, false],
      [false, true, false, true, false, false, true, true, true, false, false, false, true, false, true, true, false, false, true, false, true],
      [false, true, false, true, true, false, true, false, false, true, true, false, true, true, false, false, true, true, false, true],
      [false, false, true, false, false, true, false, false, true, true, false, true, false, false, false, true, true, false, false, true, false],
      [true, true, false, true, false, true, true, true, false, true, false, true, true, false, false, false, true, true, false, true],
      [true, false, false, true, true, false, false, false, false, false, true, false, false, true, false, true, false, false, true, false, true],
      [true, false, true, false, false, true, true, false, true, true, false, true, false, true, false, true, false, false, false, true],
      [false, true, true, false, true, true, false, true, true, false, false, true, true, false, true, false, true, false, true, true, false],
      [true, false, false, false, true, false, false, false, false, true, false, false, false, false, true, false, true, true, false, false],
      [true, false, true, false, false, false, false, true, true, true, true, true, true, false, false, true, false, false, false, true, false],
      [false, false, false, true, true, false, true, false, false, false, false, false, false, true, true, false, false, true, true, false],
      [true, false, true, true, false, true, true, false, true, true, true, true, true, true, false, false, false, true, false, false, false],
      [true, false, true, false, false, false, false, false, false, false, true, false, false, false, false, true, false, true, true, false],
      [false, true, false, false, false, true, true, false, true, true, false, false, true, true, false, true, true, false, false, true, false],
      [false, false, true, false, true, false, true, false, true, false, true, true, false, false, false, false, true, true, false, true],
      [false, true, true, true, true, false, false, true, false, false, true, false, false, true, false, true, false, false, true, false, true],
      [false, false, false, true, false, true, true, false, true, false, true, false, false, true, false, true, true, false, false, true],
      [false, true, true, false, false, true, false, false, true, true, false, true, false, false, true, false, false, true, true, true, false],
      [false, true, false, false, false, true, true, true, false, true, true, false, false, false, true, true, true, false, true, false]
    ],

  ];

  List<List<bool>> getSquare(int index) {
    if(index < squareAnswer.length) {
      return squareAnswer[index];
    }
    return [];
  }
}