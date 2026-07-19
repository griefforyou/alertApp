import 'package:flutter/material.dart';

class ControlButtons extends StatelessWidget {
  final bool isRunning;
  final bool isPaused;
  final bool isFinished;
  final VoidCallback onStart;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final Future<void> Function() onStop;

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
    final cs = Theme.of(context).colorScheme;

    if (isFinished) {
      return ElevatedButton.icon(
        onPressed: onStart,
        icon: const Icon(Icons.refresh),
        label: const Text('重新开始'),
      );
    }

    if (isPaused) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          OutlinedButton.icon(
            onPressed: () => onStop(),
            icon: Icon(Icons.stop, color: cs.error),
            label: Text('结束', style: TextStyle(color: cs.error)),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: cs.error.withValues(alpha: 0.5)),
            ),
          ),
          const SizedBox(width: 16),
          ElevatedButton.icon(
            onPressed: onResume,
            icon: const Icon(Icons.play_arrow),
            label: const Text('继续'),
          ),
        ],
      );
    }

    if (!isRunning) {
      return ElevatedButton.icon(
        onPressed: onStart,
        icon: const Icon(Icons.play_arrow),
        label: const Text('开始'),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
          textStyle: const TextStyle(fontSize: 18),
        ),
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        OutlinedButton.icon(
          onPressed: () => onStop(),
          icon: Icon(Icons.stop, color: cs.error),
          label: Text('结束', style: TextStyle(color: cs.error)),
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: cs.error.withValues(alpha: 0.5)),
          ),
        ),
        const SizedBox(width: 16),
        ElevatedButton.icon(
          onPressed: isPaused ? onResume : onPause,
          icon: Icon(isPaused ? Icons.play_arrow : Icons.pause),
          label: Text(isPaused ? '继续' : '暂停'),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          ),
        ),
      ],
    );
  }
}
