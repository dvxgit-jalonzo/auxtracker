import 'dart:async';

import 'package:auxtrack/helpers/api_controller.dart';
import 'package:system_idle/system_idle.dart';

class IdleService {
  // Singleton pattern
  static final IdleService _instance = IdleService._internal();
  factory IdleService() => _instance;
  IdleService._internal();

  static IdleService get instance => _instance;

  final plugin = SystemIdle.forPlatform();

  Duration? _currentIdleDuration;
  Duration? get currentIdleDuration => _currentIdleDuration;

  StreamSubscription<bool>? _idleSubscription;
  Timer? _durationCheckTimer;

  // Stream controllers
  final _idleStateController = StreamController<bool>.broadcast();
  Stream<bool> get idleStateStream => _idleStateController.stream;

  final _durationController = StreamController<Duration>.broadcast();
  Stream<Duration> get durationStream => _durationController.stream;

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  // Configuration
  static const Duration idleThreshold = Duration(seconds: 10);
  static const Duration checkInterval = Duration(seconds: 1);

  /// Initialize the idle service
  Future<void> initialize() async {
    if (_isInitialized) {
      print('IdleService already initialized');
      return;
    }

    try {
      await plugin.initialize();

      // Subscribe to idle state changes
      _idleSubscription = plugin
          .onIdleChanged(idleDuration: idleThreshold)
          .listen(
            _onIdleChanged,
            onError: (error) {
              print('Idle subscription error: $error');
            },
          );

      // Periodically check idle duration
      _durationCheckTimer = Timer.periodic(checkInterval, _checkDuration);

      _isInitialized = true;
      print('IdleService initialized successfully');
    } catch (e) {
      print('Failed to initialize IdleService: $e');
      rethrow;
    }
  }

  Future<void> _onIdleChanged(bool isIdle) async {
    if (!_isInitialized || _idleStateController.isClosed) return;

    try {
      await ApiController.instance.createEmployeeIdle(isIdle);

      if (!_idleStateController.isClosed) {
        _idleStateController.add(isIdle);
      }
    } catch (e) {
      print('Error handling idle state change: $e');
    }
  }

  Future<void> _checkDuration(Timer timer) async {
    if (!_isInitialized || _durationController.isClosed) return;

    try {
      final duration = await plugin.getIdleDuration();

      if (duration != null) {
        _currentIdleDuration = duration;

        if (!_durationController.isClosed) {
          _durationController.add(duration);
        }
      }
    } catch (e) {
      print('Error checking idle duration: $e');
    }
  }

  /// Dispose of the service
  Future<void> dispose() async {
    if (!_isInitialized) return;

    _isInitialized = false;

    await _idleSubscription?.cancel();
    _idleSubscription = null;

    _durationCheckTimer?.cancel();
    _durationCheckTimer = null;

    await _idleStateController.close();
    await _durationController.close();

    print('IdleService disposed');
  }

  /// Reset the service
  Future<void> reset() async {
    await dispose();
    await initialize();
  }
}
