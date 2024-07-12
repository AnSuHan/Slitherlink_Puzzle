import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import '../firebase_options.dart';
import 'EnterScene.dart';

class Splash extends StatelessWidget {
  const Splash({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: FutureBuilder(
        future: firebase(), // Firebase 초기화 비동기 작업
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(
                child: CircularProgressIndicator(),
              ),
            );
          } else if (snapshot.hasError) {
            print(snapshot.error);
            return MaterialApp(
              home: Scaffold(
                body: Center(
                  child: Text('Error: ${snapshot.error}'),
                ),
              ),
            );
          } else {
            return const EnterScene(); // 초기화 완료 후 EnterScene 표시
          }
        },
      ),
    );
  }

  Future<void> firebase() async {
    print("___ start firebase method ___");
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print("___ end firebase method ___");
  }
}