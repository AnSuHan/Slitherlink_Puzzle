// ignore_for_file: file_names
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:slitherlink_project/MakePuzzle/ReadSquare.dart';

import '../ThemeColor.dart';
import '../widgets/GameUI.dart';
import 'GameSceneSquare.dart';
import '../widgets/SquareBox.dart';

class GameSceneStateSquare extends State<GameSceneSquare> {
  late Size screenSize;
  static const puzzleWidth = 20;    //num of Square - horizontal
  static const puzzleHeight = 10;   //num of Square - vertical
  static const numOfEdge = 4;
  static late List<Widget> squareField;
  static late List<List<SquareBox>> puzzle;
  var findCycle = false;
  bool isDebug = false;

  //provider for using setState in other class
  static SquareProvider _provider = SquareProvider();

  //check complete puzzle;
  static bool isComplete = false;
  bool isContinue;
  String loadKey;
  static late List<List<int>> answer;
  static late List<List<int>> submit;
  //UI
  static bool showAppbar = false;
  static GameUI ui = GameUI();
  Map<String, Color> settingColor = ThemeColor().getColor();
  //save and load
  static ReadSquare readSquare = ReadSquare();

  GameSceneStateSquare({this.isContinue = false, this.loadKey = ""});

  @override
  void initState() {
    super.initState();
    _provider = SquareProvider();
    loadPuzzle();
  }

  void loadPuzzle() async {
    //print("loadKey : ${widget.loadKey}");
    isComplete = false;

    if(widget.isContinue) {
      //answer = await readSquare.loadPuzzle(MainUI.getProgressKey());
      answer = await readSquare.loadPuzzle(widget.loadKey);

      submit = await readSquare.loadPuzzle("${widget.loadKey}_continue");
    }
    else {
      answer = await readSquare.loadPuzzle(widget.loadKey);

      submit = List.generate(answer.length, (row) =>
          List.filled(answer[row].length, 0),
      );
    }

    squareField = await buildSquarePuzzleAnswer(answer, isContinue: widget.isContinue);
    _provider.setSquareField(squareField);
  }

  void restart() async {
    submit = List.generate(answer.length, (row) =>
        List.filled(answer[row].length, 0),
    );
    squareField = await buildSquarePuzzleAnswer(answer);
    _provider.setSquareField(squareField);
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider( // ChangeNotifierProvider 사용
      create: (context) => _provider, //ChangeNotifier class
      child: Consumer<SquareProvider>(
        builder: (context, provider, child) {
          screenSize = MediaQuery.of(context).size;
          ui.setScreenSize(screenSize);

          return Scaffold(
            appBar: !showAppbar ? null : ui.getGameAppBar(context, settingColor["appBar"]!, settingColor["appIcon"]!),
            body: GestureDetector(
              onTap: () {
                setState(() {
                  showAppbar = !showAppbar;
                });
              },
              child: AbsorbPointer(
                absorbing: isComplete,
                child: Container(
                  color: settingColor["background"],
                  child: InteractiveViewer(
                    boundaryMargin: EdgeInsets.symmetric(
                      horizontal: screenSize.width * 0.4,
                      vertical: screenSize.height * 0.4,
                    ),
                    constrained: false,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 20),
                      child: Column(
                        //provider와 ChangeNotifier를 통해 접근
                        children: _provider.getSquareField(),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  static List<List<SquareBox>> initSquarePuzzle(width, height) {
    puzzle = [];
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

  //List<List<SquareBox>> to List<Widget>
  static List<Widget> buildSquarePuzzle(width, height) {
    List<List<SquareBox>> puzzle = initSquarePuzzle(width, height);
    //print("puzzle row ${puzzle.length}, col ${puzzle[0].length}");
    List<Widget> columnChildren = [];

    for (int i = 0; i < height; i++) {
      List<Widget> rowChildren = [];
      for (int j = 0; j < width; j++) {
        rowChildren.add(puzzle[i][j]);
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

  static Future<List<Widget>> buildSquarePuzzleAnswer(List<List<int>> answer, {bool isContinue = false}) async {
    //resize puzzle
    if(answer.isEmpty) {
      //print("answer is empty");
      return Future.value([]);
    }
    List<List<SquareBox>> puzzle = initSquarePuzzle(answer[0].length, answer.length ~/ 2);
    //print("puzzle SquareBox => row ${puzzle.length}, col ${puzzle[0].length}");
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

  static void setNumWithAnswer(List<List<SquareBox>> puzzle) {
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

  //answer is key-value pair
  static void applyUIWithAnswer(List<List<SquareBox>> puzzle, List<List<int>> answer) {
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

  static void clearLineForStart() {
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

  static void checkCompletePuzzle(BuildContext context) {
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
    print("complete puzzle!");
    //clear continue puzzle
    isComplete = true;
    showComplete(context);
    //UserInfo.ContinuePuzzle();
  }

  static void showComplete(BuildContext context) {
    print("call showComplete");
    // Show AlertDialog if isComplete is true
    WidgetsBinding.instance!.addPostFrameCallback((_) {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Game Completed'),
            content: const Text('Congratulations! You have completed the game.'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();  //close popup
                  Navigator.of(context).pop();  //close GameScene
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
    squareField = await buildSquarePuzzleLabel(answer, submit);
    _provider.setSquareField(squareField);
  }

  static Future<List<Widget>> puzzleToSquareField() async {
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

  static Future<List<Widget>> buildSquarePuzzleLabel(List<List<int>> answer, List<List<int>> submit) async {
    //resize puzzle
    if(answer.isEmpty) {
      //print("answer is empty");
      return Future.value([]);
    }
    List<List<SquareBox>> puzzle = initSquarePuzzle(answer[0].length, answer.length ~/ 2);
    //print("puzzle SquareBox => row ${puzzle.length}, col ${puzzle[0].length}");
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

  ///SquareBox List's index
  static Set<Color> getNearColor(int row, int col, String pos) {
    Set<Color> use = {};

    if(row != 0 && col != 0) {
      switch(pos) {
        case "down":
          use.add(puzzle[row][col - 1].colorDown);
          use.add(puzzle[row][col - 1].colorRight);
          use.add(puzzle[row][col].colorRight);

          if(puzzle.length > row + 1) {
            use.add(puzzle[row + 1][col - 1].colorRight);
            use.add(puzzle[row + 1][col].colorRight);
          }
          if(puzzle[row].length > col + 1) {
            use.add(puzzle[row][col + 1].colorDown);
          }
          break;
        case "right":
          use.add(puzzle[row - 1][col].colorRight);
          use.add(puzzle[row - 1][col].colorDown);
          use.add(puzzle[row][col].colorDown);

          if(puzzle[row].length > col + 1) {
            use.add(puzzle[row - 1][col + 1].colorUp);
            use.add(puzzle[row][col + 1].colorUp);
          }
          if(puzzle.length > row + 1) {
            use.add(puzzle[row + 1][col].colorRight);
          }
          break;
      }
    }
    else if(col != 0) {
      switch(pos) {
        case "up":
          use.add(puzzle[row][col - 1].colorUp);
          use.add(puzzle[row][col - 1].colorRight);
          use.add(puzzle[row][col].colorRight);

          if(puzzle[row].length > col + 1) {
            use.add(puzzle[row][col + 1].colorUp);
          }

          break;
        case "down":
          use.add(puzzle[row][col - 1].colorDown);
          use.add(puzzle[row][col - 1].colorRight);
          use.add(puzzle[row][col].colorRight);

          if(puzzle[row].length > col + 1) {
            use.add(puzzle[row][col + 1].colorDown);
          }
          if(puzzle.length > row + 1) {
            use.add(puzzle[row + 1][col - 1].colorRight);
            use.add(puzzle[row + 1][col].colorRight);
          }
          break;
        case "right":
          use.add(puzzle[row][col].colorUp);
          use.add(puzzle[row][col].colorDown);

          if(puzzle[row].length > col + 1) {
            use.add(puzzle[row][col + 1].colorUp);
            use.add(puzzle[row][col + 1].colorDown);
          }
          if(puzzle.length > row + 1) {
            use.add(puzzle[row + 1][col].colorRight);
          }
          break;
      }
    }
    else if(row != 0) {
      switch(pos) {
        case "down":
          use.add(puzzle[row][col].colorLeft);
          use.add(puzzle[row][col].colorRight);
          use.add(puzzle[row + 1][col].colorLeft);
          use.add(puzzle[row + 1][col].colorRight);
          use.add(puzzle[row][col + 1].colorDown);
          break;
        case "left":
          use.add(puzzle[row - 1][col].colorLeft);
          use.add(puzzle[row - 1][col].colorDown);
          use.add(puzzle[row][col].colorDown);

          if(puzzle.length > row + 1) {
            use.add(puzzle[row + 1][col].colorLeft);
          }
          break;
        case "right":
          use.add(puzzle[row - 1][col].colorRight);
          use.add(puzzle[row - 1][col].colorDown);
          use.add(puzzle[row - 1][col + 1].colorDown);
          use.add(puzzle[row][col].colorDown);

          if(puzzle.length > row + 1) {
            use.add(puzzle[row + 1][col].colorRight);
            use.add(puzzle[row + 1][col + 1].colorDown);
          }
          break;
      }
    }
    else {
      switch(pos) {
        case "up":
          use.add(puzzle[row][col].colorLeft);
          use.add(puzzle[row + 1][col].colorUp);

          print("use up $use");
          break;
        case "down":
          use.add(puzzle[row][col].colorLeft);
          use.add(puzzle[row][col].colorRight);
          use.add(puzzle[row + 1][col].colorLeft);
          use.add(puzzle[row + 1][col].colorRight);
          use.add(puzzle[row][col + 1].colorDown);
          print("use down $use");
          break;
        case "left":
          use.add(puzzle[row][col].colorUp);
          use.add(puzzle[row][col].colorDown);
          use.add(puzzle[row + 1][col].colorLeft);
          print("use left $use");
          break;
        case "right":
          use.add(puzzle[row][col].colorUp);
          use.add(puzzle[row][col].colorDown);
          use.add(puzzle[row][col + 1].colorUp);
          use.add(puzzle[row][col + 1].colorDown);
          use.add(puzzle[row + 1][col].colorRight);

          print("use right $use");
          break;
      }
    }

    print("use : $use");
    return use;
  }

  static List<List<SquareBox>> getPuzzle() {
    return puzzle;
  }
}