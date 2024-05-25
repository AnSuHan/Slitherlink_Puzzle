// ignore: file_names
import 'dart:math';

import 'package:flutter/cupertino.dart';

class Draw {
  int row = 0;
  int col = 0;
  late List<List<int>> grid;
  List<List<int>> points = [];  //order is needed

  void init(int row, int col) {
    this.row = row;
    this.col = col;
    grid = List.generate(row, (index) =>
        List.generate(index % 2 == 0 ? col : col + 1, (_) => 0)
    );

    setPoints();
    stepFirst();
    stepSecond();
  }

  void setPoints() {
    points.add([0, 0]);
    points.add([0, grid[0].length - 1]);
    points.add([grid.length - 1, 0]);
    points.add([grid.length - 1, grid[grid.length - 1].length - 1]);
  }

  void stepFirst() {
    for(var point in points) {
      grid[point[0]][point[1]] = 1;
    }
  }

  void stepSecond() {
    //horizontal
    for(int i = 0 ; i < points.length ; i++) {
      for(int j = 0 ; j < grid[i].length ; j++) {
        grid[points[i][0]][points[i][1]] = 1;
      }
    }
  }

  List<List<int>> getGrid() {
    return grid;
  }
}

class Visit {
  int row = 10;
  int col = 10;
  //(0,0) means left&down
  List<List<int>> pos = [[0,0],[0,0]];
  List<String?> lastDir = ["", ""];
  Set<List<int>> visit = {};
  List<int> firstPoint = [0, 0];

  bool findPath() {
    //set start position
    pos[0][0] = Random().nextInt(row);
    pos[0][1] = Random().nextInt(col);
    pos[1][0] = pos[0][0];
    pos[1][1] = pos[0][1];

    visit.add(pos[0]);
    firstPoint[0] = pos[0][0];
    firstPoint[1] = pos[0][1];
    innerFindPath(pos[0], 0);
    innerFindPath(pos[1], 1);

    bool b1 = false, b2 = false;
    do {
      b1 = innerFindPath(pos[0], 0, lastDir[0]);
      b2 = innerFindPath(pos[1], 1, lastDir[1]);

      //can't find direction
      if(b1 && b2) {
        print("failed find path");
        return false;
      }
    } while(false);

    print("path : ${visit.toString()}");
    return true;
  }

  bool innerFindPath(List<int> pos, int num, [String? lastDir]) {
    //filter available direction
    Set<String> validDirection = {"left", "right", "up", "down"};
    if(pos[0] <= 0) {
      validDirection.remove("left");
    }
    else if(pos[0] >= row) {
      validDirection.remove("right");
    }
    if(pos[1] <= 0) {
      validDirection.remove("down");
    }
    else if(pos[1] >= col) {
      validDirection.remove("up");
    }

    //don't access visited point
    for (var value in validDirection) {
      switch(value) {
        case "left":
          if(visit.contains([pos[0] - 1, pos[1]])) {
            validDirection.remove(value);
          }
          break;
        case "right":
          if(visit.contains([pos[0] + 1, pos[1]])) {
            validDirection.remove(value);
          }
          break;
        case "up":
          if(visit.contains([pos[0], pos[1] + 1])) {
            validDirection.remove(value);
          }
          break;
        case "down":
          if(visit.contains([pos[0], pos[1] - 1])) {
            validDirection.remove(value);
          }
          break;
      }
    }

    //can't access direct opposite direction
    if(lastDir != null) {
      switch(lastDir) {
        case "left":
          validDirection.remove("right");
          break;
        case "right":
          validDirection.remove("left");
          break;
        case "up":
          validDirection.remove("down");
          break;
        case "down":
          validDirection.remove("up");
          break;
      }
    }

    if(validDirection.isEmpty) {
      print("can't find direction");
      return false;
    }

    List<String> dirList = validDirection.toList();
    String setDir = dirList[Random().nextInt(dirList.length)];

    //update visit list
    switch(setDir) {
      case "left":
        visit.add([pos[0] - 1, pos[1]]);

        break;
      case "right":
        visit.add([pos[0] + 1, pos[1]]);
        break;
      case "up":
        visit.add([pos[0], pos[1] + 1]);
        break;
      case "down":
        visit.add([pos[0], pos[1] - 1]);
        break;
    }

    return true;
  }
}

class AlgorithmSquare {
  HamiltonianCycle hamiltonianCycle(int n) {
    return HamiltonianCycle(n);
  }
}

class Grid {
  late List<List<bool>> grid;
  late int rows;
  late int cols;
  Random random = Random();

  Grid(int m, int n) {
    rows = m;
    cols = n;
    grid = List.generate(m, (_) => List.generate(n, (_) => false));
  }

  // 인접한 true 선분의 개수를 반환합니다.
  int countAdjacentTrue(int row, int col) {
    int count = 0;
    if (row > 0 && grid[row - 1][col]) count++;
    if (row < rows - 1 && grid[row + 1][col]) count++;
    if (col > 0 && grid[row][col - 1]) count++;
    if (col < cols - 1 && grid[row][col + 1]) count++;
    return count;
  }

  // true 선분을 랜덤하게 변경합니다.
  void setRandomTrue() {
    int row = random.nextInt(rows);
    int col = random.nextInt(cols);
    while (grid[row][col]) {
      row = random.nextInt(rows);
      col = random.nextInt(cols);
    }
    grid[row][col] = true;
  }

  // 주어진 시작 지점부터 사이클을 확인합니다.
  bool hasCycle(int startRow, int startCol) {
    List<List<bool>> visited = List.generate(rows, (_) => List.generate(cols, (_) => false));

    int currentRow = startRow;
    int currentCol = startCol;
    int countVisited = 0;

    // DFS를 사용하여 사이클을 확인합니다.
    while (!visited[currentRow][currentCol]) {
      visited[currentRow][currentCol] = true;
      countVisited++;

      // 인접한 true 선분을 탐색합니다.
      if (currentRow > 0 && grid[currentRow - 1][currentCol]) currentRow--;
      else if (currentRow < rows - 1 && grid[currentRow + 1][currentCol]) currentRow++;
      else if (currentCol > 0 && grid[currentRow][currentCol - 1]) currentCol--;
      else if (currentCol < cols - 1 && grid[currentRow][currentCol + 1]) currentCol++;
      else return false; // 인접한 true 선분이 없으면 사이클이 아닙니다.
    }

    // 사이클이 완성되려면 모든 지점을 방문해야 합니다.
    return countVisited == rows * cols;
  }
}

class Valid {
  bool isValid(List<String> path) {
    Set<List<int>> visitedPoints = {}; // 방문한 지점을 기록하는 집합
    List<int> currentPoint = [0, 0]; // 현재 위치

    bool isPathValid = true;

    for (int i = 0; i < path.length; i++) {
      // 현재 위치를 기록합니다.
      visitedPoints.add(currentPoint.toList());

      // 다음 지점을 계산합니다.
      switch (path[i]) {
        case 'left':
          currentPoint[1]--;
          break;
        case 'right':
          currentPoint[1]++;
          break;
        case 'up':
          currentPoint[0]--;
          break;
        case 'down':
          currentPoint[0]++;
          break;
      }

      // 다음 지점이 이미 방문한 지점인지 확인합니다.
      if (visitedPoints.contains(currentPoint)) {
        isPathValid = false;
        break;
      }
    }

    print('Is path valid: $isPathValid');
    return isPathValid;
  }
}

class Insert {
  List<String> generateRandomDirections2(int length) {
    List<String> directions = [];
    Random random = Random();
    Map<String, int> directionCounts = {'left': 0, 'right': 0, 'up': 0, 'down': 0};
    String? prevDirection;

    Set<int> visitedPoints = {}; // 방문한 지점을 추적하기 위한 Set

    for (int i = 0; i < length; i++) {
      List<String> availableDirections = [];

      // 각 방향별로 카운트를 확인하여 가능한 방향을 추가합니다.
      if (directionCounts['left']! < length ~/ 2) {
        availableDirections.add('left');
      }
      if (directionCounts['right']! < length ~/ 2) {
        availableDirections.add('right');
      }
      if (directionCounts['up']! < length ~/ 2) {
        availableDirections.add('up');
      }
      if (directionCounts['down']! < length ~/ 2) {
        availableDirections.add('down');
      }

      // 이전 방향과 반대되는 방향을 제거합니다.
      availableDirections.remove(prevDirection);

      // 가능한 방향 중에서 랜덤하게 선택합니다.
      String direction = availableDirections[random.nextInt(availableDirections.length)];

      // 선택한 방향에 대한 카운트를 업데이트합니다.
      directionCounts.update(direction, (value) => value + 1);

      // 다음 지점 계산
      int nextPoint = directions.length;

      // 다음 지점이 이미 방문한 지점인 경우 새로운 지점을 선택합니다.
      while (visitedPoints.contains(nextPoint)) {
        nextPoint = random.nextInt(length);
      }
      visitedPoints.add(nextPoint);

      // 방향을 추가하고 이전 방향을 갱신합니다.
      directions.add(direction);
      prevDirection = direction;
    }

    return directions;
  }

  List<String> generateRandomDirections(int length) {
    List<String> directions = [];
    Random random = Random();
    Map<String, int> directionCounts = {'left': 0, 'right': 0, 'up': 0, 'down': 0};
    String? prevDirection;

    Set<int> visitedPoints = {}; // 방문한 지점을 추적하기 위한 Set

    for (int i = 0; i < length; i++) {
      List<String> availableDirections = [];

      if (prevDirection != 'right' && directionCounts['left']! < length ~/ 2) {
        availableDirections.add('left');
      }
      if (prevDirection != 'left' && directionCounts['right']! < length ~/ 2) {
        availableDirections.add('right');
      }
      if (prevDirection != 'down' && directionCounts['up']! < length ~/ 2) {
        availableDirections.add('up');
      }
      if (prevDirection != 'up' && directionCounts['down']! < length ~/ 2) {
        availableDirections.add('down');
      }

      String direction = availableDirections[random.nextInt(availableDirections.length)];
      directions.add(direction);
      directionCounts.update(direction, (value) => value + 1);

      // 다음 지점 계산
      int nextPoint = directions.length - 1;

      // 이전에 방문한 지점이 아닌지 확인하고, 방문한 지점으로 추가
      while (visitedPoints.contains(nextPoint)) {
        nextPoint = random.nextInt(length);
      }
      visitedPoints.add(nextPoint);

      prevDirection = direction;
    }

    return directions;
  }
}

class HamiltonianCycle {
  final int n;
  late List<List<bool>> visited;
  final List<List<int>> directions = [
    [-1, 0], // up
    [1, 0],  // down
    [0, -1], // left
    [0, 1]   // right
  ];

  HamiltonianCycle(this.n) {
    visited = List.generate(n, (_) => List.generate(n, (_) => false));
  }

  bool isValidMove(int x, int y) {
    return x >= 0 && x < n && y >= 0 && y < n && !visited[x][y];
  }

  List<List<int>>? dfs(int x, int y, List<List<int>> path) {
    if (path.length == n * n) {
      if (x == 0 && y == 0) {
        return path;
      } else {
        return null;
      }
    }

    for (var dir in directions) {
      int newX = x + dir[0];
      int newY = y + dir[1];
      if (isValidMove(newX, newY)) {
        visited[newX][newY] = true;
        path.add([newX, newY]);
        var result = dfs(newX, newY, path);
        if (result != null) {
          return result;
        }
        path.removeLast();
        visited[newX][newY] = false;
      }
    }

    return null;
  }

  List<List<int>>? findHamiltonianCycle() {
    visited[0][0] = true;
    return dfs(0, 0, [[0, 0]]);
  }
}