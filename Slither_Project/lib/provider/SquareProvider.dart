import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import '../MakePuzzle/ReadSquare.dart';
import '../Platform/ExtractData.dart'
  if (dart.library.html) '../Platform/ExtractDataWeb.dart'; // 조건부 import
//안드로이드 빌드 시 삭제 필수
//import '../Platform/ExtractDataWeb.dart';
import '../Scene/GameSceneSquare.dart';
import '../ThemeColor.dart';
import '../User/UserInfo.dart';
import '../widgets/SquareBox.dart';

class SquareProvider with ChangeNotifier {
  late ReadSquare readSquare;
  late BuildContext context;
  final String loadKey;

  final GameStateSquare gameStateSquare;
  bool shutdown = false;  //showdialog에서 ok를 눌러 GameSceneSquare을 닫아야 하는 경우

  SquareProvider({
    this.isContinue = false,
    required this.context,
    required this.gameStateSquare,
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
  void init() async {
    puzzle = initSquarePuzzle(answer[0].length, answer.length ~/ 2);
    squareField = await buildSquarePuzzleAnswer(answer, isContinue: isContinue);
    readSquare.setPuzzle(puzzle);
    notifyListeners();
  }

  void restart() async {
    for(int i = 0 ; i < submit.length ; i++) {
      for(int j = 0 ; j < submit[i].length ; j++) {
        submit[i][j] = 0;
      }
    }

    await readSquare.writeSubmit(puzzle, submit);
    notifyListeners();
  }

  void showHint(BuildContext context) async {
    List<List<dynamic>> items = await checkCompletePuzzleCompletely(context);
    //print("hint items : $items");
    List<dynamic> item;
    if(items.length > 1) {
      item = items[Random().nextInt(items.length - 1)];
    }
    else {
      item = items[0];
    }

    //print("hint item : $item");
    setLineColor(int.parse(item[0].toString()), int.parse(item[1].toString()), item[2].toString(), -3);
  }

  Future<void> refreshSubmit() async {
    submit = await readSquare.readSubmit(puzzle);
    // ignore: use_build_context_synchronously
    checkCompletePuzzle(context);
    notifyListeners();
  }

  //row, column is puzzle's row, column
  void setLineColor(int row, int column, String dir, int color) {
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

  Future<List<List<dynamic>>> checkCompletePuzzleCompletely(BuildContext context) async {
    List<List<dynamic>> rtValue = [];

    submit = await readSquare.readSubmit(puzzle);

    String dir = "";
    int row = 0, col = 0;

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

    return rtValue;
  }

  void showComplete(BuildContext context) {
    gameStateSquare.isComplete = true;
    UserInfo.clearPuzzle(loadKey);
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

  ///control only submit data
  void applyLabel(List<List<int>> data) async {
    submit = data;
    //squareField = await buildSquarePuzzleLabel(answer, submit);
    //_provider.setSquareField(await buildSquarePuzzleLabel(answer, submit));
  }

  Future<List<Widget>> puzzleToSquareField() async {
    List<Widget> columnChildren = [];

    for (int i = 0; i < puzzle.length; i++) {
      List<Widget> rowChildren = [];
      for (int j = 0; j < puzzle[i].length; j++) {
        rowChildren.add(puzzle[i][j]);
        //print("${puzzle[i][j].up}${puzzle[i][j].down}${puzzle[i][j].left}${puzzle[i][j].right}");
      }
      columnChildren.add(
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: rowChildren,
        ),
      );
    }

    return columnChildren;
  }

  Future<List<Widget>> buildSquarePuzzleLabel(List<List<int>> answer, List<List<int>> submit) async {
    //resize puzzle
    if(answer.isEmpty) {
      //print("answer is empty");
      return Future.value([]);
    }
    List<List<SquareBox>> puzzle = initSquarePuzzle(answer[0].length, answer.length ~/ 2);
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

    applyUIWithAnswer(puzzle, submit);

    return columnChildren;
  }

  ///getter and setter about widgets

  List<Widget> getSquareField() {
    return squareField;
  }
  void setSquareField(List<Widget> field) {
    squareField = field;
    notifyListeners();
  }

  void setPuzzle(List<List<SquareBox>> puzzle) {
    this.puzzle = puzzle;
    puzzleToWidget();
  }

  void setGameField(GameStateSquare gameField) {
    this.gameField = gameField;
    notifyListeners();
  }

  void setContinue(bool isContinue) {
    this.isContinue = isContinue;
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

    /*
    if(kIsWeb) {
      //웹 플랫폼
      //안드로이드 빌드 시, 웹 전용 저장 함수 주석 처리 필수
      // + import '../Platform/ExtractDataWeb.dart'; 부분도 주석 처리 필수
      //ExtractDataWeb().saveStringToFileInWeb(temp, "filename.txt");
    } else {
      //모든 플랫폼
      //웹 빌드 시, 다른 플랫폼 용 함수 주석 처리 필수
      //안드로이드로 생성된 파일은 PC에서만 확인 가능하다
      //경로 : 스마트폰\내장 저장공간\Android\data\slitherlink.com.puzzle.glorygem.slitherlink_project\files
      ExtractData().saveStringToFile(temp, "filename.txt");
    }
     */
  }

  ///**********************************************************************************
  ///**********************************************************************************
  ///****************************** about undo & redo ******************************
  ///**********************************************************************************
  ///**********************************************************************************
  List<List<List<int>>> doSubmit = [];
  int doPointer = -1;   //now position
  int doIndex = -1;     //max Index

  Future<void> setDo() async {
    List<List<int>> clonedSubmit = List.generate(submit.length, (i) => List.from(submit[i]));

    //when clicking square after click undo
    if(doPointer < doIndex) {
      doSubmit = doSubmit.sublist(0, doPointer + 1);
      doSubmit.add(clonedSubmit);
      doIndex = doSubmit.length - 1;
      doPointer = doIndex;
    }
    else {
      doSubmit.add(clonedSubmit);
      doIndex++;
      doPointer++;
    }
  }

  Future<void> undo() async {
    if(doPointer >= 0) {
      doPointer--;
      if(doPointer >= 0) {
        submit = doSubmit[doPointer];
      }
      else if(doPointer == -1) {
        for(int i = 0 ; i < submit.length ; i++) {
          for(int j = 0 ; j < submit[i].length ; j++) {
            submit[i][j] = 0;
          }
        }
      }

      await readSquare.writeSubmit(puzzle, submit);
      refreshSubmit();
      notifyListeners();
    }
  }

  Future<void> redo() async {
    if(doPointer < doIndex) {
      doPointer++;
      submit = doSubmit[doPointer];

      await readSquare.writeSubmit(puzzle, submit);
      refreshSubmit();
      notifyListeners();
    }
  }

  void printSubmit() {
    String temp = "";
    for(int i = 0 ; i < submit.length ; i++) {
      for(int j = 0 ; j < submit[i].length ; j++) {
        temp += "${submit[i][j]} ";
      }
      // ignore: avoid_print
      print("row $i $temp");
      temp = "";
    }
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
    Set<int> nearColor = {};
    int lineValue = 0; //new line's value

    if (down != null) {
      nearColor = getNearColor(row, column, "down");
      lineValue = down;
    } else if (right != null) {
      nearColor = getNearColor(row, column, "right");
      lineValue = right;
    } else if (up != null) {
      nearColor = getNearColor(row, column, "up");
      lineValue = up;
    } else if (left != null) {
      nearColor = getNearColor(row, column, "left");
      lineValue = left;
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
        //print("set $row, $column, $lineValue");

        await refreshSubmit();
        notifyListeners();
        await setDo();
        return;
      }

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

        setLineColor(oldRow, oldColumn, pos, lineValue);
        //print("set [$oldRow, $oldColumn, $pos, $lineValue]");
      }
    }

    await refreshSubmit();
    notifyListeners();
    await setDo();
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
    else if(col != 0) {
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
    else if(row != 0) {
      switch(pos) {
        case "down":
          addIfPositive(use, puzzle[row][col].left);
          addIfPositive(use, puzzle[row][col].right);
          addIfPositive(use, puzzle[row + 1][col].left);
          addIfPositive(use, puzzle[row + 1][col].right);
          addIfPositive(use, puzzle[row][col + 1].down);
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
          addIfPositive(use, puzzle[row - 1][col + 1].down);
          addIfPositive(use, puzzle[row][col].down);

          if(puzzle.length > row + 1) {
            addIfPositive(use, puzzle[row + 1][col].right);
            addIfPositive(use, puzzle[row + 1][col + 1].down);
          }
          break;
      }
    }
    else {
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

  List<dynamic> getOldColorList(int row, int col, String pos, int now) {
    //[row, col, pos]
    List<dynamic> rtValue = [];
    int normal = 0;

    //same as getNearColor except for comparing color
    if(row != 0 && col != 0) {
      switch(pos) {
        case "down":
        //use.add(puzzle[row][col - 1].down);
          if(puzzle[row][col - 1].down != normal && puzzle[row][col - 1].down != now) {
            rtValue.add([row, col - 1, "down"]);
          }
          if (puzzle[row][col - 1].right != normal && puzzle[row][col - 1].right != now) {
            rtValue.add([row, col - 1, "right"]);
          }
          if (puzzle[row][col].right != normal && puzzle[row][col].right != now) {
            rtValue.add([row, col, "right"]);
          }
          if (puzzle.length > row + 1) {
            if (puzzle[row + 1][col - 1].right != normal && puzzle[row + 1][col - 1].right != now) {
              rtValue.add([row + 1, col - 1, "right"]);
            }
            if (puzzle[row + 1][col].right != normal && puzzle[row + 1][col].right != now) {
              rtValue.add([row + 1, col, "right"]);
            }
          }
          if (puzzle[row].length > col + 1) {
            if (puzzle[row][col + 1].down != normal && puzzle[row][col + 1].down != now) {
              rtValue.add([row, col + 1, "down"]);
            }
          }
          break;
        case "right":
          if (puzzle[row - 1][col].right != normal && puzzle[row - 1][col].right != now) {
            rtValue.add([row - 1, col, "right"]);
          }
          if (puzzle[row - 1][col].down != normal && puzzle[row - 1][col].down != now) {
            rtValue.add([row - 1, col, "down"]);
          }
          if (puzzle[row][col].down != normal && puzzle[row][col].down != now) {
            rtValue.add([row, col, "down"]);
          }
          if (puzzle[row].length > col + 1) {
            if (puzzle[row - 1][col + 1].down != normal && puzzle[row - 1][col + 1].down != now) {
              rtValue.add([row - 1, col + 1, "down"]);
            }
            if (puzzle[row][col + 1].down != normal && puzzle[row][col + 1].down != now) {
              rtValue.add([row, col + 1, "down"]);
            }
          }
          if (puzzle.length > row + 1) {
            if (puzzle[row + 1][col].right != normal && puzzle[row + 1][col].right != now) {
              rtValue.add([row + 1, col, "right"]);
            }
          }
          break;
      }
    }
    else if (col != 0) {
      switch (pos) {
        case "up":
          if (puzzle[row][col - 1].up != normal && puzzle[row][col - 1].up != now) {
            rtValue.add([row, col - 1, "up"]);
          }
          if (puzzle[row][col - 1].right != normal && puzzle[row][col - 1].right != now) {
            rtValue.add([row, col - 1, "right"]);
          }
          if (puzzle[row][col].right != normal && puzzle[row][col].right != now) {
            rtValue.add([row, col, "right"]);
          }
          if (puzzle[row].length > col + 1) {
            if (puzzle[row][col + 1].up != normal && puzzle[row][col + 1].up != now) {
              rtValue.add([row, col + 1, "up"]);
            }
          }
          break;
        case "down":
          if (puzzle[row][col - 1].down != normal && puzzle[row][col - 1].down != now) {
            rtValue.add([row, col - 1, "down"]);
          }
          if (puzzle[row][col - 1].right != normal && puzzle[row][col - 1].right != now) {
            rtValue.add([row, col - 1, "right"]);
          }
          if (puzzle[row][col].right != normal && puzzle[row][col].right != now) {
            rtValue.add([row, col, "right"]);
          }
          if (puzzle[row].length > col + 1) {
            if (puzzle[row][col + 1].down != normal && puzzle[row][col + 1].down != now) {
              rtValue.add([row, col + 1, "down"]);
            }
          }
          if (puzzle.length > row + 1) {
            if (puzzle[row + 1][col - 1].right != normal && puzzle[row + 1][col - 1].right != now) {
              rtValue.add([row + 1, col - 1, "right"]);
            }
            if (puzzle[row + 1][col].right != normal && puzzle[row + 1][col].right != now) {
              rtValue.add([row + 1, col, "right"]);
            }
          }
          break;
        case "right":
          if (puzzle[row][col].up != normal && puzzle[row][col].up != now) {
            rtValue.add([row, col, "up"]);
          }
          if (puzzle[row][col].down != normal && puzzle[row][col].down != now) {
            rtValue.add([row, col, "down"]);
          }
          if (puzzle[row].length > col + 1) {
            if (puzzle[row][col + 1].up != normal && puzzle[row][col + 1].up != now) {
              rtValue.add([row, col + 1, "up"]);
            }
            if (puzzle[row][col + 1].down != normal && puzzle[row][col + 1].down != now) {
              rtValue.add([row, col + 1, "down"]);
            }
          }
          if (puzzle.length > row + 1) {
            if (puzzle[row + 1][col].right != normal && puzzle[row + 1][col].right != now) {
              rtValue.add([row + 1, col, "right"]);
            }
          }
          break;
      }
    }
    else if (row != 0) {
      switch (pos) {
        case "down":
          if (puzzle[row][col].left != normal && puzzle[row][col].left != now) {
            rtValue.add([row, col, "left"]);
          }
          if (puzzle[row][col].right != normal && puzzle[row][col].right != now) {
            rtValue.add([row, col, "right"]);
          }
          if (puzzle[row + 1][col].left != normal && puzzle[row + 1][col].left != now) {
            rtValue.add([row + 1, col, "left"]);
          }
          if (puzzle[row + 1][col].right != normal && puzzle[row + 1][col].right != now) {
            rtValue.add([row + 1, col, "right"]);
          }
          if (puzzle[row][col + 1].down != normal && puzzle[row][col + 1].down != now) {
            rtValue.add([row, col + 1, "down"]);
          }
          break;
        case "left":
          if (puzzle[row - 1][col].left != normal && puzzle[row - 1][col].left != now) {
            rtValue.add([row - 1, col, "left"]);
          }
          if (puzzle[row - 1][col].down != normal && puzzle[row - 1][col].down != now) {
            rtValue.add([row - 1, col, "down"]);
          }
          if (puzzle[row][col].down != normal && puzzle[row][col].down != now) {
            rtValue.add([row, col, "down"]);
          }
          if (puzzle.length > row + 1) {
            if (puzzle[row + 1][col].left != normal && puzzle[row + 1][col].left != now) {
              rtValue.add([row + 1, col, "left"]);
            }
          }
          break;
        case "right":
          if (puzzle[row - 1][col].right != normal && puzzle[row - 1][col].right != now) {
            rtValue.add([row - 1, col, "right"]);
          }
          if (puzzle[row - 1][col].down != normal && puzzle[row - 1][col].down != now) {
            rtValue.add([row - 1, col, "down"]);
          }
          if (puzzle[row - 1][col + 1].down != normal && puzzle[row - 1][col + 1].down != now) {
            rtValue.add([row - 1, col + 1, "down"]);
          }
          if (puzzle[row][col].down != normal && puzzle[row][col].down != now) {
            rtValue.add([row, col, "down"]);
          }
          if (puzzle.length > row + 1) {
            if (puzzle[row + 1][col].right != normal && puzzle[row + 1][col].right != now) {
              rtValue.add([row + 1, col, "right"]);
            }
            if (puzzle[row + 1][col + 1].down != normal && puzzle[row + 1][col + 1].down != now) {
              rtValue.add([row + 1, col + 1, "down"]);
            }
          }
          break;
      }
    }
    else {
      switch(pos) {
        case "up":
          if (puzzle[row][col].left != normal && puzzle[row][col].left != now) {
            rtValue.add([row, col, "left"]);
          }
          if (puzzle[row][col].right != normal && puzzle[row][col].right != now) {
            rtValue.add([row, col, "right"]);
          }
          if (puzzle[row][col + 1].up != normal && puzzle[row][col + 1].up != now) {
            rtValue.add([row, col + 1, "up"]);
          }
          break;
        case "down":
          if (puzzle[row][col].left != normal && puzzle[row][col].left != now) {
            rtValue.add([row, col, "left"]);
          }
          if (puzzle[row][col].right != normal && puzzle[row][col].right != now) {
            rtValue.add([row, col, "right"]);
          }
          if (puzzle[row + 1][col].left != normal && puzzle[row + 1][col].left != now) {
            rtValue.add([row + 1, col, "left"]);
          }
          if (puzzle[row + 1][col].right != normal && puzzle[row + 1][col].right != now) {
            rtValue.add([row + 1, col, "right"]);
          }
          if (puzzle[row][col + 1].down != normal && puzzle[row][col + 1].down != now) {
            rtValue.add([row, col + 1, "down"]);
          }
          break;
        case "left":
          if (puzzle[row][col].up != normal && puzzle[row][col].up != now) {
            rtValue.add([row, col, "up"]);
          }
          if (puzzle[row][col].down != normal && puzzle[row][col].down != now) {
            rtValue.add([row, col, "down"]);
          }
          if (puzzle[row + 1][col].left != normal && puzzle[row + 1][col].left != now) {
            rtValue.add([row + 1, col, "left"]);
          }
          break;
        case "right":
          if (puzzle[row][col].up != normal && puzzle[row][col].up != now) {
            rtValue.add([row, col, "up"]);
          }
          if (puzzle[row][col].down != normal && puzzle[row][col].down != now) {
            rtValue.add([row, col, "down"]);
          }
          if (puzzle[row][col + 1].up != normal && puzzle[row][col + 1].up != now) {
            rtValue.add([row, col + 1, "up"]);
          }
          if (puzzle[row][col + 1].down != normal && puzzle[row][col + 1].down != now) {
            rtValue.add([row, col + 1, "down"]);
          }
          if (puzzle[row + 1][col].right != normal && puzzle[row + 1][col].right != now) {
            rtValue.add([row + 1, col, "right"]);
          }
          break;
      }
    }

    //print("end of getOldColorList : $rtValue");
    //return rtValue;
    return getContinueOld(rtValue);
  }

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
      else if (col != 0) {
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
      else if (row != 0) {
        switch (pos) {
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

  void clearLineForStart() {
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
  }


  void puzzleToWidget() {
    //puzzle = initSquarePuzzle(answer[0].length, answer.length ~/ 2);
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

    squareField = columnChildren;
    notifyListeners();
  }
}