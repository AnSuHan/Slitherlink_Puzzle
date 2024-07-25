// ignore_for_file: file_names
import 'dart:convert';

// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html if (dart.library.html) 'dart:html';

class ExtractDataWeb {
// 웹 플랫폼에서 데이터를 파일로 저장하고 다운로드하는 메소드
  void saveDataToWeb(String data, String fileName) {
    final bytes = utf8.encode(data);
    final blob = html.Blob([bytes]);
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..setAttribute("download", fileName)
      ..click();
    html.Url.revokeObjectUrl(url);

    print('웹 파일 다운로드 성공: $fileName');
  }
}
