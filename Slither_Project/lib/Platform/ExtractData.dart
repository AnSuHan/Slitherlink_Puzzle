import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb; // 웹 플랫폼 확인을 위해 추가
import 'package:path_provider/path_provider.dart';

class ExtractData {
  // JSON 데이터를 파일로 저장하는 메소드
  Future<void> saveStringToFile(String data, String fileName) async {
    try {
      // 웹 플랫폼 확인
      if (kIsWeb) {
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
      final String filePath = '${directory.path}/$fileName';

      // 파일 객체 생성
      final File file = File(filePath);

      // 파일에 데이터 쓰기
      await file.writeAsString(data);

      print('파일 저장 성공: $filePath');
    } catch (e) {
      print('파일 저장 실패: $e');
    }
  }
}
