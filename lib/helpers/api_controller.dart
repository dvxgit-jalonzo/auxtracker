import 'dart:convert';

import 'package:auxtrack/helpers/configuration.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

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
      final host = await Configuration.instance.get("host");
      final headers = await _headers();

      final url = Uri.http(host, '/api/get-reverb-key');
      final response = await http.get(url, headers: headers);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('reverbAppKey', jsonEncode(data));
        print('Reverb App Key fetched and saved to local storage successfully.');
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
      final host = await Configuration.instance.get("host");
      // Get site_id from saved user info
      final userInfo = await loadUserInfo();

      if (userInfo == null || userInfo['site_id'] == null) {
        throw Exception(
          'get auxiliaries User info not found. Please login first.',
        );
      }
      final siteId = userInfo['site_id'].toString();

      Map<String, dynamic> params = {"site_id": siteId};

      final headers = await _headers();

      final url = Uri.http(host, '/api/get-auxiliaries', params);
      final response = await http.get(url, headers: headers);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('auxiliaries', jsonEncode(data));
        print('Auxiliaries fetched and saved to local storage successfully.');
      } else {
        print(
          'Failed to fetch auxiliaries: ${response.statusCode} - ${response.body}',
        );
        throw Exception('Failed to fetch auxiliaries');
      }
    } catch (e) {
      final message = e.toString();
      print(message);
      rethrow;
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
        await getUserInfo();
        await getAuxiliaries();
        return true;
      } else {
        print('Login failed: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('Error during login: $e');
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
  Future<bool> createEmployeeLog(String sub) async {
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

      if (response.statusCode == 200) {
        print('Employee log created successfully.');
        return true;
      } else {
        print(
          'Failed to create employee log. Status: ${response.statusCode}, Body: ${response.body}',
        );
        return false;
      }
    } catch (e) {
      print('Error creating employee log: $e');
      return false;
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
      final url = Uri.parse('$baseUrl/create-employee-idle');
      final response = await http.post(
        url,
        headers: headers,
        body: jsonEncode({'employee_id': employeeId, 'status': idleStatus}),
      );

      if (response.statusCode == 200) {
        print('Employee idle status updated successfully.');
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
  Future<void> getUserInfo() async {
    try {
      final baseUrl = await Configuration.instance.get("baseUrl");
      final headers = await _headers();
      final url = Uri.parse('$baseUrl/me');
      final response = await http.get(url, headers: headers);
      if (response.statusCode == 200) {
        print('User info fetched successfully.');
        final userInfo = jsonDecode(response.body);
        await _saveUserInfo(userInfo); // Save to localStorage
      } else {
        print('Failed to fetch user info: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching user info: $e');
    }
  }

  /// Logout
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    _accessToken = null;
    print('Logged out.');
  }
}
