import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../Front/EnterScene.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized(); // Flutter 초기화
  await Firebase.initializeApp(); // Firebase 초기화

  firebase();
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

void firebase() async {
  FirebaseAuth.instance
      .authStateChanges()
      .listen((User? user) {
    if (user != null) {
      print("user is ${user.uid}");
    }
    else {
      print("user is null");
    }
  });
}