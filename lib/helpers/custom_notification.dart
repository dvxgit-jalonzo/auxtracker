import 'package:flutter/material.dart';

import '../app_navigator.dart';

// Add enum for position
enum NotificationPosition { top, bottom }

class CustomNotification {
  static OverlayEntry? _currentOverlay;

  static OverlayState? get _overlay => navigatorKey.currentState?.overlay;

  static BuildContext? get _context => navigatorKey.currentContext;

  static void show({
    required String message,
    required NotificationType type,
    Duration duration = const Duration(seconds: 3),
    String? title,
    bool autoDismiss = true,
    NotificationPosition position = NotificationPosition.top, // Add parameter
  }) {
    final overlay = _overlay;
    final context = _context;

    if (overlay == null || context == null) return;

    // Remove existing notification if any
    try {
      _currentOverlay?.remove();
    } catch (_) {}

    final size = MediaQuery.sizeOf(context);
    final isMobile = size.width < 600;
    final notifWidth = isMobile ? size.width * 0.9 : 400.0;

    _currentOverlay = OverlayEntry(
      builder: (_) => _NotificationWidget(
        message: message,
        type: type,
        width: notifWidth,
        duration: duration,
        title: title,
        autoDismiss: autoDismiss,
        position: position, // Pass position
        onDismiss: () {
          _currentOverlay?.remove();
          _currentOverlay = null;
        },
      ),
    );

    overlay.insert(_currentOverlay!);
  }

  static void fromHttpCode(
    String message, {
    int httpCode = 200,
    String? title,
    NotificationPosition position = NotificationPosition.top, // Add parameter
  }) {
    final notifType = _getNotificationTypeFromHttpCode(httpCode);
    final defaultTitle = _getDefaultTitleFromHttpCode(httpCode);
    final autoDismiss = _shouldAutoDismiss(httpCode);

    show(
      message: message,
      type: notifType,
      title: title ?? defaultTitle,
      autoDismiss: autoDismiss,
      position: position, // Pass position
    );
  }

  static NotificationType _getNotificationTypeFromHttpCode(int code) {
    if (code >= 200 && code < 300) {
      return NotificationType.success;
    } else if (code >= 300 && code < 400) {
      return NotificationType.info;
    } else if (code >= 400 && code < 500) {
      return NotificationType.warning;
    } else if (code >= 500) {
      return NotificationType.error;
    } else {
      return NotificationType.info;
    }
  }

  static String _getDefaultTitleFromHttpCode(int code) {
    switch (code) {
      case 200:
        return 'Success';
      case 201:
        return 'Created';
      case 204:
        return 'No Content';
      case 301:
      case 302:
        return 'Redirected';
      case 400:
        return 'Bad Request';
      case 401:
        return 'Unauthorized';
      case 403:
        return 'Forbidden';
      case 404:
        return 'Not Found';
      case 422:
        return 'Validation Error';
      case 429:
        return 'Too Many Requests';
      case 500:
        return 'Server Error';
      case 502:
        return 'Bad Gateway';
      case 503:
        return 'Service Unavailable';
      default:
        if (code >= 200 && code < 300) return 'Success';
        if (code >= 400 && code < 500) return 'Client Error';
        if (code >= 500) return 'Server Error';
        return 'Info';
    }
  }

  static bool _shouldAutoDismiss(int code) {
    if (code >= 200 && code < 300) return true;
    if (code >= 300 && code < 400) return true;
    return false;
  }

  static void success(
    String message, {
    String? title,
    bool autoDismiss = true,
    NotificationPosition position = NotificationPosition.top, // Add parameter
  }) {
    show(
      message: message,
      type: NotificationType.success,
      title: title,
      autoDismiss: autoDismiss,
      position: position, // Pass position
    );
  }

  static void error(
    String message, {
    String? title,
    bool autoDismiss = false,
    NotificationPosition position = NotificationPosition.top, // Add parameter
  }) {
    show(
      message: message,
      type: NotificationType.error,
      title: title,
      autoDismiss: autoDismiss,
      position: position, // Pass position
    );
  }

  static void info(
    String message, {
    String? title,
    bool autoDismiss = true,
    NotificationPosition position = NotificationPosition.top, // Add parameter
  }) {
    show(
      message: message,
      type: NotificationType.info,
      title: title,
      autoDismiss: autoDismiss,
      position: position, // Pass position
    );
  }

  static void warning(
    String message, {
    String? title,
    bool autoDismiss = false,
    NotificationPosition position = NotificationPosition.top, // Add parameter
  }) {
    show(
      message: message,
      type: NotificationType.warning,
      title: title,
      autoDismiss: autoDismiss,
      position: position, // Pass position
    );
  }
}

enum NotificationType { success, error, info, warning }

class _NotificationConfig {
  final Color color;
  final Color bgColor;
  final IconData icon;
  final String defaultTitle;

  _NotificationConfig({
    required this.color,
    required this.bgColor,
    required this.icon,
    required this.defaultTitle,
  });
}

class _NotificationWidget extends StatefulWidget {
  final String message;
  final NotificationType type;
  final double width;
  final Duration duration;
  final String? title;
  final bool autoDismiss;
  final NotificationPosition position; // Add parameter
  final VoidCallback onDismiss;

  const _NotificationWidget({
    required this.message,
    required this.type,
    required this.width,
    required this.duration,
    required this.onDismiss,
    required this.autoDismiss,
    required this.position, // Add parameter
    this.title,
  });

  @override
  State<_NotificationWidget> createState() => _NotificationWidgetState();
}

class _NotificationWidgetState extends State<_NotificationWidget>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;
  late AnimationController _progressController; // Add progress controller
  late Animation<double> _progressAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _slideAnimation = Tween<Offset>(
      begin: widget.position == NotificationPosition.top
          ? const Offset(0, -1)
          : const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.elasticOut));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeIn));

    _controller.forward();

    // Progress bar controller
    if (widget.autoDismiss) {
      _progressController = AnimationController(
        vsync: this,
        duration: widget.duration,
      );

      _progressAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
        CurvedAnimation(parent: _progressController, curve: Curves.linear),
      );

      _progressController.forward();

      Future.delayed(widget.duration - const Duration(milliseconds: 300), () {
        if (mounted) {
          _controller.reverse().then((_) => widget.onDismiss());
        }
      });
    } else {
      // Dummy controller for non-auto-dismiss
      _progressController = AnimationController(vsync: this);
      _progressAnimation = AlwaysStoppedAnimation(0.0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _progressController.dispose();
    super.dispose();
  }

  _NotificationConfig _getConfig() {
    switch (widget.type) {
      case NotificationType.success:
        return _NotificationConfig(
          color: const Color(0xFF10B981),
          bgColor: const Color(0xFFD1FAE5),
          icon: Icons.check_circle_rounded,
          defaultTitle: 'Success',
        );
      case NotificationType.error:
        return _NotificationConfig(
          color: const Color(0xFFEF4444),
          bgColor: const Color(0xFFFEE2E2),
          icon: Icons.error_rounded,
          defaultTitle: 'Error',
        );
      case NotificationType.info:
        return _NotificationConfig(
          color: const Color(0xFF3B82F6),
          bgColor: const Color(0xFFDBEAFE),
          icon: Icons.info_rounded,
          defaultTitle: 'Info',
        );
      case NotificationType.warning:
        return _NotificationConfig(
          color: const Color(0xFFF59E0B),
          bgColor: const Color(0xFFFEF3C7),
          icon: Icons.warning_rounded,
          defaultTitle: 'Warning',
        );
    }
  }

  void _dismiss() {
    _progressController.stop();
    _controller.reverse().then((_) => widget.onDismiss());
  }

  @override
  Widget build(BuildContext context) {
    final config = _getConfig();
    final size = MediaQuery.sizeOf(context);
    final isMobile = size.width < 600;

    return Positioned(
      top: widget.position == NotificationPosition.top
          ? (isMobile ? 16 : 24)
          : null,
      bottom: widget.position == NotificationPosition.bottom
          ? (isMobile ? 16 : 24)
          : null,
      right: isMobile ? (size.width - widget.width) / 2 : 24,
      child: SlideTransition(
        position: _slideAnimation,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: widget.width,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: config.color.withOpacity(0.3),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: config.color.withOpacity(0.15),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Main content
                  Padding(
                    padding: EdgeInsets.all(isMobile ? 12 : 16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: config.bgColor,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            config.icon,
                            color: config.color,
                            size: isMobile ? 20 : 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                widget.title ?? config.defaultTitle,
                                style: TextStyle(
                                  fontSize: isMobile ? 14 : 15,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF1F2937),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                widget.message,
                                style: TextStyle(
                                  fontSize: isMobile ? 12 : 13,
                                  color: const Color(0xFF6B7280),
                                  height: 1.4,
                                ),
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        GestureDetector(
                          onTap: _dismiss,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Icon(
                              Icons.close,
                              size: isMobile ? 16 : 18,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Progress bar (only show if autoDismiss is true)
                  if (widget.autoDismiss)
                    AnimatedBuilder(
                      animation: _progressAnimation,
                      builder: (context, child) {
                        return ClipRRect(
                          borderRadius: const BorderRadius.only(
                            bottomLeft: Radius.circular(11),
                            bottomRight: Radius.circular(11),
                          ),
                          child: LinearProgressIndicator(
                            value: _progressAnimation.value,
                            backgroundColor: Colors.grey.shade200,
                            valueColor: AlwaysStoppedAnimation(config.color),
                            minHeight: 3,
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
