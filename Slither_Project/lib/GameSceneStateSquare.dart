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
    setPuzzle2(puzzle);

    return columnChildren;
  }

  static void setPuzzle(width, int height, List<List<SquareBox>> puzzle) {
    const minimumLineCount = 5;

    //cycle이 저장될 배열
    List<List<int>> answer = List.generate(3 + (height - 1) * 2, (index) {
      if (index % 2 == 0) {
        return List<int>.filled(width, 0);
      } else {
        return List<int>.filled(width + 1, 0);
      }
    });

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
        var temp = [0, 0];  //이동할 row, column
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
          case 3:
            temp[1] = 1;
        }
        print("current : $currentRow, $currentColumn\ntemp : ${temp[0]}, ${temp[1]}");

        //while에 걸린 조건을 통과할 예정인 경우에
        //도착하는 셀이 이미 방문했는지 미리 확인하고, 방문한 적이 있으면 방문할 셀을 다시 검색
        if((currentRow + temp[0] >= 0) && (currentRow + temp[0] < answer.length) &&
            (currentColumn + temp[1] >= 0) && (currentColumn + temp[1] < answer[currentRow].length)) {
          if(answer[currentRow + temp[0]][currentColumn + temp[1]] == 1) {
            continue;
          }
        }
        else {  //범위를 벗어나는 경우
          print("out of range");
          if(currentColumn >= answer[currentRow].length) {
            currentColumn--;
          }
          continue;
        }
      } while(
          (nextDirection == 0 && currentRow == 0) ||
          (nextDirection == 1 && currentRow >= answer.length - 1) ||
          (nextDirection == 2 && currentColumn == 0) ||
          (nextDirection == 3 && currentColumn >= answer[currentRow].length - 1)
      );  //진행 가능한 방향이 나올 때까지 while

      print("nextDirection : $nextDirection");

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
        case 3:
          currentColumn += 1;
      }

      //사이클 종료 조건
      if((currentRow == startRow) && (currentColumn == startColumn)) {
        break;
      }

      print("before input : $currentRow, $currentColumn");
      answer[currentRow][currentColumn] = 1;
    }

    print(answer);

    //cycle의 크기가 작으면 재호출
    if(checkCount(answer) < minimumLineCount) {
      setPuzzle(width, height, puzzle);
    }

    return;
  }

  static void setPuzzle2(List<List<SquareBox>> puzzle) {
    //기본 변수 세팅
    var numWidth = puzzle[0].length;
    var numHeight = puzzle.length;

    var answerWidthMin = puzzle[0].length;   //10 ,11, 10, 11...
    var answerHeight = puzzle.length * 2 + 1; //3, 5, 7, 9...

    List<List<int>> answer = List.generate(answerHeight,
            (index) => List<int>.filled((index % 2 == 0 ? answerWidthMin : answerWidthMin + 1), 0));

    //print("set Puzzle2 answer :\n$answer");
    //print("height : ${answer.length}, linewidth : ${answer[0].length}");

    //퍼즐 알고리즘 세팅
    final rand = Random();
    var isVertical = rand.nextBool(); //0:가로선, 1:세로선
    var direction = "";   //진행 방향
    int startRow, startColumn;
    int beforeRow, beforeColumn, currentRow, currentColumn;
    bool isFirstEdge = true;
    var tempCnt = 0;

    //answer 배열에서의 시작 위치 설정
    startRow = rand.nextInt(answerHeight);
    startColumn = (startRow % 2 == 0) ? rand.nextInt(answerWidthMin) : rand.nextInt(answerWidthMin + 1);
    print("start row, col : $startRow, $startColumn");

    currentRow = startRow;
    currentColumn = startColumn;

    //반복할 부분
    while(true) {
      //방문한 곳을 제외하고 이동할 방향을 설정
      direction = setDirection(answer, currentRow, currentColumn, answerWidthMin, answerHeight);

      print("cur row : $currentRow, col : $currentColumn, direction : $direction");

      if(direction == "up") {
        currentRow--;
      } else if(direction == "down") {
        currentRow++;
      } else if(direction == "left") {
        currentColumn--;
      } else {
        currentColumn++;
      }

      //cycle이 정상적으로 종료되었는지 확인
      if(!isFirstEdge &&
          startRow == currentRow && startColumn == currentColumn) {
        break;
      }
      //임시 종료
      if(tempCnt >= 5) {
        break;
      }

      //배열에 적용
      applyToAnswer(answer, currentRow, currentColumn);

      isFirstEdge = false;
      tempCnt++;
    }
  }

  static String setDirection(List<List<int>> answer, int currentRow, int currentColumn, int answerWidthMin, int answerHeight) {
    String direction = "";

    if(currentRow % 2 == 0) { //선만 있는 라인
      if(currentColumn == 0) {
        direction = "right";

        if(answer[currentRow][currentColumn + 1] == 1) {
          return setDirection(answer, currentRow, currentColumn, answerWidthMin, answerHeight);
        }
      }
      else if(currentColumn == answerWidthMin) {
        direction = "left";

        if(answer[currentRow][currentColumn - 1] == 1) {
          return setDirection(answer, currentRow, currentColumn, answerWidthMin, answerHeight);
        }
      }
      else {
        direction = ["left", "right"][Random().nextInt(2)];
      }
    } else {  //숫자가 있는 라인
      if(currentRow == 0) {
        direction = "down";

        if(answer[currentRow + 1][currentColumn] == 1) {
          return setDirection(answer, currentRow, currentColumn, answerWidthMin, answerHeight);
        }
      }
      else if(currentRow == answerHeight) {
        direction = "up";

        if(answer[currentRow - 1][currentColumn] == 1) {
          return setDirection(answer, currentRow, currentColumn, answerWidthMin, answerHeight);
        }
      }
      else {
        direction = ["up", "down"][Random().nextInt(2)];
      }
    }
    return direction;
  }

  static void applyToAnswer(List<List<int>> answer, currentRow, currentColumn) {
    answer[currentRow][currentColumn] = 1;
    var str = "";

    for(int i = 0 ; i < answer.length ; i++) {
      str = "";

      for(int j = 0 ; j < answer[i].length ; j++) {
        str += "${answer[i][j]} ";
      }
      print(str);
    }
  }

  static int checkCount(List<List<int>> list) {
    int count = 0;

    for(int i = 0 ; i < list.length ; i++) {
      for(int j = 0 ; j < list[i].length ; j++) {
        if(list[i][j] == 1) {
          count += 1;
        }
      }
    }
    print(count);

    return count;
  }
}