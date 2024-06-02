import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  final SquareProvider _provider = SquareProvider();

  //check complete puzzle;
  static late List<List<int>> answer;
  static late List<List<int>> submit;
  //save and load progress statue
  static late List<List<List<int>>> saveStatue;
  //UI
  static bool showAppbar = false;
  static GameUI ui = GameUI();

  @override
  void initState() {
    super.initState();
    _setupKeyListener();
    _provider.resetPuzzle();
    loadPuzzle();
  }

  void loadPuzzle() async {
    answer = await ReadSquare().loadPuzzle("square");
    submit = List.generate(answer.length, (row) =>
        List.filled(answer[row].length, 0),
    );

    squareField = buildSquarePuzzle(answer[0].length, answer.length ~/ 2);
    List<Widget> newSquareField = await buildSquarePuzzleAnswer(answer);

    setState(() {
      squareField = newSquareField;
    });
  }

  void _setupKeyListener() {
    RawKeyboard.instance.addListener((RawKeyEvent event) async {
      _handleKeyEvent(event.logicalKey.debugName);
    });
  }

  //separate method for running in Android(debug)
  void _handleKeyEvent(String? keyName) async {
    if (keyName == "Key S") {
      ReadSquare().savePuzzle("square");
      print("Save complete");
    } else if (keyName == "Key R") {
      List<List<int>> data = await ReadSquare().loadPuzzle("square");
      List<Widget> newSquareField = await buildSquarePuzzleAnswer(data);

      setState(() {
        squareField = newSquareField;
      });
    } else if (keyName == "Key P") {
      ReadSquare().printData();
    } else if (keyName == "Key A") {
      List<List<int>> apply = await ReadSquare().loadPuzzle("square");
      List<Widget> newSquareField = await buildSquarePuzzleAnswer(apply);

      setState(() {
        squareField = newSquareField;
      });
    } else if (keyName == "Key C") {
      setState(() {
        squareField = buildSquarePuzzle(puzzleWidth, puzzleHeight);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider( // ChangeNotifierProvider 사용
      create: (context) => SquareProvider(), // 여기서 YourChangeNotifierClass는 사용자가 만든 ChangeNotifier 클래스입니다.
      child: Consumer<SquareProvider>(
        builder: (context, provider, child) {
          // Build your UI based on the provider's state
          return MaterialApp(  // Replace YourWidget with your actual widget
            home: Builder(
              builder: (context) {
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
                          children: SquareProvider().getSquareField(),
                        ),
                      ),
                    ),
                  ),
                );
              },
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
    /*
    //정상
    for(int i = 0 ; i < answer.length ; i++) {
      for(int j = 0 ; j < answer[i].length ; j++) {
        print("answer $i $j = ${answer[i][j]}");
      }
    }
     */

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

  //set(0,0) & find num 0 in all field
  static void setDefaultLineStep1(List<List<SquareBox>> puzzle) {
    int inValidColor = -2;
    List<List<int>> points = [];

    //set (0,0)
    if(puzzle[0][0].num == 0) {
      puzzle[0][0].up = inValidColor;
      puzzle[0][0].down = inValidColor;
      puzzle[0][0].left = inValidColor;
      puzzle[0][0].right = inValidColor;

      points.add([0,0]);
    }
    else if(puzzle[0][0].num == 1) {
      puzzle[0][0].up = inValidColor;
      puzzle[0][0].down = 0;
      puzzle[0][0].left = inValidColor;
      puzzle[0][0].right = 0;

      points.add([0,0]);
    }
    else {
      puzzle[0][0].up = 0;
      puzzle[0][0].down = 0;
      puzzle[0][0].left = 0;
      puzzle[0][0].right = 0;
    }

    for(int i = 0 ; i < puzzle.length ; i++) {
      for(int j = 0 ; j < puzzle[i].length ; j++) {
        if(puzzle[i][j].num == 0) {
          if(i != 0 && j != 0) {
            puzzle[i - 1][j].down = inValidColor;
            puzzle[i][j].down = inValidColor;
            puzzle[i][j - 1].right = inValidColor;
            puzzle[i][j].right = inValidColor;

            points.add([i,j]);
          }
          //first row
          else if(i == 0 && j != 0) {
            puzzle[i][j].up = inValidColor;
            puzzle[i][j].down = inValidColor;
            puzzle[i][j - 1].right = inValidColor;
            puzzle[i][j].right = inValidColor;

            points.add([i,j]);
          }
          //first col
          else if(i != 0 && j == 0) {
            puzzle[i - 1][j].down = inValidColor;
            puzzle[i][j].down = inValidColor;
            puzzle[i][j].left = inValidColor;
            puzzle[i][j].right = inValidColor;

            points.add([i,j]);
          }
          else {
            //(0,0) is already set
          }
        }
      }
    }

    setDefaultLineStep2(puzzle, points);
  }

  static void setDefaultLineStep2(List<List<SquareBox>> puzzle, List<List<int>> points) {
    int inValidColor = -2;
    int startRow = 0, startCol = 1;
    int endRow = 1, endCol = 0;
    List<List<int>> newPoints = [];

    for(int i = 0 ; i < points.length ; i++) {
      //check 2 dir
      if(points[i] == [0,0] || points[i] == [puzzle.length - 1,0]
          || points[i] == [0, puzzle[puzzle.length - 1].length - 1]
          || points[i] == [puzzle.length - 1, puzzle[puzzle.length - 1].length - 1]) {
        //down, right
        if(points[i] == [0,0]) {
          if(puzzle[0][0].right == inValidColor) {
            puzzle[0][1].up == inValidColor;
          }
          if(puzzle[0][0].left == inValidColor && puzzle[0][0].down == inValidColor) {
            puzzle[0][1].left == inValidColor;
          }
        }
        //up, right
        else if(points[i] == [puzzle.length - 1,0]) {

        }
        //down, left
        else if(points[i] == [0, puzzle[puzzle.length - 1].length - 1]) {

        }
        //up, left
        else {

        }
      }
      //check 3 dir
      else if(false) {

      }
    }
  }

  //set (0,0) & row 0's up & col 0's left
  static void setDefaultLineStep123(List<List<SquareBox>> puzzle) {
    int inValidColor = -2;
    int cntEdge = 0;

    //set (0,0)
    if(puzzle[0][0].num == 0) {
      puzzle[0][0].up = inValidColor;
      puzzle[0][0].down = inValidColor;
      puzzle[0][0].left = inValidColor;
      puzzle[0][0].right = inValidColor;
    }
    else if(puzzle[0][0].num == 1) {
      puzzle[0][0].up = inValidColor;
      puzzle[0][0].down = 0;
      puzzle[0][0].left = inValidColor;
      puzzle[0][0].right = 0;
    }
    else {
      puzzle[0][0].up = 0;
      puzzle[0][0].down = 0;
      puzzle[0][0].left = 0;
      puzzle[0][0].right = 0;
    }

    int a = 0, b = 1;
    int remainEdge = numOfEdge;
    while(true) {
      for(int i = a ; i < puzzle.length ; i++) {
        //row axis's up (left to right)
        for(int j = b ; j < puzzle[i].length ; j++) {
          if(puzzle[i][j].num == 0) {
            puzzle[i][j].up = inValidColor;
            puzzle[i][j].down = inValidColor;
            puzzle[i][j - 1].right = inValidColor;
            puzzle[i][j].right = inValidColor;
          }
          else {
            if(i >= 1) {
              if(puzzle[i][j - 1].right == inValidColor &&
                  puzzle[i][j - 1].up == inValidColor &&
                  puzzle[i - 1][j].right == inValidColor) {
                puzzle[i][j].up = inValidColor;
                remainEdge--;
                print("set [$i][$j].up with left to right -1");
              }
            }
            else {  // i < 1
              if(puzzle[i][j - 1].right == inValidColor &&
                  puzzle[i][j - 1].up == inValidColor) {
                puzzle[i][j].up = inValidColor;
                remainEdge--;
                print("set [$i][$j].up with left to right -1");
              }
            }
          }
        }
        //row axis's up (right to left)
        for(int j = puzzle[i].length - 1 ; j >= b ; j--) {
          if(puzzle[i][j].num <= 1) {
            //check j+1's left
            if(j < puzzle[i].length - 1) {
              if(puzzle[i][j + 1].left == inValidColor) {
                puzzle[i][j].up = inValidColor;
              }
            }
            //j+1's left is not exist
            else {
              puzzle[i][j].up = inValidColor;
            }
          }
          else {
            puzzle[i][j].up = 0;
          }


          if(j < puzzle[i].length - 1) {
            if(puzzle[i][j].num <= 1) {
              puzzle[i][j].up = inValidColor;
            }
            else {

            }
          }
          else {

          }

          if(puzzle[i][j - 1].right == inValidColor) {
            puzzle[i][j].up = inValidColor;
            remainEdge--;
            print("set [$i][$j].up with right to left -1");
          }
        }
        /*
        //row axis's left and right
        for(int j = b ; j < puzzle[i].length ; j++) {
          //judge left
          if(puzzle[i][j - 1].up == inValidColor && puzzle[i][j].up == inValidColor) {
            puzzle[i][j].left = inValidColor;
            print("set [$i][$j].left -1");
          }
          //judge right
          if(j < puzzle[i].length) {
            if(puzzle[i][j].up == inValidColor && puzzle[i][j + 1].up == inValidColor) {
              puzzle[i][j].right = inValidColor;
              print("set [$i][$j].right -1");
            }
          }
          else {
            if(puzzle[i][j].up == inValidColor) {
              puzzle[i][j].right = inValidColor;
              print("set [$i][$j].right -1");
            }
          }

        }
         */

        break;
      }

      break;
      //const col axis
    }

    /*
    for(int i = 0 ; i < puzzle.length ; i++) {
      for (int j = 0; j < puzzle[i].length; j++) {
        if(i != 0 && j != 0) {

        }
        //set col 0's left
        else if(i != 0 && j == 0) {

        }
        //set row 0's up
        else if(i == 0 && j != 0) {
          if(puzzle[i][j].num == 0) {
            puzzle[i][j].up = inValidColor;
            puzzle[i][j].down = inValidColor;
            puzzle[i][j].right = inValidColor;
          }
          else {
            if(puzzle[i][j - 1].right == -1) {
              cntEdge++;
            }
            if()
          }
        }
        else {
          if(puzzle[i][j].num == 0) {
            puzzle[i][j].up = inValidColor;
            puzzle[i][j].down = inValidColor;
            puzzle[i][j].left = inValidColor;
            puzzle[i][j].right = inValidColor;
          }
          else {
            if(puzzle[i][j].num == 1) {
              puzzle[i][j].up = inValidColor;
              puzzle[i][j].left = inValidColor;
              continue;
            }

            puzzle[i][j].up = 0;
            puzzle[i][j].down = 0;
            puzzle[i][j].left = 0;
            puzzle[i][j].right = 0;
          }
        }
      }
    }
     */
  }

  //set line with condition
  static void setDefaultLine(List<List<SquareBox>> puzzle) {
    int count = 0;

    for(int i = 0 ; i < puzzle.length ; i++) {
      for(int j = 0 ; j < puzzle[i].length ; j++) {
        count = 0;

        if(i != 0 && j != 0) {
          puzzle[i][j].down = 0;
          puzzle[i][j].right = 0;
        }
        //set col 0's left
        else if(i != 0 && j == 0) {
          if(puzzle[i][j].num == 0) {
            puzzle[i][j].down = 0;
            puzzle[i][j].left = 0;
            puzzle[i][j].right = 0;
            continue;
          }
          else {
            if(puzzle[i - 1][j].down == -1) {
              puzzle[i][j].left = -1;
            }
          }
        }
        //set row 0's up
        else if(i == 0 && j != 0) {
          if(puzzle[i][j].num == 0) {
            puzzle[i][j].up = -1;
            puzzle[i][j].down = -1;
            puzzle[i][j].right = -1;
            continue;
          }
          else {
            if(puzzle[i][j - 1].right == -1) {
              count++;
            }
            //already set
            if(numOfEdge == puzzle[i][j].num + count) {
              puzzle[i][j].up = 0;
              puzzle[i][j].down = 0;
              puzzle[i][j].right = 0;
            }
            //need setting -1
            else {
              //set `up`
              if(puzzle[i][j - 1].right == -1) {
                puzzle[i][j].up = -1;
              }
              else {
                puzzle[i][j].up = 0;
              }
            }
          }
        }
        else {
          if(puzzle[i][j].num == 0) {
            puzzle[i][j].up = -1;
            puzzle[i][j].down = -1;
            puzzle[i][j].left = -1;
            puzzle[i][j].right = -1;
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

  static void cprint(bool condition, String text) {
    if(condition) {
      print(text);
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
  }

  void resetPuzzle() async {
    _provider.resetPuzzle();
  }

  static List<List<SquareBox>> getPuzzle() {
    return puzzle;
  }
}