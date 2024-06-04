import 'package:flutter/cupertino.dart';
import 'package:slitherlink_project/Scene/GameSceneStateSquare.dart';

class GameSceneSquare extends StatefulWidget {
  const GameSceneSquare({Key? key}) : super(key: key);

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