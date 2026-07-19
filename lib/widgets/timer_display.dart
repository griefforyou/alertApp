import 'package:flutter/material.dart';
import '../models/session_state.dart';

class TimerDisplay extends StatelessWidget {
  final Duration remaining;
  final Phase phase;
  final int currentRound;
  final int totalRounds;
  final int currentCycle;
  final int totalCycles;
  final double progress;
  final int studyMinutes;
  final int breakMinutes;
  final String typeName;

  const TimerDisplay({
    super.key,
    required this.remaining,
    required this.phase,
    this.currentRound = 1,
    this.totalRounds = 1,
    required this.currentCycle,
    required this.totalCycles,
    required this.progress,
    this.studyMinutes = 0,
    this.breakMinutes = 0,
    this.typeName = '学习',
  });

  String get _timeText {
    final m = remaining.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = remaining.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (remaining.inHours > 0) {
      final h = remaining.inHours.toString().padLeft(2, '0');
      return '$h:$m:$s';
    }
    return '$m:$s';
  }

  String get _phaseText {
    switch (phase) {
      case Phase.idle:
        return '准备开始';
      case Phase.learning:
        return '$typeName中';
      case Phase.breaking:
        return '休息中';
      case Phase.finished:
        return '已完成';
    }
  }

  String get _groupText {
    if (totalRounds <= 1) return '';
    return '第 $currentRound/$totalRounds 组 · ';
  }

  String get _cycleText {
    if (phase == Phase.idle) {
      final roundsInfo = totalRounds > 1 ? '共${totalRounds}组 · ' : '';
      if (totalCycles == 0) return '${roundsInfo}${typeName}${studyMinutes}分 · 休息${breakMinutes}分 · 无限循环';
      return '${roundsInfo}${typeName}${studyMinutes}分 · 休息${breakMinutes}分 · ${totalCycles}轮';
    }
    if (phase == Phase.finished) return '所有轮次已完成';
    final group = _groupText;
    if (totalCycles == 0) return '${group}第 $currentCycle 轮（无限循环）';
    return '${group}第 $currentCycle/$totalCycles 轮';
  }

  @override
  Widget build(BuildContext context) {
    final color = phase == Phase.idle
        ? const Color(0xFF9E9E9E)
        : phase == Phase.learning
            ? const Color(0xFF2196F3)
            : phase == Phase.breaking
                ? const Color(0xFF4CAF50)
                : const Color(0xFF9E9E9E);

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          _phaseText,
          style: TextStyle(
            fontSize: 20,
            color: color,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _timeText,
          style: TextStyle(
            fontSize: 72,
            fontWeight: FontWeight.w200,
            color: color,
            fontFamily: 'monospace',
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _cycleText,
          style: TextStyle(
            fontSize: 16,
            color: color.withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(height: 24),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress.clamp(0.0, 1.0),
            minHeight: 6,
            backgroundColor: color.withValues(alpha: 0.15),
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
      ],
    );
  }
}
