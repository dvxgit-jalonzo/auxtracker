import 'dart:io';

Process? recorderProcess;
final outputPath = '${Directory.current.path}\\recorded.mp4';

String get ffmpegPath {
  final exeDir = Directory.current.path;
  return '$exeDir/windows/ffmpeg/ffmpeg.exe';
}

Future<void> startRecording() async {
  final path = ffmpegPath;
  print(path);
  recorderProcess = await Process.start(path, [
    '-y',
    '-f', 'gdigrab',
    '-framerate', '30',
    '-i', 'desktop',
    '-vcodec', 'libx264', // Use H.264 codec
    '-preset', 'veryfast', // Balance speed vs compression
    '-crf', '28', // Lower CRF = higher quality, higher storage
    '-pix_fmt', 'yuv420p',
    outputPath,
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
