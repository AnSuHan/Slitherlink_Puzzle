import 'dart:math';
import 'dart:ui';

import 'User/UserInfo.dart';

class ThemeColor {
  Map<String, Color> lineColor = {
    'line_wrong': const Color(0xFFFF0000),    // Red
    'line_hint': const Color(0xFFFFD700),     // Gold
    'line_disable': const Color(0x33C0C0C0),  // Gray
    'line_normal': const Color(0xFFC0C0C0),  // Silver

    'line_01': const Color(0xFF40E0D0),  // Turquoise
    'line_02': const Color(0xFF00FF00),  // Green
    'line_03': const Color(0xFF0000FF),  // Blue
    'line_04': const Color(0xFF00FFFF),  // Cyan
    'line_05': const Color(0xFFFF00FF),  // Magenta
    'line_06': const Color(0xFFFFFF00),  // Yellow
    'line_07': const Color(0xFFFFA500),  // Orange
    'line_08': const Color(0xFF800080),  // Purple
    'line_09': const Color(0xFF00FF00),  // Lime
    'line_10': const Color(0xFFFFC0CB),  // Pink
    'line_11': const Color(0xFF008080),  // Teal
    'line_12': const Color(0xFFABABFF),  // Lavender
    'line_13': const Color(0xFFA52A2A),  // Brown
    'line_14': const Color(0xFF800000),  // Maroon
    'line_15': const Color(0xFF000080),  // Navy
    'line_16': const Color(0xFF808000),  // Olive
    'line_17': const Color(0xFFFF7F50),  // Coral
  };

  Map<String, Color> defaultColor = {
    'appBar': const Color(0xFF00C8FF),        //GameUI
    'appIcon': const Color(0xFF000000),       //GameUI
    'background': const Color(0xFFFFF0E3),    //GameSceneStateSquare
    'box': const Color(0xFFFFFFFF),           //SquareBoxState
    'number': const Color(0xFF000000),        //SquareBoxState
  };

  Map<String, Color> warm = {
    'appBar': const Color(0xFFFF6F61),
    'appIcon': const Color(0xFFE94E3F),
    'background': const Color(0xFFFFF0E3),
    'box': const Color(0xFFFFD700),
    'number': const Color(0xFFD2691E),
  };

  Map<String, Color> cool = {
    'appBar': const Color(0xFF4682B4),
    'appIcon': const Color(0xFF5F9EA0),
    'background': const Color(0xFFE0FFFF),
    'box': const Color(0xFFAFEEEE),
    'number': const Color(0xFF20B2AA),
  };

  Map<String, Color> earth = {
    'appBar': const Color(0xFF8B4513),
    'appIcon': const Color(0xFFA0522D),
    'background': const Color(0xFFF5F5DC),
    'box': const Color(0xFFDEB887),
    'number': const Color(0xFF8B0000),
  };

  Map<String, Color> pastel = {
    'appBar': const Color(0xFFFFB6C1),
    'appIcon': const Color(0xFFFF69B4),
    'background': const Color(0xFFFFFACD),
    'box': const Color(0xFFE6E6FA),
    'number': const Color(0xFFB0E0E6),
  };

  Map<String, Color> vibrant = {
    'appBar': const Color(0xFFFF4500),
    'appIcon': const Color(0xFFFF6347),
    'background': const Color(0xFFFFFFE0),
    'box': const Color(0xFF32CD32),
    'number': const Color(0xFFFFD700),
  };

  ThemeColor();

  List<String> getList() {
    return ["default", "warm", "cool", "earth", "pastel", "vibrant"];
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

  ///1 : normal, 2 : hint, -1 : disable, -2 : wrong, 0 : select
  Color getLineColor({int type = 0}) {
    //user selection
    if(type == 0) {
      //line_01 ~ line_17
      int num = Random().nextInt(lineColor.keys.length - 4) + 1;
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
      case 1:
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
      case 2:
        rtColor = lineColor["line_hint"]!;
        break;
    }

    //print("rtColor : $rtColor");
    return rtColor;
  }
}