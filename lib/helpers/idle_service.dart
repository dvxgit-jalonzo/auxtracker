import 'dart:async';

import 'package:auxtrack/helpers/api_controller.dart';
import 'package:system_idle/system_idle.dart';

// Configuration class
class IdleServiceConfig {
  final bool enabled;
  final Duration idleThreshold;
  final Duration checkInterval;

  const IdleServiceConfig({
    this.enabled = true,
    this.idleThreshold = const Duration(seconds: 10),
    this.checkInterval = const Duration(seconds: 1),
  });

  IdleServiceConfig copyWith({
    bool? enabled,
    Duration? idleThreshold,
    Duration? checkInterval,
  }) {
    return IdleServiceConfig(
      enabled: enabled ?? this.enabled,
      idleThreshold: idleThreshold ?? this.idleThreshold,
      checkInterval: checkInterval ?? this.checkInterval,
    );
  }

  // For saving to SharedPreferences
  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'idleThresholdSeconds': idleThreshold.inSeconds,
    'checkIntervalSeconds': checkInterval.inSeconds,
  };

  // For loading from SharedPreferences
  factory IdleServiceConfig.fromJson(Map<String, dynamic> json) {
    return IdleServiceConfig(
      enabled: json['enabled'] ?? true,
      idleThreshold: Duration(seconds: json['idleThresholdSeconds'] ?? 10),
      checkInterval: Duration(seconds: json['checkIntervalSeconds'] ?? 1),
    );
  }
}

class IdleService {
  // Singleton pattern
  static final IdleService _instance = IdleService._internal();
  factory IdleService() => _instance;
  IdleService._internal() {
    // Initialize streams in constructor
    _idleStateController = StreamController<bool>.broadcast();
    _durationController = StreamController<Duration>.broadcast();
    _configController = StreamController<IdleServiceConfig>.broadcast();
  }

  static IdleService get instance => _instance;

  final plugin = SystemIdle.forPlatform();

  IdleServiceConfig _config = const IdleServiceConfig();
  IdleServiceConfig get config => _config;

  Duration? _currentIdleDuration;
  Duration? get currentIdleDuration => _currentIdleDuration;

  StreamSubscription<bool>? _idleSubscription;
  Timer? _durationCheckTimer;

  // Stream controllers - use late to allow recreation
  late StreamController<bool> _idleStateController;
  Stream<bool> get idleStateStream => _idleStateController.stream;

  late StreamController<Duration> _durationController;
  Stream<Duration> get durationStream => _durationController.stream;

  late StreamController<IdleServiceConfig> _configController;
  Stream<IdleServiceConfig> get configStream => _configController.stream;

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  /// Initialize the idle service with optional config
  Future<void> initialize([IdleServiceConfig? config]) async {
    if (config != null) {
      _config = config;
    }

    if (_isInitialized) {
      print('IdleService already initialized');
      return;
    }

    if (!_config.enabled) {
      print('IdleService is disabled');
      return;
    }

    try {
      await plugin.initialize();

      // Subscribe to idle state changes
      _idleSubscription = plugin
          .onIdleChanged(idleDuration: _config.idleThreshold)
          .listen(
        _onIdleChanged,
        onError: (error) {
          print('Idle subscription error: $error');
        },
      );

      // Periodically check idle duration
      _durationCheckTimer =
          Timer.periodic(_config.checkInterval, _checkDuration);

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
      print('🔔 Idle state detected: $isIdle');
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

  /// Update configuration
  Future<void> updateConfig(IdleServiceConfig newConfig) async {
    final oldConfig = _config;
    _config = newConfig;

    print('🔍 updateConfig - old: ${oldConfig.enabled}, new: ${newConfig.enabled}');

    // Notify listeners
    if (!_configController.isClosed) {
      _configController.add(_config);
    }

    // If enabled state changed
    if (oldConfig.enabled != newConfig.enabled) {
      if (newConfig.enabled) {
        print('✅ Enabling IdleService');
        await initialize();
      } else {
        print('❌ Disabling IdleService');
        await dispose();
      }
      return;
    }

    // If other settings changed and service is running
    if (_isInitialized &&
        (oldConfig.idleThreshold != newConfig.idleThreshold ||
            oldConfig.checkInterval != newConfig.checkInterval)) {
      print('🔄 Resetting IdleService with new settings');
      await reset();
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

    // Close old streams
    await _idleStateController.close();
    await _durationController.close();

    // ✅ CRITICAL: Recreate streams for next use
    _idleStateController = StreamController<bool>.broadcast();
    _durationController = StreamController<Duration>.broadcast();

    print('IdleService disposed and streams recreated');
  }

  /// Reset the service
  Future<void> reset() async {
    await dispose();
    await initialize();
  }

  /// Clean up all resources
  Future<void> cleanUp() async {
    await dispose();
    await _configController.close();
  }
}