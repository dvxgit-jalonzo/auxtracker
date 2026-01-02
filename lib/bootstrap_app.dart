import 'dart:io';

import 'package:auto_updater/auto_updater.dart';
import 'package:auxtrack/helpers/app_updater_listener.dart';
import 'package:auxtrack/helpers/configuration.dart';
import 'package:flutter/material.dart';

import 'helpers/window_modes.dart';
import 'main.dart';

class BootstrapApp extends StatefulWidget {
  const BootstrapApp({super.key});

  @override
  State<BootstrapApp> createState() => _BootstrapAppState();
}

class _BootstrapAppState extends State<BootstrapApp> {
  bool ready = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await WindowModes.boostrap();
    if (Platform.isWindows) {
      final feedURL = await Configuration.instance.get("updater");

      await autoUpdater.setFeedURL(feedURL);
      await autoUpdater.setScheduledCheckInterval(3600);

      autoUpdater.addListener(
        AppUpdaterListener(
          onReady: () {
            if (mounted) {
              setState(() => ready = true);
            }
          },
        ),
      );

      await autoUpdater.checkForUpdates(inBackground: true);
    } else {
      setState(() => ready = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!ready) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.green.shade700, Colors.deepPurple.shade900],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Animated loading indicator
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.1),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.blue.withValues(alpha: 0.3),
                          blurRadius: 20,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: const Padding(
                      padding: EdgeInsets.all(20),
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        strokeWidth: 3,
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                  // Main text
                  const Text(
                    "Update Available!",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Subtitle
                  Text(
                    "A new version is ready to install.",
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  Text(
                    "Please update to continue.",
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return const MyApp();
  }
}
