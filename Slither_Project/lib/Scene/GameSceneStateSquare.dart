import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:slitherlink_project/MakePuzzle/ReadSquare.dart';

import 'GameSceneSquare.dart';
import '../widgets/SquareBox.dart';

class GameSceneStateSquare extends State<GameSceneSquare> {
  late Size screenSize;
  static const puzzleWidth = 20;    //num of Square - horizontal
  static const puzzleHeight = 10;   //num of Square - vertical
  static late List<Widget> squareField;
  static late List<List<SquareBox>> puzzle;
  var findCycle = false;

  @override
  void initState() {
    super.initState();
    _setupKeyListener();
    squareField = buildSquarePuzzle(puzzleWidth, puzzleHeight);
  }

  void _setupKeyListener() {
    RawKeyboard.instance.addListener((RawKeyEvent event) async {
      if (event is RawKeyDownEvent) {
        //save puzzle for answer
        if(event.logicalKey.debugName?.compareTo("Key S") == 0) {
          ReadSquare().savePuzzle();
          print("Save complete");
        }
        //load puzzle for answer
        else if(event.logicalKey.debugName?.compareTo("Key R") == 0) {
          List<List<int>> data = await ReadSquare().loadPuzzle();
          List<Widget> newSquareField = await buildSquarePuzzleAnswer(data);

          setState(() {
            squareField = newSquareField;
          });
        }
        //print answer data
        else if(event.logicalKey.debugName?.compareTo("Key P") == 0) {
          ReadSquare().printData();
        }
        //apply answer to field
        else if(event.logicalKey.debugName?.compareTo("Key A") == 0) {
          List<List<int>> apply = await ReadSquare().loadPuzzle();
          List<Widget> newSquareField = await buildSquarePuzzleAnswer(apply);
          //var newSquareField = await buildSquarePuzzleAnswer(apply, progress: 2);

          setState(() {
            squareField = newSquareField;
          });
        }
        //clear field
        else if(event.logicalKey.debugName?.compareTo("Key C") == 0) {
          setState(() {
            squareField = buildSquarePuzzle(puzzleWidth, puzzleHeight);
          });
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Builder(
        builder: (context) {
          screenSize = MediaQuery.of(context).size;

          return Scaffold(
            body: Center(
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
                    children: squareField,
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

    /*
    //모서리에 1개씩 설정하는 코드
    var draw = Draw();
    draw.init(puzzleHeight * 2 + 1, puzzleWidth);
    setGrid(puzzle, draw.getGrid());
     */

    return columnChildren;
  }

  static Future<List<Widget>> buildSquarePuzzleAnswer(List<List<int>> answer, {int progress = 1}) async {
    //check progress

    //resize puzzle
    List<List<SquareBox>> puzzle = initSquarePuzzle(answer.length - 1, answer[0].length / 2);
    List<Widget> columnChildren = [];

    //marking answer
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

    return columnChildren;
  }

  //answer is key-value pair
  static void applyUIWithAnswer(List<List<SquareBox>> puzzle, List<List<int>> answer) {
    int lineType;

    for(int i = 0 ; i < answer.length ; i++) {      //10 ,11, 10, 11...
      for (int j = 0; j < answer[i].length; j++) {  //3, 5, 7, 9...
        lineType = answer[i][j];

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
          } else if(i % 2 != 0 && ((i - 1) ~/ 2 + 1 < puzzle.length && j < puzzle[(i - 1) ~/ 2 + 1].length)){
            puzzle[(i - 1) ~/ 2][j - 1].right = lineType;
          }
        }
      }
    }
  }

  static void cprint(bool condition, String text) {
    if(condition) {
      print(text);
    }
  }

  static List<List<SquareBox>> getPuzzle() {
    return puzzle;
  }
}