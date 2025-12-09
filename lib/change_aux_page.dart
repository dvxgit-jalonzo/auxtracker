import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:auxtrack/helpers/websocket_service.dart';
import 'package:auxtrack/helpers/window_modes.dart';
import 'package:elegant_notification/elegant_notification.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';

import 'helpers/api_controller.dart';
import 'helpers/idle_service.dart';
import 'helpers/recording_service.dart';
import 'main.dart';
import 'models/auxiliary.dart';

class ChangeAuxPage extends StatefulWidget {
  const ChangeAuxPage({super.key});

  @override
  State<ChangeAuxPage> createState() => _ChangeAuxPageState();
}

class _ChangeAuxPageState extends State<ChangeAuxPage>
    with WindowListener, SingleTickerProviderStateMixin {
  Map<String, List<Auxiliary>> _auxiliariesByCategory = {};
  Map<String, dynamic>? _selectedAux;
  TabController? _tabController;
  final recorder = VideoRecorderController();

  String _stateAux = "Time In";

  Timer? _timer;
  Duration _elapsedTime = Duration.zero;
  String _formattedTime = "00:00:00";

  void _dismissStatus() {
    setState(() {
      _currentStatus = null; // Setting to null hides the widget
    });
  }

  void _startTimer() {
    _timer?.cancel();
    _elapsedTime = Duration.zero;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _elapsedTime = Duration(seconds: _elapsedTime.inSeconds + 1);
        _formattedTime = _formatDuration(_elapsedTime);
      });
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    setState(() {
      _elapsedTime = Duration.zero;
      _formattedTime = "00:00:00";
    });
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String hours = twoDigits(duration.inHours);
    String minutes = twoDigits(duration.inMinutes.remainder(60));
    String seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$hours:$minutes:$seconds";
  }

  // @override
  // void onWindowClose() async {
  //   // Prevent default close behavior
  //   // Instead, hide to system tray
  //   await windowManager.hide();
  // }

  StreamSubscription<bool>? _idleSubscription;
  String? _currentStatus;
  @override
  void initState() {
    super.initState();
    WindowModes.restricted();
    windowManager.addListener(this);
    _loadAuxiliariesFromLocal();
    IdleService.instance.initialize();
    _idleSubscription = IdleService.instance.idleStateStream.listen((isIdle) {
      ApiController.instance.createEmployeeIdle(isIdle);
    });

    WebSocketService().connect();
    WebSocketService().messageStream.listen((message) {
      print('Received: ${message['event']}');

      // Extract 'status' if it exists
      final data = message['data'];
      if (data != null &&
          data is Map<String, dynamic> &&
          data.containsKey('status')) {
        if (data['status'] == "APPROVED") {
          _createEmployeeLogPersonalBreak();
        }
        setState(() {
          _currentStatus = data['status'].toString();
        });
      }
    });

    _createEmployeeLogTimeIn();
    _startScreenRecording();
  }

  void _createEmployeeLogPersonalBreak() async {
    await ApiController.instance.createEmployeeLog("Personal Break");
  }

  void _startScreenRecording() async {
    final userInfo = await ApiController.instance.loadUserInfo();
    if (userInfo == null || userInfo['id'] == null) {
      throw Exception(
        'start recording User info not found. Please login first.',
      );
    }
    final isEnableScreenCapture = userInfo['enable_screen_capture'];
    if (isEnableScreenCapture == 1) {
      try {
        await recorder.startRecording();
      } catch (e) {
        print('Error starting screen recording: $e');
      }
    }
  }

  void _stopScreenRecording() async {
    final userInfo = await ApiController.instance.loadUserInfo();
    if (userInfo == null || userInfo['id'] == null) {
      throw Exception(
        'stop recording User info not found. Please login first.',
      );
    }
    final isEnableScreenCapture = userInfo['enable_screen_capture'];
    if (isEnableScreenCapture == 1) {
      try {
        await recorder.stopRecording();
        print('Stop command sent');
      } catch (e) {
        print('Error stopping screen recording: $e');
      }
    }
  }

  void _createEmployeeLogTimeIn() async {
    await ApiController.instance.createEmployeeLog("Time In");
    _startTimer();
    print("Time In already sent to the server");
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    _idleSubscription?.cancel();
    _tabController?.dispose();
    WebSocketService().disconnect();
    _stopScreenRecording();
    _timer?.cancel();
    super.dispose();
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'LOG ON':
        return Icons.login_rounded;
      case 'BREAK':
        return Icons.coffee_rounded;
      case 'OT':
        return Icons.access_time_filled_rounded;
      case 'OTHER':
        return Icons.more_horiz_rounded;
      case 'LOG OFF':
        return Icons.logout_rounded;
      default:
        return Icons.category_rounded;
    }
  }

  Future<void> _loadAuxiliariesFromLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final auxiliariesString = prefs.getString('auxiliaries');

      if (auxiliariesString != null) {
        final Map<String, dynamic> data = jsonDecode(auxiliariesString);

        // Create a map to store parsed auxiliaries by category
        Map<String, List<Auxiliary>> auxiliariesMap = {};

        // Parse each category
        data.forEach((category, items) {
          if (items is List) {
            auxiliariesMap[category] = items
                .map((item) => Auxiliary.fromJson(item as Map<String, dynamic>))
                .toList();
          }
        });

        setState(() {
          _auxiliariesByCategory = auxiliariesMap;

          // Initialize tab controller with the number of categories
          if (_auxiliariesByCategory.isNotEmpty) {
            _tabController = TabController(
              length: _auxiliariesByCategory.length,
              vsync: this,
            );
          }
        });

        print('Successfully loaded ${auxiliariesMap.length} categories');
      }
    } catch (e) {
      print('Error loading auxiliaries from local storage: $e');
    }
  }

  Future<void> _handleLogout() async {
    try {
      await ApiController.instance.logout();
      await WindowModes.normal();
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginPage()),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Logout error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _handleAuxSelection(Auxiliary aux) {
    setState(() {
      _selectedAux = {'id': aux.id, 'main': aux.main, 'sub': aux.sub};
    });
    _handleConfirm();
  }

  Future<void> _requestLogout() async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.white.withOpacity(0.2)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.25),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                width: 300,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Icon container
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.help_outline_rounded,
                        color: Colors.white,
                        size: 34,
                      ),
                    ),

                    const SizedBox(height: 18),

                    // Title
                    const Text(
                      'Confirm Selection',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),

                    const SizedBox(height: 14),

                    // Selected item card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 14,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.18),
                        ),
                      ),
                      child: Text(
                        "OFF",
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),

                    const SizedBox(height: 22),

                    Row(
                      children: [
                        // Cancel
                        Expanded(
                          child: TextButton(
                            onPressed: () {
                              Navigator.pop(context);
                            },
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                                side: BorderSide(
                                  color: Colors.white.withOpacity(0.4),
                                ),
                              ),
                            ),
                            child: const Text(
                              'Cancel',
                              style: TextStyle(fontSize: 13),
                            ),
                          ),
                        ),

                        const SizedBox(width: 12),

                        // Confirm
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => Navigator.pop(context, true),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue.shade800,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              elevation: 6,
                            ),
                            child: const Text(
                              'Confirm',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );

    if (result == true) {
      if (mounted) {
        await ApiController.instance.createEmployeeLog("OFF");
        final userInfo = await ApiController.instance.loadUserInfo();
        if (userInfo == null || userInfo['id'] == null) {
          throw Exception(
            'change aux User info not found. Please login first.',
          );
        }

        _stopScreenRecording();
        _handleLogout();
        ElegantNotification.success(
          title: Text("Success"),
          description: Text("OFF has been saved."),
        ).show(context);
      }
    }
  }

  Future<void> _handleConfirm() async {
    if (_selectedAux == null) return;

    // Handle Personal Break with dialog to get reason
    if (_selectedAux!['sub'] == "Personal Break") {
      final reasonController = TextEditingController();

      final reasonResult = await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.all(24),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Colors.white.withOpacity(0.2)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.25),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  width: 300,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Icon container
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.coffee_outlined,
                          color: Colors.white,
                          size: 34,
                        ),
                      ),

                      const SizedBox(height: 18),

                      // Title
                      const Text(
                        'Personal Break',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),

                      const SizedBox(height: 14),

                      // Reason input field
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.18),
                          ),
                        ),
                        child: TextField(
                          controller: reasonController,
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(
                            hintText: 'Enter reason (optional)',
                            hintStyle: TextStyle(
                              color: Colors.white54,
                              fontSize: 13,
                            ),
                            border: InputBorder.none,
                          ),
                          maxLines: 2,
                        ),
                      ),

                      const SizedBox(height: 22),

                      Row(
                        children: [
                          // Cancel
                          Expanded(
                            child: TextButton(
                              onPressed: () {
                                Navigator.pop(context);
                              },
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  side: BorderSide(
                                    color: Colors.white.withOpacity(0.4),
                                  ),
                                ),
                              ),
                              child: const Text(
                                'Cancel',
                                style: TextStyle(fontSize: 13),
                              ),
                            ),
                          ),

                          const SizedBox(width: 12),

                          // Confirm
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () =>
                                  Navigator.pop(context, reasonController.text),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue.shade800,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                elevation: 6,
                              ),
                              child: const Text(
                                'Request Break',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      );

      if (reasonResult != null) {
        try {
          final success = await ApiController.instance.createPersonalBreak(
            reasonResult,
          );
          if (mounted) {
            if (success) {
              ElegantNotification.success(
                title: Text("Request Sent"),
                description: Text("Please wait for confirmation."),
              ).show(context);
            } else {
              ElegantNotification.error(
                title: Text("Error"),
                description: Text("Failed to request Personal Break"),
              ).show(context);
            }
          }
        } catch (e) {
          if (mounted) {
            ElegantNotification.error(
              title: Text("Error"),
              description: Text("Failed to request Personal Break: $e"),
            ).show(context);
          }
        }
      }
      return; // Exit early for Personal Break
    }

    // For other selections, show the regular confirmation dialog
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.white.withOpacity(0.2)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.25),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                width: 300,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Icon container
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.help_outline_rounded,
                        color: Colors.white,
                        size: 34,
                      ),
                    ),

                    const SizedBox(height: 18),

                    // Title
                    const Text(
                      'Confirm Selection',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),

                    const SizedBox(height: 14),

                    // Selected item card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 14,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.18),
                        ),
                      ),
                      child: Text(
                        _selectedAux!['sub'] ?? '',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),

                    const SizedBox(height: 22),

                    Row(
                      children: [
                        // Cancel
                        Expanded(
                          child: TextButton(
                            onPressed: () {
                              Navigator.pop(context);
                            },
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                                side: BorderSide(
                                  color: Colors.white.withOpacity(0.4),
                                ),
                              ),
                            ),
                            child: const Text(
                              'Cancel',
                              style: TextStyle(fontSize: 13),
                            ),
                          ),
                        ),

                        const SizedBox(width: 12),

                        // Confirm
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => Navigator.pop(context, true),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue.shade800,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              elevation: 6,
                            ),
                            child: const Text(
                              'Confirm',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );

    if (result == true) {
      if (mounted) {
        await ApiController.instance.createEmployeeLog(_selectedAux!['sub']);
        final userInfo = await ApiController.instance.loadUserInfo();
        if (userInfo == null || userInfo['id'] == null) {
          throw Exception(
            'change aux User info not found. Please login first.',
          );
        }
        if (_selectedAux!['sub'] == "OFF") {
          _stopScreenRecording();
          _handleLogout();
        } else {
          _startTimer();
        }
        setState(() {
          _stateAux = _selectedAux!['sub'];
        });
        ElegantNotification.success(
          title: Text("Success"),
          description: Text("${_selectedAux!['sub']} has been saved."),
        ).show(context);
      }
    } else {
      setState(() {
        _selectedAux = null; // Ito ang magpapakita na 'di na selected ang item
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DragToMoveArea(
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.green.shade700, Colors.deepPurple.shade900],
            ),
          ),
          child: SafeArea(
            child: Stack(
              // Use a Stack to overlay the status indicator at the top
              children: [
                Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            // ✅ Add Flexible here
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12, // 16 → 12
                                vertical: 8, // 10 → 8
                              ),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.lightBlue.withOpacity(0.2),
                                    Colors.white.withOpacity(0.08),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(
                                  20,
                                ), // 25 → 20
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.4),
                                  width: 1.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.4),
                                    blurRadius: 12, // 15 → 12
                                    offset: const Offset(0, 4), // 5 → 4
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const SizedBox(width: 6), // 8 → 6
                                  Flexible(
                                    child: Text(
                                      _stateAux ?? "NOT LOGGED",
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12, // 14 → 12
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 0.8, // 1.0 → 0.8
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 10), // 15 → 10
                                  Container(
                                    height: 16, // 20 → 16
                                    width: 1,
                                    color: Colors.white.withOpacity(0.3),
                                  ),
                                  const SizedBox(width: 10), // 15 → 10
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8, // 10 → 8
                                      vertical: 4, // 5 → 4
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(
                                        12,
                                      ), // 15 → 12
                                      border: Border.all(
                                        color: Colors.white.withOpacity(0.2),
                                        width: 1,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.timer_sharp,
                                          size: 12, // 14 → 12
                                          color: Colors.lightGreenAccent,
                                        ),
                                        const SizedBox(width: 5), // 6 → 5
                                        Text(
                                          _formattedTime,
                                          style: TextStyle(
                                            color: Colors.lightGreenAccent,
                                            fontSize: 11, // 12 → 11
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 0.4, // 0.5 → 0.4
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          InkWell(
                            borderRadius: BorderRadius.circular(40),
                            onTap: () {
                              _requestLogout();
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 1.5,
                                vertical: 1.5,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(40),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.deepPurple,
                                    blurRadius: 8,
                                  ),
                                ],
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.deepOrange.shade500,
                                    Colors.pinkAccent.shade700,
                                  ],
                                ),
                              ),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade900,
                                  borderRadius: BorderRadius.circular(40),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.settings_power,
                                      size: 15,
                                      color: Colors.deepOrange.shade500,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 8),

                      if (_tabController != null)
                        Container(
                          height: 42,
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.15),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.25),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Listener(
                              onPointerSignal: (event) {
                                if (event is PointerScrollEvent) {
                                  // Handle mouse wheel scroll - switches tabs
                                  final scrollOffset = event.scrollDelta.dy;

                                  if (scrollOffset > 0 &&
                                      _tabController!.index <
                                          _tabController!.length - 1) {
                                    _tabController!.animateTo(
                                      _tabController!.index + 1,
                                    );
                                  } else if (scrollOffset < 0 &&
                                      _tabController!.index > 0) {
                                    _tabController!.animateTo(
                                      _tabController!.index - 1,
                                    );
                                  }
                                }
                              },
                              child: MouseRegion(
                                cursor: SystemMouseCursors.click,
                                child: TabBar(
                                  controller: _tabController,
                                  isScrollable: true,
                                  tabAlignment: TabAlignment.start,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 3,
                                    vertical: 3,
                                  ),
                                  indicatorSize: TabBarIndicatorSize.tab,
                                  dividerColor: Colors.transparent,
                                  indicator: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        Colors.deepPurple.shade500,
                                        Colors.blue.shade900,
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.greenAccent.withOpacity(
                                          0.3,
                                        ),
                                        blurRadius: 6,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  labelColor: Colors.white,
                                  unselectedLabelColor: Colors.white
                                      .withOpacity(0.5),
                                  labelStyle: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.3,
                                  ),
                                  unselectedLabelStyle: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w500,
                                    letterSpacing: 0.2,
                                  ),
                                  tabs: _auxiliariesByCategory.keys.map((
                                    category,
                                  ) {
                                    return Tab(
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 6,
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              _getCategoryIcon(category),
                                              size: 14,
                                            ),
                                            const SizedBox(width: 5),
                                            Text(category),
                                          ],
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),
                            ),
                          ),
                        ),

                      const SizedBox(height: 8),

                      Expanded(
                        child: _tabController == null
                            ? Center(
                                child: Text(
                                  'No auxiliaries available',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.7),
                                    fontSize: 12,
                                  ),
                                ),
                              )
                            : Container(
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.3),
                                  ),
                                ),
                                child: TabBarView(
                                  controller: _tabController,
                                  children: _auxiliariesByCategory.entries
                                      .map(
                                        (entry) =>
                                            _buildAuxiliaryList(entry.value),
                                      )
                                      .toList(),
                                ),
                              ),
                      ),
                    ],
                  ),
                ),

                // --- NEW: Status Indicator Overlay ---
                if (_currentStatus != null)
                  Positioned(
                    top: 20, // Sit slightly below the very top edge
                    left: 0,
                    right: 0,
                    child: Center(
                      child: GestureDetector(
                        // Added GestureDetector for dismiss
                        onTap: _dismissStatus, // Call the new dismiss method
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            // --- UPDATED: Deep Purple/Magenta Gradient ---
                            gradient: LinearGradient(
                              colors: [
                                Colors.deepPurple.shade500,
                                Colors.blue.shade900,
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.4),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.notifications_active_rounded,
                                color: Colors.white,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Personal Brake has been $_currentStatus',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(width: 10),
                              // Subtle close indicator
                              Icon(
                                Icons.close,
                                color: Colors.white.withOpacity(0.7),
                                size: 16,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAuxiliaryList(List<Auxiliary> auxiliaries) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, left: 4, right: 4),
      child: GridView.builder(
        // Ginawang mas wide at mas mababa ang mga box (childAspectRatio: 3.5)
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 8.0,
          mainAxisSpacing: 8.0,
          childAspectRatio: 3.5,
        ),
        itemCount: auxiliaries.length,
        itemBuilder: (context, index) {
          final aux = auxiliaries[index];
          final isSelected = _selectedAux?['id'] == aux.id;

          return AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(12), // Binawasan
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => _handleAuxSelection(aux),
                child: Container(
                  padding: const EdgeInsets.all(8), // Binawasan ang padding
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isSelected
                          ? [Colors.blue.shade700, Colors.deepPurple.shade900]
                          : [
                              Colors.white.withOpacity(0.1),
                              Colors.white.withOpacity(0.06),
                            ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? Colors.lightGreenAccent.shade400.withOpacity(0.7)
                          : Colors.white.withOpacity(0.1),
                      width: isSelected ? 2.0 : 1.0,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: Colors.lightGreenAccent.withOpacity(0.2),
                              blurRadius: 8,
                              spreadRadius: 1, // Bahagyang lumiit ang shadow
                            ),
                          ]
                        : [],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Text ng Auxiliary
                      Expanded(
                        child: Text(
                          aux.sub,
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.white70,
                            fontSize: 12, // Binawasan ang font size
                            fontWeight: isSelected
                                ? FontWeight.w800
                                : FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),

                      // Selection indicator (Check Mark)
                      AnimatedScale(
                        duration: const Duration(milliseconds: 250),
                        scale: isSelected ? 1.0 : 0.0,
                        child: Container(
                          padding: const EdgeInsets.all(
                            4,
                          ), // Binawasan ang padding
                          decoration: BoxDecoration(
                            color: Colors.lightGreenAccent.shade400,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.check_rounded,
                            size: 12, // Binawasan ang icon size
                            color: Colors.deepPurple.shade900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
