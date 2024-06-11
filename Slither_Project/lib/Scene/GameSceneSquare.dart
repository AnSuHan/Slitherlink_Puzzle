import 'package:flutter/cupertino.dart';
import 'package:slitherlink_project/Scene/GameSceneStateSquare.dart';

class GameSceneSquare extends StatefulWidget {
  //to access to parameter with Navigator push, variable should be final
  final bool isContinue;
  final String loadKey;

  const GameSceneSquare({Key? key, required this.isContinue, required this.loadKey}) : super(key: key);

  @override
  GameSceneStateSquare createState() => GameSceneStateSquare();
}

class SquareProvider with ChangeNotifier {
  List<Widget> squareField = [];

  List<Widget> getSquareField() {
    return squareField;
  }
  void setSquareField(List<Widget> field) {
    squareField = field;
    notifyListeners();
  }
}