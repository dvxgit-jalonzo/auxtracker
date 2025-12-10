import 'dart:ui';

import 'package:window_manager/window_manager.dart';

class WindowModes {
  static Future<void> normal() async {
    await windowManager.ensureInitialized();

    await windowManager.waitUntilReadyToShow(WindowOptions(
      size: Size(400, 500),
      center: true,
      titleBarStyle: TitleBarStyle.normal,
      windowButtonVisibility: false,
      skipTaskbar: false,
      alwaysOnTop: true,
      title: "Auxiliary Tracker",
    ), () async {
      await windowManager.show();
      await windowManager.focus();

      await windowManager.setMinimizable(true);

      await windowManager.setMaximizable(false);
      await windowManager.setResizable(false);
      await windowManager.setPreventClose(false);
      await windowManager.setClosable(true);
    });

  }

  static Future<void> restricted() async {
    await windowManager.ensureInitialized();

    await windowManager.waitUntilReadyToShow(WindowOptions(
      size: Size(300, 350),
      center: true,
      titleBarStyle: TitleBarStyle.hidden,
      windowButtonVisibility: false,
      alwaysOnTop: true,
    ), () async {
      await windowManager.show();
      await windowManager.focus();
      await windowManager.setMaximumSize( Size(300, 350));
      await windowManager.setSkipTaskbar(true);
      await windowManager.setMinimizable(false);
      await windowManager.setMaximizable(false);
      await windowManager.setResizable(false);
      await windowManager.setPreventClose(true);
      await windowManager.setClosable(false);
    });
  }
}
