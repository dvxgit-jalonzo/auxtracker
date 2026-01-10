import 'package:flutter/material.dart';

class StatusBadge extends StatelessWidget {
  final Color baseColor;
  final bool isIdle;
  final String? stateAux;

  const StatusBadge({
    super.key,
    required this.baseColor,
    required this.isIdle,
    this.stateAux,
  });

  @override
  Widget build(BuildContext context) {
    final Color backgroundColor = isIdle ? Colors.grey.shade600 : baseColor;

    final Color borderColor = isIdle
        ? Colors.grey.shade400
        : HSLColor.fromColor(baseColor).withLightness(0.7).toColor();

    final Color glowColor = isIdle
        ? Colors.transparent
        : baseColor.withOpacity(0.45);

    return Flexible(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: backgroundColor,
          border: Border.all(color: borderColor, width: 1.5),
          borderRadius: BorderRadius.circular(8),
          boxShadow: isIdle
              ? []
              : [BoxShadow(color: glowColor, blurRadius: 12, spreadRadius: 1)],
        ),
        child: Text(
          isIdle ? "Inactive" : (stateAux ?? "NOT LOGGED"),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
