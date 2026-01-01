import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class DateTimeBar extends StatefulWidget {
  const DateTimeBar({super.key});

  @override
  State<DateTimeBar> createState() => _DateTimeBarState();
}

class _DateTimeBarState extends State<DateTimeBar> {
  late Timer _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            const Icon(
              Icons.calendar_month,
              size: 16,
              color: Colors.lightGreenAccent,
            ),
            const SizedBox(width: 8),
            Text(
              DateFormat('EEEE, MMMM d, yyyy').format(now),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.4,
              ),
            ),
          ],
        ),

        Row(
          children: [
            const Icon(
              Icons.timelapse,
              size: 16,
              color: Colors.lightGreenAccent,
            ),
            const SizedBox(width: 8),
            Text(
              DateFormat('HH:mm:ss').format(now),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.4,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
