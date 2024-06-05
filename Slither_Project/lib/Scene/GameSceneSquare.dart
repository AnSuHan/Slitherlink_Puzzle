import 'package:flutter/cupertino.dart';
import 'package:slitherlink_project/Scene/GameSceneStateSquare.dart';

class GameSceneSquare extends StatefulWidget {
  //final로 선언해야 Navigator push로 넘긴 파라미터에 접근할 수 있음
  final bool isContinue;

  const GameSceneSquare({Key? key, required this.isContinue}) : super(key: key);

  @override
  GameSceneStateSquare createState() => GameSceneStateSquare();
}

class SquareProvider with ChangeNotifier {
  static List<Widget> squareField = [];

  List<Widget> getSquareField() {
    return squareField;
  }
  void setSquareField(List<Widget> field) {
    squareField = field;
    notifyListeners();
  }
}