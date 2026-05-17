// ignore_for_file: file_names
import 'dart:math';

import 'package:flutter/material.dart';

import '../MakePuzzle/ReadSquare.dart';
import 'square_propagation_core.dart';
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
      final int hintRow = int.parse(item[0].toString());
      final int hintCol = int.parse(item[1].toString());
      final String hintDir = item[2].toString();

      setLineColorBox(
          hintRow,
          hintCol,
          hintDir,
          (item[3] as bool) ? -5 : -3   //item[3] is `isWrongSubmit`
      );
      _hintCanvasPos = _squareLineMidpoint(hintRow, hintCol, hintDir);
    }
  }

  /// Canvas position (inside InteractiveViewer's child, including the
  /// scene's outer Padding(20) and first-row/col line offsets) of the most
  /// recently placed hint, or null if no hint is currently active.
  Offset? _hintCanvasPos;
  Offset? getHintCanvasPos() => _hintCanvasPos;

  /// Approximate canvas-space midpoint of the line on side `dir` of cell
  /// (row, col). Mirrors the dimensions used by `_fitPuzzleToScreen` in
  /// GameSceneSquare: cells are 67.5×65 with a 30 px left margin and
  /// 37.5 px top margin from the InteractiveViewer-child origin.
  Offset _squareLineMidpoint(int row, int col, String dir) {
    const double cellW = 67.5;
    const double cellH = 65.0;
    const double scenePadding = 20.0;
    const double firstColExtra = 10.0;
    const double firstRowExtra = 17.5;
    final double bx = scenePadding + firstColExtra + col * cellW;
    final double by = scenePadding + firstRowExtra + row * cellH;
    final double cx = bx + 25; // box centre (box is 50×50)
    final double cy = by + 25;
    switch (dir) {
      case "up":    return Offset(cx, cy - 30);
      case "down":  return Offset(cx, cy + 30);
      case "left":  return Offset(cx - 30, cy);
      case "right": return Offset(cx + 30, cy);
    }
    return Offset(cx, cy);
  }

  Future<void> removeHintLine() async {
    if(UserInfo.debugMode["print_isUpdating"]!) {
      // ignore: avoid_print
      print("call removeHintLine : $_isUpdating");
    }
    _hintCanvasPos = null;
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

  /// Solver / batched-update flag. When true, intermediate paint notifications
  /// inside chain-merge / propagation are suppressed; only the final paint at
  /// the end of [updateSquareBox] (or an explicit flush by the caller) fires.
  /// This is what eliminates the "click → flash partial state → settle"
  /// flicker the auto-solver introduces by chaining many sub-updates rapidly.
  bool _silentMode = false;

  /// updateSquareBox 가 진입 시점에 저장하는 탭 직전 submit 스냅샷.
  /// _applyConstraints 가 incremental diff 용으로 소비 후 null 로 reset.
  /// "이 탭이 야기한 -1 만 적용" 동작에 사용. docs/click_toggle_bug_analysis.md §2.
  List<List<int>>? _preTapSubmit;

  /// Notify unless we're inside a batched update. Used by every intermediate
  /// paint path; the terminal notify in [updateSquareBox] stays unconditional
  /// so a single end-of-click paint always reaches the UI.
  void _emitNotify() {
    if (_silentMode) return;
    notifyListeners();
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
      await Future.delayed(const Duration(milliseconds: 10));
    }

    submit = await readSquare.readSubmit(puzzle);
    // ignore: use_build_context_synchronously
    checkCompletePuzzle(context);
    _emitNotify();
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
    _emitNotify();
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
    _emitNotify();
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
    _emitNotify();
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

  /// Difficulty for hint masking ("easy" 0.80, "normal" 0.55, "hard" 0.35).
  String difficulty = "normal";

  void setDifficulty(String d) {
    difficulty = d;
  }

  /// Hide a deterministic subset of clue cells so the same puzzle + difficulty
  /// always reveals the same set on each load. Seeded by the answer hash so
  /// Continue mode reproduces the original mask without persisting it.
  void _maskByDifficulty() {
    double ratio;
    switch (difficulty) {
      case "easy": ratio = 0.80; break;
      case "hard": ratio = 0.35; break;
      default: ratio = 0.55;
    }
    if (ratio >= 1.0) return;

    int seed = 0;
    for (final row in answer) {
      for (final v in row) {
        seed = (seed * 31 + v) & 0x7FFFFFFF;
      }
    }
    final int rows = puzzle.length;
    final int cols = puzzle.isEmpty ? 0 : puzzle[0].length;
    final List<List<int>> cells = [];
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        cells.add([r, c]);
      }
    }
    cells.shuffle(Random(seed));
    final int keep = (cells.length * ratio).round();
    for (int i = keep; i < cells.length; i++) {
      puzzle[cells[i][0]][cells[i][1]].num = -1;
    }
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
      await Future.delayed(const Duration(milliseconds: 10));
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

  /// Apply a previously-saved bookmark submit grid. Treated as a single
  /// edit step appended to the existing doSubmit history (dropping any
  /// redo branch first), so undo brings the user back to their pre-load
  /// state instead of replacing the whole edit history with the bookmark's.
  Future<void> applyBookmarkSubmit(List<List<int>> bookmark) async {
    await removeHintLine();

    final List<List<int>> bookmarkCopy =
        bookmark.map((row) => List<int>.from(row)).toList();

    if (doPointer >= 0 && doPointer < doIndex) {
      doSubmit = doSubmit.sublist(0, doPointer + 1);
    }
    doSubmit.add(bookmarkCopy.map((row) => List<int>.from(row)).toList());
    doIndex = doSubmit.length - 1;
    doPointer = doIndex;

    submit = bookmarkCopy;
    applyUIWithAnswer(puzzle, submit);
    _emitNotify();
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
      await Future.delayed(const Duration(milliseconds: 10));
      // ignore: avoid_print
      print("_isUpdating $_isUpdating");
    }
    await removeHintLine();
    _isUpdating = 1;
    if(UserInfo.debugMode["print_isUpdating"]!) {
      // ignore: avoid_print
      print("update updateSquareBox : $_isUpdating");
    }

    // 탭/chain merge 직전의 canonical edge 스냅샷. _applyConstraints 가
    // "이 탭이 야기한 -1 만 적용" 하기 위해 pre/post propagation 결과를 diff 한다.
    // 솔버 silentMode 경로는 _applyConstraints 가 이 값을 무시.
    if (!_silentMode) {
      final preSnap = await readSquare.readSubmit(puzzle);
      _preTapSubmit = preSnap.map((r) => List<int>.from(r)).toList();
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
    _emitNotify();
    // UI yield — 사용자가 그린 라인이 즉시 paint 된 뒤에 무거운 propagation 진입.
    // 이 yield 가 없으면 같은 frame 안에서 propagation 이 끝날 때까지 paint 가 미뤄져
    // 탭이 "느리게" 보인다. (배치 모드에서는 _emitNotify 가 skip 되어 클릭 종료 시
    // 단 1회 paint 만 발생 → 솔버가 빠르게 연속 호출해도 깜빡임 없음)
    await Future.delayed(Duration.zero);
    await setDo();
    await _applyConstraints();
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
    _maskByDifficulty();
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

    // 0-clue 셀 4 변은 직접 의미 (no edges) 라 자동 -1 마킹 유지.
    // 추가 propagation -1 은 사용자 탭의 incremental diff 로만 시각화.
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
  ///**************** constraint propagation (single source of truth) *****************
  ///**********************************************************************************
  ///**********************************************************************************
  /// Square 의 모든 propagation 진입점. Hexagon/Triangle/Trihex 의 _applyConstraints
  /// 와 동일한 흐름이며, 다음 단계는 docs/constraint_lookahead.md §5 와 1:1 대응한다.
  ///
  /// 1. 작업용 그리드 w 빌드 (≥1 → 1, 0/-1/-2 → 0, 그 외 → -1)
  ///    - -2 를 0 으로 매핑해 사용자 빨강 마킹이 hard premise 가 되지 않도록 한다.
  /// 2. propagateDirectSquare(w, nums) fixed-point   (square_propagation_core.dart)
  /// 3. isWorkingStateConsistent(w, nums) 가 true 이면 look-ahead loop ≤ 5 회
  /// 4. puzzle 에 반영 (사용자 그림 ≥1, 힌트 -3/-5, 사용자 X -4 는 보존,
  ///    기존 -1/-2 도 monotonic 유지 — docs/click_toggle_bug_analysis.md §1)
  /// 5. 원래 -2 이던 자리에 새로 -1 이 도출되면 -2 로 복원 (빨강 마킹 의미 보존)
  /// 6. 최종 isWorkingStateConsistent 가 false 면 canonical edge 만 orig 로 되돌림
  Future<void> _applyConstraints() async {
    if (UserInfo.debugMode["print_methodName"]!) {
      // ignore: avoid_print
      print("call _applyConstraints");
    }

    final int rows = puzzle.length;
    if (rows == 0) return;
    final int cols = puzzle[0].length;
    if (cols == 0) return;

    // clue 그리드를 한 번만 빌드. propagation 안에서 매번 puzzle[i][j].num 을
    // 다시 읽지 않도록.
    final List<List<int>> nums = List.generate(
        rows, (i) => List.generate(cols, (j) => puzzle[i][j].num));

    // 2. 작업용 그리드 빌드.
    final List<List<int>> edge = await readSquare.readSubmit(puzzle);
    final List<List<int>> orig = edge.map((r) => List<int>.from(r)).toList();
    final List<List<int>> w = edge.map((row) => row.map((v) {
      if (v >= 1) return 1;
      if (v == 0 || v == -1 || v == -2) return 0;
      return -1; // -3 정답 hint, -4 사용자 X, -5 오답 hint 모두 hard-disabled
    }).toList()).toList();

    // incremental diff 용 pre-tap propagation 결과.
    // 새 -1 도출 중 이번 탭 *이전* propagation 으로도 도출됐을 것은 적용에서 제외 →
    // "이 탭이 야기한 -1 만 시각화" (docs/click_toggle_bug_analysis.md §2).
    // pre-tap 스냅샷이 없거나 (외부 호출, 솔버) silentMode 면 diff 적용 안 함.
    final List<List<int>>? preSnap = _preTapSubmit;
    _preTapSubmit = null;
    List<List<int>>? wPreBaseline;
    if (preSnap != null && !_silentMode) {
      final List<List<int>> wPre = preSnap.map((row) => row.map((v) {
        if (v >= 1) return 1;
        if (v == 0 || v == -1 || v == -2) return 0;
        return -1;
      }).toList()).toList();
      propagateDirectSquare(wPre, rows, cols, nums);
      wPreBaseline = wPre;
    }

    // 3. Phase 1 — 직접 추론(셀+꼭짓점 fixed-point). 가벼움 (≤ 30ms 수준).
    //    여기 결과만으로도 사용자 시각 -1 의 80~90% 가 잡히므로 즉시 반영해
    //    탭 응답성을 확보한다. silentMode 라도 writeSubmit 은 그대로 수행해야
    //    Phase 2 가 아무 변화도 추가하지 않을 때 Phase 1 결과가 puzzle 에서
    //    누락되지 않는다. paint 는 _emitNotify 가 막아 한 클릭 = 한 paint 보장.
    propagateDirectSquare(w, rows, cols, nums);
    _writeWorkingToEdge(edge, orig, w, preBaseline: wPreBaseline);
    await readSquare.writeSubmit(puzzle, edge);
    submit = edge;
    _emitNotify();

    // 4. UI yield — Phase 1 결과를 paint 한 뒤 무거운 look-ahead 진입.
    //    Future.delayed(Duration.zero) 는 microtask 가 아니라 task 큐에 들어가
    //    Flutter scheduleFrame 이 끼어들 수 있다. silentMode 에서는 paint 가
    //    Consumer rebuild 없이는 진행되지 않으므로 (SquareBox 의 비-hint edge 는
    //    plain Container 라 puzzle mutation 자체로는 다시 그려지지 않음) yield 는
    //    무해하다.
    await Future.delayed(Duration.zero);

    // 5. Phase 2 — 1-step look-ahead. 라이브 상태가 이미 모순이면 모든 가설이
    //    모순으로 잘못 판정되므로 스킵 (모든 미정 변 -1 처리 사고 방지).
    bool laAnyChanged = false;
    if (isWorkingStateConsistent(w, rows, cols, nums)) {
      // outer iter 상한: 5 → 2. 통상 1~2 회면 수렴하며, 깊은 chain deduction 은
      // 사용자가 다음 입력 시 다시 잡힌다 (정확도 vs 응답성 균형).
      // hypChanges 는 호출 전 clear → propagateHypothesis 가 변경한 위치를 append
      // → 호출 후 그 위치들만 0 으로 되돌린다. 매 가설마다 grid 전체 deep copy 를
      //  하지 않으므로 look-ahead overhead 가 ~10× 줄어든다.
      // hypChanges: 위치를 r * 1024 + c 로 인코딩한 int 리스트 (List<int>).
      // 매 가설마다 [r, c] 짝 list 를 새로 할당하지 않으므로 GC 부담이 추가로 감소.
      final List<int> hypChanges = <int>[];
      for (int laIter = 0; laIter < 2; laIter++) {
        bool laChanged = false;
        int hypCount = 0;
        for (int er = 0; er < w.length; er++) {
          for (int ec = 0; ec < w[er].length; ec++) {
            if (w[er][ec] != 0) continue;
            // 가설 50 개마다 UI yield. 한 outer iter 가 수백 ms 라도 그 동안
            // 다른 탭/스크롤에 반응할 수 있다.
            if ((++hypCount) % 50 == 0) {
              await Future.delayed(Duration.zero);
            }
            hypChanges.clear();
            hypChanges.add(er * 1024 + ec);
            w[er][ec] = 1;
            final bool contradiction = propagateHypothesisSquare(
                w, rows, cols, nums, changes: hypChanges);
            // 가설이 만든 모든 변경(가설 자신 포함)을 0 으로 복원.
            // propagateHypothesis 의 모든 mutation 은 0 → ±1 단방향이라 0 복원이 정답.
            for (final pos in hypChanges) {
              w[pos ~/ 1024][pos & 1023] = 0;
            }
            if (contradiction) {
              w[er][ec] = -1;
              laChanged = true;
              laAnyChanged = true;
            }
          }
        }
        if (!laChanged) break;
        propagateDirectSquare(w, rows, cols, nums);
      }
    }

    // 6. Phase 2 결과 반영 (변화가 있었을 때만). edge 는 Phase 1 직후 puzzle 과
    //    동기화돼 있으므로 그 위에 추가 deduction 만 얹는다.
    if (laAnyChanged) {
      _writeWorkingToEdge(edge, orig, w, preBaseline: wPreBaseline);
      await readSquare.writeSubmit(puzzle, edge);
    }

    // 7. 사후 일관성 가드. propagation 이 보드를 globally infeasible 하게 만들었다면
    //    (예: 사용자가 정답 라인을 -4 로 잠근 직후) 이 시점에 false.
    //
    //    사용자 1회 탭 (_silentMode == false): canonical edge 만 pre-propagation
    //    스냅샷(orig)으로 되돌려 새 -1 도출만 무효화한다. 사용자 탭/chain merge 와
    //    prior -1 은 그대로 유지되어 보드 전체가 "snap" 으로 변하는 churn 이 사라짐
    //    (docs/click_toggle_bug_analysis.md §1번 대응). non-canonical 위치(inner cell
    //    .left/.up)는 propagation 이 건드리지 않았으므로 복원할 것이 없음.
    //
    //    솔버 (_silentMode == true): revert 하지 않고 _solverDetectedInconsistency
    //    플래그만 set. 이대로 두면 puzzle 에 모순 상태가 남지만, 솔버 측에서 즉시
    //    backtrack 으로 정정한다. revert 하면 잘못 그어진 라인이 puzzle 에 남아
    //    솔버가 wrong premise 위에서 계속 추론하는 사고가 생기기 때문 (참고:
    //    docs/auto_solver_bug_analysis.md §2).
    final List<List<int>> liveW = edge.map((row) => row.map((v) {
      if (v >= 1) return 1;
      if (v == 0) return 0;
      return -1;
    }).toList()).toList();
    if (!isWorkingStateConsistent(liveW, rows, cols, nums)) {
      if (_silentMode) {
        _solverDetectedInconsistency = true;
        submit = edge;
      } else {
        await readSquare.writeSubmit(puzzle, orig);
        submit = orig;
      }
    } else {
      submit = edge;
    }
    _emitNotify();
  }

  /// w 의 -1/0 결과를 edge 에 반영. 잠금 자리(-3, -4, -5, ≥1)는 보존하고
  /// 원래 -2 자리에 새로 -1 이 도출되면 -2 로 복원한다 (사용자 빨강 마킹 의미 보존).
  ///
  /// docs/click_toggle_bug_analysis.md §1 대응: 기존 -1/-2 도 propagation 이 재도출
  /// 하지 못해도 유지해 한 탭에 보드 전체 -1 분포가 churn 되는 것을 방지. propagation
  /// 은 -1 을 추가만 하고 제거하지 않는다 (monotonic). 사용자가 라인을 지워 prior -1
  /// 의 전제가 사라진 경우는 undo (doSubmit) 가 정상 정리.
  ///
  /// docs/click_toggle_bug_analysis.md §2 대응: [preBaseline] 이 주어지면
  /// pre-tap propagation 으로도 도출됐을 -1 (= w_pre[i][j] == -1) 은 이번 탭이
  /// 야기한 것이 아니므로 새로 적용에서 제외. 사용자 시각에는 "이 탭이 만든 -1" 만
  /// 보임. 솔버는 null 을 전달해 전체 propagation 결과를 그대로 받는다.
  void _writeWorkingToEdge(
      List<List<int>> edge, List<List<int>> orig, List<List<int>> w,
      {List<List<int>>? preBaseline}) {
    for (int i = 0; i < edge.length; i++) {
      for (int j = 0; j < edge[i].length; j++) {
        final int origValue = orig[i][j];
        if (origValue >= 1 ||
            origValue == -3 ||
            origValue == -4 ||
            origValue == -5) {
          continue;
        }
        final int derived = w[i][j] == -1 ? -1 : 0;
        if ((origValue == -1 || origValue == -2) && derived == 0) {
          continue;
        }
        // 새 -1 마크: pre-tap propagation 결과에서도 -1 이면 이번 탭이 야기한
        // 것이 아니라 clue 만으로도 도출됐을 것 → 적용하지 않음.
        if (preBaseline != null &&
            origValue == 0 &&
            derived == -1 &&
            preBaseline[i][j] == -1) {
          continue;
        }
        edge[i][j] =
            (origValue == -2 && derived == -1) ? -2 : derived;
      }
    }
  }

  /// External entry point for callers outside this class (e.g. HowToPlay).
  /// Internal callers should use [_applyConstraints] directly.
  Future<void> applyConstraints() => _applyConstraints();

  ///**********************************************************************************
  ///**********************************************************************************
  ///****************** human-like auto solver ******************
  ///**********************************************************************************
  ///**********************************************************************************
  /// 한 수씩 100% 확정 라인을 찾아 시각적으로 클릭한다. 확정이 없는 경우 솔버
  /// 전용 슬롯(Red/Green/Blue 라벨과 분리된 __solver_R/G/B 키)에 현재 상태를
  /// 저장하고, propagation 영향이 가장 큰 undecided edge 로 추측한다. 추측이
  /// 모순으로 이어지면 슬롯을 복원하고 반대값(-4 사용자 X)으로 확정. 슬롯 3 개를
  /// 모두 소진했거나 사용자가 [cancelSolver] 를 호출하면 종료한다.
  static const List<String> _solverSlotKeys = ["__solver_R", "__solver_G", "__solver_B"];
  static const Duration _solverStepDelay = Duration(milliseconds: 500);

  bool _solverRunning = false;
  bool _solverShouldStop = false;
  String _solverStatus = "";
  /// `_applyConstraints` 가 silentMode 중 사후 inconsistency 를 감지하면 set.
  /// 솔버는 매 click 함수 반환 직후 이 값을 확인해 backtrack 여부를 결정한다.
  bool _solverDetectedInconsistency = false;

  bool get isSolverRunning => _solverRunning;
  String get solverStatus => _solverStatus;

  void cancelSolver() {
    _solverShouldStop = true;
  }

  Future<void> solveHumanLike() async {
    if (_solverRunning) return;
    _solverRunning = true;
    _solverShouldStop = false;
    _solverStatus = "solver_running";
    notifyListeners();

    final List<_SolverGuessFrame> guesses = [];

    try {
      while (!_solverShouldStop) {
        // 진행 중인 propagation 잠금이 풀릴 때까지 대기.
        while (_isUpdating != 0 && !_solverShouldStop) {
          await Future.delayed(const Duration(milliseconds: 30));
        }
        if (_solverShouldStop) break;

        submit = await readSquare.readSubmit(puzzle);
        if (_isPuzzleSolvedLocal()) {
          _solverStatus = "solver_done";
          notifyListeners();
          break;
        }

        final int rows = puzzle.length;
        if (rows == 0) break;
        final int cols = puzzle[0].length;
        final List<List<int>> nums = List.generate(
            rows, (i) => List.generate(cols, (j) => puzzle[i][j].num));
        final List<List<int>> w = buildWorkingFromEdges(submit);
        propagateDirectSquare(w, rows, cols, nums);

        // 진입 시점에 이미 모순이면 마지막 추측이 잘못된 것 → 슬롯 복원.
        if (!isWorkingStateConsistent(w, rows, cols, nums)) {
          if (guesses.isEmpty) {
            _solverStatus = "solver_stuck";
            notifyListeners();
            break;
          }
          final frame = guesses.removeLast();
          _solverStatus = "solver_backtrack";
          notifyListeners();
          await _solverRestoreAndDisproveGuess(frame);
          await Future.delayed(_solverStepDelay);
          continue;
        }

        // "edge=-1 가설 → 모순 → 반드시 그어야 함" 으로 확정 +1 추출.
        final List<int>? draw =
            findForcedDrawByContradiction(w, rows, cols, nums);
        if (draw != null) {
          _solverStatus = "solver_step";
          notifyListeners();
          final ok = await _solverApplyDraw(draw[0], draw[1]);
          if (_solverShouldStop) break;
          if (!ok) {
            // 확정 추론이 deep contradiction 을 만들었다 — 입력 상태에 wrong
            // premise 가 깔려 있었던 셈. 가장 가까운 추측까지 backtrack.
            if (!await _backtrackToLastGuess(guesses)) break;
          }
          await Future.delayed(_solverStepDelay);
          continue;
        }

        // "edge=+1 가설 → 모순 → 반드시 비활성" 으로 확정 -1 추출.
        // 직접규칙과 _applyConstraints 의 2-iter look-ahead 가 놓친 깊은 -1
        // 확정을 잡아 -4 (사용자 X) 로 잠근다. 이 단계가 없으면 미처리분이
        // pickHighestImpactGuess 로 흘러들어가 잘못된 +1 으로 그어졌다 —
        // docs/auto_solver_bug_analysis.md §1 참조.
        final List<int>? disable =
            findForcedDisableByContradiction(w, rows, cols, nums);
        if (disable != null) {
          _solverStatus = "solver_step";
          notifyListeners();
          final ok = await _solverApplyDisable(disable[0], disable[1]);
          if (_solverShouldStop) break;
          if (!ok) {
            if (!await _backtrackToLastGuess(guesses)) break;
          }
          await Future.delayed(_solverStepDelay);
          continue;
        }

        // 확정 없음 → 라벨 슬롯에 저장 후 영향력이 가장 큰 edge 로 추측.
        if (guesses.length >= _solverSlotKeys.length) {
          _solverStatus = "solver_labels_full";
          notifyListeners();
          break;
        }
        final List<int>? guess = pickHighestImpactGuess(w, rows, cols, nums);
        if (guess == null) {
          _solverStatus = "solver_stuck";
          notifyListeners();
          break;
        }
        final int slot = guesses.length;
        await _solverSaveSlot(slot);
        guesses.add(_SolverGuessFrame(slot, guess[0], guess[1]));
        _solverStatus = "solver_guess";
        notifyListeners();
        final ok = await _solverApplyDraw(guess[0], guess[1]);
        if (_solverShouldStop) break;
        if (!ok) {
          // 추측이 deep contradiction 을 만들었다 — 정상 흐름. backtrack.
          if (!await _backtrackToLastGuess(guesses)) break;
        }
        await Future.delayed(_solverStepDelay);
      }
    } finally {
      _solverRunning = false;
      // 사용한 슬롯 키 정리 (사용자 Red/Green/Blue 라벨은 건드리지 않음).
      for (int i = 0; i < _solverSlotKeys.length; i++) {
        await _solverClearSlot(i);
      }
      notifyListeners();
    }
  }

  bool _isPuzzleSolvedLocal() {
    if (answer.isEmpty || submit.isEmpty) return false;
    for (int i = 0; i < answer.length; i++) {
      for (int j = 0; j < answer[i].length; j++) {
        final bool ansSel = answer[i][j] == 1;
        final bool subSel = submit[i][j] > 0;
        if (ansSel != subSel) return false;
      }
    }
    return true;
  }

  String _solverSlotStorageKey(int slot) =>
      "${loadKey}_${_solverSlotKeys[slot]}";

  Future<void> _solverSaveSlot(int slot) async {
    await readSquare.savePuzzle(_solverSlotStorageKey(slot));
  }

  Future<void> _solverClearSlot(int slot) async {
    final ExtractData prefs = ExtractData();
    final String key = _solverSlotStorageKey(slot);
    if (await prefs.containsKey(key)) {
      await prefs.removeKey(key);
    }
  }

  /// 마지막 추측 frame 을 pop 하고 복원 + 잠금. guesses 가 비어 있으면 false 를
  /// 반환해 호출자가 솔버를 멈추게 한다. true 면 backtrack 완료, 다음 iter 계속.
  Future<bool> _backtrackToLastGuess(List<_SolverGuessFrame> guesses) async {
    if (guesses.isEmpty) {
      _solverStatus = "solver_stuck";
      notifyListeners();
      return false;
    }
    final frame = guesses.removeLast();
    _solverStatus = "solver_backtrack";
    notifyListeners();
    await _solverRestoreAndDisproveGuess(frame);
    return true;
  }

  /// 슬롯에 저장된 시점으로 보드를 복원하고, 실패한 추측 edge 를 사용자 X (-4)
  /// 로 잠가 같은 분기를 다시 시도하지 않게 한다. 두 단계 모두 _silentMode 로
  /// 묶어 사이 paint 가 새지 않게 한다.
  Future<void> _solverRestoreAndDisproveGuess(_SolverGuessFrame frame) async {
    final List<List<int>> saved =
        await readSquare.loadPuzzle(_solverSlotStorageKey(frame.slot));
    await _solverClearSlot(frame.slot);
    if (saved.isEmpty) return;
    await _runSilently(() async {
      await applyBookmarkSubmit(saved);
      await _solverApplyDisable(frame.canonRow, frame.canonCol);
    });
    // 배경 작업이 끝났으니 한 번만 paint.
    notifyListeners();
  }

  /// canonical edge (i, j) 를 (puzzleRow, puzzleCol, dir) 로 변환.
  List<dynamic>? _canonicalToPuzzle(int i, int j) {
    if (puzzle.isEmpty) return null;
    final int pRows = puzzle.length;
    final int pCols = puzzle[0].length;
    if (i.isEven) {
      if (j < 0 || j >= pCols) return null;
      if (i == 0) return [0, j, "up"];
      final int row = i ~/ 2 - 1;
      if (row < 0 || row >= pRows) return null;
      return [row, j, "down"];
    } else {
      final int row = (i - 1) ~/ 2;
      if (row < 0 || row >= pRows) return null;
      if (j == 0) return [row, 0, "left"];
      if (j == 1) return [row, 0, "right"];
      final int col = j - 1;
      if (col >= pCols) return null;
      return [row, col, "right"];
    }
  }

  /// 호출자가 nested 로 [_silentMode] 를 켜더라도 안전하게 동작하도록
  /// try/finally 로 이전 값을 복원한다. solveHumanLike 의 backtrack 경로처럼
  /// `_silentMode=true` 가 이미 set 된 상태에서 _solverApplyDisable 이 다시
  /// 호출되어도 silent mode 가 조기 해제되지 않는다.
  Future<void> _runSilently(Future<void> Function() body) async {
    final bool outer = _silentMode;
    _silentMode = true;
    try {
      await body();
    } finally {
      _silentMode = outer;
    }
  }

  /// 반환값: 클릭 후 보드 상태가 일관되면 true, deep contradiction 이 검출되어
  /// puzzle 에 모순 상태가 남았으면 false. 호출자(solveHumanLike)는 false 일 때
  /// 즉시 backtrack 으로 정정해야 한다.
  Future<bool> _solverApplyDraw(int canonI, int canonJ) async {
    final mapped = _canonicalToPuzzle(canonI, canonJ);
    if (mapped == null) return true;
    final int row = mapped[0] as int;
    final int col = mapped[1] as int;
    final String dir = mapped[2] as String;
    // 양수 1 을 보내면 nearColor 체인 색상이 자동 선택되어 사용자 클릭처럼 보인다.
    const int drawSeed = 1;
    _solverDetectedInconsistency = false;
    // _silentMode 로 chain merge 의 setLineColorBox 와 _applyConstraints 의
    // Phase 1 paint 를 모두 억제. updateSquareBox 마지막 줄의 unconditional
    // notifyListeners 만 살아남아 한 클릭 = 한 paint 가 보장된다.
    await _runSilently(() async {
      switch (dir) {
        case "up":    await updateSquareBox(row, col, up: drawSeed); break;
        case "down":  await updateSquareBox(row, col, down: drawSeed); break;
        case "left":  await updateSquareBox(row, col, left: drawSeed); break;
        case "right": await updateSquareBox(row, col, right: drawSeed); break;
      }
    });
    return !_solverDetectedInconsistency;
  }

  Future<bool> _solverApplyDisable(int canonI, int canonJ) async {
    final mapped = _canonicalToPuzzle(canonI, canonJ);
    if (mapped == null) return true;
    final int row = mapped[0] as int;
    final int col = mapped[1] as int;
    final String dir = mapped[2] as String;
    _solverDetectedInconsistency = false;
    await _runSilently(() async {
      switch (dir) {
        case "up":    await updateSquareBox(row, col, up: -4); break;
        case "down":  await updateSquareBox(row, col, down: -4); break;
        case "left":  await updateSquareBox(row, col, left: -4); break;
        case "right": await updateSquareBox(row, col, right: -4); break;
      }
    });
    return !_solverDetectedInconsistency;
  }
}

class _SolverGuessFrame {
  final int slot;
  final int canonRow;
  final int canonCol;
  _SolverGuessFrame(this.slot, this.canonRow, this.canonCol);
}