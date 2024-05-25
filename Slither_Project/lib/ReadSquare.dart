import 'package:flutter/material.dart';
import 'GameSceneStateSquare.dart';
import 'fileAccess/ReadPuzzleData.dart';
import 'widgets/SquareBox.dart';

class ReadSquare {
  static late List<List<SquareBox>> puzzle;
  static late List<List<bool>> data;
  static late ReadPuzzleData read;
  final filename = "square.json";

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
          //1,1 => R(3,2)&D(4,1)  //3,3 => R(5,3)&D(6,2)
          //3,4 => R(5,4)&D(6,3)  //4,5 => R(7,5)&D(8,4)
          //2,2 => R(3,2)&D(4,1)  //5,4 => R(9,4)&D(10,3)
          if(puzzle[i][j].down == 1) {
            data[i <= 1 ? 4 : (i + 1) * 2][j <= 1 ? 1 : j - 1] = true;
          }
          if(puzzle[i][j].right == 1) {
            data[i <= 3 ? (i * 2) + 1 : (i + 1) * 2 - 1][j <= 1 ? 2 : j] = true;
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
          if(puzzle[i][j].left == 1) {
            data[i + 3][j] = true;
          }
          if(puzzle[i][j].right == 1) {
            data[i + 3][j + 1] = true;
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
    try {
      await read.writeData(data, filename);
    } catch (e) {
      print("EXCEPTION $e");
    }

  }
  Future<void> loadPuzzle() async {
    try {
      read;
    } catch (e) {
      read = ReadPuzzleData();
    }

    puzzle = GameSceneStateSquare.getPuzzle();
    data = await read.readData(filename);
  }

  void printData() {
    for(int i = 0 ; i < data.length ; i++) {
      print("row $i ${data[i]}");
    }
  }
}