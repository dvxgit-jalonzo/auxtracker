import 'dart:io';

import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

import 'api_controller.dart'; // Assuming this provides loadUserInfo()

class VideoRecorderController {
  // 1. Static private instance variable
  static final VideoRecorderController _instance =
      VideoRecorderController._internal();

  // 2. Factory constructor to return the static instance
  factory VideoRecorderController() {
    return _instance;
  }

  // 3. Private constructor for the singleton
  VideoRecorderController._internal();

  // --- Singleton implementation complete ---

  Process? _recorderProcess;
  bool _isRecording = false;

  // Getter to check the current recording state
  bool get isRecording => _isRecording;

  String get _ffmpegPath {
    // Assuming the application is a desktop application (e.g., built with Flutter Desktop)
    final exeDir = File(Platform.resolvedExecutable).parent.path;
    final ffmpegExe = Platform.isWindows
        ? '$exeDir\\ffmpeg\\ffmpeg.exe'
        : '$exeDir/ffmpeg';

    if (!File(ffmpegExe).existsSync()) {
      throw Exception(
        'FFmpeg not found at $ffmpegExe. Ensure it is installed with the app.',
      );
    }

    return ffmpegExe;
  }

  Future<String> _buildOutputPath() async {
    final documentsDir = await getApplicationSupportDirectory();
    final auxTrackerFolder = Directory(
      '${documentsDir.path}${Platform.pathSeparator}AuxTracker Recordings',
    );

    if (!await auxTrackerFolder.exists()) {
      await auxTrackerFolder.create(recursive: true);
    }

    // Load user info for file naming
    final userInfo = await ApiController.instance.loadUserInfo();
    final userId = userInfo?['id'] ?? 'Guest';
    final timestamp = DateFormat('yyyyMMddHHmmss').format(DateTime.now());
    final outputFileName = '$userId-$timestamp.mp4';

    return '${auxTrackerFolder.path}${Platform.pathSeparator}$outputFileName';
  }

  /// Starts the screen recording using FFmpeg.
  /// This implementation is tailored for Windows screen recording.
  Future<void> startRecording() async {
    if (_isRecording) {
      print('Recording is already running.');
      return;
    }

    if (!Platform.isWindows) {
      // NOTE: FFmpeg screen recording arguments vary significantly by OS.
      // You would need to adjust the arguments for macOS/Linux.
      throw UnsupportedError(
        'FFmpeg screen recording is only configured for Windows (gdigrab) in this example.',
      );
    }

    try {
      final outputPath = await _buildOutputPath();
      print('Starting recording to: $outputPath');

      // FFmpeg arguments for Windows screen recording (gdigrab)
      final arguments = [
        '-f', 'gdigrab', // Input format: GDI screen capture
        '-i', 'desktop', // Input: Capture the entire desktop
        '-draw_mouse',
        '0', // Recommended: Fixes mouse flicker without external tools
        '-r', '30', // Frame rate: 30 fps (Keeping your original 'nice' FPS)
        '-c:v', 'libx264', // Video codec: H.264 (Software)
        '-preset',
        'superfast', // Encoding speed preset (Kept high for smooth recording)
        '-crf', '32', // <--- NEW: Controls quality vs. file size
        '-pix_fmt', 'yuv420p', // Pixel format for compatibility
        outputPath, // Output file path
      ];

      _recorderProcess = await Process.start(
        _ffmpegPath,
        arguments,
        runInShell: true,
      );
      _isRecording = true;
      print('FFmpeg process started (PID: ${_recorderProcess!.pid}).');

      // Listen for FFmpeg process exit for error handling/logging
      _recorderProcess!.exitCode.then((exitCode) {
        if (_isRecording) {
          // Only log if we didn't stop it intentionally
          print('FFmpeg process exited with code $exitCode.');
        }
        _isRecording = false;
        _recorderProcess = null;
      });

      // Stream error output for debugging
      _recorderProcess!.stderr.listen((data) {
        final output = String.fromCharCodes(data).trim();
        if (output.isNotEmpty) {}
      });
    } catch (e) {
      _isRecording = false;
      _recorderProcess = null;
      print('Error starting recording: $e');
      rethrow;
    }
  }

  /// Stops the FFmpeg recording process.
  Future<void> stopRecording() async {
    if (!_isRecording || _recorderProcess == null) {
      print('No recording is currently active.');
      return;
    }

    print('Stopping recording (PID: ${_recorderProcess!.pid})...');

    try {
      _recorderProcess!.stdin.write('q');
      await _recorderProcess!.exitCode;

      print('Recording stopped and file finalized.');
    } on Exception catch (e) {
      // Fallback: Terminate the process if graceful stop fails (e.g., stdin not open)
      print('Error during graceful stop: $e. Killing process as fallback.');
      _recorderProcess!.kill();
    } finally {
      _isRecording = false;
      _recorderProcess = null;
    }
  }
}
