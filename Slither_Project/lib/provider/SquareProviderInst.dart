import 'package:flutter/material.dart';

import '../Scene/GameSceneSquare_Instance.dart';
import '../ThemeColor.dart';
import '../widgets/SquareBox_Inst.dart';

class SquareProviderInst with ChangeNotifier {
  SquareProviderInst({isContinue = false});

  List<Widget> squareField = [];
  List<List<SquareBoxInst>> puzzle = [];
  late GameSceneStateSquareInst gameField; // GameSceneStateSquareInst 인스턴스 추가

  late List<List<int>> answer;
  late List<List<int>> submit;
  bool isContinue = false;


  //getter and setter about widgets

  List<Widget> getSquareField() {
    print("get provider");
    return squareField;
  }
  void setSquareField(List<Widget> field) {
    squareField = field;
    notifyListeners();
    print("set provider");
  }

  void setPuzzle(List<List<SquareBoxInst>> puzzle) {
    this.puzzle = puzzle;
    puzzleToWidget();
  }

  void setGameField(GameSceneStateSquareInst gameField) {
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
    String temp = "";
    for(int i = 0 ; i < submit.length ; i++) {
      for(int j = 0 ; j < submit[i].length ; j++) {
        temp += "${submit[i][j] }";
      }
      print("row $i : $temp");
      temp = "";
    }

    this.submit = submit;
  }

  //inner process

  void puzzleToWidget() {
    //puzzle = initSquarePuzzle(answer[0].length, answer.length ~/ 2);
    //print("puzzle SquareBoxInst => row ${puzzle.length}, col ${puzzle[0].length}");
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

  void changeColor(int row, int col, String pos, Color color) {
    print("changeColor in provider\n\trow $row, col $col, pos $pos, color $color");

    switch(pos) {
      case "up":
        puzzle[row][col].colorUp = color;
        break;
      case "down":
        puzzle[row][col].colorDown = color;
        break;
      case "left":
        puzzle[row][col].colorLeft = color;
        break;
      case "right":
        puzzle[row][col].colorRight = color;
        break;
    }

    puzzleToWidget();
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
  }

  //answer is key-value pair
  void applyUIWithAnswer(List<List<SquareBoxInst>> puzzle, List<List<int>> answer) {
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

  void setNumWithAnswer(List<List<SquareBoxInst>> puzzle) {
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

}