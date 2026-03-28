// ignore_for_file: file_names
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:slitherlink_project/User/UserInfo.dart';

import '../Platform/ExtractData.dart'
if (dart.library.html) '../Platform/ExtractDataWeb.dart'; // 조건부 import
import '../Answer/Answer.dart';
import 'SlitherlinkGenerator.dart';

//handle data with SharedPreferences | local storage (NOT ACCESS to GameSceneStateSquare class)
class ReadPuzzleData {
  final BuildContext context;

  ReadPuzzleData({
    required this.context,
  }) {
    answer = Answer(context: context, loadPreset: true);
  }

  late Answer answer;

  //save submit data(int)
  Future<void> writeIntData(List<List<int>> data, String fileName) async {
    final ExtractData prefs = ExtractData();
    prefs.saveDataToLocal(fileName, jsonEncode(data));
  }

  Future<List<List<bool>>> readData(String keyName, {bool isContinue = false}) async {
    List<String> tokens = keyName.split("_");
    //load test
    if(tokens[tokens.length - 1].compareTo("test") == 0) {
      return await answer.getTestSquare();
    }
    // generate: "square_generate_{rows}x{cols}" or "square_generate_{rows}x{cols}_{difficulty}"
    if(tokens.length >= 3 && tokens[1].compareTo("generate") == 0) {
      return _generatePuzzle(tokens);
    }
    if(tokens[0].compareTo("square") == 0) {
      if(tokens[1].compareTo("small") == 0) {
        int index = int.parse(tokens[2]);
        return await answer.getSquare(index);
      }
    }

    //init
    return await answer.getSquare(UserInfo.getProgress("square_small"));
  }

  /// Parse generate key and create puzzle dynamically
  /// Key format: "square_generate_{rows}x{cols}" or "square_generate_{rows}x{cols}_{difficulty}"
  /// difficulty: "easy", "normal", "hard" (default: normal)
  List<List<bool>> _generatePuzzle(List<String> tokens) {
    // Parse size: "{rows}x{cols}"
    List<String> sizeParts = tokens[2].split("x");
    int rows = int.parse(sizeParts[0]);
    int cols = int.parse(sizeParts[1]);

    // Parse difficulty (optional)
    Difficulty difficulty = Difficulty.normal;
    if (tokens.length >= 4) {
      switch (tokens[3]) {
        case "easy":
          difficulty = Difficulty.easy;
          break;
        case "hard":
          difficulty = Difficulty.hard;
          break;
        default:
          difficulty = Difficulty.normal;
      }
    }

    return answer.generateSquare(rows, cols, difficulty: difficulty);
  }

  void printData(List<List<int>> intData) {
    for(int i = 0 ; i < intData.length ; i++) {
      // ignore: avoid_print
      print("${intData[i]}, ");
    }
  }
}
