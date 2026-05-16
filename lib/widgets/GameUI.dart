// ignore_for_file: file_names
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../Platform/ExtractData.dart'
if (dart.library.html) '../Platform/ExtractDataWeb.dart'; // 조건부 import
import '../MakePuzzle/ReadSquare.dart';
import '../l10n/app_localizations.dart';
import '../Scene/GameSceneSquare.dart';
import '../provider/SquareProvider.dart';
import 'MainUI.dart';
import 'PuzzleAppBar.dart';

class GameUI {
  late Size screenSize;
  late ReadSquare readSquare;
  final SquareProvider squareProvider;
  final BuildContext context;
  AppLocalizations appLocalizations;

  GameUI({
    required this.squareProvider,
    required this.context,
    required this.appLocalizations,
  }) {
    readSquare = ReadSquare(squareProvider: squareProvider, context: context);
    initLabel();
  }

  //ui status
  List<String> labelState = ["save", "save", "save"]; //R, G, B

  Future<void> exitGame() async {
    //when back button click, set class {UserInfo}
    String key = "${MainUI.getProgressKey()}_continue";
    //print("key : $key");  //square_small_0
    await squareProvider.removeHintLine();
    await readSquare.savePuzzle(key);
    await squareProvider.saveDoValue();
    await squareProvider.saveDoSubmit();
    // ignore: use_build_context_synchronously
    Navigator.pop(context);
  }

  void _startNewGame() {
    String key = MainUI.getProgressKey();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => GameSceneSquare(
          isContinue: false,
          loadKey: key,
          forceNewPuzzle: true,
        ),
      ),
    );
  }

  Future<void> pauseGame() async {
    //when back button click, set class {UserInfo}
    String key = "${MainUI.getProgressKey()}_continue";
    //print("key : $key");  //square_small_0
    await squareProvider.removeHintLine();
    await readSquare.savePuzzle(key);
    await squareProvider.saveDoValue();
    await squareProvider.saveDoSubmit();
  }

  AppBar getGameAppBar(BuildContext context, Color appbarColor, Color iconColor) {
    return PuzzleAppBar.build(
      context: context,
      appbarColor: appbarColor,
      iconColor: iconColor,
      appLocalizations: appLocalizations,
      labelState: labelState,
      onExit: () async {
        await exitGame();
      },
      onRestart: () {
        Provider.of<SquareProvider>(context, listen: false).restart();
      },
      onNewGame: _startNewGame,
      onHint: () async {
        final provider = Provider.of<SquareProvider>(context, listen: false);
        await provider.showHint(context);
        final p = provider.getHintCanvasPos();
        if (p != null) {
          squareProvider.gameStateSquare?.panToCanvasPoint(p);
        }
      },
      onAutoSolve: () {
        // 무거운 propagation 루프이므로 await 하지 않고 백그라운드로 시작.
        // 사용자는 동일 메뉴/취소 버튼으로 중단 가능.
        final provider = Provider.of<SquareProvider>(context, listen: false);
        provider.solveHumanLike();
      },
      onSaveBookmark: (int idx) async {
        await saveData(PuzzleAppBar.colorNames[idx]);
      },
      onLoadBookmark: (int idx) async {
        await loadData(PuzzleAppBar.colorNames[idx]);
      },
      onClearBookmark: (int idx) async {
        clearData(PuzzleAppBar.colorNames[idx]);
      },
    );
  }

  Future<void> saveData(String label) async {
    await squareProvider.removeHintLine();
    readSquare.savePuzzle("${MainUI.getProgressKey()}_$label");
    await squareProvider.controlDo(save: true, key: "${MainUI.getProgressKey()}_${label}_do");
    //await squareProvider.saveDoValue();
    await squareProvider.saveDoSubmit(color: label);

    switch(label) {
      case "Red":
        labelState[0] = "load";
        break;
      case "Green":
        labelState[1] = "load";
        break;
      case "Blue":
        labelState[2] = "load";
        break;
    }
  }
  Future<void> loadData(String label) async {
    List<List<int>> value = await readSquare.loadPuzzle("${MainUI.getProgressKey()}_$label");
    // The bookmark's saved doPointer/doSubmit files are intentionally not
    // read back: a bookmark load is now a single new edit step on top of
    // the user's current undo history, so they can undo back to the moment
    // before they tapped Load.
    await squareProvider.applyBookmarkSubmit(value);
  }
  void clearData(String label) async {
    clearLabel(label);

    switch(label) {
      case "Red":
        labelState[0] = "save";
        break;
      case "Green":
        labelState[1] = "save";
        break;
      case "Blue":
        labelState[2] = "save";
        break;
    }
  }

  void setScreenSize(Size size) {
    screenSize = size;
  }

  Size getScreenSize() {
    return screenSize;
  }

  void initLabel() async {
    ExtractData prefs = ExtractData();
    List<String> labelColor = ["Red", "Green", "Blue"];

    for(int i = 0 ; i < labelColor.length ; i++) {
      String key = "${MainUI.getProgressKey()}_${labelColor[i]}";
      if(await prefs.containsKey(key)) {
        labelState[i] = "load";
      }
    }
  }

  void clearLabel(String color) async {
    ExtractData prefs = ExtractData();
    String key = "${MainUI.getProgressKey()}_$color";

    //label data
    if(await prefs.containsKey(key)) {
      await prefs.removeKey(key);
    }
    //control do data with label
    if(await prefs.containsKey("${key}_do")) {
      await prefs.removeKey("${key}_do");
    }
  }
}