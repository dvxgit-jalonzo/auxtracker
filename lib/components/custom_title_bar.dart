import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

class CustomTitleBar extends StatefulWidget {
  final Widget titleWidget;

  const CustomTitleBar({super.key, required this.titleWidget});

  @override
  State<CustomTitleBar> createState() => _CustomTitleBarState();
}

class _CustomTitleBarState extends State<CustomTitleBar> {
  OverlayEntry? _overlayEntry; // track current overlay

  void _showMinimizeConfirmation() {
    if (_overlayEntry != null) return; // prevent multiple overlays

    final overlay = Overlay.of(context);

    _overlayEntry = OverlayEntry(
      builder: (context) {
        return Positioned(
          top: 50,
          right: 20, // small alert at top-right
          width: 250, // smaller width
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[850],
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.4),
                    blurRadius: 6,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Minimizing may forget to log out!',
                    style: TextStyle(color: Colors.white, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () {
                          _overlayEntry?.remove();
                          _overlayEntry = null;
                        },
                        child: const Text(
                          'Cancel',
                          style: TextStyle(
                            color: Colors.redAccent,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              Colors.deepPurple.shade900, // modern green
                          foregroundColor: Colors.white, // text color
                          elevation: 4,
                          shadowColor: Colors.black.withOpacity(0.4),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              8,
                            ), // rounded corners
                          ),
                          textStyle: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                        onPressed: () async {
                          _overlayEntry?.remove();
                          _overlayEntry = null;
                          await windowManager.minimize();
                        },
                        child: const Text('Confirm'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    overlay.insert(_overlayEntry!);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 30,
      decoration: BoxDecoration(
        color: Colors.deepPurple.shade900,
        gradient: LinearGradient(
          colors: [Colors.green.shade700, Colors.deepPurple.shade900],
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Drag area
          Expanded(
            child: GestureDetector(
              onPanStart: (details) async {
                await windowManager.startDragging();
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: widget.titleWidget,
              ),
            ),
          ),

          // Minimize button
          IconButton(
            tooltip: "Minimize",
            iconSize: 20,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
            icon: const Icon(Icons.remove, color: Colors.white),
            onPressed: _showMinimizeConfirmation,
          ),
        ],
      ),
    );
  }
}
