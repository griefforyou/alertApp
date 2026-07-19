import "package:flutter/material.dart";
import "../models/timer_profile.dart";

class PresetCard extends StatelessWidget {
  final TimerProfile preset;
  final String typeName;
  final VoidCallback? onTap;
  const PresetCard({super.key, required this.preset, this.typeName = "\u5b66\u4e60", this.onTap});

  String get _description {
    if (preset.rounds.length == 1) {
      final r = preset.rounds[0];
      final study = "$typeName${r.workMinutes}\u5206\u949f";
      final rest = "\u4f11\u606f${r.breakMinutes}\u5206\u949f";
      if (preset.multiCycle && preset.totalCycles > 0) {
        return "$study\uff0c$rest\uff0c\u5faa\u73af${preset.totalCycles}\u8f6e";
      }
      if (preset.multiCycle) return "$study\uff0c$rest\uff0c\u65e0\u9650\u5faa\u73af";
      return "$study\uff0c$rest";
    }
    final roundsDesc = preset.rounds.asMap().entries.map((e) {
      final i = e.key + 1;
      final r = e.value;
      final unit = preset.multiCycle ? "\u8f6e" : "\u7ec4";
      return "\u7b2c${i}$unit:$typeName${r.workMinutes}\u5206\u2192\u4f11\u606f${r.breakMinutes}\u5206";
    }).join(" | ");
    if (preset.multiCycle && preset.totalCycles > 0) return "$roundsDesc\uff0c\u5faa\u73af${preset.totalCycles}\u8f6e";
    if (preset.multiCycle) return "$roundsDesc\uff0c\u65e0\u9650\u5faa\u73af";
    return roundsDesc;
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
                      preset.displayName,
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
