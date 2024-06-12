import 'dart:ui';

import 'User/UserInfo.dart';

class ThemeColor {
  Map<String, Color> defaultColor = {
    'appBar': const Color(0xFF00C8FF),        //GameUI
    'appIcon': const Color(0xFF000000),       //GameUI
    'background': const Color(0xFFFFF0E3),    //GameSceneStateSquare
    'box': const Color(0xFFFFFFFF),           //SquareBoxState
    'number': const Color(0xFF000000),        //SquareBoxState
    'lineInactive': const Color(0xCCFFFFFF),  //SquareBox
    'lineNormal': const Color(0x1A000000),    //SquareBox
    'lineSelected': const Color(0xFF000000),  //SquareBox
    'lineWrong': const Color(0xFFFF0000),     //SquareBox
    'lineHint': const Color(0xFFFFFF00),      //SquareBox
  };

  Map<String, Color> warm = {
    'appBar': const Color(0xFFFF6F61),
    'appIcon': const Color(0xFFE94E3F),
    'background': const Color(0xFFFFF0E3),
    'box': const Color(0xFFFFD700),
    'number': const Color(0xFFD2691E),
    'lineInactive': const Color(0xFFE5E5E5),
    'lineNormal': const Color(0xFF8B4513),
    'lineSelected': const Color(0xFFCD5C5C),
    'lineWrong': const Color(0xFFB22222),
    'lineHint': const Color(0xFFFF4500),
  };

  Map<String, Color> cool = {
    'appBar': const Color(0xFF4682B4),
    'appIcon': const Color(0xFF5F9EA0),
    'background': const Color(0xFFE0FFFF),
    'box': const Color(0xFFAFEEEE),
    'number': const Color(0xFF20B2AA),
    'lineInactive': const Color(0xFFE5E5E5),
    'lineNormal': const Color(0xFF000080),
    'lineSelected': const Color(0xFF4169E1),
    'lineWrong': const Color(0xFF1E90FF),
    'lineHint': const Color(0xFF00CED1),
  };

  Map<String, Color> earth = {
    'appBar': const Color(0xFF8B4513),
    'appIcon': const Color(0xFFA0522D),
    'background': const Color(0xFFF5F5DC),
    'box': const Color(0xFFDEB887),
    'number': const Color(0xFF8B0000),
    'lineInactive': const Color(0xFFE5E5E5),
    'lineNormal': const Color(0xFF556B2F),
    'lineSelected': const Color(0xFF8FBC8F),
    'lineWrong': const Color(0xFF2E8B57),
    'lineHint': const Color(0xFF66CDAA),
  };

  Map<String, Color> pastel = {
    'appBar': const Color(0xFFFFB6C1),
    'appIcon': const Color(0xFFFF69B4),
    'background': const Color(0xFFFFFACD),
    'box': const Color(0xFFE6E6FA),
    'number': const Color(0xFFB0E0E6),
    'lineInactive': const Color(0xFFE5E5E5),
    'lineNormal': const Color(0xFF9370DB),
    'lineSelected': const Color(0xFFBA55D3),
    'lineWrong': const Color(0xFF9932CC),
    'lineHint': const Color(0xFFDA70D6),
  };

  Map<String, Color> vibrant = {
    'appBar': const Color(0xFFFF4500),
    'appIcon': const Color(0xFFFF6347),
    'background': const Color(0xFFFFFFE0),
    'box': const Color(0xFF32CD32),
    'number': const Color(0xFFFFD700),
    'lineInactive': const Color(0xFFE5E5E5),
    'lineNormal': const Color(0xFF8A2BE2),
    'lineSelected': const Color(0xFFFF1493),
    'lineWrong': const Color(0xFFDC143C),
    'lineHint': const Color(0xFF00FF00),
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
}