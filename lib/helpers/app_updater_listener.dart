import 'dart:ui';

import 'package:auto_updater/auto_updater.dart';
import 'package:auxtrack/update_gate.dart';

class AppUpdaterListener extends UpdaterListener {
  final VoidCallback onReady;

  AppUpdaterListener({required this.onReady});

  @override
  void onUpdaterBeforeQuitForUpdate(AppcastItem? appcastItem) {
    print("Before Quit For Update");
  }

  @override
  void onUpdaterCheckingForUpdate(Appcast? appcast) {
    print("Checking for Update : $appcast");
  }

  @override
  void onUpdaterError(UpdaterError? error) {
    print("Update Error : $error");
    if (!updateGate.isCompleted) {
      updateGate.complete(true);
    }

    onReady();
  }

  @override
  void onUpdaterUpdateAvailable(AppcastItem? appcastItem) {
    print("Update Available");
    if (!updateGate.isCompleted) {
      updateGate.complete(false);
    }
  }

  @override
  void onUpdaterUpdateDownloaded(AppcastItem? appcastItem) {
    print("Update Downloaded");
  }

  @override
  void onUpdaterUpdateNotAvailable(UpdaterError? error) {
    print("Update Not Available");
    if (!updateGate.isCompleted) {
      updateGate.complete(true);
    }
    onReady();
  }
}
