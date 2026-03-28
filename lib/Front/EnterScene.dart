// ignore_for_file: file_names
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart';

import '../ThemeColor.dart';
import '../User/UserInfo.dart';
import '../l10n/app_localizations.dart';
import '../widgets/MainUI.dart';

class EnterSceneState extends State<EnterScene> {
  ///ONLY-DEBUG variables
  late FocusNode _focusNode;
  bool useKeyInput = false;
  ///ONLY-DEBUG variables

  late Locale _locale;

  late Size screenSize;
  MainUI? uiNullable;
  late MainUI ui;
  Timer? _timer;

  void debugSetting() {
    if(UserInfo.isDebug) {
      useKeyInput = true;
    }
    else {
      useKeyInput = false;
    }
  }

  @override
  void initState() {
    super.initState();
    debugSetting();
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

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if(UserInfo.updateContinueWidget) {
        UserInfo.updateContinueWidget = false;
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _timer?.cancel();
    super.dispose();
  }

  void updateUI() {
    setState(() {});
  }

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
      ui.updateUI();
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        locale: _locale,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          ...GlobalMaterialLocalizations.delegates,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [
          Locale('en'),
          Locale('ko'),
        ],
        theme: ThemeData(
          useMaterial3: true,
          fontFamily: 'Roboto',
        ),
        home: RawKeyboardListener(
          focusNode: _focusNode,
          onKey: (RawKeyEvent event) {
            if(!useKeyInput) {
              return;
            }
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
                if(uiNullable == null) {
                  return;
                }
              }(),
              builder: (context, snapshot) {
                if(snapshot.connectionState == ConnectionState.done) {
                  if(uiNullable == null && AppLocalizations.of(context) != null) {
                    uiNullable = MainUI(onUpdate: updateUI, appLocalizations: AppLocalizations.of(context)!, enterSceneState: this, context: context);
                    ui = uiNullable!;
                    ui.loadSetting();
                  }

                  screenSize = MediaQuery.of(context).size;

                  ui.setScreenSize(screenSize);
                  ui.setAppLocalizations(AppLocalizations.of(context)!);

                  return _buildMainScreen(context);
                }
                else if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Scaffold(
                    backgroundColor: Color(0xFF0A0A1A),
                    body: Center(child: CircularProgressIndicator(color: Color(0xFF6C63FF))),
                  );
                }
                else {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
              }
          ),
        )
    );
  }

  Widget _buildMainScreen(BuildContext context) {
    final palette = ThemeColor().getPalette();
    final isDark = ThemeColor().isDark();

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              palette['gradientStart']!,
              palette['gradientEnd']!,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Top bar with settings
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(
                      icon: Icon(Icons.settings_rounded, color: palette['onSurfaceDim'], size: 28),
                      onPressed: () => ui.handleMainMenu(context, "setting"),
                    ),
                    IconButton(
                      icon: Icon(Icons.person_rounded, color: palette['onSurfaceDim'], size: 28),
                      onPressed: () => ui.handleMainMenu(context, "account"),
                    ),
                    IconButton(
                      icon: Icon(Icons.help_outline_rounded, color: palette['onSurfaceDim'], size: 28),
                      onPressed: () => ui.handleMainMenu(context, "how"),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      const SizedBox(height: 20),

                      // Logo / Title
                      Icon(
                        Icons.grid_4x4_rounded,
                        size: 64,
                        color: palette['primary'],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        "SLITHERLINK",
                        style: TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 6,
                          color: palette['onSurface'],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "PUZZLE",
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w300,
                          letterSpacing: 8,
                          color: palette['onSurfaceDim'],
                        ),
                      ),

                      const SizedBox(height: 40),

                      // New Game Card
                      _buildCard(
                        palette: palette,
                        isDark: isDark,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.play_circle_filled_rounded, color: palette['primary'], size: 24),
                                const SizedBox(width: 8),
                                Text(
                                  appLocalizations.translate('MainUI_btnStart'),
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    color: palette['onSurface'],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),

                            // Puzzle config chips
                            ui.getPuzzleTypeChips(context, updateUI, palette),

                            if (MainUI.selectedType[1] == "generate") ...[
                              const SizedBox(height: 12),
                              ui.getDifficultyChips(context, updateUI, palette),
                              const SizedBox(height: 12),
                              ui.getGenerateSizeSliders(context, updateUI, palette),
                            ],

                            const SizedBox(height: 20),

                            // Start button
                            SizedBox(
                              width: double.infinity,
                              height: 52,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: palette['buttonBg'],
                                  foregroundColor: palette['buttonText'],
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  elevation: 0,
                                ),
                                onPressed: () => ui.startGame(context),
                                child: Text(
                                  appLocalizations.translate('MainUI_btnStart'),
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: 1),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Continue Game Card
                      if (UserInfo.getContinuePuzzle().isNotEmpty)
                        _buildCard(
                          palette: palette,
                          isDark: isDark,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.refresh_rounded, color: palette['accent'], size: 24),
                                  const SizedBox(width: 8),
                                  Text(
                                    appLocalizations.translate('MainUI_btnContinue_title'),
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                      color: palette['onSurface'],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              ui.getContinueList(context, palette),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                height: 48,
                                child: OutlinedButton(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: palette['primary'],
                                    side: BorderSide(color: palette['primary']!, width: 1.5),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                  onPressed: () => ui.continueGame(context),
                                  child: Text(
                                    appLocalizations.translate('MainUI_btnContinue'),
                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCard({
    required Map<String, Color> palette,
    required bool isDark,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: palette['cardBg']!.withOpacity(isDark ? 0.7 : 0.95),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: palette['divider']!.withOpacity(0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.08),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }

  late AppLocalizations appLocalizations = AppLocalizations.of(context) ?? AppLocalizations(const Locale('en'));
}

class EnterScene extends StatefulWidget {
  const EnterScene({Key? key}) : super(key: key);

  @override
  EnterSceneState createState() => EnterSceneState();
}
