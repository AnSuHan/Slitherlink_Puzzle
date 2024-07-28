// ignore_for_file: file_names, avoid_web_libraries_in_flutter
import 'dart:convert';
import 'dart:html' as html;
import 'dart:math';
import 'package:flutter/foundation.dart' show kIsWeb;

class ExtractDataWeb {
  // 웹 플랫폼에서 데이터를 파일로 저장하고 다운로드하는 메소드
  void saveStringToFileInWeb(String data, String fileName) {
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
}