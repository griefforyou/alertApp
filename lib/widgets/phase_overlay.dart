import 'package:flutter/material.dart';
import '../models/session_state.dart';

class PhaseOverlay extends StatelessWidget {
  final String title;
  final String body;
  final Phase phase;
  final VoidCallback onDismiss;
  const PhaseOverlay({super.key, required this.title, required this.body, required this.phase, required this.onDismiss});
  @override
  Widget build(BuildContext context) {
    final color = phase == Phase.learning ? const Color(0xFF2196F3) : const Color(0xFF4CAF50);
    return Material(
      color: color.withValues(alpha: 0.95),
      child: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(phase == Phase.learning ? Icons.menu_book : Icons.free_breakfast, size: 80, color: Colors.white),
              const SizedBox(height: 24),
              Text(title, style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 16),
              Text(body, style: TextStyle(fontSize: 20, color: Colors.white.withValues(alpha: 0.9))),
              const SizedBox(height: 48),
              ElevatedButton(
                onPressed: onDismiss,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: color, padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16)),
                child: const Text('知道了'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
