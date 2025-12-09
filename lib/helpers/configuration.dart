import 'dart:convert';
import 'package:flutter/services.dart';

class Configuration {
  Configuration._privateConstructor();

  static final Configuration instance = Configuration._privateConstructor();

  Map<String, dynamic>? _config;
  bool _isLoaded = false;

  Future<void> _loadConfig() async {
    if (_isLoaded) return; // Already loaded

    try {
      final String configString = await rootBundle.loadString('assets/config/configuration.json');
      _config = json.decode(configString);
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

  // Optional: Initialize method to load config early
  Future<void> initialize() async {
    await _loadConfig();
  }
}