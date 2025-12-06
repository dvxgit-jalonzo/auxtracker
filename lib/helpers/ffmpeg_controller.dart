import 'dart:io';

import 'package:intl/intl.dart';

import 'api_controller.dart';

Process? recorderProcess;

/// Path to FFmpeg executable
String get ffmpegPath {
  final exeDir = Directory.current.path;
  return '$exeDir/windows/ffmpeg/ffmpeg.exe';
}

/// Path to the output recording in the user's Videos\AuxTracker folder
Future<String> outputPath() async {
  final videosDir = Directory(
    '${Platform.environment['USERPROFILE']}\\Videos\\AuxTracker',
  );
  if (!videosDir.existsSync()) {
    videosDir.createSync(recursive: true);
  }
  final userInfo = await ApiController.instance.loadUserInfo();
  if (userInfo == null || userInfo['id'] == null) {
    throw Exception('User info not found. Please login first.');
  }

  final timestamp = DateFormat('yyyyMMddHHmmss').format(DateTime.now());
  return '${videosDir.path}\\${userInfo['id']}-$timestamp.mp4';
}

Future<void> startRecording() async {
  final path = ffmpegPath;
  print('FFmpeg path: $path');
  final filename = await outputPath();
  print('Recording output path: $filename');
  recorderProcess = await Process.start(path, [
    '-y',
    '-f', 'gdigrab',
    '-framerate', '30',
    '-i', 'desktop',
    '-vcodec', 'libx264', // Use H.264 codec
    '-preset', 'veryfast', // Balance speed vs compression
    '-crf', '28', // Lower CRF = higher quality, higher storage
    '-pix_fmt', 'yuv420p',
    filename,
  ], runInShell: true);

  recorderProcess!.stderr.transform(SystemEncoding().decoder).listen((data) {
    print("FFmpeg: $data");
  });

  print("Recording started…");
}

Future<void> stopRecording() async {
  if (recorderProcess != null) {
    print("Stopping recording…");
    // send 'q' to FFmpeg's stdin to stop recording properly
    recorderProcess!.stdin.write('q');
    await recorderProcess!.exitCode; // wait until process fully exits
    recorderProcess = null;
    print("Recording stopped.");
  }
}
