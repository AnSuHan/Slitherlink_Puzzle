// ignore_for_file: file_names
import 'package:firebase_auth/firebase_auth.dart' hide UserInfo;
import 'package:flutter/material.dart';

import '../Answer/Answer.dart';
import '../Front/EnterScene.dart';
import '../Front/HowToPlay.dart';
import '../Scene/GameSceneSquare.dart';
import '../ThemeColor.dart';
import '../User/Authentication.dart';
import '../User/UserInfo.dart';
import '../l10n/app_localizations.dart';

//use "onUpdate();" for update UI
//`underline with list` means words of localization (only use for showing)
class MainUI {
  bool debugDropdown = false;

  late Size screenSize;
  List<String> puzzleMode = ["debug", "release"];
  String selectedMode= "release";

  List<String> puzzleType = ["square", "triangle"];
  static List<String> _puzzleType = ["square", "triangle"];
  List<String> puzzleSize = ["small", "generate"];
  static List<String> _puzzleSize = ["small", "generate"];
  ///shape, size
  static List<String> selectedType = ["square", "generate"];
  static final List<String> _selectedType = ["square", "generate"];

  // Generate mode settings
  List<String> difficultyList = ["easy", "normal", "hard"];
  static List<String> _difficultyList = ["easy", "normal", "hard"];
  static String selectedDifficulty = "normal";
  static String _selectedDifficulty = "normal";
  static int generateRows = 10;
  static int generateCols = 10;
  //continue data
  List<String> progressPuzzle = UserInfo.getContinuePuzzle().isEmpty ? [""] : UserInfo.getContinuePuzzle().toList();
  static String progressKey = "";

  final GlobalKey<PopupMenuButtonState<int>> _mainMenuKey = GlobalKey<PopupMenuButtonState<int>>();
  Map<String, String> setting = {};
  List<String> _theme = [];
  String _themeValue = "default";
  List<String> _language = [];
  String _languageValue = "english";
  List<String> _appbar = [];
  String _appbarValue = "fixed";
  List<String> _btnAlignment = [];
  String _btnAlignmentValue = "right";

  String prevLanguage = "";

  late Authentication auth;
  late Answer answer;

  final VoidCallback onUpdate;
  //for supporting multilingual
  AppLocalizations appLocalizations;
  final EnterSceneState enterSceneState;
  final BuildContext context;

  MainUI({
    required this.onUpdate,
    required this.appLocalizations,
    required this.enterSceneState,
    required this.context,
  }) {
    auth = Authentication();
    //subscription of stream
    checkLanguage().listen((event) {});
    answer = Answer(context: context, loadPreset: true);
  }

  void setAppLocalizations(AppLocalizations appLocalizations) {
    this.appLocalizations = appLocalizations;
  }

  void updateUI() {
    onUpdate();
  }

  ///check language per 1sec
  Stream<void> checkLanguage() async* {
    prevLanguage = "en";
    while(true) {
      await Future.delayed(const Duration(seconds: 1));
      String lang = appLocalizations.locale.languageCode;
      if(prevLanguage.compareTo(lang) != 0) {
        enterSceneState.changeLanguage(lang);

        prevLanguage = lang;
        onUpdate();
      }
      yield null;
    }
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
          value: 'how',
          child: Text(appLocalizations.translate('MainUI_menuHowToPlay')),
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
          final palette = ThemeColor().getPalette();
          final isDark = ThemeColor().isDark();

          // ignore: use_build_context_synchronously
          showDialog(
            context: context,
            builder: (BuildContext context) {
              //내부의 변경 사항을 적용하기 위해 사용
              return StatefulBuilder(
                builder: (BuildContext context, StateSetter setState) {
                  return Dialog(
                    backgroundColor: isDark ? const Color(0xFF1E1E3A) : Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    //showDialog의 height-overflow를 처리하기 위해 사용
                    child: SingleChildScrollView(
                      child: LayoutBuilder(
                          builder: (context, constraints) {
                            double containerWidth = screenSize.width < 450
                                ? screenSize.width * 0.6
                                : screenSize.width * 0.4;
                            double labelWidth = containerWidth * 0.2;

                            double buttonHeight = 0;
                            // Create TextPainter for the 'sign up' and 'reset password' buttons
                            TextPainter createTextPainter(String text, double maxWidth) {
                              final textSpan = TextSpan(
                                text: text,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              );

                              final textPainter = TextPainter(
                                text: textSpan,
                                textDirection: TextDirection.ltr,
                                maxLines: null,
                              );

                              // 텍스트를 두 줄로 강제하기 위해 추가 설정
                              textPainter.layout(minWidth: maxWidth, maxWidth: maxWidth);

                              // 한 줄의 높이 계산
                              final double lineHeight = textPainter.preferredLineHeight;

                              // 텍스트 높이가 두 줄 이상이 되도록 강제
                              final double calculatedHeight = textPainter.height > lineHeight ? textPainter.height : lineHeight * 2;
                              buttonHeight = calculatedHeight;

                              return textPainter;
                            }

                            createTextPainter(
                                appLocalizations.translate('reset_password'), containerWidth * 0.5);

                            return Container(
                                width: containerWidth,
                                padding: const EdgeInsets.all(24),
                                child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(Icons.login_rounded, color: palette['primary'], size: 28),
                                          const SizedBox(width: 10),
                                          Text(
                                            appLocalizations.translate('MainUI_login'),
                                            style: TextStyle(
                                              fontSize: 22,
                                              fontWeight: FontWeight.w700,
                                              color: palette['onSurface'],
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 24),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.stretch,
                                        children: [
                                          SizedBox(
                                            width: labelWidth,
                                            child: Align(
                                              alignment: Alignment.centerLeft,
                                              child: Text(
                                                appLocalizations.translate('email'),
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w600,
                                                  color: palette['onSurfaceDim'],
                                                  letterSpacing: 0.5,
                                                ),
                                              ),
                                            ),
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.only(top: 8),
                                            child: TextField(
                                              controller: emailInput,
                                              style: TextStyle(color: palette['onSurface']),
                                              decoration: InputDecoration(
                                                border: OutlineInputBorder(
                                                  borderRadius: BorderRadius.circular(12),
                                                  borderSide: BorderSide(color: palette['divider']!),
                                                ),
                                                enabledBorder: OutlineInputBorder(
                                                  borderRadius: BorderRadius.circular(12),
                                                  borderSide: BorderSide(color: palette['divider']!),
                                                ),
                                                focusedBorder: OutlineInputBorder(
                                                  borderRadius: BorderRadius.circular(12),
                                                  borderSide: BorderSide(color: palette['primary']!, width: 2),
                                                ),
                                                labelText: "example@example.com",
                                                labelStyle: TextStyle(color: palette['onSurfaceDim']),
                                                filled: true,
                                                fillColor: palette['surfaceLight'],
                                              ),
                                            ),
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.only(top: 12),
                                            child: SizedBox(
                                              width: labelWidth,
                                              child: Align(
                                                alignment: Alignment.centerLeft,
                                                child: Text(
                                                  appLocalizations.translate('password'),
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w600,
                                                    color: palette['onSurfaceDim'],
                                                    letterSpacing: 0.5,
                                                  ),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.visible,
                                                ),
                                              ),
                                            ),
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.only(top: 8.0),
                                            child: TextField(
                                              controller: passwordInput,
                                              obscureText: true,
                                              style: TextStyle(color: palette['onSurface']),
                                              decoration: InputDecoration(
                                                border: OutlineInputBorder(
                                                  borderRadius: BorderRadius.circular(12),
                                                  borderSide: BorderSide(color: palette['divider']!),
                                                ),
                                                enabledBorder: OutlineInputBorder(
                                                  borderRadius: BorderRadius.circular(12),
                                                  borderSide: BorderSide(color: palette['divider']!),
                                                ),
                                                focusedBorder: OutlineInputBorder(
                                                  borderRadius: BorderRadius.circular(12),
                                                  borderSide: BorderSide(color: palette['primary']!, width: 2),
                                                ),
                                                labelText: "password",
                                                labelStyle: TextStyle(color: palette['onSurfaceDim']),
                                                filled: true,
                                                fillColor: palette['surfaceLight'],
                                              ),
                                            ),
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
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.red,
                                            ),
                                          ),
                                          const SizedBox(height: 16),
                                          SizedBox(
                                            width: containerWidth * 0.6,
                                            child: ElevatedButton(
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: palette['buttonBg'],
                                                foregroundColor: palette['buttonText'],
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                                padding: const EdgeInsets.symmetric(vertical: 14),
                                                elevation: 0,
                                              ),
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
                                            children: [
                                              SizedBox(
                                                height: buttonHeight,
                                                child: OutlinedButton(
                                                  style: OutlinedButton.styleFrom(
                                                    foregroundColor: palette['onSurface'],
                                                    side: BorderSide(color: palette['divider']!),
                                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                                  ),
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
                                                    style: TextStyle(
                                                      fontSize: 16,
                                                      fontWeight: FontWeight.bold,
                                                      color: palette['onSurface'],
                                                    ),
                                                    textAlign: TextAlign.center,
                                                    overflow: TextOverflow.visible,
                                                  ),
                                                ),
                                              ),
                                              const Spacer(),
                                              SizedBox(
                                                height: buttonHeight,
                                                child: OutlinedButton(
                                                  style: OutlinedButton.styleFrom(
                                                    foregroundColor: palette['onSurface'],
                                                    side: BorderSide(color: palette['divider']!),
                                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                                  ),
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
                                                    style: TextStyle(
                                                      fontSize: 16,
                                                      fontWeight: FontWeight.bold,
                                                      color: palette['onSurface'],
                                                    ),
                                                    textAlign: TextAlign.center,
                                                    maxLines: 2,
                                                    softWrap: true,
                                                    overflow: TextOverflow.visible,
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
                        ),
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
              final acctPalette = ThemeColor().getPalette();
              final acctIsDark = ThemeColor().isDark();
              return Dialog(
                backgroundColor: acctIsDark ? const Color(0xFF1E1E3A) : Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Container(
                  width: 320,
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.account_circle_rounded, color: acctPalette['primary'], size: 28),
                          const SizedBox(width: 10),
                          Text(
                            appLocalizations.translate('MainUI_menuAccount'),
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: acctPalette['onSurface'],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                appLocalizations.translate('MainUI_menuAccount'),
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: acctPalette['onSurfaceDim'],
                                ),
                              ),
                              Text(
                                FirebaseAuth.instance.currentUser!.email.toString(),
                                style: TextStyle(color: acctPalette['onSurface']),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                appLocalizations.translate('progressTitle'),
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: acctPalette['onSurfaceDim'],
                                ),
                              ),
                              Text(
                                UserInfo.getAllProgress(),
                                style: TextStyle(color: acctPalette['onSurface']),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: acctPalette['onSurfaceDim'],
                                side: BorderSide(color: acctPalette['divider']!),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
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
                              child: Text(appLocalizations.translate('sign_out')),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.red,
                                side: const BorderSide(color: Colors.red),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
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
                              child: Text(appLocalizations.translate('withdraw')),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: TextButton(
                          style: TextButton.styleFrom(
                            foregroundColor: acctPalette['onSurfaceDim'],
                          ),
                          onPressed: () {
                            Navigator.of(context).pop();
                          },
                          child: Text(appLocalizations.translate('MainUI_btnClose')),
                        ),
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
        _showSettingsDialog(context);
        break;
      case "how":
        Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const HowToPlay(),
            )
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
    _puzzleSize = [
      appLocalizations.translate('MainUI_puzzleSize_small'),
      appLocalizations.translate('MainUI_puzzleSize_generate'),
    ];
    switch(_selectedType[1]) {
      case "small":
      case "소형":
        _selectedType[1] = appLocalizations.translate('MainUI_puzzleSize_small');
        selectedType[1] = "small";
        break;
      case "generate":
      case "생성":
        _selectedType[1] = appLocalizations.translate('MainUI_puzzleSize_generate');
        selectedType[1] = "generate";
        break;
    }

    _difficultyList = [
      appLocalizations.translate('MainUI_difficulty_easy'),
      appLocalizations.translate('MainUI_difficulty_normal'),
      appLocalizations.translate('MainUI_difficulty_hard'),
    ];
    switch(_selectedDifficulty) {
      case "easy":
      case "쉬움":
        _selectedDifficulty = appLocalizations.translate('MainUI_difficulty_easy');
        selectedDifficulty = "easy";
        break;
      case "normal":
      case "보통":
        _selectedDifficulty = appLocalizations.translate('MainUI_difficulty_normal');
        selectedDifficulty = "normal";
        break;
      case "hard":
      case "어려움":
        _selectedDifficulty = appLocalizations.translate('MainUI_difficulty_hard');
        selectedDifficulty = "hard";
        break;
    }

    //main en
    puzzleType = ["square", "triangle"];
    puzzleSize = ["small", "generate"];

    _theme = [
      appLocalizations.translate('ThemeName_01'),
      appLocalizations.translate('ThemeName_02'),
      appLocalizations.translate('ThemeName_03'),
    ];

    switch (setting["theme"]) {
      case "default":
      case "midnight":
        _themeValue = appLocalizations.translate('ThemeName_01');
        break;
      case "ocean":
        _themeValue = appLocalizations.translate('ThemeName_02');
        break;
      case "sakura":
        _themeValue = appLocalizations.translate('ThemeName_03');
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

    _appbar = [
      appLocalizations.translate('appbar_mode01'),
      appLocalizations.translate('appbar_mode02')
    ];

    switch(setting["appbar_mode"]) {
      case "fixed":
        _appbarValue = appLocalizations.translate('appbar_mode01');
        break;
      case "toggle":
        _appbarValue = appLocalizations.translate('appbar_mode02');
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
  Widget getPuzzleType(BuildContext context, VoidCallback onUpdate) {
    applyLanguageCode();

    List<Widget> children = [
      if (UserInfo.debugMode["loadTestAnswer"]!) getPuzzleMode(context, onUpdate),
      if (UserInfo.debugMode["loadTestAnswer"]!) const SizedBox(width: 50,),
      getPuzzleShape(context, onUpdate),
      const SizedBox(width: 50,),
      getPuzzleSize(context, onUpdate),
    ];

    if (selectedType[1] == "generate") {
      children.addAll([
        const SizedBox(width: 50,),
        getPuzzleDifficulty(context, onUpdate),
      ]);
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: children,
      ),
    );
  }

  Widget getGenerateSizeSelector(BuildContext context, VoidCallback onUpdate) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text("${appLocalizations.translate('MainUI_generateRows')}: ", style: const TextStyle(color: Colors.white, fontSize: 18)),
        SizedBox(
          width: 60,
          child: DropdownButton<int>(
            items: [5, 7, 10, 15, 20].map((e) => DropdownMenuItem(value: e, child: Text("$e"))).toList(),
            onChanged: (value) {
              generateRows = value ?? 10;
              onUpdate();
            },
            value: generateRows,
            style: const TextStyle(color: Colors.white, fontSize: 18),
            dropdownColor: Colors.grey,
            isExpanded: true,
          ),
        ),
        const SizedBox(width: 30,),
        Text("${appLocalizations.translate('MainUI_generateCols')}: ", style: const TextStyle(color: Colors.white, fontSize: 18)),
        SizedBox(
          width: 60,
          child: DropdownButton<int>(
            items: [5, 7, 10, 15, 20].map((e) => DropdownMenuItem(value: e, child: Text("$e"))).toList(),
            onChanged: (value) {
              generateCols = value ?? 10;
              onUpdate();
            },
            value: generateCols,
            style: const TextStyle(color: Colors.white, fontSize: 18),
            dropdownColor: Colors.grey,
            isExpanded: true,
          ),
        ),
      ],
    );
  }

  DropdownButton getPuzzleDifficulty(BuildContext context, VoidCallback onUpdate) {
    return DropdownButton(items: _difficultyList
        .map((e) => DropdownMenuItem(
      value: e,
      child: Text(e),
    ))
        .toList(),
      onChanged: (value) {
        _selectedDifficulty = value;
        switch(value) {
          case "easy":
          case "쉬움":
            selectedDifficulty = "easy";
            break;
          case "normal":
          case "보통":
            selectedDifficulty = "normal";
            break;
          case "hard":
          case "어려움":
            selectedDifficulty = "hard";
            break;
        }
        onUpdate();
      },
      value: _selectedDifficulty,
      style: const TextStyle(color: Colors.white, fontSize: 24),
      dropdownColor: Colors.grey,
    );
  }

  //for debug (no translation)
  DropdownButton getPuzzleMode(BuildContext context, VoidCallback onUpdate) {
    return DropdownButton(items: puzzleMode
        .map((e) => DropdownMenuItem(
      value: e, // 선택 시 onChanged 를 통해 반환할 value
      child: Text(e),
    ))
        .toList(),
      onChanged: (value) async {
        selectedMode = value;
        onUpdate();
      },
      value: selectedMode,
      style: const TextStyle(color: Colors.white, fontSize: 24),
      dropdownColor: Colors.grey,
    );
  }

  DropdownButton getPuzzleShape(BuildContext context, VoidCallback onUpdate) {
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

  Future<void> changePuzzleShape(dynamic value, VoidCallback onUpdate) async {
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

  DropdownButton getPuzzleSize(BuildContext context, VoidCallback onUpdate) {
    return DropdownButton(items: _puzzleSize
        .map((e) => DropdownMenuItem(
      value: e,
      child: Text(e),
    ))
        .toList(),
      onChanged: (value) {
        _selectedType[1] = value;
        switch(value) {
          case "small":
          case "소형":
            selectedType[1] = "small";
            break;
          case "generate":
          case "생성":
            selectedType[1] = "generate";
            break;
        }
        onUpdate();
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
    //when complete puzzle in continue
    if(!progressPuzzle.contains(progressKey)) {
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
      onPressed: () async {
        // Generate mode: create key like "square_generate_10x10_normal"
        if (selectedType[1] == "generate") {
          progressKey = "${selectedType[0]}_generate_${generateRows}x${generateCols}_$selectedDifficulty";
          // ignore: use_build_context_synchronously
          changeScene(context, progressKey);
          return;
        }

        int progress = UserInfo.getProgress("${selectedType[0]}_${selectedType[1]}");
        progressKey = "${selectedType[0]}_${selectedType[1]}_$progress";
        //for debug
        if(selectedMode.compareTo("debug") == 0) {
          //print("debug key : $progressKey");
          // ignore: use_build_context_synchronously
          changeScene(context, "${progressKey}_test");
          return;
        }
        //restrict puzzle's EOF
        // ignore: use_build_context_synchronously
        if(await answer.checkRemainPuzzle(context, selectedType[0], selectedType[1])) {
          UserInfo.addContinuePuzzle(progressKey);
          onUpdate();
          // ignore: use_build_context_synchronously
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
    bool isDebugMode = selectedMode.compareTo("debug") == 0;

    switch(token[0]) {
      case "square":
        Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => GameSceneSquare(isContinue: isContinue, loadKey: key, testMode: isDebugMode),
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
  double getMargin(double ratio) {
    return screenSize.height * ratio;
  }

  void setScreenSize(Size size) {
    screenSize = size;
    auth.setScreenSize(size);
  }

  //last tried key
  static String getProgressKey() {
    return progressKey;
  }

  // ============================================================
  // Modern UI Methods (used by redesigned EnterScene)
  // ============================================================

  /// Chip-style puzzle type selector (shape + size)
  Widget getPuzzleTypeChips(BuildContext context, VoidCallback onUpdate, Map<String, Color> palette) {
    applyLanguageCode();
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _buildLabel(appLocalizations.translate('MainUI_puzzleShape_square'), palette),
        ..._buildChipGroup(
          items: ["small", "generate"],
          labels: [
            appLocalizations.translate('MainUI_puzzleSize_small'),
            appLocalizations.translate('MainUI_puzzleSize_generate'),
          ],
          selected: selectedType[1],
          palette: palette,
          onSelected: (value) {
            selectedType[1] = value;
            _selectedType[1] = value == "small"
                ? appLocalizations.translate('MainUI_puzzleSize_small')
                : appLocalizations.translate('MainUI_puzzleSize_generate');
            onUpdate();
          },
        ),
      ],
    );
  }

  Widget _buildLabel(String text, Map<String, Color> palette) {
    return Chip(
      label: Text(text, style: TextStyle(color: palette['buttonText'], fontWeight: FontWeight.w600)),
      backgroundColor: palette['primary']!.withOpacity(0.8),
      side: BorderSide.none,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    );
  }

  List<Widget> _buildChipGroup({
    required List<String> items,
    required List<String> labels,
    required String selected,
    required Map<String, Color> palette,
    required Function(String) onSelected,
  }) {
    return List.generate(items.length, (i) {
      bool isSelected = selected == items[i];
      return ChoiceChip(
        label: Text(labels[i]),
        selected: isSelected,
        selectedColor: palette['accent']!.withOpacity(0.2),
        backgroundColor: palette['surface']!.withOpacity(0.5),
        labelStyle: TextStyle(
          color: isSelected ? palette['accent'] : palette['onSurfaceDim'],
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
        ),
        side: BorderSide(
          color: isSelected ? palette['accent']! : palette['divider']!,
          width: isSelected ? 1.5 : 1,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        onSelected: (_) => onSelected(items[i]),
      );
    });
  }

  /// Chip-style difficulty selector
  Widget getDifficultyChips(BuildContext context, VoidCallback onUpdate, Map<String, Color> palette) {
    List<String> difficulties = ["easy", "normal", "hard"];
    List<String> labels = [
      appLocalizations.translate('MainUI_difficulty_easy'),
      appLocalizations.translate('MainUI_difficulty_normal'),
      appLocalizations.translate('MainUI_difficulty_hard'),
    ];
    List<IconData> icons = [Icons.sentiment_satisfied, Icons.trending_flat, Icons.local_fire_department];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: List.generate(difficulties.length, (i) {
        bool isSelected = selectedDifficulty == difficulties[i];
        return ChoiceChip(
          avatar: Icon(icons[i], size: 18, color: isSelected ? palette['accent'] : palette['onSurfaceDim']),
          label: Text(labels[i]),
          selected: isSelected,
          selectedColor: palette['accent']!.withOpacity(0.2),
          backgroundColor: palette['surface']!.withOpacity(0.5),
          labelStyle: TextStyle(
            color: isSelected ? palette['accent'] : palette['onSurfaceDim'],
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
          ),
          side: BorderSide(
            color: isSelected ? palette['accent']! : palette['divider']!,
            width: isSelected ? 1.5 : 1,
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          onSelected: (_) {
            selectedDifficulty = difficulties[i];
            _selectedDifficulty = labels[i];
            onUpdate();
          },
        );
      }),
    );
  }

  /// Slider-style row/col selector for generate mode
  Widget getGenerateSizeSliders(BuildContext context, VoidCallback onUpdate, Map<String, Color> palette) {
    return Column(
      children: [
        Row(
          children: [
            SizedBox(
              width: 50,
              child: Text(
                "${appLocalizations.translate('MainUI_generateRows')}: $generateRows",
                style: TextStyle(color: palette['onSurfaceDim'], fontSize: 13),
              ),
            ),
            Expanded(
              child: SliderTheme(
                data: SliderThemeData(
                  activeTrackColor: palette['primary'],
                  inactiveTrackColor: palette['divider'],
                  thumbColor: palette['primary'],
                  overlayColor: palette['primary']!.withOpacity(0.1),
                  trackHeight: 3,
                ),
                child: Slider(
                  value: generateRows.toDouble(),
                  min: 3,
                  max: 20,
                  divisions: 17,
                  label: "$generateRows",
                  onChanged: (v) {
                    generateRows = v.round();
                    onUpdate();
                  },
                ),
              ),
            ),
          ],
        ),
        Row(
          children: [
            SizedBox(
              width: 50,
              child: Text(
                "${appLocalizations.translate('MainUI_generateCols')}: $generateCols",
                style: TextStyle(color: palette['onSurfaceDim'], fontSize: 13),
              ),
            ),
            Expanded(
              child: SliderTheme(
                data: SliderThemeData(
                  activeTrackColor: palette['primary'],
                  inactiveTrackColor: palette['divider'],
                  thumbColor: palette['primary'],
                  overlayColor: palette['primary']!.withOpacity(0.1),
                  trackHeight: 3,
                ),
                child: Slider(
                  value: generateCols.toDouble(),
                  min: 3,
                  max: 20,
                  divisions: 17,
                  label: "$generateCols",
                  onChanged: (v) {
                    generateCols = v.round();
                    onUpdate();
                  },
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Continue game list for new UI
  Widget getContinueList(BuildContext context, Map<String, Color> palette) {
    progressPuzzle = UserInfo.getContinuePuzzle().isEmpty ? [""] : UserInfo.getContinuePuzzle().toList();
    if (progressKey.isEmpty) {
      progressKey = progressPuzzle[0];
    }
    if (!progressPuzzle.contains(progressKey)) {
      progressKey = progressPuzzle[0];
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: palette['divider']!),
      ),
      child: DropdownButton<String>(
        items: progressPuzzle.map((e) => DropdownMenuItem(
          value: e,
          child: Text(e, style: TextStyle(color: palette['onSurface'])),
        )).toList(),
        onChanged: (value) {
          progressKey = value ?? progressKey;
          onUpdate();
        },
        value: progressKey,
        isExpanded: true,
        underline: const SizedBox(),
        style: TextStyle(color: palette['onSurface'], fontSize: 15),
        dropdownColor: palette['cardBg'],
        icon: Icon(Icons.expand_more, color: palette['onSurfaceDim']),
      ),
    );
  }

  /// Start game action for new UI
  void startGame(BuildContext context) {
    progressKey = "${selectedType[0]}_generate_${generateRows}x${generateCols}_$selectedDifficulty";

    // 같은 설정의 진행 중인 퍼즐이 있으면 이어하기
    if (UserInfo.continuePuzzle.contains(progressKey)) {
      changeScene(context, progressKey, isContinue: true);
      return;
    }

    UserInfo.continuePuzzle.add(progressKey);
    UserInfo.continuePuzzleDate[progressKey] = DateTime.now().toIso8601String().substring(0, 10);
    UserInfo.saveContinuePuzzle();
    onUpdate();
    changeScene(context, progressKey);
  }

  /// Continue game action for new UI
  void continueGame(BuildContext context) {
    changeScene(context, progressKey, isContinue: true);
  }

  /// Show bottom sheet to select and manage in-progress puzzles
  void showContinueSheet(BuildContext context, Map<String, Color> palette, bool isDark, AppLocalizations loc) {
    progressPuzzle = UserInfo.getContinuePuzzle().isEmpty ? [""] : UserInfo.getContinuePuzzle().toList();
    if (progressKey.isEmpty || !progressPuzzle.contains(progressKey)) {
      progressKey = progressPuzzle[0];
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1E1E3A) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            final puzzles = UserInfo.getContinuePuzzle().toList();
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40, height: 4,
                      decoration: BoxDecoration(
                        color: palette['divider'],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Icon(Icons.history_rounded, color: palette['primary'], size: 22),
                      const SizedBox(width: 8),
                      Text(
                        loc.translate('MainUI_btnContinue_title'),
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: palette['onSurface']),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(context).size.height * 0.4,
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: puzzles.length,
                      separatorBuilder: (_, __) => Divider(height: 1, color: palette['divider']!.withOpacity(0.3)),
                      itemBuilder: (context, index) {
                        final key = puzzles[index];
                        final tokens = key.split("_");
                        // "square_generate_10x10_normal" → type, size, difficulty
                        final type = tokens.isNotEmpty ? tokens[0] : "";
                        final size = tokens.length >= 3 ? tokens[2] : "";
                        final difficulty = tokens.length >= 4 ? tokens[3] : "";
                        final date = UserInfo.getPuzzleCreatedDate(key);

                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          title: Text(
                            "$size  $difficulty",
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: palette['onSurface']),
                          ),
                          subtitle: Text(
                            "${type.toUpperCase()}${date.isNotEmpty ? '  ·  $date' : ''}",
                            style: TextStyle(fontSize: 12, color: palette['onSurfaceDim']),
                          ),
                          trailing: IconButton(
                            icon: Icon(Icons.delete_outline_rounded, color: palette['onSurfaceDim'], size: 20),
                            onPressed: () {
                              UserInfo.clearPuzzle(key);
                              if (UserInfo.getContinuePuzzle().isEmpty) {
                                Navigator.pop(context);
                                onUpdate();
                              } else {
                                setState(() {});
                              }
                            },
                          ),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          onTap: () {
                            Navigator.pop(context);
                            progressKey = key;
                            changeScene(context, key, isContinue: true);
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  /// Modern settings dialog
  void _showSettingsDialog(BuildContext context) {
    loadSetting();
    final palette = ThemeColor().getPalette();
    final isDark = ThemeColor().isDark();

    String tempTheme = setting["theme"] ?? "midnight";
    String tempLang = setting["language"] ?? "english";
    String tempAppbar = setting["appbar_mode"] ?? "fixed";
    String tempBtnAlign = setting["button_alignment"] ?? "right";

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return Dialog(
              backgroundColor: isDark ? const Color(0xFF1E1E3A) : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              child: Container(
                width: 360,
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      children: [
                        Icon(Icons.tune_rounded, color: palette['primary'], size: 28),
                        const SizedBox(width: 10),
                        Text(
                          appLocalizations.translate('MainUI_menuSetting'),
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: palette['onSurface'],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Theme selection
                    _settingLabel(appLocalizations.translate('MainUI_menuSetting_theme'), palette),
                    const SizedBox(height: 8),
                    _buildThemeSelector(tempTheme, palette, isDark, (value) {
                      setState(() { tempTheme = value; });
                    }),
                    const SizedBox(height: 20),

                    // Language
                    _settingLabel(appLocalizations.translate('MainUI_menuSetting_language'), palette),
                    const SizedBox(height: 8),
                    _buildToggleRow(
                      options: ["english", "korean"],
                      labels: ["English", "한국어"],
                      selected: tempLang,
                      palette: palette,
                      isDark: isDark,
                      onSelected: (v) => setState(() { tempLang = v; }),
                    ),
                    const SizedBox(height: 20),

                    // Appbar mode
                    _settingLabel(appLocalizations.translate('MainUI_menuSetting_appbar'), palette),
                    const SizedBox(height: 8),
                    _buildToggleRow(
                      options: ["fixed", "toggle"],
                      labels: [
                        appLocalizations.translate('appbar_mode01'),
                        appLocalizations.translate('appbar_mode02'),
                      ],
                      selected: tempAppbar,
                      palette: palette,
                      isDark: isDark,
                      onSelected: (v) => setState(() { tempAppbar = v; }),
                    ),
                    const SizedBox(height: 20),

                    // Button alignment
                    _settingLabel(appLocalizations.translate('MainUI_menuSetting_btnAlignment'), palette),
                    const SizedBox(height: 8),
                    _buildToggleRow(
                      options: ["left", "right"],
                      labels: [
                        appLocalizations.translate('left'),
                        appLocalizations.translate('right'),
                      ],
                      selected: tempBtnAlign,
                      palette: palette,
                      isDark: isDark,
                      onSelected: (v) => setState(() { tempBtnAlign = v; }),
                    ),

                    const SizedBox(height: 28),

                    // Buttons
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: palette['onSurfaceDim'],
                              side: BorderSide(color: palette['divider']!),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            onPressed: () => Navigator.of(context).pop(),
                            child: Text(appLocalizations.translate('MainUI_btnClose')),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: palette['buttonBg'],
                              foregroundColor: palette['buttonText'],
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              elevation: 0,
                            ),
                            onPressed: () async {
                              setting["theme"] = tempTheme;
                              setting["language"] = tempLang;
                              setting["appbar_mode"] = tempAppbar;
                              setting["button_alignment"] = tempBtnAlign;

                              await UserInfo.setSettingAll(setting);
                              enterSceneState.changeLanguage(languageToCode(setting["language"]!));
                              onUpdate();

                              // ignore: use_build_context_synchronously
                              Navigator.of(context).pop();
                            },
                            child: Text(appLocalizations.translate('MainUI_btnApply')),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _settingLabel(String text, Map<String, Color> palette) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: palette['onSurfaceDim'],
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildThemeSelector(String selected, Map<String, Color> palette, bool isDark, Function(String) onSelected) {
    final themes = [
      {"key": "midnight", "icon": Icons.dark_mode_rounded, "color": const Color(0xFF6C63FF)},
      {"key": "ocean", "icon": Icons.water_rounded, "color": const Color(0xFF0288D1)},
      {"key": "sakura", "icon": Icons.local_florist_rounded, "color": const Color(0xFFE91E63)},
    ];
    final labels = _theme;

    return Row(
      children: List.generate(themes.length, (i) {
        String key = themes[i]["key"] as String;
        bool isSelected = selected == key || (selected == "default" && key == "midnight");
        Color color = themes[i]["color"] as Color;

        return Expanded(
          child: GestureDetector(
            onTap: () => onSelected(key),
            child: Container(
              margin: EdgeInsets.only(right: i < 2 ? 8 : 0),
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: isSelected ? color.withOpacity(0.15) : (isDark ? const Color(0xFF2A2A4A) : const Color(0xFFF5F5F5)),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected ? color : Colors.transparent,
                  width: 2,
                ),
              ),
              child: Column(
                children: [
                  Icon(themes[i]["icon"] as IconData, color: color, size: 24),
                  const SizedBox(height: 4),
                  Text(
                    i < labels.length ? labels[i] : key,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                      color: isSelected ? color : palette['onSurfaceDim'],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildToggleRow({
    required List<String> options,
    required List<String> labels,
    required String selected,
    required Map<String, Color> palette,
    required bool isDark,
    required Function(String) onSelected,
  }) {
    return Row(
      children: List.generate(options.length, (i) {
        bool isSelected = selected == options[i];
        return Expanded(
          child: GestureDetector(
            onTap: () => onSelected(options[i]),
            child: Container(
              margin: EdgeInsets.only(right: i < options.length - 1 ? 8 : 0),
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: isSelected
                    ? palette['primary']!.withOpacity(0.15)
                    : (isDark ? const Color(0xFF2A2A4A) : const Color(0xFFF5F5F5)),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected ? palette['primary']! : Colors.transparent,
                  width: 1.5,
                ),
              ),
              child: Center(
                child: Text(
                  labels[i],
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    color: isSelected ? palette['primary'] : palette['onSurfaceDim'],
                  ),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}