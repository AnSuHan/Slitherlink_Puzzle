import 'package:flutter/material.dart';

import '../MakePuzzle/ReadSquare.dart';
import '../Scene/GameSceneSquareProvider.dart';
import '../widgets/SquareBoxProvider.dart';

class SquareProviderProvider with ChangeNotifier {
  SquareProviderProvider({isContinue = false});

  ReadSquare readSquare = ReadSquare();

  List<Widget> squareField = [];
  List<List<SquareBoxProvider>> puzzle = [];
  late GameSceneStateSquareProvider gameField; // instance of GameSceneStateSquareProvider

  late List<List<int>> answer;
  late List<List<int>> submit;
  bool isContinue = false;

  ///Init
  void init() async {
    print("call init");
    puzzle = initSquarePuzzle(answer[0].length, answer.length ~/ 2);
    squareField = await buildSquarePuzzleAnswer(answer, isContinue: isContinue);
    notifyListeners();
    setLineColor(2, 4, "down", 3);
  }

  ///update `puzzle` variable
  void updateSquareBox(int row, int column, {int? up, int? down, int? left, int? right}) {
    if (up != null) puzzle[row][column].up = up;
    if (down != null) puzzle[row][column].down = down;
    if (left != null) puzzle[row][column].left = left;
    if (right != null) puzzle[row][column].right = right;

    refreshSubmit();
    notifyListeners();
  }

  void refreshSubmit() async {
    submit = await readSquare.readSubmit(puzzle);

    String temp = "";
    for(int i = 0 ; i < submit.length ; i++) {
      for(int j = 0 ; j < submit[i].length ; j++) {
        temp += "${submit[i][j]} ";
      }
      print("row $i : $temp");
      temp = "";
    }
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
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
  Set<int> getNearColor(int row, int col, String pos) {
    Set<int> use = {};

    if(row != 0 && col != 0) {
      switch(pos) {
        case "down":
          use.add(puzzle[row][col - 1].down);
          use.add(puzzle[row][col - 1].right);
          use.add(puzzle[row][col].right);

          if(puzzle.length > row + 1) {
            use.add(puzzle[row + 1][col - 1].right);
            use.add(puzzle[row + 1][col].right);
          }
          if(puzzle[row].length > col + 1) {
            use.add(puzzle[row][col + 1].down);
          }
          break;
        case "right":
          use.add(puzzle[row - 1][col].right);
          use.add(puzzle[row - 1][col].down);
          use.add(puzzle[row][col].down);

          if(puzzle[row].length > col + 1) {
            use.add(puzzle[row - 1][col + 1].down);
            use.add(puzzle[row][col + 1].down);
          }
          if(puzzle.length > row + 1) {
            use.add(puzzle[row + 1][col].right);
          }
          break;
      }
    }
    else if(col != 0) {
      switch(pos) {
        case "up":
          use.add(puzzle[row][col - 1].up);
          use.add(puzzle[row][col - 1].right);
          use.add(puzzle[row][col].right);

          if(puzzle[row].length > col + 1) {
            use.add(puzzle[row][col + 1].up);
          }
          break;
        case "down":
          use.add(puzzle[row][col - 1].down);
          use.add(puzzle[row][col - 1].right);
          use.add(puzzle[row][col].right);

          if(puzzle[row].length > col + 1) {
            use.add(puzzle[row][col + 1].down);
          }
          if(puzzle.length > row + 1) {
            use.add(puzzle[row + 1][col - 1].right);
            use.add(puzzle[row + 1][col].right);
          }
          break;
        case "right":
          use.add(puzzle[row][col].up);
          use.add(puzzle[row][col].down);

          if(puzzle[row].length > col + 1) {
            use.add(puzzle[row][col + 1].up);
            use.add(puzzle[row][col + 1].down);
          }
          if(puzzle.length > row + 1) {
            use.add(puzzle[row + 1][col].right);
          }
          break;
      }
    }
    else if(row != 0) {
      switch(pos) {
        case "down":
          use.add(puzzle[row][col].left);
          use.add(puzzle[row][col].right);
          use.add(puzzle[row + 1][col].left);
          use.add(puzzle[row + 1][col].right);
          use.add(puzzle[row][col + 1].down);
          break;
        case "left":
          use.add(puzzle[row - 1][col].left);
          use.add(puzzle[row - 1][col].down);
          use.add(puzzle[row][col].down);

          if(puzzle.length > row + 1) {
            use.add(puzzle[row + 1][col].left);
          }
          break;
        case "right":
          use.add(puzzle[row - 1][col].right);
          use.add(puzzle[row - 1][col].down);
          use.add(puzzle[row - 1][col + 1].down);
          use.add(puzzle[row][col].down);

          if(puzzle.length > row + 1) {
            use.add(puzzle[row + 1][col].right);
            use.add(puzzle[row + 1][col + 1].down);
          }
          break;
      }
    }
    else {
      switch(pos) {
        case "up":
          use.add(puzzle[row][col].left);
          use.add(puzzle[row][col].right);
          use.add(puzzle[row + 1][col].up);
          break;
        case "down":
          use.add(puzzle[row][col].left);
          use.add(puzzle[row][col].right);
          use.add(puzzle[row + 1][col].left);
          use.add(puzzle[row + 1][col].right);
          use.add(puzzle[row][col + 1].down);
          break;
        case "left":
          use.add(puzzle[row][col].up);
          use.add(puzzle[row][col].down);
          use.add(puzzle[row + 1][col].left);
          break;
        case "right":
          use.add(puzzle[row][col].up);
          use.add(puzzle[row][col].down);
          use.add(puzzle[row][col + 1].up);
          use.add(puzzle[row][col + 1].down);
          use.add(puzzle[row + 1][col].right);
          break;
      }
    }

    use.remove(const Color(0xff000000));
    return use;
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
          if (puzzle[row + 1][col].up != normal && puzzle[row + 1][col].up != now) {
            rtValue.add([row + 1, col, "up"]);
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

  void changeColor(BuildContext context, int row, int col, String pos, int color) {
    switch(pos) {
      case "up":
        puzzle[row][col].up = color;
        print("color : ${puzzle[row][col].up}, colorNum : ${puzzle[row][col].up}");
        break;
      case "down":
        puzzle[row][col].down = color;
        print("color : ${puzzle[row][col].down}, colorNum : ${puzzle[row][col].down}");
        break;
      case "left":
        puzzle[row][col].left = color;
        print("color : ${puzzle[row][col].left}, colorNum : ${puzzle[row][col].left}");
        break;
      case "right":
        puzzle[row][col].right = color;
        print("color : ${puzzle[row][col].right}, colorNum : ${puzzle[row][col].right}");
        break;
    }


    notifyListeners();
    //print("changeColor in GameScene $row, $col, $pos, $color, $pr");
    //print("${puzzle[row][col-1].down} ${puzzle[row][col].down} ${puzzle[row][col+1].down}");

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
    List<dynamic> oldColorList = getOldColorList(row, col, pos, 0);
    print("oldColorList : $oldColorList");

    List<int> oldColors = [];
    for(int i = 0 ; i < oldColorList.length ; i++) {
      int row = int.parse(oldColorList[i][0].toString());
      int col = int.parse(oldColorList[i][1].toString());

      switch(pos) {
        case "up":
          oldColors.add(puzzle[row][col].up);
          break;
        case "down":
          oldColors.add(puzzle[row][col].down);
          break;
        case "left":
          oldColors.add(puzzle[row][col].left);
          break;
        case "right":
          oldColors.add(puzzle[row][col].right);
          break;
      }
    }
    print("oldColors : $oldColors");

    return rtColor;
  }
}