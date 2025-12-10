import 'dart:async';

import 'package:auxtrack/helpers/api_controller.dart';
import 'package:system_idle/system_idle.dart';

class IdleService {
  // Singleton pattern
  static final IdleService _instance = IdleService._internal();
  factory IdleService() => _instance;
  IdleService._internal();

  // Or use a getter for cleaner access
  static IdleService get instance => _instance;

  final plugin = SystemIdle.forPlatform();

  Duration? _currentIdleDuration;
  Duration? get currentIdleDuration => _currentIdleDuration;

  StreamSubscription<bool>? _idleSubscription;
  Timer? _durationCheckTimer;

  // Stream controller to broadcast idle changes to multiple listeners
  final _idleStateController = StreamController<bool>.broadcast();
  Stream<bool> get idleStateStream => _idleStateController.stream;

  final _durationController = StreamController<Duration>.broadcast();

  bool _isInitialized = false;

  // Configuration
  static const Duration idleThreshold = Duration(seconds: 5);
  static const Duration checkInterval = Duration(seconds: 1);

  /// Initialize the idle service
  Future<void> initialize() async {
    if (_isInitialized) return;

    await plugin.initialize();

    // Subscribe to idle state changes
    _idleSubscription = plugin
        .onIdleChanged(idleDuration: idleThreshold)
        .listen(_onIdleChanged);

    // Periodically check idle duration
    _durationCheckTimer = Timer.periodic(checkInterval, _checkDuration);

    _isInitialized = true;
  }

  void _onIdleChanged(bool isIdle) {
    print('Idle state changed: $isIdle');
    _idleStateController.add(isIdle);
    ApiController.instance.createEmployeeIdle(isIdle);
  }

  Future<void> _checkDuration(Timer timer) async {
    try {
      final duration = await plugin.getIdleDuration();
      _currentIdleDuration = duration;
      _durationController.add(duration!);
    } catch (e) {
      print('Error checking idle duration: $e');
    }
  }

  /// Dispose of the service (call this when app is closing)
  void dispose() {
    _idleSubscription?.cancel();
    _durationCheckTimer?.cancel();
    _idleStateController.close();
    _durationController.close();
    _isInitialized = false;
  }

  /// Reset the service (useful for testing or reinitialization)
  void reset() {
    dispose();
    _isInitialized = false;
  }
}
