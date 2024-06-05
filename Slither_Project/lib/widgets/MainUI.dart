import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../Scene/GameSceneSquare.dart';
import '../User/UserInfo.dart';

class MainUI {
  late Size screenSize;
  List<String> puzzleType = ["square"];
  List<String> puzzleSize = ["small"];
  List<String> selectedType = ["square", "small"];
  List<String> progressPuzzle = [""];

  UserInfo user = UserInfo();
  final GlobalKey<PopupMenuButtonState<int>> _mainMenuKey = GlobalKey<PopupMenuButtonState<int>>();

  final VoidCallback onUpdate;
  MainUI({required this.onUpdate});


  PopupMenuButton getMainMenu(BuildContext context) {
    return PopupMenuButton(
      iconSize: 32,
      key: _mainMenuKey,
      onSelected: (value) {
        handleMainMenu(context, value);
      },
      itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
        const PopupMenuItem<String>(
          value: 'account',
          child: Text('Account'),
        ),
        const PopupMenuItem<String>(
          value: 'setting',
          child: Text("Setting"),
        ),
      ],
      icon: const Icon(Icons.menu),
    );
  }

  void handleMainMenu(BuildContext context, String result) {
    switch(result) {
      case "account":
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              child: Container(
                width: 300, // 원하는 너비로 설정
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Account',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text("Account"),
                            Text(user.progress.toString()), //temp
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text("Progress"),
                            Text(user.progress.toString()), //temp
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          child: const Text('Close'),
                          onPressed: () {
                            Navigator.of(context).pop(); // 다이얼로그 닫기
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
        break;
      case "setting":
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              child: Container(
                width: 300, // 원하는 너비로 설정
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Setting',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text("Setting"),
                            Text(user.progress.toString()), //temp
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text("Setting"),
                            Text(user.progress.toString()), //temp
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          child: const Text('Apply'),
                          onPressed: () {
                            Navigator.of(context).pop(); // 다이얼로그 닫기
                          },
                        ),
                        TextButton(
                          child: const Text('Close'),
                          onPressed: () {
                            Navigator.of(context).pop(); // 다이얼로그 닫기
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );

        break;
    }
  }

  //about puzzle difficulty
  Widget getPuzzleType(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        getPuzzleShape(context),
        const SizedBox(
          width: 50,
        ),
        getPuzzleSize(context),
      ],
    );
  }

  DropdownButton getPuzzleShape(BuildContext context) {
    return DropdownButton(items: puzzleType
        .map((e) => DropdownMenuItem(
          value: e, // 선택 시 onChanged 를 통해 반환할 value
          child: Text(e),
        ))
        .toList(),
        onChanged: (value) {
          selectedType[0] = value;
        },
        value: selectedType[0],
        style: const TextStyle(color: Colors.white, fontSize: 24),
    );
  }

  DropdownButton getPuzzleSize(BuildContext context) {
    return DropdownButton(items: puzzleSize
        .map((e) => DropdownMenuItem(
          value: e, // 선택 시 onChanged 를 통해 반환할 value
          child: Text(e),
        ))
        .toList(),
        onChanged: (value) {
          selectedType[1] = value;
        },
        value: selectedType[1],
        style: const TextStyle(color: Colors.white, fontSize: 24),
    );
  }

  DropdownButton? getProgressPuzzle(BuildContext context) {
    if(UserInfo.getContinuePuzzle().isEmpty) {
      return null;
    }

    return DropdownButton(items: progressPuzzle
        .map((e) => DropdownMenuItem(
          value: e, // 선택 시 onChanged 를 통해 반환할 value
          child: Text(e),
        ))
        .toList(),
        onChanged: (value) {
          progressPuzzle[0] = value;
        },
        value: progressPuzzle[0],
        style: const TextStyle(color: Colors.white, fontSize: 24),
    );
  }

  //about start button
  ElevatedButton getStartButton(BuildContext context) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(100, 50),
      ),
      onPressed: () {
        UserInfo.addContinuePuzzle("${selectedType[0]}_${selectedType[1]}_progress");
        onUpdate();
        changeScene(context);
      },
      child: const Text("Start Game", style: TextStyle(fontSize: 24),)
    );
  }

  void changeScene(BuildContext context) {
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) => const GameSceneSquare()
        )
    );
  }

  //about screen size
  double getTopMargin() {
    return screenSize.height / 5;
  }

  double getMargin(double ratio) {
    return screenSize.height * ratio;
  }

  void setScreenSize(Size size) {
    screenSize = size;
  }
}