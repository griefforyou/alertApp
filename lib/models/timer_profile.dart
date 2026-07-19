import 'round_config.dart';

enum TimerCategory { study, training, custom }

class TimerProfile {
  final String id;
  final TimerCategory category;
  final String? customName;
  final List<RoundConfig> rounds;
  final bool multiCycle;
  final int totalCycles;

  const TimerProfile({
    required this.id,
    required this.category,
    this.customName,
    this.rounds = const [RoundConfig()],
    this.multiCycle = true,
    this.totalCycles = 4,
  });

  String get displayName {
    switch (category) {
      case TimerCategory.study:
        return '学习';
      case TimerCategory.training:
        return '训练';
      case TimerCategory.custom:
        return customName ?? '自定义';
    }
  }

  int get studyMinutes => rounds.isNotEmpty ? rounds[0].workMinutes : 2;
  int get breakMinutes => rounds.isNotEmpty ? rounds[0].breakMinutes : 1;

  TimerProfile copyWith({
    String? id,
    TimerCategory? category,
    String? customName,
    List<RoundConfig>? rounds,
    bool? multiCycle,
    int? totalCycles,
  }) {
    return TimerProfile(
      id: id ?? this.id,
      category: category ?? this.category,
      customName: customName ?? this.customName,
      rounds: rounds ?? this.rounds,
      multiCycle: multiCycle ?? this.multiCycle,
      totalCycles: totalCycles ?? this.totalCycles,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'category': category.name,
    if (customName != null) 'customName': customName,
    'rounds': rounds.map((r) => r.toJson()).toList(),
    'multiCycle': multiCycle,
    'totalCycles': totalCycles,
  };

  factory TimerProfile.fromJson(Map<String, dynamic> json) {
    List<RoundConfig> rounds;
    if (json.containsKey('rounds')) {
      rounds = (json['rounds'] as List).map((e) => RoundConfig.fromJson(e as Map<String, dynamic>)).toList();
    } else {
      rounds = [RoundConfig(
        workMinutes: json['studyMinutes'] as int? ?? 2,
        breakMinutes: json['breakMinutes'] as int? ?? 1,
      )];
    }
    return TimerProfile(
      id: json['id'] as String,
      category: TimerCategory.values.byName(json['category'] as String),
      customName: json['customName'] as String?,
      rounds: rounds,
      multiCycle: json['multiCycle'] as bool? ?? true,
      totalCycles: json['totalCycles'] as int? ?? 4,
    );
  }

  static List<TimerProfile> defaults() => [
    TimerProfile(
      id: 'builtin_study',
      category: TimerCategory.study,
      rounds: const [RoundConfig(workMinutes: 2, breakMinutes: 1)],
      multiCycle: true,
      totalCycles: 4,
    ),
    TimerProfile(
      id: 'builtin_training',
      category: TimerCategory.training,
      rounds: const [RoundConfig(workMinutes: 1, breakMinutes: 1)],
      multiCycle: true,
      totalCycles: 8,
    ),
  ];
}
