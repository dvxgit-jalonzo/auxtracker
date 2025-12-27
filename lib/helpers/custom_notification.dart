import 'package:flutter/material.dart';

import '../app_navigator.dart';

class CustomNotification {
  static OverlayEntry? _currentOverlay;

  static OverlayState? get _overlay => navigatorKey.currentState?.overlay;

  static BuildContext? get _context => navigatorKey.currentContext;

  static void show({
    required String message,
    required NotificationType type,
    Duration duration = const Duration(seconds: 3),
    String? title,
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
        onDismiss: () {
          _currentOverlay?.remove();
          _currentOverlay = null;
        },
      ),
    );

    overlay.insert(_currentOverlay!);

    // Auto dismiss
    Future.delayed(duration, () {
      _currentOverlay?.remove();
      _currentOverlay = null;
    });
  }

  static void success(String message, {String? title}) {
    show(message: message, type: NotificationType.success, title: title);
  }

  static void error(String message, {String? title}) {
    show(message: message, type: NotificationType.error, title: title);
  }

  static void info(String message, {String? title}) {
    show(message: message, type: NotificationType.info, title: title);
  }

  static void warning(String message, {String? title}) {
    show(message: message, type: NotificationType.warning, title: title);
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
  final VoidCallback onDismiss;

  const _NotificationWidget({
    required this.message,
    required this.type,
    required this.width,
    required this.duration,
    required this.onDismiss,
    this.title,
  });

  @override
  State<_NotificationWidget> createState() => _NotificationWidgetState();
}

class _NotificationWidgetState extends State<_NotificationWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.elasticOut));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeIn));

    _controller.forward();

    // Auto dismiss animation
    Future.delayed(widget.duration - const Duration(milliseconds: 300), () {
      if (mounted) {
        _controller.reverse().then((_) => widget.onDismiss());
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
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
    _controller.reverse().then((_) => widget.onDismiss());
  }

  @override
  Widget build(BuildContext context) {
    final config = _getConfig();
    final size = MediaQuery.sizeOf(context);
    final isMobile = size.width < 600;

    return Positioned(
      bottom: isMobile ? 16 : 24,
      right: isMobile ? (size.width - widget.width) / 2 : 24,
      child: SlideTransition(
        position: _slideAnimation,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: widget.width,
              padding: EdgeInsets.all(isMobile ? 12 : 16),
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
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Icon
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

                  // Content
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

                  // Close button
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
          ),
        ),
      ),
    );
  }
}
