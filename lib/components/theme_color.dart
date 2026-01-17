import 'package:flutter/material.dart';

enum ThemeColor {
  breaks,
  overtime,
  other,
  logoff,
  logon,
  puertoRico,
  warmPastel,
  dullLavender,
  chalky,
  bermuda,
  pictonBlue,
  primrose,
  froly,
  fountainBlue,
}

extension ThemeColorExtension on ThemeColor {
  Color get color {
    switch (this) {
      case ThemeColor.other:
        return const Color.fromRGBO(43, 127, 255, 1);
      case ThemeColor.logoff:
        // return const Color.fromRGBO(157, 78, 1, 1);
        return const Color.fromRGBO(220, 39, 79, 1);
      case ThemeColor.logon:
        return const Color.fromRGBO(18, 60, 121, 1);
      // return const Color.fromRGBO(89, 142, 54, 1);
      case ThemeColor.breaks:
        return const Color.fromRGBO(230, 96, 0, 1);
      case ThemeColor.puertoRico:
        return const Color.fromRGBO(54, 191, 164, 1);
      case ThemeColor.overtime:
        return const Color.fromRGBO(142, 81, 255, 1);
      case ThemeColor.dullLavender:
        return const Color.fromRGBO(188, 155, 226, 1);
      case ThemeColor.chalky:
        return const Color.fromRGBO(240, 202, 150, 1);
      case ThemeColor.bermuda:
        return const Color.fromRGBO(119, 224, 174, 1);
      case ThemeColor.pictonBlue:
        return const Color.fromRGBO(25, 180, 236, 1);
      case ThemeColor.warmPastel:
        return const Color.fromRGBO(249, 216, 77, 1);
      case ThemeColor.primrose:
        return const Color.fromRGBO(232, 240, 170, 1);
      case ThemeColor.froly:
        return const Color.fromRGBO(243, 129, 118, 1);
      case ThemeColor.fountainBlue:
        return const Color.fromRGBO(92, 187, 187, 1);
    }
  }

  static ThemeColor fromAuxiliaryKey(String key) {
    switch (key.toUpperCase()) {
      case "BREAK":
        return ThemeColor.breaks;
      case "OT":
        return ThemeColor.dullLavender;
      case "OTHER":
        return ThemeColor.other;
      case "LOG OFF":
        return ThemeColor.logoff;
      case "LOG ON":
        return ThemeColor.warmPastel;
      default:
        return ThemeColor.puertoRico;
    }
  }
}
