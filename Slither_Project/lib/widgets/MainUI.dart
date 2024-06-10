import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../Answer/Answer.dart';
import '../Front/EnterScene.dart';
import '../Scene/GameSceneSquare.dart';
import '../ThemeColor.dart';
import '../User/UserInfo.dart';
import '../l10n/app_localizations.dart';

//use "onUpdate();" for update UI
class MainUI {
  late Size screenSize;
  List<String> puzzleType = ["square"];
  List<String> puzzleSize = ["small"];
  ///shape, size
  List<String> selectedType = ["square", "small"];
  //continue data
  List<String> progressPuzzle = UserInfo.getContinuePuzzle().isEmpty ? [""] : UserInfo.getContinuePuzzle().toList();
  String selectedContinue = "";
  static String progressKey = "";

  final GlobalKey<PopupMenuButtonState<int>> _mainMenuKey = GlobalKey<PopupMenuButtonState<int>>();
  Map<String, String> setting = {};

  final VoidCallback onUpdate;
  //for supporting multilingual
  final AppLocalizations appLocalizations;
  final EnterSceneState enterSceneState;

  MainUI({
    required this.onUpdate,
    required this.appLocalizations,
    required this.enterSceneState
  });

  void loadSetting() {
    //hard copy
    setting = Map.from(UserInfo.getSettingAll());
  }

  PopupMenuButton getMainMenu(BuildContext context) {
    return PopupMenuButton(
      iconSize: 32,
      key: _mainMenuKey,
      onSelected: (value) {
        handleMainMenu(context, value);
      },
      itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
        PopupMenuItem<String>(
          value: 'account',
          child: Text(appLocalizations.translate('MainUI_menuAccount')),
        ),
        PopupMenuItem<String>(
          value: 'setting',
          child: Text(appLocalizations.translate('MainUI_menuSetting')),
        ),
      ],
      icon: const Icon(Icons.menu),
    );
  }

  void handleMainMenu(BuildContext context, String result) {
    loadSetting();

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
                    Text(
                      appLocalizations.translate('MainUI_menuAccount'),
                      style: const TextStyle(
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
                            Text(appLocalizations.translate('MainUI_menuAccount')),
                            Text(UserInfo.progress.toString()), //temp
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          child: Text(appLocalizations.translate('MainUI_btnClose')),
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
                    Text(
                      appLocalizations.translate('MainUI_menuSetting'),
                      style: const TextStyle(
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
                            Text(appLocalizations.translate('MainUI_menuSetting_theme')),
                            DropdownButton(items: ThemeColor().getList().map((String item) {
                              return DropdownMenuItem<String>(
                                value: item,
                                child: Text(item),
                              );
                            }).toList(),
                              onChanged: (value) {
                                setting["theme"] = value.toString();
                                onUpdate();
                              },
                              value: setting["theme"],
                              style: const TextStyle(color: Colors.black, fontSize: 18),),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(appLocalizations.translate('MainUI_menuSetting_language')),
                            DropdownButton(items: UserInfo.getSupportLanguage().map((String item) {
                              return DropdownMenuItem<String>(
                                value: item,
                                child: Text(item),
                              );
                            }).toList(),
                              onChanged: (value) {
                                setting["language"] = value.toString();
                                onUpdate();
                              },
                              value: setting["language"],
                              style: const TextStyle(color: Colors.black, fontSize: 18),),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          child: Text(appLocalizations.translate('MainUI_btnApply')),
                          onPressed: () {
                            enterSceneState.changeLanguage(context, languageToCode(setting["language"]!));
                            //특정 문자만 불러와지지 않는 경우
                            //https://stackoverflow.com/questions/66932705/how-do-i-resolve-id-does-not-exist-error
                            UserInfo.setSettingAll(setting);
                            onUpdate();
                            Navigator.of(context).pop(); // 다이얼로그 닫기
                          },
                        ),
                        TextButton(
                          child: Text(appLocalizations.translate('MainUI_btnClose')),
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

  String languageToCode(String language) {
    String rtValue = "";
    switch(language) {
      case "english":
        rtValue = "en";
        break;
      case "korean":
        rtValue = "ko";
        break;
    }

    return rtValue;
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

  Widget? getContinueWidget(BuildContext context) {
    if(UserInfo.getContinuePuzzle().isEmpty) {
      return null;
    }

    return Column(
      children: [
        Padding(padding: const EdgeInsets.symmetric(vertical: 20), child: Text(appLocalizations.translate('MainUI_btnContinue_title'), style: const TextStyle(fontSize: 24),),),
        Padding(padding: const EdgeInsets.symmetric(vertical: 20), child: getProgressPuzzle(context),),
        Padding(padding: const EdgeInsets.symmetric(vertical: 20), child: getContinueButton(context),),
      ],
    );
  }

  DropdownButton getProgressPuzzle(BuildContext context) {
    progressPuzzle = UserInfo.getContinuePuzzle().isEmpty ? [""] : UserInfo.getContinuePuzzle().toList();
    if(progressKey.isEmpty) {
      progressKey = progressPuzzle[0];
    }

    return DropdownButton(items: progressPuzzle
        .map((e) => DropdownMenuItem(
          value: e, // 선택 시 onChanged 를 통해 반환할 value
          child: Text(e),
        ))
        .toList(),
        onChanged: (value) {
          progressPuzzle[0] = value;
          progressKey = value;
          onUpdate();
        },
        value: progressKey,
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
        int progress = UserInfo.getProgress("${selectedType[0]}_${selectedType[1]}");
        progressKey = "${selectedType[0]}_${selectedType[1]}_$progress";

        //restrict puzzle's EOF
        if(Answer().checkRemainPuzzle(selectedType[0], selectedType[1])) {
          UserInfo.addContinuePuzzle(progressKey);
          onUpdate();
          changeScene(context, progressKey);
        }
        else {
          print("You solved all available puzzles");
        }
      },
      child: Text(appLocalizations.translate('MainUI_btnStart'), style: const TextStyle(fontSize: 24),),
    );
  }

  //about continue button
  ElevatedButton getContinueButton(BuildContext context) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(100, 50),
      ),
      onPressed: () {
        changeScene(context, progressKey, isContinue: true);
      },
      child: Text(appLocalizations.translate('MainUI_btnContinue'), style: TextStyle(fontSize: 24),)
    );
  }

  void changeScene(BuildContext context, String key, {bool isContinue = false}) {
    //print("change Scene with key : $key, isContinue : $isContinue");

    Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => GameSceneSquare(isContinue: isContinue, loadKey: key),
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

  //last tried key
  static String getProgressKey() {
    return progressKey;
  }
}