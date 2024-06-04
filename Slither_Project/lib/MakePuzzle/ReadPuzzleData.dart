import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slitherlink_project/User/UserInfo.dart';

import '../Answer/Answer.dart';

//handle data with SharedPreferences (NOT ACCESS to GameSceneStateSquare class)
class ReadPuzzleData {
  List<List<bool>> prefData = [];
  UserInfo info = UserInfo();
  Answer answer = Answer();

  Future<void> writeData(List<List<bool>> data, String fileName) async {
    // Convert List<List<bool>> to List<List<int>> for JSON serialization
    List<List<int>> intData = data.map((row) => row.map((b) => b ? 1 : 0).toList()).toList();

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setString(fileName, jsonEncode(intData));
    //print("jsonData in writeData : ${jsonEncode(intData)}");
  }

  Future<List<List<bool>>> readData(String fileName) async {
    //init
    if(!fileName.contains("_")) {
      //getSquare(0) is debug mode(all line is 1)
      return answer.getSquare(UserInfo().getProgress("square") + 1);
    }
    
    //load user saved data
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    String? jsonData = prefs.getString(fileName);

    if (jsonData == null) {
      // 저장된 데이터가 없으면 빈 리스트를 반환하거나 원하는 처리를 수행합니다.
      return [];
    } else {
      // JSON 문자열을 List<List<int>>로 변환한 다음 List<List<bool>>로 변환합니다.
      List<List<int>> intData = (jsonDecode(jsonData) as List<dynamic>).map((row) => (row as List<dynamic>).map((val) => val as int).toList()).toList();
      List<List<bool>> boolData = intData.map((row) => row.map((intVal) => intVal == 1 ? true : false).toList()).toList();

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
