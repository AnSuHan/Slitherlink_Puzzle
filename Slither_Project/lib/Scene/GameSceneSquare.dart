import 'package:flutter/cupertino.dart';
import 'package:slitherlink_project/Scene/GameSceneStateSquare.dart';

import '../MakePuzzle/ReadSquare.dart';
import '../widgets/SquareBox.dart';

class GameSceneSquare extends StatefulWidget {
  const GameSceneSquare({Key? key}) : super(key: key);

  @override
  GameSceneStateSquare createState() => GameSceneStateSquare();
}

class SquareProvider with ChangeNotifier {
  static List<Widget> squareField = [];
  //check complete puzzle;
  static late List<List<int>> answer;
  static late List<List<int>> submit;

  ///한 번 화면을 클릭해서 build가 다시 일어나야 ui에 초기화가 반영
  void resetPuzzle() {
    loadPuzzle();
    notifyListeners(); // Update UI
  }

  List<Widget> getSquareField() {
    return squareField;
  }

  void loadPuzzle() async {
    answer = await ReadSquare().loadPuzzle("square");
    submit = List.generate(answer.length, (row) =>
        List.filled(answer[row].length, 0),
    );

    squareField = GameSceneStateSquare.buildSquarePuzzle(answer[0].length, answer.length ~/ 2);
    List<Widget> newSquareField = await GameSceneStateSquare.buildSquarePuzzleAnswer(answer);

    squareField = newSquareField;
    notifyListeners(); // Update UI
  }
}