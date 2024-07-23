// ignore_for_file: file_names
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart';

import '../User/UserInfo.dart';
import '../l10n/app_localizations.dart';
import '../widgets/MainUI.dart';

class EnterSceneState extends State<EnterScene> {
  late Locale _locale;
  late FocusNode _focusNode;

  late Size screenSize;
  MainUI? uiNullable;
  late MainUI ui;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
    setState(() {
      switch(UserInfo.getLanguage()) {
        case "english":
          _locale = const Locale('en');
          Intl.defaultLocale = "en";
          break;
        case "korean":
          _locale = const Locale('ko');
          Intl.defaultLocale = "ko";
          break;
      }
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void updateUI() {
    setState(() {});
  }

  //AppLocalizations.of(context)!.translate('helloWorld')
  ///language Code is "en", "ko"
  void changeLanguage(String languageCode) {
    setState(() {
      _locale = Locale(languageCode);
      Intl.defaultLocale = languageCode;

      switch(languageCode) {
        case "en":
          UserInfo.setLanguage("english");
          break;
        case "ko":
          UserInfo.setLanguage("korean");
          break;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(  // Replace YourWidget with your actual widget
        locale: _locale,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          ...GlobalMaterialLocalizations.delegates, // 전체 로케일 추가
          GlobalCupertinoLocalizations.delegate, // Cupertino 로케일 추가
        ],
        supportedLocales: const [
          Locale('en'),
          Locale('ko'),
        ],
        home: RawKeyboardListener(
          focusNode: _focusNode,
          onKey: (RawKeyEvent event) {
            if (event is RawKeyDownEvent) {
              if (event.logicalKey == LogicalKeyboardKey.keyR) {
                updateUI();
              }
              else if (event.logicalKey == LogicalKeyboardKey.keyW) {
                changeLanguage(_locale.languageCode == "en" ? "ko" : "en");
              }
            }
          },
          child: FutureBuilder<void>(
              future: () async {
                //first execution
                if(uiNullable == null) {
                  return;
                }
              }(),
              builder: (context, snapshot) {
                if(uiNullable == null && AppLocalizations.of(context) != null) {
                  uiNullable = MainUI(onUpdate: updateUI, appLocalizations: AppLocalizations.of(context)!, enterSceneState: this);
                  ui = uiNullable!;
                  ui.loadSetting();
                }

                if(snapshot.connectionState == ConnectionState.done) {
                  screenSize = MediaQuery.of(context).size;

                  ui.setScreenSize(screenSize);
                  ui.setAppLocalizations(AppLocalizations.of(context)!);

                  if(screenSize.width < screenSize.height) {
                    return portrait(context);
                  } else {
                    if (screenSize.height > 600) {
                      return landscape(context);
                    } else {
                      return landscapeSmall(context);
                    }
                  }
                }
                else if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                else {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
              }
          ),
        )
    );
  }

  Scaffold portrait(BuildContext context) {
    return Scaffold(
        backgroundColor: Colors.blueGrey,
        body: Column(
          children: [
            Flexible(
              flex: 1,
              child: Center(
                child: Column(
                  children: [
                    const SizedBox(
                      height: 25,
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        ui.getMainMenu(context)
                      ],
                    ),
                  ],
                ),
              ),
            ),
            //title, start button, puzzle type
            Flexible(
              flex: 3,
              child: Center(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Padding(
                      padding: EdgeInsetsDirectional.symmetric(vertical: ui.getMargin(0.005)),
                      child: const Text("Slitherlink",
                        style: TextStyle(
                          fontSize: 45, fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsetsDirectional.symmetric(vertical: ui.getMargin(0.1)),
                      child: ui.getStartButton(context),
                    ),
                    Center(
                      child: ui.getPuzzleType(context, updateUI),
                    ),
                  ],
                ),
              ),
            ),
            //continue puzzle
            Flexible(
              flex: 2,
              child: Center(
                child: ui.getContinueWidget(context),
              ),
            ),
          ],
        ),
    );
  }

  Scaffold landscape(BuildContext context) {
    return Scaffold(
        backgroundColor: Colors.blueGrey,
        body: Column(
          children: [
            Flexible(
              flex: 1,
              child: Center(
                child: Column(
                  children: [
                    const SizedBox(
                      height: 15,
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        ui.getMainMenu(context)
                      ],
                    ),
                  ],
                ),
              ),
            ),
            //title, start button, puzzle type
            Flexible(
              flex: 2,
              child: Center(
                child: Column(
                  children: [
                    Padding(
                      padding: EdgeInsetsDirectional.symmetric(vertical: ui.getMargin(0.0005)),
                      child: const Text("Slitherlink",
                        style: TextStyle(
                          fontSize: 45, fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsetsDirectional.symmetric(vertical: ui.getMargin(0.05)),
                      child: ui.getStartButton(context),
                    ),
                    ui.getPuzzleType(context, updateUI),
                  ],
                ),
              ),
            ),
            //continue puzzle
            Flexible(
              flex: 2,
              child: Center(
                child: ui.getContinueWidget(context),
              ),
            ),
          ],
        )
    );
  }

  Scaffold landscapeSmall(BuildContext context) {
    return Scaffold(
        backgroundColor: Colors.blueGrey,
        body: Column(
          children: [
            Flexible(
              flex: 1,
              child: Center(
                child: Column(
                  children: [
                    const SizedBox(
                      height: 15,
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        ui.getMainMenu(context)
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Flexible(
              flex: 3,
              child: Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    //title, start button, puzzle type
                    Column(
                      children: [
                        Padding(
                          padding: EdgeInsetsDirectional.symmetric(vertical: ui.getMargin(0.0005)),
                          child: const Text("Slitherlink",
                            style: TextStyle(
                              fontSize: 45, fontWeight: FontWeight.w400,
                            ),
                          ),
                        ),
                        Padding(
                          padding: EdgeInsetsDirectional.symmetric(vertical: ui.getMargin(0.05)),
                          child: ui.getStartButton(context),
                        ),
                        ui.getPuzzleType(context, updateUI),
                      ],
                    ),
                    //continue puzzle
                    Center(
                      child: ui.getContinueWidget(context),
                    ),
                  ],
                )
              ),
            ),
          ],
        )
    );
  }
}

class EnterScene extends StatefulWidget {
  const EnterScene({Key? key}) : super(key: key);

  @override
  EnterSceneState createState() => EnterSceneState();
}