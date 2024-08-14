// ignore_for_file: file_names
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:slitherlink_project/User/UserInfo.dart';

import '../Platform/ExtractData.dart'
if (dart.library.html) '../Platform/ExtractDataWeb.dart'; // 조건부 import
import '../Answer/Answer.dart';

//handle data with SharedPreferences | local storage (NOT ACCESS to GameSceneStateSquare class)
class ReadPuzzleData {
  final BuildContext context;

  ReadPuzzleData({
    required this.context,
  }) {
    answer = Answer(context: context);
  }

  late Answer answer;

  //save submit data(int)
  Future<void> writeIntData(List<List<int>> data, String fileName) async {
    final ExtractData prefs = ExtractData();
    prefs.saveDataToLocal(fileName, jsonEncode(data));
  }

  Future<List<List<bool>>> readData(String keyName, {bool isContinue = false}) async {
    List<String> tokens = keyName.split("_");
    if(tokens[0].compareTo("square") == 0) {
      if(tokens[1].compareTo("small") == 0) {
        int index = int.parse(tokens[2]);
        return await answer.getSquare(index);
      }
    }

    //init
    return await answer.getSquare(UserInfo.getProgress("square_small"));
  }

  void printData(List<List<int>> intData) {
    for(int i = 0 ; i < intData.length ; i++) {
      // ignore: avoid_print
      print("${intData[i]}, ");
    }
  }
}
