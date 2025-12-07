import 'dart:io';

import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

import 'api_controller.dart';

class VideoRecorderController {
  Process? _recorderProcess;

  // -----------------------------
  // 1. FFmpeg path from installation folder
  // -----------------------------
  String get _ffmpegPath {
    final exeDir = File(Platform.resolvedExecutable).parent.path;
    final ffmpegExe = Platform.isWindows
        ? '$exeDir\\ffmpeg.exe'
        : '$exeDir/ffmpeg';

    if (!File(ffmpegExe).existsSync()) {
      throw Exception(
        'FFmpeg not found at $ffmpegExe. Ensure it is installed with the app.',
      );
    }

    return ffmpegExe;
  }

  // -----------------------------
  // 2. Build output path in installation folder
  // -----------------------------
  Future<String> _buildOutputPath() async {
    // 1. Get the path to the user's Documents directory (or equivalent)
    final documentsDir = await getApplicationDocumentsDirectory();

    // 2. Create a specific subfolder for your app's recordings
    final auxTrackerFolder = Directory(
      '${documentsDir.path}${Platform.pathSeparator}AuxTracker Recordings',
    );

    // Create the directory if it doesn't exist
    if (!await auxTrackerFolder.exists()) {
      await auxTrackerFolder.create(recursive: true);
    }

    final userInfo = await ApiController.instance.loadUserInfo();

    // Safely get user ID or use a default
    final userId = userInfo?['id'] ?? 'Guest';

    final timestamp = DateFormat('yyyyMMddHHmmss').format(DateTime.now());
    final outputFileName = '$userId-$timestamp.mp4';

    // 3. Return the final safe and absolute path
    return '${auxTrackerFolder.path}${Platform.pathSeparator}$outputFileName';
  }

  // -----------------------------
  // 3. Start recording
  // -----------------------------
  Future<void> startRecording() async {
    if (_recorderProcess != null) {
      print('Recording already in progress.');
      return;
    }

    try {
      final ffmpeg = _ffmpegPath;
      final output = await _buildOutputPath();

      print('FFmpeg path: $ffmpeg');
      print('Recording output path: $output');

      _recorderProcess = await Process.start(ffmpeg, [
        '-y',
        '-f',
        'gdigrab',
        '-framerate',
        '30',
        '-i',
        'desktop',
        '-vcodec',
        'libx264',
        '-preset',
        'veryfast',
        '-crf',
        '28',
        '-pix_fmt',
        'yuv420p',
        output,
      ], runInShell: true);

      _recorderProcess!.stderr
          .transform(SystemEncoding().decoder)
          .listen((data) => print('FFmpeg: $data'));

      print('Recording started...');
    } catch (e) {
      print('Error starting recording: $e');
    }
  }

  // -----------------------------
  // 4. Stop recording
  // -----------------------------
  Future<void> stopRecording() async {
    if (_recorderProcess == null) {
      print('No active recording.');
      return;
    }

    print('Stopping recording...');

    try {
      _recorderProcess!.stdin.write('q');
      await _recorderProcess!.exitCode;
      print('Recording stopped.');
    } catch (e) {
      print('Error stopping recording: $e');
    } finally {
      _recorderProcess = null;
    }
  }
}
