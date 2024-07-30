import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../provider/SquareProvider.dart';
import '../widgets/SquareBox.dart';
import 'ReadPuzzleData.dart';

//handle data with puzzle in GameSceneStateSquare
class ReadSquare {
  List<List<SquareBox>> puzzle = [];
  late List<List<bool>> data;
  late ReadPuzzleData read;
  late List<List<int>> lineData;
  final SquareProvider squareProvider;
  final BuildContext context;

  ReadSquare({
    required this.squareProvider,
    required this.context,
  }) {
    puzzle = []; // 초기화
    lineData = [];
    read = ReadPuzzleData(context: context);
  }

  void setPuzzle(List<List<SquareBox>> puzzle) {
    this.puzzle = puzzle;
  }

  Future<void> savePuzzle(String key) async {
    puzzle = squareProvider.getPuzzle();
    lineData = await readSubmit(puzzle);

    try {
      await read.writeIntData(lineData, key);
    } catch (e) {
      //print("EXCEPTION $e");
    }
  }

  ///param should be "shape`_`size`_`progress`_`{continue}"
  Future<List<List<int>>> loadPuzzle(String key) async {
    try {
      read;
    } catch (e) {
      read = ReadPuzzleData(context: context);
    }

    //get answer data
    //read from Answer.dart
    if(key.split("_").length == 3) {
      data = await read.readData(key);
      //printData();
      return data.map((row) => row.map((b) => b ? 1 : 0).toList()).toList();
    }
    //get submit data
    //read from SharedPreference
    else {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      String? temp = prefs.getString(key);

      if (temp != null) {
        // JSON to List<List<int>>
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


  Future<List<List<int>>> readSubmit(List<List<SquareBox>> puzzle) async {
    lineData = List.generate(puzzle.length * 2 + 1, (row) =>
        List.filled(row % 2 == 0 ? puzzle[0].length : puzzle[0].length + 1, 0),
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
          if(puzzle[i][j].down != 0) {
            lineData[(i + 1) * 2][j] = puzzle[i][j].down;
          }
          if(puzzle[i][j].right != 0) {
            lineData[(i * 2) + 1][j + 1] = puzzle[i][j].right;
          }
        }
        //up, down, right
        else if(j != 0) {
          if(puzzle[i][j].up != 0) {
            lineData[i][j] = puzzle[i][j].up;
          }
          if(puzzle[i][j].down != 0) {
            lineData[i + 2][j] = puzzle[i][j].down;
          }
          if(puzzle[i][j].right != 0) {
            lineData[i + 1][j + 1] = puzzle[i][j].right;
          }
        }
        //down, left, right
        else if(i != 0) {
          if(puzzle[i][j].down != 0) {
            //1=>4, 2=>6, 3=>8 //x*2+2
            lineData[i * 2 + 2][j] = puzzle[i][j].down;
          }
          //2=>5, 3=>7
          if(puzzle[i][j].left != 0) {
            lineData[i * 2 + 1][j] = puzzle[i][j].left;
          }
          if(puzzle[i][j].right != 0) {
            lineData[i * 2 + 1][j + 1] = puzzle[i][j].right;
          }
        }
        //up, down, left, right
        else {
          if(puzzle[i][j].up != 0) {
            lineData[i][j] = puzzle[i][j].up;
          }
          if(puzzle[i][j].down != 0) {
            lineData[i + 2][j] = puzzle[i][j].down;
          }
          if(puzzle[i][j].left != 0) {
            lineData[i + 1][j] = puzzle[i][j].left;
          }
          if(puzzle[i][j].right != 0) {
            lineData[i + 1][j + 1] = puzzle[i][j].right;
          }
        }
      }
    }
    
    return lineData;
  }

  Future<void> writeSubmit(List<List<SquareBox>> puzzle, List<List<int>> submit) async {
    for (int i = 0; i < puzzle.length; i++) {
      for (int j = 0; j < puzzle[i].length; j++) {
        //down, right
        if (i != 0 && j != 0) {
          puzzle[i][j].down = submit[(i + 1) * 2][j];
          puzzle[i][j].right = submit[(i * 2) + 1][j + 1];
        }
        //up, down, right
        else if (j != 0) {
          puzzle[i][j].up = submit[i][j];
          puzzle[i][j].down = submit[i + 2][j];
          puzzle[i][j].right = submit[i + 1][j + 1];
        }
        //down, left, right
        else if (i != 0) {
          puzzle[i][j].down = submit[i * 2 + 2][j];
          puzzle[i][j].left = submit[i * 2 + 1][j];
          puzzle[i][j].right = submit[i * 2 + 1][j + 1];
        }
        //up, down, left, right
        else {
          puzzle[i][j].up = submit[i][j];
          puzzle[i][j].down = submit[i + 2][j];
          puzzle[i][j].left = submit[i + 1][j];
          puzzle[i][j].right = submit[i + 1][j + 1];
        }
      }
    }
  }

}