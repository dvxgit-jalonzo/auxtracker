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
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          // Kapag idle, gawin nating Grey/Slate para halatang "Inactive"
          // Kapag active, gamitin ang baseColor (e.g., Purple)
          color: isIdle ? Colors.grey[600] : baseColor,
          borderRadius: BorderRadius.circular(12),
          // Inalis ang Border.all para maging solid type
        ),
        child: Text(
          isIdle ? "Inactive" : (stateAux ?? "NOT LOGGED"),
          style: const TextStyle(
            color: Colors.white, // Mas malinis tignan ang White sa solid background
            fontSize: 13,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}