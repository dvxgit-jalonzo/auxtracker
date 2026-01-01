import 'dart:async';

import 'package:auto_updater/auto_updater.dart';

class AppUpdaterListener extends UpdaterListener {
  final Completer<bool> gate;

  AppUpdaterListener(this.gate);

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
    if (!gate.isCompleted) {
      gate.complete(true);
    }
  }

  @override
  void onUpdaterUpdateAvailable(AppcastItem? appcastItem) {
    print("Update Available");
    if (!gate.isCompleted) {
      gate.complete(false);
    }
  }

  @override
  void onUpdaterUpdateDownloaded(AppcastItem? appcastItem) {
    print("Update Downloaded");
  }

  @override
  void onUpdaterUpdateNotAvailable(UpdaterError? error) {
    print("Update Not Available");
    if (!gate.isCompleted) {
      gate.complete(true);
    }
  }
}
