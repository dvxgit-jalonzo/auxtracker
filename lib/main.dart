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
  HttpOverrides.global = MyHttpOverrides();
  runApp(const BootstrapApp());
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
            colors: [Colors.grey, Colors.black],
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
                            style: const TextStyle(
                              color: Colors.black,
                              fontSize: 15,
                            ),
                            decoration: InputDecoration(
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                              hintText: 'Username',
                              hintStyle: const TextStyle(
                                color: Colors.black45,
                              ),
                              prefixIcon: const Icon(
                                Icons.person_outline,
                                color: Colors.black,
                                size: 20,
                              ),
                              filled: true,
                              fillColor: Colors.white,

                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(6),
                                borderSide: const BorderSide(color: Colors.black26),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(6),
                                borderSide: const BorderSide(color: Colors.black26),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(6),
                                borderSide: const BorderSide(color: Colors.black26),
                              ),
                              errorStyle: const TextStyle(color: Colors.yellow),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter your username';
                              }
                              return null;
                            },
                          )

                          ,
                          const SizedBox(height: 10),
                          // Password Field
                          TextFormField(
                            controller: _passwordController,
                            obscureText: !_isPasswordVisible,
                            style: const TextStyle(
                              color: Colors.black,
                              fontSize: 15,
                            ),
                            decoration: InputDecoration(
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                              hintText: 'Password',
                              hintStyle: const TextStyle(
                                color: Colors.black45,
                              ),
                              prefixIcon: const Icon(
                                Icons.lock,
                                color: Colors.black,
                                size: 20,
                              ),
                              filled: true,
                              fillColor: Colors.white,

                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(6),
                                borderSide: const BorderSide(color: Colors.black26),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(6),
                                borderSide: const BorderSide(color: Colors.black26),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(6),
                                borderSide: const BorderSide(color: Colors.black26),
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
                            height: 45, // Tinaasan ko nang kaunti mula 38 para hindi ma-clip ang text/padding
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _handleLogin,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Color.fromARGB(255, 54, 190, 165), // Pure Teal
                                disabledBackgroundColor: Colors.teal.shade200, // Light teal kapag loading/disabled
                                foregroundColor: Colors.white, // White text
                                elevation: 0, // Tinanggal ang shadow para maging flat
                                shadowColor: Colors.transparent, // Siguradong walang anino
                                surfaceTintColor: Colors.transparent, // DITO NATATANGGAL YUNG "GRADIENT" EFFECT
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12), // Ginawa kong 12 para sumunod sa modern UI
                                ),
                                padding: const EdgeInsets.symmetric(vertical: 0), // Center text automatically
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                                  : const Text(
                                'Login',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.0,
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
