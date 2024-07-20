// ignore_for_file: file_names
import 'package:firebase_auth/firebase_auth.dart' hide UserInfo;
import 'package:flutter/material.dart';

import '../Answer/Answer.dart';
import '../Front/EnterScene.dart';
import '../Scene/GameSceneSquare.dart';
import '../User/Authentication.dart';
import '../User/UserInfo.dart';
import '../l10n/app_localizations.dart';

//use "onUpdate();" for update UI
//`underline with list` means words of localization (only use for showing)
class MainUI {
  bool debugDropdown = true;

  late Size screenSize;
  List<String> puzzleType = ["square", "triangle"];
  static List<String> _puzzleType = ["square", "triangle"];
  List<String> puzzleSize = ["small"];
  static List<String> _puzzleSize = ["small"];
  ///shape, size
  static List<String> selectedType = ["square", "small"];
  static final List<String> _selectedType = ["square", "small"];
  //continue data
  List<String> progressPuzzle = UserInfo.getContinuePuzzle().isEmpty ? [""] : UserInfo.getContinuePuzzle().toList();
  String selectedContinue = "";
  static String progressKey = "";

  final GlobalKey<PopupMenuButtonState<int>> _mainMenuKey = GlobalKey<PopupMenuButtonState<int>>();
  Map<String, String> setting = {};
  List<String> _theme = [];
  String _themeValue = "default";
  List<String> _language = [];
  String _languageValue = "english";
  List<String> _btnAlignment = [];
  String _btnAlignmentValue = "right";

  late Authentication auth;

  final VoidCallback onUpdate;
  //for supporting multilingual
  final AppLocalizations appLocalizations;
  final EnterSceneState enterSceneState;

  MainUI({
    required this.onUpdate,
    required this.appLocalizations,
    required this.enterSceneState
  }) {
    auth = Authentication();
  }

  PopupMenuButton getMainMenu(BuildContext context) {
    return PopupMenuButton(
      iconSize: 32,
      key: _mainMenuKey,
      onSelected: (value) async {
        await handleMainMenu(context, value);
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

  void loadSetting() {
    //hard copy
    setting = Map.from(UserInfo.getSettingAll());
    applyLanguageCode();
  }

  Future<void> handleMainMenu(BuildContext context, String result) async {
    loadSetting();

    switch(result) {
      case "account":
        //login progress
        if(!UserInfo.authState) {
          final TextEditingController emailInput = TextEditingController();
          final TextEditingController passwordInput = TextEditingController();
          int errType = -1;
          String popupMsg = "";

          // ignore: use_build_context_synchronously
          showDialog(
            context: context,
            builder: (BuildContext context) {
              return StatefulBuilder(
                builder: (BuildContext context, StateSetter setState) {
                  return Dialog(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: LayoutBuilder(
                        builder: (context, constraints) {
                          double containerWidth = screenSize.width < 450
                              ? screenSize.width * 0.6
                              : screenSize.width * 0.4;
                          double labelWidth = containerWidth * 0.2;
                          return Container(
                              width: containerWidth,
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      appLocalizations.translate('MainUI_login'),
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
                                            SizedBox(
                                              width: labelWidth,
                                              child: Text(
                                                appLocalizations.translate('email'),
                                                style: const TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                            Expanded(
                                              child: TextField(
                                                controller: emailInput,
                                                decoration: const InputDecoration(
                                                  border: OutlineInputBorder(),
                                                  labelText: "example@example.com",
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            SizedBox(
                                              width: labelWidth,
                                              child: Text(
                                                appLocalizations.translate('password'),
                                                style: const TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                            Expanded(
                                              child: TextField(
                                                controller: passwordInput,
                                                decoration: const InputDecoration(
                                                  border: OutlineInputBorder(),
                                                  labelText: "password",
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 10),
                                        //error message
                                        Text(
                                          errType == 0 ? "" :
                                          errType == 11 ? appLocalizations.translate('errMsg_Sign04') :
                                          errType == 10 ? appLocalizations.translate('errMsg_Sign01') :
                                          errType == 13 ? appLocalizations.translate('errMsg_Sign02') :
                                          errType == 400 ? appLocalizations.translate('errMsg_Sign03') :
                                          errType == 1 ? appLocalizations.translate('errMsg_Sign05') :
                                          errType == 14 ? appLocalizations.translate('errMsg_Sign06') :
                                          "",
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.red,
                                          ),
                                        ),
                                        const SizedBox(height: 10),
                                        SizedBox(
                                          width: containerWidth * 0.6,
                                          child: ElevatedButton(
                                            onPressed: () async {
                                              auth.setScreenSize(screenSize);
                                              errType = await auth.signInEmail(context, emailInput.text, passwordInput.text);

                                              setState(() {});
                                              onUpdate();
                                              //print("errType : $errType");
                                              if(errType == 0) {
                                                popupMsg = appLocalizations.translate('complete_sign_in');
                                                // ignore: use_build_context_synchronously
                                                Navigator.of(context).pop();
                                              }
                                            },
                                            child: Text(
                                              appLocalizations.translate('sign_in'),
                                              style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 20),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            SizedBox(
                                              width: containerWidth * 0.3,
                                              child: ElevatedButton(
                                                onPressed: () async {
                                                  auth.setScreenSize(screenSize);
                                                  errType = await auth.signUpEmail(context, emailInput.text, passwordInput.text);

                                                  setState(() {});
                                                  onUpdate();
                                                  //print("errType : $errType");
                                                  if(errType == 0) {
                                                    popupMsg = appLocalizations.translate('complete_sign_up');
                                                    // ignore: use_build_context_synchronously
                                                    Navigator.of(context).pop();
                                                  }
                                                },
                                                child: Text(
                                                  appLocalizations.translate('sign_up'),
                                                  style: const TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                  textAlign: TextAlign.center,
                                                ),
                                              ),
                                            ),
                                            SizedBox(
                                              width: containerWidth * 0.1,
                                            ),
                                            SizedBox(
                                              width: containerWidth * 0.3,
                                              child: ElevatedButton(
                                                onPressed: () async {
                                                  auth.setScreenSize(screenSize);
                                                  errType = await auth.resetPasswordEmail(context, emailInput.text);

                                                  setState(() {});
                                                  onUpdate();
                                                  //print("errType : $errType");
                                                  if(errType == 1) {
                                                    popupMsg = appLocalizations.translate('errMsg_Sign05');
                                                    // ignore: use_build_context_synchronously
                                                    Navigator.of(context).pop();
                                                  }
                                                },
                                                child: Text(
                                                  appLocalizations.translate('reset_password'),
                                                  style: const TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                  textAlign: TextAlign.center,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ]
                              )
                          );
                        }
                      )
                  );
                }
              );
            }
          ).then((_) async {
            if(errType == 0) {
              await Future.delayed(const Duration(milliseconds: 100));
              // ignore: use_build_context_synchronously
              auth.popup(context, popupMsg);
            }
          });
        }
        else {
          await UserInfo.init();
          int errType = -1;
          String popupMsg = "";

          // ignore: use_build_context_synchronously
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
                              Text(FirebaseAuth.instance.currentUser!.email.toString()),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(appLocalizations.translate('progressTitle')),
                              Text(UserInfo.getAllProgress()),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            child: Text(appLocalizations.translate('sign_out')),
                            onPressed: () async {
                              auth.setScreenSize(screenSize);
                              errType = await auth.signOutEmail(context);
                              onUpdate();
                              popupMsg = appLocalizations.translate('complete_sign_out');
                              if(errType == 0) {
                                // ignore: use_build_context_synchronously
                                Navigator.of(context).pop();
                              }
                            },
                          ),
                          TextButton(
                            child: Text(appLocalizations.translate('withdraw')),
                            onPressed: () async {
                              auth.setScreenSize(screenSize);
                              errType = await auth.withdrawEmail(context);
                              popupMsg = appLocalizations.translate('complete_withdraw');
                              onUpdate();
                              if(errType == 0) {
                                // ignore: use_build_context_synchronously
                                Navigator.of(context).pop();
                              }
                            },
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
                              Navigator.of(context).pop();
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ).then((_) async {
            if(errType == 0) {
              await Future.delayed(const Duration(milliseconds: 100));
              // ignore: use_build_context_synchronously
              auth.popup(context, popupMsg);
            }
          });
        }
        break;
      case "setting":
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return StatefulBuilder(
              builder: (BuildContext context, StateSetter setState) {
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
                                DropdownButton(
                                  items: _theme.map((String item) {
                                    return DropdownMenuItem<String>(
                                      value: item,
                                      child: Text(item),
                                    );
                                  }).toList(),
                                  onChanged: (value) {
                                    setState(() {
                                      _themeValue = value!;
                                    });
                                    if(debugDropdown) {
                                      // ignore: avoid_print
                                      print("_themeValue : $_themeValue");
                                    }
                                    onUpdate();
                                  },
                                  value: _themeValue,
                                  style: const TextStyle(color: Colors.black, fontSize: 18),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(appLocalizations.translate('MainUI_menuSetting_language')),
                                DropdownButton(items: _language.map((String item) {
                                  return DropdownMenuItem<String>(
                                    value: item,
                                    child: Text(item),
                                  );
                                }).toList(),
                                  onChanged: (value) {
                                    setState(() {
                                      _languageValue = value!;
                                    });
                                    if(debugDropdown) {
                                      // ignore: avoid_print
                                      print("_languageValue : $_languageValue");
                                    }
                                    onUpdate();
                                  },
                                  value: _languageValue,
                                  style: const TextStyle(color: Colors.black, fontSize: 18),),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(appLocalizations.translate('MainUI_menuSetting_btnAlignment')),
                                DropdownButton(items: _btnAlignment.map((String item) {
                                  return DropdownMenuItem<String>(
                                    value: item,
                                    child: Text(item),
                                  );
                                }).toList(),
                                  onChanged: (value) {
                                    setState(() {
                                      _btnAlignmentValue = value!;
                                    });
                                    if(debugDropdown) {
                                      // ignore: avoid_print
                                      print("_btnAlignmentValue : $_btnAlignmentValue");
                                    }
                                    onUpdate();
                                  },
                                  value: _btnAlignmentValue,
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
                                switch(_languageValue) {
                                  case "english":
                                  case "영어":
                                    setting["language"] = "english";
                                    break;
                                  case "korean":
                                  case "한국어":
                                    setting["language"] = "korean";
                                    break;
                                }
                                switch(_themeValue) {
                                  case "default":
                                  case "기본":
                                    setting["theme"] = "default";
                                    break;
                                  case "warm":
                                  case "따뜻한":
                                    setting["theme"] = "warm";
                                    break;
                                  case "cool":
                                  case "시원한":
                                    setting["theme"] = "cool";
                                    break;
                                  case "earth":
                                  case "자연":
                                    setting["theme"] = "earth";
                                    break;
                                  case "pastel":
                                  case "파스텔":
                                    setting["theme"] = "pastel";
                                    break;
                                  case "vibrant":
                                  case "생동감있는":
                                    setting["theme"] = "vibrant";
                                    break;
                                }
                                switch(_btnAlignmentValue) {
                                  case "left":
                                  case "왼쪽":
                                    setting["button_alignment"] = "left";
                                    break;
                                  case "right":
                                  case "오른쪽":
                                    setting["button_alignment"] = "right";
                                    break;
                                }
                                enterSceneState.changeLanguage(context, languageToCode(setting["language"]!));
                                UserInfo.setSettingAll(setting);
                                onUpdate();
                                Navigator.of(context).pop();
                              },
                            ),
                            TextButton(
                              child: Text(appLocalizations.translate('MainUI_btnClose')),
                              onPressed: () {
                                Navigator.of(context).pop();
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }
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

  ///apply language about dropdown button's list
  void applyLanguageCode() {
    //main local
    _puzzleType = [
      appLocalizations.translate('MainUI_puzzleShape_square'),
      appLocalizations.translate('MainUI_puzzleShape_triangle')
    ];
    switch(_selectedType[0]) {
      case "square":
      case "사각형":
        _selectedType[0] = appLocalizations.translate('MainUI_puzzleShape_square');
        selectedType[0] = "square";
        break;
      case "triangle":
      case "삼각형":
        _selectedType[0] = appLocalizations.translate('MainUI_puzzleShape_triangle');
        selectedType[0] = "triangle";
        break;
    }
    _puzzleSize = [appLocalizations.translate('MainUI_puzzleSize_small')];
    switch(_selectedType[1]) {
      case "small":
      case "소형":
        _selectedType[1] = appLocalizations.translate('MainUI_puzzleSize_small');
        selectedType[1] = "small";
        break;
    }


    //main en
    puzzleType = ["square", "triangle"];
    puzzleSize = ["small"];

    _theme = [
      appLocalizations.translate('ThemeName_01'),
      appLocalizations.translate('ThemeName_02'),
      appLocalizations.translate('ThemeName_03'),
      appLocalizations.translate('ThemeName_04'),
      appLocalizations.translate('ThemeName_05'),
      appLocalizations.translate('ThemeName_06')
    ];

    switch (setting["theme"]) {
      case "default":
        _themeValue = appLocalizations.translate('ThemeName_01');
        break;
      case "warm":
        _themeValue = appLocalizations.translate('ThemeName_02');
        break;
      case "cool":
        _themeValue = appLocalizations.translate('ThemeName_03');
        break;
      case "earth":
        _themeValue = appLocalizations.translate('ThemeName_04');
        break;
      case "pastel":
        _themeValue = appLocalizations.translate('ThemeName_05');
        break;
      case "vibrant":
        _themeValue = appLocalizations.translate('ThemeName_06');
        break;
    }

    _language = [
      appLocalizations.translate('language_en'),
      appLocalizations.translate('language_ko')
    ];

    switch(setting["language"]) {
      case "english":
        _languageValue = appLocalizations.translate('language_en');
        break;
      case "korean":
        _languageValue = appLocalizations.translate('language_ko');
        break;
    }

    _btnAlignment = [
      appLocalizations.translate('left'),
      appLocalizations.translate('right')
    ];

    switch(setting["button_alignment"]) {
      case "left":
        _btnAlignmentValue = appLocalizations.translate('left');
        break;
      case "right":
        _btnAlignmentValue = appLocalizations.translate('right');
        break;
    }
  }

  //about puzzle difficulty
  static Widget getPuzzleType(BuildContext context, VoidCallback onUpdate) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        getPuzzleShape(context, onUpdate),
        const SizedBox(
          width: 50,
        ),
        getPuzzleSize(context, onUpdate),
      ],
    );
  }

  static DropdownButton getPuzzleShape(BuildContext context, VoidCallback onUpdate) {
    return DropdownButton(items: _puzzleType
        .map((e) => DropdownMenuItem(
      value: e, // 선택 시 onChanged 를 통해 반환할 value
      child: Text(e),
    ))
        .toList(),
      onChanged: (value) async {
        await changePuzzleShape(value, onUpdate);
      },
      value: _selectedType[0],
      style: const TextStyle(color: Colors.white, fontSize: 24),
      dropdownColor: Colors.grey,
    );
  }

  static Future<void> changePuzzleShape(dynamic value, VoidCallback onUpdate) async {
    _selectedType[0] = value;
    //en
    switch(value) {
      case "square":
      case "사각형":
        selectedType[0] = "square";
        break;

      case "triangle":
      case "삼각형":
        selectedType[0] = "triangle";
        break;
    }
    onUpdate();
  }

  static DropdownButton getPuzzleSize(BuildContext context, VoidCallback onUpdate) {
    return DropdownButton(items: _puzzleSize
        .map((e) => DropdownMenuItem(
      value: e, // 선택 시 onChanged 를 통해 반환할 value
      child: Text(e),
    ))
        .toList(),
      onChanged: (value) {
        _selectedType[1] = value;
      },
      value: _selectedType[1],
      style: const TextStyle(color: Colors.white, fontSize: 24),
      dropdownColor: Colors.grey,
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
      dropdownColor: Colors.grey,
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
        if(Answer(context: context).checkRemainPuzzle(context, selectedType[0], selectedType[1])) {
          UserInfo.addContinuePuzzle(progressKey);
          onUpdate();
          changeScene(context, progressKey);
        }
        else {
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
        child: Text(appLocalizations.translate('MainUI_btnContinue'), style: const TextStyle(fontSize: 24),)
    );
  }

  void changeScene(BuildContext context, String key, {bool isContinue = false}) {
    //print("change Scene with key : $key, isContinue : $isContinue");
    List<String> token = key.split("_");

    switch(token[0]) {
      case "square":
        Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => GameSceneSquare(isContinue: isContinue, loadKey: key),
            )
        );
        break;
      case "triangle":
        Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => GameSceneSquare(isContinue: isContinue, loadKey: key),
            )
        );
        break;
    }
  }

  //about screen size
  double getTopMargin() {
    return screenSize.height / 10;
  }

  double getMargin(double ratio) {
    return screenSize.height * ratio;
  }

  void setScreenSize(Size size) {
    screenSize = size;
    auth.setScreenSize(size);
  }

  Size getScreenSize(Size size) {
    return screenSize;
  }

  //last tried key
  static String getProgressKey() {
    return progressKey;
  }
}