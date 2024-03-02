

import 'dart:math';

import 'package:flutter/material.dart';

import 'GameSceneSquare.dart';
import 'widgets/SquareBox.dart';

class GameSceneStateSquare extends State<GameSceneSquare> {
  late Size screenSize;
  static var puzzleWidth = 20;
  static var puzzleHeight = 10;
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

          //print("screenSize : ${screenSize.width}");
          //print("screenSize : ${screenSize.height}");

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
    setPuzzle3(puzzle);

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

  //사이클이 아닌 라인을 생성하는 것을 목적으로 변경
  static void setPuzzle2(List<List<SquareBox>> puzzle) {
    //기본 변수 세팅
    var answerWidthMin = puzzle[0].length;   //10 ,11, 10, 11...
    var answerHeight = puzzle.length * 2 + 1; //3, 5, 7, 9...

    List<List<int>> answer = List.generate(answerHeight,
            (index) => List<int>.filled((index % 2 == 0 ? answerWidthMin : answerWidthMin + 1), 0));

    //퍼즐 알고리즘 세팅
    final rand = Random();
    String direction = "";   //진행 방향
    String postDirection = "";
    int startRow, startColumn;
    int currentRow, currentColumn;
    bool isFirstEdge = true;
    var tempCnt = 0;

    //answer 배열에서의 시작 위치 설정
    startRow = rand.nextInt(answerHeight);
    startColumn = (startRow % 2 == 0) ? rand.nextInt(answerWidthMin) : rand.nextInt(answerWidthMin + 1);
    print("start row, col : $startRow, $startColumn");

    //시작점을 배열에 적용
    applyToAnswer(answer, startRow, startColumn);

    currentRow = startRow;
    currentColumn = startColumn;

    //반복할 부분
    /*
    while(true) {
      //방문한 곳을 제외하고 이동할 방향을 설정
      direction = setDirection(answer, postDirection, currentRow, currentColumn, answerWidthMin, answerHeight);

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
      // if(!isFirstEdge &&
      //     startRow == currentRow && startColumn == currentColumn) {
      //   break;
      // }
      //임시 종료
      if(tempCnt >= 5) {
        break;
      }

      //배열에 적용
      applyToAnswer(answer, currentRow, currentColumn);

      isFirstEdge = false;
      tempCnt++;
    }

     */

    applyUIWithAnswer(puzzle, answer);
  }

  static String setDirection(List<List<int>> answer, String postDirection, int currentRow, int currentColumn, int answerWidthMin, int answerHeight) {
    String direction = "";
    //0 : 이동 불가, 1 : 이동 가능
    var valid = [1, 1, 1, 1]; //up, down, left, right

    if(currentRow == 0 || currentRow == answerHeight) {
      //물리적으로 up또는 down으로 이동하지 못하는 경우
      if(currentRow == 0) {
        valid[0] = 0;
      } else if(currentRow == answerHeight) {
        valid[1] = 0;
      }
    } else if(currentColumn == 0 || currentColumn == (currentRow % 2 == 0 ? answerWidthMin : answerWidthMin + 1)) {
      //물리적으로 left또는 right로 이동하지 못하는 경우
      if(currentColumn == 0) {
        valid[2] = 0;
      } else if(currentColumn == (currentRow % 2 == 0 ? answerWidthMin : answerWidthMin + 1)) {
        valid[3] = 0;
      }
    } else {
      //물리적으로 이동 불가한 장소가 없는 경우
    }

    //논리적으로 이동 불가한 방향을 제외
    //이 부분은 변경 필요 hor -> ver or ver -> hor로 이동 시 오류 발생 가능?
    if(valid[0] == 1 && answer[currentRow - 1][currentColumn] == 1) {
      valid[0] = 0;
    } else if(valid[1] == 1 && answer[currentRow + 1][currentColumn] == 1) {
      valid[1] = 0;
    } else if(valid[2] == 1 && answer[currentRow][currentColumn - 1] == 1) {
      valid[2] = 0;
    } else if(valid[3] == 1 && answer[currentRow][currentColumn + 1] == 1) {
      valid[3] = 0;
    }

    if(postDirection == "") {
    } else if(postDirection == "up") {

    }

    //이동 가능한 방향 만을 변수에 저장
    var available = [];

    for(int i = 0 ; i < 4 ; i++) {
      if(valid[i] == 1) {
        switch(i) {
          case 0:
            available.add("up");
            break;
          case 1:
            available.add("down");
            break;
          case 2:
            available.add("left");
            break;
          default:
            available.add("right");
        }
      }
    }
    direction = available[Random().nextInt(available.length)];

    return direction;
  }

  //사이클이 아닌 라인을 생성하는 것을 목적으로 변경
  static void setPuzzle3(List<List<SquareBox>> puzzle) {
    final rand = Random();

    //기본 변수 세팅
    var answerWidthMin = puzzle[0].length;    //10 ,11, 10, 11...
    var answerHeight = puzzle.length * 2 + 1; //3, 5, 7, 9...

    List<List<int>> answer = List.generate(answerHeight,
            (index) => List<int>.filled((index % 2 == 0 ? answerWidthMin : answerWidthMin + 1), 0));

    const numOfPoints = 4;
    int boundary = 0;   //제한
    var points = List.generate(numOfPoints,
            (index) => List<int>.filled(2, 0));  //row, column을 4개 저장하는 2차원 배열

    if(numOfPoints == 4) {
      //numOfPoints인 경우에만 사용하도록 작성
      for(int i = 0 ; i < numOfPoints ; i++) {
        //setting Row
        boundary = (answer.length * 0.25).ceil();
        points[i][0] = i < 2 ? rand.nextInt(boundary) : answer.length - rand.nextInt(boundary);

        if(points[i][0] >= answer.length) {
          points[i][0] = answer.length - 1;
        } else if(points[i][0] < 0) {
          points[i][0] = 0;
        }

        //setting Column
        boundary = (answer[points[i][0]].length * 0.25).ceil();
        points[i][1] = (i == 0 || i == 3) ? rand.nextInt(boundary) : answer[points[i][0]].length - 1 - rand.nextInt(boundary);
      }
    }
    print("points : ${points[0]} ${points[1]} ${points[2]} ${points[3]}");

    innerFindRoute4(puzzle, answer, [points[0], points[1]]);
    // innerFindRoute3(puzzle, answer, [points[1], points[2]]);
    // innerFindRoute3(puzzle, answer, [points[2], points[3]]);
    // innerFindRoute3(puzzle, answer, [points[3], points[0]]);

    // var row_1st = rand.nextInt(answer.length);
    // var column_1st = rand.nextInt(answer[row_1st].length);
    // var row_2nd = rand.nextInt(answer.length);
    // var column_2nd = rand.nextInt(answer[row_2nd].length);
    //
    // innerFindRoute3(puzzle, answer, [row_1st, column_1st, row_2nd, column_2nd]);
    //hardApplyUI(puzzle);
  }

  static void innerFindRoute4(List<List<SquareBox>> puzzle, List<List<int>> answer, List<List<int>> points) {
    var rand = Random();
    var nowRow = points[0][0];
    var nowColumn = points[0][1];
    var goalRow = points[1][0];
    var goalColumn = points[1][1];

    List<String> typeList = []; //순서가 없는 최소 이동 방향
    List<String> dirList = [];  //시작,종료 방향을 고려한 이동 방향
    List<String> linkList = []; //시작,종료 방향을 고려한 순서가 있는 이동 방향
    int i = 0;
    int subCount = 0;  //시작이 가로/세로인지에 따라 반복 횟수를 다르게 감소
    String nowDirection = (nowRow % 2 == 0) ? ["left", "right"][rand.nextInt(2)] : ["up", "down"][rand.nextInt(2)];   //진행 방향 저장
    String goalDirection = (goalRow % 2 == 0) ? ["left", "right"][rand.nextInt(2)] : ["up", "down"][rand.nextInt(2)];   //진행 방향 저장
    String firstIdealDirection = "";
    String goalIdealDirection = "";

    //반복 횟수를 nowRow가 가로선이면 1감소, 세로선이면 2감소
    subCount = nowRow % 2 == 0 ? subCount + 1 : subCount + 2;

    if(nowRow != goalRow) {
      for(i = 0 ; i < (nowRow - goalRow).abs() - subCount ; i++) {
        if(goalRow > nowRow) {
          typeList.add("down");
        } else {
          typeList.add("up");
        }
      }
    }

    subCount = (nowRow % 2 == 0) ? 1 : 0;

    if(nowColumn != goalColumn) {
      for(i = 0 ; i < (nowColumn - goalColumn).abs() - subCount ; i++) {
        if(goalColumn > nowColumn) {
          typeList.add("right");
        } else {
          typeList.add("left");
        }
      }
    }

    //print("typelist : $typeList");
    print("nowDir : $nowDirection, goalDir : $goalDirection");

    //디버그 전용
    answer[nowRow][nowColumn] = 1;
    answer[goalRow][goalColumn] = 1;
    //

    //시작, 종료 방향을 고려한 방향 배열 생성
    dirList = List.from(typeList);  //soft copy
    //print("dirList : $dirList");

    //최소 거리이기 위한 start point의 방향
    if(nowRow % 2 == 0) {
      if(nowColumn < goalColumn) {
        firstIdealDirection = "right";
      } else if(nowColumn > goalColumn) {
        firstIdealDirection = "left";
      } else {
        firstIdealDirection = "";
      }
    } else {
      if(nowRow < goalRow) {
        firstIdealDirection = "down";
      } else if(nowRow > goalRow) {
        firstIdealDirection = "up";
      } else {
        firstIdealDirection = "";
      }
    }

    firstIdealDirection = firstIdealDirection == "" ? nowDirection : firstIdealDirection;
    //print("firstIdealDirection : $firstIdealDirection, ${dirList.contains(firstIdealDirection)}");

    //최소 거리이기 위한 goal point의 방향
    if(goalRow % 2 == 0) {
      if(nowColumn < goalColumn) {
        goalIdealDirection= "right";
      } else if(nowColumn > goalColumn) {
        goalIdealDirection= "left";
      } else {
        goalIdealDirection= "";
      }
    } else {
      if(nowRow < goalRow) {
        goalIdealDirection= "down";
      } else if(nowRow > goalRow) {
        goalIdealDirection= "up";
      } else {
        goalIdealDirection= "";
      }
    }

    goalIdealDirection = goalIdealDirection == "" ? goalDirection : goalIdealDirection;
    //print("goalIdealDirection: $goalIdealDirection, ${dirList.contains(goalIdealDirection)}");


    //시작 방향에 대한 보정 값
    if(nowDirection != firstIdealDirection) {
      switch(nowDirection) {
        case "left":
          dirList.add("right");
          break;
        case "right":
          dirList.add("left");
          break;
        case "up":
          dirList.add("down");
          break;
        case "down":
          dirList.add("up");
          break;
      }
    }
    //목표 방향에 대한 보정 값
    if(goalDirection != goalIdealDirection) {
      switch(nowDirection) {
        case "left":
          dirList.add("right");
          break;
        case "right":
          dirList.add("left");
          break;
        case "up":
          dirList.add("down");
          break;
        case "down":
          dirList.add("up");
          break;
      }
    }


    while(dirList.isNotEmpty) {
      i = rand.nextInt(dirList.length);  //삭제할 인덱스
      linkList.add(dirList[i]);
      dirList.removeAt(i);
    }

    //print("linkList : $linkList");
    var beforeDir = nowDirection;
    var changedIndexList = [];
    var changedIndex = -1;

    //처음, 마지막 element는 이전 방향과 다르도록 강제로 설정
    //방향을 맞추기 위해서
    if(nowDirection == "left" && linkList[0] == "right") {
      //순서 변경으로 해결 불가한 경우에만, 새로운 element 추가
      if(!linkList.contains("up") && !linkList.contains("down")) {
        linkList.add("up");
        linkList.add("down");
        linkList.add("right");
      }

      //순서 변경으로 해결
      for(i = 0 ; i < linkList.length ; i++) {
        if(linkList[i] == "up" || linkList[i] == "down") {
          changedIndexList.add(i);
        }
      }
      changedIndex = changedIndexList[rand.nextInt(changedIndexList.length)];

      var temp = linkList[changedIndex];
      linkList[changedIndex] = linkList[0];
      linkList[0] = temp;
    } else if(nowDirection == "right" && linkList[0] == "left") {
      // 순서 변경으로 해결 불가한 경우에만, 새로운 element 추가
      if(!linkList.contains("up") && !linkList.contains("down")) {
        linkList.add("up");
        linkList.add("down");
        linkList.add("left");
      }

      // 순서 변경으로 해결
      for(i = 0 ; i < linkList.length ; i++) {
        if(linkList[i] == "up" || linkList[i] == "down") {
          changedIndexList.add(i);
        }
      }
      changedIndex = changedIndexList[rand.nextInt(changedIndexList.length)];

      var temp = linkList[changedIndex];
      linkList[changedIndex] = linkList[0];
      linkList[0] = temp;
    } else if(nowDirection == "up" && linkList[0] == "down") {
      // 순서 변경으로 해결 불가한 경우에만, 새로운 element 추가
      if(!linkList.contains("left") && !linkList.contains("right")) {
        linkList.add("left");
        linkList.add("right");
        linkList.add("down");
      }

      // 순서 변경으로 해결
      for(i = 0 ; i < linkList.length ; i++) {
        if(linkList[i] == "left" || linkList[i] == "right") {
          changedIndexList.add(i);
        }
      }
      changedIndex = changedIndexList[rand.nextInt(changedIndexList.length)];

      var temp = linkList[changedIndex];
      linkList[changedIndex] = linkList[0];
      linkList[0] = temp;
    } else if(nowDirection == "down" && linkList[0] == "up") {
      // 순서 변경으로 해결 불가한 경우에만, 새로운 element 추가
      if(!linkList.contains("left") && !linkList.contains("right")) {
        linkList.add("left");
        linkList.add("right");
        linkList.add("up");
      }

      // 순서 변경으로 해결
      for(i = 0 ; i < linkList.length ; i++) {
        if(linkList[i] == "left" || linkList[i] == "right") {
          changedIndexList.add(i);
        }
      }
      changedIndex = changedIndexList[rand.nextInt(changedIndexList.length)];

      var temp = linkList[changedIndex];
      linkList[changedIndex] = linkList[0];
      linkList[0] = temp;
    }

    //print("modified linkList for start : $linkList");

    if(goalDirection == "left" && linkList[linkList.length - 1] == "right") {
      //순서 변경으로 해결 불가한 경우, 새로운 element 추가
      if(!linkList.contains("left") && !linkList.contains("up") && !linkList.contains("down")) {
        //linkList가 right만 가지고 있을 때
        linkList.add("left");
        // linkList.add("right");
        linkList.add("up");
        linkList.add("down");
      }

      //순서 변경으로 해결
      for(i = 0 ; i < linkList.length ; i++) {
        if(linkList[i] != "right") {
          changedIndexList.add(i);
        }
      }
      changedIndex = changedIndexList[rand.nextInt(changedIndexList.length)];

      var temp = linkList[changedIndex];
      linkList[changedIndex] = linkList[linkList.length - 1];
      linkList[linkList.length - 1] = temp;
    } else if(goalDirection == "right" && linkList[linkList.length - 1] == "left") {
      //순서 변경으로 해결 불가한 경우, 새로운 element 추가
      if(!linkList.contains("right") && !linkList.contains("up") && !linkList.contains("down")) {
        //linkList가 right만 가지고 있을 때
        // linkList.add("left");
        linkList.add("right");
        linkList.add("up");
        linkList.add("down");
      }

      //순서 변경으로 해결
      for(i = 0 ; i < linkList.length ; i++) {
        if(linkList[i] != "left") {
          changedIndexList.add(i);
        }
      }
      changedIndex = changedIndexList[rand.nextInt(changedIndexList.length)];

      var temp = linkList[changedIndex];
      linkList[changedIndex] = linkList[linkList.length - 1];
      linkList[linkList.length - 1] = temp;
    } else if(goalDirection == "up" && linkList[linkList.length - 1] == "down") {
      //순서 변경으로 해결 불가한 경우, 새로운 element 추가
      if(!linkList.contains("left") && !linkList.contains("right") && !linkList.contains("up")) {
        //linkList가 right만 가지고 있을 때
        linkList.add("left");
        linkList.add("right");
        linkList.add("up");
        // linkList.add("down");
      }

      //순서 변경으로 해결
      for(i = 0 ; i < linkList.length ; i++) {
        if(linkList[i] != "down") {
          changedIndexList.add(i);
        }
      }
      changedIndex = changedIndexList[rand.nextInt(changedIndexList.length)];

      var temp = linkList[changedIndex];
      linkList[changedIndex] = linkList[linkList.length - 1];
      linkList[linkList.length - 1] = temp;
    } else if(goalDirection == "down" && linkList[linkList.length - 1] == "up") {
      //순서 변경으로 해결 불가한 경우, 새로운 element 추가
      if(!linkList.contains("left") && !linkList.contains("right") && !linkList.contains("down")) {
        //linkList가 right만 가지고 있을 때
        linkList.add("left");
        linkList.add("right");
        // linkList.add("up");
        linkList.add("down");
      }

      //순서 변경으로 해결
      for(i = 0 ; i < linkList.length ; i++) {
        if(linkList[i] != "up") {
          changedIndexList.add(i);
        }
      }
      changedIndex = changedIndexList[rand.nextInt(changedIndexList.length)];

      var temp = linkList[changedIndex];
      linkList[changedIndex] = linkList[linkList.length - 1];
      linkList[linkList.length - 1] = temp;
    }

    print("2modified linkList for start : $linkList");

    //index 0과 마지막은 고정해 둔 상태에서
    //이전 방향과 반대 방향으로 이동하는 경우를 제거
    for(i = 1 ; i < linkList.length ; i++) {
      if(linkList[i - 1] == "left" && linkList[i] == "right") {

      }
    }

    //answer 배열에 값 설정
    for(i = 0 ; i < linkList.length ; i++) {
      print("$beforeDir -> ${linkList[i]}");

      if(nowRow % 2 == 0) {
        if(beforeDir == "left") {
          switch(linkList[i]) {
            case "up":
              nowRow--;
              break;
            case "down":
              nowRow++;
              break;
            case "left":
              nowColumn--;
              break;
          }
        } else {
        switch(linkList[i]) {
          case "up":
            nowRow--;
            nowColumn++;
            break;
          case "down":
            nowRow++;
            nowColumn++;
            break;
          case "right":
            nowColumn++;
            break;
          }
        }

      } else {
        if(beforeDir == "up") {
          switch(linkList[i]) {
            case "up":
              nowRow -= 2;
              break;
            case "left":
              nowRow--;
              nowColumn--;
              break;
            case "right":
              nowRow--;
              break;
          }
        } else {
          switch(linkList[i]) {
            case "down":
              nowRow += 2;
              break;
            case "left":
              nowRow++;
              nowColumn--;
              break;
            case "right":
              nowRow++;
              break;
          }
        }
      }


      print("nowRow : $nowRow, nowColumn : $nowColumn");
      beforeDir = linkList[i];

      // if(i == 0) {
      //   continue;
      // }
      answer[nowRow][nowColumn] = 2;
    }



    applyUIWithAnswer2(puzzle, answer);
  }

  //수정 필요
  static void innerFindRoute3(List<List<SquareBox>> puzzle, List<List<int>> answer, List<List<int>> points) {
    var rand = Random();
    var nowRow = points[0][0];
    var nowColumn = points[0][1];
    var goalRow = points[1][0];
    var goalColumn = points[1][1];

    var cnt = 0;
    const maxCnt = 5;

    //화면에 표기
    answer[nowRow][nowColumn] = 1;
    print("make route [$nowRow, $nowColumn] -> [$goalRow, $goalColumn]");

    applyUIWithAnswer2(puzzle, answer);

    //앞으로 진행해 갈 방향
    String lookAt = "";
    //움직인 방향 (answer 기준 아님
    // up, left 당 -1, down, right 당 +1)
    var absMove = [0, 0];
    //다음으로 이동할 수 있는 방향
    var canMove = ["up", "down", "left", "right"];

    while(cnt < maxCnt) {
      //앞으로 진행해 갈 방향은 처음에만 초기화
      if(cnt++ == 0) {
        if(nowRow % 2 == 0) {
          if(nowColumn == 0) {
            lookAt = "right";
          } else if(nowColumn == answer[nowRow].length) {
            lookAt = "left";
          } else {
            lookAt = ["left", "right"][rand.nextInt(2)];
          }
        } else {
          if(nowRow == 0) {
            lookAt = "down";
          } else if(nowRow == answer.length) {
            lookAt = "up";
          } else {
            lookAt = ["up", "down"][rand.nextInt(2)];
          }
        }
      }

      //print("lookAt : $lookAt");

      //다음 라인 설정
      switch(lookAt) {
        case "up":
          canMove.remove("down");

          if(nowColumn == 0) {
            canMove.remove("left");
          } else if(nowColumn == answer[nowRow].length - 1) {
            canMove.remove("right");
          }
          if(nowRow == 1) {
            canMove.remove("up");
          }

          notAccessVisitedLine(lookAt, canMove, answer, nowRow, nowColumn);
          break;
        case "down":
          canMove.remove("up");

          if(nowColumn == 0) {
            canMove.remove("left");
          } else if(nowColumn == answer[nowRow].length - 1) {
            canMove.remove("right");
          }
          if(nowRow == answer.length - 2) {
            canMove.remove("down");
          }

          notAccessVisitedLine(lookAt, canMove, answer, nowRow, nowColumn);
          break;
        case "left":
          canMove.remove("right");

          if(nowRow == 0) {
            canMove.remove("up");
          } else if(nowRow == answer.length - 1) {
            canMove.remove("down");
          }

          if(nowColumn == 0) {
            canMove.remove("left");
          }

          notAccessVisitedLine(lookAt, canMove, answer, nowRow, nowColumn);
          break;
        case "right":
          canMove.remove("left");

          if(nowRow == 0) {
            canMove.remove("up");
          } else if(nowRow == answer.length - 1) {
            canMove.remove("down");
          }

          if(nowColumn == answer[nowRow].length - 1) {
            canMove.remove("right");
          }

          notAccessVisitedLine(lookAt, canMove, answer, nowRow, nowColumn);
          break;
      }

      //print("canMove : $canMove");
      //print("row : $nowRow, col : $nowColumn");

      //다음 라인을 설정
      var nextMove = canMove.isNotEmpty ? canMove[rand.nextInt(canMove.length)] : "";
      //print("nextMove : $lookAt -> $nextMove");

      switch(lookAt) {
        case "up":
          if(nextMove == "up") {
            nowRow -= 2;
          } else if(nextMove == "left") {
            nowRow--;
            nowColumn--;
          } else if(nextMove == "right") {
            nowRow--;
          }

          break;
        case "down":
          if(nextMove == "down") {
            nowRow += 2;
          } else if(nextMove == "left") {
            nowRow++;
            nowColumn--;
          } else if(nextMove == "right") {
            nowRow++;
          }

          break;
        case "left":
          if(nextMove == "left") {
            nowColumn--;
          } else if(nextMove == "up") {
            nowRow--;
          } else if(nextMove == "down") {
            nowRow++;
          }

          break;
        case "right":
          if(nextMove == "right") {
            nowColumn++;
          } else if(nextMove == "up") {
            nowRow--;
            nowColumn++;
          } else if(nextMove == "down") {
            nowRow++;
            nowColumn++;
          }
      }

      //종료를 판단하기 위해 absMove에 저장
      switch(nextMove) {
        case "up":
          absMove[0]--;
          break;
        case "down":
          absMove[0]++;
          break;
        case "left":
          absMove[1]--;
          break;
        case "right":
          absMove[1]++;
          break;
      }

      //print("row : $nowRow, col : $nowColumn");

      answer[nowRow][nowColumn] = 1;

      //종료 조건
      if(nowRow == goalRow &&
      nowColumn == goalColumn) {
        applyUIWithAnswer2(puzzle, answer);

        return;
      }

      //다음 실행을 위해 초기화
      canMove = ["up", "down", "left", "right"];
      lookAt = nextMove;
    }

    applyUIWithAnswer2(puzzle, answer);
  }

  /** 이미 방문한 선 제외 */
  static void notAccessVisitedLine(String lookAt, List<String> canMove, List<List<int>> answer, int nowRow, int nowColumn) {
    switch(lookAt) {
      case "up":
        if(canMove.contains("up")) {
          if(answer[nowRow - 2][nowColumn] != 0) {
            canMove.remove("up");
          }
        }
        if(canMove.contains("left")) {
          if(answer[nowRow - 1][nowColumn - 1] != 0) {
            canMove.remove("left");
          }
        }
        if(canMove.contains("right")) {
          if(answer[nowRow - 1][nowColumn] != 0) {
            canMove.remove("right");
          }
        }
        break;
      case "down":
        if(canMove.contains("down")) {
          if(answer[nowRow + 2][nowColumn] != 0) {
            canMove.remove("down");
          }
        }
        if(canMove.contains("left")) {
          if(answer[nowRow + 1][nowColumn - 1] != 0) {
            canMove.remove("left");
          }
        }
        if(canMove.contains("right")) {
          if(answer[nowRow + 1][nowColumn] != 0) {
            canMove.remove("right");
          }
        }
        break;
      case "left":
        if(canMove.contains("left")) {
          if(answer[nowRow][nowColumn - 1] != 0) {
            canMove.remove("left");
          }
        }
        if(canMove.contains("up")) {
          if(answer[nowRow - 1][nowColumn] != 0) {
            canMove.remove("up");
          }
        }
        if(canMove.contains("down")) {
          if(answer[nowRow + 1][nowColumn] != 0) {
            canMove.remove("down");
          }
        }
        break;
      case "right":
        if(canMove.contains("right")) {
          if(answer[nowRow][nowColumn + 1] != 0) {
            canMove.remove("right");
          }
        }
        if(canMove.contains("up")) {
          if(answer[nowRow - 1][nowColumn] != 0) {
            canMove.remove("up");
          }
        }
        if(canMove.contains("down")) {
          if(answer[nowRow + 1][nowColumn] != 0) {
            canMove.remove("down");
          }
        }
        break;
    }
  }

  static void innerFindRoute2(List<List<SquareBox>> puzzle, List<List<int>> answer, row_1st, col_1st, row_2nd, col_2nd) {
    var mvHorizontal = col_2nd - col_1st;
    var mvVertical = row_2nd - row_1st;
    print("findRoute $row_1st, $col_1st -> $row_2nd, $col_2nd");
    var absHorizontal = 0,
        absVertical = 0; //2nd 방향으로 이동한 값

    var currentRow = row_1st;
    var currentColumn = col_1st;

    answer[row_1st][col_1st] = 1;
    answer[row_2nd][col_2nd] = 1;

    applyUIWithAnswer(puzzle, answer);

    //이미 연결 되었는 지 판단
    if ((col_1st == col_2nd) && ((row_1st - row_2nd).abs()) == 1) {
      return;
    } else if ((row_1st == row_2nd) && ((col_1st - col_2nd).abs()) == 1) {
      return;
    }

    //연결되지 않은 경우
    //최소로 이동이 필요한 조건
    var moveDirection = [];
    int i;

    //left & right 존재
    if((row_1st - row_2nd).abs() <= 1) {
      print("left/right only");

      if(row_1st % 2 == 0 && row_2nd % 2 == 0) {
        //horizontal -> horizontal
        print("hor to hor");
        //0->2(1), 3->8(4), 7->2(-4)
        if(col_1st < col_2nd) {
          //okok
          for(i = 0 ; i < (col_1st - col_2nd).abs() - 1 ; i++) {
            moveDirection.add("right");
          }
        } else {
          //ok
          for(i = 0 ; i < (col_1st - col_2nd).abs() - 1 ; i++) {
            moveDirection.add("left");
          }
        }
      } else if(row_1st % 2 == 0 && row_2nd % 2 != 0) {
        //horizontal -> vertical
        print("hor to ver");
        //0->4(3), 2->6(3), 6->3(-3), 1->4(2)
        //4,8(4)
        if(col_1st < col_2nd) {
          //okok
          //2,3->1,5(2)
          for(i = 0 ; i < (col_1st - col_2nd).abs() ; i++) {
            moveDirection.add("right");
          }
        } else {
          //ok
          for(i = 0 ; i < (col_1st - col_2nd).abs() - 1 ; i++) {
            moveDirection.add("left");
          }
        }
      } else if(row_1st % 2 != 0 && row_2nd % 2 == 0 && !((col_1st - col_2nd).abs() <= 1)) {
        //vertical -> horizontal
        print("ver to hor");
        //0->3(3), 2->6(4), 3->1(-2)
        //4->7(2), 2->6(3), 0->3(2)
        //9->0(-8), 10->6(-4), 8->7(-1)
        if(col_1st < col_2nd) {
          //okok
          for(i = 0 ; i < (col_1st - col_2nd).abs() - 1 ; i++) {
            moveDirection.add("right");
          }
        } else {
          //ok
          for(i = 0 ; i < (col_1st - col_2nd).abs() ; i++) {
            moveDirection.add("left");
          }
        }
      } else {
        //vertical -> vertical
        print("ver to ver");
        //0->4(4), 1->4(3), 3->8(5)
        //new : 5,4->7,6(2)
        if(col_1st < col_2nd) {
          //ok
          for(i = 0 ; i < (col_1st - col_2nd).abs() ; i++) {
            moveDirection.add("right");
          }
        } else {
          //ok
          for(i = 0 ; i < (col_1st - col_2nd).abs() ; i++) {
            moveDirection.add("left");
          }
        }
      }
    }

    //up & down 존재
    else if((col_1st - col_2nd).abs() <= 1) {
      print("up/down only");

    }
    //모두 존재
    else {
      print("all exist");

    }

    print("moveDirection : $moveDirection");
  }

  static void innerFindRoute(List<List<SquareBox>> puzzle, List<List<int>> answer, row_1st, col_1st, row_2nd, col_2nd) {
    var mvHorizontal = col_2nd - col_1st;
    var mvVertical = row_2nd - row_1st;
    print("findRoute $row_1st, $col_1st -> $row_2nd, $col_2nd");
    var absHorizontal = 0, absVertical = 0; //2nd 방향으로 이동한 값

    var currentRow = row_1st;
    var currentColumn = col_1st;

    answer[row_1st][col_1st] = 1;
    answer[row_2nd][col_2nd] = 1;

    applyUIWithAnswer(puzzle, answer);

    //이미 연결 되었는 지 판단
    if((col_1st == col_2nd) && ((row_1st - row_2nd).abs()) == 1) {
      return;
    } else if((row_1st == row_2nd) && ((col_1st - col_2nd).abs()) == 1) {
      return;
    }

    //연결되지 않은 경우
    //최소로 이동이 필요한 조건
    var moveDirection = [];
    int i;

    //8,9 -> 10,6 (right * 2, up * 1)
    //0,6 -> 9,1 (left * 4, down * 4)
    //4,0 -> 8,4 (right * 2, down * 2)
    //0,9 -> 7,8 (down * 3)
    //0,3 -> 1,5 (right * 2)

    //col1 - col2의 절대값이 1이하이면 left/right 없음
    //row1 - row2의 절대값이 1이하이면 up/down 없음
    if((row_1st - row_2nd).abs() <= 1) {
      //left & right만 존재
      print("left/right only");

      if(row_1st % 2 == 0 && row_2nd % 2 == 0) {
        //horizontal -> horizontal
        //print("hor to hor");
        //0->2(1), 3->8(4), 7->2(-4)
        if(col_1st < col_2nd) {
          //ok
          for(i = 0 ; i < (col_1st - col_2nd).abs() - 1 ; i++) {
            moveDirection.add("right");
          }
        } else {
          //ok
          for(i = 0 ; i < (col_1st - col_2nd).abs() - 1 ; i++) {
            moveDirection.add("left");
          }
        }
      } else if(row_1st % 2 == 0 && row_2nd % 2 != 0) {
        //horizontal -> vertical
        //print("hor to ver");
        //0->4(3), 2->6(3), 6->3(-3), 1->4(2)
        //4,8(4)
        if(col_1st < col_2nd) {
          //ok
          //2,3->1,5(2)
          for(i = 0 ; i < (col_1st - col_2nd).abs() ; i++) {
            moveDirection.add("right");
          }
        } else {
          //ok
          for(i = 0 ; i < (col_1st - col_2nd).abs() - 1 ; i++) {
            moveDirection.add("left");
          }
        }
      } else if(row_1st % 2 != 0 && row_2nd % 2 == 0 && !((col_1st - col_2nd).abs() <= 1)) {
        //vertical -> horizontal
        //print("ver to hor");
        //0->3(3), 2->6(4), 3->1(-2)
        //4->7(2), 2->6(3), 0->3(2)
        //9->0(-8), 10->6(-4), 8->7(-1)
        if(col_1st < col_2nd) {
          //ok
          for(i = 0 ; i < (col_1st - col_2nd).abs() - 1 ; i++) {
            moveDirection.add("right");
          }
        } else {
          //ok
          for(i = 0 ; i < (col_1st - col_2nd).abs() ; i++) {
            moveDirection.add("left");
          }
        }
      } else {
        //vertical -> vertical
        //print("ver to ver");
        //0->4(4), 1->4(3), 3->8(5)
        //new : 5,4->7,6(2)
        if(col_1st < col_2nd) {
          //ok
          for(i = 0 ; i < (col_1st - col_2nd).abs() ; i++) {
            moveDirection.add("right");
          }
        } else {
          //ok
          for(i = 0 ; i < (col_1st - col_2nd).abs() ; i++) {
            moveDirection.add("left");
          }
        }
      }
    } else if((col_1st - col_2nd).abs() <= 1) {
      //up & down만 존재
      print("up/down only");

      if(row_1st % 2 == 0 && row_2nd % 2 == 0) {
        //horizontal -> horizontal
        //print("hor to hor");
        //2->8(3), 0->4(2), 0->2(1), 0->6(3)
        if(row_1st < row_2nd) {
          //ok
          for(i = 0 ; i < (row_1st - row_2nd).abs() / 2 ; i++) {
            moveDirection.add("down");
          }
        } else {
          //ok
          for(i = 0 ; i < (row_1st - row_2nd).abs() / 2 ; i++) {
            moveDirection.add("up");
          }
        }
      } else if(row_1st % 2 == 0 && row_2nd % 2 != 0) {
        //horizontal -> vertical
        //print("hor to ver");
        //2->7(2), 0->3(1), 6->9(1), 6->3(-1), 4->9(2)
        //2.5 1.5 1.5 1.5 2.5

        if(row_1st < row_2nd) {
          //ok
          for(i = 0 ; i < ((row_1st - row_2nd).abs() / 2).toInt() ; i++) {
            moveDirection.add("down");
          }
        } else {
          //ok
          for(i = 0 ; i < ((row_1st - row_2nd).abs() / 2).toInt() ; i++) {
            moveDirection.add("up");
          }
        }
      } else if(row_1st % 2 != 0 && row_2nd % 2 == 0 && !((row_1st - row_2nd).abs() <= 1)) {
        //vertical -> horizontal
        //print("ver to hor");
        //1->6(2), 7->10(1), 7->0(-3)
        //2.5 1.5 3.5

        if(row_1st < row_2nd) {
          //ok
          for(i = 0 ; i < ((row_1st - row_2nd).abs() / 2).toInt() ; i++) {
            moveDirection.add("down");
          }
        } else {
          //ok
          for(i = 0 ; i < ((row_1st - row_2nd).abs() / 2).toInt() ; i++) {
            moveDirection.add("up");
          }
        }
      } else {
        //vertical -> vertical
        //print("ver to ver");
        //7->3(-1), 3->9(2), 5->9(1), 7->1(-2), 3->7(1)
        //2 3 2 3 2

        if(row_1st < row_2nd) {
          //ok
          for(i = 0 ; i < ((row_1st - row_2nd).abs() / 2).toInt() - 1 ; i++) {
            moveDirection.add("down");
          }
        } else {
          //ok
          for(i = 0 ; i < ((row_1st - row_2nd).abs() / 2).toInt() - 1 ; i++) {
            moveDirection.add("up");
          }
        }
      }
    } else {
      //모두 존재
      int j;
      print("@@@ all exist @@@");

      if(row_1st % 2 == 0 && row_2nd % 2 == 0) {
        //horizontal -> horizontal
        print("hor to hor");
        //6,6->10,0(2,-4), 6,7->8,5(1,-1)


      } else if(row_1st % 2 == 0 && row_2nd % 2 != 0) {
        //horizontal -> vertical
        print("hor to ver");
        //8,0->5,4(-1,3)


      } else if(row_1st % 2 != 0 && row_2nd % 2 == 0 && !((row_1st - row_2nd).abs() <= 1)) {
        //vertical -> horizontal
        print("ver to hor");
        //5,10->0,4(-2,-6), 9,5->6,7(-1,1), 5,7->0,3(-2,-4)
        //5,0->8,8(1,7)

        if(row_1st < row_2nd) {
          for(i = 0 ; i < ((row_1st - row_2nd).abs() / 2).toInt() ; i++) {
            moveDirection.add("down");
          }
        } else {
          for(i = 0 ; i < ((row_1st - row_2nd).abs() / 2).toInt() ; i++) {
            moveDirection.add("up");
          }
        }

      } else {
        //vertical -> vertical
        print("ver to ver");
        //3,9->7,7(1,-2), 5,4->7,6(

      }
    }

    print("dir : $moveDirection");

    applyUIWithAnswer(puzzle, answer);
  }

  static void hardApplyUI(List<List<SquareBox>> puzzle) {
    var answerWidthMin = puzzle[0].length;   //10 ,11, 10, 11...
    var answerHeight = puzzle.length * 2 + 1; //3, 5, 7, 9...

    List<List<int>> answer = List.generate(answerHeight,
            (index) => List<int>.filled((index % 2 == 0 ? answerWidthMin : answerWidthMin + 1), 0));

    /*
    var row = 9;

    answer[row][0] = 1;
    answer[row][1] = 2;
    answer[row][2] = -2;

    answer[row][3] = 1;
    answer[row][4] = 2;
    answer[row][5] = -2;

    answer[row][6] = 1;
    answer[row][7] = 2;
    answer[row][8] = -2;

    answer[row][9] = 1;
    answer[row][10] = 2;
    */
    /*
    var col = 1;

    answer[0][col] = 1;
    answer[1][col] = 1;
    answer[2][col] = 1;

    answer[3][col] = 2;
    answer[4][col] = 2;
    answer[5][col] = 2;

    answer[6][col] = -2;
    answer[7][col] = -2;
    answer[8][col] = -2;

    answer[9][col] = 1;
    answer[10][col] = 1;
    */

    int lineType;

    for(int i = 0 ; i < answer.length ; i++) {
      for (int j = 0; j < answer[i].length; j++) {
        if(answer[i][j] == 0) {
          continue;
        }
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
          } else {
            if(j == 0) {
              puzzle[(i - 1) ~/ 2][0].left = lineType;
            } else {
              puzzle[(i - 1) ~/ 2][0].right = lineType;
            }
          }
        } else {            //down, right 2개 존재
          if(i % 2 == 0) {
            puzzle[(i - 1) ~/ 2][j].down = lineType;
          } else {
            puzzle[(i - 1) ~/ 2][j - 1].right = lineType;
          }
        }

      }
    }
  }
  static void applyUIWithAnswer2(List<List<SquareBox>> puzzle, List<List<int>> answer) {
    //var answerWidthMin = puzzle[0].length;   //10 ,11, 10, 11...
    //var answerHeight = puzzle.length * 2 + 1; //3, 5, 7, 9...

    int lineType;

    for(int i = 0 ; i < answer.length ; i++) {
      for (int j = 0; j < answer[i].length; j++) {
        if(answer[i][j] == 0) {
          continue;
        }
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
          } else {
            if(j == 0) {
              puzzle[(i - 1) ~/ 2][0].left = lineType;
            } else {
              puzzle[(i - 1) ~/ 2][0].right = lineType;
            }
          }
        } else {            //down, right 2개 존재
          if(i % 2 == 0) {
            puzzle[(i - 1) ~/ 2][j].down = lineType;
          } else {
            puzzle[(i - 1) ~/ 2][j - 1].right = lineType;
          }
        }

      }
    }
  }

  //테스트 용 메소드
  static void applyUIWithAnswer(List<List<SquareBox>> puzzle, List<List<int>> answer) {
    int i, j;

    for(i = 0 ; i < answer.length ; i++) {
      for(j = 0 ; j < answer[i].length ; j++) {
        //UI에 적용이 필요한 경우
        if(answer[i][j] == 1) {

          if(i <= 2 && j <= 1) {    //up, down, left, right 모두 존재
            if(i == 0) {
              puzzle[0][0].up = 1;
            } else if(i == 1){
              if(j == 0) {
                puzzle[0][0].left = 1;
              } else {
                puzzle[0][0].right = 1;
              }
            } else {
              puzzle[0][0].down = 1;
            }
          } else if(i <= 2) {       //up, down, right 3개 존재
            if(i == 0) {
              puzzle[0][(j > 1) ? j - 1 : 0].up = 1;
              //0,1 -> 0, 2 -> 1, 3 -> 2, 4 -> 3
            } else if(i == 1) {
              puzzle[0][(j > 1) ? j - 1 : 0].right = 1;
            } else {
              puzzle[0][j].down = 1;
            }
          } else if(j <= 1) {       //down, left, right 3개 존재
            if(i % 2 == 0) {
              puzzle[(i <= 2) ? 0 : (i - 1) ~/ 2][0].down = 1;
              //2로 나눈 몫 + 나머지는 버림
              //0,1,2 -> 0, 3,4 -> 1, 5,6 -> 2, 7,8 -> 3, 9,10 -> 4
            } else {
              if(j == 0) {
                puzzle[(i <= 2) ? 0 : (i - 1) ~/ 2][0].left = 1;
              } else {
                puzzle[(i <= 2) ? 0 : (i - 1) ~/ 2][0].right = 1;
              }
            }
          } else {                  //down, right 2개 존재
            if(i % 2 == 0) {
              puzzle[(i <= 2) ? 0 : (i - 1) ~/ 2][(j > 1) ? j - 1 : 0].down = 1;
            } else {
              puzzle[(i <= 2) ? 0 : (i - 1) ~/ 2][j].right = 1;
            }
          }
        }
      }
    }
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