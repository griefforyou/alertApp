import 'package:flutter/material.dart';

class ControlButtons extends StatelessWidget {
  final bool isRunning;
  final bool isPaused;
  final bool isFinished;
  final VoidCallback onStart;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onStop;

  const ControlButtons({
    super.key,
    required this.isRunning,
    required this.isPaused,
    required this.isFinished,
    required this.onStart,
    required this.onPause,
    required this.onResume,
    required this.onStop,
  });

  @override
  Widget build(BuildContext context) {
    if (isFinished) {
      return ElevatedButton.icon(
        onPressed: onStart,
        icon: const Icon(Icons.refresh),
        label: const Text('重新开始'),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        ),
      );
    }

    if (!isRunning) {
      return ElevatedButton.icon(
        onPressed: onStart,
        icon: const Icon(Icons.play_arrow),
        label: const Text('开始'),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          textStyle: const TextStyle(fontSize: 18),
        ),
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        OutlinedButton.icon(
          onPressed: onStop,
          icon: const Icon(Icons.stop),
          label: const Text('结束'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            foregroundColor: Colors.red,
          ),
        ),
        const SizedBox(width: 16),
        ElevatedButton.icon(
          onPressed: isPaused ? onResume : onPause,
          icon: Icon(isPaused ? Icons.play_arrow : Icons.pause),
          label: Text(isPaused ? '继续' : '暂停'),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            textStyle: const TextStyle(fontSize: 16),
          ),
        ),
      ],
    );
  }
}
