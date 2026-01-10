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
    return Flexible(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isIdle ? Colors.grey[600] : baseColor,
          borderRadius: BorderRadius.circular(8),
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
