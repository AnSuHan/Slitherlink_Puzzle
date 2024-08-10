// ignore_for_file: file_names
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../MakePuzzle/ReadSquare.dart';
import '../l10n/app_localizations.dart';
import '../provider/SquareProvider.dart';
import 'MainUI.dart';

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
  final GlobalKey<PopupMenuButtonState<int>> _bookmarkKey = GlobalKey<PopupMenuButtonState<int>>();
  final GlobalKey<PopupMenuButtonState<int>> _menuKey = GlobalKey<PopupMenuButtonState<int>>();
  List<String> labelState = ["save", "save", "save"]; //R, G, B

  AppBar getGameAppBar(BuildContext context, Color appbarColor, Color iconColor) {
    return AppBar(
      backgroundColor: appbarColor,
      foregroundColor: iconColor,
      leading: InkWell(
        onTap: () async {
          //when back button click, set class {UserInfo}
          String key = "${MainUI.getProgressKey()}_continue";
          //print("key : $key");  //square_small_0
          readSquare.savePuzzle(key);
          squareProvider.saveDoValue();
          Navigator.pop(context);
        },
        child: Icon(Icons.keyboard_backspace, color: iconColor,),
      ),
      actions: <Widget>[
        //save icon
        SizedBox(
          width: 50,
          height: 50,
          child: PopupMenuButton(
            key: _bookmarkKey,
            onSelected: (String result) {
              String color = result.split(" ")[2];
              int index = -1;
              switch(color) {
                case "Red":
                  index = 0;
                  break;
                case "Green":
                  index = 1;
                  break;
                case "Blue":
                  index = 2;
                  break;
              }
              Text snack = const Text("");
              switch(result.split(" ")[0]) {
                case "click":
                  snack = Text('${labelState[index]} data with $color');
                  break;
                case "clear":
                  snack = Text('clear $color data');
                  break;
              }
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: snack,
                duration: const Duration(milliseconds: 500),
              ));

              controlMenu(context, result);
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              PopupMenuItem<String>(
                value: 'click Label Red',
                child: Row(
                  children: [const Icon(Icons.bookmark_sharp, color: Colors.red,),
                    Text(
                        labelState[0].compareTo("save") == 0
                        ? appLocalizations.translateComplex("save", "red")
                        : appLocalizations.translateComplex("load", "red")
                    )],
                ),
              ),
              PopupMenuItem<String>(
                value: 'click Label Green',
                child: Row(
                  children: [const Icon(Icons.bookmark_sharp, color: Colors.green,),
                    Text(
                        labelState[1].compareTo("save") == 0
                        ? appLocalizations.translateComplex("save", "green")
                        : appLocalizations.translateComplex("load", "green")
                    )],
                ),
              ),
              PopupMenuItem<String>(
                value: 'click Label Blue',
                child: Row(
                  children: [const Icon(Icons.bookmark_sharp, color: Colors.blue,),
                    Text(
                        labelState[2].compareTo("save") == 0
                        ? appLocalizations.translateComplex("save", "blue")
                        : appLocalizations.translateComplex("load", "blue")
                    )],
                ),
              ),
              PopupMenuItem<String>(
                value: 'clear Label Red',
                enabled: labelState[0].compareTo("load") == 0,
                child: Row(
                  children: [const Icon(Icons.bookmark_remove, color: Colors.red,),
                    Text(appLocalizations.translateComplex("clear", "red"))],
                ),
              ),
              PopupMenuItem<String>(
                value: 'clear Label Green',
                enabled: labelState[1].compareTo("load") == 0,
                child: Row(
                  children: [const Icon(Icons.bookmark_remove, color: Colors.green,),
                    Text(appLocalizations.translateComplex("clear", "green"))],
                ),
              ),
              PopupMenuItem<String>(
                value: 'clear Label Blue',
                enabled: labelState[2].compareTo("load") == 0,
                child: Row(
                  children: [const Icon(Icons.bookmark_remove, color: Colors.blue,),
                    Text(appLocalizations.translateComplex("clear", "blue"))],
                ),
              ),
            ],
            icon: const Icon(Icons.bookmarks),
          ),
        ),
        //menu icon
        SizedBox(
          width: 50,
          height: 50,
          child: PopupMenuButton(
            key: _menuKey,
            onSelected: (String result) {
              controlMenu(context, result);
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              PopupMenuItem<String>(
                value: 'menu restart',
                child: Text(appLocalizations.translate('restart')),
              ),
              PopupMenuItem<String>(
                value: 'menu hint',
                child: Text(appLocalizations.translate("hint")),
              ),
            ],
            icon: const Icon(Icons.menu),
          ),
        ),
        const SizedBox(
          width: 10,
        )
      ],
    );
  }

  void controlMenu(BuildContext context, String label) {
    List<String> token = label.split(" ");

    //bookmark
    if(token.length == 3) {
      if(token[0].compareTo("click") == 0) {
        //save or load
        switch(token[2]) {
          case "Red":
            if(labelState[0].compareTo("save") == 0) {
              saveData(token[2]);
            }
            else {
              loadData(token[2]);
            }
            break;
          case "Green":
            if(labelState[1].compareTo("save") == 0) {
              saveData(token[2]);
            }
            else {
              loadData(token[2]);
            }
            break;
          case "Blue":
            if(labelState[2].compareTo("save") == 0) {
              saveData(token[2]);
            }
            else {
              loadData(token[2]);
            }
            break;
        }
      }
      else if(token[0].compareTo("clear") == 0) {
        //clear
        switch(token[2]) {
          case "Red":
            clearData("Red");
            break;
          case "Green":
            clearData("Green");
            break;
          case "Blue":
            clearData("Blue");
            break;
        }
      }
    }

    //menu
    if(token.length == 2) {
      switch(token[1]) {
        case "restart":
          Provider.of<SquareProvider>(context, listen: false).restart();
          break;
        case "hint":
          Provider.of<SquareProvider>(context, listen: false).showHint(context);
          break;
      }
    }
  }

  Future<void> saveData(String label) async {
    readSquare.savePuzzle("${MainUI.getProgressKey()}_$label");
    await squareProvider.controlDo(save: true, key: "${MainUI.getProgressKey()}_${label}_do");

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
  void loadData(String label) async {
    List<List<int>> value = await readSquare.loadPuzzle("${MainUI.getProgressKey()}_$label");
    squareProvider.loadLabel(value);
    await squareProvider.controlDo(load: true, key: "${MainUI.getProgressKey()}_${label}_do");
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
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String> labelColor = ["Red", "Green", "Blue"];

    for(int i = 0 ; i < labelColor.length ; i++) {
      String key = "${MainUI.getProgressKey()}_${labelColor[i]}";
      if(prefs.containsKey(key)) {
        labelState[i] = "load";
      }
    }
  }

  void clearLabel(String color) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String key = "${MainUI.getProgressKey()}_$color";

    //label data
    if(prefs.containsKey(key)) {
      await prefs.remove(key);
    }
    //control do data with label
    if(prefs.containsKey("${key}_do")) {
      await prefs.remove("${key}_do");
    }
  }
}