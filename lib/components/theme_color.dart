import 'dart:ui';

enum ThemeColor {
  puertoRico,
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
      case ThemeColor.puertoRico:
        return const Color.fromRGBO(54, 191, 164, 1);
      case ThemeColor.dullLavender:
        return const Color.fromRGBO(188, 155, 226, 1);
      case ThemeColor.chalky:
        return const Color.fromRGBO(240, 202, 150, 1);
      case ThemeColor.bermuda:
        return const Color.fromRGBO(119, 224, 174, 1);
      case ThemeColor.pictonBlue:
        return const Color.fromRGBO(25, 180, 236, 1);
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
        return ThemeColor.froly;
      case "OT":
        return ThemeColor.dullLavender;
      case "OTHER":
        return ThemeColor.pictonBlue;
      case "LOG OFF":
        return ThemeColor.chalky;
      case "LOG ON":
        return ThemeColor.puertoRico;
      default:
        return ThemeColor.bermuda; // Default color kung walang match
    }
  }
}
