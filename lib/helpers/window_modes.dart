import 'package:window_manager/window_manager.dart';

class WindowModes {
  static Future<void> normal() async {
    await windowManager.setTitleBarStyle(TitleBarStyle.normal);
    await windowManager.setSkipTaskbar(false);
    await windowManager.setMinimizable(true);
    await windowManager.setMaximizable(false);
    await windowManager.setResizable(false);
    await windowManager.setPreventClose(false);
    await windowManager.setClosable(true);
  }

  static Future<void> restricted() async {
    await windowManager.setTitleBarStyle(TitleBarStyle.hidden);
    await windowManager.setSkipTaskbar(true);
    await windowManager.setMinimizable(false);
    await windowManager.setMaximizable(false);
    await windowManager.setResizable(false);
    await windowManager.setPreventClose(true);
    await windowManager.setClosable(false);
  }
}
