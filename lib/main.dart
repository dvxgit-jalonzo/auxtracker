import 'dart:io';

import 'package:auto_updater/auto_updater.dart';
import 'package:auxtrack/helpers/custom_notification.dart';
import 'package:auxtrack/helpers/window_modes.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';

import 'app_navigator.dart';
import 'change_aux_page.dart';
import 'helpers/api_controller.dart';
import 'helpers/configuration.dart';
import 'helpers/http_overrides.dart';

bool updateChecker = false;
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Platform.isWindows) {
    String feedURL = await Configuration.instance.get("updater");

    await autoUpdater.setFeedURL(feedURL);
    await autoUpdater.setScheduledCheckInterval(3600);
    await autoUpdater.checkForUpdates(inBackground: true);
    updateChecker = true;
  }

  HttpOverrides.global = MyHttpOverrides();
  await WindowModes.normal();
  runApp(const MyApp());
}

Future<void> _initUpdater() async {
  if (Platform.isWindows) {
    try {
      String feedURL = await Configuration.instance.get("updater");
      await autoUpdater.setFeedURL(feedURL);
      await autoUpdater.setScheduledCheckInterval(3600);

      // Some versions of the plugin handle the thread better
      // if called slightly after startup.
      Future.delayed(const Duration(seconds: 3), () {
        autoUpdater.checkForUpdates(inBackground: true);
        updateChecker = true;
      });
    } catch (e) {
      print("Updater Error: $e");
    }
  }
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      home: const LoginPage(),
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with WindowListener {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  // final _usernameController = TextEditingController(text: "admin");
  // final _passwordController = TextEditingController(text: "admin123");
  bool _isPasswordVisible = false;
  bool _isLoading = false;
  String _version = "";
  String _buildNumber = "";

  @override
  void initState() {
    super.initState();
    _getAppVersion();
    windowManager.addListener(this);
    _checkUpdate();
  }

  Future<void> _checkUpdate() async {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (updateChecker == true) {
        CustomNotification.success("Checking for updates has completed.");
      } else {
        CustomNotification.warning("Please reload the app.");
      }
    });
  }

  void _getAppVersion() async {
    PackageInfo packageInfo = await PackageInfo.fromPlatform();
    setState(() {
      _version = packageInfo.version; // Pulls '1.0.0' from pubspec
      _buildNumber = packageInfo.buildNumber; // Pulls '+1' from pubspec
    });
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _handleLogin() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      try {
        final username = _usernameController.text;
        final password = _passwordController.text;

        final success = await ApiController.instance.login(username, password);
        setState(() => _isLoading = false);

        if (success) {
          if (mounted) {
            final prefs = await SharedPreferences.getInstance();

            final accessToken = prefs.getString("accessToken");
            if (accessToken != null && accessToken.isNotEmpty) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const ChangeAuxPage()),
              );
            } else {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const LoginPage()),
              );
            }
          }
        } else {
          if (mounted) {
            CustomNotification.error("Invalid username or password");
            await Future.delayed(Duration(seconds: 4));
            CustomNotification.error(
              "The user must have site.",
              title: "Site Error",
            );
          }
        }
      } catch (e) {
        setState(() => _isLoading = false);

        if (mounted) {
          print(e.toString());
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Connection error: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.green.shade700, Colors.deepPurple.shade900],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(
                left: 24,
                right: 24,
                bottom: 24,
                top: 5,
              ),
              child: KeyboardListener(
                focusNode: FocusNode(),
                onKeyEvent: (event) {
                  if (event.logicalKey == LogicalKeyboardKey.enter &&
                      !_isLoading) {
                    _handleLogin();
                  }
                },
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // App Icon/Logo
                      ClipOval(
                        child: Image.asset(
                          'assets/images/icon.png',
                          width: 74,
                          height: 74,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(height: 15),

                      // Username Field
                      TextFormField(
                        controller: _usernameController,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Username',
                          labelStyle: const TextStyle(color: Colors.white70),
                          prefixIcon: const Icon(
                            Icons.person_outline,
                            color: Colors.white70,
                          ),
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.1),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: Colors.white.withOpacity(0.3),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Colors.white,
                              width: 2,
                            ),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your username';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Password Field
                      TextFormField(
                        controller: _passwordController,
                        obscureText: !_isPasswordVisible,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Password',
                          labelStyle: const TextStyle(color: Colors.white70),
                          prefixIcon: const Icon(
                            Icons.lock_outline,
                            color: Colors.white70,
                          ),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _isPasswordVisible
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                              color: Colors.white70,
                            ),
                            onPressed: () {
                              setState(
                                () => _isPasswordVisible = !_isPasswordVisible,
                              );
                            },
                          ),
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.1),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: Colors.white.withOpacity(0.3),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Colors.white,
                              width: 2,
                            ),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your password';
                          }
                          if (value.length < 6) {
                            return 'Password must be at least 6 characters';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),
                      // Login Button
                      SizedBox(
                        width: double.infinity,
                        height: 40,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _handleLogin,
                          style: ButtonStyle(
                            padding: MaterialStateProperty.all(
                              const EdgeInsets.symmetric(
                                vertical: 14,
                                horizontal: 24,
                              ),
                            ),
                            shape: MaterialStateProperty.all(
                              RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            elevation: MaterialStateProperty.all(6),
                            backgroundColor:
                                MaterialStateProperty.resolveWith<Color>((
                                  states,
                                ) {
                                  if (states.contains(MaterialState.disabled)) {
                                    return Colors.blue.shade300;
                                  }
                                  return Colors.blue.shade900;
                                }),
                            shadowColor: MaterialStateProperty.all(
                              Colors.deepPurpleAccent.withOpacity(0.4),
                            ),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  height: 24,
                                  width: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 3,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  ),
                                )
                              : const Text(
                                  'Login',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        "Version: $_version (Build: $_buildNumber)",
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
