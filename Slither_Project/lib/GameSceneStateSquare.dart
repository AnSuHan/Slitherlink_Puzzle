import 'package:flutter/material.dart';

import 'GameSceneSquare.dart';
import 'widgets/SquareBox.dart';

class GameSceneStateSquare extends State<GameSceneSquare> {
  late Size screenSize;
  static var puzzleWidth = 10;
  static var puzzleHeight = 5;
  late List<Widget> squareField;

  @override
  void initState() {
    super.initState();

    squareField = buildSquarePuzzle(puzzleWidth, puzzleHeight);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Builder(
        builder: (context) {
          screenSize = MediaQuery.of(context).size;

          print("screenSize : ${screenSize.width}");
          print("screenSize : ${screenSize.height}");

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
    List<List<SquareBox>> puzzle = [];
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
    List<List<Widget>> puzzle = initSquarePuzzle(width, height);
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
}