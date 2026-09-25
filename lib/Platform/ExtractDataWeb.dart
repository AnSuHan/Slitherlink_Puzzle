// ignore_for_file: file_names
import 'dart:convert';
import 'dart:js_interop';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:web/web.dart' as web;

class ExtractData {
  ///웹 플랫폼에서 데이터를 파일로 저장하고 다운로드하는 메소드
  Future<void> saveStringToFile(String data, String fileName) async {
    if (!kIsWeb) {
      // ignore: avoid_print
      print("kIsWeb in ExtractDataWeb");
      return;
    }

    final Uint8List bytes = Uint8List.fromList(utf8.encode(data));
    final blob = web.Blob(
      <JSAny>[bytes.toJS].toJS,
      web.BlobPropertyBag(type: 'text/plain;charset=utf-8'),
    );
    final url = web.URL.createObjectURL(blob);
    final anchor = web.document.createElement('a') as web.HTMLAnchorElement
      ..href = url
      ..setAttribute(
        "download",
        "${fileName.split(".")[0]}-${Random().nextInt(10000) * Random().nextInt(10000)}.txt",
      );
    anchor.click();
    web.URL.revokeObjectURL(url);

    // ignore: avoid_print
    print('웹 파일 다운로드 성공: $fileName');
  }

  ///데이터를 localStorage에 저장
  Future<void> saveDataToLocal(String key, dynamic value) async {
    try {
      web.window.localStorage.setItem(key, value.toString());
    } catch (e) {
      debugPrintStack(stackTrace: StackTrace.fromString(key));
    }
  }

  ///데이터를 localStorage에서 불러오기
  Future<dynamic> getDataFromLocal(String key) async {
    try {
      final value = web.window.localStorage.getItem(key);
      if (value == null) return null;
      return value;
    } catch (e) {
      return null;
    }
  }

  Future<void> removeKey(String key) async {
    web.window.localStorage.removeItem(key);
  }

  Future<void> removeKeyAll() async {
    //remove web local storage's key
    web.window.localStorage.clear();
  }

  Future<void> removeKeyAllExcept(bool Function(String key) shouldKeep) async {
    final storage = web.window.localStorage;
    final List<String> keys = [];
    for (int i = 0; i < storage.length; i++) {
      final k = storage.key(i);
      if (k != null) keys.add(k);
    }
    for (final k in keys) {
      if (!shouldKeep(k)) storage.removeItem(k);
    }
  }

  Future<bool> containsKey(String key) async {
    return web.window.localStorage.getItem(key) != null;
  }
}
