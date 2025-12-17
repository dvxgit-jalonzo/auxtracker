import 'dart:convert';

import 'package:auxtrack/helpers/configuration.dart';
import 'package:auxtrack/helpers/periodic_capture_controller.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'idle_service.dart';

class ApiController {
  // Singleton pattern
  ApiController._privateConstructor();
  static final ApiController instance = ApiController._privateConstructor();

  String? _accessToken;

  /// Load token from SharedPreferences
  Future<void> _loadToken() async {
    if (_accessToken != null) return;
    final prefs = await SharedPreferences.getInstance();
    _accessToken = prefs.getString('accessToken');
  }

  /// Save token to SharedPreferences
  Future<void> _saveToken(String token) async {
    _accessToken = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('accessToken', token);
  }

  Future<void> getReverbAppKey() async {
    try {
      final host = await Configuration.instance.get("baseUrl");
      final headers = await _headers();

      final url = Uri.parse("$host/get-reverb-key");
      final response = await http.get(url, headers: headers);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('reverbAppKey', jsonEncode(data));
        print(
          'Reverb App Key fetched and saved to local storage successfully.',
        );
      } else {
        print(
          'Failed to fetch Reverb: ${response.statusCode} - ${response.body}',
        );
        throw Exception('Failed to fetch Reverb');
      }
    } catch (e) {
      final message = e.toString();
      print(message);
      rethrow;
    }
  }

  Future<void> getAuxiliaries() async {
    try {
      final baseUrl = await Configuration.instance.get("baseUrl");
      final userInfo = await loadUserInfo();

      if (userInfo == null || userInfo['id'] == null) {
        throw Exception(
          'getAuxiliaries: User info not found. Please login first.',
        );
      }

      final headers = await _headers();
      final employeeId = userInfo['id'];
      final siteId = userInfo['site_id'];

      final base = Uri.parse(baseUrl);

      final protocol = base.scheme; // http or https
      final host = base.host; // domain or IP
      final port = base.hasPort ? base.port : null;
      print(base);
      print(protocol);
      print(host);
      print(port);

      final params = {
        "employee_id": employeeId.toString(),
        "site_id": siteId.toString(),
      };

      // Build the GET URL
      Uri url = protocol == "https"
          ? Uri.https(host, '/api/get-auxiliaries', params)
          : Uri.http(host, '/api/get-auxiliaries', params);

      if (port != null) {
        url = url.replace(port: port);
      }

      // Send GET request
      final response = await http.get(url, headers: headers);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('auxiliaries', jsonEncode(data));

        print("Auxiliaries saved!");
      } else {
        print("Error getting auxiliaries: ${response.statusCode}");
      }
    } catch (e) {
      print("Error getting auxiliaries: $e");
    }
  }

  /// Login using username and password
  Future login(String username, String password) async {
    try {
      final baseUrl = await Configuration.instance.get("baseUrl");
      final url = Uri.parse("$baseUrl/login");
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'username': username, 'password': password}),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        await _saveToken(data['access_token']);
        await getReverbAppKey();
        final successfullyGetUserInfo = await getUserInfo();
        if (!successfullyGetUserInfo) return false;
        await getAuxiliaries();
        return true;
      } else {
        print('Login failed: ${response.statusCode} - ${response.body}');
        return false;
      }
    } catch (e) {
      print('Error during login: $e');
      return false;
    }
    return false;
  }

  /// Common headers with authorization
  Future<Map<String, String>> _headers() async {
    await _loadToken();
    if (_accessToken == null) {
      throw Exception('Access token not found.');
    }
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $_accessToken',
    };
  }

  Future<void> logoutAndClear() async {
    try {
      // 1. Clear SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      ApiController.instance.clearToken();

      print("All local storage cleared. Background service stopped.");
    } catch (e) {
      print("Error clearing app data: $e");
    }
  }

  void clearToken() {
    _accessToken = null;
  }


  /// Create employee log
  Future<dynamic> createEmployeeLog(String sub) async {
    try {
      final baseUrl = await Configuration.instance.get("baseUrl");
      final userInfo = await loadUserInfo();
      if (userInfo == null || userInfo['id'] == null) {
        throw Exception(
          'create employee log User info not found. Please login first.',
        );
      }
      final headers = await _headers();
      final employeeId = userInfo['id'];
      final url = Uri.parse('$baseUrl/create-employee-log');

      final response = await http.post(
        url,
        headers: headers,
        body: jsonEncode({"employee_id": employeeId, "sub": sub}),
      );
      final result = jsonDecode(response.body);

      // ✅ Check result code first!
      if (result['code'] == 200) {

        final enabledStates = ["On Shift", "Calling", "SMS", "Lunch OT"];

        final capturer = PeriodicCaptureController();

        if (enabledStates.contains(sub)) {
          print('✅ Enabling idle detection for: $sub');
          await IdleService.instance.updateConfig(
            IdleService.instance.config.copyWith(enabled: true),
          );
          if (userInfo['enable_screen_capture'] == 1) {
            capturer.startCapturing();
          }
        } else {
          // Time In, Break, Lunch, Meeting, etc. - DISABLE
          print('❌ Disabling idle detection for: $sub');
          await IdleService.instance.updateConfig(
            IdleService.instance.config.copyWith(enabled: false),
          );
          if (userInfo['enable_screen_capture'] == 1) {
            capturer.startCapturing();
          }
        }
      }

      return result;
    } catch (e) {
      print('Error creating employee log: $e');
      rethrow;
    }
  }

  Future<bool> createPersonalBreak(String reason) async {
    try {
      final baseUrl = await Configuration.instance.get("baseUrl");
      final headers = await _headers();
      final userInfo = await loadUserInfo();
      if (userInfo == null || userInfo['id'] == null) {
        throw Exception(
          'create personal break User info not found. Please login first.',
        );
      }
      final employeeId = userInfo['id'];
      final siteId = userInfo['site_id'];
      final url = Uri.parse('$baseUrl/create-personal-break');

      Map<String, dynamic> params = {
        "site_id": siteId,
        "employee_id": employeeId,
        "reason": reason,
      };

      final response = await http.post(
        url,
        headers: headers,
        body: jsonEncode(params),
      );

      if (response.statusCode != 200) {
        print(
          'Failed to create personal break. Status: ${response.statusCode}, Body: ${response.body}',
        );
      }
      print('Personal break created successfully.');
      return true;
    } catch (e) {
      print('Error creating personal break: $e');
      return false;
    }
  }

  /// Update employee idle status
  Future<void> createEmployeeIdle(bool isIdle) async {
    try {
      final baseUrl = await Configuration.instance.get("baseUrl");
      final headers = await _headers();
      final idleStatus = isIdle ? "1" : "0";
      final userInfo = await loadUserInfo();

      if (userInfo == null || userInfo['id'] == null) {
        throw Exception(
          'create employee idle User info not found. Please login first.',
        );
      }
      final employeeId = userInfo['id'];
      final siteId = userInfo['site_id'];
      final timezone = userInfo['timezone'];
      final url = Uri.parse('$baseUrl/create-employee-idle');
      final response = await http.post(
        url,
        headers: headers,
        body: jsonEncode({
          'employee_id': employeeId,
          'site_id': siteId,
          'timezone': timezone,
          'status': idleStatus,
        }),
      );

      if (response.statusCode == 200) {
        print('Employee idle status updated to $isIdle successfully.');
      } else {
        print(
          'Failed to update idle status. Status: ${response.statusCode}, Body: ${response.body}',
        );
      }
    } catch (e) {
      print('Error updating employee idle: $e');
    }
  }

  /// Save user info to SharedPreferences
  Future<void> _saveUserInfo(Map<String, dynamic> userInfo) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('userInfo', jsonEncode(userInfo));
  }

  /// Load user info from SharedPreferences
  Future<Map<String, dynamic>?> loadUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    final userInfoString = prefs.getString('userInfo');
    if (userInfoString != null) {
      return jsonDecode(userInfoString);
    }
    return null;
  }

  Future<Map<String, dynamic>?> loadReverbAppKey() async {
    final prefs = await SharedPreferences.getInstance();
    final revertAppKey = prefs.getString('reverbAppKey');
    if (revertAppKey != null) {
      return jsonDecode(revertAppKey);
    }
    return null;
  }

  /// Get user info from API and save to localStorage (no return)
  Future<bool> getUserInfo() async {
    try {
      final baseUrl = await Configuration.instance.get("baseUrl");
      final headers = await _headers();
      final url = Uri.parse('$baseUrl/me');
      final response = await http.get(url, headers: headers);

      if (response.statusCode == 200) {
        print('User info fetched successfully.');
        final userInfo = jsonDecode(response.body);
        await _saveUserInfo(userInfo); // Save to localStorage
        return true;
      } else {
        print('Failed to fetch user info: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('Error fetching user info: $e');
      return false;
    }
  }

  Future<String> confirmCredential(String username, String password) async {
    final baseUrl = await Configuration.instance.get("baseUrl");
    final headers = await _headers();

    final uri = Uri.parse("$baseUrl/confirm-credentials");
    final params = {"username": username, "password": password};

    final response = await http.post(
      uri,
      headers: headers,
      body: jsonEncode(params),
    );
    return response.body;
  }

  /// Logout
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    _accessToken = null;
    print('Logged out.');
  }
}
