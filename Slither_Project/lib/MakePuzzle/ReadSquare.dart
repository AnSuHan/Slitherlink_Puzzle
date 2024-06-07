import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../Scene/GameSceneStateSquare.dart';
import 'ReadPuzzleData.dart';
import '../widgets/SquareBox.dart';

//handle data with puzzle in GameSceneStateSquare
class ReadSquare {
  static late List<List<SquareBox>> puzzle;
  static late List<List<bool>> data;
  static late ReadPuzzleData read;

  bool checkCycle() {
    puzzle = GameSceneStateSquare.getPuzzle();

    return false;
  }

  Future<void> savePuzzle(String key) async {
    try {
      read;
    } catch (e) {
      read = ReadPuzzleData();
    }

    puzzle = GameSceneStateSquare.getPuzzle();
    data = List.generate(puzzle.length * 2 + 1, (row) =>
        List.filled(row % 2 == 0 ? puzzle[0].length : puzzle[0].length + 1, false),
    );
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
      await read.writeData(data, key);
      //await read.writePuzzleData("square", data, 0);
    } catch (e) {
      print("EXCEPTION $e");
    }
  }

  ///param should be "shape`_`size`_`progress`_`{continue}"
  Future<List<List<int>>> loadPuzzle(String key) async {
    try {
      read;
    } catch (e) {
      read = ReadPuzzleData();
    }

    //get answer data
    if(key.split("_").length == 3) {
      data = await read.readData(key);
      //printData();
      return data.map((row) => row.map((b) => b ? 1 : 0).toList()).toList();
    }
    //get submit data
    else {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      String? temp = prefs.getString(key);

      if (temp != null) {
        // JSON 문자열을 List<List<int>> 타입으로 변환
        List<dynamic> decodedJson = jsonDecode(temp);
        List<List<int>> data = [];
        for (var row in decodedJson) {
          List<int> intRow = List<int>.from(row); // List<int>로 변환
          data.add(intRow);
        }
        return data;
      }
      else {
        return [];
      }
    }
  }

  void printData() {
    for(int i = 0 ; i < data.length ; i++) {
      print("row $i ${data[i]}");
    }
  }
}