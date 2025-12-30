import 'dart:io';

import 'package:auxtrack/helpers/api_controller.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

class PrototypeLogger {
  static final PrototypeLogger _instance = PrototypeLogger._internal();
  factory PrototypeLogger() => _instance;
  PrototypeLogger._internal();

  Future<String?> _buildLoggerPath() async {
    final appDataDir = await getApplicationSupportDirectory();
    final yearMonth = DateFormat('yyyyMM').format(DateTime.now());
    final userInfo = await ApiController.instance.loadUserInfo();
    if (userInfo == null) return null;
    final username = userInfo['username'];

    // ----------------------------------------------------)
    final loggerFolder = Directory(
      '${appDataDir.path}${Platform.pathSeparator}.cache${Platform.pathSeparator}logger${Platform.pathSeparator}$yearMonth${Platform.pathSeparator}$username${Platform.pathSeparator}',
    );

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

    final fileName = DateFormat('yyyyMMdd').format(now);
    final logFile = File('$logPath${Platform.pathSeparator}$fileName.txt');

    final buffer = StringBuffer();
    buffer.write('[$timestamp] $message');

    if (optional.isNotEmpty) {
      buffer.write(' | Optional: ${optional.join(', ')}');
    }

    buffer.writeln();
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

  Future<void> clearOldLogs({required String yearMonth}) async {
    final appDataDir = await getApplicationSupportDirectory();

    final monthFolder = Directory(
      '${appDataDir.path}${Platform.pathSeparator}.cache${Platform.pathSeparator}logger${Platform.pathSeparator}$yearMonth',
    );

    if (await monthFolder.exists()) {
      try {
        await monthFolder.delete(recursive: true);
        print('Deleted logs for $yearMonth');
      } catch (e) {
        print('Failed to delete logs for $yearMonth: $e');
      }
    } else {
      print('No logs found for $yearMonth');
    }
  }
}
