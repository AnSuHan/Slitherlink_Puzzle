// ignore_for_file: file_names
import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show kIsWeb; // 웹 플랫폼 확인을 위해 추가
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ExtractData {
  ///String(JSON) 데이터를 앱 내 저장 공간에 파일로 저장하는 메소드
  Future<void> saveStringToFile(String data, String fileName) async {
    try {
      // 웹 플랫폼 확인
      if (kIsWeb) {
        // ignore: avoid_print
        print("kIsWeb in ExtractData");
        return;
      }

      // 각 플랫폼에 맞는 디렉토리 경로 가져오기
      Directory? directory;
      if (Platform.isAndroid) {
        directory = await getExternalStorageDirectory();
      } else if (Platform.isIOS) {
        directory = await getApplicationDocumentsDirectory();
      } else if (Platform.isLinux || Platform.isMacOS || Platform.isWindows) {
        directory = await getDownloadsDirectory();
      } else {
        throw UnsupportedError('지원되지 않는 플랫폼입니다.');
      }

      if (directory == null) {
        throw Exception('디렉토리를 찾을 수 없습니다.');
      }

      // 파일 경로 생성
      String filePath = '${directory.path}/$fileName';
      // 중복 이름 처리
      File file = File(filePath);
      int index = 1;

      while (await file.exists()) {
        final extensionIndex = fileName.lastIndexOf('.');
        if (extensionIndex == -1) {
          filePath = '${directory.path}/$fileName-$index';
        } else {
          final name = fileName.substring(0, extensionIndex);
          final extension = fileName.substring(extensionIndex);
          filePath = '${directory.path}/$name-$index$extension';
        }
        // 파일 객체 생성
        file = File(filePath);
        index++;
      }

      // 파일에 데이터 쓰기
      await file.writeAsString(data);

      // ignore: avoid_print
      print('파일 저장 성공: $filePath');
    } catch (e) {
      // ignore: avoid_print
      print('파일 저장 실패: $e');
    }
  }

  ///String 데이터를 SharedPreference에 저장
  Future<void> saveStringToLocal(String key, String value) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    try {
      // 웹 플랫폼 확인
      if (kIsWeb) {
        // ignore: avoid_print
        print("kIsWeb in ExtractData");
        return;
      }

      prefs.setString(key, value);
    }
    catch(e) {
      debugPrintStack(stackTrace: StackTrace.fromString(value));
    }
  }

  ///String 데이터를 SharedPreference에서 불러오기
  Future<String?> getStringFromLocal(String key) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    try {
      // 웹 플랫폼 확인
      if (kIsWeb) {
        // ignore: avoid_print
        print("kIsWeb in ExtractData");
        return "imported wrong class : $kIsWeb";
      }
      if(prefs.containsKey(key)) {
        return prefs.getString(key)!;
      }
      return null;
    }
    catch(e) {
      return null;
    }
  }

  Future<void> removeKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(key);
  }

  Future<void> removeKeyAll() async {
    //remove SharedPreference's keys
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String> keys = prefs.getKeys().toList();

    for(var key in keys) {
      await prefs.remove(key);
    }

    //print("now key : ${prefs.getKeys().toList()}");
  }
}
