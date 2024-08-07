// ignore_for_file: file_names
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slitherlink_project/User/UserInfo.dart';

import '../Answer/Answer.dart';

//handle data with SharedPreferences (NOT ACCESS to GameSceneStateSquare class)
class ReadPuzzleData {
  final BuildContext context;

  ReadPuzzleData({
    required this.context,
  }) {
    answer = Answer(context: context);
  }

  List<List<bool>> prefData = [];
  UserInfo info = UserInfo();
  late Answer answer;

  Future<void> writeData(List<List<bool>> data, String fileName) async {
    // Convert List<List<bool>> to List<List<int>> for JSON serialization
    List<List<int>> intData = data.map((row) => row.map((b) => b ? 1 : 0).toList()).toList();

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setString(fileName, jsonEncode(intData));
    //print("jsonData in writeData : ${jsonEncode(intData)}");
  }

  //save submit data(int)
  Future<void> writeIntData(List<List<int>> data, String fileName) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setString(fileName, jsonEncode(data));
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
