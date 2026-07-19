enum TimerCategory { study, training, custom }

class TimerProfile {
  final String id;
  final TimerCategory category;
  final String? customName;
  final int studyMinutes;
  final int breakMinutes;
  final int totalCycles;

  const TimerProfile({
    required this.id,
    required this.category,
    this.customName,
    this.studyMinutes = 2,
    this.breakMinutes = 1,
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

  TimerProfile copyWith({
    String? id,
    TimerCategory? category,
    String? customName,
    int? studyMinutes,
    int? breakMinutes,
    int? totalCycles,
  }) {
    return TimerProfile(
      id: id ?? this.id,
      category: category ?? this.category,
      customName: customName ?? this.customName,
      studyMinutes: studyMinutes ?? this.studyMinutes,
      breakMinutes: breakMinutes ?? this.breakMinutes,
      totalCycles: totalCycles ?? this.totalCycles,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'category': category.name,
    if (customName != null) 'customName': customName,
    'studyMinutes': studyMinutes,
    'breakMinutes': breakMinutes,
    'totalCycles': totalCycles,
  };

  factory TimerProfile.fromJson(Map<String, dynamic> json) => TimerProfile(
    id: json['id'] as String,
    category: TimerCategory.values.byName(json['category'] as String),
    customName: json['customName'] as String?,
    studyMinutes: json['studyMinutes'] as int,
    breakMinutes: json['breakMinutes'] as int,
    totalCycles: json['totalCycles'] as int,
  );

  static List<TimerProfile> defaults() => [
    const TimerProfile(
      id: 'builtin_study',
      category: TimerCategory.study,
      studyMinutes: 2,
      breakMinutes: 1,
      totalCycles: 4,
    ),
    const TimerProfile(
      id: 'builtin_training',
      category: TimerCategory.training,
      studyMinutes: 1,
      breakMinutes: 1,
      totalCycles: 8,
    ),
  ];
}
