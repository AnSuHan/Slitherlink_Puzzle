// ignore_for_file: file_names
import 'dart:math';

import 'package:flutter/material.dart';

import '../MakePuzzle/ReadSquare.dart';
import '../Platform/ExtractData.dart'
  if (dart.library.html) '../Platform/ExtractDataWeb.dart'; // 조건부 import
import '../Scene/GameSceneSquare.dart';
import '../ThemeColor.dart';
import '../User/UserInfo.dart';
import '../widgets/MainUI.dart';
import '../widgets/SquareBox.dart';

class SquareProvider with ChangeNotifier {
  late ReadSquare readSquare;
  late BuildContext context;
  final String loadKey;

  final GameStateSquare? gameStateSquare;   //gameStateSquare == null => this is HowToPlay mode
  bool shutdown = false;  //showdialog에서 ok를 눌러 GameSceneSquare을 닫아야 하는 경우

  SquareProvider({
    this.isContinue = false,
    required this.context,
    this.gameStateSquare,
    required this.loadKey,
  }) {
    readSquare = ReadSquare(squareProvider: this, context: context);
  }

  ThemeColor themeColor = ThemeColor();

  List<Widget> squareField = [];
  List<List<SquareBox>> puzzle = [];
  late GameStateSquare gameField; // instance of GameSceneStateSquareProvider

  late List<List<int>> answer;
  late List<List<int>> submit;
  bool isContinue = false;

  ///Init
  Future<void> init() async {
    //setting field
    puzzle = initSquarePuzzle(answer[0].length, answer.length ~/ 2);
    squareField = await buildSquarePuzzleAnswer(answer, isContinue: isContinue);
    readSquare.setPuzzle(puzzle);

    //for working do-things
    initDoValue();
    notifyListeners();
  }

  Future<void> restart() async {
    for(int i = 0 ; i < submit.length ; i++) {
      for(int j = 0 ; j < submit[i].length ; j++) {
        submit[i][j] = 0;
      }
    }

    await clearLineForStart();
    await resetDo();
    notifyListeners();
    submit = await readSquare.readSubmit(puzzle);
    notifyListeners();
  }

  Future<void> readSubmit() async {
    // ignore: avoid_print
    print("readSubmit : ${await readSquare.readSubmit(puzzle)}");
  }

  Future<void> showHint(BuildContext context) async {
    await removeHintLine();

    // ignore: use_build_context_synchronously
    List<List<dynamic>> items = await checkCompletePuzzleCompletely(context);
    //print("hint items : $items");
    List<dynamic> item;

    if(items.isNotEmpty) {
      if(items.length > 1) {
        item = items[Random().nextInt(items.length - 1)];
      }
      else {
        item = items.first;
      }
      //print("hint item : $item");
      //gameStateSquare.moveTo(gameStateSquare.getHintPos(item), 1.6);

      setLineColorBox(
          int.parse(item[0].toString()),
          int.parse(item[1].toString()),
          item[2].toString(),
          (item[3] as bool) ? -5 : -3   //item[3] is `isWrongSubmit`
      );
    }
  }

  Future<void> removeHintLine() async {
    if(UserInfo.debugMode["print_isUpdating"]!) {
      print("call removeHintLine : $_isUpdating");
    }
    //howToPlay에서는 힌트 라인을 지우지 않음
    if(gameStateSquare == null) {
      return;
    }
    while(_isUpdating != 0) {
      Future.delayed(const Duration(milliseconds: 50));
      //print("wait in check : $_isUpdating");
    }
    submit = await readSquare.readSubmit(puzzle);

    //find hint line
    for(int i = 0 ; i < answer.length ; i++) {
      for(int j = 0 ; j < answer[i].length ; j++) {
        //힌트 라인이 남아 있는 경우 제거 후 조기 종료
        if(submit[i][j] == -3 || submit[i][j] == -5) {
          setLineColor(i, j, 0);
          return;
        }
      }
    }
  }

  ///[width, height]
  List<int> getResolutionCount() {
    return [answer.length, answer[0].length];
  }

  ///메소드에서 필요할 때마다 호출 (_isUpdating가 0 또는 2인 경우에만 진행 가능)
  ///
  ///(updateSquareBox에서 호출하지 않음)
  Future<void> refreshSubmit() async {
    if(UserInfo.debugMode["print_isUpdating"]!) {
      print("call refreshSubmit : $_isUpdating");
    }
    //0이거나 2일 때만 통과
    while(_isUpdating != 0 && _isUpdating != 2) {
      await Future.delayed(const Duration(milliseconds: 50));
    }

    submit = await readSquare.readSubmit(puzzle);
    // ignore: use_build_context_synchronously
    checkCompletePuzzle(context);
    notifyListeners();
  }

  //row, column is puzzle's row, column
  ///SquareBox 단위로 방향을 지정하여 동작하는 함수
  ///
  ///(submit 기준 : setLineColor)
  void setLineColorBox(int row, int column, String dir, int color) {
    switch(dir) {
      case "up":
        puzzle[row][column].up = color;
        break;
      case "down":
        puzzle[row][column].down = color;
        break;
      case "left":
        puzzle[row][column].left = color;
        break;
      case "right":
        puzzle[row][column].right = color;
        break;
    }
    refreshSubmit();
    notifyListeners();
  }

  int getLineColorBox(int row, int column, String dir) {
    int value = 0;

    switch(dir) {
      case "up":
        value = puzzle[row][column].up;
        break;
      case "down":
        value = puzzle[row][column].down;
        break;
      case "left":
        value = puzzle[row][column].left;
        break;
      case "right":
        value = puzzle[row][column].right;
        break;
    }
    return value;
  }

  ///color => 0 : normal, 1 : highLight
  void setBoxColor(int row, int column, int color) {
    puzzle[row][column].boxColor = color;
    refreshSubmit();
    notifyListeners();
  }

  int getBoxColor(int row, int column) {
    return puzzle[row][column].boxColor;
  }

  ///submit 기준으로 동작하는 함수
  ///
  ///(SquareBox 기준 + dir 제공 : setLineColorBox)
  void setLineColor(int row, int column, int color) {
    int puzzleRow = row == 0 ? 0 : (row - 1) ~/ 2;    //012->0, 34->1, 56->2
    int puzzleCol = row % 2 == 0 ? column :   //0->0, 1->1
      column <= 1 ? 0 : column - 1;           //01->1, 2->1

    if(row % 2 == 0) {
      if(row == 0) {
        puzzle[puzzleRow][puzzleCol].up = color;
      }
      else {
        puzzle[puzzleRow][puzzleCol].down = color;
      }
    }
    else {
      if(column == 0) {
        puzzle[puzzleRow][puzzleCol].left = color;
      }
      else {
        puzzle[puzzleRow][puzzleCol].right = color;
      }
    }

    refreshSubmit();
    notifyListeners();
  }

  void checkCompletePuzzle(BuildContext context) {
    //showComplete(context);
    //refresh submit
    for(int i = 0 ; i < puzzle.length ; i++) {
      for(int j = 0 ; j < puzzle[i].length ; j++) {

        if(i != 0 && j != 0) {
          submit[i + 3][j] = puzzle[i][j].down;
          //(1,19)->(3,19)  //(2,19)->(5,19)
          submit[i + 2][j] = puzzle[i][j].right;
        }
        else if(i == 0 && j != 0) {
          submit[i][j] = puzzle[i][j].up;
          submit[i + 2][j] = puzzle[i][j].down;
          submit[i + 1][j + 1] = puzzle[i][j].right;
        }
        else if(i != 0 && j == 0) {
          submit[i + 3][j] = puzzle[i][j].down;
          submit[i + 2][j] = puzzle[i][j].left;
          submit[i + 2][j + 1] = puzzle[i][j].right;
        }
        else if(i == 0 && j == 0) {
          submit[i][j] = puzzle[i][j].up;
          submit[i + 2][j] = puzzle[i][j].down;
          submit[i + 1][j] = puzzle[i][j].left;
          submit[i + 1][j + 1] = puzzle[i][j].right;
        }
      }
    }

    //compare submit and answer
    for(int i = 0 ; i < answer.length ; i++) {
      for(int j = 0 ; j < answer[i].length ; j++) {
        if(submit[i][j] != answer[i][j]) {
          return;
        }
      }
    }

    //complete puzzle
    //print("complete puzzle!");
    //clear continue puzzle
    //isComplete = true;
    showComplete(context);
    //UserInfo.ContinuePuzzle();
  }

  ///for getting hint item : [row, col, dir, `isWrongSubmit : bool`]
  Future<List<List<dynamic>>> checkCompletePuzzleCompletely(BuildContext context) async {
    List<List<dynamic>> rtValue = [];

    while(_isUpdating != 0) {
      Future.delayed(const Duration(milliseconds: 50));
      //print("wait in check : $_isUpdating");
    }
    submit = await readSquare.readSubmit(puzzle);

    String dir = "";
    int row = 0, col = 0;
    bool isWrongSubmit = true;

    //compare submit and answer
    for(int i = 0 ; i < answer.length ; i++) {
      for(int j = 0 ; j < answer[i].length ; j++) {
        //정답이라고 입력했는데 오답인 경우 || 오답이라고 입력했는데 정답인 경우
        //submit : 1~15, answer : 0,1
        if((submit[i][j] >= 1 && answer[i][j] == 0) || (submit[i][j] == -4 && answer[i][j] == 1)) {
          if (i <= 2) {
            if ((i % 2 == 0 && j == 0) || (i % 2 != 0 && j <= 1)) {
              row = 0;
              col = 0;

              if (i == 0) {
                dir = "up";
              } else if (i == 2) {
                dir = "down";
              } else if (i == 1 && j == 0) {
                dir = "left";
              } else if (i == 1 && j == 1) {
                dir = "right";
              }
            } else {
              row = 0;

              if (i == 0) {
                dir = "up";
                col = j;
              } else if (i == 2) {
                dir = "down";
                col = j;
              } else if (i == 1) {
                dir = "right";
                col = j - 1;
              }
            }
          } else {
            if ((i % 2 == 0 && j == 0) || (i % 2 != 0 && j <= 1)) {
              col = 0;

              if (i % 2 == 0) {
                dir = "down";
                row = (i - 1) ~/ 2;
              } else if (j == 0) {
                dir = "left";
                row = (i - 1) ~/ 2;
              } else if (j == 1) {
                dir = "right";
                row = (i - 1) ~/ 2;
              }
            } else {
              // 1번과 2번 조건 모두 불만족
              if (i % 2 == 0) {
                dir = "down";
                row = (i - 1) ~/ 2;
                col = j;
              } else {
                dir = "right";
                row = (i - 1) ~/ 2;
                col = j - 1;
              }
            }
          }

          rtValue.add([row, col, dir]);
        }
      }
    }

    //현재 입력한 데이터가 모두 정답인 경우, answer 중 입력되지 않은 것을 리턴
    if(rtValue.isEmpty) {
      isWrongSubmit = false;
      for(int i = 0 ; i < answer.length ; i++) {
        for(int j = 0 ; j < answer[i].length ; j++) {
          if(submit[i][j] == 0 && answer[i][j] == 1) {
            if (i <= 2) {
              if ((i % 2 == 0 && j == 0) || (i % 2 != 0 && j <= 1)) {
                row = 0;
                col = 0;

                if (i == 0) {
                  dir = "up";
                } else if (i == 2) {
                  dir = "down";
                } else if (i == 1 && j == 0) {
                  dir = "left";
                } else if (i == 1 && j == 1) {
                  dir = "right";
                }
              } else {
                row = 0;

                if (i == 0) {
                  dir = "up";
                  col = j;
                } else if (i == 2) {
                  dir = "down";
                  col = j;
                } else if (i == 1) {
                  dir = "right";
                  col = j - 1;
                }
              }
            } else {
              if ((i % 2 == 0 && j == 0) || (i % 2 != 0 && j <= 1)) {
                col = 0;

                if (i % 2 == 0) {
                  dir = "down";
                  row = (i - 1) ~/ 2;
                } else if (j == 0) {
                  dir = "left";
                  row = (i - 1) ~/ 2;
                } else if (j == 1) {
                  dir = "right";
                  row = (i - 1) ~/ 2;
                }
              } else {
                // 1번과 2번 조건 모두 불만족
                if (i % 2 == 0) {
                  dir = "down";
                  row = (i - 1) ~/ 2;
                  col = j;
                } else {
                  dir = "right";
                  row = (i - 1) ~/ 2;
                  col = j - 1;
                }
              }
            }

            rtValue.add([row, col, dir]);
          }
        }
      }
    }

    for(int i = 0 ; i < rtValue.length ; i++) {
      rtValue[i].add(isWrongSubmit);
    }
    return rtValue;
  }

  Future<void> showComplete(BuildContext context) async {
    //for handling HowToPlay
    if (gameStateSquare != null) {
      gameStateSquare!.isComplete = true;
    }
    UserInfo.clearPuzzle(loadKey);

    //delete sharedPreference key about label
    ExtractData prefs = ExtractData();
    List<String> item = ["Red", "Green", "Blue"];
    for(int i = 0 ; i < 3 ; i++) {
      String key = "${MainUI.getProgressKey()}_${item[i]}";

      //label data
      if(await prefs.containsKey(key)) {
        await prefs.removeKey(key);
      }
      //control do data with label
      if(await prefs.containsKey("${key}_do")) {
        await prefs.removeKey("${key}_do");
      }
    }

    //clear doValue normal & label
    await clearDoValue();
    //clear submit data
    await clearDoSubmit();

    // Show AlertDialog if isComplete is true
    WidgetsBinding.instance.addPostFrameCallback((_) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Game Completed'),
            content: const Text('Congratulations! You have completed the game.'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();  //close popup
                  shutdown = true;
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  });
                },
                child: const Text('OK'),
              ),
            ],
          );
        },
      );
    });
  }

  ///getter and setter about widgets

  List<Widget> getSquareField() {
    return squareField;
  }

  void setGameField(GameStateSquare gameField) {
    this.gameField = gameField;
    notifyListeners();
  }

  void setAnswer(List<List<int>> answer) {
    this.answer = answer;
  }

  void setSubmit(List<List<int>> submit) {
    this.submit = submit;
  }

  List<List<SquareBox>> getPuzzle() {
    return puzzle;
  }

  ///**********************************************************************************
  ///**********************************************************************************
  ///************************* about extract puzzle data ******************************
  ///**********************************************************************************
  ///**********************************************************************************
  Future<void> extractData() async {
    submit = await readSquare.readSubmit(puzzle);

    String temp = "[";
    for(int i = 0 ; i < submit.length ; i++) {
      temp += "[";
      for(int j = 0 ; j < submit[i].length ; j++) {
        temp += submit[i][j].toString();

        if(j < submit[i].length - 1) {
          temp += ", ";
        }
      }
      temp += "],\n";
    }

    temp = "${temp.substring(0, temp.length - 2)}]";
    ExtractData().saveStringToFile(temp, "filename.txt");
  }

  ///**********************************************************************************
  ///**********************************************************************************
  ///****************************** about undo & redo ******************************
  ///**********************************************************************************
  ///**********************************************************************************
  int _isUpdating = 0; //0: can update, 1,2 : in updateSquareBox, 3,0 : setDo
  List<List<List<int>>> doSubmit = [];
  int doPointer = -1;   //now position
  int doIndex = -1;     //max Index
  List<int> doPointerColor = [];  //for label
  List<int> doIndexColor = [];    //for label

  Future<void> initDoValue() async {
    String? value = await ExtractData().getDataFromLocal("${loadKey}_doValue");

    if(value == null) {
      doPointer = -1;
      doIndex = -1;
      doPointerColor= [-1, -1, -1];
      doIndexColor = [-1, -1, -1];

      return;
    }

    List<String> token = value.split("_");
    doPointer = int.parse(token[0]);
    doIndex = int.parse(token[1]);
    doPointerColor = token[2].split("@").map(int.parse).toList();
    doIndexColor = token[3].split("@").map(int.parse).toList();
    await loadDoSubmit();
  }
  Future<void> saveDoValue() async {
    //split with `@`
    String pointer = "${doPointerColor[0]}@${doPointerColor[1]}@${doPointerColor[2]}";
    String index = "${doIndexColor[0]}@${doIndexColor[1]}@${doIndexColor[2]}";
    //split with `_`
    String value = "${doPointer}_${doIndex}_${pointer}_$index";

    await ExtractData().saveDataToLocal("${loadKey}_doValue", value);
  }
  Future<void> clearDoValue() async {
    await ExtractData().removeKey("${loadKey}_doValue");
  }

  Future<void> saveDoSubmit({String? color}) async {
    List<String> flatList = [];
    for (var list2D in doSubmit) {
      List<String> tempList = [];
      for (var list1D in list2D) {
        String innerListString = list1D.join(',');
        tempList.add(innerListString);
      }
      flatList.add(tempList.join('_'));
    }

    String value = flatList.join('|');
    if(color == null) {
      await ExtractData().saveDataToLocal("${loadKey}__doSubmit", value);
    }
    else {
      await ExtractData().saveDataToLocal("${loadKey}_${color}_doSubmit", value);
    }

  }
  ///call in initDoValue() & change label
  Future<void> loadDoSubmit({String? color}) async {
    String? value = color == null
        ? await ExtractData().getDataFromLocal("${loadKey}__doSubmit")
        : await ExtractData().getDataFromLocal("${loadKey}_${color}_doSubmit");

    if(value == null) {
      doSubmit = [];
      doSubmit.add(await readSquare.readSubmit(puzzle));
      return;
    }

    List<String> list2DStrings = value.split('|');
    List<List<List<int>>> loadedDoSubmit = [];

    for (var list2DString in list2DStrings) {
      List<String> list1DStrings = list2DString.split('_');
      List<List<int>> list2D = [];

      for (var list1DString in list1DStrings) {
        if(list1DString.isEmpty) {
          continue;
        }
        List<int> list1D = list1DString.split(',').map(int.parse).toList();
        list2D.add(list1D);
      }
      loadedDoSubmit.add(list2D);
    }

    if(doPointer == -1) {
      return;
    }

    doSubmit = loadedDoSubmit.map((list2D) =>
        list2D.map((list1D) =>
        List<int>.from(list1D)
        ).toList()
    ).toList();

    for (var list1D in doSubmit[doPointer]) {
      submit.add(List<int>.from(list1D));
    }
  }
  Future<void> clearDoSubmit() async {
    await ExtractData().removeKey("${loadKey}_doSubmit");
  }

  Future<void> setDo() async {
    if(UserInfo.debugMode["print_isUpdating"]!) {
      print("call setDo : $_isUpdating");
    }
    while(_isUpdating != 1) {
      await Future.delayed(const Duration(milliseconds: 50));
    }
    _isUpdating = 2;
    if(UserInfo.debugMode["print_isUpdating"]!) {
      print("update setDo : $_isUpdating");
    }

    submit = await readSquare.readSubmit(puzzle);
    List<List<int>> lineData = submit.map((row) => List<int>.from(row)).toList();

    //when clicking square after click undo
    if(doPointer < doIndex) {
      doSubmit = doSubmit.sublist(0, doPointer + 1);
      doSubmit.add(lineData);
      doIndex = doSubmit.length - 1;
      doPointer = doIndex;
    }
    else {
      doSubmit.add(lineData);
      doIndex++;
      doPointer++;
    }
    _isUpdating = 3;
    if(UserInfo.debugMode["print_isUpdating"]!) {
      print("update setDo : $_isUpdating");
    }
  }

  Future<void> undo() async {
    await removeHintLine();

    if(doPointer >= 0) {
      doPointer--;
      if(doPointer >= 0) {
        submit = List.generate(
            doSubmit[doPointer].length,
            (i) => List.from(doSubmit[doPointer][i])
        );
      }
      //back to init
      else if(doPointer == -1) {
        for(int i = 0 ; i < submit.length ; i++) {
          for(int j = 0 ; j < submit[i].length ; j++) {
            submit[i][j] = 0;
          }
        }

        await clearLineForStart();
        notifyListeners();
        submit = await readSquare.readSubmit(puzzle);
        notifyListeners();
      }

      readSquare.writeSubmit(puzzle, submit);
      await refreshSubmit();
      notifyListeners();
    }
  }

  Future<void> redo() async {
    await removeHintLine();

    if(doPointer < doIndex) {
      doPointer++;
      submit = List.generate(
          doSubmit[doPointer].length,
              (i) => List.from(doSubmit[doPointer][i])
      );

      readSquare.writeSubmit(puzzle, submit);
      await refreshSubmit();
      notifyListeners();
    }
  }

  ///key : loadKey + color + `do`
  Future<void> controlDo({String key = "", bool save = false, bool load = false}) async {
    ExtractData prefs = ExtractData();

    try {
      if(save) {
        await prefs.saveDataToLocal(key, doPointer);
      }
      else if(load) {
        //초기화 후 라벨 로드를 하고 undo 하면 doSubmit이 존재하지 않음
        doPointer = int.parse(await prefs.getDataFromLocal(key));
        doIndex = doPointer;
        //doSubmit 배열도 복구
        await loadDoSubmit(color: key.split("_")[3]);
      }
    }
    catch(e) {
      // ignore: avoid_print
      print(e);
    }
  }

  Future<void> resetDo() async {
    doPointer = -1;
    doIndex = -1;
    doSubmit = [];
    _isUpdating = 0;
  }

  void printSubmit() {
    String temp = "";
    for(int i = 0 ; i < submit.length ; i++) {
      for(int j = 0 ; j < submit[i].length ; j++) {
        temp += "${submit[i][j]} ";
      }
      // ignore: avoid_print
      print("row $i | $temp");
      temp = "";
    }
  }

  void printSubmitSimple(List<List<int>> list) {
    // ignore: avoid_print
    print("submit : ${list.toString().replaceAll("0, ", "").replaceAll("0", "")}");
  }

  ///**********************************************************************************
  ///**********************************************************************************
  ///****************************** about load label ******************************
  ///**********************************************************************************
  ///**********************************************************************************
  void loadLabel(List<List<int>> submit) {
    this.submit = submit.map((innerList) => List<int>.from(innerList)).toList();
    applyUIWithAnswer(puzzle, this.submit);
    notifyListeners();
  }


  ///**********************************************************************************
  ///**********************************************************************************
  ///****************************** about color ******************************
  ///**********************************************************************************
  ///**********************************************************************************
  ///update `puzzle` variable
  Future<void> updateSquareBox(int row, int column, {int? up, int? down, int? left, int? right}) async {
    if(UserInfo.debugMode["print_isUpdating"]!) {
      print("==============================");
      print("call updateSquareBox : $_isUpdating");
    }
    while(_isUpdating != 0) {
      await Future.delayed(const Duration(milliseconds: 50));
      print("_isUpdating $_isUpdating");
    }
    await removeHintLine();
    _isUpdating = 1;
    if(UserInfo.debugMode["print_isUpdating"]!) {
      print("update updateSquareBox : $_isUpdating");
    }

    Set<int> nearColor = {};
    int lineValue = 0; //new line's value
    String pos = "";
    //print("up $up down $down left $left right $right");

    if (down != null) {
      nearColor = getNearColor(row, column, "down");
      lineValue = down;
      pos = "down";
    } else if (right != null) {
      nearColor = getNearColor(row, column, "right");
      lineValue = right;
      pos = "right";
    } else if (up != null) {
      nearColor = getNearColor(row, column, "up");
      lineValue = up;
      pos = "up";
    } else if (left != null) {
      nearColor = getNearColor(row, column, "left");
      lineValue = left;
      pos = "left";
    }
    //print("nearColor : $nearColor, lineValue : $lineValue");

    //forced line color
    if(lineValue <= 0) {
      if (down != null) {
        puzzle[row][column].down = lineValue;
      }
      else if (right != null) {
        puzzle[row][column].right = lineValue;
      }
      else if (up != null) {
        puzzle[row][column].up = lineValue;
      }
      else if (left != null) {
        puzzle[row][column].left = lineValue;
      }
    }
    //random line color
    else if(nearColor.isEmpty) {
      lineValue = themeColor.getNormalRandom();

      if (down != null) {
        puzzle[row][column].down = lineValue;
      }
      else if (right != null) {
        puzzle[row][column].right = lineValue;
      }
      else if (up != null) {
        puzzle[row][column].up = lineValue;
      }
      else if (left != null) {
        puzzle[row][column].left = lineValue;
      }
    }
    //continue line color
    else {
      lineValue = nearColor.first;
      List<dynamic> oldList = [];

      //새로 입력된 라인의 색만 처리하면 되는 경우
      //새로운 라인 주변에 0이 아닌 색이 1개만 있는 경우 getOldColorList 호출할 필요가 없음
      if(nearColor.length == 1) {
        if (down != null) {
          puzzle[row][column].down = lineValue;
        }
        else if (right != null) {
          puzzle[row][column].right = lineValue;
        }
        else if (up != null) {
          puzzle[row][column].up = lineValue;
        }
        else if (left != null) {
          puzzle[row][column].left = lineValue;
        }
      }

      if(_isUpdating == 1) {
        //print("standard color is $lineValue");
        //1개 이상의 라인 색을 변경해야 하는 경우
        if (down != null) {
          puzzle[row][column].down = lineValue;
          oldList = getOldColorList(row, column, "down", lineValue);
        }
        else if (right != null) {
          puzzle[row][column].right = lineValue;
          oldList = getOldColorList(row, column, "right", lineValue);
        }
        else if (up != null) {
          puzzle[row][column].up = lineValue;
          oldList = getOldColorList(row, column, "up", lineValue);
        }
        else if (left != null) {
          puzzle[row][column].left = lineValue;
          oldList = getOldColorList(row, column, "left", lineValue);
        }

        //print("\n★★★★★ oldList : $oldList\n");

        //change old list to new color
        for(int i = 0 ; i < oldList.length ; i++) {
          int oldRow = int.parse(oldList[i][0].toString());
          int oldColumn = int.parse(oldList[i][1].toString());
          String pos = oldList[i][2].toString();

          setLineColorBox(oldRow, oldColumn, pos, lineValue);
          //print("set [$oldRow, $oldColumn, $pos, $lineValue]");
        }
      }
    }

    submit = await readSquare.readSubmit(puzzle);
    notifyListeners();
    await setDo();
    ///TODO : -4일 때도 enable 되도록 처리
    await findBlockEnableDisable(row, column, pos, enable: lineValue <= 0, disable: lineValue > 0);
    notifyListeners();
    while(_isUpdating != 3) {
      await Future.delayed(const Duration(milliseconds: 50));
      print("_isUpdating $_isUpdating");
    }
    _isUpdating = 0;
    if(UserInfo.debugMode["print_isUpdating"]!) {
      print("update updateSquareBox : $_isUpdating");
    }
  }

  ///SquareBoxProvider List's index
  Set<int> getNearColor(int row, int col, String pos) {
    Set<int> use = {};

    if(row != 0 && col != 0) {
      switch(pos) {
        case "down":
          addIfPositive(use, puzzle[row][col - 1].down);
          addIfPositive(use, puzzle[row][col - 1].right);
          addIfPositive(use, puzzle[row][col].right);

          if(puzzle.length > row + 1) {
            addIfPositive(use, puzzle[row + 1][col - 1].right);
            addIfPositive(use, puzzle[row + 1][col].right);
          }
          if(puzzle[row].length > col + 1) {
            addIfPositive(use, puzzle[row][col + 1].down);
          }
          break;
        case "right":
          addIfPositive(use, puzzle[row - 1][col].right);
          addIfPositive(use, puzzle[row - 1][col].down);
          addIfPositive(use, puzzle[row][col].down);

          if(puzzle[row].length > col + 1) {
            addIfPositive(use, puzzle[row - 1][col + 1].down);
            addIfPositive(use, puzzle[row][col + 1].down);
          }
          if(puzzle.length > row + 1) {
            addIfPositive(use, puzzle[row + 1][col].right);
          }
          break;
      }
    }
    else if(row == 0 && col != 0) {
      switch(pos) {
        case "up":
          addIfPositive(use, puzzle[row][col - 1].up);
          addIfPositive(use, puzzle[row][col - 1].right);
          addIfPositive(use, puzzle[row][col].right);

          if(puzzle[row].length > col + 1) {
            addIfPositive(use, puzzle[row][col + 1].up);
          }
          break;
        case "down":
          addIfPositive(use, puzzle[row][col - 1].down);
          addIfPositive(use, puzzle[row][col - 1].right);
          addIfPositive(use, puzzle[row][col].right);

          if(puzzle[row].length > col + 1) {
            addIfPositive(use, puzzle[row][col + 1].down);
          }
          if(puzzle.length > row + 1) {
            addIfPositive(use, puzzle[row + 1][col - 1].right);
            addIfPositive(use, puzzle[row + 1][col].right);
          }
          break;
        case "right":
          addIfPositive(use, puzzle[row][col].up);
          addIfPositive(use, puzzle[row][col].down);

          if(puzzle[row].length > col + 1) {
            addIfPositive(use, puzzle[row][col + 1].up);
            addIfPositive(use, puzzle[row][col + 1].down);
          }
          if(puzzle.length > row + 1) {
            addIfPositive(use, puzzle[row + 1][col].right);
          }
          break;
      }
    }
    else if(row != 0 && col == 0) {
      switch(pos) {
        case "down":
          addIfPositive(use, puzzle[row][col].left);
          addIfPositive(use, puzzle[row][col].right);
          if(row + 1 < puzzle.length) {
            addIfPositive(use, puzzle[row + 1][col].left);
            addIfPositive(use, puzzle[row + 1][col].right);
          }
          if(col + 1 < puzzle[row].length) {
            addIfPositive(use, puzzle[row][col + 1].down);
          }
          break;
        case "left":
          addIfPositive(use, puzzle[row - 1][col].left);
          addIfPositive(use, puzzle[row - 1][col].down);
          addIfPositive(use, puzzle[row][col].down);

          if(puzzle.length > row + 1) {
            addIfPositive(use, puzzle[row + 1][col].left);
          }
          break;
        case "right":
          addIfPositive(use, puzzle[row - 1][col].right);
          addIfPositive(use, puzzle[row - 1][col].down);
          addIfPositive(use, puzzle[row][col].down);

          if(puzzle.length > row + 1) {
            addIfPositive(use, puzzle[row + 1][col].right);
          }
          if(col + 1 < puzzle[row].length) {
            addIfPositive(use, puzzle[row - 1][col + 1].down);
            addIfPositive(use, puzzle[row][col + 1].down);
          }
          break;
      }
    }
    else {    //row == 0 && col == 0
      switch(pos) {
        case "up":
          addIfPositive(use, puzzle[row][col].left);
          addIfPositive(use, puzzle[row][col].right);
          addIfPositive(use, puzzle[row][col + 1].up);
          break;
        case "down":
          addIfPositive(use, puzzle[row][col].left);
          addIfPositive(use, puzzle[row][col].right);
          addIfPositive(use, puzzle[row + 1][col].left);
          addIfPositive(use, puzzle[row + 1][col].right);
          addIfPositive(use, puzzle[row][col + 1].down);
          break;
        case "left":
          addIfPositive(use, puzzle[row][col].up);
          addIfPositive(use, puzzle[row][col].down);
          addIfPositive(use, puzzle[row + 1][col].left);
          break;
        case "right":
          addIfPositive(use, puzzle[row][col].up);
          addIfPositive(use, puzzle[row][col].down);
          addIfPositive(use, puzzle[row][col + 1].up);
          addIfPositive(use, puzzle[row][col + 1].down);
          addIfPositive(use, puzzle[row + 1][col].right);
          break;
      }
    }

    use.remove(0);
    return use;
  }

  void addIfPositive(Set<int> use, int value) {
    if(value > 0) {
      use.add(value);
    }
  }

  ///클릭한 라인 기준으로 가장 가까운 변경해야 할 라인을 하나 찾아서 getContinueOld()로 넘기는 메소드
  List<dynamic> getOldColorList(int row, int col, String pos, int now) {
    //[row, col, pos]
    ///rtValue는 값을 now로 변경해야 할 목록
    List<dynamic> rtValue = [];

    //same as getNearColor except for comparing color
    if(row != 0 && col != 0) {
      switch(pos) {
        case "down":
        //use.add(puzzle[row][col - 1].down);
          if(puzzle[row][col - 1].down > 0 && puzzle[row][col - 1].down != now) {
            rtValue.add([row, col - 1, "down"]);
          }
          if (puzzle[row][col - 1].right > 0 && puzzle[row][col - 1].right != now) {
            rtValue.add([row, col - 1, "right"]);
          }
          if (puzzle[row][col].right > 0 && puzzle[row][col].right != now) {
            rtValue.add([row, col, "right"]);
          }
          if (puzzle.length > row + 1) {
            if (puzzle[row + 1][col - 1].right > 0 && puzzle[row + 1][col - 1].right != now) {
              rtValue.add([row + 1, col - 1, "right"]);
            }
            if (puzzle[row + 1][col].right > 0 && puzzle[row + 1][col].right != now) {
              rtValue.add([row + 1, col, "right"]);
            }
          }
          if (puzzle[row].length > col + 1) {
            if (puzzle[row][col + 1].down > 0 && puzzle[row][col + 1].down != now) {
              rtValue.add([row, col + 1, "down"]);
            }
          }
          break;
        case "right":
          if (puzzle[row - 1][col].right > 0 && puzzle[row - 1][col].right != now) {
            rtValue.add([row - 1, col, "right"]);
          }
          if (puzzle[row - 1][col].down > 0 && puzzle[row - 1][col].down != now) {
            rtValue.add([row - 1, col, "down"]);
          }
          if (puzzle[row][col].down > 0 && puzzle[row][col].down != now) {
            rtValue.add([row, col, "down"]);
          }
          if (puzzle[row].length > col + 1) {
            if (puzzle[row - 1][col + 1].down > 0 && puzzle[row - 1][col + 1].down != now) {
              rtValue.add([row - 1, col + 1, "down"]);
            }
            if (puzzle[row][col + 1].down > 0 && puzzle[row][col + 1].down != now) {
              rtValue.add([row, col + 1, "down"]);
            }
          }
          if (puzzle.length > row + 1) {
            if (puzzle[row + 1][col].right > 0 && puzzle[row + 1][col].right != now) {
              rtValue.add([row + 1, col, "right"]);
            }
          }
          break;
      }
    }
    else if (row == 0 && col != 0) {
      switch (pos) {
        case "up":
          if (puzzle[row][col - 1].up > 0 && puzzle[row][col - 1].up != now) {
            rtValue.add([row, col - 1, "up"]);
          }
          if (puzzle[row][col - 1].right > 0 && puzzle[row][col - 1].right != now) {
            rtValue.add([row, col - 1, "right"]);
          }
          if (puzzle[row][col].right > 0 && puzzle[row][col].right != now) {
            rtValue.add([row, col, "right"]);
          }
          if (puzzle[row].length > col + 1) {
            if (puzzle[row][col + 1].up > 0 && puzzle[row][col + 1].up != now) {
              rtValue.add([row, col + 1, "up"]);
            }
          }
          break;
        case "down":
          if (puzzle[row][col - 1].down > 0 && puzzle[row][col - 1].down != now) {
            rtValue.add([row, col - 1, "down"]);
          }
          if (puzzle[row][col - 1].right > 0 && puzzle[row][col - 1].right != now) {
            rtValue.add([row, col - 1, "right"]);
          }
          if (puzzle[row][col].right > 0 && puzzle[row][col].right != now) {
            rtValue.add([row, col, "right"]);
          }
          if (puzzle[row].length > col + 1) {
            if (puzzle[row][col + 1].down > 0 && puzzle[row][col + 1].down != now) {
              rtValue.add([row, col + 1, "down"]);
            }
          }
          if (puzzle.length > row + 1) {
            if (puzzle[row + 1][col - 1].right > 0 && puzzle[row + 1][col - 1].right != now) {
              rtValue.add([row + 1, col - 1, "right"]);
            }
            if (puzzle[row + 1][col].right > 0 && puzzle[row + 1][col].right != now) {
              rtValue.add([row + 1, col, "right"]);
            }
          }
          break;
        case "right":
          if (puzzle[row][col].up > 0 && puzzle[row][col].up != now) {
            rtValue.add([row, col, "up"]);
          }
          if (puzzle[row][col].down > 0 && puzzle[row][col].down != now) {
            rtValue.add([row, col, "down"]);
          }
          if (puzzle[row].length > col + 1) {
            if (puzzle[row][col + 1].up > 0 && puzzle[row][col + 1].up != now) {
              rtValue.add([row, col + 1, "up"]);
            }
            if (puzzle[row][col + 1].down > 0 && puzzle[row][col + 1].down != now) {
              rtValue.add([row, col + 1, "down"]);
            }
          }
          if (puzzle.length > row + 1) {
            if (puzzle[row + 1][col].right > 0 && puzzle[row + 1][col].right != now) {
              rtValue.add([row + 1, col, "right"]);
            }
          }
          break;
      }
    }
    else if (row != 0 && col == 0) {
      switch (pos) {
        case "down":
          if (puzzle[row][col].left > 0 && puzzle[row][col].left != now) {
            rtValue.add([row, col, "left"]);
          }
          if (puzzle[row][col].right > 0 && puzzle[row][col].right != now) {
            rtValue.add([row, col, "right"]);
          }
          if (puzzle[row + 1][col].left > 0 && puzzle[row + 1][col].left != now) {
            rtValue.add([row + 1, col, "left"]);
          }
          if (puzzle[row + 1][col].right > 0 && puzzle[row + 1][col].right != now) {
            rtValue.add([row + 1, col, "right"]);
          }
          if (puzzle[row][col + 1].down > 0 && puzzle[row][col + 1].down != now) {
            rtValue.add([row, col + 1, "down"]);
          }
          break;
        case "left":
          if (puzzle[row - 1][col].left > 0 && puzzle[row - 1][col].left != now) {
            rtValue.add([row - 1, col, "left"]);
          }
          if (puzzle[row - 1][col].down > 0 && puzzle[row - 1][col].down != now) {
            rtValue.add([row - 1, col, "down"]);
          }
          if (puzzle[row][col].down > 0 && puzzle[row][col].down != now) {
            rtValue.add([row, col, "down"]);
          }
          if (puzzle.length > row + 1) {
            if (puzzle[row + 1][col].left > 0 && puzzle[row + 1][col].left != now) {
              rtValue.add([row + 1, col, "left"]);
            }
          }
          break;
        case "right":
          if (puzzle[row - 1][col].right > 0 && puzzle[row - 1][col].right != now) {
            rtValue.add([row - 1, col, "right"]);
          }
          if (puzzle[row - 1][col].down > 0 && puzzle[row - 1][col].down != now) {
            rtValue.add([row - 1, col, "down"]);
          }
          if (puzzle[row - 1][col + 1].down > 0 && puzzle[row - 1][col + 1].down != now) {
            rtValue.add([row - 1, col + 1, "down"]);
          }
          if (puzzle[row][col].down > 0 && puzzle[row][col].down != now) {
            rtValue.add([row, col, "down"]);
          }
          if (puzzle[row][col + 1].down > 0 && puzzle[row][col + 1].down != now) {
            rtValue.add([row, col + 1, "down"]);
          }
          if (puzzle.length > row + 1) {
            if (puzzle[row + 1][col].right > 0 && puzzle[row + 1][col].right != now) {
              rtValue.add([row + 1, col, "right"]);
            }
          }
          break;
      }
    }
    else {
      switch(pos) {
        case "up":
          if (puzzle[row][col].left > 0 && puzzle[row][col].left != now) {
            rtValue.add([row, col, "left"]);
          }
          if (puzzle[row][col].right > 0 && puzzle[row][col].right != now) {
            rtValue.add([row, col, "right"]);
          }
          if (puzzle[row][col + 1].up > 0 && puzzle[row][col + 1].up != now) {
            rtValue.add([row, col + 1, "up"]);
          }
          break;
        case "down":
          if (puzzle[row][col].left > 0 && puzzle[row][col].left != now) {
            rtValue.add([row, col, "left"]);
          }
          if (puzzle[row][col].right > 0 && puzzle[row][col].right != now) {
            rtValue.add([row, col, "right"]);
          }
          if (puzzle[row + 1][col].left > 0 && puzzle[row + 1][col].left != now) {
            rtValue.add([row + 1, col, "left"]);
          }
          if (puzzle[row + 1][col].right > 0 && puzzle[row + 1][col].right != now) {
            rtValue.add([row + 1, col, "right"]);
          }
          if (puzzle[row][col + 1].down > 0 && puzzle[row][col + 1].down != now) {
            rtValue.add([row, col + 1, "down"]);
          }
          break;
        case "left":
          if (puzzle[row][col].up > 0 && puzzle[row][col].up != now) {
            rtValue.add([row, col, "up"]);
          }
          if (puzzle[row][col].down > 0 && puzzle[row][col].down != now) {
            rtValue.add([row, col, "down"]);
          }
          if (puzzle[row + 1][col].left > 0 && puzzle[row + 1][col].left != now) {
            rtValue.add([row + 1, col, "left"]);
          }
          break;
        case "right":
          if (puzzle[row][col].up > 0 && puzzle[row][col].up != now) {
            rtValue.add([row, col, "up"]);
          }
          if (puzzle[row][col].down > 0 && puzzle[row][col].down != now) {
            rtValue.add([row, col, "down"]);
          }
          if (puzzle[row][col + 1].up > 0 && puzzle[row][col + 1].up != now) {
            rtValue.add([row, col + 1, "up"]);
          }
          if (puzzle[row][col + 1].down > 0 && puzzle[row][col + 1].down != now) {
            rtValue.add([row, col + 1, "down"]);
          }
          if (puzzle[row + 1][col].right > 0 && puzzle[row + 1][col].right != now) {
            rtValue.add([row + 1, col, "right"]);
          }
          break;
      }
    }

    //print("end of getOldColorList : $rtValue");
    if(rtValue.isEmpty) {
      return [];
    }
    //return rtValue;
    return getContinueOld(rtValue);
  }

  ///변경해야 하는 라인 하나를 받아, 변경이 필요한 모든 라인을 찾아 반환하는 메소드
  List<dynamic> getContinueOld(List<dynamic> start) {
    List<List<dynamic>> rtTempList = [start[0]];

    int row = int.parse(start[0][0].toString());
    int col = int.parse(start[0][1].toString());
    String pos = start[0][2].toString();
    int find = 0;
    //print("getContinueOld row $row, col $col, pos $pos");

    switch(pos) {
      case "down":
        find = puzzle[row][col].down;
        break;
      case "right":
        find = puzzle[row][col].right;
        break;
      case "up":
        find = puzzle[row][col].up;
        break;
      case "left":
        find = puzzle[row][col].left;
        break;
    }

    int count = 0;
    do {
      //print("\n find color(will be changed) is $find / time ${count + 1}");
      if(rtTempList.length <= count) {
        break;
      }
      //set now standard
      row = int.parse(rtTempList[count][0].toString());
      col = int.parse(rtTempList[count][1].toString());
      pos = rtTempList[count][2];
      //print("NOW : row $row col $col len ${rtTempList.length}");
      count++;

      //same as find color
      if(row != 0 && col != 0) {
        switch(pos) {
          case "down":
          //use.add(puzzle[row][col - 1].down);
            if(puzzle[row][col - 1].down == find) {
              addIfNotExist(rtTempList, [row, col - 1, "down"]);
            }
            if (puzzle[row][col - 1].right == find) {
              addIfNotExist(rtTempList, [row, col - 1, "right"]);
            }
            if (puzzle[row][col].right == find) {
              addIfNotExist(rtTempList, [row, col, "right"]);
            }
            if (puzzle.length > row + 1) {
              if (puzzle[row + 1][col - 1].right == find) {
                addIfNotExist(rtTempList, [row + 1, col - 1, "right"]);
              }
              if (puzzle[row + 1][col].right == find) {
                addIfNotExist(rtTempList, [row + 1, col, "right"]);
              }
            }
            if (puzzle[row].length > col + 1) {
              if (puzzle[row][col + 1].down == find) {
                addIfNotExist(rtTempList, [row, col + 1, "down"]);
              }
            }
            break;
          case "right":
            if (puzzle[row - 1][col].right == find) {
              addIfNotExist(rtTempList, [row - 1, col, "right"]);
            }
            if (puzzle[row - 1][col].down == find) {
              addIfNotExist(rtTempList, [row - 1, col, "down"]);
            }
            if (puzzle[row][col].down == find) {
              addIfNotExist(rtTempList, [row, col, "down"]);
            }
            if (puzzle[row].length > col + 1) {
              if (puzzle[row - 1][col + 1].down == find) {
                addIfNotExist(rtTempList, [row - 1, col + 1, "down"]);
              }
              if (puzzle[row][col + 1].down == find) {
                addIfNotExist(rtTempList, [row, col + 1, "down"]);
              }
            }
            if (puzzle.length > row + 1) {
              if (puzzle[row + 1][col].right == find) {
                addIfNotExist(rtTempList, [row + 1, col, "right"]);
              }
            }
            break;
        }
      }
      else if (row == 0 && col != 0) {
        switch (pos) {
          case "up":
            if (puzzle[row][col - 1].up == find) {
              addIfNotExist(rtTempList, [row, col - 1, "up"]);
            }
            if (puzzle[row][col - 1].right == find) {
              addIfNotExist(rtTempList, [row, col - 1, "right"]);
            }
            if (puzzle[row][col].right == find) {
              addIfNotExist(rtTempList, [row, col, "right"]);
            }
            if (puzzle[row].length > col + 1) {
              if (puzzle[row][col + 1].up == find) {
                addIfNotExist(rtTempList, [row, col + 1, "up"]);
              }
            }
            break;
          case "down":
            if (puzzle[row][col - 1].down == find) {
              addIfNotExist(rtTempList, [row, col - 1, "down"]);
            }
            if (puzzle[row][col - 1].right == find) {
              addIfNotExist(rtTempList, [row, col - 1, "right"]);
            }
            if (puzzle[row][col].right == find) {
              addIfNotExist(rtTempList, [row, col, "right"]);
            }
            if (puzzle[row].length > col + 1) {
              if (puzzle[row][col + 1].down == find) {
                addIfNotExist(rtTempList, [row, col + 1, "down"]);
              }
            }
            if (puzzle.length > row + 1) {
              if (puzzle[row + 1][col - 1].right == find) {
                addIfNotExist(rtTempList, [row + 1, col - 1, "right"]);
              }
              if (puzzle[row + 1][col].right == find) {
                addIfNotExist(rtTempList, [row + 1, col, "right"]);
              }
            }
            break;
          case "right":
            if (puzzle[row][col].up == find) {
              addIfNotExist(rtTempList, [row, col, "up"]);
            }
            if (puzzle[row][col].down == find) {
              addIfNotExist(rtTempList, [row, col, "down"]);
            }
            if (puzzle[row].length > col + 1) {
              if (puzzle[row][col + 1].up == find) {
                addIfNotExist(rtTempList, [row, col + 1, "up"]);
              }
              if (puzzle[row][col + 1].down == find) {
                addIfNotExist(rtTempList, [row, col + 1, "down"]);
              }
            }
            if (puzzle.length > row + 1) {
              if (puzzle[row + 1][col].right == find) {
                addIfNotExist(rtTempList, [row + 1, col, "right"]);
              }
            }
            break;
        }
      }
      else if (row != 0 && col == 0) {
        switch (pos) {
          case "down":
            if (puzzle[row][col].left == find) {
              addIfNotExist(rtTempList, [row, col, "left"]);
            }
            if (puzzle[row][col].right == find) {
              addIfNotExist(rtTempList, [row, col, "right"]);
            }
            if (puzzle[row][col + 1].down == find) {
              addIfNotExist(rtTempList, [row, col + 1, "down"]);
            }
            if(row + 1 < puzzle.length) {
              if (puzzle[row + 1][col].left == find) {
                addIfNotExist(rtTempList, [row + 1, col, "left"]);
              }
              if (puzzle[row + 1][col].right == find) {
                addIfNotExist(rtTempList, [row + 1, col, "right"]);
              }
            }
            break;
          case "left":
            if (puzzle[row - 1][col].left == find) {
              addIfNotExist(rtTempList, [row - 1, col, "left"]);
            }
            if (puzzle[row - 1][col].down == find) {
              addIfNotExist(rtTempList, [row - 1, col, "down"]);
            }
            if (puzzle[row][col].down == find) {
              addIfNotExist(rtTempList, [row, col, "down"]);
            }
            if (puzzle.length > row + 1) {
              if (puzzle[row + 1][col].left == find) {
                addIfNotExist(rtTempList, [row + 1, col, "left"]);
              }
            }
            break;
          case "right":
            if (puzzle[row - 1][col].right == find) {
              addIfNotExist(rtTempList, [row - 1, col, "right"]);
            }
            if (puzzle[row - 1][col].down == find) {
              addIfNotExist(rtTempList, [row - 1, col, "down"]);
            }
            if (puzzle[row - 1][col + 1].down == find) {
              addIfNotExist(rtTempList, [row - 1, col + 1, "down"]);
            }
            if (puzzle[row][col].down == find) {
              addIfNotExist(rtTempList, [row, col, "down"]);
            }
            if (puzzle.length > row + 1) {
              if (puzzle[row + 1][col].right == find) {
                addIfNotExist(rtTempList, [row + 1, col, "right"]);
              }
              if (puzzle[row + 1][col + 1].down == find) {
                addIfNotExist(rtTempList, [row + 1, col + 1, "down"]);
              }
            }
            break;
        }
      }
      else {
        switch(pos) {
          case "up":
            if (puzzle[row][col].left == find) {
              addIfNotExist(rtTempList, [row, col, "left"]);
            }
            if (puzzle[row][col].right == find) {
              addIfNotExist(rtTempList, [row, col, "right"]);
            }
            if (puzzle[row + 1][col].up == find) {
              addIfNotExist(rtTempList, [row + 1, col, "up"]);
            }
            break;
          case "down":
            if (puzzle[row][col].left == find) {
              addIfNotExist(rtTempList, [row, col, "left"]);
            }
            if (puzzle[row][col].right == find) {
              addIfNotExist(rtTempList, [row, col, "right"]);
            }
            if (puzzle[row + 1][col].left == find) {
              addIfNotExist(rtTempList, [row + 1, col, "left"]);
            }
            if (puzzle[row + 1][col].right == find) {
              addIfNotExist(rtTempList, [row + 1, col, "right"]);
            }
            if (puzzle[row][col + 1].down == find) {
              addIfNotExist(rtTempList, [row, col + 1, "down"]);
            }
            break;
          case "left":
            if (puzzle[row][col].up == find) {
              addIfNotExist(rtTempList, [row, col, "up"]);
            }
            if (puzzle[row][col].down == find) {
              addIfNotExist(rtTempList, [row, col, "down"]);
            }
            if (puzzle[row + 1][col].left == find) {
              addIfNotExist(rtTempList, [row + 1, col, "left"]);
            }
            break;
          case "right":
            if (puzzle[row][col].up == find) {
              addIfNotExist(rtTempList, [row, col, "up"]);
            }
            if (puzzle[row][col].down == find) {
              addIfNotExist(rtTempList, [row, col, "down"]);
            }
            if (puzzle[row][col + 1].up == find) {
              addIfNotExist(rtTempList, [row, col + 1, "up"]);
            }
            if (puzzle[row][col + 1].down == find) {
              addIfNotExist(rtTempList, [row, col + 1, "down"]);
            }
            if (puzzle[row + 1][col].right == find) {
              addIfNotExist(rtTempList, [row + 1, col, "right"]);
            }
            break;
        }
      }

      //print("rtTempList $rtTempList");

    } while(true);


    //print("end of getContinueOld : ${rtTempList.toList()}");
    return rtTempList.toList();
  }

  void addIfNotExist(List<List<dynamic>> list, List<dynamic> item) {
    if (!list.any((element) =>
    element[0] == item[0] && element[1] == item[1] && element[2] == item[2])) {
      list.add(item);
    }
  }

  ///**********************************************************************************
  ///**********************************************************************************
  ///******************** default setting of making puzzle ********************
  ///**********************************************************************************
  ///**********************************************************************************
  List<List<SquareBox>> initSquarePuzzle(width, height) {
    List<List<SquareBox>> puzzle = [];
    List<SquareBox> temp = [];
    int i, j;

    for(i = 0 ; i < height ; i++) {
      temp = [];

      for(j = 0 ; j < width ; j++) {
        if(i == 0 && j == 0) {
          temp.add(SquareBox(isFirstRow: true, isFirstColumn: true, row: i, column: j,));
        } else if(i == 0) {
          temp.add(SquareBox(isFirstRow: true, row: i, column: j,));
        } else if(j == 0) {
          temp.add(SquareBox(isFirstColumn: true, row: i, column: j,));
        } else {
          temp.add(SquareBox(row: i, column: j,));
        }
      }
      puzzle.add(temp);
    }

    return puzzle;
  }

  Future<List<Widget>> buildSquarePuzzleAnswer(List<List<int>> answer, {bool isContinue = false}) async {
    //resize puzzle
    if(answer.isEmpty) {
      //print("answer is empty");
      return Future.value([]);
    }
    puzzle = initSquarePuzzle(answer[0].length, answer.length ~/ 2);
    //print("puzzle SquareBoxProvider => row ${puzzle.length}, col ${puzzle[0].length}");
    List<Widget> columnChildren = [];

    //marking answer line
    applyUIWithAnswer(puzzle, answer);

    for (int i = 0; i < puzzle.length; i++) {
      List<Widget> rowChildren = [];
      for (int j = 0; j < puzzle[i].length; j++) {
        rowChildren.add(puzzle[i][j]);
      }
      columnChildren.add(
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: rowChildren,
        ),
      );
    }
    //marking number with answer
    setNumWithAnswer(puzzle);
    //setDefaultLineStep1(puzzle);
    clearLineForStart();

    //apply saved submit lines
    if(isContinue) {
      applyUIWithAnswer(puzzle, submit);
    }

    return columnChildren;
  }

  //answer is key-value pair
  void applyUIWithAnswer(List<List<SquareBox>> puzzle, List<List<int>> answer) {
    int lineType;

    for(int i = 0 ; i < answer.length ; i++) {      //10 ,11, 10, 11...
      for (int j = 0; j < answer[i].length; j++) {  //3, 5, 7, 9...
        lineType = answer[i][j];
        //print("list $i $j / $lineType");

        if(i <= 2 && j <= 1) {  //up, down, left, right 모두 존재
          if(i == 0) {
            puzzle[0][j].up = lineType;
          } else if(i == 2) {
            puzzle[0][j].down = lineType;
          } else {
            if(j == 0) {
              puzzle[0][0].left = lineType;
            } else {
              puzzle[0][0].right = lineType;
            }
          }
        } else if(i <= 2) { //up, down, right 3개 존재
          if(i == 0) {
            puzzle[0][j].up = lineType;
          } else if(i == 1) {
            puzzle[0][j - 1].right = lineType;
          } else {
            puzzle[0][j].down = lineType;
          }
        } else if(j <= 1) { //down, left, right 3개 존재
          if(i % 2 == 0) {
            puzzle[(i - 1) ~/ 2][j].down = lineType;
          } else {
            if(j == 0) {
              puzzle[i ~/ 2][0].left = lineType;
            } else {
              puzzle[i ~/ 2][0].right = lineType;
            }
          }
        } else {            //down, right 2개 존재
          if(i % 2 == 0) {
            //puzzle[(i - 1) ~/ 2 + 1][j + 1].down = lineType;
            //i=4,j=1 => 1,1  //10,2 => 4,2
            //20,3 => 9,3     //12,7 => 5,7
            puzzle[i ~/ 2 - 1][j].down = lineType;
          } else {
            puzzle[(i - 1) ~/ 2][j - 1].right = lineType;
          }
        }
      }
    }
  }

  void setNumWithAnswer(List<List<SquareBox>> puzzle) {
    int count = 0;

    for(int i = 0 ; i < puzzle.length ; i++) {
      for(int j = 0 ; j < puzzle[i].length ; j++) {
        count = 0;

        if(i != 0 && j != 0) {
          if(puzzle[i - 1][j].down != 0) { count++; } //puzzle[i][j].up
          if(puzzle[i][j].down != 0) { count++; }
          if(puzzle[i][j - 1].right != 0) { count++; } //puzzle[i][j].left
          if(puzzle[i][j].right != 0) { count++; }
        } else if(i != 0 && j == 0) {
          if(puzzle[i - 1][j].down != 0) { count++; } //puzzle[i][j].up
          if(puzzle[i][j].down != 0) { count++; }
          if(puzzle[i][j].left != 0) { count++; }
          if(puzzle[i][j].right != 0) { count++; }
        } else if(i == 0 && j != 0) {
          if(puzzle[i][j].up != 0) { count++; }
          if(puzzle[i][j].down != 0) { count++; }
          if(puzzle[i][j - 1].right != 0) { count++; } //puzzle[i][j].left
          if(puzzle[i][j].right != 0) { count++; }
        } else {
          if(puzzle[i][j].up != 0) { count++; }
          if(puzzle[i][j].down != 0) { count++; }
          if(puzzle[i][j].left != 0) { count++; }
          if(puzzle[i][j].right != 0) { count++; }
        }

        puzzle[i][j].num = count;
      }
    }
  }

  Future<void> clearLineForStart() async {
    for(int i = 0 ; i < puzzle.length ; i++) {
      for(int j = 0 ; j < puzzle[i].length ; j++) {
        if(i != 0 && j != 0) {
          puzzle[i][j].down = 0;
          puzzle[i][j].right = 0;
        }
        else if(i == 0 && j != 0) {
          puzzle[i][j].up = 0;
          puzzle[i][j].down = 0;
          puzzle[i][j].right = 0;
        }
        else if(i != 0 && j == 0) {
          puzzle[i][j].down = 0;
          puzzle[i][j].left = 0;
          puzzle[i][j].right = 0;
        }
        else {
          puzzle[i][j].up = 0;
          puzzle[i][j].down = 0;
          puzzle[i][j].left = 0;
          puzzle[i][j].right = 0;
        }
      }
    }

    await setDefaultLineStep1();
  }

  ///find SquareBox(num is zero) and set color -1
  Future<void> setDefaultLineStep1() async {
    for(int i = 0 ; i < puzzle.length ; i++) {
      for(int j = 0 ; j < puzzle[i].length ; j++) {
        if(puzzle[i][j].num == 0) {
          if(i != 0 && j != 0) {
            puzzle[i - 1][j].down = -1;
            puzzle[i][j].down = -1;
            puzzle[i][j - 1].right = -1;
            puzzle[i][j].right = -1;
          }
          else if(i == 0 && j != 0) {
            puzzle[i][j].up = -1;
            puzzle[i][j].down = -1;
            puzzle[i][j - 1].right = -1;
            puzzle[i][j].right = -1;
          }
          else if(i != 0 && j == 0) {
            puzzle[i - 1][j].down = -1;
            puzzle[i][j].down = -1;
            puzzle[i][j].left = -1;
            puzzle[i][j].right = -1;
          }
          else {
            puzzle[i][j].up = -1;
            puzzle[i][j].down = -1;
            puzzle[i][j].left = -1;
            puzzle[i][j].right = -1;
          }
        }
      }  
    }

    await setDefaultLineStep2();
  }

  Future<void> setDefaultLineStep2() async {
    await setDefaultLineStep2Inner();
    await setDefaultLineStep2Inner();
  }

  ///내부 라인인 경우 상|하|좌|우 중 3개의 -1이 인접하면 해당 라인이 -1
  ///
  ///테두리 라인인 경우 상|하|좌|우 중 2개의 -1이 인접하면 해당 라인이 -1
  ///
  /// 모서리 라인인 경우 상|하|좌|우 중 1~2개의 -1이 인접하면 해당 라인이 -1
  Future<void> setDefaultLineStep2Inner() async {
    int value = 0;

    for (int i = 0; i < puzzle.length; i++) {
      for (int j = 0; j < puzzle[i].length; j++) {
        if(i > 0 && j > 0) {
          //puzzle[i][j].down
          {
            value = 0;
            //check left
            value = max(puzzle[i][j - 1].down, puzzle[i][j - 1].right);
            if(i + 1 < puzzle.length) {
              value = max(value, puzzle[i + 1][j - 1].right);
            }
            //check right
            if(value == 0) {
              value = puzzle[i][j].right;
              if(i + 1 < puzzle.length) {
                value = max(value, puzzle[i + 1][j].right);
              }
              if(j + 1 < puzzle[i].length) {
                value = max(value, puzzle[i][j + 1].down);
              }
            }

            if(puzzle[i][j].down == 0) {
              puzzle[i][j].down = value;
            }
          }
          //puzzle[i][j].right
          {
            value = 0;
            //check up
            value = max(puzzle[i - 1][j].down, puzzle[i - 1][j].right);
            if(j + 1 < puzzle[i].length) {
              value = max(value, puzzle[i - 1][j + 1].down);
            }
            //check down
            if(value == 0) {
              value = puzzle[i][j].down;
              if(i + 1 < puzzle.length) {
                value = max(value, puzzle[i + 1][j].right);
              }
              if(j + 1 < puzzle[i].length) {
                value = max(value, puzzle[i][j + 1].down);
              }
            }

            if(puzzle[i][j].right == 0) {
              puzzle[i][j].right = value;
            }
          }
        }
        else if(i == 0 && j != 0) {
          //puzzle[i][j].up
          {
            value = 0;
            //left
            value = max(puzzle[i][j - 1].up, puzzle[i][j - 1].right);
            //right
            if(value == 0) {
              if(j + 1 < puzzle[i].length) {
                value = max(puzzle[i][j].right, puzzle[i][j + 1].up);
              }
              else {
                value = puzzle[i][j].right;
              }
            }
            if(puzzle[i][j].up == 0) {
              puzzle[i][j].up = value;
            }
          }
          //puzzle[i][j].down
          {
            value = 0;
            //left
            value = max(puzzle[i][j - 1].right, max(puzzle[i][j - 1].down, puzzle[i + 1][j - 1].right));
            if(value == 0){
              //right
              if(j + 1 < puzzle[i].length) {
                value = max(puzzle[i][j + 1].down, max(puzzle[i][j].right, puzzle[i + 1][j].right));
              }
              else {
                value = max(puzzle[i][j].right, puzzle[i + 1][j].right);
              }
            }
            if(puzzle[i][j].down == 0) {
              puzzle[i][j].down = value;
            }
          }
          //puzzle[i][j].right
          {
            value = 0;
            //up
            if(j + 1 < puzzle[i].length) {
              value = max(puzzle[i][j].up, puzzle[i][j + 1].up);
            }
            else {
              value = puzzle[i][j].up;
            }
            //down
            if(value == 0) {
              value = max(puzzle[i][j].down, puzzle[i + 1][j].right);
              if(j + 1 < puzzle[i].length) {
                value = max(value, puzzle[i][j + 1].down);
              }
            }
            if(puzzle[i][j].right == 0) {
              puzzle[i][j].right = value;
            }
          }
        }
        else if(i != 0 && j == 0) {
          //puzzle[i][j].left
          {
            value = 0;
            //up
            value = max(puzzle[i - 1][j].left, puzzle[i - 1][j].down);
            //down
            if(value == 0) {
              if(i + 1 < puzzle.length) {
                value = max(puzzle[i][j].down, puzzle[i + 1][j].left);
              }
              else {
                value = puzzle[i][j].down;
              }
            }

            if(puzzle[i][j].left == 0) {
              puzzle[i][j].left = value;
            }
          }
          //puzzle[i][j].right
          {
            value = 0;
            //up
            value = max(max(puzzle[i - 1][j].down, puzzle[i - 1][j].right), puzzle[i - 1][j + 1].down);
            //down
            if(value == 0) {
              if(i + 1 < puzzle.length) {
                value = max(puzzle[i + 1][j].right, max(puzzle[i][j].down, puzzle[i][j + 1].down));
              }
              else {
                value = max(puzzle[i][j].down, puzzle[i][j + 1].down);
              }
            }

            if(puzzle[i][j].right == 0) {
              puzzle[i][j].right = value;
            }
          }
          //puzzle[i][j].down
          {
            value = 0;
            //left
            value = puzzle[i][j].left;
            if(i + 1 < puzzle.length) {
              value = max(value, puzzle[i + 1][j].left);
            }
            //right
            if(value == 0) {
              value = max(puzzle[i][j].right, puzzle[i][j + 1].down);
              if(i + 1 < puzzle.length) {
                value = max(value, puzzle[i + 1][j].right);
              }
            }

            if(puzzle[i][j].down == 0) {
              puzzle[i][j].down = value;
            }
          }
        }
        else {
          //i == 0 && j == 0
          //puzzle[i][j].up
          if(puzzle[i][j].left == -1 || (puzzle[i][j].right == -1 && puzzle[i][j + 1].up == -1)) {
            puzzle[i][j].up = -1;
          }
          //puzzle[i][j].left
          if(puzzle[i][j].up == -1 || (puzzle[i][j].down == -1 && puzzle[i + 1][j].left == -1)) {
            puzzle[i][j].left = -1;
          }
          //puzzle[i][j].down
          if((puzzle[i][j].left == -1 && puzzle[i + 1][j].left == -1)
              || (puzzle[i][j].right == -1 && puzzle[i][j + 1].down == -1 && puzzle[i + 1][j].right == -1)) {
            puzzle[i][j].down = -1;
          }
          //puzzle[i][j].right
          if((puzzle[i][j].up == -1 && puzzle[i][j + 1].up == -1)
            || (puzzle[i][j].down == -1 && puzzle[i][j + 1].down == -1 && puzzle[i + 1][j].right == -1)) {
            puzzle[i][j].right = -1;
          }
        }
      }
    }

    notifyListeners();
  }

  ///**********************************************************************************
  ///**********************************************************************************
  ///************************** change interacted line color **************************
  ///**********************************************************************************
  ///**********************************************************************************
  ///row, column은 puzzle 기준
  ///lineValue가 1이상 이면 disable = true, 0이하 이면 enable = true
  Future<void> findBlockEnableDisable(
      int row, int column, String pos,
      {bool enable = false, bool disable = false, List<List<int>>? changedList}
    ) async {
    //print("clicked box : $row, $column, $pos");
    //puzzle 기준
    int rowMin = max(0, min(puzzle.length - 1, row - 1));
    int rowMax = min(puzzle.length - 1, row + 1);
    int colMin = max(0, min(puzzle[row].length - 1, column - 1));
    int colMax = min(puzzle[row].length - 1, column + 1);
    colMax = min(colMax + 1, puzzle[row].length - 1);
    //print("call findBlockEnableDisable($row $column $pos $enable $disable $changedList)");
    //print("row : $rowMin - $rowMax, col : $colMin - $colMax, changedList : $changedList");

    bool isChanged = false; //변경 사항이 있는가
    changedList ??= [];

    for(int i = rowMin ; i <= rowMax ; i++) {
      for(int j = colMin ; j <= colMax ; j++) {
        isChanged = false;

        if(disable && (puzzle[i][j].num <= getLineCount(i, j))) {
          isChanged = setLineDisable(i, j);
          if(isChanged) {
            changedList.add([i, j]);
          }
        }
        else if(enable) {
          isChanged = setLineEnable(i, j);
          //setLineEnable()를 통해 모든 -1값들을 0으로 변경 시킨 후, -1로 설정이 필요한 라인을 다시 계산
          await checkCurrentPath();
          if(isChanged) {
            changedList.add([i, j]);
          }
        }
        notifyListeners();
        submit = await readSquare.readSubmit(puzzle);
      }
    }

    notifyListeners();
    submit = await readSquare.readSubmit(puzzle);
    //print("changedList $changedList");
  }

  ///현재 submit 기준 사용할 수 없는 라인을 -1로 변경
  Future<void> checkCurrentPath() async {
    await checkMaxLine();
    await checkCurrentPathInner();
    await checkCurrentPathInner();
  }

  Future<void> checkMaxLine() async {
    int count = 0;

    for (int i = 0; i < puzzle.length; i++) {
      for (int j = 0; j < puzzle[i].length; j++) {
        count = 0;

        if(i > 0 && j > 0) {
          count = [puzzle[i - 1][j].down, puzzle[i][j].down, puzzle[i][j - 1].right, puzzle[i][j].right]
              .where((value) => value >= 1)
              .length;

          if(count >= puzzle[i][j].num) {
            if(puzzle[i - 1][j].down == 0) puzzle[i - 1][j].down = -1;
            if(puzzle[i][j].down == 0) puzzle[i][j].down = -1;
            if(puzzle[i][j - 1].right == 0) puzzle[i][j - 1].right = -1;
            if(puzzle[i][j].right == 0) puzzle[i][j].right = -1;
          }
        }
        else if(i == 0 && j != 0) {
          count = [puzzle[i][j].up, puzzle[i][j].down, puzzle[i][j - 1].right, puzzle[i][j].right]
              .where((value) => value >= 1)
              .length;

          if(count >= puzzle[i][j].num) {
            if(puzzle[i][j].up == 0) puzzle[i][j].up = -1;
            if(puzzle[i][j].down == 0) puzzle[i][j].down = -1;
            if(puzzle[i][j - 1].right == 0) puzzle[i][j - 1].right = -1;
            if(puzzle[i][j].right == 0) puzzle[i][j].right = -1;
          }
        }
        else if(i != 0 && j == 0) {
          count = [puzzle[i - 1][j].down, puzzle[i][j].down, puzzle[i][j].left, puzzle[i][j].right]
              .where((value) => value >= 1)
              .length;

          if(count >= puzzle[i][j].num) {
            if(puzzle[i - 1][j].down == 0) puzzle[i - 1][j].down = -1;
            if(puzzle[i][j].down == 0) puzzle[i][j].down = -1;
            if(puzzle[i][j].left == 0) puzzle[i][j].left = -1;
            if(puzzle[i][j].right == 0) puzzle[i][j].right = -1;
          }
        }
        else {
          //i == 0 && j == 0
          count = [puzzle[i][j].up, puzzle[i][j].down, puzzle[i][j].left, puzzle[i][j].right]
              .where((value) => value >= 1)
              .length;

          if(count >= puzzle[i][j].num) {
            if(puzzle[i][j].up == 0) puzzle[i][j].up = -1;
            if(puzzle[i][j].down == 0) puzzle[i][j].down = -1;
            if(puzzle[i][j].left == 0) puzzle[i][j].left = -1;
            if(puzzle[i][j].right == 0) puzzle[i][j].right = -1;
          }
        }
      }
    }

    notifyListeners();
    submit = await readSquare.readSubmit(puzzle);
  }

  ///-1이 되는 조건을 만족하면 -1로, 아니면 0으로 세팅
  Future<void> checkCurrentPathInner() async {
    int value = 0;
    //print("${puzzle.length} ${puzzle[0].length} ${puzzle[1].length}");  //3, 4, 4
    List<int> inValid = [-1, -4];

    for (int i = 0; i < puzzle.length; i++) {
      for (int j = 0; j < puzzle[i].length; j++) {
        if(i > 0 && j > 0) {
          //puzzle[i][j].down
          {
            value = 0;
            //handling heading to minus edge
            //left
            value = max(puzzle[i][j - 1].down, puzzle[i][j - 1].right);
            if(i + 1 < puzzle.length) {
              value = max(value, puzzle[i + 1][j - 1].right);
            }
            //check right
            if(value >= 0) {
              value = puzzle[i][j].right;
              if(i + 1 < puzzle.length) {
                value = max(value, puzzle[i + 1][j].right);
              }
              if(j + 1 < puzzle[i].length) {
                value = max(value, puzzle[i][j + 1].down);
              }
            }

            if(value < 0 && puzzle[i][j].down == 0) {
              puzzle[i][j].down = -1;
              continue;
            }
            else if(value >= 0 && puzzle[i][j].down == -1) {
              puzzle[i][j].down = 0;
            }
            value = 0;
            //handling heading to positive edge
            //left
            if(i + 1 < puzzle.length) {
              if([puzzle[i][j - 1].down, puzzle[i][j - 1].right, puzzle[i + 1][j - 1].right]
                  .where((value) => value > 0).length >= 2) {
                if(puzzle[i][j].down == 0){
                  puzzle[i][j].down = -1;
                  value++;
                }
              }
            }
            else if(puzzle[i][j - 1].down > 0 && puzzle[i][j - 1].right > 0) {
              if(puzzle[i][j].down == 0){
                puzzle[i][j].down = -1;
                value++;
              }
            }
            //right
            if(value == 0) {
              if((i + 1 < puzzle.length) && (j + 1 < puzzle[i].length)) {
                if([puzzle[i][j].right, puzzle[i + 1][j].right, puzzle[i][j + 1].down]
                    .where((value) => value > 0).length >= 2) {
                  if(puzzle[i][j].down == 0){
                    puzzle[i][j].down = -1;
                  }
                }
              }
              else if((i + 1 < puzzle.length) && !(j + 1 < puzzle[i].length)) {
                if(puzzle[i][j].right > 0 && puzzle[i + 1][j].right > 0) {
                  if(puzzle[i][j].down == 0){
                    puzzle[i][j].down = -1;
                  }
                }
              }
              else if(!(i + 1 < puzzle.length) && (j + 1 < puzzle[i].length)) {
                if(puzzle[i][j].right > 0 && puzzle[i][j + 1].down > 0) {
                  if(puzzle[i][j].down == 0){
                    puzzle[i][j].down = -1;
                  }
                }
              }
            }
          }
          //puzzle[i][j].right
          {
            value = 0;
            //handling heading to minus edge
            //check up
            value = max(puzzle[i - 1][j].down, puzzle[i - 1][j].right);
            if(j + 1 < puzzle[i].length) {
              value = max(value, puzzle[i - 1][j + 1].down);
            }
            //check down
            if(value >= 0) {
              value = puzzle[i][j].down;
              if(i + 1 < puzzle.length) {
                value = max(value, puzzle[i + 1][j].right);
              }
              if(j + 1 < puzzle[i].length) {
                value = max(value, puzzle[i][j + 1].down);
              }
            }

            if(value < 0 && puzzle[i][j].right == 0) {
              puzzle[i][j].right = -1;
              continue;
            }
            else if(value >= 0 && puzzle[i][j].right == -1) {
              puzzle[i][j].right = 0;
            }
            value = 0;
            //handling heading to minus edge
            //up
            if(j + 1 < puzzle[i].length) {
              if([puzzle[i - 1][j].down, puzzle[i - 1][j].right, puzzle[i - 1][j + 1].down]
                  .where((value) => value > 0).length >= 2) {
                if(puzzle[i][j].right == 0){
                  puzzle[i][j].right = -1;
                  value++;
                }
              }
            }
            else if(puzzle[i - 1][j].down > 0 && puzzle[i - 1][j].right > 0) {
              if(puzzle[i][j].right == 0){
                puzzle[i][j].right = -1;
                value++;
              }
            }
            //down
            if(value == 0) {
              if((i + 1 < puzzle.length) && (j + 1 < puzzle[i].length)) {
                if([puzzle[i][j].down, puzzle[i + 1][j].right, puzzle[i][j + 1].down]
                    .where((value) => value > 0).length >= 2) {
                  if(puzzle[i][j].right == 0){
                    puzzle[i][j].right = -1;
                  }
                }
              }
              else if((i + 1 < puzzle.length) && !(j + 1 < puzzle[i].length)) {
                if(puzzle[i][j].down > 0 && puzzle[i + 1][j].right > 0) {
                  if(puzzle[i][j].right == 0){
                    puzzle[i][j].right = -1;
                  }
                }
              }
              else if(!(i + 1 < puzzle.length) && (j + 1 < puzzle[i].length)) {
                if(puzzle[i][j].down > 0 && puzzle[i][j + 1].down > 0) {
                  if(puzzle[i][j].right == 0){
                    puzzle[i][j].right = -1;
                  }
                }
              }
            }
          }
        }
        else if(i == 0 && j != 0) {
          //print("i $i, j $j");
          //puzzle[i][j].up
          {
            value = 0;
            //handling heading to minus edge
            //left
            value = max(puzzle[i][j - 1].up, puzzle[i][j - 1].right);
            //right
            if(value >= 0) {
              if(j + 1 < puzzle[i].length) {
                value = max(puzzle[i][j].right, puzzle[i][j + 1].up);
              }
              else {
                value = puzzle[i][j].right;
              }
            }
            if(value < 0 && puzzle[i][j].up == 0) {
              puzzle[i][j].up = -1;
              continue;
            }
            else if(value >= 0 && puzzle[i][j].up == -1) {
              puzzle[i][j].up = 0;
            }
            //handling heading to positive edge
            //left
            if(puzzle[i][j - 1].up > 0 && puzzle[i][j - 1].right > 0) {
              if(puzzle[i][j].up == 0){
                puzzle[i][j].up = -1;
              }
            }
            //right
            else if(j + 1 < puzzle[i].length){
               if(puzzle[i][j].right > 0 && puzzle[i][j + 1].up > 0) {
                 if(puzzle[i][j].up == 0){
                  puzzle[i][j].up = -1;
                }
              }
            }
          }
          //puzzle[i][j].down
          {
            value = 0;
            //handling heading to minus edge
            //left
            value = max(puzzle[i][j - 1].right, max(puzzle[i][j - 1].down, puzzle[i + 1][j - 1].right));
            if(value >= 0){
              //right
              if(j + 1 < puzzle[i].length) {
                value = max(puzzle[i][j + 1].down, max(puzzle[i][j].right, puzzle[i + 1][j].right));
              }
              else {
                value = max(puzzle[i][j].right, puzzle[i + 1][j].right);
              }
            }
            if(value < 0 && puzzle[i][j].down == 0) {
              puzzle[i][j].down = -1;
              continue;
            }
            else if(value >= 0 && puzzle[i][j].down == -1) {
              puzzle[i][j].down = 0;
            }
            //handling heading to positive edge
            //left
            if([puzzle[i][j -1].right, puzzle[i][j - 1].down, puzzle[i + 1][j - 1].right]
                .where((value) => value > 0).length >= 2) {
              if(puzzle[i][j].down == 0){
                puzzle[i][j].down = -1;
              }
            }
            //right
            else {
              if(j + 1 < puzzle[i].length) {
                if([puzzle[i][j].right, puzzle[i + 1][j].right, puzzle[i][j + 1].down]
                    .where((value) => value > 0).length >= 2) {
                  if(puzzle[i][j].down == 0){
                    puzzle[i][j].down = -1;
                  }
                }
              }
              else {
                if(puzzle[i][j].right > 0 && puzzle[i + 1][j].right > 0) {
                  if(puzzle[i][j].down == 0){
                    puzzle[i][j].down = -1;
                  }
                }
              }
            }
          }
          //puzzle[i][j].right
          {
            value = 0;
            //handling heading to minus edge
            //up
            if(j + 1 < puzzle[i].length) {
              value = max(puzzle[i][j].up, puzzle[i][j + 1].up);
            }
            else {
              value = puzzle[i][j].up;
            }
            //down
            if(value >= 0) {
              value = max(puzzle[i][j].down, puzzle[i + 1][j].right);
              if(j + 1 < puzzle[i].length) {
                value = max(value, puzzle[i][j + 1].down);
              }
            }
            if(value < 0 && puzzle[i][j].right == 0) {
              puzzle[i][j].right = -1;
              continue;
            }
            else if(value >= 0 && puzzle[i][j].right == -1) {
              puzzle[i][j].right = 0;
            }
            //handling heading to positive edge
            //up
            if(j + 1 < puzzle[i].length) {
              if(puzzle[i][j].up > 0 && puzzle[i][j + 1].up > 0) {
                if(puzzle[i][j].right == 0){
                  puzzle[i][j].right = -1;
                }
              }
            }
            //down
            if(puzzle[i][j].right == 0) {
              if(j + 1 < puzzle[i].length) {
                if([puzzle[i][j].down, puzzle[i + 1][j].right, puzzle[i][j + 1].down]
                    .where((value) => value > 0).length >= 2) {
                  if(puzzle[i][j].right == 0){
                    puzzle[i][j].right = -1;
                  }
                }
              }
              else {
                if(puzzle[i][j].down > 0 && puzzle[i + 1][j].right > 0) {
                  if(puzzle[i][j].right == 0){
                    puzzle[i][j].right = -1;
                  }
                }
              }
            }
          }
        }
        else if(i != 0 && j == 0) {
          //puzzle[i][j].left
          {
            value = 0;
            //handling heading to minus edge
            //up
            value = max(puzzle[i - 1][j].left, puzzle[i - 1][j].down);
            //down
            if(value >= 0) {
              if(i + 1 < puzzle.length) {
                value = max(puzzle[i][j].down, puzzle[i + 1][j].left);
              }
              else {
                value = puzzle[i][j].down;
              }
            }

            if(value < 0 && puzzle[i][j].left == 0) {
              puzzle[i][j].left = -1;
              continue;
            }
            else if(value >= 0 && puzzle[i][j].left == -1) {
              puzzle[i][j].right = 0;
            }
            //handling heading to positive edge
            //up
            if(puzzle[i - 1][j].left > 0 && puzzle[i - 1][j].down > 0) {
              if(puzzle[i][j].left == 0){
                puzzle[i][j].left = -1;
              }
            }
            //down
            else if(i + 1 < puzzle.length) {
              if(puzzle[i][j].down > 0 && puzzle[i + 1][j].left > 0) {
                if(puzzle[i][j].left == 0){
                  puzzle[i][j].left = -1;
                }
              }
            }
          }
          //puzzle[i][j].right
          {
            value = 0;
            //handling heading to minus edge
            //up
            value = max(max(puzzle[i - 1][j].down, puzzle[i - 1][j].right), puzzle[i - 1][j + 1].down);
            //down
            if(value >= 0) {
              if(i + 1 < puzzle.length) {
                value = max(puzzle[i + 1][j].right, max(puzzle[i][j].down, puzzle[i][j + 1].down));
              }
              else {
                value = max(puzzle[i][j].down, puzzle[i][j + 1].down);
              }
            }

            if(value < 0 && puzzle[i][j].right == 0) {
              puzzle[i][j].right = -1;
              continue;
            }
            else if(value >= 0 && puzzle[i][j].right == -1) {
              puzzle[i][j].right = 0;
            }
            //handling heading to positive edge
            //up
            if([puzzle[i - 1][j].down, puzzle[i - 1][j].right, puzzle[i - 1][j + 1].down]
                .where((value) => value > 0).length >= 2) {
              if(puzzle[i][j].right == 0){
                puzzle[i][j].right = -1;
              }
            }
            //down
            else {
              if(i + 1 < puzzle.length) {
                if([puzzle[i][j].down, puzzle[i][j + 1].down, puzzle[i + 1][j].right]
                    .where((value) => value > 0).length >= 2) {
                  if(puzzle[i][j].right == 0){
                    puzzle[i][j].right = -1;
                  }
                }
              }
              else {
                if(puzzle[i][j].down > 0 && puzzle[i][j + 1].down > 0) {
                  if(puzzle[i][j].right == 0){
                    puzzle[i][j].right = -1;
                  }
                }
              }
            }
          }
          //puzzle[i][j].down
          {
            value = 0;
            //handling heading to minus edge
            //left
            value = puzzle[i][j].left;
            if(i + 1 < puzzle.length) {
              value = max(value, puzzle[i + 1][j].left);
            }
            //right
            if(value >= 0) {
              value = max(puzzle[i][j].right, puzzle[i][j + 1].down);
              if(i + 1 < puzzle.length) {
                value = max(value, puzzle[i + 1][j].right);
              }
            }

            if(value < 0 && puzzle[i][j].down == 0) {
              puzzle[i][j].down = -1;
              continue;
            }
            else if(value >= 0 && puzzle[i][j].down == -1) {
              puzzle[i][j].down = 0;
            }
            //handling heading to positive edge
            //left
            if(i + 1 < puzzle.length) {
              if(puzzle[i][j].left > 0 && puzzle[i + 1][j].left > 0) {
                if(puzzle[i][j].down == 0){
                  puzzle[i][j].down = -1;
                }
              }
            }
            //right
            else {
              if(i + 1 < puzzle.length) {
                if([puzzle[i][j].right, puzzle[i][j + 1].down, puzzle[i + 1][j].right]
                    .where((value) => value > 0).length >= 2) {
                  if(puzzle[i][j].down == 0){
                    puzzle[i][j].down = -1;
                  }
                }
              }
              else if(puzzle[i][j].right > 0 && puzzle[i][j + 1].down > 0) {
                if(puzzle[i][j].down == 0){
                  puzzle[i][j].down = -1;
                }
              }
            }
          }
        }
        else {
          //i == 0 && j == 0
          //puzzle[i][j].up
          {
            value = 0;
            //handling heading to minus edge
            if (inValid.contains(puzzle[i][j].left) ||
                (inValid.contains(puzzle[i][j].right) &&
                    inValid.contains(puzzle[i][j + 1].up))) {
              value = -1;
            }
            //handling heading to positive edge
            else if (puzzle[i][j].right > 0 && puzzle[i][j + 1].up > 0) {
              if (puzzle[i][j].up == 0) {
                value = -1;
              }
            }
            if(value != 0 && puzzle[i][j].up == 0) {
              puzzle[i][j].up = value;
            }
            else if(value == 0 && puzzle[i][j].up == -1) {
              puzzle[i][j].up = 0;
            }
          }
          //puzzle[i][j].left
          {
            value = 0;
            //handling heading to minus edge
            if (inValid.contains(puzzle[i][j].up) ||
                (inValid.contains(puzzle[i][j].down) &&
                    inValid.contains(puzzle[i + 1][j].left))) {
              value = -1;
            }
            //handling heading to positive edge
            else if (puzzle[i][j].down > 0 && puzzle[i + 1][j].left > 0) {
              if (puzzle[i][j].left == 0) {
                value = -1;
              }
            }
            if(value != 0 && puzzle[i][j].left == 0) {
              puzzle[i][j].left = value;
            }
            else if(value == 0 && puzzle[i][j].left == -1) {
              puzzle[i][j].left = 0;
            }
          }
          //puzzle[i][j].down
          {
            value = 0;
            //handling heading to minus edge
            if ((inValid.contains(puzzle[i][j].left) &&
                    inValid.contains(puzzle[i + 1][j].left)) ||
                (inValid.contains(puzzle[i][j].right) &&
                    inValid.contains(puzzle[i][j + 1].down) &&
                    inValid.contains(puzzle[i + 1][j].right))) {
              value = -1;
            }
            //handling heading to positive edge
            //left
            else if (puzzle[i][j].left > 0 && puzzle[i + 1][j].left > 0) {
              if (puzzle[i][j].down == 0) {
                value = -1;
              }
            }
            //handling heading to positive edge
            //right
            else if ([
                  puzzle[i][j].right,
                  puzzle[i + 1][j].right,
                  puzzle[i][j + 1].down
                ].where((value) => value > 0).length >=
                2) {
              if (puzzle[i][j].down == 0) {
                value = -1;
              }
            }
            if(value != 0 && puzzle[i][j].down == 0) {
              puzzle[i][j].down = value;
            }
            else if(value == 0 && puzzle[i][j].down == -1) {
              puzzle[i][j].down = 0;
            }
          }
          //puzzle[i][j].right
          {
            value = 0;
            //handling heading to minus edge
            if ((inValid.contains(puzzle[i][j].up) &&
                    inValid.contains(puzzle[i][j + 1].up)) ||
                (inValid.contains(puzzle[i][j].down) &&
                    inValid.contains(puzzle[i][j + 1].down) &&
                    inValid.contains(puzzle[i + 1][j].right))) {
              value = -1;
            }
            //handling heading to positive edge
            //up
            else if (puzzle[i][j].up > 0 && puzzle[i][j + 1].up > 0) {
              if (puzzle[i][j].right == 0) {
                value = -1;
              }
            }
            //handling heading to positive edge
            //down
            else if ([
                  puzzle[i][j].down,
                  puzzle[i + 1][j].right,
                  puzzle[i][j + 1].down
                ].where((value) => value > 0).length >=
                2) {
              if (puzzle[i][j].right == 0) {
                value = -1;
              }
            }
            if(value != 0 && puzzle[i][j].right == 0) {
              puzzle[i][j].right = value;
            }
            else if(value == 0 && puzzle[i][j].right == -1) {
              puzzle[i][j].right = 0;
            }
          }
        }
      }
    }

    notifyListeners();
    submit = await readSquare.readSubmit(puzzle);
  }

  int getLineCount(int row, int col) {
    int count = 0;

    if(row != 0 && col != 0) {
      count = [
        puzzle[row - 1][col].down,
        puzzle[row][col].down,
        puzzle[row][col - 1].right,
        puzzle[row][col].right
      ].where((value) => value > 0).length;
    }
    else if(row != 0 && col == 0) {
      count = [
        puzzle[row - 1][col].down,
        puzzle[row][col].down,
        puzzle[row][col].left,
        puzzle[row][col].right
      ].where((value) => value > 0).length;
    }
    else if(row == 0 && col != 0) {
      count = [
        puzzle[row][col].up,
        puzzle[row][col].down,
        puzzle[row][col - 1].right,
        puzzle[row][col].right
      ].where((value) => value > 0).length;
    }
    else {
      count = [
        puzzle[row][col].up,
        puzzle[row][col].down,
        puzzle[row][col].left,
        puzzle[row][col].right
      ].where((value) => value > 0).length;
    }

    return count;
  }

  ///현재 라인이 num 이상인 경우 호출되는 함수
  ///
  ///0으로 남아 있는 라인을 모두 -1로 변경
  bool setLineDisable(int row, int col) {
    bool isChanged = false;

    if(row != 0 && col != 0) {
      if (puzzle[row - 1][col].down == 0) {
        puzzle[row - 1][col].down = -1;
        isChanged = true;
      }
      if (puzzle[row][col].down == 0) {
        puzzle[row][col].down = -1;
        isChanged = true;
      }
      if (puzzle[row][col - 1].right == 0) {
        puzzle[row][col - 1].right = -1;
        isChanged = true;
      }
      if (puzzle[row][col].right == 0) {
        puzzle[row][col].right = -1;
        isChanged = true;
      }
    }
    else if(row != 0 && col == 0) {
      if (puzzle[row - 1][col].down == 0) {
        puzzle[row - 1][col].down = -1;
        isChanged = true;
      }
      if (puzzle[row][col].down == 0) {
        puzzle[row][col].down = -1;
        isChanged = true;
      }
      if (puzzle[row][col].left == 0) {
        puzzle[row][col].left = -1;
        isChanged = true;
      }
      if (puzzle[row][col].right == 0) {
        puzzle[row][col].right = -1;
        isChanged = true;
      }
    }
    else if(row == 0 && col != 0) {
      if (puzzle[row][col].up == 0) {
        puzzle[row][col].up = -1;
        isChanged = true;
      }
      if (puzzle[row][col].down == 0) {
        puzzle[row][col].down = -1;
        isChanged = true;
      }
      if (puzzle[row][col - 1].right == 0) {
        puzzle[row][col - 1].right = -1;
        isChanged = true;
      }
      if (puzzle[row][col].right == 0) {
        puzzle[row][col].right = -1;
        isChanged = true;
      }
    }
    else {
      if (puzzle[row][col].up == 0) {
        puzzle[row][col].up = -1;
        isChanged = true;
      }
      if (puzzle[row][col].down == 0) {
        puzzle[row][col].down = -1;
        isChanged = true;
      }
      if (puzzle[row][col].left == 0) {
        puzzle[row][col].left = -1;
        isChanged = true;
      }
      if (puzzle[row][col].right == 0) {
        puzzle[row][col].right = -1;
        isChanged = true;
      }
    }

    return isChanged;
  }

  ///enable이 true로 호출되는 경우 호출되는 함수
  ///
  ///findBlockEnableDisable의 checkCurrentPath()에서 다시 계산을 할 수 있도록 모든 -1 값을 0으로 변경
  bool setLineEnable(int row, int col) {
    bool isChanged = false;

    if(row != 0 && col != 0) {
      if (puzzle[row - 1][col].down == -1) {
        puzzle[row - 1][col].down = 0;
        isChanged = true;
      }
      if (puzzle[row][col].down == -1) {
        puzzle[row][col].down = 0;
        isChanged = true;
      }
      if (puzzle[row][col - 1].right == -1) {
        puzzle[row][col - 1].right = 0;
        isChanged = true;
      }
      if (puzzle[row][col].right == -1) {
        puzzle[row][col].right = 0;
        isChanged = true;
      }
    }
    else if(row != 0 && col == 0) {
      if (puzzle[row - 1][col].down == -1) {
        puzzle[row - 1][col].down = 0;
        isChanged = true;
      }
      if (puzzle[row][col].down == -1) {
        puzzle[row][col].down = 0;
        isChanged = true;
      }
      if (puzzle[row][col].left == -1) {
        puzzle[row][col].left = 0;
        isChanged = true;
      }
      if (puzzle[row][col].right == -1) {
        puzzle[row][col].right = 0;
        isChanged = true;
      }
    }
    else if(row == 0 && col != 0) {
      if (puzzle[row][col].up == -1) {
        puzzle[row][col].up = 0;
        isChanged = true;
      }
      if (puzzle[row][col].down == -1) {
        puzzle[row][col].down = 0;
        isChanged = true;
      }
      if (puzzle[row][col - 1].right == -1) {
        puzzle[row][col - 1].right = 0;
        isChanged = true;
      }
      if (puzzle[row][col].right == -1) {
        puzzle[row][col].right = 0;
        isChanged = true;
      }
    }
    else {
      if (puzzle[row][col].up == -1) {
        puzzle[row][col].up = 0;
        isChanged = true;
      }
      if (puzzle[row][col].down == -1) {
        puzzle[row][col].down = 0;
        isChanged = true;
      }
      if (puzzle[row][col].left == -1) {
        puzzle[row][col].left = 0;
        isChanged = true;
      }
      if (puzzle[row][col].right == -1) {
        puzzle[row][col].right = 0;
        isChanged = true;
      }
    }

    return isChanged;
  }
}