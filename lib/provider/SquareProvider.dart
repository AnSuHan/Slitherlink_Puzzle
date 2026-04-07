// ignore_for_file: file_names
import 'dart:math';

import 'package:flutter/material.dart';

import '../MakePuzzle/ReadSquare.dart';
import '../Platform/ExtractData.dart'
  if (dart.library.html) '../Platform/ExtractDataWeb.dart'; // 조건부 import
import '../Scene/GameSceneSquare.dart';
import '../ThemeColor.dart';
import '../User/UserInfo.dart';
import '../l10n/app_localizations.dart';
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
      // ignore: avoid_print
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
      // ignore: avoid_print
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
    //submit is already populated by readSquare.readSubmit(puzzle) in refreshSubmit()
    //compare: answer 1 == submit > 0 (selected), answer 0 == submit <= 0 (not selected)
    for(int i = 0 ; i < answer.length ; i++) {
      for(int j = 0 ; j < answer[i].length ; j++) {
        bool answerSelected = answer[i][j] == 1;
        bool submitSelected = submit[i][j] > 0;
        if(answerSelected != submitSelected) {
          return;
        }
      }
    }

    //complete puzzle
    showComplete(context);
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
    UserInfo.incrementCompleted(loadKey);

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

    // Show completion dialog with theme
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final palette = ThemeColor().getPalette();
      final isDark = ThemeColor().isDark();
      final l10n = AppLocalizations.of(context);

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return Dialog(
            backgroundColor: isDark ? const Color(0xFF1E1E3A) : Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.celebration_rounded, color: palette['primary'], size: 48),
                  const SizedBox(height: 16),
                  Text(
                    l10n?.translate('game_complete_title') ?? 'Puzzle Complete!',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: palette['onSurface'],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    l10n?.translate('game_complete_message') ?? 'Congratulations!\nYou solved the puzzle.',
                    style: TextStyle(
                      fontSize: 16,
                      color: palette['onSurfaceDim'],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: palette['buttonBg'],
                        foregroundColor: palette['buttonText'],
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        elevation: 0,
                      ),
                      onPressed: () {
                        Navigator.of(context).pop();
                        shutdown = true;
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          Navigator.of(context).popUntil((route) => route.isFirst);
                        });
                      },
                      child: Text(
                        l10n?.translate('game_complete_ok') ?? 'OK',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
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
    if(UserInfo.debugMode["print_isUpdating"]! || UserInfo.debugMode["print_methodName"]!) {
      // ignore: avoid_print
      print("call setDo : $_isUpdating");
    }
    while(_isUpdating != 1) {
      await Future.delayed(const Duration(milliseconds: 50));
    }
    _isUpdating = 2;
    if(UserInfo.debugMode["print_isUpdating"]!) {
      // ignore: avoid_print
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
      // ignore: avoid_print
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
    // ignore: avoid_print
    print("");
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

  ///TODO : 계산량이 너무 많아 정상적으로 사용하는 것이 불가하다
  ///**********************************************************************************
  ///**********************************************************************************
  ///****************************** about color ******************************
  ///**********************************************************************************
  ///**********************************************************************************
  ///update `puzzle` variable
  Future<void> updateSquareBox(int row, int column, {int? up, int? down, int? left, int? right, Future<void> Function(int, int, String)? callback}) async {
    if(UserInfo.debugMode["print_isUpdating"]! || UserInfo.debugMode["print_methodName"]!) {
      // ignore: avoid_print
      print("==============================");
      // ignore: avoid_print
      print("call updateSquareBox : $_isUpdating");
    }
    while(_isUpdating != 0) {
      await Future.delayed(const Duration(milliseconds: 50));
      // ignore: avoid_print
      print("_isUpdating $_isUpdating");
    }
    await removeHintLine();
    _isUpdating = 1;
    if(UserInfo.debugMode["print_isUpdating"]!) {
      // ignore: avoid_print
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
        ///TODO : 특정 라인에서 색 변경이 정상적이지 못 함

        // ignore: avoid_print
        print("★★★★★ oldList : $oldList");

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

    //HowToPlay에서 step을 벗어나는 경우 처리
    if(callback != null) {
      //check condition -> if it is wrong, rollback
      await callback(row, column, pos);
    }

    submit = await readSquare.readSubmit(puzzle);
    notifyListeners();
    await setDo();
    await findBlockEnableDisable(
        row, column, pos, enable: lineValue <= 0, disable: lineValue > 0);
    notifyListeners();
    while(_isUpdating != 3) {
      await Future.delayed(const        // ignore: avoid_print
        // ignore: avoid_print
 Duration(milliseconds: 50));
      // ignore: avoid_print
      print("_isUpdating $_isUpdating");
    }
    _isUpdating = 0;

    if(UserInfo.debugMode["print_isUpdating"]!) {
      // ignore: avoid_print
      print("update updateSquareBox : $_isUpdating");
    }

    //check puzzle completion after user input
    checkCompletePuzzle(context);
  }

  /// 라인(row, col, dir)의 값을 읽는 헬퍼
  int _getEdgeValue(int row, int col, String dir) {
    switch (dir) {
      case "up":    return puzzle[row][col].up;
      case "down":  return puzzle[row][col].down;
      case "left":  return puzzle[row][col].left;
      case "right": return puzzle[row][col].right;
      default: return 0;
    }
  }

  /// 라인(row, col, dir)의 값을 설정하는 헬퍼
  void _setEdgeValue(int row, int col, String dir, int value) {
    switch (dir) {
      case "up":    puzzle[row][col].up = value; break;
      case "down":  puzzle[row][col].down = value; break;
      case "left":  puzzle[row][col].left = value; break;
      case "right": puzzle[row][col].right = value; break;
    }
  }

  /// 라인(row, col, dir)의 양 끝 꼭짓점 좌표를 반환
  /// 꼭짓점 (vi, vj): 0 <= vi <= numRows, 0 <= vj <= numCols
  List<List<int>> _getEdgeVertices(int row, int col, String dir) {
    switch (dir) {
      case "up":    return [[row, col], [row, col + 1]];
      case "down":  return [[row + 1, col], [row + 1, col + 1]];
      case "left":  return [[row, col], [row + 1, col]];
      case "right": return [[row, col + 1], [row + 1, col + 1]];
      default: return [];
    }
  }

  /// 꼭짓점 (vi, vj)에서 만나는 모든 라인을 [row, col, dir] 형태로 반환
  List<List<dynamic>> _getEdgesAtVertex(int vi, int vj) {
    List<List<dynamic>> edges = [];
    int numRows = puzzle.length;
    int numCols = puzzle[0].length;

    // 왼쪽 수평 라인: (vi, vj-1) — (vi, vj)
    if (vj > 0) {
      if (vi == 0) {
        edges.add([0, vj - 1, "up"]);
      } else if (vi - 1 < numRows) {
        edges.add([vi - 1, vj - 1, "down"]);
      }
    }

    // 오른쪽 수평 라인: (vi, vj) — (vi, vj+1)
    if (vj < numCols) {
      if (vi == 0) {
        edges.add([0, vj, "up"]);
      } else if (vi - 1 < numRows) {
        edges.add([vi - 1, vj, "down"]);
      }
    }

    // 위쪽 수직 라인: (vi-1, vj) — (vi, vj)
    if (vi > 0) {
      if (vj == 0) {
        if (vi - 1 < numRows) edges.add([vi - 1, 0, "left"]);
      } else if (vj - 1 < numCols) {
        if (vi - 1 < numRows) edges.add([vi - 1, vj - 1, "right"]);
      }
    }

    // 아래쪽 수직 라인: (vi, vj) — (vi+1, vj)
    if (vi < numRows) {
      if (vj == 0) {
        edges.add([vi, 0, "left"]);
      } else if (vj - 1 < numCols) {
        edges.add([vi, vj - 1, "right"]);
      }
    }

    return edges;
  }

  /// 라인의 각 꼭짓점별로 인접 라인을 분리하여 반환 (자기 자신 제외)
  /// 반환: [vertex0의 인접 라인들, vertex1의 인접 라인들]
  List<List<List<dynamic>>> getAdjacentEdgesPerVertex(int row, int col, String dir) {
    List<List<int>> vertices = _getEdgeVertices(row, col, dir);
    String selfKey = "$row,$col,$dir";
    List<List<List<dynamic>>> result = [];

    for (var v in vertices) {
      List<List<dynamic>> edgesAtVertex = [];
      for (var edge in _getEdgesAtVertex(v[0], v[1])) {
        String key = "${edge[0]},${edge[1]},${edge[2]}";
        if (key != selfKey) {
          edgesAtVertex.add(edge);
        }
      }
      result.add(edgesAtVertex);
    }

    return result;
  }

  /// 라인 (row, col, dir)에 인접한 모든 라인을 반환 (자기 자신 제외)
  List<List<dynamic>> getAdjacentEdges(int row, int col, String dir) {
    List<List<int>> vertices = _getEdgeVertices(row, col, dir);
    Set<String> seen = {"$row,$col,$dir"};
    List<List<dynamic>> result = [];

    for (var v in vertices) {
      for (var edge in _getEdgesAtVertex(v[0], v[1])) {
        String key = "${edge[0]},${edge[1]},${edge[2]}";
        if (!seen.contains(key)) {
          seen.add(key);
          result.add(edge);
        }
      }
    }

    return result;
  }

  ///SquareBoxProvider List's index
  Set<int> getNearColor(int row, int col, String pos) {
    Set<int> use = {};

    for (var edge in getAdjacentEdges(row, col, pos)) {
      int value = _getEdgeValue(edge[0] as int, edge[1] as int, edge[2] as String);
      if (value > 0) {
        use.add(value);
      }
    }

    return use;
  }

  void addIfPositive(Set<int> use, int value) {
    if(value > 0) {
      use.add(value);
    }
  }

  ///클릭한 라인 기준으로 인접한 라인 중 색이 다른 것을 찾아, 연결된 모든 라인을 반환
  List<dynamic> getOldColorList(int row, int col, String pos, int now) {
    List<dynamic> rtValue = [];

    for (var edge in getAdjacentEdges(row, col, pos)) {
      int value = _getEdgeValue(edge[0] as int, edge[1] as int, edge[2] as String);
      if (value > 0 && value != now) {
        rtValue.add([edge[0], edge[1], edge[2]]);
      }
    }

    if (rtValue.isEmpty) {
      return [];
    }
    return getContinueOld(rtValue);
  }

  ///변경해야 하는 라인들을 시작점으로, 같은 색으로 연결된 모든 라인을 BFS로 찾아 반환
  List<dynamic> getContinueOld(List<dynamic> start) {
    List<List<dynamic>> rtTempList = [start[0]];

    int row = int.parse(start[0][0].toString());
    int col = int.parse(start[0][1].toString());
    String pos = start[0][2].toString();
    int find = _getEdgeValue(row, col, pos);

    int count = 0;
    while (count < rtTempList.length) {
      row = int.parse(rtTempList[count][0].toString());
      col = int.parse(rtTempList[count][1].toString());
      pos = rtTempList[count][2].toString();
      count++;

      for (var edge in getAdjacentEdges(row, col, pos)) {
        int value = _getEdgeValue(edge[0] as int, edge[1] as int, edge[2] as String);
        if (value == find) {
          addIfNotExist(rtTempList, [edge[0], edge[1], edge[2]]);
        }
      }
    }

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
          temp.add(SquareBox(isFirstRow: true, isFirstColumn: true, row: i, column: j, isHowToPlay: gameStateSquare == null,));
        } else if(i == 0) {
          temp.add(SquareBox(isFirstRow: true, row: i, column: j, isHowToPlay: gameStateSquare == null,));
        } else if(j == 0) {
          temp.add(SquareBox(isFirstColumn: true, row: i, column: j, isHowToPlay: gameStateSquare == null,));
        } else {
          temp.add(SquareBox(row: i, column: j, isHowToPlay: gameStateSquare == null,));
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
    await clearLineForStart();

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
  ///
  ///TODO : howToPlay에서는 문제 없지만, release에서는 계산량이 너무 많아 시간이 오래 걸린다 (계산은 정상적으로 진행됨)
  ///TODO : 계산량을 줄이는 방법을 howToPlay 브랜치 merge 이후 모색할 예정
  Future<void> findBlockEnableDisable(
      int row, int column, String pos,
      {bool enable = false, bool disable = false, bool isMax = false}
    ) async {
    if(UserInfo.debugMode["print_methodName"]!) {
      // ignore: avoid_print
      print("call findBlockEnableDisable($row $column $pos $enable $disable)");
    }

    // Re-enable disabled lines around the changed line, then propagate.
    // Use a queue to spread outward only to cells that actually change.
    Set<int> visited = {};
    List<int> queue = [];

    // Seed: cells adjacent to the changed line
    int rowMin = max(0, min(puzzle.length - 1, row - 1));
    int rowMax = min(puzzle.length - 1, row + 1);
    int colMin = max(0, min(puzzle[row].length - 1, column - 1));
    int colMax = min(puzzle[row].length - 1, column + 1);
    colMax = min(colMax + 1, puzzle[row].length - 1);

    for (int i = rowMin; i <= rowMax; i++) {
      for (int j = colMin; j <= colMax; j++) {
        int key = i * 1000 + j;
        if (!visited.contains(key)) {
          visited.add(key);
          queue.add(key);
        }
      }
    }

    // Propagate: re-enable and check neighbors
    while (queue.isNotEmpty) {
      int key = queue.removeAt(0);
      int i = key ~/ 1000;
      int j = key % 1000;

      bool changed = await setLineEnable(i, j);
      if (changed) {
        // If lines were re-enabled, check surrounding cells too
        for (int di = -1; di <= 1; di++) {
          for (int dj = -1; dj <= 1; dj++) {
            int ni = i + di, nj = j + dj;
            if (ni >= 0 && ni < puzzle.length && nj >= 0 && nj < puzzle[0].length) {
              int nkey = ni * 1000 + nj;
              if (!visited.contains(nkey)) {
                visited.add(nkey);
                queue.add(nkey);
              }
            }
          }
        }
      }
    }

    await checkCurrentPath();
    notifyListeners();
    submit = await readSquare.readSubmit(puzzle);
  }

  List<List<dynamic>> needCalcLine = [];
  List<List<int>> needCalcSet = [];
  List<List<dynamic>> needCalcLineTemp = [];
  int calcIndex = 0;

  ///findBlockEnableDisable의 계산량을 줄인 메소드
  Future<void> findBlockEnableDisableRefactor(
      int row, int column, String pos,
      {bool enable = false, bool disable = false}
    ) async {

    //[row, col, pos]에 인접한 라인을 검색
    if(needCalcLine.isEmpty) {
      needCalcLine = getMinusNearLine([[row, column, pos]]);
    }
    for(int i = 0 ; i < needCalcLine.length ; i++) {
      if(needCalcSet.isNotEmpty) {
        bool flag = true;
        //같은 것을 찾으면 false로 즉시 종료
        for(int j = 0 ; flag && j < needCalcSet.length ; j++) {
          if(needCalcSet[j][0] == needCalcLine[i][0] && needCalcSet[j][1] == needCalcLine[i][1]) {
            flag = false;
            break;
          }
        }

        if(flag) {
          needCalcSet.add([needCalcLine[i][0], needCalcLine[i][1]]);
        }
      }
      else {
        needCalcSet.add([needCalcLine[i][0], needCalcLine[i][1]]);
      }
    }
    print("needCalcSet : $needCalcSet");


    //종료 조건 검색
    while(calcIndex < needCalcSet.length) {
      print("call checkMaxLineBox");
      checkMaxLineBox(needCalcSet[calcIndex][0], needCalcSet[calcIndex][1]);

      //추가 조건 만족
      if(false) {
        needCalcLineTemp = getMinusNearLine([[row, column, pos]]);
        for(int i = 0 ; i < needCalcLineTemp.length ; i++) {
          for(int j = 0 ; j < needCalcLine.length ; j++) {
            if(needCalcLine[j][0] == needCalcLineTemp[i][0] &&
                needCalcLine[j][1] == needCalcLineTemp[i][1] &&
                needCalcLine[j][2].compareTo(needCalcLineTemp[i][2]) == 0) {

            }
          }
        }
      }

      calcIndex++;
    }

    await checkCurrentPath();
    notifyListeners();
    submit = await readSquare.readSubmit(puzzle);
  }

  ///현재 submit 기준 사용할 수 없는 라인을 -1로 변경
  Future<void> checkCurrentPath() async {
    if(UserInfo.debugMode["print_methodName"]!) {
      // ignore: avoid_print
      print("call checkCurrentPath");
    }
    await checkMaxLine();
    await checkCurrentPathSet();
    await propagateLookAhead();
  }

  ///셀(num) 규칙과 꼭짓점(차수=2) 규칙을 fixed-point 까지 시뮬레이션해서
  ///사용자가 그린 라인은 건드리지 않고, 비활성(-1) 표시만 더 적극적으로 반영한다.
  ///
  ///가상 강제선(2)은 시뮬레이션 내부 추론용으로만 사용되며 실제 puzzle 에는 기록하지 않는다.
  Future<void> propagateLookAhead() async {
    int rows = puzzle.length;
    int cols = puzzle[0].length;
    if (rows == 0 || cols == 0) return;

    List<List<int>> edge = await readSquare.readSubmit(puzzle);
    List<List<int>> orig = edge.map((r) => List<int>.from(r)).toList();

    // 작업용 그리드: 1 = 그어짐, 2 = 가상 강제선, 0 = 미정, -1 = 비활성
    List<List<int>> w = edge.map((row) => row.map((v) {
      if (v >= 1) return 1;
      if (v == 0) return 0;
      return -1;
    }).toList()).toList();

    bool changed = true;
    int iter = 0;
    while (changed && iter < 30) {
      changed = false;
      iter++;

      // 셀 규칙
      for (int i = 0; i < rows; i++) {
        for (int j = 0; j < cols; j++) {
          int num = puzzle[i][j].num;
          if (num < 0 || num > 4) continue;
          List<List<int>> es = [
            [2 * i, j], [2 * i + 2, j], [2 * i + 1, j], [2 * i + 1, j + 1],
          ];
          int dr = 0, un = 0, xc = 0;
          for (var e in es) {
            int v = w[e[0]][e[1]];
            if (v == 1 || v == 2) {
              dr++;
            } else if (v == 0) {
              un++;
            } else {
              xc++;
            }
          }
          if (un == 0) continue;
          if (dr == num) {
            for (var e in es) {
              if (w[e[0]][e[1]] == 0) { w[e[0]][e[1]] = -1; changed = true; }
            }
          } else if (4 - xc == num) {
            for (var e in es) {
              if (w[e[0]][e[1]] == 0) { w[e[0]][e[1]] = 2; changed = true; }
            }
          }
        }
      }

      // 꼭짓점 규칙 (차수는 0 또는 2)
      for (int vi = 0; vi <= rows; vi++) {
        for (int vj = 0; vj <= cols; vj++) {
          List<List<int>> ve = [];
          if (vj > 0) ve.add([2 * vi, vj - 1]);
          if (vj < cols) ve.add([2 * vi, vj]);
          if (vi > 0) ve.add([2 * vi - 1, vj]);
          if (vi < rows) ve.add([2 * vi + 1, vj]);
          int dr = 0, un = 0;
          for (var e in ve) {
            int v = w[e[0]][e[1]];
            if (v == 1 || v == 2) {
              dr++;
            } else if (v == 0) {
              un++;
            }
          }
          if (un == 0) continue;
          if (dr >= 2) {
            for (var e in ve) {
              if (w[e[0]][e[1]] == 0) { w[e[0]][e[1]] = -1; changed = true; }
            }
          } else if (dr == 1 && un == 1) {
            for (var e in ve) {
              if (w[e[0]][e[1]] == 0) { w[e[0]][e[1]] = 2; changed = true; }
            }
          } else if (dr == 0 && un == 1) {
            for (var e in ve) {
              if (w[e[0]][e[1]] == 0) { w[e[0]][e[1]] = -1; changed = true; }
            }
          }
        }
      }
    }

    // 새로 -1 이 된 칸만 실제 puzzle 에 반영 (가상 강제선 2 는 무시)
    bool anyChanged = false;
    for (int i = 0; i < edge.length; i++) {
      for (int j = 0; j < edge[i].length; j++) {
        if (orig[i][j] == 0 && w[i][j] == -1) {
          edge[i][j] = -1;
          anyChanged = true;
        }
      }
    }

    if (anyChanged) {
      await readSquare.writeSubmit(puzzle, edge);
      submit = await readSquare.readSubmit(puzzle);
      notifyListeners();
    }
  }

  ///각 박스마다 lineValue가 1이상인 값을 세고, 해당 박스의 num 이상인 경우 남은 0 라인을 -1로 변경
  Future<void> checkMaxLine() async {
    if(UserInfo.debugMode["print_methodName"]!) {
      // ignore: avoid_print
      print("call checkMaxLine");
    }
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

  ///각 박스마다 lineValue가 1이상인 값을 세고, 해당 박스의 num 이상인 경우 남은 0 라인을 -1로 변경
  Future<void> checkMaxLineBox(int row, int col) async {
    if(UserInfo.debugMode["print_methodName"]!) {
      // ignore: avoid_print
      print("call checkMaxLineBox");
    }
    int count = 0;

    int i = row, j = col;
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

    notifyListeners();
    submit = await readSquare.readSubmit(puzzle);
  }

  ///-1로 설정된 라인들 부터 너비 우선 탐색으로 모든 연관 라인과 조건을 비교
  ///
  ///조건이 참이면 -1로 설정 후 set에 추가
  Future<void> checkCurrentPathSet() async {
    List<List<dynamic>> minusSet = findMinusOneLine();

    do {
      List<List<dynamic>> nearSet = getMinusNearLine(minusSet);
      if (nearSet.isEmpty) break;

      List<List<dynamic>> validLines = checkLineValid(nearSet);

      // 새로 비활성화된 라인 = nearSet - validLines
      Set<String> validKeys = {};
      for (var line in validLines) {
        validKeys.add("${line[0]},${line[1]},${line[2]}");
      }

      minusSet = [];
      for (var line in nearSet) {
        String key = "${line[0]},${line[1]},${line[2]}";
        if (!validKeys.contains(key)) {
          minusSet.add(line);
        }
      }
    } while (minusSet.isNotEmpty);
  }

  ///lineValue가 -1인 모든 라인을 찾아 반환
  ///
  ///puzzle 변수를 직접 조작하지 않음
  List<List<dynamic>> findMinusOneLine() {
    List<List<dynamic>> rtValue = [];

    for(int i = 0 ; i < puzzle.length ; i++) {
      for(int j = 0 ; j < puzzle[i].length ; j++) {
        if(i != 0 && j != 0) {
          if(puzzle[i][j].down == -1) {
            rtValue.add([i, j, "down"]);
          }
          if(puzzle[i][j].right == -1) {
            rtValue.add([i, j, "right"]);
          }
        }
        else if(i != 0 && j == 0) {
          if(puzzle[i][j].left == -1) {
            rtValue.add([i, j, "left"]);
          }
          if(puzzle[i][j].right == -1) {
            rtValue.add([i, j, "right"]);
          }
          if(puzzle[i][j].down == -1) {
            rtValue.add([i, j, "down"]);
          }
        }
        else if(i == 0 && j != 0) {
          if(puzzle[i][j].up == -1) {
            rtValue.add([i, j, "up"]);
          }
          if(puzzle[i][j].down == -1) {
            rtValue.add([i, j, "down"]);
          }
          if(puzzle[i][j].right == -1) {
            rtValue.add([i, j, "right"]);
          }
        }
        else {
          if(puzzle[i][j].up == -1) {
            rtValue.add([i, j, "up"]);
          }
          if(puzzle[i][j].down == -1) {
            rtValue.add([i, j, "down"]);
          }
          if(puzzle[i][j].left == -1) {
            rtValue.add([i, j, "left"]);
          }
          if(puzzle[i][j].right == -1) {
            rtValue.add([i, j, "right"]);
          }
        }
      }
    }

    return rtValue;
  }

  ///minusList와 인접한 모든 라인을 반환
  ///
  ///puzzle 변수를 직접 조작하지 않음
  List<List<dynamic>> getMinusNearLine(List<List<dynamic>> minusList) {
    List<int> checkValue = [0];

    //isHowToPlay
    if(gameStateSquare == null) {
      checkValue.add(-3);
    }

    Set<String> seen = {};
    List<List<dynamic>> result = [];

    for(int i = 0 ; i < minusList.length ; i++) {
      int row = int.parse(minusList[i][0].toString());
      int col = int.parse(minusList[i][1].toString());
      String dir = minusList[i][2].toString();

      for (var edge in getAdjacentEdges(row, col, dir)) {
        int value = _getEdgeValue(edge[0] as int, edge[1] as int, edge[2] as String);
        if (checkValue.contains(value)) {
          String key = "${edge[0]},${edge[1]},${edge[2]}";
          if (!seen.contains(key)) {
            seen.add(key);
            result.add([edge[0], edge[1], edge[2]]);
          }
        }
      }
    }

    return result;
  }

  ///nearList가 valid 한지 검사하고 inValid면 -1로 설정
  ///
  ///valid 하다면 마지막에 모아서 다시 검사하여 모든 라인의 상태가 변경되지 않을 때까지 반복
  ///
  ///puzzle 변수를 직접 조작함
  ///
  ///비활성화 조건 (꼭짓점 기준):
  ///  negative: 한쪽 꼭짓점의 모든 인접 라인이 비활성(-1, -4)이면 dead end → 비활성화
  ///  positive: 한쪽 꼭짓점에 활성(>0) 라인이 2개 이상이면 분기점 → 비활성화
  List<List<dynamic>> checkLineValid(List<List<dynamic>> nearList) {
    List<List<dynamic>> validLine = [];
    List<int> inValid = [-1, -4];

    for (int i = 0; i < nearList.length; i++) {
      int row = int.parse(nearList[i][0].toString());
      int col = int.parse(nearList[i][1].toString());
      String pos = nearList[i][2].toString();
      bool isValid = true;

      List<List<List<dynamic>>> perVertex = getAdjacentEdgesPerVertex(row, col, pos);

      for (var vertexEdges in perVertex) {
        if (vertexEdges.isEmpty) continue;

        // negative condition: 이 꼭짓점의 모든 인접 라인이 비활성
        bool allDisabled = vertexEdges.every((edge) {
          int value = _getEdgeValue(edge[0] as int, edge[1] as int, edge[2] as String);
          return inValid.contains(value);
        });

        if (allDisabled) {
          _setEdgeValue(row, col, pos, -1);
          isValid = false;
          break;
        }

        // positive condition: 이 꼭짓점에 활성 라인이 2개 이상 → 분기점
        int positiveCount = vertexEdges.where((edge) {
          int value = _getEdgeValue(edge[0] as int, edge[1] as int, edge[2] as String);
          return value > 0;
        }).length;

        if (positiveCount >= 2) {
          _setEdgeValue(row, col, pos, -1);
          isValid = false;
          break;
        }
      }

      if (isValid) {
        validLine.add(nearList[i]);
      }
    }

    return validLine;
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
  ///
  ///setLineDisable() 호출 직후 checkMaxLine()를 호출함
  Future<bool> setLineDisable(int row, int col) async {
    if(UserInfo.debugMode["print_methodName"]!) {
      // ignore: avoid_print
      print("call setLineDisable($row, $col)");
    }
    await checkMaxLine();
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
  ///
  ///setLineEnable() 호출 직후 checkMaxLine()를 호출함
  Future<bool> setLineEnable(int row, int col) async {
    if(UserInfo.debugMode["print_methodName"]!) {
      // ignore: avoid_print
      print("call setLineEnable($row, $col)");
    }
    await checkMaxLine();
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