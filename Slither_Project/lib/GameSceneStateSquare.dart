import 'dart:math';

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
    // puzzle[0][2].down = 1;
    setPuzzle(width, height, puzzle);

    return columnChildren;
  }

  static void setPuzzle(width, height, List<List<SquareBox>> puzzle) {
    //cycle이 저장될 배열
    List<List<int>> answer = List.generate(height, (index) {
      if (index % 2 == 0) {
        return List<int>.filled(width, 0);
      } else {
        return List<int>.filled(width + 1, 0);
      }
    });

    //배열 초기화
    for(int i = 0 ; i < height ; i++) {
      for(int j = 0 ; j < ((i % 2) == 0 ? width : (width + 1)) ; j++) {
        answer[i][j] = 0;
      }
    }

    //print("answer : ${answer.length}"); //5
    //print("answer : ${answer[1].length}"); //10 or 11

    var startRow = Random().nextInt(answer.length);
    var startColumn = Random().nextInt(answer[startRow].length);
    var currentRow = startRow;
    var currentColumn = startColumn;

    var nextDirection  = -1; //0 : up, 1 : down, 2 : left, 3 : right
    var nextDirectionList = [0, 1, 2, 3];

    // print("row $nextRow, col $nextColumn");
    // print("width $width, height $height");

    answer[currentRow][currentColumn] = 1;

    //cycle이 완성될 때까지 반복
    while(true) {
      //방향 변수 초기화
      nextDirectionList = [0, 1, 2, 3];

      //진행 방향을 설정
      do {
        nextDirection = nextDirectionList[nextDirectionList.isNotEmpty ? Random().nextInt(nextDirectionList.length) : 0];
        //최대 4번 내에 프로세스가 종료되도록 나온 값을 제거
        nextDirectionList.remove(nextDirection);

        print("nextDirection $nextDirection, nextRow : $currentRow, nextColumn : $currentColumn");

        //다음에 갈 셀의 값이 1이면 다시 반복해야 함 (잘못된 사이클이 생성)
        var temp = [0, 0];
        switch(nextDirection) {
          case 0:
            temp[0] = -1;
            break;
          case 1:
            temp[0] = 1;
            break;
          case 2:
            temp[1] = -1;
            break;
          default:
            temp[1] = -1;
        }
        //while에 걸린 조건을 통과한 경우에만 검사
        if(!((nextDirection == 0 && currentRow == 0) ||
            (nextDirection == 1 && currentRow == height) ||
            (nextDirection == 2 && currentColumn == 0) ||
            (nextDirection == 3 && currentColumn == width))) {
          if(answer[currentRow + temp[0]][currentColumn + temp[1]] == 1) {
            continue;
          }
        }
      } while(
          (nextDirection == 0 && currentRow == 0) ||
          (nextDirection == 1 && currentRow == height) ||
          (nextDirection == 2 && currentColumn == 0) ||
          (nextDirection == 3 && currentColumn == width)
      );  //진행 가능한 방향이 나올 때까지 while

      //진행 방향을 적용
      switch(nextDirection) {
        case 0:
          currentRow -= 1;
          break;
        case 1:
          currentRow += 1;
          break;
        case 2:
          currentColumn -= 1;
          break;
        default:
          currentColumn += 1;
      }

      //사이클 종료 조건
      if((currentRow == startRow) && (currentColumn == startColumn)) {
        break;
      }

      answer[currentRow][currentColumn] = 1;
      print(answer);

      //cycle이 완성 되었는지 판단
      break;
    }
  }
}