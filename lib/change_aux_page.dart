import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:auxtrack/components/status_badge.dart';
import 'package:auxtrack/helpers/custom_notification.dart';
import 'package:auxtrack/helpers/periodic_capture_controller.dart';
import 'package:auxtrack/helpers/websocket_service.dart';
import 'package:auxtrack/helpers/window_modes.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';

import 'components/custom_title_bar.dart';
import 'components/date_time_bar.dart';
import 'components/theme_color.dart';
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
  bool _hasOvertimeRequest = false;
  DateTime? _startTime;
  bool _isAnimating = false;

  late Future<String> _name;
  Color _badgeColor = Colors.grey;
  Map<String, Color> _auxiliaryColors = {};

  Color _getColorForCurrentTab() {
    final categories = _auxiliariesByCategory.keys.toList();
    final currentIndex = _tabController!.index;

    if (currentIndex < 0 || currentIndex >= categories.length) {
      return Colors.blue; // Default fallback
    }

    final category = categories[currentIndex]; // Halimbawa: "BREAK"

    if (category == "LOG ON") {
      return ThemeColorExtension.fromAuxiliaryKey("CUSTOM").color;
    } else {
      return ThemeColorExtension.fromAuxiliaryKey(category).color;
    }
  }

  Future<void> _loadAuxiliaryColors() async {
    final prefs = await SharedPreferences.getInstance();
    final colorsJson = prefs.getString('auxiliaryColors');

    if (colorsJson != null) {
      final Map<String, dynamic> colorsMap = json.decode(colorsJson);

      setState(() {
        _auxiliaryColors = colorsMap.map(
          (key, value) =>
              MapEntry(key, ThemeColorExtension.fromAuxiliaryKey(value).color),
        );
      });
    }
  }

  @override
  void initState() {
    super.initState();
    WindowModes.restricted();
    windowManager.addListener(this);
    _loadAuxiliariesFromLocal();
    _loadAuxiliaryColors();
    _initializeApp();
    _name = _getUsername();
    WebSocketService().connect();
    WebSocketService().messageStream.listen((message) {
      if (message['event'] == "personalBreakResponse") {
        final data = message['data'];
        final status = data['status'];

        if (status == "APPROVED") {
          _createEmployeeLogPersonalBreak();
          setSelectedAux(sub: "Personal Break");
        } else {
          setSelectedAux();
        }
        setState(() {
          _hasPersonalBreakRequest = false;
        });
      }

      if (message['event'] == "overtimeResponse") {
        final data = message['data'];
        final status = data['status'];

        if (status == "APPROVED") {
          final sub = data['sub'];
          _createEmployeeLogOvertime(sub);
          setSelectedAux(sub: sub);
        } else {
          setSelectedAux();
        }
        setState(() {
          _hasOvertimeRequest = false;
        });
      }

      if (message['event'] == "messageEvent") {
        final data = message['data'];
        final content = data['message'];
        CustomNotification.warning(
          content,
          position: NotificationPosition.bottom,
        );
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
  void onWindowMinimize() async {
    bool isMinimizable;
    final userInfo = await ApiController.instance.loadUserInfo();
    if (userInfo!['minimizable'] != null) {
      isMinimizable = userInfo['minimizable'];
    } else {
      isMinimizable = false;
    }
    print(isMinimizable);
    if (!isMinimizable) {
      await windowManager.restore();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        textTheme: GoogleFonts.poppinsTextTheme(Theme.of(context).textTheme),
      ),
      child: Scaffold(
        backgroundColor: Colors.white, // Clean white background
        body: SafeArea(
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.only(
                  top: 33.0,
                  left: 12,
                  right: 12,
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
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.15),
                                ),
                              ),
                              child: const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white70,
                                ),
                              ),
                            ),
                          );
                        }

                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.teal.shade600,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.teal.shade400,
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black,
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
                                          Colors.yellow.shade900,
                                          Colors.amber.shade400,
                                        ],
                                      ),
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.red.withValues(
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
                                  StatusBadge(
                                    baseColor: _badgeColor,
                                    isIdle: _isIdle,
                                    stateAux: _stateAux,
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
                                          color: Colors.white,
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
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Listener(
                                onPointerSignal: (event) {
                                  if (event is PointerScrollEvent) {
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
                                child: AnimatedBuilder(
                                  animation: _tabController!,
                                  builder: (context, child) {
                                    final indicatorColor =
                                        _getColorForCurrentTab();

                                    return MouseRegion(
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
                                          indicatorSize:
                                              TabBarIndicatorSize.tab,
                                          dividerColor: Colors.transparent,
                                          indicator: BoxDecoration(
                                            color: indicatorColor,
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: indicatorColor
                                                    .withValues(alpha: 0.3),
                                                blurRadius: 6,
                                                offset: const Offset(0, 2),
                                              ),
                                            ],
                                          ),
                                          labelColor: Colors.white,
                                          unselectedLabelColor:
                                              Colors.grey.shade600,
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
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 12,
                                                      vertical: 6,
                                                    ),
                                                child: Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    Icon(
                                                      _getCategoryIcon(
                                                        category,
                                                      ),
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
                                    );
                                  },
                                ),
                              ),
                            ),
                            // Left arrow indicator
                            if (_tabController!.index > 0)
                              Positioned(
                                left: 0,
                                top: 0,
                                bottom: 0,
                                child: GestureDetector(
                                  onTap: _isAnimating
                                      ? null
                                      : () async {
                                          if (_tabController!.index > 0 &&
                                              !_isAnimating) {
                                            setState(() => _isAnimating = true);

                                            _tabController!.animateTo(
                                              _tabController!.index - 1,
                                            );

                                            await Future.delayed(
                                              const Duration(milliseconds: 300),
                                            );

                                            if (mounted) {
                                              setState(
                                                () => _isAnimating = false,
                                              );
                                            }
                                          }
                                        },
                                  child: Container(
                                    width: 30,
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade100,
                                      borderRadius: const BorderRadius.only(
                                        topLeft: Radius.circular(10),
                                        bottomLeft: Radius.circular(10),
                                      ),
                                    ),
                                    child: Icon(
                                      Icons.chevron_left,
                                      color: Colors.black38,
                                      size: 20,
                                    ),
                                  ),
                                ),
                              ),

                            // Right arrow
                            if (_tabController!.index <
                                _tabController!.length - 1)
                              Positioned(
                                right: 0,
                                top: 0,
                                bottom: 0,
                                child: GestureDetector(
                                  onTap: _isAnimating
                                      ? null
                                      : () async {
                                          if (_tabController!.index <
                                                  _tabController!.length - 1 &&
                                              !_isAnimating) {
                                            setState(() => _isAnimating = true);

                                            _tabController!.animateTo(
                                              _tabController!.index + 1,
                                            );

                                            await Future.delayed(
                                              const Duration(milliseconds: 300),
                                            );

                                            if (mounted) {
                                              setState(
                                                () => _isAnimating = false,
                                              );
                                            }
                                          }
                                        },
                                  child: Container(
                                    width: 30,
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade100,
                                      borderRadius: const BorderRadius.only(
                                        topRight: Radius.circular(10),
                                        bottomRight: Radius.circular(10),
                                      ),
                                    ),
                                    child: Icon(
                                      Icons.chevron_right,
                                      color: Colors.black38,
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
                                  color: Colors.grey.shade600,
                                  fontSize: 12,
                                ),
                              ),
                            )
                          : Container(
                              padding: EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey.shade200),
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
                    color: Colors.white,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.timelapse_rounded,
                              color: Colors.grey.shade700,
                              size: 20,
                            ),

                            const SizedBox(width: 12),

                            Expanded(
                              child: Text(
                                "Break request in progress",
                                style: TextStyle(
                                  color: Colors.grey.shade800,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),

                            TextButton(
                              onPressed: () async {
                                final status = await ApiController.instance
                                    .deletePersonalBreak();
                                setState(() {
                                  _hasPersonalBreakRequest = false;
                                });
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
                ),
              ],
              if (_hasOvertimeRequest) ...[
                Positioned(
                  bottom: 10,
                  left: 12,
                  right: 12,
                  child: Material(
                    elevation: 6,
                    borderRadius: BorderRadius.circular(14),
                    color: Colors.white,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.timelapse_rounded,
                              color: Colors.grey.shade700,
                              size: 20,
                            ),

                            const SizedBox(width: 12),

                            Expanded(
                              child: Text(
                                "OT request in progress",
                                style: TextStyle(
                                  color: Colors.grey.shade800,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),

                            TextButton(
                              onPressed: () async {
                                final result = await ApiController.instance
                                    .deleteOvertime();
                                if (result == true) {
                                  setSelectedAux();
                                }
                                setState(() {
                                  _hasOvertimeRequest = false;
                                });
                                return;
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

          return InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => _handleAuxSelection(aux),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected
                    ? _badgeColor.withValues(alpha: 0.1)
                    : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected
                      ? _badgeColor
                      : Colors.grey.shade400.withValues(alpha: 0.7),
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: Center(
                child: Text(
                  aux.sub,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isSelected ? _badgeColor : Colors.grey.shade700,
                    fontSize: 11,
                    overflow: TextOverflow.ellipsis,
                    fontWeight: isSelected
                        ? FontWeight.w600
                        : FontWeight.normal,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> setSelectedAux({dynamic sub}) async {
    if (sub == null) {
      final lastAux = await ApiController.instance.getLatestEmployeeLog();
      sub = lastAux['aux_sub'];
    }

    final aux = findAuxiliaryBySub(sub);

    if (aux != null) {
      setState(() {
        _badgeColor = ThemeColorExtension.fromAuxiliaryKey(aux.main).color;
        _selectedAux = {'id': aux.id, 'main': aux.main, 'sub': aux.sub};
      });
    } else {
      print("Auxiliary not found for sub: ${sub['aux_sub']}");
    }
  }

  Future<String> _getUsername() async {
    final userInfo = await ApiController.instance.loadUserInfo();
    return userInfo!['name'];
    // return "Jhun Norman";
  }

  Future<void> _initializeApp() async {
    try {
      print("initializing the app");
      // 1. First, create time in log (this will disable idle detection)
      await _createEmployeeLogTimeIn();

      // 2. Then initialize idle service (it will be disabled already)
      await _initializeServices();

      // 3. Listen to config changes
      _listenToIdleConfig();
    } catch (e) {
      CustomNotification.warning(e.toString());
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
    CustomNotification.fromHttpCode(
      response['message'],
      httpCode: response['http_code'],
    );
    if (response['code'] != "DUPLICATE_AUX") _startTimer();
    final userInfo = await ApiController.instance.loadUserInfo();
    if (userInfo != null) {
      final logger = PrototypeLogger(
        logFolder: userInfo['username'].toString().toLowerCase(),
      );
      logger.trail("[${response['code']}] auxiliary set to $sub.");
    }
  }

  void _createEmployeeLogOvertime(String sub) async {
    final response = await ApiController.instance.createEmployeeLog(sub);
    setState(() {
      _stateAux = sub;
    });
    CustomNotification.fromHttpCode(response['message']);
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
      final aux = findAuxiliaryBySub(sub);

      setState(() {
        _badgeColor = ThemeColorExtension.fromAuxiliaryKey(aux!.main).color;
        _stateAux = sub;
      });
      final userInfo = await ApiController.instance.loadUserInfo();
      if (userInfo != null) {
        final logger = PrototypeLogger(
          logFolder: userInfo['username'].toString().toLowerCase(),
        );
        logger.trail("[${response['code']}] auxiliary set to $sub.");
      }
      CustomNotification.fromHttpCode(response['message']);
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

      CustomNotification.fromHttpCode(result['message']);
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
        CustomNotification.warning("Logout Error");
        await ApiController.instance.forceLogout();
      }
    }
  }

  Auxiliary? findAuxiliaryBySub(String sub) {
    try {
      // Flatten all categories and search
      return _auxiliariesByCategory.values
          .expand((list) => list) // Flatten the lists
          .firstWhere(
            (aux) => aux.sub == sub,
            orElse: () => throw Exception('Not found'),
          );
    } catch (e) {
      return null;
    }
  }

  void _handleAuxSelection(Auxiliary aux) async {
    setState(() {
      _selectedAux = {'id': aux.id, 'main': aux.main, 'sub': aux.sub};
    });
    _handleConfirm();
  }

  Future<void> _handleConfirm() async {
    if (_selectedAux == null) return;
    final userInfo = await ApiController.instance.loadUserInfo();

    if (userInfo!['ot_approval'] == true) {
      if (_selectedAux!['main'] == "OT") {
        final result = await ApiController.instance.createOvertimeRequest(
          _selectedAux!['sub'],
        );

        if (result == true) {
          setState(() {
            _badgeColor = ThemeColorExtension.fromAuxiliaryKey(
              _selectedAux!['main'],
            ).color;
            _hasOvertimeRequest = true;
          });
        } else {
          CustomNotification.warning(
            "Failed to request OT. Check if theres pending OT request.",
          );
        }
        return;
      }
    }

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
              CustomNotification.fromHttpCode(message);
            } else {
              CustomNotification.warning("Failed to request Personal Break");
            }
          }
        } catch (e) {
          if (mounted) {
            CustomNotification.warning("Failed to request Personal Break");
          }
        }
      }
      setSelectedAux();
      return; // Exit early for Personal Break
    }
    if (_selectedAux!['sub'] == "Troubleshooting") {
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
                        'Please contact a Team Lead, Center Manager, or IT to authorize this request.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.orange,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
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
            setSelectedAux(sub: _selectedAux!['sub']);
            CustomNotification.fromHttpCode(response['message']);
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
              CustomNotification.warning("Failed to request OT");
            }
          }
        } catch (e) {
          if (mounted) {
            CustomNotification.warning("Failed to request OT");
          }
        }
      } else if (confirmResult == "false") {
        CustomNotification.warning("Credentials incorrect.");
        setSelectedAux();
      } else {
        setSelectedAux();
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

      final auxColor = await ApiController.instance.pluckAuxiliaryColor(
        _selectedAux!['main'],
      );

      setState(() {
        _badgeColor = ThemeColorExtension.fromAuxiliaryKey(
          _selectedAux!['main'],
        ).color;
        _stateAux = _selectedAux!['sub'];
      });
      CustomNotification.fromHttpCode(
        response['message'],
        httpCode: response['http_code'],
      );
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
      if (response['code'] == "ALREADY_TIMED_IN" ||
          response['code'] == "DUPLICATE_AUX") {
        await settingLastLog();
        return;
      }
      _startTimer();

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
    final aux = findAuxiliaryBySub(lastLog);

    _badgeColor = ThemeColorExtension.fromAuxiliaryKey(aux!.main).color;
    if (lastLog == "OFF") {
      setSelectedAux();
      CustomNotification.warning(
        "Status: $lastLog. Please update your Aux to continue today's session.",
      );
    } else {
      setSelectedAux();
      print("eyy ${response}");
      CustomNotification.fromHttpCode(
        "Setting aux to $lastLog",
        httpCode: response['http_code'],
      );
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
