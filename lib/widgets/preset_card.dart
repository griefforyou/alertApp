import 'package:flutter/material.dart';
import '../models/study_preset.dart';

class PresetCard extends StatelessWidget {
  final StudyPreset preset;
  final VoidCallback? onTap;
  const PresetCard({super.key, required this.preset, this.onTap});
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.schedule, color: Color(0xFF2196F3)),
            const SizedBox(width: 12),
            Text(preset.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}
