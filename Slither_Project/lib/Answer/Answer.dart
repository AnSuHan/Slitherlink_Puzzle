import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import '../User/UserInfo.dart';

class Answer {
  bool isFinishInit = false;

  Answer({
    BuildContext? context
  }) {
    initPuzzleAll().then((_) {
      isFinishInit = true;
    });
  }

  List<List<List<bool>>> squareSmallAnswer = [];

  Future<void> initPuzzleAll() async {
    List<String> type = ["square"];
    List<String> size = ["small"];

    for(int i = 0 ; i < type.length ; i++) {
      for(int j = 0 ; j < size.length ; j++) {
        await initPuzzle(type[i], size[i]);
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

    final file = File(filename);
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

  List<List<List<bool>>> squareAnswer = [
    //show edge test
    [
      List.filled(20, true), List.filled(21, true), List.filled(20, true), List.filled(21, true), List.filled(20, true),
      List.filled(21, true), List.filled(20, true), List.filled(21, true), List.filled(20, true), List.filled(21, true),
      List.filled(20, true), List.filled(21, true), List.filled(20, true), List.filled(21, true), List.filled(20, true),
      List.filled(21, true), List.filled(20, true), List.filled(21, true), List.filled(20, true), List.filled(21, true),
      List.filled(20, true)
    ],
    //square_small_0
    [
      [false, false, true, false, true, true, true, true, true, false, false, true, false, true, true, true, true, false, false, true],
      [false, false, true, true, true, false, false, false, false, true, false, true, true, true, false, false, false, true, false, true, true],
      [false, true, false, false, true, true, false, true, false, true, true, false, false, true, false, true, true, false, true, false],
      [false, true, false, true, false, false, true, true, true, false, false, false, true, false, true, true, false, false, true, false, true],
      [false, true, false, true, true, false, true, false, false, true, true, false, true, true, false, false, true, true, false, true],
      [false, false, true, false, false, true, false, false, true, true, false, true, false, false, false, true, true, false, false, true, false],
      [true, true, false, true, false, true, true, true, false, true, false, true, true, false, false, false, true, true, false, true],
      [true, false, false, true, true, false, false, false, false, false, true, false, false, true, false, true, false, false, true, false, true],
      [true, false, true, false, false, true, true, false, true, true, false, true, false, true, false, true, false, false, false, true],
      [false, true, true, false, true, true, false, true, true, false, false, true, true, false, true, false, true, false, true, true, false],
      [true, false, false, false, true, false, false, false, false, true, false, false, false, false, true, false, true, true, false, false],
      [true, false, true, false, false, false, false, true, true, true, true, true, true, false, false, true, false, false, false, true, false],
      [false, false, false, true, true, false, true, false, false, false, false, false, false, true, true, false, false, true, true, false],
      [true, false, true, true, false, true, true, false, true, true, true, true, true, true, false, false, false, true, false, false, false],
      [true, false, true, false, false, false, false, false, false, false, true, false, false, false, false, true, false, true, true, false],
      [false, true, false, false, false, true, true, false, true, true, false, false, true, true, false, true, true, false, false, true, false],
      [false, false, true, false, true, false, true, false, true, false, true, true, false, false, false, false, true, true, false, true],
      [false, true, true, true, true, false, false, true, false, false, true, false, false, true, false, true, false, false, true, false, true],
      [false, false, false, true, false, true, true, false, true, false, true, false, false, true, false, true, true, false, false, true],
      [false, true, true, false, false, true, false, false, true, true, false, true, false, false, true, false, false, true, true, true, false],
      [false, true, false, false, false, true, true, true, false, true, true, false, false, false, true, true, true, false, true, false]
    ],
    //square_small_1
    [
      [false, true, true, true, true, false, false, true, true, false, false, true, true, true, false, false, true, true, true, false],
      [false, true, false, false, false, true, false, true, false, true, false, true, false, false, true, false, true, false, false, true, false],
      [true, false, true, true, false, true, false, false, true, false, false, false, true, true, false, false, false, true, true, false],
      [true, false, true, false, true, false, true, true, true, false, false, true, true, false, false, false, true, true, false, false, false],
      [true, false, false, false, true, false, true, false, true, false, true, false, true, true, true, true, false, true, false, true],
      [false, true, true, false, false, true, false, false, false, true, true, false, false, false, false, false, false, false, true, true, true],
      [true, false, true, true, false, false, true, false, false, false, false, true, true, true, false, true, true, false, true, false],
      [true, false, false, false, true, true, true, true, false, true, true, true, false, false, true, true, false, true, false, false, true],
      [true, false, false, false, false, true, false, true, false, true, false, true, true, false, true, false, true, false, false, true],
      [false, true, false, false, true, false, false, false, true, false, false, false, false, true, false, false, true, false, false, true, false],
      [false, true, true, false, true, true, true, false, true, true, true, false, true, false, true, false, false, true, false, false],
      [false, false, false, true, false, false, false, true, false, false, false, true, true, false, true, true, true, true, true, true, false],
      [true, true, true, false, true, false, true, false, false, true, false, false, false, true, false, false, true, false, false, true],
      [true, false, false, false, true, true, true, false, false, true, true, true, true, true, false, true, false, false, true, false, true],
      [false, true, false, true, false, true, false, false, true, false, true, false, false, false, true, false, false, true, false, false],
      [true, true, true, true, false, false, false, false, true, false, false, false, true, true, true, false, false, true, false, false, true],
      [false, false, false, true, true, false, true, true, false, true, true, false, true, false, true, true, false, false, false, true],
      [true, true, true, false, false, true, true, false, false, true, false, true, false, false, false, false, true, true, false, true, false],
      [false, false, false, false, true, false, true, true, false, true, false, true, true, true, false, false, false, true, false, true],
      [true, true, true, false, true, false, false, false, true, false, true, false, false, false, true, false, true, false, true, false, true],
      [true, false, true, true, false, false, false, false, true, true, false, false, false, false, true, true, false, false, true, true]
    ],
    //square_small_2
    [
      [true, false, false, true, false, true, true, true, false, false, false, true, true, true, false, false, false, true, true, true],
      [true, true, false, true, true, true, false, false, true, false, false, true, false, false, true, false, false, true, false, false, true],
      [false, true, true, false, false, true, true, false, true, true, false, true, true, false, false, true, false, true, true, false],
      [true, false, false, false, true, false, false, true, false, false, true, false, false, true, true, true, true, false, false, true, true],
      [true, false, true, true, false, true, false, false, true, true, false, true, true, false, true, false, true, false, false, false],
      [false, true, true, false, false, true, true, true, true, false, false, true, false, false, false, false, false, true, false, true, true],
      [false, false, true, true, true, false, true, false, false, true, true, false, true, false, true, true, true, false, true, false],
      [false, true, false, false, false, false, false, false, true, true, false, false, true, true, true, false, false, false, true, false, true],
      [true, false, true, false, false, true, true, false, false, true, false, true, false, true, false, true, true, false, false, true],
      [true, false, true, true, false, true, false, true, true, false, true, true, false, false, false, true, false, true, true, true, false],
      [true, false, false, true, false, true, false, false, true, true, false, true, true, true, true, false, false, true, false, true],
      [false, true, true, false, true, false, true, true, false, false, false, false, false, false, false, false, false, false, false, false, true],
      [false, false, true, false, true, true, false, true, false, false, true, false, false, true, true, true, true, false, true, true],
      [false, true, false, true, false, false, false, false, true, false, true, true, false, true, false, false, false, true, true, false, false],
      [true, false, true, false, false, true, true, false, true, false, false, true, true, false, true, true, false, false, true, true],
      [true, false, true, false, false, true, false, true, false, true, true, false, false, false, true, false, true, true, false, false, true],
      [true, false, true, true, true, false, true, false, false, false, true, false, true, true, false, false, false, true, true, false],
      [false, true, false, false, false, false, true, false, false, true, false, true, true, false, false, false, true, false, false, true, true],
      [true, false, true, false, true, false, true, true, false, true, false, false, true, false, true, false, true, true, true, false],
      [true, false, true, true, true, true, false, false, true, false, true, true, false, true, true, true, false, false, false, false, true],
      [true, true, false, true, false, true, true, true, false, false, true, false, false, true, false, true, true, true, true, true]
    ],
    //square_small_3
    [
      [true, true, true, true, true, false, true, false, false, true, false, true, true, true, false, true, true, true, true, false],
      [true, false, false, false, false, true, true, true, false, true, true, true, false, false, true, true, false, false, false, true, false],
      [false, true, true, true, false, false, false, true, true, false, false, true, true, false, false, true, true, false, false, true],
      [true, true, false, false, true, true, true, false, false, false, true, false, false, true, true, false, false, true, false, false, true],
      [false, false, true, true, false, false, true, false, true, false, false, true, true, false, true, false, true, false, true, false],
      [true, true, true, false, false, true, false, true, true, true, true, true, false, false, false, true, true, false, true, true],
      [true, false, true, true, false, true, false, true, false, false, true, false, true, false, true, false, false, true, false],
      [false, false, false, false, true, false, true, false, false, true, false, false, true, true, true, false, true, true, false, true, true],
      [true, true, true, false, true, false, true, true, true, false, true, true, false, false, false, true, false, false, true, false],
      [true, false, false, true, false, true, false, false, false, false, true, false, false, true, true, true, false, true, true, false, true],
      [true, true, false, true, true, false, true, false, true, true, false, true, false, true, false, false, true, false, true, true],
      [false, false, true, false, false, false, true, true, true, false, false, true, true, false, false, true, true, false, false, false],
      [true, true, false, true, true, false, false, false, false, true, true, false, false, false, true, false, true, true, true, true],
      [true, false, false, true, false, true, true, true, true, true, false, false, true, false, true, false, false, false, false, true],
      [true, false, true, false, false, true, false, false, false, false, true, false, true, true, false, true, true, true, true, false],
      [false, true, true, false, false, false, false, true, true, true, true, true, false, false, false, true, false, false, false, true, true],
      [false, false, false, true, true, false, true, false, true, false, false, true, true, false, true, false, true, true, true, false],
      [false, true, true, true, false, true, true, false, false, false, true, false, false, true, true, false, true, false, false, false, true],
      [false, false, false, true, false, true, false, true, true, false, true, true, false, false, false, false, false, true, false, false],
      [false, true, true, false, true, false, false, true, false, true, false, false, true, true, true, false, true, true, true, false, true],
      [false, true, false, false, true, true, true, false, false, true, true, true, false, true, false, false, true, false, true, true]
    ],
    //square_small_4
    [
      [true, true, true, false, true, true, false, true, true, true, true, true, true, true, true, true, true, true, true, false],
      [true, false, false, true, true, false, true, true, false, false, false, false, false, false, false, false, false, false, false, true, false],
      [true, true, false, true, false, false, true, false, true, true, true, true, true, false, true, true, true, true, false, true],
      [false, false, true, false, false, false, false, false, true, false, false, false, false, true, true, false, false, false, true, false, true],
      [false, false, false, true, true, true, false, false, true, true, true, true, false, false, true, true, false, false, true, false],
      [false, false, true, true, false, false, true, false, false, false, false, false, true, true, false, false, true, false, false, true, true],
      [true, true, false, true, true, false, true, false, true, true, true, false, false, true, true, false, true, false, true, false],
      [true, false, false, false, false, true, false, true, true, false, false, true, true, false, false, true, false, true, true, false, true],
      [false, true, false, true, true, false, true, false, false, false, false, false, true, true, false, false, false, false, false, true],
      [true, true, true, true, false, false, true, false, true, false, false, true, false, false, true, true, false, true, true, true, false],
      [false, false, true, false, true, false, true, false, true, false, true, false, true, true, false, false, true, false, false, true],
      [true, true, false, false, true, true, false, true, false, true, true, false, true, false, false, true, true, false, true, false, true],
      [false, true, true, false, false, true, false, false, true, false, true, false, true, false, true, false, false, true, false, true],
      [true, false, false, true, true, false, true, true, true, false, false, true, false, true, true, false, true, true, false, true, false],
      [false, false, true, false, true, false, true, false, false, true, false, true, true, false, true, true, false, false, true, false],
      [true, false, true, false, false, true, false, false, true, true, true, false, false, false, false, false, false, true, true, false, false],
      [true, false, false, true, true, false, false, true, false, false, true, false, true, true, true, true, true, false, true, true],
      [false, true, true, true, false, false, false, true, false, true, false, true, true, false, false, false, false, false, false, false, true],
      [true, false, false, false, true, true, false, false, true, false, false, true, false, true, false, false, true, false, true, false],
      [true, false, true, true, true, false, true, true, true, false, false, false, false, true, true, false, true, true, true, true, true],
      [true, true, false, true, false, false, true, false, true, true, true, true, true, false, true, true, false, true, false, true]
    ],
  ];

  final List<List<int>> directions = [
    [-1, 0], [1, 0], [0, -1], [0, 1],  // up, down, left, right
    [-1, -1], [-1, 1], [1, -1], [1, 1]  // diagonals
  ];

  bool isValid(int row, int col, List<List<bool>> matrix) {
    return row >= 0 && row < matrix.length && col >= 0 && col < matrix[0].length;
  }

  bool dfs(int row, int col, List<List<bool>> matrix, Set<String> visited, int parentRow, int parentCol) {
    String key = '$row,$col';
    visited.add(key);

    for (var direction in directions) {
      int newRow = row + direction[0];
      int newCol = col + direction[1];

      // Skip the parent cell to avoid trivial cycle
      if (newRow == parentRow && newCol == parentCol) continue;

      if (isValid(newRow, newCol, matrix) && matrix[newRow][newCol]) {
        String newKey = '$newRow,$newCol';
        if (visited.contains(newKey)) {
          return true;  // Cycle detected
        }
        if (dfs(newRow, newCol, matrix, visited, row, col)) {
          return true;  // Cycle detected in recursion
        }
      }
    }

    return false;
  }

  bool hasCycle(List<List<bool>> matrix) {
    Set<String> visited = HashSet<String>();

    for (int row = 0; row < matrix.length; row++) {
      for (int col = 0; col < matrix[0].length; col++) {
        if (matrix[row][col]) {
          String key = '$row,$col';
          if (!visited.contains(key)) {
            if (dfs(row, col, matrix, visited, -1, -1)) {
              return true;
            }
          }
        }
      }
    }

    return false;
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

  Future<void> _waitForInitialization() async {
    while (!isFinishInit) {
      await Future.delayed(const Duration(milliseconds: 100));
    }
  }
}