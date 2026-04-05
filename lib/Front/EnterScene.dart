// ignore_for_file: file_names
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../ThemeColor.dart';
import '../User/UserInfo.dart';
import '../l10n/app_localizations.dart';
import '../provider/MainScreenProvider.dart';
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
  late MainScreenProvider _provider;
  bool _providerReady = false;

  void debugSetting() {
    useKeyInput = UserInfo.isDebug;
  }

  @override
  void initState() {
    super.initState();
    debugSetting();
    _focusNode = FocusNode();
    _provider = MainScreenProvider();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });

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

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if(UserInfo.updateContinueWidget) {
        UserInfo.updateContinueWidget = false;
        if (_providerReady) _provider.refresh();
      }
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _timer?.cancel();
    super.dispose();
  }

  /// Only called for language/theme changes that need MaterialApp rebuild
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

  /// Light refresh via Provider (no MaterialApp rebuild)
  void refreshContent() {
    if (_providerReady) _provider.refresh();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _provider,
      child: MaterialApp(
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
          theme: ThemeData(useMaterial3: true),
          home: RawKeyboardListener(
            focusNode: _focusNode,
            onKey: (RawKeyEvent event) {
              if(!useKeyInput) return;
              if (event is RawKeyDownEvent) {
                if (event.logicalKey == LogicalKeyboardKey.keyR) {
                  refreshContent();
                }
                else if (event.logicalKey == LogicalKeyboardKey.keyW) {
                  changeLanguage(_locale.languageCode == "en" ? "ko" : "en");
                }
              }
            },
            child: Builder(
              builder: (context) {
                final localizations = AppLocalizations.of(context);
                if (localizations == null) {
                  return const Scaffold(
                    backgroundColor: Color(0xFF0A0A1A),
                    body: Center(child: CircularProgressIndicator(color: Color(0xFF6C63FF))),
                  );
                }

                if(uiNullable == null) {
                  uiNullable = MainUI(
                    onUpdate: refreshContent,
                    appLocalizations: localizations,
                    enterSceneState: this,
                    context: context,
                  );
                  ui = uiNullable!;
                  ui.loadSetting();
                  _providerReady = true;
                }

                screenSize = MediaQuery.of(context).size;
                ui.setScreenSize(screenSize);
                ui.setAppLocalizations(localizations);

                return _MainScreenContent(
                  ui: ui,
                  loc: localizations,
                  provider: _provider,
                );
              },
            ),
          )
      ),
    );
  }

  AppLocalizations get appLocalizations => ui.appLocalizations;
}

/// Stateless content widget that rebuilds only via Consumer<MainScreenProvider>
class _MainScreenContent extends StatelessWidget {
  final MainUI ui;
  final AppLocalizations loc;
  final MainScreenProvider provider;

  const _MainScreenContent({
    required this.ui,
    required this.loc,
    required this.provider,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<MainScreenProvider>(
      builder: (context, prov, _) {
        final palette = ThemeColor().getPalette();
        final isDark = ThemeColor().isDark();

        return Scaffold(
          body: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  palette['gradientStart']!,
                  palette['gradientEnd']!,
                  palette['gradientStart']!,
                ],
                stops: const [0.0, 0.5, 1.0],
              ),
            ),
            child: SafeArea(
              child: Column(
                children: [
                  // Top bar
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        _topBarButton(Icons.help_outline_rounded, palette, () => ui.handleMainMenu(context, "how")),
                        _topBarButton(Icons.person_outline_rounded, palette, () => ui.handleMainMenu(context, "account")),
                        _topBarButton(Icons.settings_outlined, palette, () => ui.handleMainMenu(context, "setting")),
                      ],
                    ),
                  ),

                  // Content
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        children: [
                          const SizedBox(height: 24),

                          // App icon
                          ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: Image.asset(
                              'assets/images/app_icon.png',
                              width: 80,
                              height: 80,
                              errorBuilder: (_, __, ___) => Icon(
                                Icons.grid_4x4_rounded, size: 64, color: palette['primary'],
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            "SLITHERLINK",
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 4,
                              color: palette['onSurface'],
                            ),
                          ),

                          const SizedBox(height: 32),

                          // ===== New Game Card =====
                          _card(palette, isDark, Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Continue & New Game buttons
                              IntrinsicHeight(
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    if (UserInfo.getContinuePuzzle().isNotEmpty) ...[
                                      Expanded(
                                        child: OutlinedButton.icon(
                                          icon: Icon(Icons.history_rounded, size: 22, color: palette['primary']),
                                          label: Padding(
                                            padding: const EdgeInsets.symmetric(vertical: 14),
                                            child: Text(
                                              loc.translate('MainUI_btnContinue'),
                                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: palette['primary']),
                                            ),
                                          ),
                                          style: OutlinedButton.styleFrom(
                                            side: BorderSide(color: palette['primary']!, width: 1.5),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                          ),
                                          onPressed: () => ui.showContinueSheet(context, palette, isDark, loc),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                    ],
                                    Expanded(
                                      child: ElevatedButton.icon(
                                        icon: const Icon(Icons.play_arrow_rounded, size: 22),
                                        label: Padding(
                                          padding: const EdgeInsets.symmetric(vertical: 14),
                                          child: Text(
                                            loc.translate('MainUI_btnStart'),
                                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                                          ),
                                        ),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: palette['buttonBg'],
                                          foregroundColor: palette['buttonText'],
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                          elevation: 0,
                                        ),
                                        onPressed: () => ui.startGame(context),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 20),

                              // Difficulty selector
                              _miniLabel(loc.translate('MainUI_difficulty'), palette),
                              const SizedBox(height: 8),
                              _difficultySelector(palette, isDark, prov),
                              const SizedBox(height: 16),

                              _miniLabel("${prov.generateRows} x ${prov.generateCols}", palette, isBold: true),
                              const SizedBox(height: 4),
                              _sizeSliders(palette, prov),
                              const SizedBox(height: 8),

                            ],
                          )),

                          // ===== Progress Card =====
                          if (UserInfo.getTotalCompleted() > 0) ...[
                            const SizedBox(height: 16),
                            _card(palette, isDark, Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _sectionHeader(Icons.emoji_events_rounded, loc.translate('progress_title'), palette),
                                const SizedBox(height: 12),
                                ...UserInfo.completed.entries.map((entry) => Padding(
                                  padding: const EdgeInsets.only(bottom: 6),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        entry.key,
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: palette['onSurfaceDim'],
                                        ),
                                      ),
                                      Text(
                                        '${entry.value}',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          color: palette['primary'],
                                        ),
                                      ),
                                    ],
                                  ),
                                )),
                              ],
                            )),
                          ],

                          const SizedBox(height: 32),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // --- Helper widgets ---

  Widget _topBarButton(IconData icon, Map<String, Color> palette, VoidCallback onTap) {
    return IconButton(
      icon: Icon(icon, color: palette['onSurfaceDim'], size: 24),
      onPressed: onTap,
      splashRadius: 22,
    );
  }

  Widget _sectionHeader(IconData icon, String title, Map<String, Color> palette) {
    return Row(
      children: [
        Icon(icon, color: palette['primary'], size: 22),
        const SizedBox(width: 8),
        Text(title, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: palette['onSurface'])),
      ],
    );
  }

  Widget _miniLabel(String text, Map<String, Color> palette, {bool isBold = false}) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 13,
        fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
        color: palette['onSurfaceDim'],
        letterSpacing: 0.3,
      ),
    );
  }

  Widget _card(Map<String, Color> palette, bool isDark, Widget child) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? palette['cardBg']!.withOpacity(0.75) : palette['cardBg']!.withOpacity(0.95),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette['divider']!.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.25 : 0.06),
            blurRadius: 16,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: child,
    );
  }

  // Mode selector: Preset vs Generate
  Widget _modeSelector(Map<String, Color> palette, bool isDark, AppLocalizations loc, MainScreenProvider prov) {
    return Row(
      children: [
        _modeButton(
          label: loc.translate('MainUI_puzzleSize_small'),
          icon: Icons.list_alt_rounded,
          isSelected: prov.selectedSize == "small",
          palette: palette,
          isDark: isDark,
          onTap: () => prov.setSize("small"),
        ),
        const SizedBox(width: 10),
        _modeButton(
          label: loc.translate('MainUI_puzzleSize_generate'),
          icon: Icons.auto_awesome_rounded,
          isSelected: prov.selectedSize == "generate",
          palette: palette,
          isDark: isDark,
          onTap: () => prov.setSize("generate"),
        ),
      ],
    );
  }

  Widget _modeButton({
    required String label,
    required IconData icon,
    required bool isSelected,
    required Map<String, Color> palette,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: isSelected
                ? palette['primary']!.withOpacity(0.15)
                : (isDark ? const Color(0xFF2A2A4A) : const Color(0xFFF0F0F5)),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? palette['primary']! : Colors.transparent,
              width: 2,
            ),
          ),
          child: Column(
            children: [
              Icon(icon, color: isSelected ? palette['primary'] : palette['onSurfaceDim'], size: 22),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                  color: isSelected ? palette['primary'] : palette['onSurfaceDim'],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Difficulty selector
  Widget _difficultySelector(Map<String, Color> palette, bool isDark, MainScreenProvider prov) {
    final items = [
      {"key": "easy", "icon": Icons.sentiment_satisfied_alt_rounded, "color": const Color(0xFF4CAF50)},
      {"key": "normal", "icon": Icons.trending_flat_rounded, "color": const Color(0xFFFFA726)},
      {"key": "hard", "icon": Icons.local_fire_department_rounded, "color": const Color(0xFFEF5350)},
    ];

    return Row(
      children: items.map((item) {
        String key = item["key"] as String;
        bool isSelected = prov.selectedDifficulty == key;
        Color color = item["color"] as Color;

        return Expanded(
          child: GestureDetector(
            onTap: () => prov.setDifficulty(key),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: EdgeInsets.only(right: key != "hard" ? 8 : 0),
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: isSelected ? color.withOpacity(0.15) : (isDark ? const Color(0xFF2A2A4A) : const Color(0xFFF0F0F5)),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isSelected ? color : Colors.transparent,
                  width: 2,
                ),
              ),
              child: Column(
                children: [
                  Icon(item["icon"] as IconData, color: isSelected ? color : palette['onSurfaceDim'], size: 20),
                  const SizedBox(height: 2),
                  Text(
                    key.toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                      color: isSelected ? color : palette['onSurfaceDim'],
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // Size sliders
  Widget _sizeSliders(Map<String, Color> palette, MainScreenProvider prov) {
    return Column(
      children: [
        _slider("R", prov.generateRows, palette, (v) => prov.setRows(v.round())),
        _slider("C", prov.generateCols, palette, (v) => prov.setCols(v.round())),
      ],
    );
  }

  Widget _slider(String label, int value, Map<String, Color> palette, ValueChanged<double> onChanged) {
    return Row(
      children: [
        SizedBox(
          width: 20,
          child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: palette['onSurfaceDim'])),
        ),
        Expanded(
          child: SliderTheme(
            data: SliderThemeData(
              activeTrackColor: palette['primary'],
              inactiveTrackColor: palette['divider'],
              thumbColor: palette['primary'],
              overlayColor: palette['primary']!.withOpacity(0.08),
              trackHeight: 3,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
            ),
            child: Slider(
              value: value.toDouble(),
              min: 3,
              max: 20,
              divisions: 17,
              onChanged: onChanged,
            ),
          ),
        ),
        SizedBox(
          width: 24,
          child: Text("$value", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: palette['onSurface'])),
        ),
      ],
    );
  }
}

class EnterScene extends StatefulWidget {
  const EnterScene({Key? key}) : super(key: key);

  @override
  EnterSceneState createState() => EnterSceneState();
}
