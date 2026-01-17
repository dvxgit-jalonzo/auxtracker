import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:window_manager/window_manager.dart';

class WindowModes with WindowListener {
  final Size size = Size(320, 350);
  static WindowModes? _instance;

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

  static Future<void> boostrap() async {
    await windowManager.ensureInitialized();

    await windowManager.waitUntilReadyToShow(
      WindowOptions(
        size: WindowModes().size,
        center: false,
        titleBarStyle: TitleBarStyle.normal,
        windowButtonVisibility: false,
        alwaysOnTop: true,
        skipTaskbar: true,
        title: "Auxiliary Tracker",
      ),
      () async {
        await windowManager.setAlignment(Alignment.centerRight);
        await windowManager.show();
        await windowManager.focus();
        await windowManager.setMaximumSize(WindowModes().size);
        await windowManager.setSkipTaskbar(false);
        await windowManager.setMinimizable(false);
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
        skipTaskbar: false,
        title: "Auxiliary Tracker",
      ),
      () async {
        await windowManager.setAlignment(Alignment.centerRight);
        await windowManager.show();
        await windowManager.focus();
        await windowManager.setMaximumSize(WindowModes().size);
        await windowManager.setSkipTaskbar(false);
        await windowManager.setMinimizable(true);
        await windowManager.setMaximizable(false);
        await windowManager.setResizable(false);
        await windowManager.setPreventClose(true);
        await windowManager.setClosable(false);

        // Enable position restriction
        _instance = WindowModes();
        windowManager.removeListener(_instance!);
        windowManager.addListener(_instance!);
      },
    );
  }

  @override
  void onWindowMoved() async {
    try {
      // Get current window position and size
      Rect bounds = await windowManager.getBounds();

      // Get screen size - using the primary display
      final display = ui.PlatformDispatcher.instance.displays.first;
      final screenWidth = display.size.width / display.devicePixelRatio;
      final screenHeight = display.size.height / display.devicePixelRatio;

      // Minimum visible area (in pixels)
      const minVisibleWidth = 320.0;
      const minVisibleHeight = 140.0;

      double newX = bounds.left;
      double newY = bounds.top;
      bool needsAdjustment = false;

      // Prevent dragging too far left
      if (newX < -bounds.width + minVisibleWidth) {
        newX = -bounds.width + minVisibleWidth;
        needsAdjustment = true;
      }

      // Prevent dragging too far right
      if (newX > screenWidth - minVisibleWidth) {
        newX = screenWidth - minVisibleWidth;
        needsAdjustment = true;
      }

      // Prevent dragging too far up
      if (newY < 0) {
        newY = 0;
        needsAdjustment = true;
      }

      // Prevent dragging too far down
      if (newY > screenHeight - minVisibleHeight) {
        newY = screenHeight - minVisibleHeight;
        needsAdjustment = true;
      }

      // Reset position if out of bounds
      if (needsAdjustment) {
        await windowManager.setPosition(Offset(newX, newY));
      }
    } catch (e) {
      // Silently handle any errors
      print('Error constraining window position: $e');
    }
  }

  // Clean up listener when needed
  static Future<void> removePositionRestriction() async {
    if (_instance != null) {
      windowManager.removeListener(_instance!);
      _instance = null;
    }
  }
}
