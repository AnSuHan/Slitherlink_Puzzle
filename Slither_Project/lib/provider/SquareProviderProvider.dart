import 'package:flutter/material.dart';

import '../Scene/GameSceneSquareProvider.dart';
import '../ThemeColor.dart';
import '../widgets/SquareBoxProvider.dart';

class SquareProviderProvider with ChangeNotifier {
  SquareProviderProvider({isContinue = false});

  List<Widget> squareField = [];
  List<List<SquareBoxProvider>> puzzle = [];
  late GameSceneStateSquareProvider gameField; // GameSceneStateSquareProvider 인스턴스 추가

  late List<List<int>> answer;
  late List<List<int>> submit;
  bool isContinue = false;

  ///Init
  void init() async {
    print("call init");
    puzzle = initSquarePuzzle(answer[0].length, answer.length ~/ 2);
    squareField = await buildSquarePuzzleAnswer(answer, isContinue: isContinue);
  }

  List<List<SquareBoxProvider>> initSquarePuzzle(width, height) {
    List<List<SquareBoxProvider>> puzzle = [];
    List<SquareBoxProvider> temp = [];
    int i, j;

    for(i = 0 ; i < height ; i++) {
      temp = [];

      for(j = 0 ; j < width ; j++) {
        if(i == 0 && j == 0) {
          temp.add(SquareBoxProvider(isFirstRow: true, isFirstColumn: true, row: i, column: j,));
        } else if(i == 0) {
          temp.add(SquareBoxProvider(isFirstRow: true, row: i, column: j,));
        } else if(j == 0) {
          temp.add(SquareBoxProvider(isFirstColumn: true, row: i, column: j,));
        } else {
          temp.add(SquareBoxProvider(row: i, column: j,));
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

  //i, j의 범위를 변경하였을 때는 정상적으로 맵의 크기가 변경되는 것으로 보아
  //다른 부분이 문제
  void buildSquarePuzzleColor({BuildContext? context}) {
    List<Widget> columnChildren = [];

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
  }

  void setNumWithAnswer(List<List<SquareBoxProvider>> puzzle) {
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
  void applyUIWithAnswer(List<List<SquareBoxProvider>> puzzle, List<List<int>> answer) {
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

  void checkCompletePuzzle(BuildContext context) {
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
    //isComplete = true;
    showComplete(context);
    //UserInfo.ContinuePuzzle();
  }

  void showComplete(BuildContext context) {
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
    List<List<SquareBoxProvider>> puzzle = initSquarePuzzle(answer[0].length, answer.length ~/ 2);
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

  ///SquareBoxProvider List's index
  Set<Color> getNearColor(int row, int col, String pos) {
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
            use.add(puzzle[row - 1][col + 1].colorDown);
            use.add(puzzle[row][col + 1].colorDown);
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
          use.add(puzzle[row][col].colorRight);
          use.add(puzzle[row + 1][col].colorUp);
          break;
        case "down":
          use.add(puzzle[row][col].colorLeft);
          use.add(puzzle[row][col].colorRight);
          use.add(puzzle[row + 1][col].colorLeft);
          use.add(puzzle[row + 1][col].colorRight);
          use.add(puzzle[row][col + 1].colorDown);
          break;
        case "left":
          use.add(puzzle[row][col].colorUp);
          use.add(puzzle[row][col].colorDown);
          use.add(puzzle[row + 1][col].colorLeft);
          break;
        case "right":
          use.add(puzzle[row][col].colorUp);
          use.add(puzzle[row][col].colorDown);
          use.add(puzzle[row][col + 1].colorUp);
          use.add(puzzle[row][col + 1].colorDown);
          use.add(puzzle[row + 1][col].colorRight);
          break;
      }
    }

    use.remove(const Color(0xff000000));
    return use;
  }

  List<dynamic> getOldColorList(int row, int col, String pos, Color now) {
    //[row, col, pos]
    List<dynamic> rtValue = [];
    Color normal = ThemeColor().getLineColor(type: 0);

    //same as getNearColor except for comparing color
    if(row != 0 && col != 0) {
      switch(pos) {
        case "down":
        //use.add(puzzle[row][col - 1].colorDown);
          if(puzzle[row][col - 1].colorDown != normal && puzzle[row][col - 1].colorDown != now) {
            rtValue.add([row, col - 1, "down"]);
          }
          if (puzzle[row][col - 1].colorRight != normal && puzzle[row][col - 1].colorRight != now) {
            rtValue.add([row, col - 1, "right"]);
          }
          if (puzzle[row][col].colorRight != normal && puzzle[row][col].colorRight != now) {
            rtValue.add([row, col, "right"]);
          }
          if (puzzle.length > row + 1) {
            if (puzzle[row + 1][col - 1].colorRight != normal && puzzle[row + 1][col - 1].colorRight != now) {
              rtValue.add([row + 1, col - 1, "right"]);
            }
            if (puzzle[row + 1][col].colorRight != normal && puzzle[row + 1][col].colorRight != now) {
              rtValue.add([row + 1, col, "right"]);
            }
          }
          if (puzzle[row].length > col + 1) {
            if (puzzle[row][col + 1].colorDown != normal && puzzle[row][col + 1].colorDown != now) {
              rtValue.add([row, col + 1, "down"]);
            }
          }
          break;
        case "right":
          if (puzzle[row - 1][col].colorRight != normal && puzzle[row - 1][col].colorRight != now) {
            rtValue.add([row - 1, col, "right"]);
          }
          if (puzzle[row - 1][col].colorDown != normal && puzzle[row - 1][col].colorDown != now) {
            rtValue.add([row - 1, col, "down"]);
          }
          if (puzzle[row][col].colorDown != normal && puzzle[row][col].colorDown != now) {
            rtValue.add([row, col, "down"]);
          }
          if (puzzle[row].length > col + 1) {
            if (puzzle[row - 1][col + 1].colorDown != normal && puzzle[row - 1][col + 1].colorDown != now) {
              rtValue.add([row - 1, col + 1, "down"]);
            }
            if (puzzle[row][col + 1].colorDown != normal && puzzle[row][col + 1].colorDown != now) {
              rtValue.add([row, col + 1, "down"]);
            }
          }
          if (puzzle.length > row + 1) {
            if (puzzle[row + 1][col].colorRight != normal && puzzle[row + 1][col].colorRight != now) {
              rtValue.add([row + 1, col, "right"]);
            }
          }
          break;
      }
    }
    else if (col != 0) {
      switch (pos) {
        case "up":
          if (puzzle[row][col - 1].colorUp != normal && puzzle[row][col - 1].colorUp != now) {
            rtValue.add([row, col - 1, "up"]);
          }
          if (puzzle[row][col - 1].colorRight != normal && puzzle[row][col - 1].colorRight != now) {
            rtValue.add([row, col - 1, "right"]);
          }
          if (puzzle[row][col].colorRight != normal && puzzle[row][col].colorRight != now) {
            rtValue.add([row, col, "right"]);
          }
          if (puzzle[row].length > col + 1) {
            if (puzzle[row][col + 1].colorUp != normal && puzzle[row][col + 1].colorUp != now) {
              rtValue.add([row, col + 1, "up"]);
            }
          }
          break;
        case "down":
          if (puzzle[row][col - 1].colorDown != normal && puzzle[row][col - 1].colorDown != now) {
            rtValue.add([row, col - 1, "down"]);
          }
          if (puzzle[row][col - 1].colorRight != normal && puzzle[row][col - 1].colorRight != now) {
            rtValue.add([row, col - 1, "right"]);
          }
          if (puzzle[row][col].colorRight != normal && puzzle[row][col].colorRight != now) {
            rtValue.add([row, col, "right"]);
          }
          if (puzzle[row].length > col + 1) {
            if (puzzle[row][col + 1].colorDown != normal && puzzle[row][col + 1].colorDown != now) {
              rtValue.add([row, col + 1, "down"]);
            }
          }
          if (puzzle.length > row + 1) {
            if (puzzle[row + 1][col - 1].colorRight != normal && puzzle[row + 1][col - 1].colorRight != now) {
              rtValue.add([row + 1, col - 1, "right"]);
            }
            if (puzzle[row + 1][col].colorRight != normal && puzzle[row + 1][col].colorRight != now) {
              rtValue.add([row + 1, col, "right"]);
            }
          }
          break;
        case "right":
          if (puzzle[row][col].colorUp != normal && puzzle[row][col].colorUp != now) {
            rtValue.add([row, col, "up"]);
          }
          if (puzzle[row][col].colorDown != normal && puzzle[row][col].colorDown != now) {
            rtValue.add([row, col, "down"]);
          }
          if (puzzle[row].length > col + 1) {
            if (puzzle[row][col + 1].colorUp != normal && puzzle[row][col + 1].colorUp != now) {
              rtValue.add([row, col + 1, "up"]);
            }
            if (puzzle[row][col + 1].colorDown != normal && puzzle[row][col + 1].colorDown != now) {
              rtValue.add([row, col + 1, "down"]);
            }
          }
          if (puzzle.length > row + 1) {
            if (puzzle[row + 1][col].colorRight != normal && puzzle[row + 1][col].colorRight != now) {
              rtValue.add([row + 1, col, "right"]);
            }
          }
          break;
      }
    }
    else if (row != 0) {
      switch (pos) {
        case "down":
          if (puzzle[row][col].colorLeft != normal && puzzle[row][col].colorLeft != now) {
            rtValue.add([row, col, "left"]);
          }
          if (puzzle[row][col].colorRight != normal && puzzle[row][col].colorRight != now) {
            rtValue.add([row, col, "right"]);
          }
          if (puzzle[row + 1][col].colorLeft != normal && puzzle[row + 1][col].colorLeft != now) {
            rtValue.add([row + 1, col, "left"]);
          }
          if (puzzle[row + 1][col].colorRight != normal && puzzle[row + 1][col].colorRight != now) {
            rtValue.add([row + 1, col, "right"]);
          }
          if (puzzle[row][col + 1].colorDown != normal && puzzle[row][col + 1].colorDown != now) {
            rtValue.add([row, col + 1, "down"]);
          }
          break;
        case "left":
          if (puzzle[row - 1][col].colorLeft != normal && puzzle[row - 1][col].colorLeft != now) {
            rtValue.add([row - 1, col, "left"]);
          }
          if (puzzle[row - 1][col].colorDown != normal && puzzle[row - 1][col].colorDown != now) {
            rtValue.add([row - 1, col, "down"]);
          }
          if (puzzle[row][col].colorDown != normal && puzzle[row][col].colorDown != now) {
            rtValue.add([row, col, "down"]);
          }
          if (puzzle.length > row + 1) {
            if (puzzle[row + 1][col].colorLeft != normal && puzzle[row + 1][col].colorLeft != now) {
              rtValue.add([row + 1, col, "left"]);
            }
          }
          break;
        case "right":
          if (puzzle[row - 1][col].colorRight != normal && puzzle[row - 1][col].colorRight != now) {
            rtValue.add([row - 1, col, "right"]);
          }
          if (puzzle[row - 1][col].colorDown != normal && puzzle[row - 1][col].colorDown != now) {
            rtValue.add([row - 1, col, "down"]);
          }
          if (puzzle[row - 1][col + 1].colorDown != normal && puzzle[row - 1][col + 1].colorDown != now) {
            rtValue.add([row - 1, col + 1, "down"]);
          }
          if (puzzle[row][col].colorDown != normal && puzzle[row][col].colorDown != now) {
            rtValue.add([row, col, "down"]);
          }
          if (puzzle.length > row + 1) {
            if (puzzle[row + 1][col].colorRight != normal && puzzle[row + 1][col].colorRight != now) {
              rtValue.add([row + 1, col, "right"]);
            }
            if (puzzle[row + 1][col + 1].colorDown != normal && puzzle[row + 1][col + 1].colorDown != now) {
              rtValue.add([row + 1, col + 1, "down"]);
            }
          }
          break;
      }
    }
    else {
      switch(pos) {
        case "up":
          if (puzzle[row][col].colorLeft != normal && puzzle[row][col].colorLeft != now) {
            rtValue.add([row, col, "left"]);
          }
          if (puzzle[row][col].colorRight != normal && puzzle[row][col].colorRight != now) {
            rtValue.add([row, col, "right"]);
          }
          if (puzzle[row + 1][col].colorUp != normal && puzzle[row + 1][col].colorUp != now) {
            rtValue.add([row + 1, col, "up"]);
          }
          break;
        case "down":
          if (puzzle[row][col].colorLeft != normal && puzzle[row][col].colorLeft != now) {
            rtValue.add([row, col, "left"]);
          }
          if (puzzle[row][col].colorRight != normal && puzzle[row][col].colorRight != now) {
            rtValue.add([row, col, "right"]);
          }
          if (puzzle[row + 1][col].colorLeft != normal && puzzle[row + 1][col].colorLeft != now) {
            rtValue.add([row + 1, col, "left"]);
          }
          if (puzzle[row + 1][col].colorRight != normal && puzzle[row + 1][col].colorRight != now) {
            rtValue.add([row + 1, col, "right"]);
          }
          if (puzzle[row][col + 1].colorDown != normal && puzzle[row][col + 1].colorDown != now) {
            rtValue.add([row, col + 1, "down"]);
          }
          break;
        case "left":
          if (puzzle[row][col].colorUp != normal && puzzle[row][col].colorUp != now) {
            rtValue.add([row, col, "up"]);
          }
          if (puzzle[row][col].colorDown != normal && puzzle[row][col].colorDown != now) {
            rtValue.add([row, col, "down"]);
          }
          if (puzzle[row + 1][col].colorLeft != normal && puzzle[row + 1][col].colorLeft != now) {
            rtValue.add([row + 1, col, "left"]);
          }
          break;
        case "right":
          if (puzzle[row][col].colorUp != normal && puzzle[row][col].colorUp != now) {
            rtValue.add([row, col, "up"]);
          }
          if (puzzle[row][col].colorDown != normal && puzzle[row][col].colorDown != now) {
            rtValue.add([row, col, "down"]);
          }
          if (puzzle[row][col + 1].colorUp != normal && puzzle[row][col + 1].colorUp != now) {
            rtValue.add([row, col + 1, "up"]);
          }
          if (puzzle[row][col + 1].colorDown != normal && puzzle[row][col + 1].colorDown != now) {
            rtValue.add([row, col + 1, "down"]);
          }
          if (puzzle[row + 1][col].colorRight != normal && puzzle[row + 1][col].colorRight != now) {
            rtValue.add([row + 1, col, "right"]);
          }
          break;
      }
    }

    return rtValue;
    return getContinueOld(rtValue);
  }

  List<dynamic> getContinueOld(List<dynamic> start) {
    List<dynamic> rtValue = [start];
    List<dynamic> temp = [];

    int count = 0;
    while(true) {
      temp = rtValue[count];

      if(temp[0] != 0 && temp[1] != 0) {

      }
      else if(temp[0] == 0 && temp[1] != 0) {

      }
      else if(temp[0] != 0 && temp[1] == 0) {

      }
      else if(temp[0] == 0 && temp[1] == 0) {

      }

    }


    return rtValue;
  }

  void changeColor(BuildContext context, int row, int col, String pos, Color color) {
    switch(pos) {
      case "up":
        puzzle[row][col].colorUp = color;
        puzzle[row][col].up = ThemeColor().getColorNum(color);
        print("color : ${puzzle[row][col].colorUp}, colorNum : ${puzzle[row][col].up}");
        break;
      case "down":
        puzzle[row][col].colorDown = color;
        puzzle[row][col].down = ThemeColor().getColorNum(color);
        print("color : ${puzzle[row][col].colorDown}, colorNum : ${puzzle[row][col].down}");
        break;
      case "left":
        puzzle[row][col].colorLeft = color;
        puzzle[row][col].left = ThemeColor().getColorNum(color);
        print("color : ${puzzle[row][col].colorLeft}, colorNum : ${puzzle[row][col].left}");
        break;
      case "right":
        puzzle[row][col].colorRight = color;
        puzzle[row][col].right = ThemeColor().getColorNum(color);
        print("color : ${puzzle[row][col].colorRight}, colorNum : ${puzzle[row][col].right}");
        break;
    }


    notifyListeners();
    //print("changeColor in GameScene $row, $col, $pos, $color, $pr");
    //print("${puzzle[row][col-1].colorDown} ${puzzle[row][col].colorDown} ${puzzle[row][col+1].colorDown}");

    buildSquarePuzzleColor();
  }

  ///getter and setter about widgets

  List<Widget> getSquareField() {
    print("get provider");
    return squareField;
  }
  void setSquareField(List<Widget> field) {
    squareField = field;
    notifyListeners();
    print("provider setSquareField");
  }

  void setPuzzle(List<List<SquareBoxProvider>> puzzle) {
    this.puzzle = puzzle;
    puzzleToWidget();
  }

  void setGameField(GameSceneStateSquareProvider gameField) {
    print("provider setGameField\n---------------");
    this.gameField = gameField;
    notifyListeners();
  }

  void setContinue(bool isContinue) {
    this.isContinue = isContinue;
  }

  void setAnswer(List<List<int>> answer) {
    print("provider setAnswer");
    this.answer = answer;
  }

  void setSubmit(List<List<int>> submit) {
    print("provider setSubmit");
    this.submit = submit;
  }

  ///inner process

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

  Color getNewColor(int row, int col, String pos) {
    Color rtColor = const Color(0x00000000);
    print("---------------");
    print("in provider getNewColor($row, $col, $pos)");
    List<dynamic> oldColorList = getOldColorList(row, col, pos, ThemeColor().getLineColor(type: 0));
    print("oldColorList : $oldColorList");

    List<Color> oldColors = [];
    for(int i = 0 ; i < oldColorList.length ; i++) {
      int row = int.parse(oldColorList[i][0].toString());
      int col = int.parse(oldColorList[i][1].toString());

      switch(pos) {
        case "up":
          oldColors.add(puzzle[row][col].colorUp);
          break;
        case "down":
          oldColors.add(puzzle[row][col].colorDown);
          break;
        case "left":
          oldColors.add(puzzle[row][col].colorLeft);
          break;
        case "right":
          oldColors.add(puzzle[row][col].colorRight);
          break;
      }
    }
    print("oldColors : $oldColors");

    return rtColor;
  }
}