import 'package:elegant_notification/elegant_notification.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';

import 'change_aux_page.dart';
import 'helpers/api_controller.dart';

// Global system tray instance
// final SystemTray systemTray = SystemTray();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await windowManager.ensureInitialized();

  const windowWidth = 500.0;
  const windowHeight = 500.0;

  WindowOptions windowOptions = const WindowOptions(
    size: Size(windowWidth, windowHeight),
    center: true,
    titleBarStyle: TitleBarStyle.normal,
    windowButtonVisibility: false,
    skipTaskbar: false,
    alwaysOnTop: true,
    title: "Auxiliary Tracker",
  );

  await windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();

    await windowManager.setMinimizable(true);

    await windowManager.setMaximizable(false);
    await windowManager.setResizable(false);
    await windowManager.setPreventClose(false);
    await windowManager.setClosable(true);
  });

  // Initialize system tray
  // await initSystemTray();

  runApp(const MyApp());
}

// Future<void> initSystemTray() async {
//   try {
//     // Get the executable directory for the icon
//     String path = Platform.resolvedExecutable;
//     List<String> pathSegments = path.split(Platform.pathSeparator)
//       ..removeLast();
//     String iconPath =
//         '${pathSegments.join(Platform.pathSeparator)}${Platform.pathSeparator}data${Platform.pathSeparator}flutter_assets${Platform.pathSeparator}assets${Platform.pathSeparator}images${Platform.pathSeparator}icon.ico';
//
//     // Try to initialize with icon, if fails, try without icon
//     try {
//       await systemTray.initSystemTray(
//         title: "AuxTrack",
//         iconPath: iconPath,
//         toolTip: "AuxTrack - Click to open",
//       );
//     } catch (e) {
//       print('Failed to load icon, initializing without icon: $e');
//       // Initialize without icon if icon loading fails
//     }
//
//     // Create context menu
//     final Menu menu = Menu();
//     await menu.buildFrom([
//       MenuItemLabel(
//         label: 'Show Window',
//         onClicked: (menuItem) async {
//           await windowManager.show();
//           await windowManager.focus();
//         },
//       ),
//       MenuSeparator(),
//       MenuItemLabel(
//         label: 'Exit',
//         onClicked: (menuItem) async {
//           await windowManager.destroy();
//           exit(0);
//         },
//       ),
//     ]);
//
//     await systemTray.setContextMenu(menu);
//
//     // Handle left click on tray icon
//     systemTray.registerSystemTrayEventHandler((eventName) {
//       if (eventName == kSystemTrayEventClick) {
//         // Left click - show window
//         windowManager.show();
//         windowManager.focus();
//       } else if (eventName == kSystemTrayEventRightClick) {
//         // Right click - show context menu (handled automatically)
//         systemTray.popUpContextMenu();
//       }
//     });
//   } catch (e) {
//     print('System tray initialization error: $e');
//     // Continue without system tray if it fails
//   }
// }

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
  final _usernameController = TextEditingController(text: "admin");
  final _passwordController = TextEditingController(text: "admin123");
  bool _isPasswordVisible = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // THIS IS THE KEY PART - Handle window close event
  // @override
  // void onWindowClose() async {
  //   // Prevent default close behavior
  //   // Instead, hide to system tray
  //   await windowManager.hide();
  // }

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
            ElegantNotification.success(
              title: Text("Success"),
              description: Text("Login Successful"),
            ).show(context);
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
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Invalid username or password'),
                backgroundColor: Colors.red,
              ),
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
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // App Icon/Logo
                    ClipOval(
                      child: Image.asset(
                        'assets/images/icon.png',
                        width: 100,
                        height: 100,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Title
                    const Text(
                      'Welcome Back',
                      style: TextStyle(fontSize: 26, color: Colors.white),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Sign in to continue',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withOpacity(0.8),
                      ),
                    ),
                    const SizedBox(height: 32),

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
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
