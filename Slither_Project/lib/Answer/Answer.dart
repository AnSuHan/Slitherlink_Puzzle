// ignore_for_file: file_names
import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import '../User/UserInfo.dart';

class Answer {
  bool isFinishInit = false;
  bool showCycle = false;

  Answer({
    BuildContext? context
  }) {
    ///hot load don't apply changes in json files
    initPuzzleAll().then((_) {
      isFinishInit = true;
      showCycle = UserInfo.debugMode["Answer_showCycle"]!;
      if(showCycle) {
        checkDuplicateAll();
        checkCycleSquareAll();
      }
    });
  }

  List<List<List<bool>>> squareSmallAnswer = [];
  List<List<List<bool>>> squareSmallTestAnswer = [];

  Future<void> initPuzzleAll() async {
    List<String> type = ["square"];
    List<String> size = ["small"];
    bool loadTest = UserInfo.debugMode["loadTestAnswer"]!;

    for(int i = 0 ; i < type.length ; i++) {
      for(int j = 0 ; j < size.length ; j++) {
        loadTest ? await initTestPuzzle(type[i], size[i]) : await initPuzzle(type[i], size[i]);
      }
    }
  }

  Future<void> initPuzzle(String type, String size) async {
    String filename = "lib/Answer/";
    switch(type) {
      case "square":
        switch(size) {
          case "small":
            filename += "Square_small.json";
            break;
        }
        break;
    }

    String jsonString = await rootBundle.loadString(filename);
    Map<String, dynamic> jsonData = jsonDecode(jsonString);

    jsonData.forEach((key, value) {
      if (!key.endsWith("_test")) {
        // 데이터 변환: 1 -> true, 0 -> false
        List<List<bool>> convertedList = (value as List)
            .map((list) => (list as List)
            .map((item) => item == 1 ? true : false).toList()).toList();
        squareSmallAnswer.add(convertedList);
      }
    });
  }

  //for using test answer
  Future<void> initTestPuzzle(String type, String size) async {
    String filename = "lib/Answer/";
    switch(type) {
      case "square":
        switch(size) {
          case "small":
            filename += "Square_small.json";
            break;
        }
        break;
    }

    String jsonString = await rootBundle.loadString(filename);
    Map<String, dynamic> jsonData = jsonDecode(jsonString);

    jsonData.forEach((key, value) {
      if (!key.endsWith("_test")) {
        // 데이터 변환: 1 -> true, 0 -> false
        List<List<bool>> convertedList = (value as List)
            .map((list) => (list as List)
            .map((item) => item == 1 ? true : false).toList()).toList();
        squareSmallAnswer.add(convertedList);
      }
      else {
        // 데이터 변환: 1 -> true, 0 -> false
        List<List<bool>> convertedList = (value as List)
            .map((list) => (list as List)
            .map((item) => item == 1 ? true : false).toList()).toList();
        squareSmallTestAnswer.add(convertedList);
      }
    });
  }

  void checkCycleSquareAll() {
    List<String> size = ["small"];
    List<List<List<bool>>> squareAnswer = [];
    List<bool> squareCycle = [];

    for(int i = 0 ; i < size.length ; i++) {
      switch(size[i]) {
        case "small":
          squareAnswer = squareSmallAnswer.map((list2D) => list2D.map((list1D) => List<bool>.from(list1D)).toList()).toList();
          break;
      }

      //check cycle
      int index;  //each puzzle
      for(index = 0 ; index < squareAnswer.length ; index++) {
        squareCycle.add(checkCycleSquare(squareAnswer[index]));
      }
      // ignore: avoid_print
      print("check square_${size[i]} Cycle : $squareCycle");
    }
  }

  bool checkCycleSquare(List<List<bool>> squareAnswer) {
    // 방문 상태를 저장할 배열
    List<List<bool>> visited = List.generate(
        squareAnswer.length, (i) => List.generate(squareAnswer[i].length, (_) => false)
    );

    int? startRow, startCol;
    bool found = false;
    // DFS는 한 번만 호출 (재귀 호출 제외)
    for (int i = 0; i < squareAnswer.length; i++) {
      for (int j = 0; j < squareAnswer[i].length; j++) {
        if (squareAnswer[i][j] && !visited[i][j]) {
          startRow = i;
          startCol = j;
          found = true;
          break;
        }
      }
      if(found) {
        break;
      }
    }

    if (dfs(squareAnswer, visited, startRow!, startCol!, -1, -1)) {
      return true;
    }

    return false;
  }

  bool dfs(List<List<bool>> squareAnswer, List<List<bool>> visited, int x, int y, int parentX, int parentY) {
    //print("dfs : $x, $y | $parentX, $parentY");
    int rows = squareAnswer.length;

    // 방향 벡터 (상, 하, 좌, 우)
    List<List<int>> evenDirections = [
      [-1, 0], // 상1
      [-1, 1], // 상2
      [1, 0],  // 하1
      [1, 1],  // 하2
      [0, -1], // 좌
      [0, 1]   // 우
    ];

    List<List<int>> oddDirections = [
      [-2, 0],  // 상
      [2, 0],   // 하
      [-1, -1], // 좌1
      [1, -1],  // 좌2
      [-1, 0],  // 우1
      [1, 0],   // 우2
    ];

    visited[x][y] = true;

    //방문한 라인을 제거하면 direction은 반드시 하나로 정해진다
    for (var direction in x % 2 == 0 ? evenDirections : oddDirections) {
      int newX = x + direction[0];
      int newY = y + direction[1];

      // 경계를 넘어가거나 현재 위치와 같은 위치로 이동하지 않도록 체크
      if (newX < 0 || newX >= rows || newY < 0 || newY >= (newX < squareAnswer.length ? squareAnswer[newX].length : 0)) {
        continue;
      }

      if (squareAnswer[newX][newY]) {
        if (!visited[newX][newY]) {
          // 재귀 호출
          if (dfs(squareAnswer, visited, newX, newY, x, y)) {
            return true;
          }
        } else if (newX != parentX || newY != parentY) {
          // 이미 방문한 노드가 부모 노드가 아닌 경우 사이클 발견
          return true;
        }
      }
    }

    return false;
  }

  Future<void> checkDuplicateAll() async {
    await checkDuplicate(squareSmallAnswer);
  }

  Future<void> checkDuplicate(List<List<List<bool>>> answer) async {
    List<List<double>> matrix = List.generate(answer.length, (_) => List.filled(answer.length, 0.0));
    for (int i = 0; i < answer.length; i++) {
      for (int j = i + 1; j < answer.length; j++) {
        matrix[i][j] = calculateMatchPercentage(answer[i], answer[j]);
      }
    }

    for(int i = 0 ; i < answer.length ; i++) {
      matrix[i][i] = 100.0;
    }

    for (List<double> row in matrix) {
      // ignore: avoid_print
      print(row.map((e) => e.toStringAsFixed(2)).toList());
    }
  }

  double calculateMatchPercentage(List<List<bool>> list1, List<List<bool>> list2) {
    int totalCount = 1;
    int matchCount = 0;

    for (int i = 0; i < list1.length; i++) {
      for (int j = 0; j < list1[i].length; j++) {
        totalCount++;
        if (list1[i][j] == list2[i][j]) {
          matchCount++;
        }
      }
    }

    return (matchCount / totalCount) * 100;
  }

  ///parameter is always EN
  Future<bool> checkRemainPuzzle(BuildContext context, String shape, String size) async {
    bool rtValue = false;
    String key = "";

    if(shape.compareTo("square") == 0 && size.compareTo("small") == 0) {
      key = "square_small";
      if(squareSmallAnswer.length - 1 > UserInfo.getProgress(key)) {
        rtValue = true;
      }
    }

    return rtValue;
  }

  Future<List<List<bool>>> getSquare(int index) async {
    await _waitForInitialization();

    if(index < squareSmallAnswer.length) {
      return squareSmallAnswer[index];
    }
    return [];
  }

  Future<List<List<bool>>> getTestSquare() async {
    await _waitForInitialization();
    return squareSmallTestAnswer[1];
  }

  Future<void> _waitForInitialization() async {
    while (!isFinishInit) {
      await Future.delayed(const Duration(milliseconds: 100));
    }
  }
}