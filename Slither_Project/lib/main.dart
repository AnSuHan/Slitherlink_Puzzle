import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'Front/Splash.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const Splash());
}

void beforeRelease() async {
  //remove SharedPreference's keys
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  List<String> keys = prefs.getKeys().toList();

  for(var key in keys) {
    await prefs.remove(key);
  }
}