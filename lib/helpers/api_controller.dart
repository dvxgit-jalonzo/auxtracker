import 'dart:convert';

import 'package:auxtrack/app_navigator.dart';
import 'package:auxtrack/helpers/configuration.dart';
import 'package:auxtrack/helpers/custom_notification.dart';
import 'package:auxtrack/helpers/idle_service.dart';
import 'package:auxtrack/helpers/periodic_capture_controller.dart';
import 'package:auxtrack/helpers/prototype_logger.dart';
import 'package:auxtrack/helpers/window_modes.dart';
import 'package:auxtrack/main.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiController {
  // Singleton pattern
  ApiController._privateConstructor();
  static final ApiController instance = ApiController._privateConstructor();

  String? _accessToken;

  void _displayHostInfo(Uri base) {
    print(base.toString());
    print(base.scheme);
    print(base.host);
    print(base.hasPort ? base.port : null);
  }

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
    final host = await Configuration.instance.get("baseUrl");
    final headers = await _headers();
    final url = Uri.parse("$host/get-reverb-key");

    try {
      final response = await http.get(url, headers: headers);

      // Check if the content is actually JSON
      final status = jsonDecode(response.body);

      if (response.statusCode == 200) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('reverbAppKey', status['key']);
      } else {
        throw Exception(status['message']);
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> getAuxiliaries() async {
    try {
      final baseUrl = await Configuration.instance.get("baseUrl");
      final userInfo = await loadUserInfo();

      if (userInfo == null) {
        throw Exception('User info not found.');
      }

      final headers = await _headers();
      final employeeId = userInfo['id'];
      final siteId = userInfo['site_id'];

      final base = Uri.parse(baseUrl);

      final protocol = base.scheme;
      final host = base.host;
      final port = base.hasPort ? base.port : null;
      _displayHostInfo(base);

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
      final status = jsonDecode(response.body);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('auxiliaries', jsonEncode(data));
      } else {
        throw Exception(status['message']);
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> checkActiveSchedule() async {
    try {
      final userInfo = await loadUserInfo();
      final headers = await _headers();
      final baseUrl = await Configuration.instance.get("baseUrl");
      final url = Uri.parse("$baseUrl/check-active-schedule");

      //
      final response = await http.post(
        url,
        headers: headers,
        body: jsonEncode({'employee_id': userInfo?['id']}),
      );

      //
      final result = jsonDecode(response.body);

      final logger = PrototypeLogger(
        logFolder: userInfo?['username'].toString().toLowerCase(),
      );
      logger.trail("[${result['code']}] have a schedule: ${result['message']}");

      if (response.statusCode != 200) {
        throw Exception(result['message']);
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Login using username and password
  Future<void> login(String username, String password) async {
    try {
      final baseUrl = await Configuration.instance.get("baseUrl");
      final url = Uri.parse("$baseUrl/login");
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'username': username, 'password': password}),
      );

      final status = jsonDecode(response.body);
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        await _saveToken(data['access_token']);
        await getUserInfo();
        await getAuxiliaries();
        await getReverbAppKey();
        await checkActiveSchedule();
      } else {
        throw Exception(status['message']);
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Common headers with authorization
  Future<Map<String, String>> _headers() async {
    await _loadToken();
    if (_accessToken == null) {
      throw Exception('Access token not found.');
    }
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
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
  Future<Map<String, dynamic>> createEmployeeLog(String sub) async {
    try {
      final baseUrl = await Configuration.instance.get("baseUrl");
      final userInfo = await loadUserInfo();

      if (userInfo == null) {
        throw Exception('User info not found.');
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

      print("CreateEmployeeLogResult : $result");
      final enabledStates = ["On Shift", "Calling", "SMS", "Lunch OT"];

      if (enabledStates.contains(sub)) {
        print('✅ Enabling idle detection for: $sub');
        await IdleService.instance.updateConfig(
          IdleService.instance.config.copyWith(enabled: true),
        );
      } else {
        print('❌ Disabling idle detection for: $sub');
        await IdleService.instance.updateConfig(
          IdleService.instance.config.copyWith(enabled: false),
        );
      }

      final capturer = PeriodicCaptureController();
      if (userInfo['enable_screen_capture'] == 1) {
        capturer.startCapturing();
      }

      return result;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> forceLogout() async {
    await ApiController.instance.logout();
    await WindowModes.normal();
    navigatorKey.currentState?.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (_) => false,
    );
  }

  Future<dynamic> getLatestEmployeeLog() async {
    // get-employee-last-aux
    try {
      final baseUrl = await Configuration.instance.get("baseUrl");
      final userInfo = await loadUserInfo();

      if (userInfo == null) {
        throw Exception('getLatestEmployeeLog: User info not found.');
      }

      final headers = await _headers();
      final employeeId = userInfo['id'];
      final siteId = userInfo['site_id'];

      final base = Uri.parse(baseUrl);

      final protocol = base.scheme;
      final host = base.host;
      final port = base.hasPort ? base.port : null;
      _displayHostInfo(base);

      final params = {
        "employee_id": employeeId.toString(),
        "site_id": siteId.toString(),
      };

      // Build the GET URL
      Uri url = protocol == "https"
          ? Uri.https(host, '/api/get-employee-last-aux', params)
          : Uri.http(host, '/api/get-employee-last-aux', params);

      if (port != null) {
        url = url.replace(port: port);
      }

      // Send GET request
      final response = await http.get(url, headers: headers);

      //
      final result = jsonDecode(response.body);

      return result;
    } catch (e) {
      CustomNotification.error("Error getting last aux");
    }
  }

  Future<bool> deletePersonalBreak() async {
    try {
      final baseUrl = await Configuration.instance.get("baseUrl");
      final headers = await _headers();
      final userInfo = await loadUserInfo();

      if (userInfo == null) {
        print('User info not found.');
        return false;
      }

      final employeeId = userInfo['id'];
      final siteId = userInfo['site_id'];
      final url = Uri.parse('$baseUrl/delete-personal-break');

      Map<String, dynamic> params = {
        "site_id": siteId,
        "employee_id": employeeId,
      };

      final response = await http.post(
        url,
        headers: headers,
        body: jsonEncode(params),
      );

      if (response.statusCode == 200) {
        // I-decode ang response (true/false na galing sa Laravel)
        final bool isDeleted = jsonDecode(response.body);

        if (isDeleted) {
          print('Personal break record actually removed from DB.');
          return true;
        } else {
          print('No pending break found to delete.');
          return false;
        }
      } else {
        print('Server Error: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      CustomNotification.error("Error deleting personal break");
      await forceLogout();
      return false;
    }
  }

  Future<bool> deleteOvertime() async {
    try {
      final baseUrl = await Configuration.instance.get("baseUrl");
      final headers = await _headers();
      final userInfo = await loadUserInfo();

      if (userInfo == null) {
        print('User info not found.');
        return false;
      }

      final employeeId = userInfo['id'];
      final siteId = userInfo['site_id'];
      final url = Uri.parse('$baseUrl/delete-overtime');

      Map<String, dynamic> params = {
        "site_id": siteId,
        "employee_id": employeeId,
      };

      final response = await http.post(
        url,
        headers: headers,
        body: jsonEncode(params),
      );

      if (response.statusCode == 200) {
        // I-decode ang response (true/false na galing sa Laravel)
        final bool isDeleted = jsonDecode(response.body);

        if (isDeleted) {
          print('Overtime record actually removed from DB.');
          return true;
        } else {
          print('No pending overtime found to delete.');
          return false;
        }
      } else {
        print('Server Error: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      CustomNotification.error("Error deleting overtime");
      await forceLogout();
      return false;
    }
  }

  Future<bool> createOvertimeRequest(String sub) async {
    try {
      final baseUrl = await Configuration.instance.get("baseUrl");
      final headers = await _headers();
      final userInfo = await loadUserInfo();

      if (userInfo == null) {
        print('Error: User info not found.');
        return false;
      }

      final employeeId = userInfo['id'];
      final url = Uri.parse('$baseUrl/create-overtime');

      Map<String, dynamic> params = {"employee_id": employeeId, "sub": sub};

      final response = await http.post(
        url,
        headers: headers,
        body: jsonEncode(params),
      );

      if (response.statusCode == 200) {
        final bool isCreated = jsonDecode(response.body);

        if (isCreated) {
          print('Overtime created successfully.');
          return true;
        } else {
          print(
            'Request denied: Employee might already have a pending overtime.',
          );
          return false;
        }
      } else {
        print('Failed to connect. Status: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      CustomNotification.error("Error creating personal break");
      await forceLogout();
      return false;
    }
  }

  Future<bool> createPersonalBreak(String reason) async {
    try {
      final baseUrl = await Configuration.instance.get("baseUrl");
      final headers = await _headers();
      final userInfo = await loadUserInfo();

      if (userInfo == null) {
        print('Error: User info not found.');
        return false;
      }

      final employeeId = userInfo['id'];
      final url = Uri.parse('$baseUrl/create-personal-break');

      Map<String, dynamic> params = {
        "employee_id": employeeId,
        "reason": reason,
      };

      final response = await http.post(
        url,
        headers: headers,
        body: jsonEncode(params),
      );

      if (response.statusCode == 200) {
        final bool isCreated = jsonDecode(response.body);

        if (isCreated) {
          print('Personal break created successfully.');
          return true;
        } else {
          print('Request denied: Employee might already have a pending break.');
          return false;
        }
      } else {
        print('Failed to connect. Status: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      CustomNotification.error("Error creating personal break");
      await forceLogout();
      return false;
    }
  }

  /// Update employee idle status
  Future<void> createEmployeeIdle(bool isIdle) async {
    final baseUrl = await Configuration.instance.get("baseUrl");
    final headers = await _headers();
    final idleStatus = isIdle ? "1" : "0";
    final userInfo = await loadUserInfo();

    if (userInfo == null) {
      throw Exception('create employee idle User info not found.');
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

  Future<String?> loadReverbAppKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('reverbAppKey');
  }

  /// Get user info from API and save to localStorage (no return)
  Future<void> getUserInfo() async {
    try {
      final baseUrl = await Configuration.instance.get("baseUrl");
      final headers = await _headers();
      final url = Uri.parse('$baseUrl/me');
      final response = await http.get(url, headers: headers);
      final status = jsonDecode(response.body);
      if (response.statusCode == 200) {
        print('User info fetched successfully.');
        final userInfo = jsonDecode(response.body);
        await _saveUserInfo(userInfo);
      } else {
        throw Exception(status['message']);
      }
    } catch (e) {
      rethrow;
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
    print('Clearing cache.');
  }
}
