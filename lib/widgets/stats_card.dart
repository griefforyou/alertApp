import 'package:flutter/material.dart';

class StatsCard extends StatelessWidget {
  const StatsCard({super.key});
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.bar_chart, color: Color(0xFF2196F3)),
            const SizedBox(width: 12),
            const Text('今日学习: ', style: TextStyle(fontSize: 16)),
            const Text('0h 0m', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF2196F3))),
          ],
        ),
      ),
    );
  }
}
