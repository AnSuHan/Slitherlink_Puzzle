import 'package:flutter/material.dart';
import '../Scene/GameSceneStateSquare.dart';
import 'ReadPuzzleData.dart';
import '../widgets/SquareBox.dart';

class ReadSquare {
  static late List<List<SquareBox>> puzzle;
  static late List<List<bool>> data;
  static late ReadPuzzleData read;
  final filename = "square.json";

  bool checkCycle() {
    puzzle = GameSceneStateSquare.getPuzzle();

    return false;
  }

  Future<void> savePuzzle() async {
    try {
      read;
    } catch (e) {
      read = ReadPuzzleData();
    }

    puzzle = GameSceneStateSquare.getPuzzle();
    data = List.generate(puzzle.length * 2 + 1, (index) => List.filled(puzzle[0].length, false));
    //10, 20, 20
    //print("Call savePuzzle ${puzzle.length} ${puzzle[0].length} ${puzzle[1].length}");

    for(int i = 0 ; i < puzzle.length ; i++) {
      for(int j = 0 ; j < puzzle[i].length ; j++) {
        //down, right
        if(i != 0 && j != 0) {
          //start from 0,0
          //1,1 => R(3,2)&D(4,1)
          //2,5 => R(5,6)&D(6,5)  //3,2 => R(7,3)&D(8,2)
          if(puzzle[i][j].down == 1) {
            data[(i + 1) * 2][j] = true;
          }
          if(puzzle[i][j].right == 1) {
            data[(i * 2) + 1][j + 1] = true;
          }
        }
        //up, down, right
        else if(j != 0) {
          if(puzzle[i][j].up == 1) {
            data[i][j] = true;
          }
          if(puzzle[i][j].down == 1) {
            data[i + 2][j] = true;
          }
          if(puzzle[i][j].right == 1) {
            data[i + 1][j + 1] = true;
          }
        }
        //down, left, right
        else if(i != 0) {
          if(puzzle[i][j].down == 1) {
            //1=>4, 2=>6, 3=>8 //x*2+2
            data[i * 2 + 2][j] = true;
          }
          //2=>5, 3=>7
          if(puzzle[i][j].left == 1) {
            data[i * 2 + 1][j] = true;
          }
          if(puzzle[i][j].right == 1) {
            data[i * 2 + 1][j + 1] = true;
          }
        }
        //up, down, left, right
        else {
          if(puzzle[i][j].up == 1) {
            data[i][j] = true;
          }
          if(puzzle[i][j].down == 1) {
            data[i + 2][j] = true;
          }
          if(puzzle[i][j].left == 1) {
            data[i + 1][j] = true;
          }
          if(puzzle[i][j].right == 1) {
            data[i + 1][j + 1] = true;
          }
        }
      }
    }
    //printData();
    try {
      await read.writeData(data, filename);
    } catch (e) {
      print("EXCEPTION $e");
    }

  }
  Future<List<List<int>>> loadPuzzle() async {
    try {
      read;
    } catch (e) {
      read = ReadPuzzleData();
    }

    data = await read.readData(filename);
    //printData();
    return data.map((row) => row.map((b) => b ? 1 : 0).toList()).toList();
  }

  /*
  Future<List<List<int>>> getAnswer() async {
    await loadPuzzle();
    List<List<int>> intData = data.map((row) => row.map((b) => b ? 1 : 0).toList()).toList();
    return intData;
  }
   */

  /*
  Future<List<List<SquareBox>>> applyData() async {
    await loadPuzzle();
    print("applyData");
    printData();

    int lineType;

    for(int i = 0 ; i < data.length ; i++) {      //10 ,11, 10, 11...
      for (int j = 0; j < data[i].length; j++) {  //3, 5, 7, 9...
        lineType = data[i][j] ? 1 : 0;
        //print("i : $i, j : $j, lineType : $lineType");

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
            if ((i ~/ 2 + 1) < puzzle.length && puzzle[(i ~/ 2 + 1)].isNotEmpty) {
              if(j == 0) {
                puzzle[i ~/ 2 + 1][0].left = lineType;
              } else {
                puzzle[i ~/ 2 + 1][0].right = lineType;
              }
            }
          }
        } else {            //down, right 2개 존재
          if(i % 2 == 0) {
            if ((i - 1) ~/ 2 < puzzle.length && j + 1 < puzzle[(i - 1) ~/ 2].length) {
              puzzle[(i - 1) ~/ 2][j + 1].down = lineType;
            }
          } else {
            if ((i - 1) ~/ 2 < puzzle.length && j < puzzle[(i - 1) ~/ 2].length) {
              puzzle[(i - 1) ~/ 2][j].right = lineType;
            }
          }
        }

      }
    }

    /*
    for (int i = 0; i < data.length; i++) {
      for (int j = 0; j < data[i].length; j++) {
        if (((i == 0 || i == 2) && j == 0)
            || (i == 1 && j < 2)) {
          switch(i) {
            case 0:
              puzzle[0][0].up = 1;
              break;
            case 1:
              if(j == 0) {
                puzzle[0][0].left = 1;
              } else {
                puzzle[0][0].right = 1;
              }
              break;
            default:
              puzzle[0][0].down = 1;
          }

        }
        else if (i < 3) {

        }
        else if (j < 2) {

        }
        else {

        }

      }
    }
    */

    return puzzle;
  }
  */

  void printData() {
    for(int i = 0 ; i < data.length ; i++) {
      print("row $i ${data[i]}");
    }
  }
}