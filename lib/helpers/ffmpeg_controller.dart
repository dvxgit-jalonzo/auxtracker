import 'dart:io';

import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import 'api_controller.dart'; // your API to get user info

Process? recorderProcess;

// --------------------------------------------------------
// 1. Extract FFmpeg.exe from assets → LocalAppData directory
// --------------------------------------------------------
Future<String> ensureFfmpegInstalled() async {
  final localAppData = Platform.environment['LOCALAPPDATA']!;
  final ffmpegDir = Directory('$localAppData\\AuxTracker\\ffmpeg');

  if (!ffmpegDir.existsSync()) {
    ffmpegDir.createSync(recursive: true);
  }

  final ffmpegExe = File('${ffmpegDir.path}\\ffmpeg.exe');

  // Only copy if missing
  if (!ffmpegExe.existsSync()) {
    print("Extracting FFmpeg to ${ffmpegExe.path}…");

    final data = await rootBundle.load('assets/ffmpeg/ffmpeg.exe');
    final bytes = data.buffer.asUint8List();
    await ffmpegExe.writeAsBytes(bytes, flush: true);

    print("FFmpeg installed.");
  }

  return ffmpegExe.path;
}

// --------------------------------------------------------
// 2. Build output path in Videos/AuxTracker
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
    throw Exception('User info not found. Login first.');
  }

  final timestamp = DateFormat('yyyyMMddHHmmss').format(DateTime.now());
  return '${userVideos.path}\\${userInfo['id']}-$timestamp.mp4';
}

// --------------------------------------------------------
// 3. Start Recording
// --------------------------------------------------------
Future<void> startRecording() async {
  try {
    final ffmpeg = await ensureFfmpegInstalled();
    final output = await buildOutputPath();

    print("FFmpeg path: $ffmpeg");
    print("Saving recording to: $output");

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

    print("Recording started.");
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

  print("Stopping recording…");

  try {
    recorderProcess!.stdin.write('q');
    await recorderProcess!.exitCode;
    print("Recording stopped.");
  } catch (e) {
    print("Error stopping recording: $e");
  }

  recorderProcess = null;
}
