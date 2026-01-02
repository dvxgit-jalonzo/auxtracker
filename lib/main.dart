import 'dart:io';

import 'package:auxtrack/helpers/custom_notification.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_single_instance/flutter_single_instance.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';

import 'app_navigator.dart';
import 'bootstrap_app.dart';
import 'change_aux_page.dart';
import 'helpers/api_controller.dart';
import 'helpers/http_overrides.dart';
import 'helpers/window_modes.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await windowManager.ensureInitialized();

  if (!await FlutterSingleInstance().isFirstInstance()) {
    print("App is already running");

    final err = await FlutterSingleInstance().focus();

    if (err != null) {
      print("Error focusing running instance: $err");
    }
    exit(0);
  }

  FlutterSingleInstance.onFocus = (metadata) async {
    print("Another instance attempted to open");
    await windowManager.show();
    await windowManager.focus();
  };

  // if (Platform.isWindows) {
  //   String feedURL = await Configuration.instance.get("updater");
  //
  //   await autoUpdater.setFeedURL(feedURL);
  //   await autoUpdater.setScheduledCheckInterval(3600);
  //
  //   autoUpdater.addListener(AppUpdaterListener(updateGate));
  //   await Future.delayed(const Duration(milliseconds: 300));
  //   await autoUpdater.checkForUpdates(inBackground: true);
  // }

  HttpOverrides.global = MyHttpOverrides();
  // final shouldRunApp = await updateGate.future;

  runApp(const BootstrapApp());
  // if (shouldRunApp) {
  //   await WindowModes.normal();
  //   runApp(const MyApp());
  // }
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
    _init();
  }

  Future<void> _init() async {
    await WindowModes.normal();
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
  // final _usernameController = TextEditingController(text: "jessa");
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

        await ApiController.instance.login(username, password);
        setState(() => _isLoading = false);

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
      } catch (e) {
        setState(() => _isLoading = false);
        if (mounted) {
          CustomNotification.error(e.toString());
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
          child: Stack(
            children: [
              // Centered login form
              Center(
                child: Container(
                  padding: const EdgeInsets.only(
                    left: 24,
                    right: 24,
                    bottom: 24,
                    top: 1,
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
                        mainAxisSize: MainAxisSize.min,
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
                          const SizedBox(height: 10),
                          // Username Field
                          TextFormField(
                            controller: _usernameController,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              isDense: true,
                              labelText: 'Username',
                              labelStyle: const TextStyle(
                                color: Colors.white70,
                              ),
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
                              errorStyle: const TextStyle(color: Colors.yellow),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter your username';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 10),
                          // Password Field
                          TextFormField(
                            controller: _passwordController,
                            obscureText: !_isPasswordVisible,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              isDense: true,
                              labelText: 'Password',
                              labelStyle: const TextStyle(
                                color: Colors.white70,
                              ),
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
                                    () => _isPasswordVisible =
                                        !_isPasswordVisible,
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
                              errorStyle: const TextStyle(color: Colors.yellow),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter your password';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 15),

                          // Login Button
                          SizedBox(
                            width: double.infinity,
                            height: 38,
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
                                      if (states.contains(
                                        MaterialState.disabled,
                                      )) {
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
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
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
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // Positioned version text at the bottom
              Positioned(
                bottom: 10,
                left: 0,
                right: 0,
                child: Text(
                  "Version: $_version ${_buildNumber.isNotEmpty ? "+$_buildNumber" : ""}",
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
