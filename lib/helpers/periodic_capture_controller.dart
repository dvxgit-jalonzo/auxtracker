import 'dart:async';
import 'dart:io';

import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

// No longer needed for FFmpeg approach
// import 'package:screen_capturer/screen_capturer.dart';

import 'api_controller.dart'; // Assuming this provides loadUserInfo()

class PeriodicCaptureController {
  // 1. Singleton Setup
  static final PeriodicCaptureController _instance =
      PeriodicCaptureController._internal();
  factory PeriodicCaptureController() => _instance;
  PeriodicCaptureController._internal();

  // 2. Internal State
  Timer? _captureTimer;
  bool get isCapturingPeriodically => _captureTimer?.isActive ?? false;

  final Duration _defaultInterval = const Duration(
    seconds: 5,
  ); // Increased interval for stability

  // --- FFmpeg Path Getter ---

  /// Determines the path to the bundled ffmpeg.exe relative to the main executable.
  String get _ffmpegPath {
    // On Windows, the resolvedExecutable is the app's .exe path.
    // We assume ffmpeg.exe is in a subfolder named 'ffmpeg' next to the main .exe.
    final exeDir = File(Platform.resolvedExecutable).parent.path;
    final ffmpegExe =
        '$exeDir${Platform.pathSeparator}ffmpeg${Platform.pathSeparator}ffmpeg.exe';

    if (!File(ffmpegExe).existsSync()) {
      // For development in VS Code/IDE, ffmpeg may need to be in the PATH
      return 'ffmpeg';
      // throw Exception(
      //   'FFmpeg not found at $ffmpegExe. Please ensure it is bundled correctly.',
      // );
    }
    return ffmpegExe;
  }

  // --- Helper Methods ---

  Future<String> _buildCapturePath() async {
    // ----------------------------------------------------
    // CHANGE THIS LINE:
    // final documentsDir = await getApplicationDocumentsDirectory();
    // TO THIS LINE:
    final appDataDir = await getApplicationSupportDirectory();
    // ----------------------------------------------------

    // Use an AuxTracker subfolder in AppData
    final yearMonth = DateFormat('yyyyMM').format(DateTime.now());
    final day = DateFormat('dd').format(DateTime.now());
    final captureFolder = Directory(
      // ----------------------------------------------------
      // AND CHANGE THE VARIABLE NAME HERE:
      '${appDataDir.path}${Platform.pathSeparator}AuxTracker/$yearMonth/$day',
      // ----------------------------------------------------
    );

    if (!await captureFolder.exists()) {
      await captureFolder.create(recursive: true);
    }

    // Load user info for file naming (rest of the code is the same)
    final userInfo = await ApiController.instance.loadUserInfo();
    final userId = userInfo?['id'] ?? 'Guest';
    final timestamp = DateFormat('HHmmss').format(DateTime.now());
    // FFmpeg is highly optimized for PNG output
    final outputFileName = '$userId-$timestamp.jpeg';

    return '${captureFolder.path}${Platform.pathSeparator}$outputFileName';
  }

  // --- Core Capture Function (Modified for FFmpeg) ---

  Future<void> _takeExternalScreenshot() async {
    // ... (omitted boilerplate code)
    try {
      final ffmpegPath = _ffmpegPath;
      final screenshotPath = await _buildCapturePath();
      // print(screenshotPath);
      // Arguments to capture a single, silent frame using gdigrab
      final arguments = [
        '-f', 'gdigrab',
        '-i',
        'desktop', // <--- FIX: Changed from 'desktop:0' back to 'desktop'
        '-offset_x',
        '0', // Start capture at the top-left corner of the virtual desktop
        '-offset_y', '0',
        '-vframes', '1',
        '-draw_mouse', '0',

        // --- Output Control Options for JPEG ---
        '-q:v',
        '6', // Quality scale: 2 (best) to 31 (worst). 4 is high quality.

        screenshotPath, // Output file path (.jpg)
      ];

      // Process.run executes the external command and waits for it to complete
      final result = await Process.run(ffmpegPath, arguments);

      // ... (omitted success/failure logging)
    } catch (e) {
      print('Critical error during FFmpeg capture execution: $e');
    }
  }

  // --- Public Control Methods (Unchanged) ---

  /// Starts the periodic screen capturing.
  ///
  /// [seconds] The interval in seconds between each capture.
  /// Defaults to 5 seconds.
  void startCapturing({int? seconds}) {
    if (isCapturingPeriodically) {
      print('Periodic capture is already running. Stopping and restarting...');
      stopCapturing();
    }

    final interval = Duration(seconds: seconds ?? _defaultInterval.inSeconds);

    print('Starting periodic capture every ${interval.inSeconds} seconds.');

    // Run the capture function immediately
    _takeExternalScreenshot();

    // Set up the timer to run the capture function repeatedly
    _captureTimer = Timer.periodic(interval, (Timer t) {
      _takeExternalScreenshot();
    });
  }

  /// Stops the periodic screen capturing.
  void stopCapturing() {
    if (_captureTimer != null) {
      _captureTimer!.cancel();
      _captureTimer = null;
      print('Periodic capture stopped.');
    } else {
      print('No periodic capture was active.');
    }
  }
}
