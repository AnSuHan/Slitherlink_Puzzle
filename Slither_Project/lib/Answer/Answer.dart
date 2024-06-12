import 'dart:collection';

import 'package:flutter/cupertino.dart';

import '../User/UserInfo.dart';

class Answer {
  Answer({
    BuildContext? context
  });

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
  bool checkRemainPuzzle(BuildContext context, String shape, String size) {
    bool rtValue = false;
    String key = "";

    if(shape.compareTo("square") == 0 && size.compareTo("small") == 0) {
      key = "square_small";
      if(squareAnswer.length - 1 > UserInfo.getProgress(key)) {
        rtValue = true;
      }
    }

    return rtValue;
  }

  List<List<bool>> getSquare(int index) {
    if(index < squareAnswer.length) {
      return squareAnswer[index];
    }
    return [];
  }
}