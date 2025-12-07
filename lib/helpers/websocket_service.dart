import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class WebSocketService {
  static final WebSocketService _instance = WebSocketService._internal();
  factory WebSocketService() => _instance;
  WebSocketService._internal();

  WebSocketChannel? _channel;
  bool _isConnected = false;
  bool get isConnected => _isConnected;
  String? _lastLogOutput;

  Timer? _reconnectTimer;
  bool _isManualDisconnect = false;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 5;
  static const Duration _reconnectDelay = Duration(seconds: 3);

  final _messageController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get messageStream => _messageController.stream;

  // Hardcoded connection details
  static const String _androidHost = "127.0.0.1:8080";
  static const String _reverbAppKey = "jl8hdc0f7s5s7xept132";

  Future<void> connect() async {
    if (_isConnected) {
      _logOnce("WS connected");
      return;
    }

    _isManualDisconnect = false;
    await _connect();
  }

  Future<void> _connect() async {
    try {
      debugPrint("Websocket Connecting...");

      _channel = IOWebSocketChannel.connect(
        Uri.parse(
          'ws://$_androidHost/app/$_reverbAppKey?protocol=7&client=js&version=4.4.0&flash=false',
        ),
      );

      // Subscribe to channels
      _channel!.sink.add(
        json.encode({
          "event": "pusher:subscribe",
          "data": {"channel": "personalBreakResponseEvent"},
        }),
      );

      _isConnected = true;
      _reconnectAttempts = 0;

      debugPrint("*********************************************************");
      debugPrint("***        Websocket connection established           ***");
      debugPrint("*********************************************************");

      _channel!.stream.listen(
        _onMessage,
        onError: _onError,
        onDone: _onDone,
        cancelOnError: false,
      );
    } catch (e) {
      debugPrint("WebSocket connection error: $e");
      _isConnected = false;
      _scheduleReconnect();
    }
  }

  void _onMessage(dynamic data) {
    try {
      Map<String, dynamic> jsonMap = jsonDecode(data);
      final String? event = jsonMap['event'];

      if (event == "pusher:ping") {
        final pongMessage = jsonEncode({'event': 'pusher:pong'});
        if (kDebugMode) {
          print("📥 ← $data");
          print("📤 → $pongMessage");
        }

        _channel!.sink.add(pongMessage);
        if (kDebugMode) {
          print("✅ pong sent");
        }
      } else if (event == "pusher:subscription_succeeded") {
        if (kDebugMode) {
          print("✅ Subscribed to channel: ${jsonMap['channel']}");
        }
      } else {
        // Log the full message for debugging
        if (kDebugMode) {
          print("📨 Event: $event");
          print("📦 Full data: $data");
        }

        // Extract the actual event data
        if (jsonMap.containsKey('data')) {
          final eventData = jsonMap['data'];
          final parsedData = eventData is String
              ? jsonDecode(eventData)
              : eventData;

          if (kDebugMode) {
            print("📋 Parsed data: $parsedData");
          }

          // Add to stream with event name and data
          _messageController.add({
            'event': event,
            'channel': jsonMap['channel'],
            'data': parsedData,
          });
        } else {
          _messageController.add(jsonMap);
        }
      }
    } catch (e) {
      debugPrint("Error processing message: $e");
    }
  }

  void _onError(error) {
    debugPrint("WebSocket error: $error");
    _isConnected = false;
    _scheduleReconnect();
  }

  void _onDone() {
    debugPrint("WebSocket connection closed");
    _isConnected = false;

    if (!_isManualDisconnect) {
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    if (_isManualDisconnect || _reconnectAttempts >= _maxReconnectAttempts) {
      debugPrint(
        _isManualDisconnect
            ? "Manual disconnect - not reconnecting"
            : "Max reconnect attempts reached",
      );
      return;
    }

    _reconnectTimer?.cancel();
    _reconnectAttempts++;

    final delay = _reconnectDelay * _reconnectAttempts;
    debugPrint(
      'Reconnecting in ${delay.inSeconds}s (attempt $_reconnectAttempts/$_maxReconnectAttempts)',
    );

    _reconnectTimer = Timer(delay, () {
      if (!_isManualDisconnect) {
        _connect();
      }
    });
  }

  void _logOnce(String message) {
    if (_lastLogOutput != message) {
      debugPrint(message);
      _lastLogOutput = message;
    }
  }

  void send(Map<String, dynamic> message) {
    if (!_isConnected) {
      debugPrint("Cannot send message: WebSocket not connected");
      return;
    }

    try {
      final data = jsonEncode(message);
      _channel?.sink.add(data);
      if (kDebugMode) {
        print("📤 Sent: $data");
      }
    } catch (e) {
      debugPrint("Error sending message: $e");
    }
  }

  void disconnect() {
    debugPrint("Manually disconnecting WebSocket");
    _isManualDisconnect = true;
    _reconnectTimer?.cancel();
    _channel?.sink.close();
    _isConnected = false;
    _lastLogOutput = null;
  }

  void dispose() {
    disconnect();
    _messageController.close();
  }
}
