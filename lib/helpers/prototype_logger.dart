import 'dart:io';

import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

class PrototypeLogger {
  String? _customFolder;

  // Constructor with optional logFolder parameter
  PrototypeLogger({String? logFolder}) : _customFolder = logFolder;

  // Still keep setFolder if needed to change later
  void setFolder(String folderName) {
    _customFolder = folderName;
  }

  // Clear custom folder
  void clearFolder() {
    _customFolder = null;
  }

  Future<String?> _buildLoggerPath() async {
    final appDataDir = await getApplicationSupportDirectory();
    final yearMonth = DateFormat('yyyyMM').format(DateTime.now());

    // Build path based on whether custom folder is set
    final pathParts = [
      appDataDir.path,
      '.cache',
      'logger',
      yearMonth,
      if (_customFolder != null) _customFolder!,
    ];

    final loggerFolder = Directory(pathParts.join(Platform.pathSeparator));

    if (!await loggerFolder.exists()) {
      await loggerFolder.create(recursive: true);
    }

    return loggerFolder.path;
  }

  Future<void> trail(
    dynamic message, [
    List<dynamic> optional = const [],
  ]) async {
    final now = DateTime.now();
    final timestamp = DateFormat('yyyy-MM-dd HH:mm:ss.SSS').format(now);
    final logPath = await _buildLoggerPath();

    if (logPath == null) return;

    // File name format: yyyyMMdd.txt
    final fileName = DateFormat('yyyyMMdd').format(now);
    final logFile = File('$logPath${Platform.pathSeparator}$fileName.txt');

    // Build log entry
    final buffer = StringBuffer();
    buffer.write('[$timestamp] $message');

    // Add optional parameters if provided
    if (optional.isNotEmpty) {
      buffer.write(' | Optional: ${optional.join(', ')}');
    }

    buffer.writeln();
    // Write to file (append mode)
    try {
      await logFile.writeAsString(
        buffer.toString(),
        mode: FileMode.append,
        flush: true,
      );
    } catch (e) {
      print('Logger error: $e');
    }
  }

  // Additional helper methods
  Future<void> error(dynamic message, [dynamic stackTrace]) async {
    await trail('ERROR: $message', stackTrace != null ? [stackTrace] : []);
  }

  Future<void> info(dynamic message) async {
    await trail('INFO: $message');
  }

  Future<void> debug(dynamic message) async {
    await trail('DEBUG: $message');
  }

  Future<void> warning(dynamic message) async {
    await trail('WARNING: $message');
  }

  Future<void> clearOldLogs({required String yearMonth, String? folder}) async {
    final appDataDir = await getApplicationSupportDirectory();

    final pathParts = [
      appDataDir.path,
      '.cache',
      'logger',
      yearMonth,
      if (folder != null) folder,
    ];

    final monthFolder = Directory(pathParts.join(Platform.pathSeparator));

    if (await monthFolder.exists()) {
      try {
        await monthFolder.delete(recursive: true);
        print('Deleted logs for $yearMonth${folder != null ? '/$folder' : ''}');
      } catch (e) {
        print('Failed to delete logs for $yearMonth: $e');
      }
    } else {
      print('No logs found for $yearMonth${folder != null ? '/$folder' : ''}');
    }
  }
}
