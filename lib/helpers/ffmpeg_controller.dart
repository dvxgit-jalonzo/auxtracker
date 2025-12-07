import 'dart:io';

import 'package:intl/intl.dart';

import 'api_controller.dart';

Process? recorderProcess;

// --------------------------------------------------------
// 1. Get FFmpeg path from installation folder
// --------------------------------------------------------
String get ffmpegPath {
  // Use executable directory (where the EXE is installed)
  final exeDir = File(Platform.resolvedExecutable).parent.path;
  final ffmpegExe = '$exeDir\\ffmpeg.exe';

  if (!File(ffmpegExe).existsSync()) {
    throw Exception(
      'FFmpeg not found at $ffmpegExe. Make sure it is installed with the app.',
    );
  }

  return ffmpegExe;
}

// --------------------------------------------------------
// 2. Build output path in Videos\AuxTracker
// --------------------------------------------------------
Future<String> buildOutputPath() async {
  final userVideos = Directory(
    '${Platform.environment['USERPROFILE']}\\Videos\\AuxTracker',
  );

  if (!userVideos.existsSync()) {
    userVideos.createSync(recursive: true);
  }

  final userInfo = await ApiController.instance.loadUserInfo();
  if (userInfo == null || userInfo['id'] == null) {
    throw Exception('User info not found. Please login first.');
  }

  final timestamp = DateFormat('yyyyMMddHHmmss').format(DateTime.now());
  return '${userVideos.path}\\${userInfo['id']}-$timestamp.mp4';
}

// --------------------------------------------------------
// 3. Start Recording
// --------------------------------------------------------
Future<void> startRecording() async {
  try {
    final ffmpeg = ffmpegPath;
    final output = await buildOutputPath();

    print("FFmpeg path: $ffmpeg");
    print("Recording output path: $output");

    recorderProcess = await Process.start(ffmpeg, [
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

    recorderProcess!.stderr
        .transform(SystemEncoding().decoder)
        .listen((data) => print("FFmpeg: $data"));

    print("Recording started...");
  } catch (e) {
    print("Error starting recording: $e");
  }
}

// --------------------------------------------------------
// 4. Stop Recording
// --------------------------------------------------------
Future<void> stopRecording() async {
  if (recorderProcess == null) {
    print("No active recording.");
    return;
  }

  print("Stopping recording...");

  try {
    recorderProcess!.stdin.write('q');
    await recorderProcess!.exitCode;
    print("Recording stopped.");
  } catch (e) {
    print("Error stopping recording: $e");
  }

  recorderProcess = null;
}
