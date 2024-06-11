import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart';

import '../l10n/app_localizations.dart';
import '../widgets/MainUI.dart';

class EnterSceneState extends State<EnterScene> {
  Locale _locale = const Locale('en');

  late Size screenSize;
  late MainUI ui;

  @override
  void initState() {
    super.initState();
  }

  void _updateUI() {
    setState(() {});
  }

  //AppLocalizations.of(context)!.translate('helloWorld')
  ///language Code is "en", "ko"
  void changeLanguage(BuildContext context, String languageCode) {
    setState(() {
      _locale = Locale(languageCode);
    });
    Intl.defaultLocale = languageCode;
    _updateUI();
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
        home: Builder(
            builder: (context) {
              screenSize = MediaQuery.of(context).size;
              ui = MainUI(onUpdate: _updateUI, appLocalizations: AppLocalizations.of(context)!, enterSceneState: this,);
              ui.loadSetting();
              ui.setScreenSize(screenSize);

              return Scaffold(
                  backgroundColor: Colors.blueGrey,
                  body: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          ui.getMainMenu(context)
                        ],
                      ),
                      SizedBox(
                        height: ui.getTopMargin(),
                      ),
                      //title, start button, puzzle type
                      Flexible(
                        flex: 1,
                        child: Center(
                          child: Column(
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
                              ui.getPuzzleType(context),
                            ],
                          ),
                        ),
                      ),
                      //continue puzzle
                      Flexible(
                        flex: 1,
                        child: Center(
                          child: ui.getContinueWidget(context),
                        ),
                      ),
                    ],
                  )
              );
            }
        )
    );
  }
}

class EnterScene extends StatefulWidget {
  const EnterScene({Key? key}) : super(key: key);

  @override
  EnterSceneState createState() => EnterSceneState();
}