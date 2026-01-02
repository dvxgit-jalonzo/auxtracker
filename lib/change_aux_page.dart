import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:auxtrack/helpers/custom_notification.dart';
import 'package:auxtrack/helpers/periodic_capture_controller.dart';
import 'package:auxtrack/helpers/websocket_service.dart';
import 'package:auxtrack/helpers/window_modes.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';

import 'components/custom_title_bar.dart';
import 'components/date_time_bar.dart';
import 'helpers/api_controller.dart';
import 'helpers/idle_service.dart';
import 'helpers/prototype_logger.dart';
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
  final capturer = PeriodicCaptureController();

  String? _stateAux;
  bool _isIdle = false;

  Timer? _timer;
  Duration _elapsedTime = Duration.zero;
  String _formattedTime = "00:00:00";

  StreamSubscription<bool>? _idleSubscription;
  StreamSubscription<IdleServiceConfig>? _configSubscription;
  bool _hasPersonalBreakRequest = false;
  DateTime? _startTime;

  late Future<String> _name;

  @override
  void initState() {
    super.initState();
    WindowModes.restricted();
    windowManager.addListener(this);
    _loadAuxiliariesFromLocal();

    _initializeApp();
    _name = _getUsername();
    WebSocketService().connect();
    WebSocketService().messageStream.listen((message) {
      if (message['event'] == "personalBreakResponse") {
        final data = message['data'];
        final status = data['status'];

        if (status == "APPROVED") {
          _createEmployeeLogPersonalBreak();
        }
        setState(() {
          _hasPersonalBreakRequest = false;
        });
      }

      if (message['event'] == "messageEvent") {
        final data = message['data'];
        final content = data['message'];
        CustomNotification.info(content);
      }

      if (message['event'] == "logoutEmployeeEvent") {
        final data = message['data'];
        _handleLogout();
      }
    });
  }

  @override
  void dispose() {
    _idleSubscription?.cancel();
    _configSubscription?.cancel();
    windowManager.removeListener(this);
    _tabController?.dispose();
    WebSocketService().disconnect();
    capturer.stopCapturing();
    _timer?.cancel();
    IdleService.instance.dispose();
    super.dispose();
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
                padding: const EdgeInsets.only(
                  top: 33.0,
                  left: 10,
                  right: 10,
                  bottom: 10,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FutureBuilder<String>(
                      future: _name,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return Center(
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.lightBlue.withValues(alpha: 0.2),
                                    Colors.white.withValues(alpha: 0.08),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  width: 1.5,
                                ),
                              ),
                              child: Center(
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.lightGreenAccent.withValues(
                                    alpha: 0.7,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }

                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.lightBlue.withValues(alpha: 0.2),
                                Colors.white.withValues(alpha: 0.08),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.2),
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.4),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Name section
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          Colors.yellow.shade600,
                                          Colors.amber.shade400,
                                        ],
                                      ),
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.yellow.withValues(
                                            alpha: 0.5,
                                          ),
                                          blurRadius: 8,
                                          spreadRadius: 1,
                                        ),
                                      ],
                                    ),
                                    child: Icon(
                                      Icons.person,
                                      size: 16,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      snapshot.data?.toUpperCase() ?? "UNKNOWN",
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                        letterSpacing: 1.2,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 10),

                              // Status and Timer section
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Flexible(
                                    child: Text(
                                      _isIdle
                                          ? "Inactive"
                                          : (_stateAux ?? "NOT LOGGED"),
                                      style: TextStyle(
                                        color: _isIdle
                                            ? Colors.yellow
                                            : Colors.lightGreenAccent,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 0.8,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(
                                        alpha: 0.1,
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: Colors.white.withValues(
                                          alpha: 0.2,
                                        ),
                                        width: 1,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.timer_sharp,
                                          size: 16,
                                          color: Colors.lightGreenAccent,
                                        ),
                                        const SizedBox(width: 5),
                                        Text(
                                          _formattedTime,
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 0.4,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 5),
                    if (_tabController != null)
                      Container(
                        height: 42,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.15),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.25),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Stack(
                          children: [
                            ClipRRect(
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
                                  child: Tooltip(
                                    message: "Scroll to switch tabs",
                                    showDuration: Duration(seconds: 2),
                                    preferBelow: false,
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
                                            color: Colors.greenAccent
                                                .withValues(alpha: 0.3),
                                            blurRadius: 6,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      labelColor: Colors.white,
                                      unselectedLabelColor: Colors.white
                                          .withValues(alpha: 0.5),
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
                            // Left arrow indicator (clickable)
                            if (_tabController!.index > 0)
                              Positioned(
                                left: 0,
                                top: 0,
                                bottom: 0,
                                child: GestureDetector(
                                  onTap: () {
                                    _tabController!.animateTo(
                                      _tabController!.index - 1,
                                    );
                                  },
                                  child: Container(
                                    width: 30,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          Colors.black.withOpacity(0.6),
                                          Colors.transparent,
                                        ],
                                        begin: Alignment.centerLeft,
                                        end: Alignment.centerRight,
                                      ),
                                      borderRadius: const BorderRadius.only(
                                        topLeft: Radius.circular(10),
                                        bottomLeft: Radius.circular(10),
                                      ),
                                    ),
                                    child: Icon(
                                      Icons.chevron_left,
                                      color: Colors.white.withOpacity(0.8),
                                      size: 20,
                                    ),
                                  ),
                                ),
                              ),

                            // Right arrow indicator (clickable)
                            if (_tabController!.index <
                                _tabController!.length - 1)
                              Positioned(
                                right: 0,
                                top: 0,
                                bottom: 0,
                                child: GestureDetector(
                                  onTap: () {
                                    _tabController!.animateTo(
                                      _tabController!.index + 1,
                                    );
                                  },
                                  child: Container(
                                    width: 30,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          Colors.transparent,
                                          Colors.black.withOpacity(0.6),
                                        ],
                                        begin: Alignment.centerLeft,
                                        end: Alignment.centerRight,
                                      ),
                                      borderRadius: const BorderRadius.only(
                                        topRight: Radius.circular(10),
                                        bottomRight: Radius.circular(10),
                                      ),
                                    ),
                                    child: Icon(
                                      Icons.chevron_right,
                                      color: Colors.white.withOpacity(0.8),
                                      size: 20,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),

                    const SizedBox(height: 5),
                    Expanded(
                      child: _tabController == null
                          ? Center(
                              child: Text(
                                'No auxiliaries available',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.7),
                                  fontSize: 12,
                                ),
                              ),
                            )
                          : Container(
                              padding: EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.purple.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.2),
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
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: CustomTitleBar(titleWidget: DateTimeBar()),
              ),
              if (_hasPersonalBreakRequest) ...[
                Positioned(
                  bottom: 10,
                  left: 12,
                  right: 12,
                  child: Material(
                    elevation: 6,
                    borderRadius: BorderRadius.circular(14),
                    color: Colors.blueGrey.shade900,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.timelapse_rounded,
                            color: Colors.white70,
                            size: 20,
                          ),

                          const SizedBox(width: 12),

                          const Expanded(
                            child: Text(
                              "Break request in progress",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),

                          TextButton(
                            onPressed: () async {
                              final status = await ApiController.instance
                                  .deletePersonalBreak();
                              if (status) {
                                setState(() {
                                  _hasPersonalBreakRequest = false;
                                });
                              }
                            },
                            child: const Text(
                              "CANCEL",
                              style: TextStyle(
                                color: Colors.redAccent,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAuxiliaryList(List<Auxiliary> auxiliaries) {
    return Padding(
      padding: const EdgeInsets.all(2),
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 5,
          mainAxisSpacing: 5,
          childAspectRatio: 2,
        ),
        itemCount: auxiliaries.length,
        itemBuilder: (context, index) {
          final aux = auxiliaries[index];
          final isSelected = _selectedAux?['id'] == aux.id;

          return AnimatedContainer(
            duration: const Duration(seconds: 5),
            curve: Curves.easeOut,
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(50),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => _handleAuxSelection(aux),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isSelected
                          ? [Colors.lightBlue.shade600, Colors.indigo.shade800]
                          : [
                              Colors.white.withValues(alpha: 0.15),
                              Colors.white.withValues(alpha: 0.08),
                            ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected
                          ? Colors.cyanAccent.shade400.withValues(alpha: 0.8)
                          : Colors.white.withValues(alpha: 0.15),
                      width: isSelected ? 2.5 : 1.0,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: Colors.cyanAccent.withValues(alpha: 0.3),
                              blurRadius: 10,
                              spreadRadius: 2,
                            ),
                          ]
                        : [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.3),
                              blurRadius: 3,
                              offset: const Offset(1, 1),
                            ),
                          ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Text ng Auxiliary
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            FittedBox(
                              fit: BoxFit
                                  .scaleDown, // Mag-shrink ang font if needed
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                ),
                                child: Text(
                                  aux.sub,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: isSelected
                                        ? Colors.white
                                        : Colors.white70,
                                    fontSize: 13,
                                    fontWeight: isSelected
                                        ? FontWeight.w900
                                        : FontWeight.w600,
                                    letterSpacing: 0.8,
                                  ),
                                  maxLines: null,
                                ),
                              ),
                            ),
                          ],
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

  Future<String> _getUsername() async {
    final userInfo = await ApiController.instance.loadUserInfo();
    return userInfo!['name'];
    // return "Jhun Norman";
  }

  Future<void> _initializeApp() async {
    try {
      // 1. First, create time in log (this will disable idle detection)
      await _createEmployeeLogTimeIn();

      // 2. Then initialize idle service (it will be disabled already)
      await _initializeServices();

      // 3. Listen to config changes
      _listenToIdleConfig();
    } catch (e) {
      CustomNotification.error(e.toString());
    }
  }

  Future<void> _initializeServices() async {
    try {
      // Initialize with disabled state by default
      await IdleService.instance.initialize(
        const IdleServiceConfig(
          enabled: false,
          idleThreshold: Duration(minutes: 1),
        ),
      );
      _subscribeToIdleStream();
      print('✅ IdleService initialized (disabled by default)');
    } catch (e) {
      print('Failed to initialize IdleService: $e');
    }
  }

  void _subscribeToIdleStream() {
    print('🔔 Subscribing to idle stream');

    _idleSubscription?.cancel();

    _idleSubscription = IdleService.instance.idleStateStream.listen(
      (isIdle) {
        print('🔔 Idle state changed in UI: $isIdle');
        if (mounted) {
          setState(() {
            _isIdle = isIdle;
          });
        }
      },
      onError: (error) {
        print('❌ Idle stream error: $error');
      },
      cancelOnError: false,
    );
  }

  void _listenToIdleConfig() {
    _configSubscription = IdleService.instance.configStream.listen((config) {
      print(
        '🔔 Config changed - enabled: ${config.enabled}, initialized: ${IdleService.instance.isInitialized}',
      );

      if (config.enabled && IdleService.instance.isInitialized) {
        Future.delayed(Duration(milliseconds: 100), () {
          _subscribeToIdleStream();
        });
      }
    });
  }

  void _startTimer([Duration elapsedTime = Duration.zero]) {
    _timer?.cancel();
    _elapsedTime = elapsedTime;
    _startTime = DateTime.now().subtract(elapsedTime);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _elapsedTime = DateTime.now().difference(_startTime!);
        _formattedTime = _formatDuration(_elapsedTime);
      });
    });
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String hours = twoDigits(duration.inHours);
    String minutes = twoDigits(duration.inMinutes.remainder(60));
    String seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$hours:$minutes:$seconds";
  }

  void _createEmployeeLogPersonalBreak() async {
    final sub = "Personal Break";
    final response = await ApiController.instance.createEmployeeLog(sub);
    setState(() {
      _stateAux = sub;
    });
    CustomNotification.info(response['message']);
    if (response['code'] != "DUPLICATE_AUX") _startTimer();
    final userInfo = await ApiController.instance.loadUserInfo();
    if (userInfo != null) {
      final logger = PrototypeLogger(
        logFolder: userInfo['username'].toString().toLowerCase(),
      );
      logger.trail("[${response['code']}] auxiliary set to $sub.");
    }
  }

  Future<void> _createEmployeeLogTimeIn() async {
    final sub = "Time In";
    final response = await ApiController.instance.createEmployeeLog(sub);

    if (response['code'] == "NO_ACTIVE_SCHEDULE") {
      final userInfo = await ApiController.instance.loadUserInfo();
      if (userInfo != null) {
        final logger = PrototypeLogger(
          logFolder: userInfo['username'].toString().toLowerCase(),
        );
        logger.trail("[${response['code']}] force logout.");
      }
      CustomNotification.warning(response['message']);
      await Future.delayed(Duration(seconds: 3));
      await ApiController.instance.forceLogout();
      return;
    }

    if (response['code'] == "ALREADY_TIMED_IN" ||
        response['code'] == "DUPLICATE_AUX") {
      final userInfo = await ApiController.instance.loadUserInfo();
      if (userInfo != null) {
        final logger = PrototypeLogger(
          logFolder: userInfo['username'].toString().toLowerCase(),
        );
        logger.trail("[${response['code']}] ${response['message']}");
      }
      await settingLastLog();
      return;
    } else {
      _startTimer();
      setState(() {
        _stateAux = sub;
      });
      final userInfo = await ApiController.instance.loadUserInfo();
      if (userInfo != null) {
        final logger = PrototypeLogger(
          logFolder: userInfo['username'].toString().toLowerCase(),
        );
        logger.trail("[${response['code']}] auxiliary set to $sub.");
      }
      CustomNotification.info(response['message']);
    }
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
        return Icons.settings_power_rounded;
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
      final userInfo = await ApiController.instance.loadUserInfo();
      if (userInfo == null || userInfo['id'] == null) {
        throw Exception('change aux User info not found. Please login first.');
      }
      final result = await ApiController.instance.createEmployeeLog("OFF");

      final logger = PrototypeLogger(
        logFolder: userInfo['username'].toString().toLowerCase(),
      );
      logger.trail("[${result['code']}] auxiliary set to OFF.");

      CustomNotification.info(result['message']);
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
        CustomNotification.error("Logout Error");
        await ApiController.instance.forceLogout();
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
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.2),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.25),
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
                        color: Colors.white.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.settings_power,
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
                        color: Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.18),
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
                                  color: Colors.white.withValues(alpha: 0.4),
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
        _handleLogout();
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
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.2),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.25),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  width: 300,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
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
                          color: Colors.white.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.18),
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
                                    color: Colors.white.withValues(alpha: 0.4),
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
                                'Request',
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
              final message = "Request Sent";
              setState(() {
                _hasPersonalBreakRequest = true;
              });
              CustomNotification.info(message);
            } else {
              CustomNotification.error("Failed to request Personal Break");
            }
          }
        } catch (e) {
          if (mounted) {
            CustomNotification.error("Failed to request Personal Break");
          }
        }
      }
      setState(() {
        _selectedAux = null;
      });
      return; // Exit early for Personal Break
    }
    if (_selectedAux!['main'] == "OT" ||
        _selectedAux!['sub'] == "Troubleshooting") {
      final username = TextEditingController();
      final password = TextEditingController();

      final confirmResult = await showDialog<String>(
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
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.2),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.25),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  width: 300,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Title
                      const Text(
                        'TL or Manager is required for this request.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.yellow,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.18),
                          ),
                        ),
                        child: TextField(
                          controller: username,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                          ),
                          decoration: const InputDecoration(
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(vertical: 11),
                            hintText: 'Enter username',
                            hintStyle: TextStyle(
                              color: Colors.white54,
                              fontSize: 13,
                            ),
                            border: InputBorder.none,
                          ),
                          maxLines: 1,
                        ),
                      ),
                      const SizedBox(height: 7),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.18),
                          ),
                        ),
                        child: TextField(
                          obscureText: true,
                          controller: password,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                          ),
                          decoration: const InputDecoration(
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(vertical: 11),
                            hintText: 'Enter password',
                            hintStyle: TextStyle(
                              color: Colors.white54,
                              fontSize: 13,
                            ),
                            border: InputBorder.none,
                          ),
                          maxLines: 1,
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
                                    color: Colors.white.withValues(alpha: 0.4),
                                  ),
                                ),
                              ),
                              child: const Text(
                                'Cancel',
                                style: TextStyle(fontSize: 13),
                              ),
                            ),
                          ),

                          const SizedBox(width: 11),

                          Expanded(
                            child: ElevatedButton(
                              onPressed: () async {
                                final confirm = await ApiController.instance
                                    .confirmCredential(
                                      username.text,
                                      password.text,
                                    );
                                Navigator.pop(context, confirm);
                              },
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
                                'Approve',
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

      if (confirmResult == "true") {
        try {
          if (mounted) {
            final userInfo = await ApiController.instance.loadUserInfo();
            if (userInfo == null || userInfo['id'] == null) {
              throw Exception(
                'change aux User info not found. Please login first.',
              );
            }
            final response = await ApiController.instance.createEmployeeLog(
              _selectedAux!['sub'],
            );
            setState(() {
              _stateAux = _selectedAux!['sub'];
            });
            CustomNotification.info(response['message']);
            if (response['code'] == "NO_ACTIVE_SCHEDULE") {
              final userInfo = await ApiController.instance.loadUserInfo();
              if (userInfo != null) {
                final logger = PrototypeLogger(
                  logFolder: userInfo['username'].toString().toLowerCase(),
                );
                logger.trail("[${response['code']}] force logout.");
              }
              await ApiController.instance.forceLogout();
              return;
            }

            final logger = PrototypeLogger(
              logFolder: userInfo['username'].toString().toLowerCase(),
            );
            logger.trail(
              "[${response['code']}] auxiliary set to ${_selectedAux!['sub']}.",
            );

            if (response['code'] != "DUPLICATE_AUX") _startTimer();
          } else {
            if (mounted) {
              CustomNotification.error("Failed to request OT");
            }
          }
        } catch (e) {
          if (mounted) {
            CustomNotification.error("Failed to request OT");
          }
        }
      } else if (confirmResult == "false") {
        CustomNotification.error("Credentials incorrect.");
        setState(() {
          _selectedAux = null;
        });
      } else {
        setState(() {
          _selectedAux = null;
        });
      }
      return; // Exit early for Personal Break
    }

    if (_selectedAux!['sub'] == "OFF") {
      _handleLogout();
      return;
    }

    if (mounted) {
      final userInfo = await ApiController.instance.loadUserInfo();
      if (userInfo == null || userInfo['id'] == null) {
        throw Exception('change aux User info not found. Please login first.');
      }
      final response = await ApiController.instance.createEmployeeLog(
        _selectedAux!['sub'],
      );
      print(response);
      setState(() {
        _stateAux = _selectedAux!['sub'];
      });
      CustomNotification.info(response['message']);
      if (response['code'] == "NO_ACTIVE_SCHEDULE") {
        final userInfo = await ApiController.instance.loadUserInfo();
        if (userInfo != null) {
          final logger = PrototypeLogger(
            logFolder: userInfo['username'].toString().toLowerCase(),
          );
          logger.trail("[${response['code']}] force logout.");
        }
        await ApiController.instance.forceLogout();
        return;
      }
      if (response['code'] != "DUPLICATE_AUX") {
        _startTimer();
      }

      final logger = PrototypeLogger(
        logFolder: userInfo['username'].toString().toLowerCase(),
      );
      logger.trail(
        "[${response['code']}] auxiliary set to ${_selectedAux!['sub']}.",
      );
    }
  }

  Future<void> settingLastLog() async {
    final response = await ApiController.instance.getLatestEmployeeLog();
    final lastLog = response['aux_sub'];
    if (lastLog == "OFF") {
      CustomNotification.warning(
        "Status: $lastLog. Please update your Aux to continue today's session.",
      );
    } else {
      CustomNotification.info("Setting aux to $lastLog");
    }
    setState(() {
      _stateAux = lastLog;
    });
    final userInfo = await ApiController.instance.loadUserInfo();
    if (userInfo != null) {
      final logger = PrototypeLogger(
        logFolder: userInfo['username'].toString().toLowerCase(),
      );
      logger.trail("[${response['code']}] auxiliary set to $lastLog.");
    }
    _startTimer(Duration(seconds: response['elapsedTime']));
  }
}
