import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:auxtrack/helpers/websocket_service.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';
import 'package:windows_toast/windows_toast.dart';

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
  bool _isLoading = false;
  Map<String, List<Auxiliary>> _auxiliariesByCategory = {};
  Map<String, dynamic>? _selectedAux;
  TabController? _tabController;
  final recorder = VideoRecorderController();

  void _dismissStatus() {
    setState(() {
      _currentStatus = null; // Setting to null hides the widget
    });
  }

  @override
  void onWindowClose() async {
    // Prevent default close behavior
    // Instead, hide to system tray
    await windowManager.hide();
  }

  StreamSubscription<bool>? _idleSubscription;
  String? _currentStatus;
  @override
  void initState() {
    super.initState();
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
        setState(() {
          _currentStatus = data['status'].toString();
        });
      }
    });

    _createEmployeeLogTimeIn();
    _startScreenRecording();
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
    print("Time In already sent to the server");
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    _idleSubscription?.cancel();
    _tabController?.dispose();
    WebSocketService().disconnect();
    _stopScreenRecording();
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
    setState(() => _isLoading = true);

    try {
      await ApiController.instance.logout();
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginPage()),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
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
              WindowsToast.show("Please wait for confirmation!", context, 30);
            } else {
              WindowsToast.show(
                "Failed to request Personal Break",
                context,
                30,
              );
            }
          }
        } catch (e) {
          if (mounted) {
            WindowsToast.show("Error: ${e.toString()}", context, 30);
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
        }

        WindowsToast.show("Saved!", context, 30);
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
            // Use a Stack to overlay the status indicator at the top
            children: [
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Original Title (moved up)
                    const Text(
                      'Select Auxiliary',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // The rest of your content (TabBar, TabBarView, etc.)
                    if (_tabController != null)
                      Container(
                        // ... (Your TabBar code) ...
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
                                      Colors.blue.shade400,
                                      Colors.blue.shade600,
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
                                unselectedLabelColor: Colors.white.withOpacity(
                                  0.5,
                                ),
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
                              const Color(
                                0xFF9C27B0,
                              ).withOpacity(0.95), // Deep Purple
                              const Color(
                                0xFFE91E63,
                              ).withOpacity(0.95), // Magenta/Pink
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
    );
  }

  Widget _buildAuxiliaryList(List<Auxiliary> auxiliaries) {
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: auxiliaries.length,
      itemBuilder: (context, index) {
        final aux = auxiliaries[index];
        final isSelected =
            _selectedAux != null && _selectedAux!['id'] == aux.id;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: isSelected
                    ? Colors.blue.withOpacity(0.3)
                    : Colors.black.withOpacity(0.1),
                blurRadius: isSelected ? 12 : 6,
                offset: Offset(0, isSelected ? 4 : 2),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => _handleAuxSelection(aux),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isSelected
                        ? [
                            Colors.blue.shade400.withOpacity(0.85),
                            Colors.blue.shade600.withOpacity(0.90),
                          ]
                        : [
                            Colors.white.withOpacity(0.12),
                            Colors.white.withOpacity(0.08),
                          ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected
                        ? Colors.blue.shade300.withOpacity(0.5)
                        : Colors.white.withOpacity(0.15),
                    width: isSelected ? 1.5 : 1,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 14,
                  ),
                  child: Row(
                    children: [
                      // Icon with gradient background
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: isSelected
                                ? [
                                    Colors.white.withOpacity(0.25),
                                    Colors.white.withOpacity(0.15),
                                  ]
                                : [
                                    Colors.white.withOpacity(0.15),
                                    Colors.white.withOpacity(0.08),
                                  ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.2),
                            width: 1,
                          ),
                        ),
                        child: Icon(
                          Icons.radio_button_checked_rounded,
                          size: 20,
                          color: isSelected
                              ? Colors.white
                              : Colors.white.withOpacity(0.6),
                        ),
                      ),

                      const SizedBox(width: 14),

                      // Text content
                      Expanded(
                        child: Text(
                          aux.sub,
                          style: TextStyle(
                            color: isSelected
                                ? Colors.white
                                : Colors.white.withOpacity(0.9),
                            fontSize: 13.5,
                            fontWeight: isSelected
                                ? FontWeight.w700
                                : FontWeight.w600,
                            letterSpacing: 0.3,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),

                      // Selection indicator with animation
                      AnimatedScale(
                        duration: const Duration(milliseconds: 200),
                        scale: isSelected ? 1.0 : 0.0,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.white.withOpacity(0.4),
                                blurRadius: 8,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.check_rounded,
                            size: 16,
                            color: Colors.blue.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
