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

  Map<String, Color> defaultColor = {
    'appBar': const Color(0xFF00C8FF),        //GameUI
    'appIcon': const Color(0xFF000000),       //GameUI
    'background': const Color(0xFFFFF0E3),    //GameSceneStateSquare
    'box': const Color(0xFFFFFFFF),           //SquareBoxState
    'boxHighLight': const Color(0xFFFFCCBC),
    'number': const Color(0xFF000000),        //SquareBoxState
  };

  Map<String, Color> warm = {
    'appBar': const Color(0xFFFF5722),
    'appIcon': const Color(0xFFFFFFFF),
    'background': const Color(0xFFFFEBE5),
    'box': const Color(0xFFFFCCBC),
    'boxHighLight': const Color(0xFFFFCCBC),
    'number': const Color(0xFFBF360C),
  };

  Map<String, Color> cool = {
    'appBar': const Color(0xFF2196F3),
    'appIcon': const Color(0xFFFFFFFF),
    'background': const Color(0xFFE3F2FD),
    'box': const Color(0xFFBBDEFB),
    'boxHighLight': const Color(0xFFFFCCBC),
    'number': const Color(0xFF0D47A1),
  };

  Map<String, Color> earth = {
    'appBar': const Color(0xFF795548),
    'appIcon': const Color(0xFFFFFFFF),
    'background': const Color(0xFFD7CCC8),
    'box': const Color(0xFFBCAAA4),
    'boxHighLight': const Color(0xFFFFCCBC),
    'number': const Color(0xFF3E2723),
  };

  Map<String, Color> pastel = {
    'appBar': const Color(0xFFB39DDB),
    'appIcon': const Color(0xFFFFFFFF),
    'background': const Color(0xFFEDE7F6),
    'box': const Color(0xFFD1C4E9),
    'boxHighLight': const Color(0xFFFFCCBC),
    'number': const Color(0xFF512DA8),
  };

  Map<String, Color> vibrant = {
    'appBar': const Color(0xFFFF4081),
    'appIcon': const Color(0xFFFFFFFF),
    'background': const Color(0xFFF8BBD0),
    'box': const Color(0xFFF48FB1),
    'boxHighLight': const Color(0xFF81D4FA),
    'number': const Color(0xFFC2185B),
  };

  Map<String, Color> nature = {
    'appBar': const Color(0xFF4CAF50),
    'appIcon': const Color(0xFFFFFFFF),
    'background': const Color(0xFFE8F5E9),
    'box': const Color(0xFFC8E6C9),
    'boxHighLight': const Color(0xFFFFCCBC),
    'number': const Color(0xFF1B5E20),
  };

  Map<String, Color> sunset = {
    'appBar': const Color(0xFFFF7043),
    'appIcon': const Color(0xFFFFFFFF),
    'background': const Color(0xFFFFE0B2),
    'box': const Color(0xFFFFCC80),
    'boxHighLight': const Color(0xFF81D4FA),
    'number': const Color(0xFFE65100),
  };

  Map<String, Color> ocean = {
    'appBar': const Color(0xFF0288D1),
    'appIcon': const Color(0xFFFFFFFF),
    'background': const Color(0xFFE1F5FE),
    'box': const Color(0xFF81D4FA),
    'boxHighLight': const Color(0xFFFFCCBC),
    'number': const Color(0xFF01579B),
  };

  Map<String, Color> forest = {
    'appBar': const Color(0xFF388E3C),
    'appIcon': const Color(0xFFFFFFFF),
    'background': const Color(0xFFE8F5E9),
    'box': const Color(0xFFA5D6A7),
    'boxHighLight': const Color(0xFF81D4FA),
    'number': const Color(0xFF2E7D32),
  };

  Map<String, Color> lavender = {
    'appBar': const Color(0xFFFF4081),
    'appIcon': const Color(0xFFFFFFFF),
    'background': const Color(0xFFF8BBD0),
    'box': const Color(0xFFF48FB1),
    'boxHighLight': const Color(0xFF81D4FA),
    'number': const Color(0xFFC2185B),
  };

  ThemeColor();

  List<String> getList() {
    return ["default", "warm", "cool", "earth", "pastel", "vibrant"];
  }

  List<String> getColorListTr(BuildContext context) {
    return [
      AppLocalizations.of(context)!.translate('ThemeName_01'),
      AppLocalizations.of(context)!.translate('ThemeName_02'),
      AppLocalizations.of(context)!.translate('ThemeName_03'),
      AppLocalizations.of(context)!.translate('ThemeName_04'),
      AppLocalizations.of(context)!.translate('ThemeName_05'),
      AppLocalizations.of(context)!.translate('ThemeName_06'),
    ];
  }

  Map<String, Color> getColor() {
    String type = UserInfo.getSetting("theme")!;
    switch (type) {
      case "default":
        return defaultColor;
      case "warm":
        return warm;
      case "cool":
        return cool;
      case "earth":
        return earth;
      case "pastel":
        return pastel;
      case "vibrant":
        return vibrant;
    }
    return {};
  }

  ///0 : normal, 1 : select, 2 : hint, -1 : disable, -2 : wrong
  Color getLineColor({int type = 1}) {
    //user selection
    if(type == 1) {
      //line_01 ~ line_15
      int num = Random().nextInt(getNormalLineNum()) + 1;
      if(num < 10) {
        //print("lineColor : ${lineColor["line_0$num"]!}");
        return lineColor["line_0$num"]!;
      }
      else {
        //print("lineColor : ${lineColor["line_$num"]!}");
        return lineColor["line_$num"]!;
      }
    }

    Color rtColor = const Color(0xFF000000);
    switch(type) {
      //normal(no select)
      case 0:
        //print("lineColor[line_normal] : ${lineColor["line_normal"]}");
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

    //print("rtColor in getLineColor : $rtColor");
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
    //print("getNormalLineNum : ${getNormalLineNum()}");  //15
    return Random().nextInt(getNormalLineNum()) + 1;
  }
}