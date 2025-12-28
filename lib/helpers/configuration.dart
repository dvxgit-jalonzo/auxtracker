import 'dart:convert';

import 'package:flutter/services.dart';

class Configuration {
  Configuration._privateConstructor();

  static final Configuration instance = Configuration._privateConstructor();

  Map<String, dynamic>? _config;
  String? _activeEnvironment;
  bool _isLoaded = false;

  Future<void> _loadConfig() async {
    if (_isLoaded) return; // Already loaded

    try {
      final String configString = await rootBundle.loadString(
        'assets/config/configuration.json',
      );
      final Map<String, dynamic> fullConfig = json.decode(configString);

      // Get the active environment
      _activeEnvironment = fullConfig['active']?['environment'] ?? 'local';

      // Load only the active environment config
      _config = fullConfig[_activeEnvironment];

      if (_config == null) {
        print(
          'Warning: Active environment "$_activeEnvironment" not found in config',
        );
        _config = {};
      }

      _isLoaded = true;
    } catch (e) {
      print('Error loading config: $e');
      _config = {};
    }
  }

  Future<dynamic> get(String key) async {
    await _loadConfig(); // Load once if not loaded
    return _config?[key];
  }

  // Get the active environment name
  Future<String?> getActiveEnvironment() async {
    await _loadConfig();
    return _activeEnvironment;
  }

  // Optional: Initialize method to load config early
  Future<void> initialize() async {
    await _loadConfig();
  }
}
