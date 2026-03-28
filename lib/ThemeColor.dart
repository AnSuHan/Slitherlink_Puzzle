// ignore_for_file: file_names
import 'dart:math';

import 'package:flutter/material.dart';

import 'User/UserInfo.dart';
import 'l10n/app_localizations.dart';

class ThemeColor {
  Map<String, Color> lineColor = {
    'line_wrong': const Color(0xFFFF0000),    // Red
    'line_hint': const Color(0xFFFFD700),     // Gold
    'line_disable': const Color(0x33C0C0C0),  // Gray
    'line_normal': const Color(0xFFC0C0C0),  // Silver
    'line_x': const Color(0x00000000),

    'line_01': const Color(0xFF40E0D0),  // Turquoise
    'line_02': const Color(0xFF00FF00),  // Green
    'line_03': const Color(0xFF0000FF),  // Blue
    'line_04': const Color(0xFF00FFFF),  // Cyan
    'line_05': const Color(0xFFFF00FF),  // Magenta
    'line_06': const Color(0xFFFFFF00),  // Yellow
    'line_07': const Color(0xFFFFA500),  // Orange
    'line_08': const Color(0xFF800080),  // Purple
    'line_09': const Color(0xFF008080),  // Teal
    'line_10': const Color(0xFFABABFF),  // Lavender
    'line_11': const Color(0xFFA52A2A),  // Brown
    'line_12': const Color(0xFF800000),  // Maroon
    'line_13': const Color(0xFF000080),  // Navy
    'line_14': const Color(0xFF808000),  // Olive
    'line_15': const Color(0xFFFF7F50),  // Coral
  };

  // === Theme 1: Midnight (Dark elegant theme) ===
  Map<String, Color> midnight = {
    'appBar': const Color(0xFF1A1A2E),
    'appIcon': const Color(0xFFE0E0FF),
    'background': const Color(0xFF16213E),
    'box': const Color(0xFF1A1A2E),
    'boxHighLight': const Color(0xFF0F3460),
    'number': const Color(0xFFE0E0FF),
    // Extended palette for UI
    'primary': const Color(0xFF6C63FF),
    'primaryLight': const Color(0xFF8B83FF),
    'secondary': const Color(0xFF0F3460),
    'surface': const Color(0xFF1A1A2E),
    'surfaceLight': const Color(0xFF222244),
    'onSurface': const Color(0xFFE0E0FF),
    'onSurfaceDim': const Color(0xFF9090B0),
    'accent': const Color(0xFF6C63FF),
    'gradientStart': const Color(0xFF0A0A1A),
    'gradientEnd': const Color(0xFF1A1A2E),
    'cardBg': const Color(0xFF222244),
    'buttonBg': const Color(0xFF6C63FF),
    'buttonText': const Color(0xFFFFFFFF),
    'divider': const Color(0xFF333366),
  };

  // === Theme 2: Ocean (Cool blue theme) ===
  Map<String, Color> ocean = {
    'appBar': const Color(0xFF0277BD),
    'appIcon': const Color(0xFFFFFFFF),
    'background': const Color(0xFFE8F4FD),
    'box': const Color(0xFFFFFFFF),
    'boxHighLight': const Color(0xFFB3E5FC),
    'number': const Color(0xFF01579B),
    // Extended palette for UI
    'primary': const Color(0xFF0288D1),
    'primaryLight': const Color(0xFF03A9F4),
    'secondary': const Color(0xFF4FC3F7),
    'surface': const Color(0xFFFFFFFF),
    'surfaceLight': const Color(0xFFF5FAFF),
    'onSurface': const Color(0xFF1A1A2E),
    'onSurfaceDim': const Color(0xFF607D8B),
    'accent': const Color(0xFF00BCD4),
    'gradientStart': const Color(0xFF0277BD),
    'gradientEnd': const Color(0xFF4FC3F7),
    'cardBg': const Color(0xFFFFFFFF),
    'buttonBg': const Color(0xFF0288D1),
    'buttonText': const Color(0xFFFFFFFF),
    'divider': const Color(0xFFB0BEC5),
  };

  // === Theme 3: Sakura (Warm pink theme) ===
  Map<String, Color> sakura = {
    'appBar': const Color(0xFFAD1457),
    'appIcon': const Color(0xFFFFFFFF),
    'background': const Color(0xFFFFF0F5),
    'box': const Color(0xFFFFFFFF),
    'boxHighLight': const Color(0xFFF8BBD0),
    'number': const Color(0xFF880E4F),
    // Extended palette for UI
    'primary': const Color(0xFFE91E63),
    'primaryLight': const Color(0xFFF06292),
    'secondary': const Color(0xFFF48FB1),
    'surface': const Color(0xFFFFFFFF),
    'surfaceLight': const Color(0xFFFFF5F8),
    'onSurface': const Color(0xFF2C1320),
    'onSurfaceDim': const Color(0xFF8E6B7D),
    'accent': const Color(0xFFFF4081),
    'gradientStart': const Color(0xFFAD1457),
    'gradientEnd': const Color(0xFFF06292),
    'cardBg': const Color(0xFFFFFFFF),
    'buttonBg': const Color(0xFFE91E63),
    'buttonText': const Color(0xFFFFFFFF),
    'divider': const Color(0xFFF8BBD0),
  };

  ThemeColor();

  List<String> getList() {
    return ["midnight", "ocean", "sakura"];
  }

  List<String> getColorListTr(BuildContext context) {
    return [
      AppLocalizations.of(context)!.translate('ThemeName_01'),
      AppLocalizations.of(context)!.translate('ThemeName_02'),
      AppLocalizations.of(context)!.translate('ThemeName_03'),
    ];
  }

  Map<String, Color> getColor() {
    String type = UserInfo.getSetting("theme")!;
    switch (type) {
      case "midnight":
      case "default":
        return midnight;
      case "ocean":
        return ocean;
      case "sakura":
        return sakura;
    }
    return midnight;
  }

  /// Get the full theme palette (includes extended colors)
  Map<String, Color> getPalette() {
    return getColor();
  }

  bool isDark() {
    String type = UserInfo.getSetting("theme")!;
    return type == "midnight" || type == "default";
  }

  ///0 : normal, 1 : select, 2 : hint, -1 : disable, -2 : wrong
  Color getLineColor({int type = 1}) {
    //user selection
    if(type == 1) {
      //line_01 ~ line_15
      int num = Random().nextInt(getNormalLineNum()) + 1;
      if(num < 10) {
        return lineColor["line_0$num"]!;
      }
      else {
        return lineColor["line_$num"]!;
      }
    }

    Color rtColor = const Color(0xFF000000);
    switch(type) {
      //normal(no select)
      case 0:
        rtColor = lineColor["line_normal"]!;
        break;
      //disable
      case -1:
        rtColor = lineColor["line_disable"]!;
        break;
      //wrong
      case -2:
        rtColor = lineColor["line_wrong"]!;
        break;
      //hint
      case -3:
        rtColor = lineColor["line_hint"]!;
        break;
      //x
      case -4:
        rtColor = lineColor["line_x"]!;
        break;
    }

    return rtColor;
  }

  Color getColorWithName(String name) {
    if(lineColor.containsKey(name)) {
      return lineColor[name]!;
    }
    return const Color(0x00000000);
  }

  int getColorNum(Color color) {
    Map<Color, String> reverse = {};
    lineColor.forEach((key, value) {
      reverse[value] = key;
    });
    String rt = reverse[color]!;
    int value = int.parse(rt.split("_")[1]);

    return value;
  }

  int getNormalLineNum() {
    return lineColor.length - 5;
  }

  //return over 0
  int getNormalRandom() {
    return Random().nextInt(getNormalLineNum()) + 1;
  }
}
