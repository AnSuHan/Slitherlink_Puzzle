import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:slitherlink_project/MakePuzzle/ReadSquare.dart';

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
  static late List<List<int>> answer;
  static late List<List<int>> submit;
  //UI
  static bool showAppbar = false;
  static GameUI ui = GameUI();
  //save and load
  static ReadSquare readSquare = ReadSquare();

  @override
  void initState() {
    super.initState();
    _provider = SquareProvider();
    loadPuzzle();
  }

  void loadPuzzle() async {
    answer = await readSquare.loadPuzzle("square");
    submit = List.generate(answer.length, (row) =>
        List.filled(answer[row].length, 0),
    );

    squareField = await buildSquarePuzzleAnswer(answer);
    _provider.setSquareField(squareField);
  }

  void reload() async {
    List<List<int>> data = await readSquare.loadPuzzle("square");
    List<Widget> newSquareField = await buildSquarePuzzleAnswer(data);
    submit = List.generate(answer.length, (row) =>
        List.filled(answer[row].length, 0),
    );

    setState(() {
      squareField = newSquareField;
      _provider.setSquareField(squareField);
    });
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider( // ChangeNotifierProvider 사용
      create: (context) => _provider, // 여기서 YourChangeNotifierClass는 사용자가 만든 ChangeNotifier 클래스입니다.
      child: Consumer<SquareProvider>(
        builder: (context, provider, child) {
          screenSize = MediaQuery.of(context).size;
          ui.setScreenSize(screenSize);

          return Scaffold(
            appBar: !showAppbar ? null : ui.getGameAppBar(context),
            body: GestureDetector(
              onTap: () {
                setState(() {
                  showAppbar = !showAppbar;
                });
              },
              //interactiveViewer로 변경
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
                    //필드는 앱 바를 통해 상태가 변경될 수 있으므로
                    //provider와 ChangeNotifier를 통해 접근
                    children: _provider.getSquareField(),
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
          temp.add(SquareBox(isFirstRow: true, isFirstColumn: true));
        } else if(i == 0) {
          temp.add(SquareBox(isFirstRow: true));
        } else if(j == 0) {
          temp.add(SquareBox(isFirstColumn: true));
        } else {
          temp.add(SquareBox());
        }
      }
      puzzle.add(temp);
    }

    return puzzle;
  }

  //배열에 담긴 위젯을 column에 담아서 widget으로 반환
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

  static Future<List<Widget>> buildSquarePuzzleAnswer(List<List<int>> answer) async {
    //resize puzzle
    if(answer.isEmpty) {
      print("answer is empty");
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
            //cprint(lineType != 0, "call down");
          } else {
            if(j == 0) {
              puzzle[i ~/ 2][0].left = lineType;
              //cprint(lineType != 0, "call left");
            } else {
              puzzle[i ~/ 2][0].right = lineType;
              //cprint(lineType != 0, "call right");
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

  static void checkCompletePuzzle() {
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
    //UserInfo.ContinuePuzzle();
  }

  void applyLabel(List<List<int>> data) async {
    answer = await readSquare.loadPuzzle("square");
    submit = data;

    squareField = await buildSquarePuzzleAnswer(answer);
    //apply submit data to squareField
    innerApplyLabel();

    _provider.setSquareField(squareField);
  }

  void innerApplyLabel() {
    for (int i = 0; i < puzzle.length; i++) {
      for (int j = 0; j < puzzle[i].length; j++) {
        if (i != 0 && j != 0) {   //problem //1,1 => 3,2 4,1  //2,2 => 5,3 6,2
          puzzle[i][j].down = submit[i * 2 + 2][j];
          puzzle[i][j].right = submit[i * 2 + 1][j + 1];
        } else if (i == 0 && j != 0) {
          puzzle[i][j].up = submit[i][j];
          puzzle[i][j].down = submit[i + 2][j];
          puzzle[i][j].right = submit[i + 1][j + 1];
        } else if (i != 0 && j == 0) { //1,0 => 3,0 3,1 4,0  //2,0 => 5,0 5,1 6,0
          puzzle[i][j].down = submit[i * 2 + 2][j];
          puzzle[i][j].left = submit[i * 2 + 1][j];
          puzzle[i][j].right = submit[i * 2 + 1][j + 1];
        } else if (i == 0 && j == 0) {
          puzzle[i][j].up = submit[i][j];
          puzzle[i][j].down = submit[i + 2][j];
          puzzle[i][j].left = submit[i + 1][j];
          puzzle[i][j].right = submit[i + 1][j + 1];
        }
      }
    }
  }

  static List<List<SquareBox>> getPuzzle() {
    return puzzle;
  }
}