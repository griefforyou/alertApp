import 'package:flutter/material.dart';
import '../models/study_preset.dart';

class PresetCard extends StatelessWidget {
  final StudyPreset preset;
  final String typeName;
  final VoidCallback? onTap;
  const PresetCard({super.key, required this.preset, this.typeName = '学习', this.onTap});

  String get _description {
    final study = '$typeName${preset.studyMinutes}分钟';
    final rest = '休息${preset.breakMinutes}分钟';
    final cycles = preset.totalCycles > 0 ? '循环${preset.totalCycles}轮' : '无限循环';
    return '$study，$rest，$cycles';
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Icon(Icons.schedule, color: Color(0xFF2196F3)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      preset.name,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _description,
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}
