import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'Front/EnterScene.dart';

void main() {
  //beforeRelease();
  runApp(const EnterScene());
}

void beforeRelease() async {
  //remove SharedPreference's keys
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  List<String> keys = prefs.getKeys().toList();

  for(var key in keys) {
    await prefs.remove(key);
  }

}