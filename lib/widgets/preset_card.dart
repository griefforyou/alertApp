import "package:flutter/material.dart";
import "../models/timer_profile.dart";

class PresetCard extends StatelessWidget {
  final TimerProfile preset;
  final String typeName;
  final VoidCallback? onTap;
  const PresetCard({super.key, required this.preset, this.typeName = "学习", this.onTap});

  String get _description {
    if (preset.rounds.length == 1) {
      final r = preset.rounds[0];
      final study = "$typeName${r.workMinutes}分钟";
      final rest = "休息${r.breakMinutes}分钟";
      if (preset.multiCycle && preset.totalCycles > 0) {
        return "$study，$rest，循环${preset.totalCycles}轮";
      }
      if (preset.multiCycle) return "$study，$rest，无限循环";
      return "$study，$rest";
    }
    final roundsDesc = preset.rounds.asMap().entries.map((e) {
      final i = e.key + 1;
      final r = e.value;
      final unit = preset.multiCycle ? "轮" : "组";
      return "第${i}$unit:$typeName${r.workMinutes}分→休息${r.breakMinutes}分";
    }).join(" | ");
    if (preset.multiCycle && preset.totalCycles > 0) return "$roundsDesc，循环${preset.totalCycles}轮";
    if (preset.multiCycle) return "$roundsDesc，无限循环";
    return roundsDesc;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.schedule, color: cs.primary),
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
                      style: TextStyle(fontSize: 14, color: cs.onSurface.withValues(alpha: 0.6)),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: cs.onSurface.withValues(alpha: 0.4)),
            ],
          ),
        ),
      ),
    );
  }
}
