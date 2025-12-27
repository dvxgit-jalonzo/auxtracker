import 'package:flutter/cupertino.dart';
import 'package:window_manager/window_manager.dart';

class WindowModes {
  final Size size = Size(300, 350);

  static Future<void> normal() async {
    await windowManager.ensureInitialized();

    await windowManager.waitUntilReadyToShow(
      WindowOptions(
        size: WindowModes().size,
        center: false,
        titleBarStyle: TitleBarStyle.normal,
        windowButtonVisibility: false,
        skipTaskbar: false,
        alwaysOnTop: true,
        title: "Auxiliary Tracker",
      ),
      () async {
        await windowManager.setAlignment(Alignment.centerRight);
        await windowManager.show();
        await windowManager.focus();
        await windowManager.setMaximumSize(WindowModes().size);
        await windowManager.setMinimizable(true);
        await windowManager.setMaximizable(false);
        await windowManager.setResizable(false);
        await windowManager.setPreventClose(false);
        await windowManager.setClosable(true);
      },
    );
  }

  static Future<void> restricted() async {
    await windowManager.ensureInitialized();

    await windowManager.waitUntilReadyToShow(
      WindowOptions(
        size: WindowModes().size,
        center: false,
        titleBarStyle: TitleBarStyle.hidden,
        windowButtonVisibility: false,
        alwaysOnTop: true,
      ),
      () async {
        await windowManager.setAlignment(Alignment.centerRight);
        await windowManager.show();
        await windowManager.focus();
        await windowManager.setMaximumSize(WindowModes().size);
        await windowManager.setSkipTaskbar(true);
        await windowManager.setMinimizable(false);
        await windowManager.setMaximizable(false);
        await windowManager.setResizable(false);
        await windowManager.setPreventClose(true);
        await windowManager.setClosable(false);
      },
    );
  }
}
