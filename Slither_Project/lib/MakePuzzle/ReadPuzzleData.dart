import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slitherlink_project/User/UserInfo.dart';

import '../Answer/Answer.dart';

class ReadPuzzleData {
  List<List<bool>> prefData = [];
  UserInfo info = UserInfo();
  Answer answer = Answer();

  Future<void> writePuzzleData(String puzzleType, List<List<bool>> data, int progress) async {
    //add to last
    if(progress == -1) {
      info.getProgress(puzzleType);
    }

    List<List<int>> intData = data.map((row) => row.map((b) => b ? 1 : 0).toList()).toList();
    printData(intData);
  }

  Future<List<List<bool>>> readPuzzleData(String puzzleType, int progress) async {
    List<List<bool>> value = [];

    switch(puzzleType) {
      case "square":
        value = answer.getSquare(progress);
        break;
    }

    return value;
  }

  Future<void> writeData(List<List<bool>> data, String fileName) async {
    // Convert List<List<bool>> to List<List<int>> for JSON serialization
    List<List<int>> intData = data.map((row) => row.map((b) => b ? 1 : 0).toList()).toList();

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setString(fileName, jsonEncode(intData));
    //print("jsonData in writeData : ${jsonEncode(intData)}");
  }

  Future<List<List<bool>>> readData(String fileName) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    String? jsonData = prefs.getString(fileName);

    if (jsonData == null) {
      //print("read data complete, but empty");
      // 저장된 데이터가 없으면 빈 리스트를 반환하거나 원하는 처리를 수행합니다.
      return [];
    } else {
      // JSON 문자열을 List<List<int>>로 변환한 다음 List<List<bool>>로 변환합니다.
      List<List<int>> intData = (jsonDecode(jsonData) as List<dynamic>).map((row) => (row as List<dynamic>).map((val) => val as int).toList()).toList();
      List<List<bool>> boolData = intData.map((row) => row.map((intVal) => intVal == 1 ? true : false).toList()).toList();
      //print("read data complete $boolData");

      return boolData;
    }
  }

  void printData(List<List<int>> intData) {
    for(int i = 0 ; i < intData.length ; i++) {
      // ignore: avoid_print
      print("${intData[i]}, ");
    }
  }
}
