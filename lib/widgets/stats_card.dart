import 'package:flutter/material.dart';

class StatsCard extends StatelessWidget {
  final int totalStudySeconds;
  final int completedCycles;
  final String typeName;

  const StatsCard({
    super.key,
    this.totalStudySeconds = 0,
    this.completedCycles = 0,
    this.typeName = '学习',
  });

  String get _formattedTime {
    final h = totalStudySeconds ~/ 3600;
    final m = (totalStudySeconds % 3600) ~/ 60;
    if (h > 0) return '${h}h ${m}m';
    return '${m}m';
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.bar_chart, color: Color(0xFF2196F3)),
            const SizedBox(width: 12),
            Text('今日$typeName: ', style: TextStyle(fontSize: 16)),
            Text(
              _formattedTime,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF2196F3),
              ),
            ),
            const Spacer(),
            Text(
              '完成 $completedCycles 轮',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }
}
