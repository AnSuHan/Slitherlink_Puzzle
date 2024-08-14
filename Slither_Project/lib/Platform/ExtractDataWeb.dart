// ignore_for_file: file_names, avoid_web_libraries_in_flutter
import 'dart:convert';
import 'dart:html' as html;
import 'dart:math';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class ExtractData {
  ///웹 플랫폼에서 데이터를 파일로 저장하고 다운로드하는 메소드
  Future<void> saveStringToFile(String data, String fileName) async {
    if(!kIsWeb) {
      // ignore: avoid_print
      print("kIsWeb in ExtractDataWeb");
      return;
    }

    final bytes = utf8.encode(data);
    final blob = html.Blob([bytes]);
    final url = html.Url.createObjectUrlFromBlob(blob);
    final _ = html.AnchorElement(href: url)
      ..setAttribute("download", "${fileName.split(".")[0]}-${Random().nextInt(10000) * Random().nextInt(10000)}.txt")
      ..click();
    html.Url.revokeObjectUrl(url);

    // ignore: avoid_print
    print('웹 파일 다운로드 성공: $fileName');
  }

  ///String 데이터를 SharedPreference에 저장
  Future<void> saveStringToLocal(String key, String value) async {
    try {
      html.window.localStorage[key] = value;
    }
    catch(e) {
      debugPrintStack(stackTrace: StackTrace.fromString(key));
    }
  }

  ///String 데이터를 SharedPreference에서 불러오기
  Future<String?> getStringFromLocal(String key) async {
    try {
      return html.window.localStorage[key];
    }
    catch(e) {
      return null;
    }
  }

  Future<void> removeKey(String key) async {
    html.window.localStorage.remove(key);
  }

  Future<void> removeKeyAll() async {
    //remove web local storage's key
    html.window.localStorage.clear();
    print("Local storage keys cleared. : ${html.window.localStorage.keys}");
  }
}